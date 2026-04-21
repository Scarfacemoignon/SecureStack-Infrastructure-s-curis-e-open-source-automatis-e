#!/bin/bash
# ============================================================
# TEST RÉPLICATION MariaDB Master/Slave
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

MASTER="mariadb-master"
SLAVE="mariadb-slave"
ROOT_PASS=$(grep DB_ROOT_PASSWORD .env | cut -d= -f2)
APP_PASS=$(grep DB_APP_PASSWORD .env | cut -d= -f2)
MYSQL_MASTER="docker exec $MASTER mysql -uroot -p$ROOT_PASS"
MYSQL_SLAVE="docker exec $SLAVE mysql -uroot -p$ROOT_PASS"
# Utilisateur applicatif (non-root) : bloqué par read_only=1 sur le slave
MYSQL_APP_SLAVE="docker exec $SLAVE mysql -uappuser -p$APP_PASS"

echo "============================================================"
echo " TEST RÉPLICATION MariaDB Master → Slave"
echo "============================================================"

# ── Test 1 : Statut réplication ──────────────────────────────
echo -e "\n${YELLOW}[1/4] Statut de la réplication...${NC}"
IO_STATUS=$($MYSQL_SLAVE -e "SHOW SLAVE STATUS\G" 2>/dev/null | \
    grep "Slave_IO_Running" | awk '{print $2}')
SQL_STATUS=$($MYSQL_SLAVE -e "SHOW SLAVE STATUS\G" 2>/dev/null | \
    grep "Slave_SQL_Running:" | awk '{print $2}')
DELAY=$($MYSQL_SLAVE -e "SHOW SLAVE STATUS\G" 2>/dev/null | \
    grep "Seconds_Behind_Master" | awk '{print $2}')

if [ "$IO_STATUS" = "Yes" ] && [ "$SQL_STATUS" = "Yes" ]; then
    echo -e "  ${GREEN}Slave IO Running  : $IO_STATUS${NC}"
    echo -e "  ${GREEN}Slave SQL Running : $SQL_STATUS${NC}"
    echo -e "  ${GREEN}Retard            : ${DELAY}s${NC}"
else
    echo -e "  ${RED}Slave IO Running  : $IO_STATUS${NC}"
    echo -e "  ${RED}Slave SQL Running : $SQL_STATUS${NC}"
fi

# ── Test 2 : Écriture sur master → lecture sur slave ─────────
echo -e "\n${YELLOW}[2/4] Test écriture master → lecture slave...${NC}"

TEST_MSG="test_$(date +%s)"
$MYSQL_MASTER appdb -e \
    "INSERT INTO test_replication (message) VALUES ('$TEST_MSG');" 2>/dev/null

sleep 2  # Attendre la réplication

SLAVE_RESULT=$($MYSQL_SLAVE appdb -e \
    "SELECT message FROM test_replication WHERE message='$TEST_MSG';" 2>/dev/null | \
    grep "$TEST_MSG")

if [ -n "$SLAVE_RESULT" ]; then
    echo -e "  ${GREEN}OK — '$TEST_MSG' répliqué sur le slave${NC}"
else
    echo -e "  ${RED}ERREUR — '$TEST_MSG' absent sur le slave${NC}"
fi

# ── Test 3 : Vérifier que le slave est en read-only ──────────
echo -e "\n${YELLOW}[3/4] Vérification read_only sur le slave...${NC}"
# Test avec appuser (non-root) : read_only=1 bloque les non-privilégiés
$MYSQL_APP_SLAVE appdb -e \
    "INSERT INTO test_replication (message) VALUES ('direct-write-test');" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "  ${GREEN}OK — Le slave refuse les écritures directes (read_only=1)${NC}"
else
    echo -e "  ${RED}ATTENTION — Le slave accepte les écritures directes !${NC}"
fi

# ── Test 4 : Comparer les données post-réplication ────────────
echo -e "\n${YELLOW}[4/4] Comparaison des données récentes master/slave...${NC}"

# Attendre que le slave soit à jour (max 10s)
for i in $(seq 1 10); do
    DELAY=$($MYSQL_SLAVE -e "SHOW SLAVE STATUS\G" 2>/dev/null | \
        grep "Seconds_Behind_Master" | awk '{print $2}')
    [ "$DELAY" = "0" ] && break
    sleep 1
done

# Comparer les 10 dernières entrées (post-réplication) sur les 2 nœuds
MASTER_LAST=$($MYSQL_MASTER appdb -e \
    "SELECT message FROM test_replication ORDER BY id DESC LIMIT 10;" \
    2>/dev/null | tail -n +2 | sort)
SLAVE_LAST=$($MYSQL_SLAVE appdb -e \
    "SELECT message FROM test_replication ORDER BY id DESC LIMIT 10;" \
    2>/dev/null | tail -n +2 | sort)

echo "  Master (10 dernières) : $(echo "$MASTER_LAST" | wc -l) lignes"
echo "  Slave  (10 dernières) : $(echo "$SLAVE_LAST" | wc -l) lignes"

if [ "$MASTER_LAST" = "$SLAVE_LAST" ]; then
    echo -e "  ${GREEN}OK — Données récentes synchronisées${NC}"
else
    echo -e "  ${RED}DÉSYNCHRONISATION des données récentes détectée !${NC}"
    echo "  Diff : $(diff <(echo "$MASTER_LAST") <(echo "$SLAVE_LAST"))"
fi

echo ""
echo "============================================================"
echo " FIN DU TEST RÉPLICATION"
echo "============================================================"

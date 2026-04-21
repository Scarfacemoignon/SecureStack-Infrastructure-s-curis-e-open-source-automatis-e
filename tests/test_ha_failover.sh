#!/bin/bash
# ============================================================
# TEST HA FAILOVER — Bascule HAProxy actif → passif
# ============================================================
# Ce test simule la panne de HAProxy #1 et vérifie que le
# trafic continue via HAProxy #2 (via la VIP Keepalived)
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

WAF_URL="http://localhost"
VIP="172.21.0.100"
HAPROXY1="haproxy1"

echo "============================================================"
echo " TEST HA FAILOVER — HAProxy actif/passif"
echo "============================================================"

# ── Étape 1 : Vérifier l'état initial ──────────────────────
echo -e "\n${YELLOW}[1/5] Vérification de l'état initial...${NC}"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $WAF_URL)
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}OK — WAF accessible (HTTP $RESPONSE)${NC}"
else
    echo -e "${RED}ERREUR — WAF inaccessible (HTTP $RESPONSE)${NC}"
    exit 1
fi

# ── Étape 2 : Générer du trafic en continu ──────────────────
echo -e "\n${YELLOW}[2/5] Démarrage du trafic de test continu...${NC}"
(
    for i in $(seq 1 30); do
        CODE=$(curl -s -o /dev/null -w "%{http_code}" $WAF_URL 2>/dev/null)
        echo "  Requête $i : HTTP $CODE"
        sleep 0.5
    done
) &
TRAFFIC_PID=$!

sleep 2

# ── Étape 3 : Simuler la panne de HAProxy #1 ────────────────
echo -e "\n${YELLOW}[3/5] SIMULATION PANNE — Arrêt de $HAPROXY1...${NC}"
docker stop $HAPROXY1
echo "  HAProxy #1 arrêté à $(date '+%H:%M:%S')"

# ── Étape 4 : Vérifier la bascule automatique ───────────────
echo -e "\n${YELLOW}[4/5] Attente bascule Keepalived (max 5s)...${NC}"
sleep 5

RESPONSE_AFTER=$(curl -s -o /dev/null -w "%{http_code}" $WAF_URL)
if [ "$RESPONSE_AFTER" = "200" ]; then
    echo -e "${GREEN}OK — Service toujours disponible via HAProxy #2 (HTTP $RESPONSE_AFTER)${NC}"
    echo -e "${GREEN}BASCULE RÉUSSIE !${NC}"
else
    echo -e "${RED}ERREUR — Service indisponible après bascule (HTTP $RESPONSE_AFTER)${NC}"
fi

# ── Étape 5 : Restaurer HAProxy #1 ──────────────────────────
echo -e "\n${YELLOW}[5/5] Restauration de $HAPROXY1...${NC}"
kill $TRAFFIC_PID 2>/dev/null || true
docker start $HAPROXY1
sleep 3

RESPONSE_FINAL=$(curl -s -o /dev/null -w "%{http_code}" $WAF_URL)
echo -e "${GREEN}État final : HTTP $RESPONSE_FINAL${NC}"

echo ""
echo "============================================================"
echo " RÉSULTAT DU TEST HA FAILOVER"
echo "============================================================"
echo " Avant panne  : HTTP $RESPONSE"
echo " Après panne  : HTTP $RESPONSE_AFTER"
echo " Après restore: HTTP $RESPONSE_FINAL"
[ "$RESPONSE_AFTER" = "200" ] && echo -e " ${GREEN}TEST RÉUSSI${NC}" || echo -e " ${RED}TEST ÉCHOUÉ${NC}"

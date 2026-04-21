#!/bin/bash
# ============================================================
# TEST IDS — Simulation de scans réseau détectés par Suricata
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TARGET="172.20.0.10"
SURICATA_LOG="docker exec suricata cat /var/log/suricata/fast.log"

echo "============================================================"
echo " TEST IDS Suricata — Détection de scans"
echo "============================================================"

# Compter les alertes avant les tests
ALERTS_BEFORE=$(docker exec suricata sh -c \
    "cat /var/log/suricata/eve.json | grep 'alert' | wc -l" 2>/dev/null || echo "0")

echo -e "\n${YELLOW}[1/4] Alertes Suricata avant tests : $ALERTS_BEFORE${NC}"

# ── Test 1 : Scan SYN (Nmap -sS) ─────────────────────────────
echo -e "\n${YELLOW}[2/4] Lancement scan SYN (nmap -sS)...${NC}"
nmap -sS -T4 --top-ports 100 $TARGET 2>/dev/null | tail -5
sleep 2

# ── Test 2 : Scan de version (Nmap -sV) ──────────────────────
echo -e "\n${YELLOW}[3/4] Lancement scan de version (nmap -sV)...${NC}"
nmap -sV -T3 -p 80,443,3306 $TARGET 2>/dev/null | tail -5
sleep 2

# ── Test 3 : Vérifier les alertes générées ───────────────────
echo -e "\n${YELLOW}[4/4] Vérification des alertes Suricata...${NC}"

ALERTS_AFTER=$(docker exec suricata sh -c \
    "cat /var/log/suricata/eve.json | grep 'alert' | wc -l" 2>/dev/null || echo "0")

NEW_ALERTS=$((ALERTS_AFTER - ALERTS_BEFORE))

echo ""
echo "============================================================"
echo " RÉSULTATS IDS"
echo "============================================================"
echo " Alertes avant : $ALERTS_BEFORE"
echo " Alertes après : $ALERTS_AFTER"
echo -e " Nouvelles alertes générées : ${GREEN}$NEW_ALERTS${NC}"

echo ""
echo " Dernières alertes Suricata :"
docker exec suricata sh -c \
    "cat /var/log/suricata/fast.log | tail -10" 2>/dev/null || \
    echo "  (log vide ou Suricata en cours de démarrage)"

echo ""
echo " Pour voir les alertes en temps réel :"
echo " docker exec suricata tail -f /var/log/suricata/fast.log"
echo ""
echo " Pour voir dans Wazuh :"
echo " http://localhost:5601 → Threat Intelligence"

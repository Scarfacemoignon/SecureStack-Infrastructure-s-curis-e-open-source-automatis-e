#!/bin/bash
# ============================================================
# Script de démarrage — TP Cybersécurité Open Source
# Usage : ./start.sh [all|db|web|lb|waf|ids|siem|stop|status]
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

COMPOSE="docker compose"

banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║     TP Cybersécurité — Architecture Open Source         ║"
    echo "║     WAF → HAProxy(HA) → Nginx(x2) → MariaDB(M/S)       ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_env() {
    if [ ! -f .env ]; then
        echo -e "${RED}ERREUR : fichier .env manquant !${NC}"
        echo "Créez le fichier .env (modèle disponible dans ce script)"
        exit 1
    fi
    source .env
    echo -e "${GREEN}OK — Fichier .env chargé${NC}"
}

step() {
    echo -e "\n${BLUE}━━━ $1 ━━━${NC}"
}

case "${1:-all}" in

# ── Démarrage complet ─────────────────────────────────────────
all)
    banner
    check_env

    step "ÉTAPE 1/5 — MariaDB (Base de données)"
    $COMPOSE up -d --build mariadb-master mariadb-slave
    echo "  Attente démarrage MariaDB (30s)..."
    sleep 30
    echo -e "  ${GREEN}MariaDB démarré${NC}"

    step "ÉTAPE 2/5 — Nginx (Serveurs web)"
    $COMPOSE up -d --build nginx1 nginx2
    sleep 5
    echo -e "  ${GREEN}Nginx x2 démarrés${NC}"

    step "ÉTAPE 3/5 — HAProxy + Keepalived (Load Balancer HA)"
    $COMPOSE up -d --build haproxy1 haproxy2
    sleep 5
    echo -e "  ${GREEN}HAProxy x2 démarrés${NC}"

    step "ÉTAPE 4/5 — ModSecurity WAF"
    $COMPOSE up -d --build waf
    sleep 5
    echo -e "  ${GREEN}WAF démarré${NC}"

    step "ÉTAPE 5/5 — Suricata IDS"
    $COMPOSE up -d --build suricata
    sleep 5
    echo -e "  ${GREEN}Suricata démarré${NC}"

    echo ""
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  DÉPLOIEMENT TERMINÉ                                    ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║  Application    : http://localhost                      ║"
    echo "║  HAProxy Stats  : http://localhost:8404/stats           ║"
    echo "║  Wazuh Dashboard: http://localhost:5601                 ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo ""
    echo "Pour démarrer Wazuh SIEM (séparément) :"
    echo "  cd services/wazuh && docker compose -f docker-compose.wazuh.yml up -d"
    ;;

# ── Wazuh SIEM ───────────────────────────────────────────────
siem)
    banner
    check_env
    step "Démarrage Wazuh SIEM"
    cd services/wazuh
    docker compose -f docker-compose.wazuh.yml up -d
    cd ../..
    echo ""
    echo "Wazuh démarre (2-3 minutes nécessaires)..."
    echo "Dashboard : http://localhost:5601"
    echo "Login : admin / \$INDEXER_PASSWORD (voir .env)"
    ;;

# ── Arrêt ────────────────────────────────────────────────────
stop)
    banner
    step "Arrêt de tous les services"
    $COMPOSE down
    cd services/wazuh && docker compose -f docker-compose.wazuh.yml down 2>/dev/null; cd ../..
    echo -e "${GREEN}Tous les services arrêtés${NC}"
    ;;

# ── Statut ───────────────────────────────────────────────────
status)
    banner
    step "État des conteneurs"
    $COMPOSE ps
    echo ""
    step "Tests de connectivité rapides"
    echo -n "  WAF (port 80)         : "
    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost/ 2>/dev/null || echo "KO"
    echo -n "  HAProxy stats (8404)  : "
    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8404/stats 2>/dev/null || echo "KO"
    echo -n "  Wazuh dashboard (5601): "
    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:5601/ 2>/dev/null || echo "KO"
    ;;

*)
    echo "Usage : ./start.sh [all|siem|stop|status]"
    echo "  all    : Démarrage complet (sans Wazuh)"
    echo "  siem   : Démarrage Wazuh uniquement"
    echo "  stop   : Arrêt de tout"
    echo "  status : État des services"
    ;;
esac

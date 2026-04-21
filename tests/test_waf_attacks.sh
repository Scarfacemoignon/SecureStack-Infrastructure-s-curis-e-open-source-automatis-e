#!/bin/bash
# ============================================================
# TEST WAF — Simulation d'attaques OWASP Top 10
# Vérifie que ModSecurity bloque les attaques courantes
# ============================================================

WAF_URL="http://localhost"
PASS=0
FAIL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_blocked() {
    local TEST_NAME="$1"
    local URL="$2"
    local CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null)
    if [[ "$CODE" == "403" || "$CODE" == "406" ]]; then
        echo -e "  ${GREEN}[BLOQUÉ]${NC} $TEST_NAME (HTTP $CODE)"
        ((PASS++))
    else
        echo -e "  ${RED}[PASSÉ !]${NC} $TEST_NAME (HTTP $CODE) ← PROBLÈME"
        ((FAIL++))
    fi
}

echo "============================================================"
echo " TEST WAF ModSecurity + OWASP CRS"
echo "============================================================"

# ── SQL Injection ─────────────────────────────────────────────
echo -e "\n${BLUE}[SQLi] Injection SQL${NC}"
check_blocked "SQLi classique"        "$WAF_URL/?id=1' OR '1'='1"
check_blocked "SQLi UNION"            "$WAF_URL/?id=1 UNION SELECT 1,2,3--"
check_blocked "SQLi blind (sleep)"    "$WAF_URL/?id=1; SELECT SLEEP(5)--"
check_blocked "SQLi commentaire"      "$WAF_URL/?user=admin'--"

# ── XSS ──────────────────────────────────────────────────────
echo -e "\n${BLUE}[XSS] Cross-Site Scripting${NC}"
check_blocked "XSS script tag"        "$WAF_URL/?q=<script>alert(1)</script>"
check_blocked "XSS onerror"           "$WAF_URL/?q=<img src=x onerror=alert(1)>"
check_blocked "XSS javascript:"       "$WAF_URL/?url=javascript:alert(document.cookie)"

# ── Path Traversal (LFI) ──────────────────────────────────────
echo -e "\n${BLUE}[LFI] Local File Inclusion / Path Traversal${NC}"
check_blocked "LFI /etc/passwd"       "$WAF_URL/?file=../../etc/passwd"
check_blocked "LFI encodé"            "$WAF_URL/?file=..%2F..%2Fetc%2Fpasswd"
check_blocked "LFI double encodé"     "$WAF_URL/?file=..%252F..%252Fetc%252Fpasswd"

# ── Shellshock / Command Injection ────────────────────────────
echo -e "\n${BLUE}[CMDi] Command Injection${NC}"
check_blocked "Command injection"     "$WAF_URL/?cmd=; cat /etc/passwd"

# Shellshock via User-Agent header
TEST_NAME="Shellshock"
CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H 'User-Agent: () { :;}; echo vulnerable' "$WAF_URL/" 2>/dev/null)
if [[ "$CODE" == "403" || "$CODE" == "406" ]]; then
    echo -e "  ${GREEN}[BLOQUÉ]${NC} $TEST_NAME (HTTP $CODE)"
    ((PASS++))
else
    echo -e "  ${RED}[PASSÉ !]${NC} $TEST_NAME (HTTP $CODE) ← PROBLÈME"
    ((FAIL++))
fi

# ── Scanner detection ─────────────────────────────────────────
echo -e "\n${BLUE}[SCAN] Détection de scanners${NC}"
TEST_NAME="Nikto User-Agent"
CODE=$(curl -s -o /dev/null -w "%{http_code}" -A "Nikto" "$WAF_URL" 2>/dev/null)
if [[ "$CODE" == "403" || "$CODE" == "406" ]]; then
    echo -e "  ${GREEN}[BLOQUÉ]${NC} $TEST_NAME (HTTP $CODE)"
    ((PASS++))
else
    echo -e "  ${RED}[PASSÉ !]${NC} $TEST_NAME (HTTP $CODE) ← PROBLÈME"
    ((FAIL++))
fi

# ── Résumé ────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " RÉSULTATS WAF"
echo "============================================================"
echo -e " Attaques bloquées : ${GREEN}$PASS${NC}"
echo -e " Attaques passées  : ${RED}$FAIL${NC}"
TOTAL=$((PASS + FAIL))
SCORE=$((PASS * 100 / TOTAL))
echo " Score WAF : $SCORE%"

echo ""
echo " Pour voir les alertes ModSecurity :"
echo " docker exec waf tail -f /var/log/modsecurity/audit.log"
echo ""
echo " Pour voir les alertes dans Wazuh :"
echo " http://localhost:5601 → Security Events"

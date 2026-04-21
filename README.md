# SecureStack — Infrastructure sécurisée open source automatisée

Déploiement d'une architecture réseau sécurisée et hautement disponible, entièrement automatisée via Ansible et Docker, intégrant WAF, IDS, load balancing HA et supervision SIEM avec Wazuh.

---

## Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────────────────┐
│  WAF — ModSecurity + OWASP CRS (port 80)    │  DMZ (172.20.0.0/24)
└──────────────────────┬──────────────────────┘
                       │
    ┌──────────────────▼──────────────────┐
    │  HAProxy #1 (MASTER)  ←→  Keepalived│  Frontend (172.21.0.0/24)
    │  HAProxy #2 (BACKUP)      VIP .100  │
    └──────────┬──────────────────────────┘
               │  load balancing round-robin
    ┌──────────▼──────────┐
    │  Nginx #1 │ Nginx #2 │  Backend (172.22.0.0/24)
    └─────┬─────┴────┬─────┘
          │          │
    ┌─────▼──────────▼─────┐
    │  MariaDB MASTER       │  Backend (172.22.0.0/24)
    │  MariaDB SLAVE (r/o)  │
    └──────────────────────┘

    ┌──────────────────────┐
    │  Suricata IDS         │  Host network (capture trafic)
    └──────────────────────┘

    ┌──────────────────────┐
    │  Wazuh Manager        │  Management (172.23.0.0/24)
    │  Wazuh Indexer        │
    │  Wazuh Dashboard      │
    └──────────────────────┘
```

---

## Prérequis

- Docker >= 24.0
- Docker Compose >= 2.0
- Python 3.x + pip (pour Ansible)
- nmap (pour les tests IDS) : `sudo apt install nmap`

---

## Démarrage rapide

### 1. Configurer les secrets

```bash
cp .env.example .env   # Si .env n'existe pas
# Éditer .env avec vos mots de passe
```

### 2. Démarrer l'infrastructure principale

```bash
./start.sh all
```

### 3. Démarrer le SIEM Wazuh (séparé, ~3 min)

```bash
cd services/wazuh

# Générer les certificats SSL (première fois uniquement)
docker compose -f generate-certs.yml run --rm generator

# Démarrer la stack
docker compose -f docker-compose.wazuh.yml --env-file ../../.env up -d

# Initialiser la sécurité de l'indexer (après ~30s)
docker exec -e OPENSEARCH_JAVA_HOME=/usr/share/wazuh-indexer/jdk wazuh-indexer \
  bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
  -cd /usr/share/wazuh-indexer/opensearch-security/ -icl -nhnv \
  -cacert /usr/share/wazuh-indexer/certs/root-ca.pem \
  -cert /usr/share/wazuh-indexer/certs/admin.pem \
  -key /usr/share/wazuh-indexer/certs/admin-key.pem \
  -h 172.23.0.30
```

---

## Accès aux services

| Service | URL | Credentials |
|---------|-----|-------------|
| Application web | http://localhost | — |
| HAProxy Stats | http://localhost:8404/stats | admin / voir `.env` |
| Wazuh Dashboard | https://localhost:5601 | admin / voir `.env` |

---

## Tests de validation

```bash
# Rendre les scripts exécutables
chmod +x tests/*.sh

# Réplication MariaDB master/slave
./tests/test_db_replication.sh

# WAF ModSecurity (attaques OWASP)
./tests/test_waf_attacks.sh

# IDS Suricata (scans réseau)
sudo ./tests/test_ids_scan.sh

# HA Failover HAProxy
./tests/test_ha_failover.sh
```

---

## Playbooks Ansible

```bash
cd ansible

# Installer les collections requises
ansible-galaxy collection install -r requirements.yml

# Chiffrer le vault (première fois)
ansible-vault encrypt group_vars/vault.yml

# Lancer la validation complète
ansible-playbook playbooks/site.yml

# Ou playbook par playbook
ansible-playbook playbooks/02_nginx.yml
ansible-playbook playbooks/03_haproxy.yml
ansible-playbook playbooks/04_waf.yml
ansible-playbook playbooks/05_suricata.yml
```

---

## Composants

| Composant | Technologie | Rôle |
|-----------|-------------|------|
| WAF | Nginx + ModSecurity + OWASP CRS | Filtrage des requêtes HTTP malveillantes |
| Load Balancer | HAProxy 2.8 + Keepalived | Haute disponibilité actif/passif, VIP |
| Web | Nginx 1.25 × 2 | Serveurs applicatifs en round-robin |
| Base de données | MariaDB 10.11 Master/Slave | Réplication synchrone, slave en read-only |
| IDS | Suricata | Détection d'intrusion réseau (EVE JSON) |
| SIEM | Wazuh 4.7 (Manager + Indexer + Dashboard) | Centralisation des alertes et logs |
| Automatisation | Ansible | Validation et configuration de l'infrastructure |

---

## Réseaux Docker

| Réseau | Subnet | Usage |
|--------|--------|-------|
| dmz | 172.20.0.0/24 | WAF exposé vers l'extérieur |
| frontend | 172.21.0.0/24 | HAProxy + VIP Keepalived |
| backend | 172.22.0.0/24 | Nginx + MariaDB |
| management | 172.23.0.0/24 | Wazuh + supervision |

---

## Arrêt

```bash
./start.sh stop
cd services/wazuh && docker compose -f docker-compose.wazuh.yml down
```

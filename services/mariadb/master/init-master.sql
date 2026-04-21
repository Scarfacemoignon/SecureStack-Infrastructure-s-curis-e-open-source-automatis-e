-- ============================================================
-- Initialisation du MariaDB MASTER
-- Exécuté automatiquement au 1er démarrage du conteneur
-- ============================================================

-- Base de données applicative
CREATE DATABASE IF NOT EXISTS appdb
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Utilisateur pour l'application web (Nginx/PHP)
CREATE USER IF NOT EXISTS 'appuser'@'172.22.%'
  IDENTIFIED BY 'ChangeMe_App_2024!';
GRANT SELECT, INSERT, UPDATE, DELETE ON appdb.* TO 'appuser'@'172.22.%';

-- Utilisateur de réplication (permission minimale : lecture binlog uniquement)
CREATE USER IF NOT EXISTS 'replicator'@'172.22.%'
  IDENTIFIED BY 'ChangeMe_Repl_2024!';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'172.22.%';

-- Table de test pour valider la réplication
USE appdb;
CREATE TABLE IF NOT EXISTS test_replication (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    message    VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO test_replication (message) VALUES ('master-init-ok');

FLUSH PRIVILEGES;

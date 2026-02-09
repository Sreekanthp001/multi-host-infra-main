-- Database Schema for Multi-Tenant Email Hosting
-- To be hosted on a MariaDB/MySQL instance

CREATE DATABASE IF NOT EXISTS mailserver;
GRANT ALL PRIVILEGES ON mailserver.* TO 'mailuser'@'localhost' IDENTIFIED BY 'secure_password';
FLUSH PRIVILEGES;

USE mailserver;

-- 1. Client Domains
CREATE TABLE `virtual_domains` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(50) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- 2. Mailboxes
CREATE TABLE `virtual_users` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `domain_id` INT NOT NULL,
  `password` VARCHAR(106) NOT NULL,
  `email` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- 3. Aliases / Forwarding
CREATE TABLE `virtual_aliases` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `domain_id` INT NOT NULL,
  `source` VARCHAR(100) NOT NULL,
  `destination` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`id`),
  FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

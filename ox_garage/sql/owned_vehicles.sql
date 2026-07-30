-- Véhicules personnels (ESX) — requis par ox_garage (public / privé / perso en entreprise)
-- Si la table existe déjà (esx_vehicleshop, etc.), ce fichier ajoute seulement la colonne parking.

CREATE TABLE IF NOT EXISTS `owned_vehicles` (
  `owner` VARCHAR(60) NOT NULL,
  `plate` VARCHAR(12) NOT NULL,
  `vehicle` LONGTEXT NULL,
  `type` VARCHAR(20) NOT NULL DEFAULT 'car',
  `job` VARCHAR(20) DEFAULT NULL,
  `stored` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1 = rangé, 0 = sorti',
  `parking` VARCHAR(60) DEFAULT NULL COMMENT 'id garage ox_garage (ex: legion, pinkcage, job_...)',
  `pound` VARCHAR(60) DEFAULT NULL,
  `glovebox` LONGTEXT NULL,
  `trunk` LONGTEXT NULL,
  PRIMARY KEY (`plate`),
  KEY `owner` (`owner`),
  KEY `parking` (`parking`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

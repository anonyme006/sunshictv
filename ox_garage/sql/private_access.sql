CREATE TABLE IF NOT EXISTS `ox_garage_private_access` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(60) NOT NULL,
  `garage_id` VARCHAR(64) NOT NULL,
  `slots` INT NOT NULL DEFAULT 1,
  `purchased_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `owner_garage` (`identifier`, `garage_id`),
  KEY `garage_id` (`garage_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ox_garage_job_vehicles` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `garage_id` VARCHAR(64) NOT NULL DEFAULT '',
  `template_id` INT DEFAULT NULL COMMENT 'id jc_vehicles lié',
  `plate` VARCHAR(12) NOT NULL,
  `model` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `min_grade` INT NOT NULL DEFAULT 0,
  `livery` INT NOT NULL DEFAULT 0,
  `props` LONGTEXT NULL,
  `stored` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `plate` (`plate`),
  KEY `job_name` (`job_name`),
  KEY `garage_id` (`garage_id`),
  KEY `template_id` (`template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

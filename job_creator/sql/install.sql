CREATE TABLE IF NOT EXISTS `jc_jobs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `type` VARCHAR(20) NOT NULL DEFAULT 'civil',
  `whitelisted` TINYINT(1) NOT NULL DEFAULT 1,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `actions` LONGTEXT NULL,
  `blip_sprite` INT DEFAULT 0,
  `blip_color` INT DEFAULT 0,
  `blip_scale` FLOAT DEFAULT 0.8,
  `blip_coords` TEXT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jc_grades` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `grade` INT NOT NULL DEFAULT 0,
  `name` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `salary` INT NOT NULL DEFAULT 0,
  `permissions` LONGTEXT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `job_grade` (`job_name`, `grade`),
  KEY `job_name` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jc_markers` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `type` VARCHAR(30) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `coords` TEXT NOT NULL,
  `min_grade` INT NOT NULL DEFAULT 0,
  `data` LONGTEXT NULL,
  `marker_type` INT DEFAULT 1,
  `marker_scale` TEXT NULL,
  `marker_color` TEXT NULL,
  `blip_enabled` TINYINT(1) DEFAULT 0,
  `blip_sprite` INT DEFAULT 1,
  `blip_color` INT DEFAULT 0,
  `blip_scale` FLOAT DEFAULT 0.7,
  `public` TINYINT(1) DEFAULT 0,
  `enabled` TINYINT(1) DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `job_name` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jc_vehicles` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `marker_id` INT DEFAULT NULL,
  `model` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `min_grade` INT NOT NULL DEFAULT 0,
  `price` INT NOT NULL DEFAULT 0,
  `livery` INT DEFAULT 0,
  `extras` TEXT NULL,
  PRIMARY KEY (`id`),
  KEY `job_name` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jc_outfits` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `min_grade` INT NOT NULL DEFAULT 0,
  `skin` LONGTEXT NOT NULL,
  `gender` VARCHAR(10) DEFAULT 'both',
  PRIMARY KEY (`id`),
  KEY `job_name` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jc_shop_items` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `marker_id` INT DEFAULT NULL,
  `item` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `price` INT NOT NULL DEFAULT 0,
  `min_grade` INT NOT NULL DEFAULT 0,
  `type` VARCHAR(20) DEFAULT 'item',
  PRIMARY KEY (`id`),
  KEY `job_name` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jc_crafts` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `marker_id` INT DEFAULT NULL,
  `label` VARCHAR(100) NOT NULL,
  `result_item` VARCHAR(50) NOT NULL,
  `result_count` INT NOT NULL DEFAULT 1,
  `ingredients` LONGTEXT NOT NULL,
  `duration` INT NOT NULL DEFAULT 5000,
  `min_grade` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `job_name` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jc_stashes` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `stash_id` VARCHAR(100) NOT NULL,
  `job_name` VARCHAR(50) NOT NULL,
  `items` LONGTEXT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `stash_id` (`stash_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jc_society` (
  `job_name` VARCHAR(50) NOT NULL,
  `money` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jc_duty` (
  `identifier` VARCHAR(60) NOT NULL,
  `job_name` VARCHAR(50) NOT NULL,
  `on_duty` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

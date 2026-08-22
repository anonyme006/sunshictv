CREATE TABLE IF NOT EXISTS character_creator (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50) NOT NULL,
    firstname VARCHAR(50) NOT NULL,
    lastname VARCHAR(50) NOT NULL,
    birthdate VARCHAR(20) NOT NULL,
    gender VARCHAR(20) NOT NULL,
    height INT DEFAULT 180,
    nationality VARCHAR(50),
    appearance LONGTEXT,
    clothing LONGTEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_citizenid (citizenid)
);

CREATE TABLE IF NOT EXISTS character_creator_drafts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    license VARCHAR(100) NOT NULL,
    citizenid VARCHAR(50) NULL,
    payload LONGTEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_license (license)
);

CREATE TABLE IF NOT EXISTS playerskins (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(255) NOT NULL,
    model VARCHAR(255) NOT NULL,
    skin LONGTEXT NOT NULL,
    active TINYINT(4) NOT NULL DEFAULT 1,
    KEY citizenid (citizenid),
    KEY active (active)
);

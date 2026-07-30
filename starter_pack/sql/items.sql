-- Items pour ox_inventory (à fusionner dans ox_inventory/data/items.lua)
-- Ou exécute les INSERT ci-dessous si tu utilises la table `items` ESX classique.

--[[
  ox_inventory — ajoute dans data/items.lua :

  ['id_card'] = {
      label = 'Carte d\'identité',
      weight = 10,
      stack = false,
      close = true,
  },

  ['phone'] = {
      label = 'Téléphone',
      weight = 190,
      stack = false,
      close = true,
  },

  ['bmx'] = {
      label = 'BMX',
      weight = 5000,
      stack = false,
      close = true,
      description = 'Un vélo BMX pliable',
  },

  ['water'] = {
      label = 'Eau',
      weight = 200,
      stack = true,
      close = true,
  },

  ['bread'] = {
      label = 'Pain',
      weight = 150,
      stack = true,
      close = true,
  },

  ['carte_chance'] = {
      label = 'Carte Chance',
      weight = 10,
      stack = false,
      close = true,
      description = 'Tourne la roue pour tenter de gagner de l\'argent en banque',
  },
]]

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
('id_card', 'Carte d\'identité', 10, 0, 1),
('phone', 'Téléphone', 190, 0, 1),
('bmx', 'BMX', 5000, 0, 1),
('water', 'Eau', 200, 0, 1),
('bread', 'Pain', 150, 0, 1),
('carte_chance', 'Carte Chance', 10, 0, 1);

CREATE TABLE IF NOT EXISTS `starter_pack_claims` (
  `identifier` VARCHAR(60) NOT NULL,
  `claimed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

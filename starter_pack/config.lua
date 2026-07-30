Config = {}

-- Framework : 'esx' (ESX Legacy)
Config.Framework = 'esx'

-- Donner le kit une seule fois (première connexion)
Config.GiveOnlyOnce = true

-- Délai après le spawn avant de donner le kit (ms)
Config.GiveDelay = 5000

-- Notification à la réception du kit
Config.NotifyOnReceive = true

--[[
    Items donnés à l'arrivée.
    Ajuste les noms selon ton inventaire (ox_inventory / esx_inventory).
]]
Config.StarterItems = {
    { name = 'id_card',     count = 1, label = 'Carte d\'identité' },
    { name = 'phone',       count = 1, label = 'Téléphone' },
    { name = 'bmx',         count = 1, label = 'BMX' },
    { name = 'water',       count = 5, label = 'Eau' },
    { name = 'bread',       count = 5, label = 'Pain' },
    { name = 'carte_chance', count = 1, label = 'Carte Chance' },
}

-- Spawner aussi un BMX physique à l'arrivée (en plus de l'item)
-- false = le BMX se spawn quand le joueur utilise l'item `bmx`
Config.SpawnBmxVehicle = false
Config.BmxModel = `bmx`
Config.BmxSpawnOffset = { x = 2.0, y = 0.0, z = 0.0 }

--[[
    Carte Chance — spin NUI
    Une seule utilisation : la carte est retirée après le tirage.
]]
Config.ChanceCard = {
    item = 'carte_chance',

    -- Plage de gains (déposés en banque)
    minReward = 10000,
    maxReward = 35000,

    -- Taux de réussite global (0.0 – 1.0)
    -- Ex: 0.75 = 75% de chance de gagner, 25% de perdre (0$)
    successRate = 0.75,

    -- Segments de la roue (montants + poids de probabilité relative)
    -- Plus le weight est élevé, plus le segment a de chances de sortir
    -- (uniquement si le tirage "réussite" est gagné)
    wheel = {
        { amount = 10000, weight = 30, color = '#3d5a4c' },
        { amount = 12500, weight = 22, color = '#4a6b5a' },
        { amount = 15000, weight = 18, color = '#5a7d4a' },
        { amount = 17500, weight = 12, color = '#6b8f3a' },
        { amount = 20000, weight = 8,  color = '#c9a227' },
        { amount = 25000, weight = 5,  color = '#d4a017' },
        { amount = 30000, weight = 3,  color = '#e07a2f' },
        { amount = 35000, weight = 2,  color = '#c44536' },
    },

    -- Compte bancaire ESX : 'bank'
    account = 'bank',
}

-- Messages
Config.Locale = {
    kit_received = 'Tu as reçu ton kit d\'arrivée !',
    already_received = 'Tu as déjà reçu ton kit d\'arrivée.',
    spin_success = 'Félicitations ! %s$ ont été versés sur ton compte bancaire.',
    spin_fail = 'Pas de chance… La carte n\'a rien donné cette fois.',
    no_card = 'Tu n\'as pas de Carte Chance.',
    already_spinning = 'Tirage déjà en cours…',
}

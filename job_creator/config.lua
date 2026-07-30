Config = {}

Config.Locale = 'fr'

-- Groupes autorisés à ouvrir le Job Creator
Config.AdminGroups = {
    ['admin'] = true,
    ['superadmin'] = true,
    ['god'] = true,
}

-- Commande pour ouvrir le panneau admin
Config.OpenCommand = 'jobcreator'
Config.OpenKey = nil -- ex: 'F7' ou nil

-- Distance d'interaction markers
Config.MarkerDistance = 15.0
Config.InteractDistance = 1.8

-- Marker par défaut (visuel)
Config.DefaultMarker = {
    type = 1,
    scale = { x = 1.0, y = 1.0, z = 0.8 },
    color = { r = 50, g = 150, b = 255, a = 120 },
    bobUpAndDown = false,
    faceCamera = false,
    rotate = false,
}

-- Société : utilise addon_account (esx_addonaccount) si true
Config.UseAddonAccount = true
Config.SocietyPrefix = 'society_'

-- Inventaire stash
-- 'ox' = ox_inventory | 'esx' = table SQL jc_stashes
Config.Inventory = 'esx'
Config.DefaultStashSlots = 50
Config.DefaultStashWeight = 100000

-- Salaires ESX (paycheck)
Config.SyncPaycheck = true

-- Actions job (menottes, escorte, etc.)
Config.EnableActions = true
Config.ActionsKey = 'F6'

-- Types de markers disponibles
Config.MarkerTypes = {
    { id = 'boss',       label = 'Menu Patron',      icon = 'briefcase' },
    { id = 'stash',      label = 'Coffre',            icon = 'box' },
    { id = 'cloakroom',  label = 'Vestiaire',         icon = 'shirt' },
    { id = 'garage',     label = 'Garage',            icon = 'car' },
    { id = 'garage_store', label = 'Ranger véhicule', icon = 'parking' },
    { id = 'shop',       label = 'Boutique job',      icon = 'cart' },
    { id = 'armory',     label = 'Armurerie',         icon = 'gun' },
    { id = 'duty',       label = 'Prise de service',  icon = 'badge' },
    { id = 'harvest',    label = 'Récolte',           icon = 'leaf' },
    { id = 'process',    label = 'Traitement',        icon = 'gears' },
    { id = 'craft',      label = 'Craft',             icon = 'hammer' },
    { id = 'sell',       label = 'Vente',             icon = 'dollar' },
    { id = 'teleport',   label = 'Téléportation',     icon = 'door' },
    { id = 'wash',       label = 'Blanchiment',       icon = 'money' },
}

-- Permissions disponibles par grade
Config.Permissions = {
    { id = 'boss',           label = 'Accès menu patron' },
    { id = 'hire',           label = 'Recruter' },
    { id = 'fire',           label = 'Licencier' },
    { id = 'promote',        label = 'Promouvoir / rétrograder' },
    { id = 'withdraw',       label = 'Retirer argent société' },
    { id = 'deposit',        label = 'Déposer argent société' },
    { id = 'stash',          label = 'Accès coffre' },
    { id = 'armory',         label = 'Accès armurerie' },
    { id = 'garage',         label = 'Accès garage' },
    { id = 'cloakroom',      label = 'Accès vestiaire' },
    { id = 'billing',        label = 'Faire des factures' },
    { id = 'actions',        label = 'Actions (menottes, etc.)' },
    { id = 'shop',           label = 'Accès boutique' },
    { id = 'craft',          label = 'Accès craft' },
}

-- Actions F6 par défaut (activables par job)
Config.DefaultActions = {
    { id = 'billing',   label = 'Facturer',           icon = 'file-invoice' },
    { id = 'handcuff',  label = 'Menotter / Démenotter', icon = 'handcuffs' },
    { id = 'escort',    label = 'Escorter',           icon = 'person' },
    { id = 'putinveh',  label = 'Mettre dans véhicule', icon = 'car-side' },
    { id = 'outveh',    label = 'Sortir du véhicule', icon = 'door-open' },
    { id = 'search',    label = 'Fouiller',           icon = 'search' },
    { id = 'identity',  label = 'Regarder identité',  icon = 'id-card' },
}

-- Animation récolte / traitement
Config.FarmAnim = {
    dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
    clip = 'machinic_loop_mechandplayer',
    flag = 1,
}

Config.ProcessTime = 5000
Config.HarvestTime = 4000
Config.SellTime = 3000

-- Discord webhook (logs admin)
Config.Webhook = ''

-- Debug
Config.Debug = false

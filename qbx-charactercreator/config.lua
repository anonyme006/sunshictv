Config = {}

Config.Locale = 'fr'
Config.Debug = false

-- Apparence physique : rCore Clothing (visage, parents, vêtements, etc.).
-- Ne pas recréer ces fonctionnalités dans cette ressource.
Config.ClothingSystem = 'rcore_clothing' -- 'rcore_clothing' | 'native' | 'illenium-appearance' | 'custom'

-- Taille enregistrée en centimètres dans charinfo.height (Qbox).
Config.MinHeight = 150
Config.MaxHeight = 200

Config.CreatorCamera = true
Config.AllowCancel = true
Config.RequireIdentity = true
Config.MinimumAge = 18
Config.MaximumAge = 80
Config.EnableClothing = true
Config.EnableMakeup = true
Config.EnableAccessories = true
Config.EnableSound = true
Config.EnableDrafts = true

Config.Creator = {
    EnableBlur = true,
    EnableAnimations = true,
    EnableSound = true,
    EnableCameraMovement = true,
    HideRadar = true,
    HideHud = true,
    DisableTarget = true,
    DisableInventory = true,
    IsolateBucket = true,
    BucketOffset = 7000,
}

Config.Sound = {
    enabled = true,
    volume = 0.3,
}

Config.Draft = {
    enabled = true,
    timeoutMinutes = 60,
    saveIntervalMs = 4000,
}

Config.Spawn = {
    coords = vec4(-269.4, -955.3, 31.2, 205.8),
    useQboxSpawn = true,
}

Config.CreatorPosition = vec4(402.91, -996.76, -99.0, 185.17)

Config.CreatorIpls = {}

Config.Models = {
    male = 'mp_m_freemode_01',
    female = 'mp_f_freemode_01',
}

Config.AllowedModels = {
    mp_m_freemode_01 = true,
    mp_f_freemode_01 = true,
}

Config.Identity = {
    minNameLength = 2,
    maxNameLength = 20,
    allowedNamePattern = '^[%aÀ-ÖØ-öø-ÿ\'%-%s]+$',
    defaultHeight = 180,
    minHeight = Config.MinHeight,
    maxHeight = Config.MaxHeight,
    defaultNationality = 'Française',
    dateFormat = 'DD/MM/YYYY',
}

-- Liste déroulante du formulaire d'identité. Modifiez librement ce tableau.
Config.Nationalities = {
    'Française',
    'Américaine',
    'Anglaise',
    'Espagnole',
    'Italienne',
    'Allemande',
    'Belge',
    'Canadienne',
    'Portugaise',
    'Néerlandaise',
    'Suisse',
    'Australienne',
    'Autre',
}

Config.ForbiddenNames = {
    admin = true,
    administrator = true,
    moderateur = true,
    moderator = true,
    staff = true,
    owner = true,
    console = true,
    nigger = true,
    nazi = true,
    hitler = true,
    fuck = true,
    shit = true,
    ass = true,
    dick = true,
    pussy = true,
    rape = true,
}

Config.Parents = {
    fathers = {
        { id = 0, label = 'Benjamin' },
        { id = 1, label = 'Daniel' },
        { id = 2, label = 'Joshua' },
        { id = 3, label = 'Noah' },
        { id = 4, label = 'Andrew' },
        { id = 5, label = 'Juan' },
        { id = 6, label = 'Alex' },
        { id = 7, label = 'Isaac' },
        { id = 8, label = 'Evan' },
        { id = 9, label = 'Ethan' },
        { id = 10, label = 'Vincent' },
        { id = 11, label = 'Angel' },
        { id = 12, label = 'Diego' },
        { id = 13, label = 'Adrian' },
        { id = 14, label = 'Gabriel' },
        { id = 15, label = 'Michael' },
        { id = 16, label = 'Santiago' },
        { id = 17, label = 'Kevin' },
        { id = 18, label = 'Louis' },
        { id = 19, label = 'Samuel' },
        { id = 20, label = 'Anthony' },
        { id = 42, label = 'Claude' },
        { id = 43, label = 'Niko' },
        { id = 44, label = 'John' },
    },
    mothers = {
        { id = 21, label = 'Hannah' },
        { id = 22, label = 'Audrey' },
        { id = 23, label = 'Jasmine' },
        { id = 24, label = 'Giselle' },
        { id = 25, label = 'Amelia' },
        { id = 26, label = 'Isabella' },
        { id = 27, label = 'Zoe' },
        { id = 28, label = 'Ava' },
        { id = 29, label = 'Camila' },
        { id = 30, label = 'Violet' },
        { id = 31, label = 'Sophia' },
        { id = 32, label = 'Evelyn' },
        { id = 33, label = 'Nicole' },
        { id = 34, label = 'Ashley' },
        { id = 35, label = 'Grace' },
        { id = 36, label = 'Brianna' },
        { id = 37, label = 'Natalie' },
        { id = 38, label = 'Olivia' },
        { id = 39, label = 'Elizabeth' },
        { id = 40, label = 'Charlotte' },
        { id = 41, label = 'Emma' },
        { id = 45, label = 'Misty' },
    },
}

Config.FaceFeatures = {
    noseWidth = 0,
    nosePeakHeight = 1,
    nosePeakLength = 2,
    noseBoneHeight = 3,
    nosePeakLowering = 4,
    noseBoneTwist = 5,
    eyebrowHeight = 6,
    eyebrowDepth = 7,
    cheekboneHeight = 8,
    cheekboneWidth = 9,
    cheeksWidth = 10,
    eyesOpening = 11,
    lipsThickness = 12,
    jawBoneWidth = 13,
    jawBoneLength = 14,
    chinBoneLowering = 15,
    chinBoneLength = 16,
    chinBoneWidth = 17,
    chinDimple = 18,
    neckThickness = 19,
}

Config.Overlays = {
    blemishes = 0,
    beard = 1,
    eyebrows = 2,
    ageing = 3,
    makeup = 4,
    blush = 5,
    complexion = 6,
    sunDamage = 7,
    lipstick = 8,
    moles = 9,
    chestHair = 10,
    bodyBlemishes = 11,
}

Config.OverlayColorType = {
    blemishes = 0,
    beard = 1,
    eyebrows = 1,
    ageing = 0,
    makeup = 2,
    blush = 2,
    complexion = 0,
    sunDamage = 0,
    lipstick = 2,
    moles = 0,
    chestHair = 1,
    bodyBlemishes = 0,
}

Config.Limits = {
    face = { min = -1.0, max = 1.0 },
    mix = { min = 0.0, max = 1.0 },
    opacity = { min = 0.0, max = 1.0 },
    parent = { min = 0, max = 45 },
    hairStyle = { min = 0, max = 80 },
    hairColor = { min = 0, max = 63 },
    overlayStyle = { min = 0, max = 90 },
    overlayColor = { min = 0, max = 63 },
    eyeColor = { min = 0, max = 31 },
    componentDrawable = { min = 0, max = 400 },
    componentTexture = { min = 0, max = 120 },
    propDrawable = { min = -1, max = 200 },
    propTexture = { min = -1, max = 120 },
}

Config.ClothingSlots = {
    { key = 'mask', label = 'Masque', type = 'component', id = 1 },
    { key = 'arms', label = 'Bras', type = 'component', id = 3 },
    { key = 'pants', label = 'Pantalon', type = 'component', id = 4 },
    { key = 'bags', label = 'Sacs', type = 'component', id = 5 },
    { key = 'shoes', label = 'Chaussures', type = 'component', id = 6 },
    { key = 'chains', label = 'Chaînes', type = 'component', id = 7 },
    { key = 'undershirt', label = 'Sous-vêtements', type = 'component', id = 8 },
    { key = 'vest', label = 'Veste', type = 'component', id = 9 },
    { key = 'decals', label = 'Accessoires', type = 'component', id = 10 },
    { key = 'tops', label = 'Haut', type = 'component', id = 11 },
}

Config.AccessorySlots = {
    { key = 'hat', label = 'Chapeau', type = 'prop', id = 0 },
    { key = 'glasses', label = 'Lunettes', type = 'prop', id = 1 },
    { key = 'ears', label = 'Oreilles', type = 'prop', id = 2 },
    { key = 'watches', label = 'Montres', type = 'prop', id = 6 },
    { key = 'bracelets', label = 'Bracelets', type = 'prop', id = 7 },
}

Config.DefaultClothing = {
    male = {
        components = {
            [1] = { drawable = 0, texture = 0 },
            [3] = { drawable = 15, texture = 0 },
            [4] = { drawable = 61, texture = 0 },
            [5] = { drawable = 0, texture = 0 },
            [6] = { drawable = 34, texture = 0 },
            [7] = { drawable = 0, texture = 0 },
            [8] = { drawable = 15, texture = 0 },
            [9] = { drawable = 0, texture = 0 },
            [10] = { drawable = 0, texture = 0 },
            [11] = { drawable = 15, texture = 0 },
        },
        props = {
            [0] = { drawable = -1, texture = -1 },
            [1] = { drawable = -1, texture = -1 },
            [2] = { drawable = -1, texture = -1 },
            [6] = { drawable = -1, texture = -1 },
            [7] = { drawable = -1, texture = -1 },
        },
    },
    female = {
        components = {
            [1] = { drawable = 0, texture = 0 },
            [3] = { drawable = 15, texture = 0 },
            [4] = { drawable = 15, texture = 3 },
            [5] = { drawable = 0, texture = 0 },
            [6] = { drawable = 35, texture = 0 },
            [7] = { drawable = 0, texture = 0 },
            [8] = { drawable = 14, texture = 0 },
            [9] = { drawable = 0, texture = 0 },
            [10] = { drawable = 0, texture = 0 },
            [11] = { drawable = 15, texture = 3 },
        },
        props = {
            [0] = { drawable = -1, texture = -1 },
            [1] = { drawable = -1, texture = -1 },
            [2] = { drawable = -1, texture = -1 },
            [6] = { drawable = -1, texture = -1 },
            [7] = { drawable = -1, texture = -1 },
        },
    },
}

Config.Cameras = {
    body = {
        offset = vec3(0.0, 2.6, 0.35),
        point = vec3(0.0, 0.0, 0.05),
        fov = 34.0,
        duration = 650,
    },
    face = {
        offset = vec3(0.0, 0.62, 0.68),
        point = vec3(0.0, 0.0, 0.65),
        fov = 28.0,
        duration = 520,
    },
    upper = {
        offset = vec3(0.0, 1.45, 0.38),
        point = vec3(0.0, 0.0, 0.22),
        fov = 32.0,
        duration = 560,
    },
    accessories = {
        offset = vec3(0.12, 0.78, 0.70),
        point = vec3(0.0, 0.0, 0.66),
        fov = 26.0,
        duration = 520,
    },
}

Config.CategoryCameras = {
    identity = 'body',
    heritage = 'face',
    face = 'face',
    hair = 'face',
    eyes = 'face',
    skin = 'face',
    makeup = 'face',
    clothing = 'upper',
    accessories = 'accessories',
}

Config.CategoryAnimations = {
    identity = 'default',
    heritage = 'face',
    face = 'face',
    hair = 'face',
    eyes = 'face',
    skin = 'face',
    makeup = 'face',
    clothing = 'clothing',
    accessories = 'accessories',
}

Config.Animations = {
    default = {
        dict = 'amb@world_human_hang_out_street@male_c@idle_a',
        anim = 'idle_b',
        flag = 1,
    },
    face = {
        dict = 'mp_sleep',
        anim = 'bind_pose_180',
        flag = 1,
    },
    clothing = {
        dict = 'anim@heists@heist_corona@team@male_a',
        anim = 'idle',
        flag = 1,
    },
    accessories = {
        dict = 'mp_move@prostitute@m@french',
        anim = 'idle',
        flag = 1,
    },
}

Config.Lights = {
    enabled = true,
    color = { 255, 236, 210 },
    range = 8.0,
    intensity = 1.8,
}

Config.Hooks = {
    -- Ne pas consommer ce hook : rCore Clothing l'écoute pour la création initiale.
    -- https://documentation.rcore.cz/paid-resources/rcore_clothing/integration/crm_multichar.md
    CreateFirstCharacter = false,
    -- L'apparence est gérée par rCore, pas par le studio interne.
    AutoOpenIfNoAppearance = false,
}

-- Événements / exports documentés de rCore Clothing uniquement.
-- Ne pas inventer d'autres noms. Si votre build diverge, vérifiez fxmanifest.lua de rcore_clothing.
Config.Rcore = {
    Resource = 'rcore_clothing',
    -- Méthode prévue pour la création initiale QB / Qbox.
    FirstCharacterEvent = 'qb-clothes:client:CreateFirstCharacter',
    -- Fin du créateur d'apparence.
    DoneEvent = 'rcore_clothing:charcreator:done',
    SaveSkinEvent = 'rcore_clothing:saveCurrentSkin',
    ReloadSkinServerEvent = 'rcore_clothing:reloadSkin',
    -- Si rcore_clothing n'est pas démarré, ouvrir le studio interne (désactivé par défaut).
    FallbackToInternalStudio = false,
}

-- Sélecteur multi-personnages calqué sur qbx-multicharacter.
-- Désactivez le multichar interne de qbx_core : useExternalCharacters = true
Config.Multichar = {
    Enabled = true,
    TakeOverSession = true,
    EnableDeleteButton = true,
    StartingApartment = true,
    DefaultNumberOfCharacters = 3,
    PlayersNumberOfCharacters = {
        -- ['license2:xxxxxxxx'] = 5,
    },
    DefaultSpawn = vec4(-540.58, -212.02, 37.65, 208.88),
    GiveStarterItems = true,
    -- L'apparence se fait dans rCore Clothing, pas dans le studio interne.
    UseCreatorStudio = false,
    IdentityOnly = true,
    Locations = {
        {
            PedCoords = vec4(969.25, 72.61, 116.18, 276.55),
            CamCoords = vec4(972.2, 72.9, 116.68, 97.27),
        },
        {
            PedCoords = vec4(1104.49, 195.9, -49.44, 44.22),
            CamCoords = vec4(1102.29, 198.14, -48.86, 225.07),
        },
        {
            PedCoords = vec4(-2163.87, 1134.51, -24.37, 310.05),
            CamCoords = vec4(-2161.7, 1136.4, -23.77, 131.52),
        },
        {
            PedCoords = vec4(-996.71, -68.07, -99.0, 57.61),
            CamCoords = vec4(-999.90, -66.30, -98.45, 241.68),
        },
        {
            PedCoords = vec4(-1023.45, -418.42, 67.66, 205.69),
            CamCoords = vec4(-1021.8, -421.7, 68.14, 27.11),
        },
        {
            PedCoords = vec4(2265.27, 2925.02, -84.8, 267.77),
            CamCoords = vec4(2268.24, 2925.02, -84.36, 90.88),
        },
    },
}

Config.Admin = {
    ace = 'admin',
    commandGroup = 'group.admin',
    qbxPermission = 'admin',
    allowSelfCommand = true,
}

Config.RateLimit = {
    saveMs = 2500,
    draftMs = 1500,
    openMs = 1000,
    resetMs = 3000,
    loadMs = 1500,
    deleteMs = 2500,
}

Config.HudEvents = {
    hide = {
        'qbx_hud:client:hideHud',
        'hud:client:hide',
    },
    show = {
        'qbx_hud:client:showHud',
        'hud:client:show',
    },
}

Config.CustomClothingApply = nil
Config.CustomClothingCollect = nil

Config.Categories = {
    'identity',
    'heritage',
    'face',
    'hair',
    'eyes',
    'skin',
    'makeup',
    'clothing',
    'accessories',
}

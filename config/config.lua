-- Config - main settings.

Config = {}

Config.Locale = 'en'
Config.Debug = false

Config.Quality = {
    SPOILED = 0,
    NORMAL = 1,
    PRIME  = 2,
}

Config.QualityMultiplier = {
    [0] = 0.35,
    [1] = 1.00,
    [2] = 1.80,
}

Config.QualityLabel = {
    [0] = 'Spoiled',
    [1] = 'Normal',
    [2] = 'Prime',
}

Config.QualityIconSuffix = {
    [0] = '_spoiled',
    [1] = '',
    [2] = '_prime',
}

Config.DisplayMetadata = {
    { quality = 'Quality' },
}

Config.SkillCheck = {
    engine = 'ox',

    duration = 3200,

    zoneWidth = 18,

    period = 1500,

    ox = {
        difficulty = { 'easy', 'easy' },
        inputs = { 'e', 'e' },
    },
}

Config.HarvestFlow = {
    checkpoints = { 25, 75 },

    qualityWeights = {
        [0] = { [0] = 100, [1] = 0,  [2] = 0 },
        [1] = { [0] = 15,  [1] = 65, [2] = 20 },
        [2] = { [0] = 2,   [1] = 40, [2] = 58 },
    },

    bonusChance = 0.08,

    bonusExtraItemChance = 0.5,
}

Config.CropPropModel = {
    tomato = 'prop_veg_crop_02',
    corn   = 'prop_bzzz_gardenpack_cornstalk001',
    apple  = 'prop_tree_birch_03',
    orange = 'prop_tree_maple_03',
}

Config.Placement = {
    noclipCommand = '',

    minSpacing = 0.5,
    maxSpacing = 25.0,
}

Config.Marker = {
    drawDistance = 3.0,
    interactRange = 1.0,
}

Config.Harvest = {
    duration = 3500,
    cooldown = 60000,
    requireSpace = true,
    targetRadius = 1.5,

    interactKey = 38,
    interactKeyLabel = 'E',

    spawnProps = true,

    spawnPerFrame = 8,

    renderDistance = 150.0,

    propCollision = false,

    treeCollision = true,

    anim = {
        dict = 'amb@world_human_gardener_plant@male@base',
        clip = 'base',
        flag = 1,
    },
    cropAnims = {
        apple = {
            dict = 'amb@prop_human_movie_bulb@idle_a',
            clip = 'idle_a',
            flag = 1,
        },
        orange = {
            dict = 'amb@prop_human_movie_bulb@idle_a',
            clip = 'idle_b',
            flag = 1,
        },
    },
    fallbackAnims = {
        {
            dict = 'amb@world_human_janitor@male@base',
            clip = 'base',
            flag = 1,
        },
        {
            dict = 'amb@world_human_hammering@male@base',
            clip = 'base',
            flag = 1,
        },
    },
}

Config.BlipOnRadar = true
Config.BlipRadarRange = 150.0

Config.Support = {
    discord = 'https://discord.gg/Gep3cg64q4',
    store = '',
}

Config.Progression = {
    enabled = true,

    thresholds = { 0, 50, 150, 400, 900, 1800, 3500, 6500, 12000, 20000 },

    bonuses = { 0, 0.009, 0.018, 0.027, 0.036, 0.044, 0.053, 0.062, 0.071, 0.08 },
}

Config.RequiredJobs = {}

Config.Admin = {
    command = 'farmadmin',

    groups = { 'admin', 'god', 'owner', 'superadmin', 'management' },

    -- ACE permissions: the first match wins.
    -- 'command' matches servers that grant `add_ace group.admin command allow`,
    -- which is the usual admin setup. Add your own ACE name here if needed.
    aces = { 'group.admin', 'command' },

    -- QA only: when true, everyone except the console is treated as a non-admin.
    -- Use it to test the normal-player flow; keep it false in a release.
    testDeny = false,
}

Config.Market = {
    interval = 300000,

    location = {
        coords = vector4(2008.56, 4732.16, 41.29, 24.0),
        model = 'a_m_m_farmer_01',
        fallbackModels = { 'a_m_m_farmer_02', 'a_m_m_business_01', 'a_m_m_bevhills_01' },
        label = 'Farm Market',
        radius = 3.5,
    },
}

Config.Economy = {
    baseSupplyRate = 100,

    minBaseline = 20,

    autoCalibrate = true,

    emaAlpha = 0.35,

    baselineBeta = 0.05,

    supplyElasticity = 0.45,

    responsiveness = 0.35,

    meanReversion = 0.04,

    idleThreshold = 3,

    idleReversion = 0.5,

    minIndex = 0.35,
    maxIndex = 2.50,

    epsilon = 1.0,

    impactDivisor = 50,
    antiDump = true,

    -- When enabled, the anti-dump impact also reduces the payout.
    antiDumpAffectsPayout = false,

    -- When enabled, synthetic flow counts as supply and moves the price index.
    simulationAffectsPrice = false,

    -- Fraction of market stock removed each tick (visual/analytic consistency).
    marketStockDecay = 0.02,

    dailySellCap = 0,

    dailyHarvestCap = 0,

    simulation = true,
    simulationRate = 12,
}

Config.Sounds = {
    enabled = true,
}

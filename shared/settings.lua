-- Shared - settings registry definitions.

SettingsRegistry = {
    ['market.interval'] = {
        path = { 'Market', 'interval' },
        type = 'number', min = 60000, max = 3600000, step = 60000, int = true,
        divisor = 60000,
        group = 'market', label = 'Price Update Interval', unit = 'min',
    },
    ['economy.dailySellCap'] = {
        path = { 'Economy', 'dailySellCap' },
        type = 'number', min = 0, max = 2000, step = 1, int = true,
        group = 'market', label = 'Daily Sell Cap', unit = 'units',
    },
    ['economy.dailyHarvestCap'] = {
        path = { 'Economy', 'dailyHarvestCap' },
        type = 'number', min = 0, max = 5000, step = 1, int = true,
        group = 'harvest', label = 'Daily Harvest Cap', unit = 'units',
    },
    ['economy.antiDump'] = {
        path = { 'Economy', 'antiDump' },
        type = 'bool', group = 'market', label = 'Anti-Dump Damping',
    },
    ['economy.antiDumpAffectsPayout'] = {
        path = { 'Economy', 'antiDumpAffectsPayout' },
        type = 'bool', group = 'market', label = 'Anti-Dump Affects Payout',
    },
    ['economy.autoCalibrate'] = {
        path = { 'Economy', 'autoCalibrate' },
        type = 'bool', group = 'market', label = 'Auto-Calibrate Baseline',
    },
    ['economy.baseSupplyRate'] = {
        path = { 'Economy', 'baseSupplyRate' },
        type = 'number', min = 1, max = 500, step = 1, int = true,
        group = 'market', label = 'Baseline Supply per Window', unit = 'units',
    },
    ['economy.simulationAffectsPrice'] = {
        path = { 'Economy', 'simulationAffectsPrice' },
        type = 'bool', group = 'market', label = 'Synthetic Flow Affects Price',
    },
    ['economy.stockDecay'] = {
        path = { 'Economy', 'marketStockDecay' },
        type = 'number', min = 0, max = 0.2, step = 0.01,
        group = 'market', label = 'Market Stock Decay', unit = 'x', advanced = true,
    },
    ['economy.impactDivisor'] = {
        path = { 'Economy', 'impactDivisor' },
        type = 'number', min = 10, max = 200, step = 5, int = true,
        group = 'market', label = 'Damping Strength', unit = 'x',
    },
    ['economy.simulation'] = {
        path = { 'Economy', 'simulation' },
        type = 'bool', group = 'market', label = 'Synthetic Market Flow',
    },
    ['economy.simulationRate'] = {
        path = { 'Economy', 'simulationRate' },
        type = 'number', min = 0, max = 100, step = 1, int = true,
        group = 'market', label = 'Synthetic Units / Tick', unit = 'units',
    },
    ['economy.minIndex'] = {
        path = { 'Economy', 'minIndex' },
        type = 'number', min = 0.1, max = 3.0, step = 0.05,
        group = 'market', label = 'Minimum Price Index', unit = 'x',
    },
    ['economy.maxIndex'] = {
        path = { 'Economy', 'maxIndex' },
        type = 'number', min = 0.1, max = 3.0, step = 0.05,
        group = 'market', label = 'Maximum Price Index', unit = 'x',
    },
    ['quality.spoiled'] = {
        path = { 'QualityMultiplier', 0 },
        type = 'number', min = 0.1, max = 3.0, step = 0.05,
        group = 'market', label = 'Spoiled Price Multiplier', unit = 'x',
    },
    ['quality.normal'] = {
        path = { 'QualityMultiplier', 1 },
        type = 'number', min = 0.1, max = 3.0, step = 0.05,
        group = 'market', label = 'Normal Price Multiplier', unit = 'x',
    },
    ['quality.prime'] = {
        path = { 'QualityMultiplier', 2 },
        type = 'number', min = 0.1, max = 3.0, step = 0.05,
        group = 'market', label = 'Prime Price Multiplier', unit = 'x',
    },

    ['economy.supplyElasticity'] = {
        path = { 'Economy', 'supplyElasticity' },
        type = 'number', min = 0, max = 2.0, step = 0.05,
        group = 'market', label = 'Supply Elasticity', advanced = true, caution = true,
    },
    ['economy.responsiveness'] = {
        path = { 'Economy', 'responsiveness' },
        type = 'number', min = 0, max = 1.0, step = 0.05,
        group = 'market', label = 'Responsiveness', advanced = true, caution = true,
    },
    ['economy.meanReversion'] = {
        path = { 'Economy', 'meanReversion' },
        type = 'number', min = 0, max = 0.5, step = 0.01,
        group = 'market', label = 'Mean Reversion', advanced = true, caution = true,
    },
    ['economy.emaAlpha'] = {
        path = { 'Economy', 'emaAlpha' },
        type = 'number', min = 0.01, max = 1.0, step = 0.01,
        group = 'market', label = 'Sell-Rate Smoothing', advanced = true, caution = true,
    },
    ['economy.baselineBeta'] = {
        path = { 'Economy', 'baselineBeta' },
        type = 'number', min = 0.01, max = 1.0, step = 0.01,
        group = 'market', label = 'Baseline Smoothing', advanced = true, caution = true,
    },
    ['economy.idleThreshold'] = {
        path = { 'Economy', 'idleThreshold' },
        type = 'number', min = 1, max = 20, step = 1, int = true,
        group = 'market', label = 'Idle Ticks Before Recovery', advanced = true, caution = true,
    },
    ['economy.idleReversion'] = {
        path = { 'Economy', 'idleReversion' },
        type = 'number', min = 0, max = 1.0, step = 0.05,
        group = 'market', label = 'Idle Recovery Speed', advanced = true, caution = true,
    },
    ['economy.epsilon'] = {
        path = { 'Economy', 'epsilon' },
        type = 'number', min = 0, max = 10, step = 0.5,
        group = 'market', label = 'No-Sale Threshold', advanced = true, caution = true,
    },

    ['harvest.duration'] = {
        path = { 'Harvest', 'duration' },
        type = 'number', min = 1500, max = 8000, step = 100, int = true,
        divisor = 1000,
        group = 'harvest', label = 'Harvest Duration', unit = 's',
    },
    ['harvest.cooldown'] = {
        path = { 'Harvest', 'cooldown' },
        type = 'number', min = 5000, max = 600000, step = 5000, int = true,
        divisor = 1000,
        group = 'harvest', label = 'Per-Plant Cooldown', unit = 's',
    },
    ['harvest.requireSpace'] = {
        path = { 'Harvest', 'requireSpace' },
        type = 'bool', group = 'harvest', label = 'Require Inventory Space',
    },
    ['harvest.targetRadius'] = {
        path = { 'Harvest', 'targetRadius' },
        type = 'number', min = 1.0, max = 5.0, step = 0.1,
        group = 'harvest', label = 'Interaction Radius', unit = 'm',
    },
    ['harvestflow.bonusChance'] = {
        path = { 'HarvestFlow', 'bonusChance' },
        type = 'number', min = 0, max = 0.5, step = 0.01,
        group = 'harvest', label = 'Rare Bonus Chance', unit = 'x',
    },
    ['harvestflow.bonusExtraItemChance'] = {
        path = { 'HarvestFlow', 'bonusExtraItemChance' },
        type = 'number', min = 0, max = 1.0, step = 0.05,
        group = 'harvest', label = 'Bonus = Extra Item Chance', unit = 'x',
    },

    ['skillcheck.duration'] = {
        path = { 'SkillCheck', 'duration' },
        type = 'number', min = 1000, max = 6000, step = 100, int = true,
        divisor = 1000,
        group = 'minigame', label = 'Timing Bar Duration', unit = 's',
    },
    ['skillcheck.zoneWidth'] = {
        path = { 'SkillCheck', 'zoneWidth' },
        type = 'number', min = 8, max = 40, step = 1, int = true,
        group = 'minigame', label = 'Hit Zone Width', unit = '%',
    },
    ['skillcheck.period'] = {
        path = { 'SkillCheck', 'period' },
        type = 'number', min = 800, max = 3000, step = 100, int = true,
        divisor = 1000,
        group = 'minigame', label = 'Needle Sweep Period', unit = 's',
    },

    ['market.radius'] = {
        path = { 'Market', 'location', 'radius' },
        type = 'number', min = 2.0, max = 10.0, step = 0.5,
        group = 'world', label = 'Market Interaction Radius', unit = 'm',
    },
    ['harvest.spawnProps'] = {
        path = { 'Harvest', 'spawnProps' },
        type = 'bool', group = 'world', label = 'Spawn Plant Props', restart = true,
    },
    ['harvest.propCollision'] = {
        path = { 'Harvest', 'propCollision' },
        type = 'bool', group = 'world', label = 'Plant Prop Collision', restart = true,
    },
    ['harvest.treeCollision'] = {
        path = { 'Harvest', 'treeCollision' },
        type = 'bool', group = 'world', label = 'Tree Collision (Apple / Orange)', restart = true,
    },
    ['harvest.renderDistance'] = {
        path = { 'Harvest', 'renderDistance' },
        type = 'number', min = 50, max = 500, step = 10, int = true,
        group = 'world', label = 'Prop Render Distance', unit = 'm',
    },
    ['blip.show'] = {
        path = { 'ShowBlips' },
        type = 'bool', group = 'world', label = 'Show Harvest Blips', restart = true,
    },
    ['blip.perNode'] = {
        path = { 'BlipPerNode' },
        type = 'bool', group = 'world', label = 'One Blip Per Node', restart = true,
    },
    ['blip.shortDistance'] = {
        path = { 'BlipShortDistance' },
        type = 'bool', group = 'world', label = 'Short-Range Blips Only', restart = true,
    },
    ['ui.locale'] = {
        path = { 'Locale' },
        type = 'enum', options = { 'en', 'tr', 'de', 'fr', 'it', 'es' },
        group = 'world', label = 'Interface Language',
        global = true,
    },

    ['skillcheck.engine'] = {
        path = { 'SkillCheck', 'engine' },
        type = 'enum', options = { 'custom', 'ox' },
        group = 'harvest', label = 'Skill Check Engine',
        global = true,
    },

    ['progression.enabled'] = {
        path = { 'Progression', 'enabled' },
        type = 'bool', group = 'progression', section = 'general', label = 'Progression Enabled',
    },
}

for level = 2, 10 do
    SettingsRegistry['progression.threshold.' .. level] = {
        path = { 'Progression', 'thresholds', level },
        type = 'number', min = 1, max = 1000000, step = 10, int = true,
        group = 'progression', section = 'threshold',
        label = ('Lv.%d Required Harvest'):format(level), unit = 'units',
    }

    SettingsRegistry['progression.bonus.' .. level] = {
        path = { 'Progression', 'bonuses', level },
        type = 'number', min = 0, max = 0.5, step = 0.001,
        divisor = 0.01,
        group = 'progression', section = 'bonus',
        label = ('Lv.%d Bonus'):format(level), unit = '%',
    }
end

for index, crop in ipairs(Config.Crops or {}) do
    SettingsRegistry['crop.' .. crop.key .. '.basePrice'] = {
        path = { 'Crops', index, 'basePrice' },
        type = 'number', min = 1, max = 5000, step = 1, int = true,
        group = 'market', label = ('%s Base Price'):format(crop.label), unit = '$',
    }
end

function ReadFarmSetting(path)
    local node = Config

    for i = 1, #path - 1 do
        node = node and node[path[i]]

        if not node then return nil end
    end

    return node and node[path[#path]]
end

function ApplyFarmSetting(key, value)
    local def = SettingsRegistry[key]

    if not def then return false end

    local node = Config

    for i = 1, #def.path - 1 do
        node = node and node[def.path[i]]

        if not node then return false end
    end

    node[def.path[#def.path]] = value

    return true
end

function ReadAllFarmSettings()
    local values = {}

    for key, def in pairs(SettingsRegistry) do
        values[key] = ReadFarmSetting(def.path)
    end

    return values
end

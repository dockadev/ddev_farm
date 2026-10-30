-- Server - player panel data and preferences.

FarmPanel = {}

local DEFAULT_PREFS = { levelUp = true, sounds = true }

local prefsCache = {}
local lastOpen = {}

function FarmPanel.Load()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS ddev_farm_prefs (
        identifier VARCHAR(64) NOT NULL PRIMARY KEY,
        level_up TINYINT NOT NULL DEFAULT 1,
        sounds TINYINT NOT NULL DEFAULT 1
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS ddev_farm_sales (
        id INT AUTO_INCREMENT PRIMARY KEY,
        identifier VARCHAR(64) NOT NULL,
        crop VARCHAR(32) NOT NULL,
        units INT NOT NULL,
        total INT NOT NULL,
        ts BIGINT NOT NULL,
        KEY idx_player (identifier, ts)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    print('^2[ddev_farm]^7 Player panel tables ready.')
end

function FarmPanel.GetPrefs(identifier)
    if not identifier then return { levelUp = DEFAULT_PREFS.levelUp, sounds = DEFAULT_PREFS.sounds } end

    local cached = prefsCache[identifier]
    if cached then return cached end

    local row = MySQL.single.await(
        'SELECT level_up, sounds FROM ddev_farm_prefs WHERE identifier = ?', { identifier })

    local prefs = {
        levelUp = (not row) or tonumber(row.level_up) == 1,
        sounds = (not row) or tonumber(row.sounds) == 1,
    }

    prefsCache[identifier] = prefs

    return prefs
end

function FarmPanel.SetPrefs(identifier, prefs)
    if not identifier or type(prefs) ~= 'table' then return end

    local levelUp = prefs.levelUp ~= false
    local sounds = prefs.sounds ~= false

    prefsCache[identifier] = { levelUp = levelUp, sounds = sounds }

    MySQL.update(
        'INSERT INTO ddev_farm_prefs (identifier, level_up, sounds) VALUES (?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE level_up = VALUES(level_up), sounds = VALUES(sounds)',
        { identifier, levelUp and 1 or 0, sounds and 1 or 0 }
    )
end

function FarmPanel.AddSale(identifier, crop, units, total)
    if not identifier or not crop then return end

    MySQL.insert(
        'INSERT INTO ddev_farm_sales (identifier, crop, units, total, ts) VALUES (?, ?, ?, ?, ?)',
        { identifier, crop, units, total, os.time() }
    )
end

function FarmPanel.GetRecentSales(identifier)
    if not identifier then return {} end

    local result = {}

    for _, crop in ipairs(Config.Crops) do
        local rows = MySQL.query.await(
            'SELECT FLOOR(ts / 3600) AS bucket, SUM(units) AS units, SUM(total) AS total, ' ..
            'COUNT(*) AS sales, MAX(ts) AS last_ts FROM ddev_farm_sales ' ..
            'WHERE identifier = ? AND crop = ? GROUP BY bucket ORDER BY last_ts DESC LIMIT 2',
            { identifier, crop.key }
        ) or {}

        if #rows > 0 then
            local entries = {}

            for _, row in ipairs(rows) do
                local units = tonumber(row.units) or 0
                local total = tonumber(row.total) or 0

                entries[#entries + 1] = {
                    units = units,
                    total = total,
                    unitPrice = units > 0 and math.floor(total / units + 0.5) or 0,
                    count = tonumber(row.sales) or 0,
                    ts = tonumber(row.last_ts) or 0,
                }
            end

            result[#result + 1] = {
                crop = crop.key,
                label = crop.label,
                entries = entries,
            }
        end
    end

    return result
end

function FarmPanel.GetTotals(identifier)
    if not identifier then return { units = 0, earned = 0 } end

    local row = MySQL.single.await(
        'SELECT COALESCE(SUM(units), 0) AS units, COALESCE(SUM(total), 0) AS earned ' ..
        'FROM ddev_farm_sales WHERE identifier = ?', { identifier })

    return {
        units = tonumber(row and row.units) or 0,
        earned = tonumber(row and row.earned) or 0,
    }
end

RegisterNetEvent('ddev_farm:openFarm', function()
    local source = source
    local now = GetGameTimer()

    if lastOpen[source] and (now - lastOpen[source]) < 1500 then return end
    lastOpen[source] = now

    CreateThread(function()
        local identifier = Bridge.GetIdentifier(source)
        if not identifier then return end

        local info = Progression.GetInfo(source)
        local totals = FarmPanel.GetTotals(identifier)
        local prefs = FarmPanel.GetPrefs(identifier)

        TriggerClientEvent('ddev_farm:farmData', source, {
            level = info.level,
            maxLevel = info.maxLevel,
            units = info.units,
            bonus = info.bonus,
            currentAt = info.currentAt,
            nextAt = info.nextAt,
            nextBonus = info.nextBonus,
            enabled = info.enabled,
            levels = Progression.GetLevels(),
            totals = totals,
            sales = FarmPanel.GetRecentSales(identifier),
            prefs = prefs,
            playerName = Bridge.GetName(source) or '',
        })
    end)
end)

RegisterNetEvent('ddev_farm:saveFarmPrefs', function(prefs)
    local source = source

    if type(prefs) ~= 'table' then return end

    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return end

    FarmPanel.SetPrefs(identifier, prefs)

    TriggerClientEvent('ddev_farm:prefs', source, FarmPanel.GetPrefs(identifier))
end)

AddEventHandler('playerDropped', function()
    local source = source

    prefsCache[Bridge.GetIdentifier(source) or ''] = nil
    lastOpen[source] = nil
end)

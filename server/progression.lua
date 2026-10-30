-- Server - player level and bargaining bonus.

Progression = {}

local cache = {}
local dirty = {}

function Progression.Load()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS ddev_farm_players (
        identifier VARCHAR(64) NOT NULL PRIMARY KEY,
        harvested INT NOT NULL DEFAULT 0,
        updated_at BIGINT NOT NULL DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end

local function GetUnits(identifier)
    if not identifier then return 0 end
    if cache[identifier] then return cache[identifier] end

    local row = MySQL.single.await(
        'SELECT harvested FROM ddev_farm_players WHERE identifier = ?', { identifier })

    local units = row and tonumber(row.harvested) or 0

    cache[identifier] = units

    return units
end

local function LevelFromUnits(units)
    local thresholds = Config.Progression.thresholds

    for i = #thresholds, 1, -1 do
        if units >= thresholds[i] then
            return i
        end
    end

    return 1
end

function Progression.GetInfo(source)
    local identifier = Bridge.GetIdentifier(source)
    local units = GetUnits(identifier)
    local level = LevelFromUnits(units)
    local thresholds = Config.Progression.thresholds
    local bonuses = Config.Progression.bonuses
    local maxLevel = #thresholds

    return {
        enabled = Config.Progression.enabled ~= false,
        level = level,
        maxLevel = maxLevel,
        units = units,
        bonus = bonuses[level] or 0,
        currentAt = thresholds[level] or 0,
        nextAt = thresholds[level + 1],
        nextBonus = bonuses[level + 1],
    }
end

function Progression.GetLevels()
    local list = {}

    for i = 1, #Config.Progression.thresholds do
        list[i] = {
            level = i,
            at = Config.Progression.thresholds[i],
            bonus = Config.Progression.bonuses[i] or 0,
        }
    end

    return list
end

function Progression.GetBonus(identifier)
    if Config.Progression.enabled == false then return 0 end
    if not identifier then return 0 end

    return Config.Progression.bonuses[LevelFromUnits(GetUnits(identifier))] or 0
end

function Progression.Add(identifier, units)
    if Config.Progression.enabled == false then return end
    if not identifier or not units or units < 1 then return end

    local before = GetUnits(identifier)
    local after = before + units

    cache[identifier] = after
    dirty[identifier] = true

    return LevelFromUnits(before), LevelFromUnits(after)
end

CreateThread(function()
    while true do
        Wait(60000)

        for identifier in pairs(dirty) do
            local units = cache[identifier]

            if units then
                MySQL.update(
                    'INSERT INTO ddev_farm_players (identifier, harvested, updated_at) VALUES (?, ?, ?) ' ..
                    'ON DUPLICATE KEY UPDATE harvested = VALUES(harvested), updated_at = VALUES(updated_at)',
                    { identifier, units, os.time() }
                )
            end
        end

        dirty = {}
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for identifier in pairs(dirty) do
        local units = cache[identifier]

        if units then
            MySQL.update.await(
                'INSERT INTO ddev_farm_players (identifier, harvested, updated_at) VALUES (?, ?, ?) ' ..
                'ON DUPLICATE KEY UPDATE harvested = VALUES(harvested), updated_at = VALUES(updated_at)',
                { identifier, units, os.time() }
            )
        end
    end
end)

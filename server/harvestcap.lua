-- Server - daily harvest cap.

HarvestCap = {}

local cache = {}

local function TodayUtc()
    return os.date('!%Y-%m-%d')
end

local function Ensure(identifier)
    local today = TodayUtc()
    local entry = cache[identifier]

    if entry and entry.day == today then
        return entry
    end

    entry = { day = today, units = 0, dirty = false }
    cache[identifier] = entry

    local row = MySQL.single.await(
        'SELECT units FROM ddev_farm_harvest_daily WHERE identifier = ? AND day = ?',
        { identifier, today }
    )

    if row then
        entry.units = tonumber(row.units) or 0
    end

    return entry
end

function HarvestCap.Enabled()
    return (Config.Economy.dailyHarvestCap or 0) > 0
end

function HarvestCap.Get(identifier)
    return Ensure(identifier).units
end

function HarvestCap.CanHarvest(identifier, units)
    local cap = Config.Economy.dailyHarvestCap or 0

    if cap <= 0 then return true end

    return Ensure(identifier).units + units <= cap
end

function HarvestCap.Add(identifier, units)
    if (Config.Economy.dailyHarvestCap or 0) <= 0 then return end

    local entry = Ensure(identifier)
    entry.units = entry.units + units
    entry.dirty = true
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `ddev_farm_harvest_daily` (
            `identifier` VARCHAR(64) NOT NULL,
            `day` VARCHAR(10) NOT NULL,
            `units` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`identifier`, `day`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    while true do
        Wait(60000)

        for identifier, entry in pairs(cache) do
            if entry.dirty then
                entry.dirty = false

                MySQL.insert(
                    'INSERT INTO ddev_farm_harvest_daily (identifier, day, units) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE units = ?',
                    { identifier, entry.day, entry.units, entry.units }
                )
            end
        end
    end
end)

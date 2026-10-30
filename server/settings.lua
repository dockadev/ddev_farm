-- Server - settings registry persistence.

Settings = {}

local overrides = {}
local defaults = {}

Settings.overrides = overrides
Settings.defaults = defaults

local function Coerce(def, value)
    if def.type == 'enum' then
        local text = tostring(value)

        for _, option in ipairs(def.options or {}) do
            if text == option then
                return option
            end
        end

        return nil
    end

    if def.type == 'bool' then
        if value == true or value == 1 or value == '1' or value == 'true' then
            return true
        end

        if value == false or value == 0 or value == '0' or value == 'false' then
            return false
        end

        return nil
    end

    local num = tonumber(value)

    if not num then return nil end

    if def.min and num < def.min then num = def.min end
    if def.max and num > def.max then num = def.max end
    if def.int then num = math.floor(num + 0.5) end

    return num
end

function Settings.Load()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS ddev_farm_settings (
        k VARCHAR(64) NOT NULL PRIMARY KEY,
        v TEXT NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    for key, def in pairs(SettingsRegistry) do
        defaults[key] = ReadFarmSetting(def.path)
    end

    local rows = MySQL.query.await('SELECT k, v FROM ddev_farm_settings') or {}
    local applied = 0

    for _, row in ipairs(rows) do
        local def = SettingsRegistry[row.k]

        if def then
            local ok, decoded = pcall(json.decode, row.v)
            local value = Coerce(def, ok and decoded or row.v)

            if value ~= nil then
                ApplyFarmSetting(row.k, value)
                overrides[row.k] = value
                applied = applied + 1
            end
        end
    end

    print(('^2[ddev_farm]^7 Settings loaded: %d override(s).'):format(applied))
end

function Settings.Set(key, value)
    local def = SettingsRegistry[key]

    if not def then return false, 'unknown_key' end

    local coerced = Coerce(def, value)

    if coerced == nil then return false, 'invalid_value' end

    ApplyFarmSetting(key, coerced)
    overrides[key] = coerced

    local cropKey = key:match('^crop%.(%w+)%.basePrice$')

    if cropKey then
        pcall(Market.SetBasePrice, cropKey, coerced)
    end

    MySQL.update.await(
        'INSERT INTO ddev_farm_settings (k, v) VALUES (?, ?) ON DUPLICATE KEY UPDATE v = VALUES(v)',
        { key, json.encode(coerced) }
    )

    return true, coerced
end

function Settings.Reset()
    MySQL.update.await('DELETE FROM ddev_farm_settings')

    for key, value in pairs(defaults) do
        ApplyFarmSetting(key, value)
    end

    overrides = {}
    Settings.overrides = overrides
end

function Settings.Values()
    return ReadAllFarmSettings()
end

function Settings.Snapshot()
    local list = {}

    for key, def in pairs(SettingsRegistry) do
        list[#list + 1] = {
            key = key,
            value = ReadFarmSetting(def.path),
            default = defaults[key],
            divisor = def.divisor or 1,
            type = def.type,
            options = def.options,
            min = def.min,
            max = def.max,
            step = def.step,
            group = def.group,
            section = def.section,
            label = def.label,
            unit = def.unit,
            restart = def.restart == true,
            advanced = def.advanced == true,
            caution = def.caution == true,
            global = def.global == true,
        }
    end

    table.sort(list, function(a, b)
        return a.key < b.key
    end)

    return list
end

function Settings.Broadcast(target)
    local values = Settings.Values()

    if target then
        TriggerClientEvent('ddev_farm:settings', target, values)
    else
        TriggerClientEvent('ddev_farm:settings', -1, values)
    end
end

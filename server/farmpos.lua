-- Server - /farmpos node recording and boot apply.

FarmPos = {}

local store = {}
local loaded = {}

local function FileName(crop)
    return ('farmpos_%s.lua'):format(crop)
end

local function LoadExisting(crop)
    if loaded[crop] then return end
    loaded[crop] = true

    local content = LoadResourceFile(GetCurrentResourceName(), FileName(crop))
    if not content then return end

    store[crop] = store[crop] or {}

    for x, y, z, h in content:gmatch(
        'vector3%(%s*([-%d%.]+)%s*,%s*([-%d%.]+)%s*,%s*([-%d%.]+)%s*%).-heading%s*=%s*([-%d%.]+)'
    ) do
        local px, py, pz = tonumber(x), tonumber(y), tonumber(z)

        if px and py and pz then
            store[crop][#store[crop] + 1] = {
                x = px,
                y = py,
                z = pz,
                h = tonumber(h) or 0.0,
            }
        end
    end
end

local function BuildContent(crop)
    local list = store[crop] or {}
    local model = Config.CropPropModel[crop] or 'MODEL'
    local lines = {}

    lines[#lines + 1] = ('-- ddev_farm | /farmpos %s'):format(crop)
    lines[#lines + 1] = ('-- Toplam %d nokta'):format(#list)
    lines[#lines + 1] = '-- Bu dosya otomatik olusturuldu; elle duzenleme.'
    lines[#lines + 1] = '-- Icerigi config/zones.lua icindeki ilgili bolgenin nodes listesine yapistir.'
    lines[#lines + 1] = ''

    for i, p in ipairs(list) do
        lines[#lines + 1] = ([[    { id = 'node_%s_%d', coords = vector3(%.2f, %.2f, %.2f), model = '%s', heading = %.1f, charges = 3 },]])
            :format(crop, i, p.x, p.y, p.z, model, p.h)
    end

    return table.concat(lines, '\n') .. '\n'
end

local function Save(crop)
    SaveResourceFile(GetCurrentResourceName(), FileName(crop), BuildContent(crop), -1)
end

function FarmPos.GetList(crop)
    LoadExisting(crop)

    return store[crop] or {}
end

function FarmPos.HasFile(crop)
    return LoadResourceFile(GetCurrentResourceName(), FileName(crop)) ~= nil
end

function FarmPos.Clear(crop)
    store[crop] = {}
    loaded[crop] = true

    SaveResourceFile(GetCurrentResourceName(), FileName(crop),
        ('-- ddev_farm | /farmpos %s\n-- Noktalar temizlendi.\n'):format(crop), -1)
end

local function IsDuplicate(list, coords)
    for _, p in ipairs(list) do
        if math.abs(p.x - coords.x) < 0.5 and math.abs(p.y - coords.y) < 0.5 then
            return true
        end
    end

    return false
end

RegisterNetEvent('ddev_farm:recordFarmPos', function(crop, coords, heading)
    local src = source

    if not RequireFarmAdmin(src) then return end

    if type(crop) ~= 'string' or not Config.CropMap[crop] then
        return
    end

    if type(coords) ~= 'table' or type(coords.x) ~= 'number' or type(coords.y) ~= 'number' then
        return
    end

    LoadExisting(crop)

    store[crop] = store[crop] or {}
    local list = store[crop]

    if IsDuplicate(list, coords) then
        TriggerClientEvent('ddev_farm:notify', src, ('This point is already saved: %s'):format(crop), 'error')
        return
    end

    list[#list + 1] = {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        h = tonumber(heading) or 0.0,
    }

    Save(crop)

    local model = Config.CropPropModel[crop] or 'MODEL'

    TriggerClientEvent('ddev_farm:notify', src, ('%s: %d points saved'):format(crop, #list), 'success')

    print(('[ddev_farm] farmpos %s -> %d points (%s)'):format(crop, #list, FileName(crop)))
end)

for _, zone in ipairs(Config.HarvestZones) do
    if FarmPos.HasFile(zone.crop) then
        local points = FarmPos.GetList(zone.crop)
        local model = Config.CropPropModel[zone.crop] or 'prop_bush_grape_01'
        local list = {}

        for i, p in ipairs(points) do
            list[i] = {
                id = ('node_%s_%d'):format(zone.crop, i),
                coords = vector3(p.x, p.y, p.z),
                model = model,
                heading = p.h,
                charges = 3,
            }
        end

        zone.nodes = list
    end
end

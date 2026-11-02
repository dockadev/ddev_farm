-- Client - map blips for harvest zones.

local blips = {}
local nodeBlips = {}
local blipCoords = {}

function DdevFarm.TrackBlip(handle, coords)
    if not handle or not coords then return end

    blipCoords[handle] = coords

    local alwaysOnRadar = Config.BlipOnRadar and not Config.BlipShortDistance
    SetBlipDisplay(handle, alwaysOnRadar and 2 or 3)
end

local function CreateBlip(coords, blip)
    if not coords then
        print('^1[ddev_farm]^7 Blip failed: missing coordinates')
        return nil
    end

    local handle = AddBlipForCoord(coords.x, coords.y, coords.z)
    if not handle or handle == 0 then
        print('^1[ddev_farm]^7 Blip failed: AddBlipForCoord returned no handle')
        return nil
    end

    SetBlipSprite(handle, blip.sprite or 846)
    SetBlipColour(handle, blip.color or 2)
    SetBlipScale(handle, blip.scale or 0.7)
    blipCoords[handle] = coords

    SetBlipDisplay(handle, (Config.BlipOnRadar and not Config.BlipShortDistance) and 2 or 3)
    SetBlipAsShortRange(handle, false)
    SetBlipPriority(handle, 1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(blip.label or 'Ciftlik')
    EndTextCommandSetBlipName(handle)

    return handle
end

function CreateZoneBlips(zones)
    RemoveBlips()

    for _, zone in ipairs(zones or {}) do
        if Config.BlipPerNode then
            for _, node in ipairs(zone.nodes or {}) do
                local handle = CreateBlip(node.coords, zone.blip)
                if handle then
                    blips[handle] = node.id
                    nodeBlips[node.id] = handle
                end
            end
        else
            local handle = CreateBlip(zone.blipCoords or (zone.nodes and zone.nodes[1] and zone.nodes[1].coords), zone.blip)
            if handle then
                blips[handle] = zone.id

                for _, node in ipairs(zone.nodes or {}) do
                    nodeBlips[node.id] = handle
                end
            end
        end
    end
end

function RemoveBlips()
    for handle in pairs(blips) do
        if DoesBlipExist(handle) then
            RemoveBlip(handle)
        end

        blipCoords[handle] = nil
    end

    blips = {}
    nodeBlips = {}
end

function SetNodeBlip(nodeId, hidden)
    local handle = nodeBlips[nodeId]
    if not handle then return end

    if hidden then
        if DoesBlipExist(handle) then
            SetBlipAsShortRange(handle, false)
            SetBlipAlpha(handle, 0)
        end
    else
        if DoesBlipExist(handle) then
            SetBlipAlpha(handle, 255)
        end
    end
end

RegisterNetEvent('ddev_farm:setupBlips', function(zones)
    if not Config.ShowBlips then
        print('^3[ddev_farm]^7 Blips disabled (Config.ShowBlips = false)')
        return
    end

    CreateZoneBlips(zones)

    local count = 0
    for _ in pairs(blips) do count = count + 1 end
end)

CreateThread(function()
    Wait(1000)

    if not Config.ShowBlips then
        print('^3[ddev_farm]^7 Blips disabled (Config.ShowBlips = false)')
        return
    end

    CreateZoneBlips(Config.HarvestZones)
end)

CreateThread(function()
    local shown = {}

    while true do
        Wait(1000)

        if Config.ShowBlips and Config.BlipOnRadar and Config.BlipShortDistance then
            local coords = GetEntityCoords(cache.ped)
            local range = Config.BlipRadarRange or 150.0
            local r2 = range * range

            for handle, c in pairs(blipCoords) do
                if DoesBlipExist(handle) then
                    local dx, dy, dz = coords.x - c.x, coords.y - c.y, coords.z - c.z
                    local near = (dx * dx + dy * dy + dz * dz) <= r2

                    if shown[handle] ~= near then
                        shown[handle] = near
                        SetBlipDisplay(handle, near and 2 or 3)
                    end
                end
            end
        end
    end
end)

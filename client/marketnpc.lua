-- Client - market NPC and blip.

local marketNpc = nil
local hintShown = false

local function LoadModelSafe(model, timeout)
    local hash = joaat(model)

    if not IsModelInCdimage(hash) then
        return nil
    end

    RequestModel(hash)

    local waited = 0

    while not HasModelLoaded(hash) do
        if waited >= (timeout or 3000) then
            SetModelAsNoLongerNeeded(hash)
            return nil
        end

        Wait(10)
        waited = waited + 10
    end

    return hash
end

local function LoadFirstModel(models)
    for _, name in ipairs(models or {}) do
        local hash = LoadModelSafe(name, 1500)

        if hash then
            return hash, name
        end
    end

    return nil
end

local function SpawnStaticPed(data)
    local hash, usedModel = LoadFirstModel({
        data.model,
        table.unpack(data.fallbackModels or {}),
    })

    if not hash then
        print(('^3[ddev_farm]^7 NPC model failed to load: %s'):format(tostring(data.model)))
        return nil
    end

    local c = data.coords
    local z = c.z

    local ped = CreatePed(4, hash, c.x, c.y, z, c.w or 0.0, false, true)

    SetModelAsNoLongerNeeded(hash)

    if not ped or ped == 0 then
        print(('^3[ddev_farm]^7 NPC could not be created: %s'):format(tostring(data.label)))
        return nil
    end

    SetEntityCoordsNoOffset(ped, c.x, c.y, z, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    return ped
end

local function CreateStaticBlip(coords, sprite, color, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    if not blip or blip == 0 then
        print(('^3[ddev_farm]^7 Blip failed: %s'):format(tostring(label)))
        return nil
    end

    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipScale(blip, 0.75)
    SetBlipDisplay(blip, (Config.BlipOnRadar and not Config.BlipShortDistance) and 2 or 3)
    SetBlipAsShortRange(blip, false)
    SetBlipPriority(blip, 1)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)

    if DdevFarm.TrackBlip then
        DdevFarm.TrackBlip(blip, coords)
    end

    return blip
end

CreateThread(function()
    Wait(1000)

    local market = Config.Market.location

    CreateStaticBlip(market.coords, 500, 5, market.label)

    marketNpc = SpawnStaticPed(market)
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) or DdevFarm.placing
            or NUI.IsMarketOpen() or NUI.IsAdminOpen() or NUI.IsFarmOpen()
            or NUI.IsToolsOpen() then
            if hintShown then
                hintShown = false
                NUI.HideHint()
            end

            Wait(500)
        else
            local c = Config.Market.location.coords
            local dist = #(GetEntityCoords(ped) - vector3(c.x, c.y, c.z))

            if dist <= (Config.Market.location.radius or 6.0) then
                if not hintShown then
                    hintShown = true

                    NUI.ShowHint({
                        label = 'Open',
                        key = Config.Harvest.interactKeyLabel or 'E',
                        header = Config.Market.location.label,
                    })
                end

                if IsControlJustPressed(0, Config.Harvest.interactKey or 38) then
                    hintShown = false
                    NUI.HideHint()

                    TriggerServerEvent('ddev_farm:openMarket')

                    Wait(500)
                else
                    Wait(0)
                end
            else
                if hintShown then
                    hintShown = false
                    NUI.HideHint()
                end

                Wait(400)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if marketNpc and DoesEntityExist(marketNpc) then
        DeleteEntity(marketNpc)
    end
end)

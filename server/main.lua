-- Server - bootstrap, sync and periodic tasks.

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(500)
    end

    while GetResourceState('ox_inventory') ~= 'started' do
        Wait(500)
    end

    Wait(1000)

    Settings.Load()

    Progression.Load()

    FarmPanel.Load()

    Market.Load()

    Farm.Load()

    Market.Start()

    TriggerClientEvent('ddev_farm:setupNodes', -1, Farm.GetNodeList())

    TriggerClientEvent('ddev_farm:setupBlips', -1, Farm.GetZones())

    Settings.Broadcast()

    print('^2[ddev_farm]^7 Ready.')
end)

local lastNodeRequest = {}

RegisterNetEvent('ddev_farm:requestNodes', function()
    local source = source
    local now = GetGameTimer()

    if lastNodeRequest[source] and (now - lastNodeRequest[source]) < 5000 then
        return
    end

    lastNodeRequest[source] = now

    TriggerClientEvent('ddev_farm:setupNodes', source, Farm.GetNodeList())
    TriggerClientEvent('ddev_farm:setupBlips', source, Farm.GetZones())
    Settings.Broadcast(source)
end)

AddEventHandler('playerJoining', function()
    local playerId = source
    local attempts = 0

    CreateThread(function()
        while attempts < 30 do
            if GetPlayerEndpoint(playerId) then
                TriggerClientEvent('ddev_farm:setupNodes', playerId, Farm.GetNodeList())
                TriggerClientEvent('ddev_farm:setupBlips', playerId, Farm.GetZones())
                Settings.Broadcast(playerId)
                return
            end
            attempts = attempts + 1
            Wait(1000)
        end
    end)
end)

AddEventHandler('ddev_farm:resyncNodes', function()
    TriggerClientEvent('ddev_farm:setupNodes', -1, Farm.GetNodeList())
end)

CreateThread(function()
    while true do
        Wait(60000)
        Farm.RefreshNodes()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Market.Save()
    end
end)

exports('GetPrice', function(cropKey)
    return Market.GetPrice(cropKey)
end)

exports('GetPriceTable', function()
    return Market.GetPriceTable()
end)

exports('Sell', function(source, cropKey, units)
    return Market.Sell(source, cropKey, units)
end)

exports('SetBasePrice', function(cropKey, price)
    return Market.SetBasePrice(cropKey, price)
end)

exports('ResetPrices', function()
    Market.ResetPrices()
end)

exports('RollQuality', function(cropKey, hits)
    local crop = Config.CropMap[cropKey]
    if not crop then return Config.Quality.NORMAL end
    return Farm.RollQualityFromHits(crop, hits or 0)
end)

exports('GetQualityLabel', function(quality)
    return Config.QualityLabel[quality] or 'Normal'
end)

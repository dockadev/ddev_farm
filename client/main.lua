-- Client - bootstrap, node data and admin utilities.

DdevFarm.nodes = {}

local dataReceived = false

RegisterNetEvent('ddev_farm:setupNodes', function(nodeList)
    DdevFarm.nodes = nodeList or {}
    dataReceived = true
end)
local function RequestFarmData()
    TriggerServerEvent('ddev_farm:requestNodes')
end

RegisterNetEvent('playerSpawned', function()
    DdevFarm.harvestBusy = false
    RequestFarmData()
end)

CreateThread(function()
    local attempts = 0
    while attempts < 30 and not dataReceived do
        if NetworkIsPlayerActive(PlayerId()) then
            RequestFarmData()
        end
        attempts = attempts + 1
        Wait(1000)
    end
end)

RegisterNetEvent('ddev_farm:nodeUpdate', function(nodeId, harvestable)
    for _, node in ipairs(DdevFarm.nodes) do
        if node.id == nodeId then
            node.harvestable = harvestable
            break
        end
    end

    if Config.BlipPerNode and SetNodeBlip then
        SetNodeBlip(nodeId, not harvestable)
    end
end)

RegisterNetEvent('ddev_farm:nodeCharges', function(nodeId, chargesLeft)
    for _, node in ipairs(DdevFarm.nodes) do
        if node.id == nodeId then
            node.chargesLeft = chargesLeft
            node.harvestable = chargesLeft > 0
            break
        end
    end
end)

RegisterNetEvent('ddev_farm:notify', function(message, notifyType)
    Bridge.Notify(message, notifyType)
end)

RegisterNetEvent('ddev_farm:sold', function(total)
    Sounds.Play('sale')
end)

RegisterNetEvent('ddev_farm:levelUp', function()
    Sounds.Play('levelUp')
end)
RegisterNetEvent('ddev_farm:priceUpdate', function(prices)
    if NUI and NUI.SetPrices then
        NUI.SetPrices(prices)
    end
end)
CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do
        Wait(500)
    end

    Wait(1000)

    if Config.DisplayMetadata and #Config.DisplayMetadata > 0 then
        exports.ox_inventory:displayMetadata(Config.DisplayMetadata)
    end
end)

RegisterNetEvent('ddev_farm:openMarket', function(prices, stock, progress)
    local focus = DdevFarm.marketFocus
    DdevFarm.marketFocus = nil

    if focus and NUI and NUI.SendSellCard then
        NUI.SendSellCard(prices, stock, progress, focus)
    elseif NUI and NUI.OpenMarket then
        NUI.OpenMarket(prices, stock, progress)
    end
end)

RegisterNetEvent('ddev_farm:marketPreview', function(prices, stock, progress)
    DdevFarm.marketPreview = {
        prices = prices,
        stock = stock,
        progress = progress,
    }

    if NUI and NUI.SendPreview then
        NUI.SendPreview(prices, stock, progress)
    end
end)

RegisterNetEvent('ddev_farm:refreshMarket', function(prices, stock, progress)
    if NUI and NUI.SetPrices then
        NUI.SetPrices(prices, stock, progress)
    end
end)

local function CropKeyList()
    local keys = {}
    for _, crop in ipairs(Config.Crops) do
        keys[#keys + 1] = crop.key
    end
    return table.concat(keys, ', ')
end

RegisterCommand('farmpos', function(_, args)
    local crop = args[1] and args[1]:lower()

    if not crop then
        print('^2[ddev_farm]^7 Usage: /farmpos <crop>')
        print(('  Crops: %s'):format(CropKeyList()))
        return
    end

    if not Config.CropMap[crop] then
        print(('^1[ddev_farm]^7 Unknown crop: %s'):format(crop))
        print(('  Valid: %s'):format(CropKeyList()))
        return
    end

    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    TriggerServerEvent('ddev_farm:recordFarmPos', crop, {
        x = coords.x,
        y = coords.y,
        z = coords.z,
    }, heading)

    local model = Config.CropPropModel[crop] or 'MODEL'
    print(('^2[ddev_farm]^7 %s node sent -> model: %s'):format(crop, model))
end, false)

TriggerEvent('chat:addSuggestion', '/farmpos', 'Save your current position as a harvest node', {
    { name = 'crop', help = 'Crop key: ' .. CropKeyList() },
})

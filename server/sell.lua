-- Server - selling, harvest completion and validation.

local function IsNearMarket(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end

    local c = Config.Market.location.coords
    local radius = Config.Market.location.radius or 6.0

    return #(GetEntityCoords(ped) - vector3(c.x, c.y, c.z)) <= radius
end

local function TooFast(store, source, intervalMs)
    local now = GetGameTimer()
    local last = store[source]

    if last and (now - last) < intervalMs then
        return true
    end

    store[source] = now

    return false
end

local lastMarketOpen = {}
local lastHarvestRequest = {}

local sellBuckets = {}

local function SellLimited(source)
    local now = GetGameTimer()
    local bucket = sellBuckets[source]

    if not bucket then
        bucket = { tokens = 6, last = now }
        sellBuckets[source] = bucket
    end

    bucket.tokens = math.min(6, bucket.tokens + (now - bucket.last) / 1000 * 6)
    bucket.last = now

    if bucket.tokens < 1 then
        return true
    end

    bucket.tokens = bucket.tokens - 1

    return false
end

local pendingHarvest = {}

AddEventHandler('playerDropped', function()
    local source = source

    lastMarketOpen[source] = nil
    lastHarvestRequest[source] = nil
    sellBuckets[source] = nil
    pendingHarvest[source] = nil
end)

RegisterNetEvent('ddev_farm:openMarket', function()
    local source = source

    if TooFast(lastMarketOpen, source, 2000) then return end

    CreateThread(function()
        if not IsNearMarket(source) then
            TriggerClientEvent('ddev_farm:notify', source, 'You must be at the market.', 'error')
            return
        end

        TriggerClientEvent('ddev_farm:openMarket', source,
            Market.GetPriceTable(), Market.GetPlayerStock(source), Progression.GetInfo(source))
    end)
end)

local function IsNearNode(source, node, tolerance)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end

    local playerCoords = GetEntityCoords(ped)
    local nodeCoords = node.coords

    if type(nodeCoords) == 'table' and nodeCoords.x then
        playerCoords = vector3(playerCoords.x, playerCoords.y, playerCoords.z)
        nodeCoords = vector3(nodeCoords.x, nodeCoords.y, nodeCoords.z)
    end

    return #(playerCoords - nodeCoords) <= (tolerance or 5.0)
end

RegisterNetEvent('ddev_farm:sell', function(cropKey, units, quality)
    local source = source

    if SellLimited(source) then return end

    if not IsNearMarket(source) then
        TriggerClientEvent('ddev_farm:notify', source, 'You must be at the market.', 'error')
        return
    end

    local success, result = Market.Sell(source, cropKey, units, quality)

    if not success then
        local message = ({
            invalid_crop = 'Invalid crop.',
            no_items = L('noItems'),
            market_not_ready = 'Market is not ready.',
            remove_failed = 'Could not take the items.',
            invalid_amount = 'Invalid amount.',
            no_player = 'Player not found.',
            daily_cap = 'Daily sell limit reached.',
            payment_failed = 'Payment failed.',
        })[result] or 'Sale failed.'

        TriggerClientEvent('ddev_farm:notify', source, message, 'error')
        return
    end

    local crop = Config.CropMap[cropKey]
    TriggerClientEvent('ddev_farm:notify', source, L('sold', crop.label, result), 'success')
    TriggerClientEvent('ddev_farm:sold', source, result, cropKey, units)

    local identifier = Bridge.GetIdentifier(source)

    if identifier then
        FarmPanel.AddSale(identifier, cropKey, units, result)
    end

    TriggerClientEvent('ddev_farm:refreshMarket', source,
        Market.GetPriceTable(), Market.GetPlayerStock(source), Progression.GetInfo(source))
end)

RegisterNetEvent('ddev_farm:requestHarvest', function(nodeId, branchIndex)
    local source = source

    if TooFast(lastHarvestRequest, source, 500) then return end

    local active = pendingHarvest[source]
    local timeout = (Config.Harvest.duration or 3500) + 15000

    if active and (GetGameTimer() - active.started) < timeout then
        return
    end

    if not Farm.IsHarvestable(nodeId) then
        TriggerClientEvent('ddev_farm:notify', source, L('notReady'), 'error')
        return
    end

    if not Farm.HasJob(source) then
        TriggerClientEvent('ddev_farm:notify', source, L('notYourJob'), 'error')
        return
    end

    if Farm.IsOnCooldown(source, nodeId) then
        TriggerClientEvent('ddev_farm:notify', source, L('onCooldown'), 'error')
        return
    end

    local node = Farm.GetNode(nodeId)
    if not node then
        TriggerClientEvent('ddev_farm:notify', source, 'Harvest node not found.', 'error')
        return
    end

    if not IsNearNode(source, node, 5.0) then
        TriggerClientEvent('ddev_farm:notify', source, L('tooClose'), 'error')
        return
    end

    local crop = Config.CropMap[Farm.GetNodeCrop(nodeId)]
    if not crop then
        TriggerClientEvent('ddev_farm:notify', source, 'Harvest node not found.', 'error')
        return
    end

    if Config.Harvest.requireSpace then
        if not exports.ox_inventory:CanCarryItem(source, crop.key, 1) then
            TriggerClientEvent('ddev_farm:notify', source, L('inventoryFull'), 'error')
            return
        end
    end

    pendingHarvest[source] = {
        nodeId = nodeId,
        started = GetGameTimer(),
        duration = Config.Harvest.duration or 3500,
    }

    TriggerClientEvent('ddev_farm:doHarvest', source, nodeId, branchIndex or 0)
end)

RegisterNetEvent('ddev_farm:harvestCanceled', function(nodeId)
    local source = source
    local pending = pendingHarvest[source]

    if pending and pending.nodeId == nodeId then
        pendingHarvest[source] = nil
    end
end)

RegisterNetEvent('ddev_farm:completeHarvest', function(nodeId, branchIndex, tier1, tier2)
    local source = source

    local pending = pendingHarvest[source]

    if not pending or pending.nodeId ~= nodeId then
        return
    end

    pendingHarvest[source] = nil

    local elapsed = GetGameTimer() - (pending.started or 0)
    local required = (pending.duration or 3500) - 250

    if elapsed < required then
        if Config.Debug then
            print(('[ddev_farm] erken completeHarvest: %d ms / %d ms'):format(elapsed, required))
        end

        return
    end

    if not Farm.HasJob(source) then
        TriggerClientEvent('ddev_farm:notify', source, L('notYourJob'), 'error')
        return
    end

    if not Farm.IsHarvestable(nodeId) then
        TriggerClientEvent('ddev_farm:notify', source, L('notReady'), 'error')
        return
    end

    local node = Farm.GetNode(nodeId)
    if not node or not IsNearNode(source, node, 6.0) then
        TriggerClientEvent('ddev_farm:notify', source, L('tooClose'), 'error')
        return
    end

    local cropKey = Farm.GetNodeCrop(nodeId)
    local crop = Config.CropMap[cropKey]
    if not crop then return end

    local function NormalizeTier(tier)
        if tier == 'perfect' or tier == 'good' then
            return tier
        end
        return 'miss'
    end

    tier1 = NormalizeTier(tier1)
    tier2 = NormalizeTier(tier2)

    local hits = 0
    if tier1 ~= 'miss' then hits = hits + 1 end
    if tier2 ~= 'miss' then hits = hits + 1 end

    local quality = Farm.RollQualityFromHits(crop, hits)

    local count = math.random(crop.yield.min, crop.yield.max)
    local bonus = nil

    if hits == 2 and math.random() < Config.HarvestFlow.bonusChance then
        if math.random() < Config.HarvestFlow.bonusExtraItemChance then
            count = count + 1
            bonus = 'extra'
        elseif quality < Config.Quality.PRIME then
            quality = quality + 1
            bonus = 'upgrade'
        end
    end

    local identifier = Bridge.GetIdentifier(source)

    if identifier and not HarvestCap.CanHarvest(identifier, count) then
        TriggerClientEvent('ddev_farm:notify', source, L('harvestCap'), 'error')
        return
    end

    if not exports.ox_inventory:CanCarryItem(source, crop.key, count) then
        count = exports.ox_inventory:CanCarryAmount(source, crop.key)
        if not count or count < 1 then
            TriggerClientEvent('ddev_farm:notify', source, L('inventoryFull'), 'error')
            return
        end
    end

    local metadata = Farm.BuildMetadata(crop, quality)
    local added = exports.ox_inventory:AddItem(source, crop.key, count, metadata)

    if not added then
        TriggerClientEvent('ddev_farm:notify', source, L('inventoryFull'), 'error')
        return
    end

    Farm.ConsumeNode(nodeId, identifier)

    if identifier then
        HarvestCap.Add(identifier, count)
    end

    if identifier then
        local beforeLevel, afterLevel = Progression.Add(identifier, count)

        if beforeLevel and afterLevel and afterLevel > beforeLevel then
            local info = Progression.GetInfo(source)
            local bonusPct = math.floor((info.bonus or 0) * 1000 + 0.5) / 10
            local prefs = FarmPanel.GetPrefs(identifier)

            TriggerClientEvent('ddev_farm:levelUp', source)

            if prefs.levelUp ~= false then
                TriggerClientEvent('ddev_farm:notify', source,
                    ('Level %d! Price bonus +%.1f%%'):format(info.level, bonusPct), 'success')
            end
        end
    end

    if not Farm.IsHarvestable(nodeId) then
        Farm.SetCooldown(source, nodeId)
        TriggerClientEvent('ddev_farm:nodeUpdate', -1, nodeId, false)
    end

    TriggerClientEvent('ddev_farm:harvestResult', source, quality, count, bonus)

    local qualityLabel = Config.QualityLabel[quality] or 'Normal'
    TriggerClientEvent('ddev_farm:notify', source,
        ('%s (%s) x%d'):format(crop.label, qualityLabel, count), 'success')
end)

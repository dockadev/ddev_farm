-- Server - live market economy.

Market = {}
Market.__index = Market

local state = {}
local salesThisWindow = {}
local playerSalesThisWindow = {}
local busy = false
local nextTick = 0

local function clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function Market.Calculate(crop, sold, bought, simulated)
    local st = state[crop.key]
    if not st then return 1.0, crop.basePrice end

    local eco = Config.Economy

    st.soldEma = st.soldEma + eco.emaAlpha * (sold - st.soldEma)

    local baseline
    if eco.autoCalibrate then
        st.baselineEma = st.baselineEma + eco.baselineBeta * (st.soldEma - st.baselineEma)
        if st.baselineEma < eco.minBaseline then
            st.baselineEma = eco.minBaseline
        end
        baseline = st.baselineEma
    else
        baseline = eco.baseSupplyRate
    end

    st.marketStock = st.marketStock + (sold - bought) + (simulated or 0)
    if st.marketStock < 0 then st.marketStock = 0 end

    if sold > 0 then
        st.idleTicks = 0
    else
        st.idleTicks = (st.idleTicks or 0) + 1
    end

    local targetIndex
    if st.idleTicks >= eco.idleThreshold then
        targetIndex = 1.0
    elseif st.soldEma < eco.epsilon then
        targetIndex = 1.0
    else
        local ratio = baseline / st.soldEma
        if ratio < 0.0001 then ratio = 0.0001 end
        targetIndex = clamp(
            ratio ^ eco.supplyElasticity,
            eco.minIndex,
            eco.maxIndex
        )
    end

    st.priceIndex = st.priceIndex + (targetIndex - st.priceIndex) * eco.responsiveness

    if st.idleTicks >= eco.idleThreshold then
        st.priceIndex = st.priceIndex + (1.0 - st.priceIndex) * eco.idleReversion
    else
        st.priceIndex = st.priceIndex + (1.0 - st.priceIndex) * eco.meanReversion
    end

    st.priceIndex = clamp(st.priceIndex, eco.minIndex, eco.maxIndex)

    local price = math.floor(crop.basePrice * st.priceIndex + 0.5)
    if price < 1 then price = 1 end

    st.price = price

    return st.priceIndex, price
end

function Market.Tick()
    local results = {}

    for _, crop in ipairs(Config.Crops) do
        local st = state[crop.key]
        if st then
            local sold = salesThisWindow[crop.key] or 0
            local bought = 0

            local simulated = 0
            if Config.Economy.simulation and Config.Economy.simulationRate > 0 then
                simulated = math.random(0, Config.Economy.simulationRate)
            end

            local oldPrice = st.price
            local index, price = Market.Calculate(crop, sold, bought, simulated)

            st.price = price
            st.lastTick = os.time()

            MySQL.insert(
                'INSERT INTO ddev_market_log (crop, kind, units, quality_weight, unit_price, ts) VALUES (?, ?, ?, ?, ?, ?)',
                { crop.key, 'tick', 0, 0, price, os.time() }
            )

            local change = 0
            if oldPrice and oldPrice > 0 then
                change = ((price - oldPrice) / oldPrice) * 100
            end

            st.previousPrice = oldPrice or price
            st.changePct = change

            results[crop.key] = {
                crop = crop.key,
                label = crop.label,
                price = price,
                oldPrice = oldPrice,
                change = change,
                index = index,
                sold = sold,
                stock = st.marketStock,
            }

            if Config.Discord and Config.Discord.enabled and Config.Discord.webhook ~= ''
                and math.abs(change) >= (Config.Discord.minChange or 3) then
                Market.SendDiscord(crop, change, oldPrice, price)
            end
        end
    end

    salesThisWindow = {}
    playerSalesThisWindow = {}

    return results
end

function Market.SendDiscord(crop, change, oldPrice, newPrice)
    local direction = change > 0 and '📈' or '📉'
    local embeds = {
        {
            title = 'Market Price Changed',
            description = ('%s **%s** fiyati %s%% -> **%s** ($%s)'):format(
                direction, crop.label, math.floor(change), newPrice, oldPrice),
            color = change > 0 and 3066993 or 15158332,
            footer = { text = 'ddev_farm' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        }
    }

    PerformHttpRequest(Config.Discord.webhook, function(err, text, headers) end,
        'POST', json.encode({ embeds = embeds }), { ['Content-Type'] = 'application/json' })
end

local function CountQuality(source, cropKey, quality)
    local metadata = { crop = cropKey, quality = quality }

    return exports.ox_inventory:GetItemCount(source, cropKey, metadata, false) or 0
end

function Market.Sell(source, cropKey, units, qualityFilter)
    local crop = Config.CropMap[cropKey]
    if not crop then return false, 'invalid_crop' end

    local st = state[cropKey]
    if not st then return false, 'market_not_ready' end

    units = tonumber(units)

    if not units or units ~= units or units == math.huge or units == -math.huge then
        return false, 'invalid_amount'
    end

    units = math.floor(units)
    if units < 1 then return false, 'invalid_amount' end

    local playerId = Bridge.GetIdentifier(source)
    if not playerId then return false, 'no_player' end

    local quality = Market.GetSellableQuality(source, cropKey, units, qualityFilter)
    if not quality then return false, 'no_items' end

    local count = quality.count
    if count < units then units = count end
    if units < 1 then return false, 'no_items' end

    local unitPrice = Market.GetUnitPrice(cropKey, quality.quality)
    local negotiation = Progression and Progression.GetBonus(playerId) or 0
    local effectivePrice = unitPrice * (1 + negotiation)
    local total = math.floor(effectivePrice * units + 0.5)

    if Config.Economy.dailySellCap > 0 then
        local soldToday = Market.GetDailySold(playerId, cropKey)
        if soldToday + units > Config.Economy.dailySellCap then
            return false, 'daily_cap'
        end
    end

    local impact = 1.0
    if Config.Economy.antiDump then
        local sold = playerSalesThisWindow[playerId] or 0
        impact = 1 / (1 + sold / Config.Economy.impactDivisor)
    end

    if total > 0 and not Bridge.AddMoney(source, 'money', total, 'pazar satisi: ' .. crop.label) then
        if Config.Debug then
            print(('^1[ddev_farm]^7 Odeme basarisiz: src=%s tutar=%d'):format(source, total))
        end

        return false, 'payment_failed'
    end

    local removed = 0

    if exports.ox_inventory:RemoveItem(source, cropKey, units, quality.metadata, nil, false, false) then
        removed = units
    end

    if removed < units then
        local refund = math.floor(effectivePrice * (units - removed))

        if refund > 0 then
            Bridge.RemoveMoney(source, 'money', refund, 'pazar satisi iptali: urun kaldirilamadi')
        end

        return false, 'remove_failed'
    end

    local effective = units * (quality.qualityWeight or 1) * impact
    salesThisWindow[cropKey] = (salesThisWindow[cropKey] or 0) + effective
    playerSalesThisWindow[playerId] = (playerSalesThisWindow[playerId] or 0) + units

    Market.AddDailySold(playerId, cropKey, units)

    MySQL.insert(
        'INSERT INTO ddev_market_log (crop, kind, units, quality_weight, unit_price, ts) VALUES (?, ?, ?, ?, ?, ?)',
        { cropKey, 'sell', units, quality.qualityWeight or 1, unitPrice, os.time() }
    )

    return true, total
end

local dailyCache = {}

local function TodayUtc()
    return os.date('!%Y-%m-%d')
end

local function EnsureDaily(playerId)
    local today = TodayUtc()
    local entry = dailyCache[playerId]

    if entry and entry.day == today then
        return entry
    end

    entry = { day = today, crops = {}, dirty = false }
    dailyCache[playerId] = entry

    local rows = MySQL.query.await(
        'SELECT crop, units FROM ddev_market_daily WHERE player_id = ? AND day = ?',
        { playerId, today }
    ) or {}

    for _, row in ipairs(rows) do
        entry.crops[row.crop] = tonumber(row.units) or 0
    end

    return entry
end

function Market.GetDailySold(playerId, cropKey)
    local entry = EnsureDaily(playerId)
    return entry.crops[cropKey] or 0
end

function Market.AddDailySold(playerId, cropKey, units)
    local entry = EnsureDaily(playerId)
    entry.crops[cropKey] = (entry.crops[cropKey] or 0) + units
    entry.dirty = true
end

CreateThread(function()
    while true do
        Wait(60000)

        for playerId, entry in pairs(dailyCache) do
            if entry.dirty then
                entry.dirty = false

                for crop, units in pairs(entry.crops) do
                    MySQL.insert(
                        'INSERT INTO ddev_market_daily (player_id, crop, units, day) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE units = ?',
                        { playerId, crop, units, entry.day, units }
                    )
                end
            end
        end
    end
end)

function Market.GetSellableQuality(source, cropKey, wanted, qualityFilter)
    local best = nil
    local bestWeight = -1

    local from, to = 2, 0

    local filter = tonumber(qualityFilter)
    if filter and filter >= 0 and filter <= 2 then
        from = math.floor(filter)
        to = from
    end

    for quality = from, to, -1 do
        local count = CountQuality(source, cropKey, quality)

        if count > 0 then
            local weight = Config.QualityMultiplier[quality] or 1
            if weight > bestWeight then
                bestWeight = weight
                best = {
                    quality = quality,
                    count = count,
                    metadata = { crop = cropKey, quality = quality },
                    qualityWeight = weight,
                }
                if wanted and count >= wanted then break end
            end
        end
    end

    return best
end

function Market.GetUnitPrice(cropKey, quality)
    local crop = Config.CropMap[cropKey]
    local st = state[cropKey]
    if not crop or not st then return 0 end

    local multiplier = Config.QualityMultiplier[quality] or 1
    local price = math.floor(st.price * multiplier + 0.5)
    if price < 1 then price = 1 end

    return price
end

function Market.GetPrice(cropKey)
    local st = state[cropKey]
    if not st then return 0 end
    return st.price
end

function Market.GetPriceTable()
    local table_ = {}
    for _, crop in ipairs(Config.Crops) do
        local st = state[crop.key]
        if st then
            table_[crop.key] = {
                label = crop.label,
                icon = crop.icon,
                price = st.price,
                previousPrice = st.previousPrice or st.price,
                change = st.changePct or 0,
                basePrice = crop.basePrice,
                index = st.priceIndex,
                stock = st.marketStock,
                qualityPrices = {
                    ['0'] = Market.GetUnitPrice(crop.key, 0),
                    ['1'] = Market.GetUnitPrice(crop.key, 1),
                    ['2'] = Market.GetUnitPrice(crop.key, 2),
                },
            }
        end
    end
    return table_
end

function Market.GetPlayerStock(source)
    local stock = {}

    for _, crop in ipairs(Config.Crops) do
        local total = 0
        local broken, normal, good = 0, 0, 0

        for quality = 0, 2 do
            local count = CountQuality(source, crop.key, quality)

            total = total + count

            if quality == 0 then broken = count
            elseif quality == 1 then normal = count
            else good = count end
        end

        if total > 0 then
            stock[crop.key] = {
                total = total,
                broken = broken,
                normal = normal,
                good = good,
            }
        end
    end

    return stock
end

function Market.GetStatus()
    local status = {}
    for _, crop in ipairs(Config.Crops) do
        local st = state[crop.key]
        if st then
            status[crop.key] = {
                label = crop.label,
                price = st.price,
                basePrice = crop.basePrice,
                index = st.priceIndex,
                soldEma = st.soldEma,
                baselineEma = st.baselineEma,
                marketStock = st.marketStock,
            }
        end
    end
    return status
end

function Market.SetBasePrice(cropKey, price)
    local crop = Config.CropMap[cropKey]
    local st = state[cropKey]
    if not crop or not st then return false end

    st.basePrice = price
    crop.basePrice = price

    MySQL.update.await(
        'UPDATE ddev_market SET base_price = ? WHERE crop = ?',
        { price, cropKey }
    )

    return true
end

function Market.ResetState()
    for _, crop in ipairs(Config.Crops) do
        local st = state[crop.key]
        if st then
            st.priceIndex = 1.0
            st.soldEma = 0
            st.baselineEma = Config.Economy.minBaseline
            st.marketStock = 0
            st.price = crop.basePrice
            st.idleTicks = 0
        end
    end
end

function Market.ResetPrices()
    Market.ResetState()
end

function Market.SimulateSale(cropKey, units)
    local crop = Config.CropMap[cropKey]
    if not crop then return false end

    units = tonumber(units) or 100
    salesThisWindow[cropKey] = (salesThisWindow[cropKey] or 0) + units

    return true
end

function Market.Load()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `ddev_market` (
            `crop` VARCHAR(32) NOT NULL PRIMARY KEY,
            `base_price` INT NOT NULL DEFAULT 0,
            `price_index` FLOAT NOT NULL DEFAULT 1.0,
            `sold_ema` FLOAT NOT NULL DEFAULT 0,
            `baseline_ema` FLOAT NOT NULL DEFAULT 0,
            `market_stock` FLOAT NOT NULL DEFAULT 0,
            `last_tick` BIGINT NOT NULL DEFAULT 0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `ddev_market_log` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `crop` VARCHAR(32) NOT NULL,
            `kind` ENUM('sell','buy','tick') NOT NULL,
            `units` INT NOT NULL DEFAULT 0,
            `quality_weight` FLOAT NOT NULL DEFAULT 1,
            `unit_price` INT NOT NULL DEFAULT 0,
            `ts` BIGINT NOT NULL,
            KEY `idx_crop_ts` (`crop`, `ts`),
            KEY `idx_ts` (`ts`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `ddev_market_daily` (
            `player_id` VARCHAR(64) NOT NULL,
            `crop` VARCHAR(32) NOT NULL,
            `day` VARCHAR(10) NOT NULL,
            `units` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`player_id`, `crop`, `day`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    for _, crop in ipairs(Config.Crops) do
        local row = MySQL.single.await(
            'SELECT * FROM ddev_market WHERE crop = ?', { crop.key })

        if not row then
            MySQL.insert.await(
                'INSERT INTO ddev_market (crop, base_price, price_index, sold_ema, baseline_ema, market_stock, last_tick) VALUES (?, ?, ?, ?, ?, ?, ?)',
                { crop.key, crop.basePrice, 1.0, 0, Config.Economy.minBaseline, 0, 0 }
            )
            row = { base_price = crop.basePrice, price_index = 1.0, sold_ema = 0,
                    baseline_ema = Config.Economy.minBaseline, market_stock = 0 }
        end

        local baselineEma = tonumber(row.baseline_ema) or 0
        if baselineEma < Config.Economy.minBaseline then
            baselineEma = Config.Economy.minBaseline
        end

        state[crop.key] = {
            basePrice = crop.basePrice,
            priceIndex = tonumber(row.price_index) or 1.0,
            soldEma = tonumber(row.sold_ema) or 0,
            baselineEma = baselineEma,
            marketStock = tonumber(row.market_stock) or 0,
            price = math.floor(crop.basePrice * (tonumber(row.price_index) or 1.0) + 0.5),
            lastTick = tonumber(row.last_tick) or 0,
            idleTicks = 0,
        }
    end

    print(('^2[ddev_farm]^7 Market loaded - %d crops'):format(#Config.Crops))
end

function Market.Save()
    for cropKey, st in pairs(state) do
        MySQL.update.await(
            'UPDATE ddev_market SET base_price = ?, price_index = ?, sold_ema = ?, baseline_ema = ?, market_stock = ?, last_tick = ? WHERE crop = ?',
            { st.basePrice, st.priceIndex, st.soldEma, st.baselineEma, st.marketStock, st.lastTick or os.time(), cropKey }
        )
    end
end

function Market.Start()
    Citizen.CreateThread(function()
        Wait(2000)
        Market.Tick()
        Market.Save()

        while true do
            local waited = 0

            while waited < Config.Market.interval do
                Wait(1000)
                waited = waited + 1000
            end

            if not busy then
                busy = true
                local ok, err = pcall(function()
                    local results = Market.Tick()
                    Market.Save()
                    TriggerClientEvent('ddev_farm:priceUpdate', -1, Market.GetPriceTable())
                end)
                busy = false
                if not ok then
                    print(('^1[ddev_farm]^7 Market tick error: %s'):format(err))
                end
            end
        end
    end)
end

return Market

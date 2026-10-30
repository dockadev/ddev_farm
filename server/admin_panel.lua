-- Server - admin panel settings and actions.

RegisterCommand(Config.Admin.command or 'farmadmin', function(source)
    if source == 0 then
        print('This command is used in-game.')
        return
    end

    if not RequireFarmAdmin(source) then return end

    TriggerClientEvent('ddev_farm:adminOpen', source, Settings.Snapshot())
end, false)

RegisterNetEvent('ddev_farm:adminSave', function(values)
    local src = source

    if not RequireFarmAdmin(src) then return end
    if type(values) ~= 'table' then return end

    local name = Bridge.GetName(src) or tostring(src)
    local count = 0

    for key, value in pairs(values) do
        local ok, result = Settings.Set(key, value)

        if ok then
            count = count + 1
            print(('[ddev_farm] admin %s(%d) set %s = %s'):format(
                name, src, key, tostring(result)))
        end
    end

    Settings.Broadcast()

    TriggerClientEvent('ddev_farm:adminUpdate', src, Settings.Snapshot())
    TriggerClientEvent('ddev_farm:notify', src,
        ('%d settings saved.'):format(count), 'success')
end)

RegisterNetEvent('ddev_farm:adminReset', function()
    local src = source

    if not RequireFarmAdmin(src) then return end

    Settings.Reset()
    Settings.Broadcast()

    TriggerClientEvent('ddev_farm:adminUpdate', src, Settings.Snapshot())
    TriggerClientEvent('ddev_farm:notify', src, 'Settings restored to defaults.', 'success')
end)

local Actions = {}

Actions.resetPrices = function()
    Market.ResetPrices()
    Market.Save()

    TriggerClientEvent('ddev_farm:priceUpdate', -1, Market.GetPriceTable())

    return true, 'Prices reset.'
end

Actions.tickNow = function()
    Market.Tick()
    Market.Save()

    TriggerClientEvent('ddev_farm:priceUpdate', -1, Market.GetPriceTable())

    return true, 'Tick executed.'
end

Actions.readyAll = function()
    local count = 0

    for _, node in pairs(Farm.GetAllNodes()) do
        Farm.SetNodeReady(node.id)
        TriggerClientEvent('ddev_farm:nodeUpdate', -1, node.id, true)
        count = count + 1
    end

    return true, ('%d nodes set ready.'):format(count)
end

Actions.resync = function()
    TriggerClientEvent('ddev_farm:setupNodes', -1, Farm.GetNodeList())
    TriggerClientEvent('ddev_farm:setupBlips', -1, Farm.GetZones())

    return true, 'Nodes and blips re-sent.'
end

Actions.pruneLog = function(_, data)
    local days = math.max(1, math.floor(tonumber(data and data.days) or 30))
    local cutoff = os.time() - days * 86400
    local affected = MySQL.update.await('DELETE FROM ddev_market_log WHERE ts < ?', { cutoff }) or 0

    return true, ('%d log rows deleted (%d days).'):format(affected, days)
end

Actions.giveItem = function(_, data)
    local target = tonumber(data and data.target)
    local cropKey = data and data.crop
    local count = math.max(1, math.floor(tonumber(data and data.count) or 1))
    local quality = math.min(2, math.max(0, math.floor(tonumber(data and data.quality) or 1)))

    if not target or target < 1 or not GetPlayerName(target) then
        return false, 'Invalid player.'
    end

    local crop = Config.CropMap[cropKey]

    if not crop then
        return false, 'Invalid crop.'
    end

    local metadata = Farm.BuildMetadata(crop, quality)

    if not exports.ox_inventory:AddItem(target, cropKey, count, metadata) then
        return false, 'Could not give item (inventory may be full).'
    end

    return true, ('%d x %s given (player %d).'):format(count, crop.label, target)
end

Actions.status = function()
    return true, Market.GetStatus()
end

Actions.setNpcPos = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'Player not found.' end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local content = table.concat({
        '--[[',
        '    ddev_farm - Pazar NPC konumu (otomatik olusturuldu)',
        '    /farmadmin > Setup > "Use my position" ile yazildi.',
        ']]',
        '',
        ('Config.Market.location.coords = vector4(%.2f, %.2f, %.2f, %.1f)'):format(
            coords.x, coords.y, coords.z, heading),
        '',
    }, '\n')

    SaveResourceFile(GetCurrentResourceName(), 'config/npcpos.lua', content, -1)

    return true, ('Market NPC saved: %.1f, %.1f, %.1f (restart required).'):format(
        coords.x, coords.y, coords.z)
end

RegisterCommand('farmplace', function(source)
    if not RequireFarmAdmin(source) then return end

    TriggerClientEvent('ddev_farm:openTools', source)
end, false)

Actions.nodeStats = function()
    local stats = {}

    for _, zone in ipairs(Config.HarvestZones) do
        stats[zone.crop] = {
            label = zone.label,
            file = #FarmPos.GetList(zone.crop),
            active = #(zone.nodes or {}),
        }
    end

    return true, stats
end

Actions.applyNodes = function()
    local summary = Farm.ApplyNodes()
    local total = 0

    for _, count in pairs(summary) do
        total = total + count
    end

    return true, ('Nodes applied: %d'):format(total)
end

Actions.clearNodes = function(src, data)
    local cropKey = type(data) == 'table' and data.crop or nil

    if cropKey then
        if not Config.CropMap[cropKey] then
            return false, ('Unknown crop: %s'):format(tostring(cropKey))
        end

        Farm.ClearNodes(cropKey)

        return true, ('Nodes cleared: %s'):format(cropKey)
    end

    Farm.ClearNodes()

    return true, 'All nodes cleared.'
end

Actions.openTools = function(src)
    TriggerClientEvent('ddev_farm:openTools', src)

    return true, ''
end

RegisterNetEvent('ddev_farm:adminAction', function(action, data)
    local src = source

    if not RequireFarmAdmin(src) then return end

    local fn = Actions[action]

    if not fn then return end

    local ok, success, result = pcall(fn, src, data)

    if not ok then
        TriggerClientEvent('ddev_farm:notify', src, 'Action error: ' .. tostring(success), 'error')
        return
    end

    if not success then
        TriggerClientEvent('ddev_farm:notify', src, tostring(result), 'error')
        return
    end

    if action == 'status' then
        TriggerClientEvent('ddev_farm:adminStatus', src, result)
    elseif action == 'nodeStats' then
        TriggerClientEvent('ddev_farm:nodeStats', src, result)
    else
        TriggerClientEvent('ddev_farm:notify', src, tostring(result), 'success')
    end

    if action ~= 'nodeStats' then
        TriggerClientEvent('ddev_farm:adminUpdate', src, Settings.Snapshot())
    end
end)

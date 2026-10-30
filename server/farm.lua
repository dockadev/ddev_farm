-- Server - harvest nodes and plant state.

Farm = {}
Farm.__index = Farm

local nodes = {}
local cooldowns = {}

local function ToPlainVec(v)
    if not v then return nil end

    if type(v) == 'table' then
        return { x = v.x or 0.0, y = v.y or 0.0, z = v.z or 0.0 }
    end

    local ok, x = pcall(function() return v.x end)
    if not ok then return nil end

    return { x = x, y = v.y, z = v.z }
end

function Farm.ApplyNodes()
    local summary = {}

    for _, zone in ipairs(Config.HarvestZones) do
        local points = FarmPos and FarmPos.GetList and FarmPos.GetList(zone.crop) or {}
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
        summary[zone.crop] = #list
    end

    Farm.Load()

    TriggerClientEvent('ddev_farm:setupNodes', -1, Farm.GetNodeList())
    TriggerClientEvent('ddev_farm:setupBlips', -1, Farm.GetZones())

    return summary
end

function Farm.ClearNodes(cropKey)
    for _, zone in ipairs(Config.HarvestZones) do
        if not cropKey or zone.crop == cropKey then
            if FarmPos and FarmPos.Clear then
                FarmPos.Clear(zone.crop)
            end

            zone.nodes = {}
        end
    end

    if cropKey then
        MySQL.update.await('DELETE FROM ddev_farm_plants WHERE crop = ?', { cropKey })
    else
        MySQL.update.await('DELETE FROM ddev_farm_plants')
    end

    Farm.Load()

    TriggerClientEvent('ddev_farm:setupNodes', -1, Farm.GetNodeList())
    TriggerClientEvent('ddev_farm:setupBlips', -1, Farm.GetZones())
end

function Farm.Load()
    nodes = {}

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `ddev_farm_plants` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `node_id` VARCHAR(64) NOT NULL,
            `owner` VARCHAR(64) NOT NULL,
            `crop` VARCHAR(32) NOT NULL,
            `planted_at` BIGINT NOT NULL,
            `grow_at` BIGINT NOT NULL,
            `harvested` TINYINT NOT NULL DEFAULT 0,
            UNIQUE KEY `uniq_node` (`node_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    local rows = MySQL.query.await('SELECT * FROM ddev_farm_plants')

    local total = 0

    for _, zone in ipairs(Config.HarvestZones) do
        for _, node in ipairs(zone.nodes) do
            local saved = nil
            for _, row in ipairs(rows or {}) do
                if row.node_id == node.id then
                    saved = row
                    break
                end
            end

            local now = os.time()
            local ready = true
            local harvestable = true

            if saved then
                if tonumber(saved.harvested) == 1 then
                    local readyAt = tonumber(saved.grow_at) or 0
                    ready = now >= readyAt
                    harvestable = false
                elseif now < (tonumber(saved.grow_at) or 0) then
                    ready = false
                    harvestable = false
                end
            else
                MySQL.insert.await(
                    'INSERT INTO ddev_farm_plants (node_id, owner, crop, planted_at, grow_at, harvested) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE node_id = node_id',
                    { node.id, '', zone.crop, now, now, 0 }
                )
            end

            nodes[node.id] = {
                id = node.id,
                crop = zone.crop,
                zone = zone.id,
                coords = node.coords,
                model = node.model,
                heading = node.heading,
                label = zone.label,
                growTime = node.growTime or zone.growTime or 900,
                respawn = node.respawn or zone.respawn or 1800,
                branches = node.branches,
                charges = node.charges or 1,
                chargesLeft = node.charges or 1,
                ready = ready,
                harvestable = harvestable,
            }

            total = total + 1
        end
    end

    print(('^2[ddev_farm]^7 %d harvest nodes loaded (%d zones)'):format(total, #Config.HarvestZones))
end

function Farm.IsHarvestable(nodeId)
    local node = nodes[nodeId]
    if not node then return false end

    return node.harvestable and node.ready and (node.chargesLeft or 1) > 0
end

function Farm.GetNodeCrop(nodeId)
    local node = nodes[nodeId]
    return node and node.crop or nil
end

function Farm.GetNode(nodeId)
    return nodes[nodeId]
end

function Farm.GetNodeList()
    local list = {}

    for _, node in pairs(nodes) do
        list[#list + 1] = {
            id = node.id,
            crop = node.crop,
            model = node.model,
            heading = node.heading,
            label = node.label,
            branchIndex = 0,
            harvestable = node.harvestable and node.ready and (node.chargesLeft or 1) > 0,
            charges = node.charges or 1,
            chargesLeft = node.chargesLeft or 1,
            coords = ToPlainVec(node.coords),
        }
    end

    return list
end

function Farm.GetZones()
    local serializable = {}

    for _, zone in ipairs(Config.HarvestZones) do
        local out = {
            id = zone.id,
            crop = zone.crop,
            label = zone.label,
            blip = zone.blip,
            blipCoords = ToPlainVec(zone.blipCoords or (zone.nodes and zone.nodes[1] and zone.nodes[1].coords)),
            nodes = {},
        }

        for _, node in ipairs(zone.nodes or {}) do
            out.nodes[#out.nodes + 1] = {
                id = node.id,
                coords = ToPlainVec(node.coords),
                model = node.model,
            }
        end

        serializable[#serializable + 1] = out
    end

    return serializable
end

function Farm.GetAllNodes()
    return nodes
end

function Farm.SetNodeReady(nodeId)
    local node = nodes[nodeId]
    if not node then return false end

    node.ready = true
    node.harvestable = true

    MySQL.update.await(
        'UPDATE ddev_farm_plants SET harvested = 0, grow_at = ? WHERE node_id = ?',
        { os.time(), nodeId }
    )

    return true
end

function Farm.HasJob(source)
    if not Config.RequiredJobs or #Config.RequiredJobs == 0 then
        return true
    end
    return Bridge.HasJob(source, Config.RequiredJobs)
end

function Farm.IsOnCooldown(source, nodeId)
    local playerId = Bridge.GetIdentifier(source)
    if not playerId then return false end

    local playerCooldowns = cooldowns[playerId]
    if not playerCooldowns then return false end

    local expiry = playerCooldowns[nodeId]
    if not expiry then return false end

    if os.time() >= expiry then
        playerCooldowns[nodeId] = nil
        return false
    end

    return true
end

function Farm.SetCooldown(source, nodeId)
    local playerId = Bridge.GetIdentifier(source)
    if not playerId then return end

    if not cooldowns[playerId] then
        cooldowns[playerId] = {}
    end

    cooldowns[playerId][nodeId] = os.time() + math.floor(Config.Harvest.cooldown / 1000)
end

function Farm.RollQualityFromHits(crop, hits)
    hits = math.max(0, math.min(2, math.floor(hits or 0)))

    local weights = Config.HarvestFlow.qualityWeights[hits]
    if not weights then
        return Config.Quality.NORMAL
    end

    local total = 0
    for _, weight in pairs(weights) do
        total = total + weight
    end

    if total <= 0 then
        return Config.Quality.NORMAL
    end

    local roll = math.random() * total
    local cumulative = 0

    for quality, weight in pairs(weights) do
        cumulative = cumulative + weight
        if roll <= cumulative then
            return quality
        end
    end

    return Config.Quality.NORMAL
end

function Farm.GetIconName(crop, quality)
    local suffix = Config.QualityIconSuffix[quality] or ''

    if crop.icon then
        local base = crop.icon:gsub('%.png$', '')
        return ('%s%s.png'):format(base, suffix)
    end

    return ('%s%s.png'):format(crop.key, suffix)
end

function Farm.BuildMetadata(crop, quality)
    local qualityLabel = Config.QualityLabel[quality] or 'Normal'

    return {
        label = ('%s (%s)'):format(crop.label, qualityLabel),
        description = ('%s picked in the orchard. Quality: %s'):format(crop.label, qualityLabel),
        type = crop.label,
        imageurl = ('nui://ddev_farm/web/images/%s'):format(Farm.GetIconName(crop, quality)),
        quality = quality,
        crop = crop.key,
    }
end

function Farm.ConsumeNode(nodeId, owner)
    local node = nodes[nodeId]
    if not node then return end

    node.chargesLeft = math.max(0, (node.chargesLeft or 1) - 1)

    TriggerClientEvent('ddev_farm:nodeCharges', -1, nodeId, node.chargesLeft)

    if node.chargesLeft > 0 then
        return
    end

    node.ready = false
    node.harvestable = false

    local now = os.time()
    local readyAt = now + math.floor(node.respawn / 1000)

    MySQL.update(
        'UPDATE ddev_farm_plants SET owner = ?, harvested = 1, grow_at = ? WHERE node_id = ?',
        { owner or '', readyAt, nodeId }
    )

    Citizen.CreateThread(function()
        local wait = (readyAt - now) * 1000
        if wait < 1000 then wait = 1000 end
        Wait(wait)

        local n = nodes[nodeId]
        if n then
            n.ready = true
            n.harvestable = true
            n.chargesLeft = n.charges or 1

            MySQL.update(
                'UPDATE ddev_farm_plants SET harvested = 0, grow_at = ? WHERE node_id = ?',
                { os.time(), nodeId }
            )

            TriggerClientEvent('ddev_farm:nodeUpdate', -1, nodeId, true)

            if Config.Debug then
                print(('^3[ddev_farm]^7 Node ready: %s'):format(nodeId))
            end
        end
    end)
end

function Farm.RefreshNodes()
    local now = os.time()

    for _, n in pairs(nodes) do
        if n and not n.ready and not n.harvestable then
            local row = MySQL.single.await(
                'SELECT harvested, grow_at FROM ddev_farm_plants WHERE node_id = ?', { n.id })

            if row then
                if tonumber(row.harvested) == 1 and now >= (tonumber(row.grow_at) or 0) then
                    n.ready = true
                    n.harvestable = true
                    MySQL.update.await(
                        'UPDATE ddev_farm_plants SET harvested = 0, grow_at = ? WHERE node_id = ?',
                        { now, n.id })

                    TriggerClientEvent('ddev_farm:nodeUpdate', -1, n.id, true)
                end
            end
        end
    end
end

return Farm

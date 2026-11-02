-- Client - harvest nodes as proximity markers.

local markersById = {}
local nodesById = {}
local nodesRef = nil

local function IsBusy()
    return DdevFarm.harvestBusy
        or DdevFarm.placing
        or NUI.IsSkillCheckOpen()
        or NUI.IsMarketOpen()
        or NUI.IsAdminOpen()
        or NUI.IsFarmOpen()
        or NUI.IsToolsOpen()
end

local function CanHarvest(node)
    return node and node.harvestable and (node.chargesLeft or 1) > 0
end

local function NodeOptions(node)
    if not node then return {} end

    local charges = node.charges or 1
    local left = node.chargesLeft or charges

    if not CanHarvest(node) then
        return { { key = 'harvest', label = L('noHarvests'), disabled = true } }
    end

    return {
        {
            key = 'harvest',
            label = ('%s %d/%d'):format(L('harvest'), left, charges),
        },
    }
end

local function AddNodeMarker(node)
    if not node or not node.id or not node.coords then return end

    nodesById[node.id] = node
    markersById[node.id] = true

    local crop = node.crop and Config.CropMap[node.crop]

    Marker.Add({
        id = node.id,
        coords = node.coords,
        crop = node.crop,
        offsetZ = 0.9,
        range = Config.Marker and Config.Marker.interactRange or 1.0,
        drawDistance = Config.Marker and Config.Marker.drawDistance or 3.0,
        key = Config.Harvest.interactKeyLabel or 'E',
        menuTitle = crop and crop.label or nil,
        getOptions = function()
            return NodeOptions(node)
        end,
        event = 'ddev_farm:markerAction',
    })
end

local function ClearMarkers()
    for id in pairs(markersById) do
        Marker.Remove(id)
    end

    markersById = {}
    nodesById = {}
end

local function SyncMarkers(coords)
    local px, py, pz = coords.x, coords.y, coords.z

    local radius = Config.Marker and Config.Marker.drawDistance or 3.0
    local radius2 = radius * radius
    local seen = {}

    for _, node in ipairs(DdevFarm.nodes or {}) do
        local c = node.coords

        if c and node.id then
            local dx, dy, dz = px - c.x, py - c.y, pz - c.z

            if dx * dx + dy * dy + dz * dz <= radius2 then
                seen[node.id] = true

                if not markersById[node.id] then
                    AddNodeMarker(node)
                end
            end
        end
    end

    for id in pairs(markersById) do
        if not seen[id] then
            Marker.Remove(id)
            markersById[id] = nil
            nodesById[id] = nil
        end
    end
end

AddEventHandler('ddev_farm:markerAction', function(id, option)
    if option ~= 'harvest' then return end

    local node = nodesById[id]

    if not node or not CanHarvest(node) or IsBusy() then return end

    TriggerServerEvent('ddev_farm:requestHarvest', node.id, node.branchIndex or 0)
end)

local lastX, lastY, lastZ

CreateThread(function()
    while true do
        if DdevFarm.nodes ~= nodesRef then
            nodesRef = DdevFarm.nodes
            ClearMarkers()
            lastX = nil
        end

        local coords = GetEntityCoords(cache.ped)

        if not lastX
            or math.abs(coords.x - lastX) > 0.25
            or math.abs(coords.y - lastY) > 0.25
            or math.abs(coords.z - lastZ) > 0.5 then
            lastX, lastY, lastZ = coords.x, coords.y, coords.z
            SyncMarkers(coords)
        end

        Wait(200)
    end
end)

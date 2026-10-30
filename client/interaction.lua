-- Client - harvest hint and nearest node detection.

local currentId = nil
local currentCanHarvest = nil
local currentCharges = nil

local function FindNearestNode(coords)
    local radius = Config.Harvest.targetRadius or 1.5
    local r2 = radius * radius
    local best, bestDist = nil, nil
    local list = DdevFarm.nodes

    if not list then return nil end

    for i = 1, #list do
        local node = list[i]
        local c = node.coords

        if c then
            local dx, dy, dz = coords.x - c.x, coords.y - c.y, coords.z - c.z
            local d2 = dx * dx + dy * dy + dz * dz

            if d2 <= r2 and (not bestDist or d2 < bestDist) then
                best, bestDist = node, d2
            end
        end
    end

    return best
end

local function ClearHint()
    if not currentId then return end

    currentId = nil
    currentCanHarvest = nil
    currentCharges = nil
    NUI.HideHint()
end

local function HideHintNow()
    currentId = nil
    currentCanHarvest = nil
    currentCharges = nil
    NUI.HideHint(true)
end

CreateThread(function()
    local lastScan = nil
    local cachedNode = nil
    local listRef = nil
    local frame = 0

    while true do
        frame = frame + 1

        if DdevFarm.nodes ~= listRef then
            listRef = DdevFarm.nodes
            cachedNode = nil
            lastScan = nil
        end

        local busy = DdevFarm.harvestBusy
            or DdevFarm.placing
            or NUI.IsSkillCheckOpen()
            or NUI.IsMarketOpen()
            or NUI.IsAdminOpen()
            or NUI.IsFarmOpen()
            or NUI.IsToolsOpen()

        local node = nil

        if busy then
            cachedNode = nil
            lastScan = nil
        else
            if frame % 6 == 0 or not cachedNode then
                local ped = PlayerPedId()

                if IsPedInAnyVehicle(ped, false) then
                    cachedNode = nil
                    lastScan = nil
                else
                    local coords = GetEntityCoords(ped)

                    if not lastScan or not cachedNode then
                        cachedNode = FindNearestNode(coords)
                        lastScan = coords
                    else
                        local dx, dy, dz = coords.x - lastScan.x, coords.y - lastScan.y, coords.z - lastScan.z

                        if dx * dx + dy * dy + dz * dz > 0.1225 then
                            cachedNode = FindNearestNode(coords)
                            lastScan = coords
                        end
                    end
                end
            end

            node = cachedNode
        end

        if not node then
            ClearHint()
            Wait(200)
        else
            local chargesLeft = node.chargesLeft or 1
            local canHarvest = node.harvestable and chargesLeft > 0

            if currentId ~= node.id or currentCanHarvest ~= canHarvest or currentCharges ~= chargesLeft then
                currentId = node.id
                currentCanHarvest = canHarvest
                currentCharges = chargesLeft

                if canHarvest then
                    local total = node.charges or 1
                    local extra = nil

                    if total > 1 then
                        extra = ('%d/%d'):format(chargesLeft, total)
                    end

                    NUI.ShowHint({
                        label = L('harvest'),
                        key = Config.Harvest.interactKeyLabel or 'E',
                        extra = extra,
                        crop = node.crop,
                    })
                else
                    NUI.ShowHint({
                        label = L('noHarvests'),
                        crop = node.crop,
                    })
                end
            end

            if canHarvest and IsControlJustPressed(0, Config.Harvest.interactKey or 38) then
                HideHintNow()
                TriggerServerEvent('ddev_farm:requestHarvest', node.id, node.branchIndex or 0)

                Wait(300)
            else
                Wait(0)
            end
        end
    end
end)

AddEventHandler('baseevents:onPlayerDied', ClearHint)

AddEventHandler('playerSpawned', ClearHint)

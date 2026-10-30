-- Client - crop prop streaming.

local spawned = {}

local function Inside(coords, center, limit)
    local dx, dy, dz = coords.x - center.x, coords.y - center.y, coords.z - center.z

    return dx * dx + dy * dy + dz * dz <= limit * limit
end

local function NormalizeModel(model)
    if type(model) == 'number' then
        return model
    end

    if type(model) ~= 'string' or model == '' then
        return nil
    end

    return joaat(model)
end

local function LoadModel(hash, timeout)
    if not IsModelInCdimage(hash) then
        return false
    end

    RequestModel(hash)

    local waited = 0
    local limit = timeout or 3000

    while not HasModelLoaded(hash) do
        if waited >= limit then
            return false
        end
        Wait(10)
        waited = waited + 10
    end

    return true
end

local function RemoveAll()
    for _, obj in pairs(spawned) do
        if DoesEntityExist(obj) then
            DeleteObject(obj)
        end
    end

    spawned = {}
end

local function SpawnNode(node)
    if not Config.Harvest.spawnProps then return end
    if not node.coords or not node.model then return end
    if spawned[node.id] then return end

    local hash = NormalizeModel(node.model)

    if not hash then
        print(('^3[ddev_farm]^7 Invalid model: %s (%s)'):format(tostring(node.model), node.id))
        return
    end

    if not LoadModel(hash) then
        print(('^3[ddev_farm]^7 Model failed to load: %s (%s)'):format(tostring(node.model), node.id))
        return
    end

    local coords = node.coords
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)

    if not obj or obj == 0 then
        print(('^3[ddev_farm]^7 Prop could not be created: %s (%s)'):format(tostring(node.model), node.id))
        return
    end

    SetEntityHeading(obj, node.heading or 0.0)

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    local waited = 0
    while not HasCollisionLoadedAroundEntity(obj) and waited < 300 do
        Wait(50)
        waited = waited + 50
    end

    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)

    local isTree = node.crop == 'apple' or node.crop == 'orange'
    local collide = Config.Harvest.propCollision == true
        or (isTree and Config.Harvest.treeCollision == true)

    SetEntityCollision(obj, collide)

    spawned[node.id] = obj
end

RegisterNetEvent('ddev_farm:setupNodes', function(nodeList)
    RemoveAll()

    if not Config.Harvest.spawnProps then return end

    local queue = {}
    local spawnDist = Config.Harvest.renderDistance or 150.0
    local coords = GetEntityCoords(PlayerPedId())

    for _, node in ipairs(nodeList or {}) do
        if node.coords and Inside(node.coords, coords, spawnDist) then
            queue[#queue + 1] = node
        end
    end

    local perFrame = math.max(1, Config.Harvest.spawnPerFrame or 8)

    Citizen.CreateThread(function()
        local index = 1

        while index <= #queue do
            for _ = 1, perFrame do
                local node = queue[index]
                if not node then break end

                SpawnNode(node)
                index = index + 1
            end

            Wait(0)
        end

        local count = 0
        for _ in pairs(spawned) do count = count + 1 end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    RemoveAll()
end)

CreateThread(function()
    while true do
        Wait(700)

        local list = DdevFarm.nodes

        if Config.Harvest.spawnProps and list then
            local coords = GetEntityCoords(PlayerPedId())
            local spawnDist = Config.Harvest.renderDistance or 150.0
            local budget = 8

            for i = 1, #list do
                local node = list[i]
                local c = node.coords

                if c then
                    local obj = spawned[node.id]

                    if obj and not DoesEntityExist(obj) then
                        spawned[node.id] = nil
                        obj = nil
                    end

                    if not obj and budget > 0 and Inside(c, coords, spawnDist) then
                        SpawnNode(node)
                        budget = budget - 1
                    end
                end
            end
        end
    end
end)

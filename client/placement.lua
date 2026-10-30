-- Client - /farmplace placement tool.

local active = false
local lineMode = false
local lineSpacing = 4.0
local lineStage = 1
local lineStart = nil
local lineGhostCount = 0

local crop = nil
local model = nil
local ghost = nil
local heading = 0.0
local zOffset = 0.0
local placed = 0
local previews = {}

local lineGhosts = {}
local linePreviewAt = 0
local previewPoints = {}
local previewCount = 0
local lastPoint = nil
local inputReadyAt = 0
local rawPrev = {}

local function RawJustPressed(vk, name)
    if type(IsRawKeyPressed) ~= 'function' then return false end

    local down = IsRawKeyPressed(vk)
    local was = rawPrev[name] or false

    rawPrev[name] = down

    return down and not was
end

local function RotationToDirection(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local cosX = math.abs(math.cos(x))

    return vector3(-math.sin(z) * cosX, math.cos(z) * cosX, math.sin(x))
end

local function GetCameraRay()
    local cam = GetRenderingCam()

    if cam and cam ~= -1 and DoesCamExist(cam) then
        return GetCamCoord(cam), RotationToDirection(GetCamRot(cam, 2))
    end

    return GetGameplayCamCoord(), RotationToDirection(GetGameplayCamRot(2))
end

local function AimPoint()
    local cam, dir = GetCameraRay()
    local dest = cam + dir * 400.0

    local handle = StartShapeTestRay(
        cam.x, cam.y, cam.z,
        dest.x, dest.y, dest.z,
        1 | 8 | 16,
        PlayerPedId(), 0
    )

    local _, hit, endCoords = GetShapeTestResult(handle)

    if (hit == 1 or hit == true) and endCoords then
        return endCoords
    end

    return nil
end

local function GroundZ(x, y, fromZ)
    local found, groundZ = GetGroundZFor_3dCoord(x, y, (fromZ or 0.0) + 50.0, false)

    if found and groundZ and groundZ > -100.0 then
        return groundZ
    end

    return nil
end

local function GroundPoints(points, reference)
    local refGround = GroundZ(reference.x, reference.y, reference.z)
    local refOffset = refGround and (reference.z - refGround) or 0.0

    for i = 1, #points do
        local p = points[i]
        local gz = GroundZ(p.x, p.y, p.z)

        if gz then
            points[i] = vector3(p.x, p.y, gz + refOffset)
        end
    end

    return points
end

local function LinePoints(a, b, spacing)
    local dist = #(vector3(b.x - a.x, b.y - a.y, 0.0))
    local count = math.max(2, math.min(80, math.floor(dist / spacing) + 1))
    local points = {}

    for i = 1, count do
        local t = (i - 1) / (count - 1)

        points[i] = vector3(
            a.x + (b.x - a.x) * t,
            a.y + (b.y - a.y) * t,
            a.z + (b.z - a.z) * t
        )
    end

    return points, count
end

local function ShowHint()
    local label
    local extra
    local header

    if lineMode then
        header = ('Line · %.1fm apart · %+.2fm'):format(lineSpacing, zOffset)
        label = lineStage == 1 and 'Set start' or 'Set end'
        extra = 'X cancel'

        if lineStage == 2 and lineGhostCount > 0 then
            extra = ('%d nodes · X cancel'):format(lineGhostCount)
        end
    else
        header = ('Node Placement · %+.2fm'):format(zOffset)
        label = ('Place %s'):format(crop)
        extra = ('%d placed · X cancel'):format(placed)
    end

    local items = {
        { key = ',  .', label = 'Rotate' },
    }

    if lineMode then
        items[#items + 1] = { key = '[  ]', label = 'Spacing' }
    end

    items[#items + 1] = { key = '↑  ↓', label = 'Height' }

    NUI.ShowHint({
        label = label,
        key = 'E',
        extra = extra,
        header = header,
        footerItems = items,
    })
end

local function DeleteGhost()
    if ghost and DoesEntityExist(ghost) then
        DeleteEntity(ghost)
    end

    ghost = nil
end

local function DeletePreviews()
    for _, obj in ipairs(previews) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end

    previews = {}
end

local function ClearLineGhosts()
    for _, obj in ipairs(lineGhosts) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end

    lineGhosts = {}
    lineGhostCount = 0
    previewPoints = {}
    previewCount = 0
end

local function BuildLineGhosts(count)
    ClearLineGhosts()

    local hash = joaat(model)

    for _ = 1, count do
        local obj = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false)

        SetEntityCollision(obj, false)
        SetEntityAlpha(obj, 105, false)
        SetEntityAsMissionEntity(obj, true, true)
        FreezeEntityPosition(obj, true)
        SetEntityInvincible(obj, true)
        SetEntityVisible(obj, false, false)

        lineGhosts[#lineGhosts + 1] = obj
    end

    lineGhostCount = #lineGhosts
end

local function DrawThickLine(a, b)
    local dx, dy = b.x - a.x, b.y - a.y
    local len = math.sqrt(dx * dx + dy * dy)

    if len < 0.001 then return end

    local px, py = -dy / len, dx / len
    local offsets = { -0.06, -0.03, 0.0, 0.03, 0.06 }

    for _, offset in ipairs(offsets) do
        DrawLine(
            a.x + px * offset, a.y + py * offset, a.z + 0.05,
            b.x + px * offset, b.y + py * offset, b.z + 0.05,
            127, 191, 143, 180
        )
    end
end

local function UpdateLinePreview(points, count)
    local rebuilt = false

    if count ~= lineGhostCount then
        BuildLineGhosts(count)
        rebuilt = true
    end

    previewPoints = points
    previewCount = count

    for i = 1, count do
        local point = points[i]
        local obj = lineGhosts[i]

        local h = (heading + ((i % 2 == 0) and 180.0 or 0.0)) % 360.0

        if obj and DoesEntityExist(obj) then
            SetEntityCoordsNoOffset(obj, point.x, point.y, point.z, false, false, false)

            PlaceObjectOnGroundProperly(obj)

            SetEntityHeading(obj, h)
            SetEntityVisible(obj, true, false)
        end
    end

    return rebuilt
end

local function DrawPreviewLines()
    if not lineMode or lineStage ~= 2 or previewCount < 2 then return end

    for i = 1, previewCount - 1 do
        DrawThickLine(previewPoints[i], previewPoints[i + 1])
    end
end

local function Stop()
    active = false
    lineMode = false
    lineStage = 1
    lineStart = nil
    DdevFarm.placing = false

    DeleteGhost()
    DeletePreviews()
    ClearLineGhosts()
    NUI.HideHint()

    placed = 0
    crop = nil
    model = nil
    zOffset = 0.0
    lastPoint = nil
end

local function SpawnPreview(x, y, z, h)
    local hash = joaat(model)
    local obj = CreateObject(hash, x, y, z, false, false, false)

    SetEntityHeading(obj, h)
    SetEntityCollision(obj, false)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    SetEntityAsMissionEntity(obj, true, true)

    previews[#previews + 1] = obj
end

local function SpawnGhost()
    local hash = joaat(model)

    RequestModel(hash)

    local timeout = GetGameTimer() + 5000

    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(10)
    end

    if not HasModelLoaded(hash) then
        return false
    end

    ghost = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false)

    SetEntityCollision(ghost, false)
    SetEntityAlpha(ghost, 150, false)
    SetEntityAsMissionEntity(ghost, true, true)
    FreezeEntityPosition(ghost, true)
    SetEntityInvincible(ghost, true)

    return true
end

local function RecordPoint(x, y, z, h)
    TriggerServerEvent('ddev_farm:recordFarmPos', crop, { x = x, y = y, z = z }, h)

    SpawnPreview(x, y, z, h)

    placed = placed + 1
end

local function Start(mode, key, spacing, height, headingValue)
    if active then Stop() end

    crop = key
    model = Config.CropPropModel[key] or 'prop_bush_grape_01'
    heading = headingValue or GetEntityHeading(PlayerPedId())
    zOffset = height or 0.0
    placed = 0
    previews = {}
    active = true
    lineMode = mode == 'line'
    lineSpacing = spacing or 4.0
    lineStage = 1
    lineStart = nil
    lineGhostCount = 0
    DdevFarm.placing = true

    if not SpawnGhost() then
        print(('^1[ddev_farm]^7 Model could not be loaded: %s'):format(model))
        Stop()
        return
    end

    print(('^2[ddev_farm]^7 %s mode: %s (%s)'):format(
        lineMode and 'Line' or 'Placement', crop, model))
    print('  E = place/select, , . = rotate, [ ] = spacing, X = exit')

    ShowHint()
end

function PlacementStart(opts)
    opts = opts or {}

    local cropKey = opts.crop

    if not cropKey or not Config.CropMap[cropKey] then return end

    local noclip = Config.Placement and Config.Placement.noclipCommand

    if noclip and noclip ~= '' then
        ExecuteCommand(noclip)
    end

    Start(opts.mode == 'line' and 'line' or 'free', cropKey,
        tonumber(opts.spacing) or 4.0,
        tonumber(opts.height) or 0.0,
        tonumber(opts.heading))
end

RegisterNetEvent('ddev_farm:openTools', function()
    local cropList = {}

    for _, crop in ipairs(Config.Crops or {}) do
        cropList[#cropList + 1] = { key = crop.key, label = crop.label }
    end

    NUI.OpenTools({
        heading = math.floor(GetEntityHeading(PlayerPedId())),
        crops = cropList,
        defaultSpacing = 4.0,
    })
end)

RegisterNUICallback('closeTools', function(_, cb)
    NUI.CloseTools()
    cb({ ok = true })
end)

RegisterNUICallback('toolsStart', function(data, cb)
    NUI.CloseTools()

    PlacementStart(data)

    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if not active then
            Wait(250)
        else
            Wait(0)

            local point = AimPoint()

            if point then
                lastPoint = point
            end

            local heightChanged = false

            if IsControlPressed(0, 172) then
                zOffset = zOffset + 0.015
                heightChanged = true
            end

            if IsControlPressed(0, 173) then
                zOffset = zOffset - 0.015
                heightChanged = true
            end

            if zOffset > 8.0 then zOffset = 8.0 end
            if zOffset < -3.0 then zOffset = -3.0 end

            if RawJustPressed(0xBC, 'comma') then heading = (heading - 15.0) % 360.0 end
            if RawJustPressed(0xBE, 'period') then heading = (heading + 15.0) % 360.0 end

            if IsControlJustPressed(0, 174) then heading = (heading - 15.0) % 360.0 end
            if IsControlJustPressed(0, 175) then heading = (heading + 15.0) % 360.0 end

            if lineMode then
                if RawJustPressed(0xDB, 'lbracket') then
                    lineSpacing = math.max(0.5, lineSpacing - 0.5)
                    heightChanged = true
                end

                if RawJustPressed(0xDD, 'rbracket') then
                    lineSpacing = math.min(25.0, lineSpacing + 0.5)
                    heightChanged = true
                end
            end

            if heightChanged then ShowHint() end

            if ghost and DoesEntityExist(ghost) then
                local target = point or lastPoint

                if target then
                    SetEntityCoordsNoOffset(ghost,
                        target.x, target.y, target.z + zOffset,
                        false, false, false)

                    PlaceObjectOnGroundProperly(ghost)

                    SetEntityVisible(ghost, true, false)

                    DrawMarker(1, target.x, target.y, target.z - 0.95,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.9, 0.9, 0.35,
                        127, 191, 143, 110,
                        false, false, 2, false, nil, nil, false)
                else
                    SetEntityVisible(ghost, false, false)
                end

                SetEntityHeading(ghost, heading)
            end

            if lineMode and lineStage == 2 and lineStart and point then
                local now = GetGameTimer()

                if now >= linePreviewAt then
                    linePreviewAt = now + 60

                    local endPoint = vector3(point.x, point.y, point.z + zOffset)
                    local points, count = LinePoints(lineStart, endPoint, lineSpacing)

                    GroundPoints(points, lineStart)

                    if UpdateLinePreview(points, count) then
                        ShowHint()
                    end
                end

                DrawMarker(1, lineStart.x, lineStart.y, lineStart.z - 0.95,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    0.7, 0.7, 0.5,
                    255, 255, 255, 130,
                    false, false, 2, false, nil, nil, false)
            end

            DrawPreviewLines()

            if point and IsControlJustPressed(0, 38) then
                local x, y, z = point.x, point.y, point.z + zOffset

                if not lineMode then
                    RecordPoint(x, y, z, heading)
                    ShowHint()
                elseif lineStage == 1 then
                    lineStart = vector3(x, y, z)
                    lineStage = 2
                    ShowHint()
                else
                    local points = LinePoints(lineStart, vector3(x, y, z), lineSpacing)

                    GroundPoints(points, lineStart)

                    for i, p in ipairs(points) do
                        local h = (heading + ((i % 2 == 0) and 180.0 or 0.0)) % 360.0

                        RecordPoint(p.x, p.y, p.z, h)
                    end

                    ClearLineGhosts()
                    lineStart = nil
                    lineStage = 1
                    ShowHint()
                end

                Wait(250)
            end

            if IsControlJustPressed(0, 73) then
                Stop()
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if active then Stop() end
end)

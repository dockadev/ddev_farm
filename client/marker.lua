-- Client - world-anchored markers and context menu.

Marker = {}

local markers = {}
local menuOpen = false
local menuId = nil
local menuMarker = nil
local lastSignature = nil

local function IsBlocked()
    return IsPauseMenuActive()
        or DdevFarm.harvestBusy
        or DdevFarm.placing
        or NUI.IsSkillCheckOpen()
        or NUI.IsMarketOpen()
        or NUI.IsAdminOpen()
        or NUI.IsFarmOpen()
        or NUI.IsToolsOpen()
end

local function MarkerOptions(marker)
    if type(marker.getOptions) == 'function' then
        local options = marker.getOptions()

        if type(options) == 'table' then
            return options
        end
    end

    return marker.options or {}
end

local function AnchorCoords(marker)
    if not marker then return nil end

    if marker.entity then
        local now = GetGameTimer()

        if not marker.anchorAt or now - marker.anchorAt >= 200 then
            marker.anchorAt = now
            marker.anchorValid = DoesEntityExist(marker.entity)

            if marker.anchorValid then
                local coords = GetEntityCoords(marker.entity)
                marker.anchorX, marker.anchorY, marker.anchorZ = coords.x, coords.y, coords.z
            end
        end

        if marker.anchorValid then
            return marker.anchorX, marker.anchorY, marker.anchorZ + (marker.offsetZ or 0)
        end
    end

    local coords = marker.coords
    if not coords then return nil end

    return coords.x, coords.y, coords.z + (marker.offsetZ or 0)
end

---@param def table { id, coords|entity, offsetZ, drawDistance, range, key, options, event, menuTitle }
---@return boolean
function Marker.Add(def)
    if type(def) ~= 'table' or not def.id then return false end

    markers[def.id] = def

    return true
end

---@param id string
---@param def table
---@return boolean
function Marker.Update(id, def)
    local marker = markers[id]

    if not marker or type(def) ~= 'table' then return false end

    for key, value in pairs(def) do
        marker[key] = value
    end

    return true
end

---@param id string
function Marker.Remove(id)
    markers[id] = nil

    if menuId == id then
        Marker.CloseMenu()
    end
end

---@param id string
---@return boolean
function Marker.Has(id)
    return markers[id] ~= nil
end

---@return boolean
function Marker.IsOpen()
    return menuOpen
end

function Marker.CloseMenu()
    if not menuOpen then return end

    menuOpen = false
    menuId = nil
    menuMarker = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'markerMenuClose' })
end

--- Tek secenekli marker'da karti buyutup aksiyonu tetikler.
--- Cok secenek varsa menuyu acar.
---@param id string
function Marker.Activate(id)
    local marker = markers[id]

    if not marker or IsBlocked() then return end

    local options = MarkerOptions(marker)

    if #options == 0 then return end

    if #options > 1 then
        Marker.OpenMenu(id)
        return
    end

    local option = options[1].key

    SendNUIMessage({ action = 'markerActivate', id = id })

    SetTimeout(140, function()
        if marker.event then
            TriggerEvent(marker.event, id, option)
        end
    end)
end

---@param id string
---@return boolean
function Marker.OpenMenu(id)
    local marker = markers[id]

    if not marker or menuOpen or IsBlocked() then return false end

    suppressMarker = false

    local options = MarkerOptions(marker)
    if #options == 0 then return false end

    local ax, ay, az = AnchorCoords(marker)
    if not ax then return false end

    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(ax, ay, az)

    if not onScreen then return false end

    menuOpen = true
    menuId = id
    menuMarker = marker

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'markerMenu',
        x = sx,
        y = sy,
        title = marker.menuTitle,
        options = options,
    })

    TriggerEvent('ddev_farm:markerMenuOpened', id)

    return true
end

RegisterNUICallback('markerSelect', function(data, cb)
    if not menuOpen or not menuMarker then
        cb({ ok = false })
        return
    end

    local option = data and data.option
    local marker = menuMarker
    local id = menuId

    if option and marker.event then
        SendNUIMessage({ action = 'markerMenuLoading' })
        TriggerEvent(marker.event, id, option)
    else
        Marker.CloseMenu()
    end

    cb({ ok = true })
end)

RegisterNUICallback('markerClose', function(_, cb)
    suppressMarker = true
    Marker.CloseMenu()
    cb({ ok = true })
end)

local cacheAt = 0
local cacheBlocked = false
local cacheX, cacheY, cacheZ = 0.0, 0.0, 0.0
local suppressMarker = false

local nearestAt = 0
local nearestId = nil
local nearestDist = nil
local nearestMarker = nil

local optionCacheId = nil
local optionCacheLabel = nil
local optionCacheAt = 0

CreateThread(function()
    while true do
        local now = GetGameTimer()

        if now - cacheAt >= 200 then
            cacheAt = now
            cacheBlocked = IsBlocked()

            local coords = GetEntityCoords(cache.ped)
            cacheX, cacheY, cacheZ = coords.x, coords.y, coords.z
        end

        local blocked = cacheBlocked

        if menuOpen and (blocked or next(markers) == nil) then
            Marker.CloseMenu()
        end

        if suppressMarker then
            local near = false

            for _, marker in pairs(markers) do
                local ax, ay, az = AnchorCoords(marker)

                if ax then
                    local dx, dy, dz = cacheX - ax, cacheY - ay, cacheZ - az
                    local limit = (marker.drawDistance or 3.0) + 1.0

                    if dx * dx + dy * dy + dz * dz <= limit * limit then
                        near = true
                        break
                    end
                end
            end

            if not near then
                suppressMarker = false
            elseif lastSignature ~= '' then
                lastSignature = ''
                SendNUIMessage({ action = 'markers', list = {} })
            end
        end

        if menuOpen or suppressMarker then
            Wait(150)
        else

        if next(markers) == nil then
            if lastSignature ~= '' then
                lastSignature = ''
                SendNUIMessage({ action = 'markers', list = {} })
            end

            Wait(300)
        else
            local list = {}
            local interactId = nil

        if not blocked then
            if now - nearestAt >= 100 then
                nearestAt = now
                nearestId = nil
                nearestDist = nil
                nearestMarker = nil

                local px, py, pz = cacheX, cacheY, cacheZ

                for id, marker in pairs(markers) do
                    local ax, ay, az = AnchorCoords(marker)

                    if ax then
                        local dx, dy, dz = px - ax, py - ay, pz - az
                        local dist2 = dx * dx + dy * dy + dz * dz
                        local drawDistance = marker.drawDistance or 3.0

                        if dist2 <= drawDistance * drawDistance
                            and (not nearestDist or dist2 < nearestDist) then
                            nearestId = id
                            nearestDist = dist2
                            nearestMarker = marker
                        end
                    end
                end

                if optionCacheId ~= nearestId then
                    optionCacheId = nil
                    optionCacheLabel = nil
                end
            end

            if nearestMarker then
                local ax, ay, az = AnchorCoords(nearestMarker)
                local onScreen, sx, sy = GetScreenCoordFromWorldCoord(ax, ay, az)

                if onScreen then
                    local state = 'icon'
                    local label = nil

                    if nearestDist <= (nearestMarker.range or 1.0) ^ 2 then
                        if now - optionCacheAt >= 500 then
                            optionCacheAt = now

                            local options = MarkerOptions(nearestMarker)

                            if #options > 0 then
                                optionCacheId = nearestId
                                optionCacheLabel = nearestMarker.prompt
                                    or (options[1] and options[1].label or nil)
                            else
                                optionCacheId = nil
                                optionCacheLabel = nil
                            end
                        end

                        if optionCacheId == nearestId then
                            state = 'key'
                            interactId = nearestId
                            label = optionCacheLabel
                        end
                    end

                    list[1] = {
                        id = nearestId,
                        x = sx,
                        y = sy,
                        state = state,
                        key = nearestMarker.key or 'E',
                        label = label,
                        crop = nearestMarker.crop,
                    }
                end
            end
        end

            local item = list[1]
            local signature = ''

            if item then
                signature = ('%s:%d:%d:%s'):format(
                    item.id, math.floor(item.x * 1000), math.floor(item.y * 1000), item.state)
            end

            if signature ~= lastSignature then
                lastSignature = signature

                if item then
                    SendNUIMessage({
                        action = 'marker',
                        x = item.x,
                        y = item.y,
                        state = item.state,
                        key = item.key,
                        label = item.label,
                        crop = item.crop,
                    })
                else
                    SendNUIMessage({ action = 'markers', list = {} })
                end
            end

            if not menuOpen and interactId and IsControlJustPressed(0, Config.Harvest.interactKey or 38) then
                Marker.Activate(interactId)
            end

            Wait(item and 0 or 200)
        end
        end
    end
end)

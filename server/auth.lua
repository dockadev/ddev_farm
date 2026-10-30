-- Server - admin authorization.

local DEFAULT_GROUPS = { 'admin', 'god', 'owner', 'superadmin', 'management' }

local function IsAdminGroupName(name)
    if type(name) ~= 'string' then return false end

    local lower = name:lower()
    local groups = (Config.Admin and Config.Admin.groups) or DEFAULT_GROUPS

    for _, group in ipairs(groups) do
        if lower == group then
            return true
        end
    end

    return false
end

local function IsFrameworkAdmin(source)
    local player = Bridge.GetPlayer(source)

    if not player then return false end

    local data = player.PlayerData or player

    if IsAdminGroupName(data.group) then
        return true
    end

    if type(player.getGroup) == 'function' and IsAdminGroupName(player.getGroup()) then
        return true
    end

    local framework = Bridge.Framework

    if framework == 'qbx' or framework == 'qb' then
        local ok, hasPermission = pcall(function()
            if framework == 'qbx' then
                return exports['qbx_core']:HasPermission(source, 'admin')
            end

            return exports['qb-core']:GetCoreObject().Functions.HasPermission(source, 'admin')
        end)

        if ok and hasPermission then
            return true
        end
    end

    return false
end

function IsFarmAdmin(source)
    if not source or source == 0 then
        return true
    end

    if IsFrameworkAdmin(source) then
        return true
    end

    local ace = Config.Admin and Config.Admin.ace

    if ace and ace ~= '' and IsPlayerAceAllowed(source, ace) then
        return true
    end

    local allowed = Config.Admin and Config.Admin.allowedIdentifiers

    if allowed and #allowed > 0 then
        for _, identifier in ipairs(GetPlayerIdentifiers(source) or {}) do
            for _, entry in ipairs(allowed) do
                if identifier == entry then
                    return true
                end
            end
        end
    end

    if Config.Debug then
        local player = Bridge.GetPlayer(source)
        local data = player and (player.PlayerData or player)

        print(('^3[ddev_farm]^7 admin reddedildi: %s (grup: %s)'):format(
            tostring(source), tostring(data and data.group or '?')))
    end

    return false
end

function RequireFarmAdmin(source)
    if IsFarmAdmin(source) then
        return true
    end

    if source and source ~= 0 then
        TriggerClientEvent('ddev_farm:notify', source, 'You do not have permission for this action.', 'error')
    end

    return false
end

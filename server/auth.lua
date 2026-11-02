-- Server - access control (ACE first, framework fallback).

Access = {}

local DEFAULT_GROUPS = { 'admin', 'god', 'owner', 'superadmin', 'management' }

local function IsAdminGroupName(name, groups)
    if type(name) ~= 'string' then return false end

    local lower = name:lower()
    groups = groups or DEFAULT_GROUPS

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
    local groups = (Config.Admin and Config.Admin.groups) or DEFAULT_GROUPS

    if IsAdminGroupName(data.group, groups) then
        return true
    end

    if type(player.getGroup) == 'function' and IsAdminGroupName(player.getGroup(), groups) then
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

--- ACE list: the first match wins.
---@param source number
---@param aces string|string[]
---@return boolean
function Access.HasAce(source, aces)
    if not source or source == 0 then return false end

    if type(aces) == 'string' then
        aces = { aces }
    end

    if type(aces) ~= 'table' then return false end

    for _, ace in ipairs(aces) do
        if type(ace) == 'string' and ace ~= '' and IsPlayerAceAllowed(source, ace) then
            return true
        end
    end

    return false
end

--- Order: ACE -> framework group. Console is always allowed.
---@param source number
---@return boolean
function Access.IsAdmin(source)
    if not source or source == 0 then
        return true
    end

    if Config.Admin and Config.Admin.testDeny then
        return false
    end

    local aces = (Config.Admin and Config.Admin.aces) or { 'ddev_farm.admin' }

    if Access.HasAce(source, aces) then
        return true
    end

    if IsFrameworkAdmin(source) then
        return true
    end

    if Config.Debug then
        local player = Bridge.GetPlayer(source)
        local data = player and (player.PlayerData or player)

        print(('^3[ddev_farm]^7 access denied: %s (group: %s)'):format(
            tostring(source), tostring(data and data.group or '?')))
    end

    return false
end

function IsFarmAdmin(source)
    return Access.IsAdmin(source)
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

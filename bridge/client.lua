-- Bridge - client-side framework helpers.

Bridge = {}

DdevFarm = {
    harvestBusy = false,
}

local function DetectFramework()
    if GetResourceState('qbx_core') == 'started' then
        return 'qbx'
    elseif GetResourceState('qb-core') == 'started' then
        return 'qb'
    elseif GetResourceState('es_extended') == 'started' then
        return 'esx'
    end
    return nil
end

Bridge.Framework = DetectFramework()

function Bridge.GetFrameworkName()
    return Bridge.Framework or 'none'
end

function Bridge.GetPlayerData()
    if Bridge.Framework == 'qbx' then
        return exports['qbx_core']:GetPlayerData() or {}
    elseif Bridge.Framework == 'qb' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayer(PlayerId())
        return Player and Player.PlayerData or {}
    elseif Bridge.Framework == 'esx' then
        local ESX = exports['es_extended']:getSharedObject()
        return ESX.GetPlayerData() or {}
    end
    return {}
end

function Bridge.Notify(message, type)
    if GetResourceState('ox_lib') ~= 'started' then return end

    pcall(function()
        lib.notify({
            type = type or 'inform',
            description = message,
        })
    end)
end

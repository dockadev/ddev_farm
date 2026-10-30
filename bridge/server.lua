-- Bridge - server-side framework abstraction (QBX / QB / ESX).

Bridge = {}

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

local esxObject
local qbObject

local function GetESX()
    if not esxObject then
        esxObject = exports['es_extended']:getSharedObject()
    end
    return esxObject
end

local function GetQB()
    if not qbObject then
        qbObject = exports['qb-core']:GetCoreObject()
    end
    return qbObject
end

function Bridge.IsReady()
    return Bridge.Framework ~= nil
end

function Bridge.GetFrameworkName()
    return Bridge.Framework or 'none'
end

function Bridge.GetPlayer(source)
    if not source then return nil end

    if Bridge.Framework == 'qbx' then
        return exports['qbx_core']:GetPlayer(source)
    elseif Bridge.Framework == 'qb' then
        return GetQB().Functions.GetPlayer(source)
    elseif Bridge.Framework == 'esx' then
        return GetESX().GetPlayerFromId(source)
    end

    return nil
end

function Bridge.GetIdentifier(source)
    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    if Bridge.Framework == 'qbx' then
        return player.PlayerData.citizenid
    elseif Bridge.Framework == 'qb' then
        return player.PlayerData.citizenid
    elseif Bridge.Framework == 'esx' then
        return player.getIdentifier()
    end

    return nil
end

function Bridge.GetName(source)
    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    if Bridge.Framework == 'qbx' or Bridge.Framework == 'qb' then
        return player.PlayerData.charinfo
            and (('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname))
            or GetPlayerName(source)
    elseif Bridge.Framework == 'esx' then
        return player.getName()
    end

    return nil
end

function Bridge.GetJob(source)
    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    if Bridge.Framework == 'qbx' or Bridge.Framework == 'qb' then
        local job = player.PlayerData.job
        if not job then return nil end
        return {
            name = job.name,
            label = job.label,
            grade = job.grade and job.grade.level or 0,
            gradeName = job.grade and job.grade.name or '',
            gradeLabel = job.grade and job.grade.label or '',
            onDuty = job.onduty or false,
        }
    elseif Bridge.Framework == 'esx' then
        local job = player.getJob()
        if not job then return nil end
        return {
            name = job.name,
            label = job.label,
            grade = tonumber(job.grade) or 0,
            gradeName = job.grade_name or '',
            gradeLabel = job.grade_label or '',
            onDuty = job.onDuty or false,
        }
    end

    return nil
end

function Bridge.HasJob(source, jobs)
    local job = Bridge.GetJob(source)
    if not job then return false end

    if type(jobs) == 'string' then
        return job.name == jobs
    end

    for _, name in ipairs(jobs) do
        if job.name == name then
            return true
        end
    end

    return false
end

function Bridge.HasGrade(source, grades)
    local job = Bridge.GetJob(source)
    if not job then return false end

    local required = grades[job.name]
    if not required then return false end

    if type(required) == 'table' then
        for _, grade in ipairs(required) do
            if job.grade >= grade then
                return true
            end
        end
        return false
    end

    return job.grade >= required
end

local function MoneyType(account)
    if account == 'money' and (Bridge.Framework == 'qbx' or Bridge.Framework == 'qb') then
        return 'cash'
    end

    return account
end

function Bridge.GetMoney(source, account)
    local player = Bridge.GetPlayer(source)
    if not player then return 0 end

    account = MoneyType(account)

    if Bridge.Framework == 'qbx' then
        return exports['qbx_core']:GetMoney(source, account) or 0
    elseif Bridge.Framework == 'qb' then
        return player.PlayerData.money[account] or 0
    elseif Bridge.Framework == 'esx' then
        local acc = player.getAccount(account)
        return acc and acc.money or 0
    end

    return 0
end

function Bridge.AddMoney(source, account, amount, reason)
    local player = Bridge.GetPlayer(source)
    if not player then return false end

    amount = tonumber(amount)
    if not amount or amount <= 0 then return false end

    account = MoneyType(account)
    reason = reason or 'ddev_farm'

    if Bridge.Framework == 'qbx' then
        return exports['qbx_core']:AddMoney(source, account, amount, reason) == true
    elseif Bridge.Framework == 'qb' then
        return player.Functions.AddMoney(account, amount, reason) ~= false
    elseif Bridge.Framework == 'esx' then
        local ok = pcall(player.addAccountMoney, player, account, amount, reason)
        return ok
    end

    return false
end

function Bridge.RemoveMoney(source, account, amount, reason)
    local player = Bridge.GetPlayer(source)
    if not player then return false end

    amount = tonumber(amount)
    if not amount or amount <= 0 then return false end

    account = MoneyType(account)
    reason = reason or 'ddev_farm'

    if Bridge.Framework == 'qbx' then
        return exports['qbx_core']:RemoveMoney(source, account, amount, reason) == true
    elseif Bridge.Framework == 'qb' then
        return player.Functions.RemoveMoney(account, amount, reason) ~= false
    elseif Bridge.Framework == 'esx' then
        if Bridge.GetMoney(source, account) < amount then
            return false
        end
        player.removeAccountMoney(account, amount, reason)
        return true
    end

    return false
end

function Bridge.HasMoney(source, account, amount)
    return Bridge.GetMoney(source, account) >= amount
end

function Bridge.AddItem(source, item, amount)
    if GetResourceState('ox_inventory') ~= 'started' then return false end
    local success = exports.ox_inventory:AddItem(source, item, amount)
    return success and true or false
end

function Bridge.RemoveItem(source, item, amount)
    if GetResourceState('ox_inventory') ~= 'started' then return false end
    local success = exports.ox_inventory:RemoveItem(source, item, amount)
    return success and true or false
end

function Bridge.GetItemCount(source, item)
    if GetResourceState('ox_inventory') ~= 'started' then return 0 end
    return exports.ox_inventory:GetItemCount(source, item) or 0
end

function Bridge.HasItem(source, item)
    return Bridge.GetItemCount(source, item) > 0
end

function Bridge.SetMeta(source, key, value)
    local player = Bridge.GetPlayer(source)
    if not player then return false end

    if Bridge.Framework == 'qbx' then
        exports['qbx_core']:SetMetadata(source, key, value)
        return true
    elseif Bridge.Framework == 'qb' then
        player.Functions.SetMetaData(key, value)
        return true
    elseif Bridge.Framework == 'esx' then
        player.setMeta(key, value)
        return true
    end

    return false
end

function Bridge.GetMeta(source, key)
    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    if Bridge.Framework == 'qbx' then
        return exports['qbx_core']:GetMetadata(source, key)
    elseif Bridge.Framework == 'qb' then
        return player.PlayerData.metadata[key]
    elseif Bridge.Framework == 'esx' then
        return player.getMeta(key)
    end

    return nil
end

function Bridge.Notify(source, message, type)
    if GetResourceState('ox_lib') == 'started' then
        local config = {
            type = type or 'inform',
            description = message,
        }
        TriggerClientEvent('ox_lib:notify', source, config)
    else
        TriggerClientEvent('ddev_bridge:notify', source, message, type)
    end
end

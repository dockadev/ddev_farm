-- Client - admin panel events.

RegisterNetEvent('ddev_farm:settings', function(values)
    if type(values) ~= 'table' then return end

    local previousLocale = Config.Locale

    for key, value in pairs(values) do
        ApplyFarmSetting(key, value)
    end

    if Config.Locale ~= previousLocale then
        NUI.Init()
    end
end)

RegisterNetEvent('ddev_farm:adminOpen', function(snapshot)
    NUI.OpenAdmin(snapshot)
end)

RegisterNetEvent('ddev_farm:adminUpdate', function(snapshot)
    NUI.UpdateAdmin(snapshot)
end)

RegisterNetEvent('ddev_farm:adminStatus', function(status)
    NUI.AdminStatus(status)
end)

RegisterNetEvent('ddev_farm:nodeStats', function(stats)
    NUI.NodeStats(stats)
end)

RegisterNUICallback('adminSave', function(data, cb)
    TriggerServerEvent('ddev_farm:adminSave', data.values)

    cb({ ok = true })
end)

RegisterNUICallback('adminReset', function(data, cb)
    TriggerServerEvent('ddev_farm:adminReset')

    cb({ ok = true })
end)

RegisterNUICallback('adminAction', function(data, cb)
    TriggerServerEvent('ddev_farm:adminAction', data.action, data.data)

    cb({ ok = true })
end)

RegisterNUICallback('closeAdmin', function(data, cb)
    NUI.CloseAdmin()

    cb({ ok = true })
end)

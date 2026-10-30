-- Client - /farmtablet player panel.

RegisterCommand('farmtablet', function()
    if NUI.IsMarketOpen() or NUI.IsAdminOpen() or NUI.IsFarmOpen() then
        return
    end

    TriggerServerEvent('ddev_farm:openFarm')
end, false)

RegisterNetEvent('ddev_farm:farmData', function(data)
    if type(data) ~= 'table' then return end

    if type(data.prefs) == 'table' then
        Sounds.SetEnabled(data.prefs.sounds)
    end

    NUI.OpenFarm(data)
end)

RegisterNUICallback('closeFarm', function(_, cb)
    NUI.CloseFarm()
    cb({ ok = true })
end)

RegisterNUICallback('saveFarmPrefs', function(data, cb)
    TriggerServerEvent('ddev_farm:saveFarmPrefs', data and data.prefs)

    cb({ ok = true })
end)

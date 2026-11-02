-- Client - /farmpanel player panel.

RegisterCommand('farmpanel', function()
    if NUI.IsMarketOpen() or NUI.IsAdminOpen() or NUI.IsFarmOpen() then
        return
    end

    TriggerServerEvent('ddev_farm:openFarm')
end, false)

TriggerEvent('chat:addSuggestion', '/farmpanel', 'Open the Farm Panel (Level, Bonus Roadmap, Recent Sales)')

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

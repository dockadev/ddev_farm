-- Client - NUI bridge and panel state.

NUI = {}

local skillCheckActive = false
local marketActive = false
local adminActive = false
local farmActive = false
local toolsActive = false
local progressCanceled = false

function NUI.Init()
    SendNUIMessage({
        action = 'setLocale',
        lang = Config.Locale or 'en',
    })
end

function NUI.OpenProgress(label, duration, icon)
    progressCanceled = false

    SendNUIMessage({
        action = 'openProgress',
        label = label,
        duration = duration or 3500,
        icon = icon,
    })
end

function NUI.IsSkillCheckOpen()
    return skillCheckActive
end

function NUI.IsMarketOpen()
    return marketActive
end

function NUI.PauseProgress()
    SendNUIMessage({ action = 'pauseProgress' })
end

function NUI.ResumeProgress()
    SendNUIMessage({ action = 'resumeProgress' })
end

function NUI.SetStages(data)
    SendNUIMessage({
        action = 'setStages',
        stage1 = data.stage1,
        stage2 = data.stage2,
        bonus = data.bonus,
    })
end

function NUI.ShowHint(opts)
    opts = opts or {}

    SendNUIMessage({
        action = 'showHint',
        label = opts.label,
        key = opts.key,
        extra = opts.extra,
        crop = opts.crop,
        header = opts.header,
        footer = opts.footer,
        footerItems = opts.footerItems,
    })
end

function NUI.HideHint(instant)
    SendNUIMessage({
        action = 'hideHint',
        instant = instant == true,
    })
end

function NUI.CompleteProgress(result)
    SendNUIMessage({
        action = 'completeProgress',
        quality = result and result.quality,
        count = result and result.count,
        bonus = result and result.bonus,
    })
end

function NUI.CloseProgress()
    SendNUIMessage({ action = 'closeProgress' })
end

function NUI.IsProgressCanceled()
    return progressCanceled
end

function NUI.OpenSkillCheck(data)
    skillCheckActive = true

    SetNuiFocus(true, false)
    SendNUIMessage({
        action = 'openSkillCheck',
        nodeId = data.nodeId,
        branchIndex = data.branchIndex or 0,
        duration = data.duration,
        period = data.period,
        zoneWidth = data.zoneWidth,
    })
end

function NUI.CloseSkillCheck()
    skillCheckActive = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeSkillCheck' })
end

function NUI.OpenMarket(prices, stock, progress, focus)
    marketActive = true

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openMarket',
        prices = prices,
        stock = stock,
        progress = progress,
        focus = focus,
    })
end

function NUI.SendPreview(prices, stock, progress)
    SendNUIMessage({
        action = 'marketPreview',
        prices = prices,
        stock = stock,
        progress = progress,
    })
end

function NUI.SendSellCard(prices, stock, progress, focus)
    SendNUIMessage({
        action = 'sellCard',
        prices = prices,
        stock = stock,
        progress = progress,
        focus = focus,
    })
end

function NUI.CloseMarket()
    marketActive = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMarket' })
end

function NUI.SetPrices(prices, stock, progress)
    SendNUIMessage({
        action = 'updatePrices',
        prices = prices,
        stock = stock,
        progress = progress,
    })
end

function NUI.OpenAdmin(snapshot)
    if farmActive then
        farmActive = false
        SendNUIMessage({ action = 'farmClose' })
    end

    if marketActive then
        marketActive = false
        SendNUIMessage({ action = 'closeMarket' })
    end

    adminActive = true

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'adminOpen',
        settings = snapshot,
        support = Config.Support or {},
    })
end

function NUI.UpdateAdmin(snapshot)
    SendNUIMessage({
        action = 'adminUpdate',
        settings = snapshot,
    })
end

function NUI.AdminStatus(status)
    SendNUIMessage({
        action = 'adminStatus',
        status = status,
    })
end

function NUI.NodeStats(stats)
    SendNUIMessage({
        action = 'nodeStats',
        data = stats,
    })
end

function NUI.OpenTools(data)
    if farmActive then
        farmActive = false
        SendNUIMessage({ action = 'farmClose' })
    end

    if adminActive then
        adminActive = false
        SendNUIMessage({ action = 'adminClose' })
    end

    toolsActive = true

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'toolsOpen',
        data = data,
    })
end

function NUI.CloseTools()
    toolsActive = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'toolsClose' })
end

function NUI.IsToolsOpen()
    return toolsActive
end

function NUI.OpenFarm(data)
    if adminActive then
        adminActive = false
        SendNUIMessage({ action = 'adminClose' })
    end

    farmActive = true

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'farmOpen',
        data = data,
    })
end

function NUI.CloseFarm()
    farmActive = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'farmClose' })
end

function NUI.IsFarmOpen()
    return farmActive
end

function NUI.CloseAdmin()
    adminActive = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'adminClose' })
end

function NUI.IsAdminOpen()
    return adminActive
end

RegisterNUICallback('skillcheckResult', function(data, cb)
    NUI.CloseSkillCheck()
    TriggerEvent('ddev_farm:skillcheckResult', data)
    cb({ ok = true })
end)

RegisterNUICallback('closeSkillCheck', function(data, cb)
    NUI.CloseSkillCheck()
    cb({ ok = true })
end)

RegisterNUICallback('cancelProgress', function(data, cb)
    progressCanceled = true
    cb({ ok = true })
end)

RegisterNUICallback('closeMarket', function(data, cb)
    NUI.CloseMarket()
    cb({ ok = true })
end)

RegisterNUICallback('sell', function(data, cb)
    if type(data.items) == 'table' and #data.items > 0 then
        for _, item in ipairs(data.items) do
            TriggerServerEvent('ddev_farm:sell', data.crop, item.units, item.quality)
        end
    else
        TriggerServerEvent('ddev_farm:sell', data.crop, data.units, data.quality)
    end

    cb({ ok = true })
end)

CreateThread(function()
    while true do
        Wait(200)
        if IsControlJustReleased(0, 322) then
            if skillCheckActive then
                NUI.CloseSkillCheck()
            end

            if adminActive then
                NUI.CloseAdmin()
            end

            if farmActive then
                NUI.CloseFarm()
            end

            if toolsActive then
                NUI.CloseTools()
            end
        end
    end
end)

NUI.Init()

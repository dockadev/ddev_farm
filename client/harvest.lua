-- Client - harvest flow, progress and skill checks.

local pendingSkillCheck = nil
local pendingResult = nil

local function LoadHarvestAnim(crop)
    local candidates = {}

    local cropAnim = crop and Config.Harvest.cropAnims and Config.Harvest.cropAnims[crop]
    if cropAnim then
        candidates[#candidates + 1] = cropAnim
    end

    if Config.Harvest.anim then
        candidates[#candidates + 1] = Config.Harvest.anim
    end

    for _, fallback in ipairs(Config.Harvest.fallbackAnims or {}) do
        candidates[#candidates + 1] = fallback
    end

    for _, anim in ipairs(candidates) do
        if anim and anim.dict and DoesAnimDictExist(anim.dict) then
            local ok = pcall(function()
                lib.requestAnimDict(anim.dict, 1000)
            end)

            if ok and HasAnimDictLoaded(anim.dict) then
                return anim
            end
        end
    end

    return nil
end

RegisterNetEvent('ddev_farm:skillcheckResult', function(result)
    if not pendingSkillCheck then return end

    local resolve = pendingSkillCheck
    pendingSkillCheck = nil
    resolve(result and result.tier or 'miss')
end)

RegisterNetEvent('ddev_farm:harvestResult', function(quality, count, bonus)
    if not pendingResult then return end

    local resolve = pendingResult
    pendingResult = nil
    resolve({ quality = quality, count = count, bonus = bonus })
end)

local function AwaitMinigame(nodeId, branchIndex)
    if Config.SkillCheck.engine == 'ox' then
        local passed = lib.skillCheck(
            Config.SkillCheck.ox and Config.SkillCheck.ox.difficulty or { 'easy', 'easy' },
            Config.SkillCheck.ox and Config.SkillCheck.ox.inputs or { 'e', 'e' }
        )

        return passed and 'good' or 'miss'
    end

    NUI.OpenSkillCheck({
        nodeId = nodeId,
        branchIndex = branchIndex,
        duration = Config.SkillCheck.duration,
        period = Config.SkillCheck.period,
        zoneWidth = Config.SkillCheck.zoneWidth,
    })

    local tier = nil
    pendingSkillCheck = function(value)
        tier = value
    end

    local deadline = GetGameTimer() + Config.SkillCheck.duration + 3000

    while tier == nil and GetGameTimer() < deadline do
        Wait(0)
    end

    pendingSkillCheck = nil
    NUI.CloseSkillCheck()

    return tier or 'miss'
end

RegisterNetEvent('ddev_farm:doHarvest', function(nodeId, branchIndex)
    if DdevFarm.harvestBusy then return end
    DdevFarm.harvestBusy = true

    branchIndex = branchIndex or 0

    local completed = false

    local ok, err = pcall(function()
        local crop = nodeId and nodeId:match('node_(%a+)_%d+$')

        local anim = LoadHarvestAnim(crop)
        local ped = cache.ped

        if anim then
            TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, anim.flag or 1, 0.0, false, false, false)
        end

        local icon = crop
        local duration = Config.Harvest.duration
        local checkpoints = Config.HarvestFlow.checkpoints or { 25, 75 }

        NUI.HideHint(true)
        NUI.OpenProgress(L('harvesting'), duration, icon and (icon .. '.png') or nil)
        NUI.SetStages({ stage1 = 'pending', stage2 = 'pending' })

        local elapsed = 0
        local last = GetGameTimer()
        local stage = 0
        local tiers = {}

        while elapsed < duration do
            if NUI.IsProgressCanceled() then break end

            local now = GetGameTimer()
            elapsed = elapsed + (now - last)
            last = now

            local percent = (elapsed / duration) * 100

            if stage < #checkpoints and percent >= checkpoints[stage + 1] then
                stage = stage + 1

                NUI.PauseProgress()

                local tier = AwaitMinigame(nodeId, branchIndex)
                tiers[stage] = tier

                NUI.SetStages({
                    stage1 = tiers[1] or 'pending',
                    stage2 = tiers[2] or 'pending',
                })

                NUI.ResumeProgress()
                last = GetGameTimer()
            end

            Wait(0)
        end

        completed = not NUI.IsProgressCanceled() and elapsed >= duration

        if not completed then
            TriggerServerEvent('ddev_farm:harvestCanceled', nodeId)
        end

        if anim then
            StopAnimTask(ped, anim.dict, anim.clip, 1.0)
        else
            ClearPedTasks(ped)
        end

        if completed then
            local result = nil
            pendingResult = function(value)
                result = value
            end

            TriggerServerEvent('ddev_farm:completeHarvest', nodeId, branchIndex,
                tiers[1] or 'miss', tiers[2] or 'miss')

            local deadline = GetGameTimer() + 3000

            while result == nil and GetGameTimer() < deadline do
                Wait(0)
            end

            pendingResult = nil

            NUI.CompleteProgress(result or {})

            Sounds.Play('harvest')

            Wait(1400)
        end

        NUI.CloseProgress()
    end)

    DdevFarm.harvestBusy = false

    if not ok then
        print(('^1[ddev_farm]^7 Harvest error: %s'):format(err))
        NUI.CloseProgress()
        Bridge.Notify('An error occurred while harvesting.', 'error')
        return
    end

    if not completed then
        Bridge.Notify(L('canceled'), 'error')
    end
end)

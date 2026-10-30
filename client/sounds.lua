-- Client - UI sound effects.

Sounds = {}

local enabled = true

local PRESETS = {
    harvest = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    sale    = { name = 'PURCHASE', set = 'HUD_LIQUOR_STORE_SOUNDSET' },
    levelUp = { name = 'MEDAL_UP', set = 'HUD_AWARDS' },
    error   = { name = 'ERROR', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
}

function Sounds.Play(kind)
    if not enabled then return end
    if not Config.Sounds or Config.Sounds.enabled == false then return end

    local preset = PRESETS[kind]
    if not preset then return end

    pcall(PlaySoundFrontend, -1, preset.name, preset.set, true)
end

function Sounds.SetEnabled(value)
    enabled = value ~= false
end

RegisterNetEvent('ddev_farm:prefs', function(prefs)
    if type(prefs) ~= 'table' then return end

    enabled = prefs.sounds ~= false
end)

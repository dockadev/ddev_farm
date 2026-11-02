-- ddev_farm - resource manifest.

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ddev_farm'
description 'Farming, harvest minigames and a live supply/demand market'
author 'dockadev'
version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
    'config/npcpos.lua',
    'config/crops.lua',
    'config/zones.lua',
    'config/locales.lua',
    'shared/settings.lua',
    'bridge/shared.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/sounds.lua',
    'client/nui.lua',
    'client/blips.lua',
    'client/main.lua',
    'client/marker.lua',
    'client/props.lua',
    'client/interaction.lua',
    'client/marketnpc.lua',
    'client/harvest.lua',
    'client/placement.lua',
    'client/admin.lua',
    'client/farmpanel.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/server.lua',
    'bridge/server.lua',
    'bridge/diagnostics.lua',
    'server/auth.lua',
    'server/market.lua',
    'server/farm.lua',
    'server/settings.lua',
    'server/progression.lua',
    'server/farmpanel.lua',
    'server/harvestcap.lua',
    'server/sell.lua',
    'server/admin_panel.lua',
    'server/main.lua',
    'server/farmpos.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/style.css',
    'web/css/farm.css',
    'web/css/marker.css',
    'web/js/locale.js',
    'web/js/theme.js',
    'web/js/progress.js',
    'web/js/skillcheck.js',
    'web/js/market.js',
    'web/js/hud.js',
    'web/js/marker.js',
    'web/js/admin-i18n.js',
    'web/js/admin.js',
    'web/js/farm.js',
    'web/js/tools.js',
    'web/images/*.png',
    'web/fonts/*.ttf',
    'web/locales/*.json',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'ox_inventory',
}

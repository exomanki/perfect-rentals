fx_version 'cerulean'
game 'gta5'

name 'perfect_rentals'
description 'Premium vehicle rental '
author 'Spectre Script'
version '1.2.0'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/*.lua',
    'shared/*.lua',
}

client_scripts {
    'client/framework.lua',
    'client/helpers.lua',
    'client/nui.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/framework.lua',
    'server/database.lua',
    'server/webhooks.lua',
    'server/main.lua',
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
}

dependencies {
    'ox_lib',
    'oxmysql',
}

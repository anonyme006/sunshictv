fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ox_garage'
author 'sunshictv'
description 'Garage premium NUI + ox_target — perso, hélicos, entreprise, fourrière'
version '2.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/img/logo.svg',
}

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua',
    'locales/fr.lua',
}

client_scripts {
    'client/main.lua',
    'client/keys.lua',
    'client/nui.lua',
    'client/menus.lua',
    'client/job.lua',
    'client/job_garages.lua',
    'client/impound.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/private.lua',
    'server/main.lua',
    'server/job.lua',
    'server/job_garages.lua',
    'server/impound.lua',
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'oxmysql',
}

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ox_garage'
author 'sunshictv'
description 'Garage moderne ox_lib + ox_target — menus context, états véhicule, spawn/store'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua',
    'locales/fr.lua',
}

client_scripts {
    'client/main.lua',
    'client/menus.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'oxmysql',
}

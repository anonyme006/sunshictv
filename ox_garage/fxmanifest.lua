fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ox_garage'
author 'sunshictv'
description 'Garage moderne ox_lib + ox_target — perso, entreprise, fourrière générale & mécano'
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
    'client/job.lua',
    'client/impound.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/job.lua',
    'server/impound.lua',
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'oxmysql',
}

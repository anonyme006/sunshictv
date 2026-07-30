fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fuel_logistics'
author 'sunshictv'
description 'Fuel Logistics — entreprise d\'approvisionnement carburant (ESX Legacy + ox_*)'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua',
    'locales/fr.lua',
    'locales/en.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/main.lua',
    'client/harvest.lua',
    'client/refine.lua',
    'client/delivery.lua',
    'client/export.lua',
    'client/boss.lua',
    'client/admin.lua',
    'client/orders.lua',
    'client/stations_menu.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/db.lua',
    'server/society.lua',
    'server/harvest.lua',
    'server/refine.lua',
    'server/stations.lua',
    'server/companies.lua',
    'server/delivery.lua',
    'server/export.lua',
    'server/orders.lua',
    'server/boss.lua',
    'server/admin.lua',
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql',
}

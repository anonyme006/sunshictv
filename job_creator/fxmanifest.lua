fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'job_creator'
author 'sunshictv'
description 'Job Creator complet style Jaksam — jobs, grades, markers, société, garages, shops, craft'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua',
    'locales/fr.lua',
}

client_scripts {
    'client/main.lua',
    'client/markers.lua',
    'client/menus.lua',
    'client/garage.lua',
    'client/cloakroom.lua',
    'client/boss.lua',
    'client/creator.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/jobs.lua',
    'server/markers.lua',
    'server/society.lua',
    'server/employees.lua',
    'server/actions.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}

dependencies {
    'es_extended',
    'oxmysql',
}

-- Optionnel mais recommandé pour les garages entreprise
-- dependency / ox_garage
-- dependency / ox_lib

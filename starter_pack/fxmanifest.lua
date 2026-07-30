fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'starter_pack'
author 'sunshictv'
description 'Kit d\'arrivée + carte chance (spin banque)'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependencies {
    'es_extended',
    'oxmysql',
}

-- Optionnel : ox_target (rangement BMX), ox_lib (progress), ox_inventory
-- ensure ox_target
-- ensure ox_lib
-- ensure ox_inventory


fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbx-charactercreator'
author 'sunshictv'
description 'Système complet de création de personnage pour Qbox / qbx_core'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/fr.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/utils.lua',
    'client/appearance.lua',
    'client/clothing.lua',
    'client/camera.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/validation.lua',
    'server/database.lua',
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/components/*.js',
    'web/assets/**/*',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbx-charactercreator'
author 'sunshictv'
description 'Création Qbox : identité qbx-multicharacter + apparence rCore Clothing'
version '1.1.0'

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
    'client/rcore.lua',
    'client/main.lua',
    'client/multichar.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/validation.lua',
    'server/database.lua',
    'server/main.lua',
    'server/multichar.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/identity.js',
    'web/multichar.js',
    'web/components/*.js',
    'web/assets/**/*',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}

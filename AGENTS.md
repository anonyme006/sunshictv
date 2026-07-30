# sunshictv

FiveM **ESX Legacy** resources (Lua + NUI). Two resources:

- `job_creator/` — admin NUI panel to create/manage jobs, grades, markers, vehicles, shops, crafts.
- `ox_garage/` — `ox_lib`/`ox_target` garage system (personal, private, company, impound).

See `README.md`, `job_creator/README.md`, and `ox_garage/README.md` for feature/config details.

## Cursor Cloud specific instructions

These resources run **inside an FXServer (Cfx.re) game server**; the client scripts and the in-game NUI ultimately require a running FXServer + MySQL + `es_extended` (and, for `ox_garage`, `ox_lib`/`ox_target`) plus a GTA5 game client to connect. That full stack (especially the game client) **cannot run headless in this VM**, so do not expect an in-game end-to-end run here.

What you CAN do in this environment:

### Lint / syntax (the primary code check)

- There is **no package manager** (no `package.json`, `requirements.txt`, lockfiles, or build step). Nothing to compile or bundle.
- Syntax/compile check every Lua file with `luac5.4 -p <file>` (the `fxmanifest.lua` files declare `lua54`). All files should parse with 0 errors.
- Lint with `luacheck` (installed via luarocks). Expect **many warnings but 0 errors**: FiveM runs all of a resource's Lua files in one shared state, so functions defined in one file (e.g. `IsPrivateGarage` in `ox_garage/server/private.lua`) are used as "undefined globals" in another (`server/main.lua`). These cross-file-global and FiveM-native-global warnings are expected and not bugs — the bar is **0 errors**, not 0 warnings.
- Example: `luacheck job_creator ox_garage` (pass FiveM/ESX globals via `--globals` to reduce noise).

### Running / previewing the app

- The user-facing "app" you can actually run is the **`job_creator` NUI admin panel** (`job_creator/html/`: `index.html` + `css/style.css` + `js/app.js`). It is a static web UI.
- The panel is **hidden until it receives a `postMessage({ action: 'openAdmin', data: <payload> })`** — in-game the client (`client/creator.lua`) sends this via `SendNUIMessage`. Simply opening `index.html` in a browser shows a blank page; you must emulate the FiveM NUI host.
- To preview it in a browser without FXServer: serve `job_creator/html/` (e.g. `python3 -m http.server`) and load a small dev harness that (1) defines `window.GetParentResourceName`, (2) overrides `window.fetch` to answer the panel's NUI callbacks at `https://job_creator/<callback>` (see `RegisterNUICallback` names in `client/creator.lua`), and (3) dispatches an `openAdmin` message whose `data` matches `JC.GetAdminPayload()` in `server/main.lua` (jobs/markers/… + `markerTypes`/`permissions`/`defaultActions` from `config.lua`). After a save callback, re-dispatch `openAdmin` to mimic the server→client reload. Keep such a harness out of commits.

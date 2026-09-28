# utilmenu

Category menu for NixOS (Niri + Walker + Elephant). One persistent window,
native submenu navigation, global live search, Noctalia-derived styling.

## Install

```sh
git clone <repo> ~/.config/utilmenu2   # or wherever you keep it
cd ~/.config/utilmenu2
./install.sh                 # full install incl. services
./install.sh --no-services   # files only, no systemd units
./install.sh --keybind       # + print suggested niri keybind
```

Requirements: `walker`, `elephant` (menus provider), `foot` for TUI apps.
On NixOS: add `walker` + `elephant` to `environment.systemPackages`.

What it does (all user-scope, nothing global):
- copies scripts/conf/actions to `~/.config/utilmenu2/`
- installs `utilsearch.lua` to `~/.config/elephant/menus/`
- generates submenu files via `gen-menus.sh`
- syncs Walker CSS from Noctalia config via `sync-style.sh`
- recolours app icons via `recolor-icons.sh`
- tells you what to merge into `~/.config/walker/config.toml`
- enables `utilmenu-preload.service` (cold-start cache, no GUI)
  and `utilmenu-theme.path` (live re-theme on wallpaper change)

The installer never overwrites your walker config — it prints what to merge.

## How it works

```text
menu.conf ─┬─ gen-menus.sh ─→ utilmenu.toml (root) + utilmenu_<cat>.lua (submenus)
           └─ utilsearch.lua (global search provider, stateless)
```

- **Root** (`menus:utilmenu`, TOML): the 8 categories.
- **Submenus** (Lua, generated): empty query → own children;
  any query → global search over all of `menu.conf` + desktop apps.
  Navigation is native (`SubMenu` field + `menus:open`), same window.
- **Search** (`menus:utilsearch`): same global logic at root level.
- **Styling** follows the active Noctalia wallpaper palette
  (`settings.toml` + generated M3 palette). Noctalia is never modified.
- **App icons** are recoloured to Noctalia's `app_icon_color` role.

## Files

| File | Purpose |
|---|---|
| `install.sh` | installer (this) |
| `menu.sh` | launcher (`--preload` warms cache + service) |
| `menu.conf` | the dataset (labels, order, icons, handlers) |
| `menu.conf.sh` | geometry/theme/cache paths |
| `actions.d/*` | one script per `run:<id>` |
| `gen-menus.sh` | generates root TOML + submenu Lua files |
| `sync-style.sh` | Walker CSS from live Noctalia config |
| `recolor-icons.sh` / `recolor.py` | app icons → Noctalia accent colour |
| `elephant/submenu.lua` | shared submenu logic (children + global search) |
| `elephant/menus/utilsearch.lua` | root-level global search provider |
| `walker/config-snippet.toml` | set/actions to merge into walker config |
| `systemd/` | preload service + theme watcher units |

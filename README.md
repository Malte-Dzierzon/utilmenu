# utilmenu

Omarchy-style category menu for NixOS (Niri). One persistent Walker window,
native Elephant submenus, global live search, Noctalia-derived styling.

## How it works

```text
menu.conf (action|id|parent|glyph|label|handler|alias|desc)
  ├── gen-menus.sh → native TOML menus (navigation)
  └── utilsearch.lua → global search provider (search only)
```

- **Navigation (native):** each category is its own Elephant menu,
  entries use `submenu = "utilmenu_<id>"`. Walker `menus:open` navigates
  in place (`ClearReload`), same window, no reopen.
- **Search (stateless):** `menus:utilsearch` sees the whole `menu.conf`
  plus the desktop-app cache. Empty query → no results (navigation shows).
  Non-empty → global matches with breadcrumb subtext, no Enter needed.
- **Styling:** `sync-style.sh` reads the real Noctalia config
  (`settings.toml` + wallpaper palette) into the Walker CSS.
  Noctalia itself is never modified.

## Install

```sh
DEST=~/.config/utilmenu2
mkdir -p "$DEST/actions.d" ~/.config/elephant/menus
cp menu.sh menu.conf menu.conf.sh gen-menus.sh sync-style.sh "$DEST/"
cp actions.d/* "$DEST/actions.d/"
cp elephant/menus/utilsearch.lua ~/.config/elephant/menus/utilsearch.lua
~/.config/utilmenu2/gen-menus.sh   # generates native TOMLs into elephant/menus/
~/.config/utilmenu2/sync-style.sh  # generates Walker CSS from Noctalia config
# merge walker/config-snippet.toml into ~/.config/walker/config.toml
```

Requires: `walker` + `elephant` (menus provider) running.
Keybind: `Mod+Shift+G` → `~/.config/utilmenu2/menu.sh`.

## Files

| File | Purpose |
|---|---|
| `menu.sh` | Launcher (open + app-cache refresh) |
| `menu.conf` | The dataset (labels, order, icons, handlers) |
| `menu.conf.sh` | Geometry/theme/cache paths |
| `actions.d/*` | One script per `run:<id>` |
| `gen-menus.sh` | Generates native submenu TOMLs from `menu.conf` |
| `sync-style.sh` | Generates Walker CSS from live Noctalia config |
| `elephant/menus/utilsearch.lua` | Global search provider (stateless) |
| `walker/config-snippet.toml` | Walker set/actions to merge |

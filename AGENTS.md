# utilmenu — AGENTS.md

Native Elephant submenus for navigation + one stateless Lua provider for
global search. One persistent Walker window, no `walker --dmenu`.

## Modell

```text
menu.conf (action|id|parent|glyph|label|handler|alias|desc)
  ├── gen-menus.sh → ~/.config/elephant/menus/utilmenu*.toml (Navigation, nativ)
  └── elephant/menus/utilsearch.lua → menus:utilsearch (Suche, zustandslos)
```

- Navigation = nativ: jede Kategorie ein eigenes TOML-Menü, Entries mit
  `submenu = "utilmenu_<id>"`. Walker `menus:open` + `ClearReload` navigiert
  im selben Fenster (kein close/reopen). Kein Lua-State, kein `UtilNavigate`.
- Suche = `menus:utilsearch`: Query leer → `{}`, sonst global über alle
  `parent != root` + Apps-Cache (Dedup: Menü-Eintrag gewinnt). Breadcrumb
  als Subtext. Run/Launch wie die nativen Menüs (`actions.d/`, `.desktop`).
- Walker-Set: `default = ["menus:utilsearch", "menus:utilmenu"]`,
  `empty = ["menus:utilmenu"]`.
- Styling: `sync-style.sh` liest echte Noctalia-Werte (`settings.toml` +
  Wallpaper-Palette) → Walker-CSS. Noctalia ist READ-ONLY.
- Icons = NF-Glyphen aus menu.conf-Hex (Design freeze, nie neu erfinden).

## Dateien

| Was | Wo (Repo) | Installiert nach |
|---|---|---|
| Launcher (open + Apps-Cache) | `menu.sh` | `~/.config/utilmenu2/menu.sh` |
| Daten (flach, parent_id) | `menu.conf` | `~/.config/utilmenu2/menu.conf` |
| Geometrie/Theme/Cache/Pfad | `menu.conf.sh` | `~/.config/utilmenu2/menu.conf.sh` |
| Aktionen | `actions.d/*` | `~/.config/utilmenu2/actions.d/` |
| Menü-Generator | `gen-menus.sh` | `~/.config/utilmenu2/gen-menus.sh` |
| Style-Sync | `sync-style.sh` | `~/.config/utilmenu2/sync-style.sh` |
| Search-Provider | `elephant/menus/utilsearch.lua` | `~/.config/elephant/menus/utilsearch.lua` |
| Legacy-Engine (retired, Referenz) | `elephant/menus/utilmenu.lua` | — (nicht installieren) |
| Walker-Set (Snippet zum Mergen) | `walker/config-snippet.toml` | `~/.config/walker/config.toml` |
| Keybind | niri `Mod+Shift+G` → `menu.sh` | — |

Install: siehe README.md. Nur das `utilmenu`-Set anfassen, kein globales
Launcher-Verhalten. `menu.sh` braucht `~/.local/bin` im PATH (elephant-Link).

## Fallen

- `menus:open` ohne `ClearReload` schließt das Fenster → `after`-Feld nie entfernen.
- Return doppelt binden (`open` + `default`) → Walker nimmt Close statt Navigation.
  Nur `open` auf Return; Run via Shift+Return.
- `quick_activate = []` global setzen, sonst F1–F4-Hints im Menü.
- `theme = "noctalia"` explizit — sonst läuft das Default-Theme.
- Walker-Service cached CSS → nach Style-Änderung Service neu starten.
- `elephant query` crasht CLI-seitig bei 0 Treffern (bekannt, kein Provider-Bug).
- Lua-Seite spawnt nichts pro Query (nur zwei kleine Dateien lesen);
  `nix search` hängt → nie im Menüpfad.
- Headless-Test Search-Lua: unter luajit mit `_UTILMENU_DIR`/`_UTILMENU_CACHE`
  auf Fixtures zeigen, nie walker.

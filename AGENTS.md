# utilmenu — AGENTS.md

Architektur: EIN globaler Datensatz, EIN persistentes Walker-Fenster,
Projektion = Filter. Backend = Elephant-`menus`-Provider (Lua),
kein `walker --dmenu` mehr.

## Modell

```text
ONE DATASET (menu.conf: action|id|parent|glyph|label|handler|alias|desc)
  → Elephant menus/utilmenu.lua (state = navstack)
  → Walker Set "utilmenu" (walker/config-snippet.toml)
  → query leer:    Kinder der aktuellen Id (GetEntries(""))
  → query gesetzt: GLOBALE Suche über alle parent!=root + Apps (GetEntries(q))
```

- Navigation = `UtilNavigate` pusht die Ziel-Id auf `state()`, `UtilBack`
  poppt; generisch über `submenu:<id>` bzw. Kinder-vorhanden
  (kein `if Apps/if Style`). Beliebige Tiefe (`Style › Themes › Haven`).
  Navigationszeilen tragen `open` UND `default` → beide navigieren (Return
  mit `ClearReload` bleibt im selben Fenster, vgl. Elephant-Issue #292).
- Ergebnis: `Text` = Label, `Icon` = Glyph aus menu.conf (unverändert),
  `Subtext` = Breadcrumb-Pfad (Suche) bzw. `Apps`.
- Apps: Cache `~/.cache/utilmenu-apps.list`, gelesen aus Lua (`apps`-Kinder
  bei leerem Query, global gefiltert bei Query) + nativem
  `desktopapplications`-Provider im selben Set.
- Persistent: `open`/`back`-Aktionen mit `after = "ClearReload"` → Walker
  fragt Elephant neu ab, statt zu schließen (vgl. Elephant-Issue #292:
  `after` steuert KeepOpen/Close). `default` (Run/Launch) bleibt Close.

## Dateien

| Was | Wo (Repo) | Installiert nach |
|---|---|---|
| Launcher (nur open + Apps-Cache) | `menu.sh` | `~/.config/utilmenu2/menu.sh` |
| Daten (flach, parent_id) | `menu.conf` | `~/.config/utilmenu2/menu.conf` |
| Geometrie/Theme/Cache/Pfad | `menu.conf.sh` | `~/.config/utilmenu2/menu.conf.sh` |
| Aktionen | `actions.d/*` (unverändert) | `~/.config/utilmenu2/actions.d/*` |
| Elephant-Menü (Engine) | `elephant/menus/utilmenu.lua` | `~/.config/elephant/menus/utilmenu.lua` |
| Walker-Set (Snippet zum Mergen) | `walker/config-snippet.toml` | `~/.config/walker/config.toml` |
| Keybind | niri `Mod+Shift+G` → `menu.sh` | — |

Install: `menu.sh`, `menu.conf`, `menu.conf.sh`, `actions.d/` nach
`~/.config/utilmenu2/`; Lua nach `~/.config/elephant/menus/`; Snippet in
Walkers `config.toml` mergen; `elephant` + `walker --gapplication-service`
laufen lassen. Kein Schritt davon fasst globales Launcher-Verhalten an —
nur das `utilmenu`-Set.

## Fallen

- `menus:open` ohne `ClearReload` schließt das Fenster → Navigation wäre
  wieder close/reopen. `after`-Feld im Snippet nie entfernen.
- `state()` ist pro Menü persistent: `UtilRun`/`UtilLaunchApp` resetten auf
  `{}`, sonst öffnet das nächste Mal die alte Ebene.
- Lua-Seite spawnt nichts pro Query (nur zwei kleine Dateien lesen);
  `nix search` hängt → nie im Menüpfad.
- Headless-Tests: Lua unter `lua5.1` mit `state`/`setState`-Stubs fahren
  (`_UTILMENU_DIR`/`_UTILMENU_CACHE` zeigen auf Fixtures), nie walker.
- Glyphen kommen aus menu.conf-Hex, nie neu erfinden (Design freeze).

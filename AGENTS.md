# utilmenu2 — AGENTS.md

Architektur: EIN globaler Datensatz, EIN warmes Walker-Service-Fenster,
Projektion = Filter. KEIN Elephant (nicht installiert), KEINE dmenu-Hacks
pro Ebene.

## Modell

```text
ONE DATASET (menu.conf: action|id|parent|glyph|label|handler|alias|desc)
  → Walker-Service-Fenster (warm: --gapplication-service + -k -e)
  → query leer:  Kinder von current_parent (nav_rows)
  → query gesetzt: globale Suche SEARCHABLE=1 + Desktop-Apps (search_rows)
```

- Navigation = `submenu:<id>` setzt `current_parent`, generisch (kein
  `if Apps/if Style`). Back = Parent aus `navstack`, selbes Fenster.
- Suche global, nicht auf Kontext begrenzt; Root (parent=root)
  `searchable=0`; Zwischenkategorien (Kinder vorhanden) suchbar →
  Auswahl navigiert hinein.
- Ergebniszeile: `glyph<TAB>label` (nav) bzw. `glyph<TAB>label<TAB>Pfad`
  (Suche, z.B. `Rebuild & Switch  Nixos`). IDs nur in IDMAP.
- Apps: Cache `~/.cache/utilmenu-apps.list`, dynamisch unter `apps`.

## Dateien

| Was | Wo |
|---|---|
| Engine | `~/.config/utilmenu2/menu.sh` |
| Daten (flach, parent_id) | `~/.config/utilmenu2/menu.conf` |
| Geometrie/Theme/Cache/Pfad | `~/.config/utilmenu2/menu.conf.sh` |
| Aktionen | `~/.config/utilmenu2/actions.d/*` (unverändert) |
| Keybind | niri `Mod+Shift+G` → `menu.sh` |

## Bekannte Grenze

Echtes In-Place-Update (kein Prozesswechsel pro Navigation) braucht den
Elephant-`menus`-Provider. Solange: warmes Service-Fenster (`-k`), gleiche
Geometrie/Styling, aber technisch relaunched `--dmenu` pro Ebene.
`walker --gapplication-service` allein macht daraus kein Custom-Menu.

## Fallen

- `walker --dmenu`-Rückgabe = `label`, Glyph kommt nie zurück → IDs nur IDMAP.
- `LIST | pick` in Subshell → IDMAP leer; erst Datei, dann pick.
- `nix search` hängt → nie im Menüpfad.
- Headless-Tests: nur Parser/Projektion sourcen (`head -n 97`), nie walker.

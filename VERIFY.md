# utilmenu — Install & Verify (target machine: NixOS + Niri/i3/Mango)

Repo → Ziel (alles unter `$HOME`, kein globaler Eingriff):

```sh
DEST=~/.config/utilmenu2
mkdir -p "$DEST/actions.d" ~/.config/elephant/menus
cp menu.sh menu.conf menu.conf.sh "$DEST/"
cp actions.d/* "$DEST/actions.d/"
cp elephant/menus/utilmenu.lua ~/.config/elephant/menus/utilmenu.lua
# walker/config-snippet.toml in ~/.config/walker/config.toml mergen
# (nur [providers.sets.utilmenu], [providers.actions."menus:utilmenu"],
#  [placeholders."menus:utilmenu"] — sonst nichts anfassen)
```

Voraussetzungen: `walker` + `elephant` + `elephant-menus`-Provider installiert
und laufend (`elephant &`, `walker --gapplication-service &`); Keybind
`Mod+Shift+G` → `~/.config/utilmenu2/menu.sh`.

## UI-Abnahme (live, eine Sitzung, ein Fenster)

1. **Root**: `menu.sh` → exakt 8 Zeilen `Apps Style Setup Install Remove
   Nixos About System` mit den Icons aus `menu.conf` (unverändert).
2. **Navigation**: `Apps` anklicken → SELBES Fenster (Position/Größe/
   Suchleiste identisch), neue Zeilen (Back + Apps-Cache). Gleiches für
   `Style`, `Setup`, `System`, `Themes`-Tiefe. Kein close/reopen-Flackern.
3. **Back**: In ein Submenü, dann `Zurück`/Escape → selbes Fenster, Root.
4. **Live global search**: An Root `wiremix` tippen → `Wiremix` erscheint
   WÄHREND des Tippens (kein Enter). Ebenso `haven` nach Hinzufügen von
   `action|themes|style|…` + `action|haven|themes|…` (beliebige Tiefe).
5. **Global in Submenü**: In `Apps` wechseln, `wiremix` (liegt unter Setup)
   tippen → trotzdem sichtbar. Query hängt nie vom Navigationskontext ab.
6. **Kein Enter**: Alle Suchen aktualisieren vor Enter (Elephant ruft
   `GetEntries(query)` pro Tastenschlag; Walker filtert nichts nach).
7. **Aktionen**: je eine aus Style (`Background`), Setup (`Network`),
   Nixos (`Version`), System (`Lock` bzw. ungefährlich: Screensaver),
   Apps (eine `.desktop`-App starten) auslösen.
8. **Apps**: App-Name tippen → Treffer mit Subtext `Apps`, Start klappt;
   Terminal-Apps öffnen sich in `foot`.

## Headless (hier / CI, ohne Walker/Elephant)

```sh
bash -n menu.sh
luac -p elephant/menus/utilmenu.lua
# Projektion/Suche/Aktionen unter lua5.1 mit state/setState-Stubs:
# siehe Test-Skript im Arbeitsprotokoll (ROOT/STYLE/THEMES/SEARCH-*)
```

Bestanden, wenn: Root=8 in menu.conf-Reihenfolge; Style=Back+4;
Tiefe 3 erreichbar; `wiremix`/`haven`/`firefox` live gefunden (auch aus
fremdem Kontext); Root-Labels nicht suchbar; `UtilRun` → passendes
`actions.d/`-Skript; fehlende `.desktop` → kein Spawn.

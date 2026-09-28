-- utilmenu panel v3: Suche IMMER global (wie Referenz), Navigation nur bei leerer Query.
-- Keine capture_keys für editier-Tasten (Backspace/Arrows gehören dem Input).
-- Hover via onHover-State statt Voll-Rebuild; Icons mit fester Box + Gap.

local CONF = (noctalia.getenv("HOME") or "") .. "/.config/utilmenu2/"
local CACHE = (noctalia.getenv("HOME") or "") .. "/.cache/utilmenu-apps.list"
local ICONDIR = (noctalia.getenv("HOME") or "") .. "/.cache/utilmenu-icons/"

local state = { path = {}, query = "", selected = 1, hover = 0, items = {}, menu = {}, apps = {} }

local function split(s, sep)
  local out, i, from = {}, 1, 1
  while true do
    local a, b = s:find(sep, from, true)
    if not a then out[i] = s:sub(from); break end
    out[i] = s:sub(from, a - 1); i = i + 1; from = b + 1
  end
  return out
end

local function tabler_char(hex)
  if not hex or hex == "" then return nil end
  local cp = tonumber(hex, 16)
  if not cp then return nil end
  if utf8 and utf8.char then
    local ok, ch = pcall(utf8.char, cp)
    if ok then return ch end
  end
  return nil
end

local function load_menu()
  local txt = noctalia.readFile(CONF .. "menu.conf")
  if not txt then return end
  local items = {}
  for line in (txt .. "\n"):gmatch("([^\n]*)\n") do
    if line ~= "" and line:sub(1, 1) ~= "#" then
      local p = split(line, "|")
      if #p >= 6 and p[1] == "action" and p[2] ~= "" then
        table.insert(items, {
          id = p[2], parent = (p[3] ~= "" and p[3] or "root"),
          icon = tabler_char(p[4]), label = (p[5] ~= "" and p[5] or p[2]),
          handler = p[6] or "", desc = p[8] or "",
        })
      end
    end
  end
  state.menu = items
end

local function recolor_path(name)
  return ICONDIR .. name:gsub("[^%w]", "_"):sub(1, 40) .. ".png"
end

local function load_apps()
  local txt = noctalia.readFile(CACHE)
  if not txt then return end
  local items = {}
  for line in (txt .. "\n"):gmatch("([^\n]*)\n") do
    local p = split(line, "\t")
    if #p >= 4 and p[2] ~= "" and p[3] ~= "" then
      local png = recolor_path(p[2])
      table.insert(items, { name = p[2], file = p[3], icon = p[4],
        png = (noctalia.readFile(png) ~= nil) and png or nil })
    end
  end
  state.apps = items
end

local function cur_cat()
  if #state.path == 0 then return "root" end
  return state.path[#state.path]
end

local function find_menu(id)
  for _, e in ipairs(state.menu) do
    if e.id == id then return e end
  end
  return nil
end

-- Referenz-Logik: Query leer -> Kategorie-Inhalt; Query gesetzt -> GLOBAL über alles.
local function rebuild()
  local out = {}
  local q = state.query:lower()
  if q == "" then
    local cat = cur_cat()
    for _, e in ipairs(state.menu) do
      if e.parent == cat then
        local h = e.handler or ""
        local is_sub = h:sub(1, 8) == "submenu:"
        table.insert(out, { id = "m:" .. e.id,
          label = e.label .. (is_sub and " ›" or ""),
          ticon = e.icon, desc = e.desc, kind = is_sub and "cat" or "run", data = e })
      end
    end
    if cat == "apps" then
      for _, a in ipairs(state.apps) do
        table.insert(out, { id = "a:" .. a.file, label = a.name,
          png = a.png, appicon = a.icon, kind = "app", data = a })
      end
    end
  else
    -- global: Menü-Einträge (parent != root) + Apps, mit Breadcrumb als desc
    for _, e in ipairs(state.menu) do
      if e.parent ~= "root" then
        local s = noctalia.fuzzyScore(q, e.label)
        if s ~= nil then
          local h = e.handler or ""
          local is_sub = h:sub(1, 8) == "submenu:"
          local pe = find_menu(e.parent)
          table.insert(out, { id = "m:" .. e.id,
            label = e.label .. (is_sub and " ›" or ""),
            ticon = e.icon, desc = pe and pe.label or e.desc,
            kind = is_sub and "cat" or "run", data = e, score = s })
        end
      end
    end
    for _, a in ipairs(state.apps) do
      local s = noctalia.fuzzyScore(q, a.name)
      if s ~= nil then
        table.insert(out, { id = "a:" .. a.file, label = a.name,
          png = a.png, appicon = a.icon, desc = "Apps",
          kind = "app", data = a, score = s })
      end
    end
    table.sort(out, function(x, y) return (x.score or 0) > (y.score or 0) end)
    if #out == 0 then
      table.insert(out, { id = "__noresults", label = "No match for '" .. state.query .. "'",
        desc = "keep typing or press Esc", kind = "none" })
    end
  end
  state.items = out
  if state.selected > #out then state.selected = math.max(1, #out) end
  if state.selected < 1 then state.selected = 1 end
end

local function breadcrumb()
  if #state.path == 0 then return "Utility Menu" end
  local names = {}
  for _, id in ipairs(state.path) do
    local e = find_menu(id)
    table.insert(names, e and e.label or id)
  end
  return table.concat(names, " › ")
end

local function icon_widget(it, active)
  local fg = active and "on_primary" or "on_surface"
  if it.png then
    return ui.image({ path = it.png, width = 22, height = 22 })
  end
  -- kein Wrapper: Row hat gap=12, Label trägt das Icon direkt (vertikal via paddingV der Row)
  if it.appicon and it.appicon ~= "" then
    return ui.label({ text = "▢ ", fontSize = 18, color = fg })
  end
  if it.ticon and it.ticon ~= "" then
    return ui.label({ text = it.ticon .. " ", fontSize = 17, color = fg })
  end
  return ui.glyph({ name = "settings", size = 16, color = fg })
end

function render()
  rebuild()
  local rows = {}
  for i, it in ipairs(state.items) do
    local active = (i == state.selected or i == state.hover)
    rows[#rows + 1] = ui.row(
      { fill = active and "primary" or "transparent",
        paddingH = 10, paddingV = 8, radius = 8, gap = 12,
        onClick = "onRowClick:" .. it.id, onHover = "onRowHover:" .. i },
      {
        icon_widget(it, active),
        ui.column({ gap = 2 }, {
          ui.label({ text = it.label, fontSize = 14,
            color = active and "on_primary" or "on_surface" }),
          it.desc and it.desc ~= "" and ui.label({ text = it.desc, fontSize = 11,
            color = active and "on_primary/0.7" or "on_surface_variant" }) or nil,
        }),
      })
    if #rows >= 12 then break end
  end
  panel.render(ui.column({ gap = 8, padding = 12 }, {
    ui.label({ text = breadcrumb(), fontSize = 11, color = "on_surface_variant" }),
    ui.input({ value = state.query, placeholder = "Search",
      focus = true, onChange = "onSearch", onSubmit = "onSubmit" }),
    ui.scroll({}, rows),
  }))
end

function onOpen()
  state.path = {}
  state.query = ""
  state.selected = 1
  state.hover = 0
  load_menu()
  load_apps()
  noctalia.runAsync({ "bash", CONF .. "refresh-apps.sh" }, function(r)
    if r.exitCode == 0 then load_apps() end
  end)
  render()
end

function onClose()
  state.path = {}
  state.query = ""
  state.selected = 1
  state.hover = 0
end

function onSearch(text)
  state.query = text or ""
  state.selected = 1
  state.hover = 0
  render()
end

function onSubmit()
  local it = state.items[state.selected]
  if it and it.kind ~= "none" then activate(it) end
end

function onRowClick(id)
  for i, it in ipairs(state.items) do
    if it.id == id then
      state.selected = i
      if it.kind ~= "none" then activate(it) end
      return
    end
  end
end

function onRowHover(idx)
  -- Hover folgt der Selektion OHNE Rebuild (kein Hover-Stau, kein Flackern)
  local n = tonumber(idx) or 0
  if n >= 1 and n <= #state.items and n ~= state.selected then
    state.selected = n
    state.hover = 0
    render()
  end
end

function activate(it)
  if it.kind == "cat" then
    table.insert(state.path, it.data.id)
    state.query = ""
    state.selected = 1
    state.hover = 0
    render()
    return
  end
  if it.kind == "app" then
    local f = it.data.file
    local script = "f='" .. f:gsub("'", "'\\''") .. "';"
      .. "term=$(grep -m1 '^Terminal=' \"$f\" | cut -d= -f2 | tr -d ' ');"
      .. "line=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/ %[fFuUick].*//;s/ %[FfUu]//');"
      .. "if [ \"$term\" = true ]; then wd=$(ls -t $XDG_RUNTIME_DIR/wayland-* 2>/dev/null | grep -v lock | head -1);"
      .. " wd=${wd##*/}; setsid env WAYLAND_DISPLAY=\"$wd\" foot $line >/dev/null 2>&1 &;"
      .. " else setsid sh -c \"$line\" >/dev/null 2>&1 & fi"
    noctalia.runAsync(script)
    panel.close()
    return
  end
  if it.kind == "none" then return end
  local h = it.data.handler or ""
  local run_id = h:sub(1, 4) == "run:" and h:sub(5) or it.data.id
  if run_id ~= "" and not run_id:find("/") then
    noctalia.runAsync({ "bash", CONF .. "actions.d/" .. run_id })
  end
  panel.close()
end

function onKey(chord, pressed)
  if not pressed then return end
  -- NUR Navigation (keine Edit-Tasten: die gehören dem Input)
  if chord == "escape" then
    if #state.path > 0 and state.query == "" then
      table.remove(state.path)
      state.selected = 1
      state.hover = 0
      render()
    else
      panel.close()
    end
  elseif chord == "down" then
    state.selected = math.min(state.selected + 1, #state.items)
    state.hover = 0
    render()
  elseif chord == "up" then
    state.selected = math.max(state.selected - 1, 1)
    state.hover = 0
    render()
  elseif chord == "enter" or chord == "right" then
    onSubmit()
  elseif chord == "left" then
    if #state.path > 0 then
      table.remove(state.path)
      state.query = ""
      state.selected = 1
      state.hover = 0
      render()
    else
      panel.close()
    end
  end
end

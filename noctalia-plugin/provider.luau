-- utilmenu provider v2: stateless pro Query, kein async-Reload während Suche.
-- menu.conf + App-Cache werden einmalig geladen, Refresh nur via Timer (alle 60s).

local CONF = (noctalia.getenv("HOME") or "") .. "/.config/utilmenu2/"
local CACHE = (noctalia.getenv("HOME") or "") .. "/.cache/utilmenu-apps.list"

local menu_items = {}
local app_items = {}
local last_refresh = 0

local function split(s, sep)
  local out, i = {}, 1
  for part in (s .. sep):gmatch("(.-)" .. sep) do
    out[i] = part; i = i + 1
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
  menu_items = items
end

local function load_apps()
  local txt = noctalia.readFile(CACHE)
  if not txt then return end
  local items = {}
  for line in (txt .. "\n"):gmatch("([^\n]*)\n") do
    local p = split(line, "\t")
    if #p >= 4 and p[2] ~= "" and p[3] ~= "" then
      table.insert(items, { name = p[2], file = p[3], icon = p[4] })
    end
  end
  app_items = items
end

local function maybe_refresh()
  local now = os.time()
  if now - last_refresh < 60 then return end
  last_refresh = now
  noctalia.runAsync({ "bash", CONF .. "refresh-apps.sh" }, function(r)
    if r.exitCode == 0 then load_apps() end
  end)
  load_menu()
end

load_menu()
load_apps()

local function menu_result(e, score)
  local h = e.handler or ""
  local is_sub = h:sub(1, 8) == "submenu:"
  return {
    id = "m:" .. e.id,
    title = e.label .. (is_sub and " ›" or ""),
    subtitle = (e.desc ~= "") and e.desc or nil,
    glyph = (e.icon and e.icon ~= "") and nil or "settings",
    badge = (e.icon and e.icon ~= "") and e.icon or nil,
    score = score,
  }
end

local function app_result(a, score)
  return {
    id = "a:" .. a.file,
    title = a.name,
    subtitle = nil,
    icon = (a.icon ~= "" and a.icon) and a.icon or "application",
    score = score,
  }
end

local function cat_results(cat, q, query_text)
  local out = {}
  for _, e in ipairs(menu_items) do
    if e.parent == cat then
      local s = 1
      if q ~= "" then
        local fs = noctalia.fuzzyScore(q, e.label)
        if fs == nil then goto continue end
        s = fs
      end
      table.insert(out, menu_result(e, s))
      if #out >= 50 then break end
    end
    ::continue::
  end
  if cat == "apps" then
    for _, a in ipairs(app_items) do
      local s = 1
      if q ~= "" then
        local fs = noctalia.fuzzyScore(q, a.name)
        if fs == nil then goto continue2 end
        s = fs
      end
      table.insert(out, app_result(a, s))
      if #out >= 50 then break end
    end
    ::continue2::
  end
  launcher.setResults(query_text, out)
end

function onQuery(text)
  maybe_refresh()
  local raw = text or ""
  local t = raw:match("^%s*(.-)%s*$") or ""
  if t:sub(1, 1) == ":" then
    local cat, q = t:match("^:(%S+)%s*(.*)$")
    if not cat or cat == "" then cat = t:sub(2) end
    q = ((q or ""):lower())
    cat_results(cat, q, raw)
    return
  end
  local q = t:lower()
  if q == "" then
    local out = {}
    for _, e in ipairs(menu_items) do
      if e.parent == "root" then
        table.insert(out, {
          id = "m:" .. e.id,
          title = e.label,
          subtitle = (e.desc ~= "") and e.desc or nil,
          badge = (e.icon and e.icon ~= "") and e.icon or nil,
          glyph = (e.icon and e.icon ~= "") and nil or "folder",
        })
      end
    end
    launcher.setResults(raw, out)
    return
  end
  if #q < 2 then
    launcher.setResults(raw, {})
    return
  end
  local out = {}
  for _, e in ipairs(menu_items) do
    if e.parent ~= "root" then
      local s = noctalia.fuzzyScore(q, e.label)
      if s ~= nil then
        table.insert(out, menu_result(e, s))
        if #out >= 50 then break end
      end
    end
  end
  if #out < 50 then
    for _, a in ipairs(app_items) do
      local s = noctalia.fuzzyScore(q, a.name)
      if s ~= nil then
        table.insert(out, app_result(a, s))
        if #out >= 50 then break end
      end
    end
  end
  table.sort(out, function(x, y) return (x.score or 0) > (y.score or 0) end)
  launcher.setResults(raw, out)
end

local function find_menu(id)
  for _, e in ipairs(menu_items) do
    if e.id == id then return e end
  end
  return nil
end

function onActivate(id)
  if not id or id == "" then return end
  if id:sub(1, 2) == "a:" then
    local f = id:sub(3)
    local script = "f='" .. f:gsub("'", "'\\''") .. "';"
      .. "term=$(grep -m1 '^Terminal=' \"$f\" | cut -d= -f2 | tr -d ' ');"
      .. "line=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/ %[fFuUick].*//;s/ %[FfUu]//');"
      .. "if [ \"$term\" = true ]; then wd=$(ls -t $XDG_RUNTIME_DIR/wayland-* 2>/dev/null | grep -v lock | head -1);"
      .. " wd=${wd##*/}; setsid env WAYLAND_DISPLAY=\"$wd\" foot $line >/dev/null 2>&1 &;"
      .. " else setsid sh -c \"$line\" >/dev/null 2>&1 & fi"
    noctalia.runAsync(script)
    return
  end
  if id:sub(1, 2) ~= "m:" then return end
  local e = find_menu(id:sub(3))
  if not e then return end
  local h = e.handler or ""
  if h:sub(1, 8) == "submenu:" then
    launcher.setQuery("/u :" .. h:sub(9) .. " ")
    return
  end
  local run_id = h:sub(1, 4) == "run:" and h:sub(5) or e.id
  if run_id == "" or run_id:find("/") then return end
  noctalia.runAsync({ "bash", CONF .. "actions.d/" .. run_id })
end

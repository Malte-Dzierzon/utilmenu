-- utilmenu.lua — ONE persistent Elephant menu for utilmenu.
--
-- Model:
--   menu.conf (action|id|parent|glyph-hex|label|handler|alias|desc) = ONE dataset.
--   state() = navigation stack (array of ids, empty = root) = current projection.
--   GetEntries("")    -> children of current id (+ Back + apps, if applicable).
--   GetEntries(query) -> GLOBAL live search over all searchable entries + apps.
-- No process is spawned per query; only two small files are read.
--
-- Walker side (see walker/config-snippet.toml):
--   open/back -> ClearReload (same window, re-query), default -> Close (run).

Name = "utilmenu"
NamePretty = "Utilmenu"
FixedOrder = true
SearchName = false

local BACK_LABEL = "Zurück"
local BACK_CP = 0xF060

local function utf8_of(cp)
  cp = math.floor(tonumber(cp) or 0)
  if cp < 0x80 then
    return string.char(cp)
  elseif cp < 0x800 then
    return string.char(0xC0 + math.floor(cp / 64), 0x80 + (cp % 64))
  elseif cp < 0x10000 then
    return string.char(0xE0 + math.floor(cp / 4096),
      0x80 + (math.floor(cp / 64) % 64), 0x80 + (cp % 64))
  else
    return string.char(0xF0 + math.floor(cp / 262144),
      0x80 + (math.floor(cp / 4096) % 64),
      0x80 + (math.floor(cp / 64) % 64), 0x80 + (cp % 64))
  end
end

local function trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function base_dir()
  if _UTILMENU_DIR ~= nil and _UTILMENU_DIR ~= "" then return _UTILMENU_DIR end
  local xdg = os.getenv("XDG_CONFIG_HOME")
  if xdg ~= nil and xdg ~= "" then return xdg .. "/utilmenu2" end
  return (os.getenv("HOME") or "") .. "/.config/utilmenu2"
end

local function cache_file()
  if _UTILMENU_CACHE ~= nil and _UTILMENU_CACHE ~= "" then return _UTILMENU_CACHE end
  local x = os.getenv("XDG_CACHE_HOME")
  if x ~= nil and x ~= "" then return x .. "/utilmenu-apps.list" end
  return (os.getenv("HOME") or "") .. "/.cache/utilmenu-apps.list"
end

local function split_fields(line)
  local f = {}
  local i = 1
  for part in (line .. "|"):gmatch("(.-)|") do
    f[i] = part
    i = i + 1
  end
  return f
end

local function load_dataset()
  local order = {}
  local by_id = {}
  local children = {}
  local path = base_dir() .. "/menu.conf"
  local fh = io.open(path, "r")
  if fh == nil then
    return { order = order, by_id = by_id, children = children, err = path }
  end
  for line in fh:lines() do
    if line ~= "" and line:sub(1, 1) ~= "#" then
      local f = split_fields(line)
      if f[1] == "action" and f[2] ~= nil and f[2] ~= "" then
        local id = f[2]
        local parent = (f[3] == nil or f[3] == "") and "root" or f[3]
        local cp = tonumber(f[4], 16)
        local e = {
          id = id,
          parent = parent,
          icon = (cp ~= nil) and utf8_of(cp) or "•",
          label = (f[5] ~= nil and f[5] ~= "") and f[5] or id,
          handler = f[6] or "",
          alias = f[7] or "",
          desc = f[8] or "",
        }
        by_id[id] = e
        table.insert(order, id)
        if children[parent] == nil then children[parent] = {} end
        table.insert(children[parent], id)
      end
    end
  end
  fh:close()
  return { order = order, by_id = by_id, children = children }
end

local function has_children(ds, id)
  local c = ds.children[id]
  return c ~= nil and #c > 0
end

local function nav_target(e, ds)
  local h = e.handler or ""
  if h:sub(1, 8) == "submenu:" then return h:sub(9) end
  -- Zwischenkategorien (Kinder vorhanden) sind suchbar UND navigierbar:
  -- Auswahl navigiert hinein (UtilNavigate via open UND default).
  if has_children(ds, e.id) then return e.id end
  return nil
end

local function nav_entry(e, ds)
  local t = nav_target(e, ds)
  if t ~= nil and t ~= "" then
    -- open = Return mit ClearReload (bleibt offen); default = Fallback,
    -- falls Walker die benannte Aktion nicht auflöst — navigiert genauso.
    return { Text = e.label, Icon = e.icon, Value = t,
      Actions = { open = "lua:UtilNavigate", default = "lua:UtilNavigate" } }
  end
  return { Text = e.label, Icon = e.icon, Value = e.id,
    Actions = { default = "lua:UtilRun" } }
end

local function breadcrumb(ds, id)
  local parts = {}
  local x = id
  while true do
    local e = ds.by_id[x]
    if e == nil then break end
    local p = e.parent
    if p == nil or p == "root" then break end
    local pe = ds.by_id[p]
    if pe ~= nil then table.insert(parts, 1, pe.label)
    else table.insert(parts, 1, p) end
    x = p
  end
  return table.concat(parts, " › ")
end

local function search_entry(e, ds)
  local base = nav_entry(e, ds)
  base.Subtext = breadcrumb(ds, e.id)
  return base
end

local function entry_matches(e, terms)
  local hay = (e.label .. " " .. e.alias .. " " .. e.id .. " " .. e.desc):lower()
  for i = 1, #terms do
    if not hay:find(terms[i], 1, true) then return false end
  end
  return true
end
-- filter_ql nil -> all rows; otherwise whole-query substring on the app name.
local function load_apps(filter_ql)
  local res = {}
  local fh = io.open(cache_file(), "r")
  if fh == nil then return res end
  for line in fh:lines() do
    local name, file = line:match("^[^\t]*\t([^\t]*)\t(.*)$")
    if name ~= nil and name ~= "" and file ~= nil and file ~= "" then
      if filter_ql == nil or name:lower():find(filter_ql, 1, true) then
        table.insert(res, { name = name, file = file })
      end
    end
  end
  fh:close()
  return res
end

function GetEntries(query)
  local ds = load_dataset()
  if ds.err ~= nil then
    return { { Text = "menu.conf fehlt", Subtext = ds.err } }
  end
  local q = trim(query)
  local out = {}
  if q == "" then
    local st = state()
    local cur = "root"
    if #st > 0 then cur = st[#st] end
    if cur ~= "root" then
      table.insert(out, { Text = BACK_LABEL, Icon = utf8_of(BACK_CP),
        Value = "__back", Actions = { back = "lua:UtilBack" } })
    end
    local kids = ds.children[cur] or {}
    for i = 1, #kids do
      table.insert(out, nav_entry(ds.by_id[kids[i]], ds))
    end
    if cur == "apps" then
      local apps = load_apps(nil)
      for i = 1, #apps do
        table.insert(out, { Text = apps[i].name, Subtext = "Apps",
          Value = apps[i].file, Actions = { default = "lua:UtilLaunchApp" } })
      end
    end
  else
    local ql = q:lower()
    local terms = {}
    for w in ql:gmatch("%S+") do table.insert(terms, w) end
    for i = 1, #ds.order do
      local e = ds.by_id[ds.order[i]]
      if e.parent ~= "root" and entry_matches(e, terms) then
        table.insert(out, search_entry(e, ds))
      end
    end
    local apps = load_apps(ql)
    for i = 1, #apps do
      table.insert(out, { Text = apps[i].name, Subtext = "Apps",
        Value = apps[i].file, Actions = { default = "lua:UtilLaunchApp" } })
    end
  end
  return out
end

function UtilNavigate(value, args, query)
  local st = state()
  table.insert(st, value)
  setState(st)
end

function UtilBack(value, args, query)
  local st = state()
  if #st > 0 then table.remove(st) end
  setState(st)
end

function UtilRun(value, args, query)
  setState({})
  local script = base_dir() .. "/actions.d/" .. tostring(value or "")
  local fh = io.open(script, "r")
  if fh == nil then
    os.execute("notify-send 'utilmenu' 'Aktion nicht gefunden: "
      .. tostring(value or "") .. "' >/dev/null 2>&1 &")
    return
  end
  fh:close()
  os.execute("bash '" .. script:gsub("'", "'\\''") .. "' >/dev/null 2>&1 &")
end

function UtilLaunchApp(value, args, query)
  setState({})
  local path = tostring(value or "")
  local term = false
  local exec = nil
  local fh = io.open(path, "r")
  if fh == nil then return end
  for line in fh:lines() do
    if line == "Terminal=true" then term = true end
    if exec == nil and line:sub(1, 5) == "Exec=" then exec = line:sub(6) end
    if term and exec ~= nil then break end
  end
  fh:close()
  if exec == nil or exec == "" then return end
  exec = exec:gsub(" %%[fFuUick]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if exec == "" then return end
  if term then
    os.execute("setsid foot bash -lc '" .. exec:gsub("'", "'\\''")
      .. "; read -rp \"Enter \" _' >/dev/null 2>&1 &")
  else
    os.execute("setsid " .. exec .. " >/dev/null 2>&1 &")
  end
end

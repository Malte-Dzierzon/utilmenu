-- utilsearch.lua — SEARCH-ONLY Provider. Kein State, keine Navigation.
-- Query leer -> {}. Query gesetzt -> global über menu.conf (parent!=root) + Apps-Cache.
-- Run-Aktionen nutzen dieselben actions.d-Skripte wie die nativen TOML-Menüs.
Name = "utilsearch"
NamePretty = "Utilsearch"
FixedOrder = true
SearchName = false

local function trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end
local function base_dir()
  if _UTILMENU_DIR ~= nil and _UTILMENU_DIR ~= "" then return _UTILMENU_DIR end
  return (os.getenv("HOME") or "") .. "/.config/utilmenu2"
end
local function cache_file()
  if _UTILMENU_CACHE ~= nil and _UTILMENU_CACHE ~= "" then return _UTILMENU_CACHE end
  return (os.getenv("HOME") or "") .. "/.cache/utilmenu-apps.list"
end
local function utf8_of(cp)
  cp = math.floor(tonumber(cp) or 0)
  if cp <= 0 or cp > 0x10FFFF then return "" end
  if cp < 0x80 then return string.char(cp)
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
local function split_fields(line)
  local f = {}
  local i = 1
  for part in (line .. "|"):gmatch("(.-)|") do f[i] = part; i = i + 1 end
  return f
end
local function load_dataset()
  local order = {}
  local by_id = {}
  local path = base_dir() .. "/menu.conf"
  local fh = io.open(path, "r")
  if fh == nil then return { order = order, by_id = by_id, err = path } end
  for line in fh:lines() do
    if line ~= "" and line:sub(1, 1) ~= "#" then
      local f = split_fields(line)
      if f[1] == "action" and f[2] ~= nil and f[2] ~= "" then
        local cp = tonumber(f[4], 16)
        by_id[f[2]] = {
          id = f[2], parent = (f[3] == nil or f[3] == "") and "root" or f[3],
          icon = (cp ~= nil) and utf8_of(cp) or "•",
          label = (f[5] ~= nil and f[5] ~= "") and f[5] or f[2],
          handler = f[6] or "", alias = f[7] or "", desc = f[8] or "",
        }
        table.insert(order, f[2])
      end
    end
  end
  fh:close()
  return { order = order, by_id = by_id }
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
local function entry_matches(e, terms)
  local hay = (e.label .. " " .. e.alias .. " " .. e.id .. " " .. e.desc):lower()
  for i = 1, #terms do
    if not hay:find(terms[i], 1, true) then return false end
  end
  return true
end

function GetEntries(query)
  local q = trim(query)
  if q == "" then return {} end
  local ds = load_dataset()
  if ds.err ~= nil then return {} end
  local ql = q:lower()
  local terms = {}
  for w in ql:gmatch("%S+") do table.insert(terms, w) end
  local out = {}
  local have = {}
  for i = 1, #ds.order do
    local e = ds.by_id[ds.order[i]]
    if e.parent ~= "root" and entry_matches(e, terms) then
      local h = e.handler or ""
      if h:sub(1, 4) == "run:" then
        table.insert(out, { Text = e.label, Icon = e.icon, Subtext = breadcrumb(ds, e.id),
          Value = h:sub(5), Actions = { default = "lua:UtilSearchRun" } })
      else
        table.insert(out, { Text = e.label, Icon = e.icon, Subtext = breadcrumb(ds, e.id),
          Value = e.id, Actions = { default = "lua:UtilSearchRun" } })
      end
      have[e.label:lower()] = true
    end
  end
  local fh = io.open(cache_file(), "r")
  if fh ~= nil then
    for line in fh:lines() do
      local name, file, icon = line:match("^[^\t]*\t([^\t]*)\t([^\t]*)\t?(.*)$")
      if name ~= nil and name ~= "" and file ~= nil and file ~= "" then
        if name:lower():find(ql, 1, true) and not have[name:lower()] then
          local e = { Text = name, Subtext = "Apps",
            Value = file, Actions = { default = "lua:UtilSearchLaunch" } }
          local safe = name:gsub("[^%w]", "_"):sub(1, 40)
          local rc = (os.getenv("HOME") or "") .. "/.cache/utilmenu-icons/" .. safe .. ".png"
          local rf = io.open(rc, "r")
          if rf ~= nil then rf:close(); e.Icon = rc
          elseif icon ~= nil and icon ~= "" then e.Icon = icon end
          table.insert(out, e)
        end
      end
    end
    fh:close()
  end
  if #out == 0 then
    local dt = (#q == 1) and q or ("No match for '" .. q .. "'")
    return { { Text = dt, Subtext = "keep typing or press Esc",
      Value = "__noresults" } }
  end
  return out
end

function UtilSearchRun(value, args, query)
  local script = base_dir() .. "/actions.d/" .. tostring(value or "")
  os.execute("bash '" .. script:gsub("'", "'\\''") .. "' >/dev/null 2>&1 &")
end
function UtilSearchLaunch(value, args, query)
  local f = tostring(value or "")
  local qf = "'" .. f:gsub("'", "'\\''") .. "'"
  local term = io.popen("grep -m1 '^Terminal=' " .. qf .. " 2>/dev/null | cut -d= -f2- | tr -d ' \\n'")
  local is_tui = false
  if term ~= nil then is_tui = (trim(term:read("*a") or "") == "true"); term:close() end
  local ex = io.popen("grep -m1 '^Exec=' " .. qf .. " 2>/dev/null | cut -d= -f2- | sed 's/ %[fFuUick].*//' | tr -d '\\n'")
  local line = ""
  if ex ~= nil then line = trim(ex:read("*a") or ""); ex:close() end
  if line == "" then return end
  -- erstes Wort = Binary, Rest = Args (nicht alles in ein Quote packen)
  local bin, args = line:match("^(%S+)%s*(.*)$")
  if bin == nil or bin == "" then return end
  local function shq(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
  if is_tui then
    local te = os.getenv("TERM_EMULATOR") or "foot"
    os.execute("setsid " .. te .. " " .. bin:gsub("'", "'\\''") .. (args ~= "" and " " .. args or "") .. " >/dev/null 2>&1 &")
  elseif args ~= "" and bin:find("foot", 1, true) then
    -- Exec bringt sein eigenes foot mit (tui-*.desktop): direkt starten
    os.execute("setsid " .. bin:gsub("'", "'\\''") .. " " .. args .. " >/dev/null 2>&1 &")
  else
    os.execute("setsid " .. shq(bin) .. (args ~= "" and " " .. args or "") .. " >/dev/null 2>&1 &")
  end
end

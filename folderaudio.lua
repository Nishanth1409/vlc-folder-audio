--[[
  folderaudio.lua — VLC 3.x interface (auto-loaded via extraintf=luaintf)

  Language comes from the folder under any ".../Movies/<Lang>/..." path
  (tolerates common spelling mistakes).

  Supported: eng/English, Kannada, Hindi, Tamil, Telugu
  Among matches → highest quality. If language missing → VLC default.
]]

local FOLDER_LANGS = {
  eng = { "eng", "english", "en" },
  english = { "eng", "english", "en" },
  kannada = { "kan", "kannada", "kn" },
  kan = { "kan", "kannada", "kn" },
  hindi = { "hin", "hindi", "hi" },
  hin = { "hin", "hindi", "hi" },
  tamil = { "tam", "tamil", "ta" },
  tam = { "tam", "tamil", "ta" },
  telugu = { "tel", "telugu", "te" },
  tel = { "tel", "telugu", "te" },
}

-- Common misspellings / shortcuts → canonical key in FOLDER_LANGS
local FOLDER_ALIASES = {
  kannada = "kannada", kannad = "kannada", kannadda = "kannada",
  cannad = "kannada", cannada = "kannada", kanada = "kannada",
  kannda = "kannada", kan = "kannada", kn = "kannada",
  hindi = "hindi", hindee = "hindi", hindhi = "hindi", hind = "hindi",
  hin = "hindi", hi = "hindi",
  tamil = "tamil", thamil = "tamil", tamizh = "tamil",
  tam = "tamil", ta = "tamil",
  telugu = "telugu", thelugu = "telugu", telgu = "telugu", telegu = "telugu",
  tel = "telugu", te = "telugu",
  eng = "eng", english = "eng", en = "eng",
}

local last_uri = nil
local last_applied = nil
local assert_until = {}
local tries = {}
local preferred = {} -- uri → { prefs=..., id=... }

local function lower(s)
  if not s then return "" end
  return string.lower(tostring(s))
end

local function decode_path(uri)
  if not uri then return nil end
  local path = vlc.strings.decode_uri(uri)
  path = path:gsub("^file:///", "")
  path = path:gsub("^file://", "")
  path = path:gsub("^/([A-Za-z]):", "%1:")
  path = path:gsub("\\", "/")
  return lower(path)
end

local function resolve_folder_key(name)
  if not name or name == "" then return nil end
  local n = lower(name):gsub("%s+", "")
  if FOLDER_LANGS[n] then return n end
  local alias = FOLDER_ALIASES[n]
  if alias and FOLDER_LANGS[alias] then return alias end
  if n:find("kannad", 1, true) or n:find("cannad", 1, true) then return "kannada" end
  if n:find("hindi", 1, true) or n:find("hindee", 1, true) then return "hindi" end
  if n:find("tamil", 1, true) or n:find("thamil", 1, true) or n:find("tamizh", 1, true) then return "tamil" end
  if n:find("telugu", 1, true) or n:find("thelugu", 1, true) or n:find("telegu", 1, true) then return "telugu" end
  if n:find("english", 1, true) or n == "eng" then return "eng" end
  return nil
end

local function folder_prefs(path)
  if not path then return nil end
  local idx = path:find("/movies/", 1, true)
  if idx then
    local rest = path:sub(idx + #"/movies/")
    local folder = rest:match("^([^/]+)")
    local key = resolve_folder_key(folder)
    if key then return FOLDER_LANGS[key] end
  end
  local best = nil
  for segment in path:gmatch("[^/]+") do
    local key = resolve_folder_key(segment)
    if key then best = FOLDER_LANGS[key] end
  end
  return best
end

-- Match language from VLC track label only (Lua 5.1 safe).
-- Do NOT use loose substring checks that hit "1TamilMV".
local function lang_rank(text, prefs)
  if not prefs then return 0 end
  local t = lower(text or "")
  local norm = " " .. t:gsub("[%[%]%(%),:;|/\\]", " ") .. " "

  for i, code in ipairs(prefs) do
    local rank = (#prefs - i + 1) * 100
    if t:find("%[" .. code .. "%]", 1) then return rank end
    if #code >= 3 and norm:find(" " .. code .. " ", 1, true) then return rank end
  end
  return 0
end

local function quality_score(text)
  local t = lower(text or "")
  local score = 0
  if t:find("atmos", 1, true) or t:find("truehd", 1, true) then score = score + 50000000 end
  if t:find("dts%-hd") or t:find("dtshd", 1, true) then score = score + 45000000 end
  if t:find("eac3", 1, true) or t:find("dd%+", 1) or t:find("ddp", 1, true) or t:find("dd+", 1, true) then
    score = score + 30000000
  end
  if t:find("ac3", 1, true) or t:find("ac%-3") then score = score + 20000000 end
  if t:find("aac", 1, true) then score = score + 5000000 end

  if t:find("7%.1", 1, true) then score = score + 8000000
  elseif t:find("5%.1", 1, true) then score = score + 6000000
  elseif t:find("2%.0", 1, true) or t:find("stereo", 1, true) then score = score + 2000000
  end

  local br = t:match("(%d+)%s*kbps")
  if br then score = score + tonumber(br) * 100 end
  return score
end

local function collect_tracks(input)
  local tracks = {}
  local values, texts = vlc.var.get_list(input, "audio-es")
  if not values then return tracks end
  for i, id in ipairs(values) do
    local nid = tonumber(id)
    if nid and nid >= 0 then
      local text = (texts and texts[i]) and tostring(texts[i]) or ("track " .. tostring(i))
      table.insert(tracks, { id = id, text = text, combined = lower(text) })
    end
  end
  return tracks
end

local function pick_best(tracks, prefs)
  if not prefs or #tracks == 0 then return nil end
  local best_id, best_score = nil, -1
  local matched = false
  for _, tr in ipairs(tracks) do
    local lr = lang_rank(tr.combined, prefs)
    if lr > 0 then
      matched = true
      local score = lr * 100000000 + quality_score(tr.combined)
      -- Prefer earlier ES id only as tiny tie-break (higher quality already dominates)
      score = score - (tonumber(tr.id) or 0)
      if score > best_score then
        best_score = score
        best_id = tr.id
      end
    end
  end
  if not matched then return nil end
  return best_id
end

local function apply_for_uri(uri)
  local path = decode_path(uri)
  local prefs = folder_prefs(path)
  if not prefs then return true end

  local input = vlc.object.input()
  if not input then return false end

  -- Help VLC's own track picker too (comma list)
  pcall(function()
    vlc.var.set(input, "audio-language", table.concat(prefs, ","))
  end)
  pcall(function()
    vlc.config.set("audio-language", prefs[1])
  end)

  local tracks = collect_tracks(input)
  if #tracks == 0 then return false end

  local best = pick_best(tracks, prefs)
  if not best then return true end

  preferred[uri] = { prefs = prefs, id = best }
  local cur = vlc.var.get(input, "audio-es")
  if tostring(cur) ~= tostring(best) then
    vlc.var.set(input, "audio-es", best)
    vlc.msg.info("[folderaudio] " .. table.concat(prefs, "/") .. " → audio-es=" .. tostring(best)
      .. " from track text")
  end
  return true
end

local function reassert(uri)
  local pref = preferred[uri]
  if not pref then return end
  local input = vlc.object.input()
  if not input then return end
  local cur = vlc.var.get(input, "audio-es")
  if tostring(cur) ~= tostring(pref.id) then
    vlc.var.set(input, "audio-es", pref.id)
  end
end

while true do
  pcall(function()
    local item = vlc.input.item()
    if item then
      local uri = item:uri()
      if uri and uri ~= "" then
        if uri ~= last_uri then
          last_uri = uri
          last_applied = nil
          tries[uri] = 0
          preferred[uri] = nil
          assert_until[uri] = vlc.misc.mdate() + 6000000 -- keep enforcing 6s
        end

        local now = vlc.misc.mdate()
        if last_applied ~= uri then
          tries[uri] = (tries[uri] or 0) + 1
          local ok = apply_for_uri(uri)
          if ok or tries[uri] >= 40 then
            last_applied = uri
          end
        elseif assert_until[uri] and now < assert_until[uri] then
          reassert(uri)
        end
      end
    else
      last_uri = nil
      last_applied = nil
    end
  end)
  vlc.misc.mwait(vlc.misc.mdate() + 250000)
end

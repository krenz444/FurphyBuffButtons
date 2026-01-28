-- ====================================
-- \Core\Base.lua
-- ====================================
-- This file initializes the core addon namespace, database, and basic utility functions.

local addonName, ns = ...
ns = ns or {}
_G[addonName] = ns -- Expose namespace globally

-- Initialize global database tables if they don't exist
ClickableRaidBuffsDB   = ClickableRaidBuffsDB   or {}
ClickableRaidData      = ClickableRaidData      or {}
clickableRaidBuffCache = clickableRaidBuffCache or {}
clickableRaidBuffCache.displayable                 = clickableRaidBuffCache.displayable                 or {}
clickableRaidBuffCache.playerInfo                  = clickableRaidBuffCache.playerInfo                  or {}
clickableRaidBuffCache.functions                   = clickableRaidBuffCache.functions                   or {}
clickableRaidBuffCache.functions.bagsPendingScan   = clickableRaidBuffCache.functions.bagsPendingScan   or {}

-- Constants
ns.CORNER_TEXT_FIELD = "qty"
ns.BASE_ICON_SIZE    = ns.BASE_ICON_SIZE or 50

-- Returns the main database table
function ns.GetDB()
  return ClickableRaidBuffsDB
end

-- Creates a shallow copy of an item data table
function ns.copyItemData(data)
  local copy = {}
  for k, v in pairs(data) do copy[k] = v end
  return copy
end

-- Wrapper for C_Item.GetItemCount to get item quantity
function getQuantity(itemID)
  return C_Item.GetItemCount(itemID, false, false, false, false)
end

-- Recursively copies a table
local function copyTable(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k,v in pairs(t) do
    o[k] = (type(v) == "table") and copyTable(v) or v
  end
  return o
end

-- Applies default values to the database
local function applyDefaults(db, defaults)
  if type(defaults) ~= "table" then return end
  for k, v in pairs(defaults) do
    if db[k] == nil then
      db[k] = (type(v) == "table") and copyTable(v) or v
    end
  end
end

-- Ensures a color table has r, g, b, a values
local function ensureColor(db, key)
  local c = db[key]
  if type(c) ~= "table" then
    db[key] = { r=1, g=1, b=1, a=1 }
    return
  end
  c.r = tonumber(c.r) or 1
  c.g = tonumber(c.g) or 1
  c.b = tonumber(c.b) or 1
  c.a = tonumber(c.a) or 1
end

-- Derives missing database values from defaults or other settings
local function deriveMissing(db, D)
  if db.timerSize      == nil then db.timerSize      = db.bottomSize or (D and D.bottomSize) end
  if db.timerOutline   == nil then
    local bo = db.bottomOutline
    if bo == nil and D and D.bottomOutline ~= nil then bo = D.bottomOutline end
    db.timerOutline = (bo ~= false)
  end
  if db.timerTextColor == nil then
    db.timerTextColor = copyTable(db.bottomTextColor or (D and D.bottomTextColor) or { r=1,g=1,b=1,a=1 })
  end

  if db.centerSize      == nil then db.centerSize      = db.timerSize      or (D and D.centerSize) end
  if db.centerOutline   == nil then
    local co = db.timerOutline
    if co == nil and D and D.centerOutline ~= nil then co = D.centerOutline end
    db.centerOutline = (co ~= false)
  end
  if db.centerTextColor == nil then
    db.centerTextColor = copyTable(db.timerTextColor or (D and D.centerTextColor) or { r=1,g=1,b=1,a=1 })
  end

  ensureColor(db, "topTextColor")
  ensureColor(db, "bottomTextColor")
  ensureColor(db, "timerTextColor")
  ensureColor(db, "centerTextColor")
  ensureColor(db, "cornerTextColor")
end

-- Frame to handle addon loading and initialization
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
  if name ~= addonName then return end

  if type(ClickableRaidBuffsDB) ~= "table" then
    ClickableRaidBuffsDB = {}
  end
  local db = ClickableRaidBuffsDB

  local O = ns.Options or {}
  local D = O.DEFAULTS or {}

  applyDefaults(db, D)
  deriveMissing(db, D)

  loader:UnregisterEvent("ADDON_LOADED")
end)

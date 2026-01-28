-- ====================================
-- \Options\Defaults.lua
-- ====================================
-- This file defines the default settings for the addon.

local addonName, ns = ...
ns.Options = ns.Options or {}
local O = ns.Options

-- Default configuration values
local D = {
  fontName = "Oswald-Medium",

  topSize    = 14,
  bottomSize = 14,
  timerSize  = 22,
  topOutline    = true,
  bottomOutline = true,
  timerOutline  = true,
  topTextColor    = { r=1, g=1, b=1, a=1 },
  bottomTextColor = { r=1, g=1, b=1, a=1 },
  timerTextColor  = { r=1, g=1, b=1, a=1 },

  glowEnabled       = true,
  specialGlowColor  = { r=0.35, g=0.80, b=1.00, a=1 },
  glowColor         = { r=1.00, g=0.90, b=0.20, a=1 },

  iconSize = 50,
  hSpace   = 10,
  vSpace   = 45,
}

O.DEFAULTS = D

-- Retrieves a default value by key.
-- Returns a copy for tables to prevent modification of the default table.
function O.GetDefault(key)
  local v = D[key]
  if type(v) == "table" then
    local copy = {}
    for k, vv in pairs(v) do copy[k] = vv end
    return copy
  end
  return v
end

-- ====================================
-- \UI\Glow.lua
-- ====================================
-- This file handles the pixel glow effect on buttons using LibCustomGlow.

local addonName, ns = ...
local GlowLib = LibStub and LibStub("LibCustomGlow-1.0", true)

local function DB() return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {} end
local FALLBACK_SPECIAL = { r = 0.00, g = 0.9137, b = 1.00, a = 1 }
local FALLBACK_GENERAL = { r = 0.95, g = 0.95,  b = 0.32, a = 1 }

-- Ensures a color table has valid RGBA values.
local function safeColor(tbl, fallback)
  if type(tbl) == "table" then
    return {
      r = tonumber(tbl.r or tbl[1]) or 1,
      g = tonumber(tbl.g or tbl[2]) or 1,
      b = tonumber(tbl.b or tbl[3]) or 1,
      a = tonumber(tbl.a or tbl[4]) or 1,
    }
  end
  return { r = fallback.r, g = fallback.g, b = fallback.b, a = fallback.a or 1 }
end

-- Checks if two RGBA colors are the same.
local function sameRGBA(a, b)
  if not a or not b then return false end
  return a[1]==b[1] and a[2]==b[2] and a[3]==b[3] and (a[4] or 1)==(b[4] or 1)
end

-- Enables or disables the glow effect on a button.
local function ensureGlow(btn, shouldEnable, color, size)
  if not GlowLib or not btn then return end

  if not shouldEnable then
    if btn._crb_glow_enabled then
      GlowLib.PixelGlow_Stop(btn)
      btn._crb_glow_enabled = false
      btn._crb_glow_rgba = nil
      btn._crb_glow_size = nil
    end
    return
  end

  local rgba = { color.r, color.g, color.b, color.a or 1 }
  size = size or 50
  local N = 8
  local frequency = 0.25
  local length = (10 / 50) * size
  local th     = ( 1 / 50) * size

  if btn._crb_glow_enabled then
    if not sameRGBA(btn._crb_glow_rgba, rgba) or btn._crb_glow_size ~= size then
      GlowLib.PixelGlow_Stop(btn)
      btn._crb_glow_enabled = false
    end
  end
  if not btn._crb_glow_enabled then
    GlowLib.PixelGlow_Start(btn, rgba, N, frequency, length, 1, th)
    btn._crb_glow_enabled = true
    btn._crb_glow_rgba = rgba
    btn._crb_glow_size = size
  end
end

-- Selects the appropriate glow color for an entry.
local function pickColorForEntry(db, entry, general, special)
  if not entry then return general end
  if entry.glow == "special" then return special end
  return general
end

-- Refreshes the glow effect on all active buttons.
function ns.RefreshGlow()
  local d = DB()
  local enabled = (d.glowEnabled ~= false)
  local general = safeColor(d.glowColor,        FALLBACK_GENERAL)
  local special = safeColor(d.specialGlowColor, FALLBACK_SPECIAL)

  local frames = ns.RenderFrames
  if not frames or not GlowLib then return end

  local size = d.iconSize or 50
  for i = 1, #frames do
    local btn = frames[i]
    if btn and btn:IsShown() then
      local entry = btn._crb_entry
      local color = pickColorForEntry(d, entry, general, special)
      ensureGlow(btn, enabled, color, size)
    end
  end
end

-- Sets the general glow color and state.
if type(ns.SetGlow) ~= "function" then
  function ns.SetGlow(enabled, r, g, b, a)
    local d = DB()
    d.glowEnabled = enabled and true or false
    d.glowColor   = { r = r or FALLBACK_GENERAL.r, g = g or FALLBACK_GENERAL.g,
                      b = b or FALLBACK_GENERAL.b, a = a or FALLBACK_GENERAL.a }
    if ns.RefreshGlow then ns.RefreshGlow() end
    if ns.PushRender then ns.PushRender() elseif ns.RenderAll then ns.RenderAll() end
  end
end

-- Sets the special glow color.
if type(ns.SetSpecialGlow) ~= "function" then
  function ns.SetSpecialGlow(r, g, b, a)
    local d = DB()
    d.specialGlowColor = { r = r or FALLBACK_SPECIAL.r, g = g or FALLBACK_SPECIAL.g,
                           b = b or FALLBACK_SPECIAL.b, a = a or FALLBACK_SPECIAL.a }
    if ns.RefreshGlow then ns.RefreshGlow() end
    if ns.PushRender then ns.PushRender() elseif ns.RenderAll then ns.RenderAll() end
  end
end

-- Ensures glow is applied to a specific button.
if type(ns.EnsureGlow) ~= "function" then
  function ns.EnsureGlow(btn, enabled, color, size)
    if not btn then return end
    local d = DB()
    if not color then
      color = safeColor(d.glowColor, FALLBACK_GENERAL)
    end
    size = size or d.iconSize or 50
    ensureGlow(btn, enabled and (d.glowEnabled ~= false), color, size)
  end
end

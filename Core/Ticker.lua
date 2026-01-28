-- ====================================
-- \Core\Ticker.lua
-- ====================================
-- This file handles delayed refresh updates to avoid excessive rendering.

local addonName, ns = ...
ns = ns or {}

local _pending = false

-- Schedules a refresh of the addon's display.
-- Uses a timer to debounce multiple requests.
-- Skipped during combat.
function ns.StartRefreshTicker()
  if InCombatLockdown() then return end
  if _pending then return end
  _pending = true
  C_Timer.After(0.05, function()
    _pending = false
    if InCombatLockdown() then return end
    if ns.RenderAll then ns.RenderAll() end
  end)
end

-- ====================================
-- \UI\Anchor.lua
-- ====================================
-- This file handles the positioning and saving of the main addon frame anchor.

local addonName, ns = ...
furphyBuffCache = furphyBuffCache or {}

local function InCombat() return InCombatLockdown() end
local function DB() return (ns.GetDB and ns.GetDB()) or FurphyBuffButtonsDB or {} end

-- Retrieves the main parent frame.
local function EnsureParent()
  return ns and ns.RenderParent
end

-- Reads the current anchor point of a frame.
local function ReadPoint(frame)
  local p, rel, rp, x, y = frame:GetPoint(1)
  if not p then
    return "TOP", "UIParent", "TOP", 0, -10
  end
  local relName = (rel and rel.GetName and rel:GetName()) or "UIParent"
  return p, relName, rp or "TOP", x or 0, y or 0
end

-- Applies the saved anchor position from the database.
-- Skipped during combat.
local function ApplySavedAnchor()
  if InCombat() then
    furphyBuffCache._anchor_pending = true
    return
  end
  local parent = EnsureParent()
  if not parent then return end

  local db = DB()
  db.anchor = db.anchor or { point="TOP", relative="UIParent", relativePoint="TOP", x=0, y=-60 }

  -- One-time migration: convert old CENTER-based anchor to new TOP-based default
  if db.anchor.point == "CENTER" and db.anchor.relativePoint == "CENTER" then
    db.anchor.point = "TOP"
    db.anchor.relativePoint = "TOP"
    db.anchor.x = 0
    db.anchor.y = -60
    if db.position then
      db.position.x = 0
      db.position.y = -60
    end
  end

  local point, relative, relativePoint, x, y =
      db.anchor.point, db.anchor.relative, db.anchor.relativePoint, db.anchor.x, db.anchor.y

  parent:SetClampedToScreen(true)
  parent:ClearAllPoints()
  parent:SetPoint(point or "TOP", _G[relative or "UIParent"] or UIParent, relativePoint or "TOP", x or 0, y or -10)

  parent._fbb_anchor_applied = true
  furphyBuffCache._anchor_pending = nil
end

-- Saves the current anchor position to the database.
local function SaveAnchor()
  local parent = EnsureParent()
  if not parent then return end
  local p, rel, rp, x, y = ReadPoint(parent)
  local db = DB()
  db.anchor = db.anchor or {}
  db.anchor.point         = p
  db.anchor.relative      = rel or "UIParent"
  db.anchor.relativePoint = rp or "TOP"
  db.anchor.x             = x or 0
  db.anchor.y             = y or 0
end

-- Hooks drag events to save the anchor position.
local function HookDragSavers()
  local parent = EnsureParent()
  if not parent or parent._fbb_anchor_hooks then return end

  parent:HookScript("OnDragStop", SaveAnchor)
  parent:HookScript("OnMouseUp",  SaveAnchor)
  parent._fbb_anchor_hooks = true
end

-- Attempts to setup the anchor.
local function TrySetup()
  local parent = EnsureParent()
  if parent then
    HookDragSavers()
    ApplySavedAnchor()
    return true
  end
  return false
end

-- Event handler for loading and saving anchor position.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_LOGOUT")

f:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    if not TrySetup() then
      C_Timer.After(0.05, TrySetup)
      C_Timer.After(0.50, TrySetup)
      C_Timer.After(1.00, TrySetup)
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if furphyBuffCache._anchor_pending then
      ApplySavedAnchor()
    end
  elseif event == "PLAYER_LOGOUT" then
    SaveAnchor()
  end
end)

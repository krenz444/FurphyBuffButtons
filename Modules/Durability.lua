-- ====================================
-- \Modules\Durability.lua
-- ====================================
-- This module monitors equipment durability and provides a button to summon a repair mount if durability is low.

local addonName, ns = ...

clickableRaidBuffCache = clickableRaidBuffCache or {}
clickableRaidBuffCache.displayable = clickableRaidBuffCache.displayable or {}

-- Determine faction-specific Traveler's Tundra Mammoth ID
local englishFaction, _ = UnitFactionGroup("player")
local ttmID = nil
if englishFaction == "Alliance" then ttmID = 280 elseif englishFaction == "Horde" then ttmID = 284 end

local CAT = "DURABILITY"
local REPAIR_ICON_ID = 136241
-- List of preferred repair mounts in priority order
local PREFERRED_MOUNT_IDS = { ns and ns.SelectedMount, 1039, 460, 2237, ttmID }
local chosenMountID = nil

local function DB() return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {} end
local function InCombat() return InCombatLockdown() end

local function IsDeadOrGhost()
  return UnitIsDeadOrGhost("player")
end

-- Retrieves the durability threshold percentage from settings.
local function getDurabilityThreshold()
  local db = DB()
  local t = db.durabilityThreshold or db.durabilityPercent or db.durability or 20
  if t < 0 then t = 0 end
  if t > 100 then t = 100 end
  return t
end

-- Selects the best available repair mount based on what the player has collected.
local function refreshChosenMount()
  chosenMountID = nil
  if not C_MountJournal or not C_MountJournal.GetMountInfoByID then return end
  PREFERRED_MOUNT_IDS[1] = ns and ns.SelectedMount
  for _, id in ipairs(PREFERRED_MOUNT_IDS) do
    if id then
      local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(id)
      if isCollected then
        chosenMountID = id
        break
      end
    end
  end
end

-- Calculates the lowest durability percentage among equipped items.
local function lowestEquippedDurabilityPercent()
  local minPct = nil
  for slot = 1, 19 do
    if slot ~= 4 and slot ~= 18 then -- Skip shirt and tabard
      local cur, max = GetInventoryItemDurability(slot)
      if cur and max and max > 0 then
        local pct = (cur / max) * 100
        if not minPct or pct < minPct then
          minPct = pct
        end
      end
    end
  end
  if not minPct then
    return 100
  end
  return math.floor(minPct + 0.5)
end

-- Ensures the display category for durability exists.
local function ensureCat()
  clickableRaidBuffCache.displayable[CAT] = clickableRaidBuffCache.displayable[CAT] or {}
  return clickableRaidBuffCache.displayable[CAT]
end

-- Clears the durability display category.
local function clearCat()
  if clickableRaidBuffCache.displayable[CAT] then
    wipe(clickableRaidBuffCache.displayable[CAT])
  end
end

-- Rebuilds the durability display list.
-- Skipped during combat.
local function Build()
  if InCombat() then
    clearCat()
    return
  end

  local threshold = getDurabilityThreshold()
  local pct = lowestEquippedDurabilityPercent()

  local out = ensureCat()
  wipe(out)

  if pct < threshold then
    local macro
    if chosenMountID then
      macro = "/run C_MountJournal.SummonByID(" .. tostring(chosenMountID) .. ")"
    else
      -- Fallback to Grand Expedition Yak if no specific mount is chosen/found
      macro = "/run local id=460 if C_MountJournal.GetMountInfoByID and select(11, C_MountJournal.GetMountInfoByID(id)) then C_MountJournal.SummonByID(id) end"
    end

    local e = {
      id        = -9101,
      isItem    = true,
      category  = CAT,
      name      = DURABILITY,
      spellID   = nil,
      itemID    = nil,
      icon      = REPAIR_ICON_ID,
      topLbl    = "",
      btmLbl    = MINIMAP_TRACKING_REPAIR,
      macro     = macro,
      orderHint = 1,
      quantity  = pct,
    }
    out["repair"] = e
  end
end

-- Updates the button text to show durability percentage.
local function AppendPercentAfterRender()
  if not ns.RenderFrames then return end
  for _, btn in ipairs(ns.RenderFrames) do
    if btn:IsShown() and btn._crb_entry and btn._crb_entry.category == CAT then
      if not btn._crb_center_from_cd then
        local q = btn._crb_entry.quantity
        local txt = (q and q > 0) and (tostring(q) .. "%") or ""
        if btn._crb_centerText ~= txt then
          btn.centerText:SetText(txt)
          btn._crb_centerText = txt
        end
      end
    end
  end
end

-- Hooks RenderAll to update durability text.
local function EnsureRenderHook()
  if ns._durability_wrapped then return end
  if type(ns.RenderAll) == "function" then
    local orig = ns.RenderAll
    ns.RenderAll = function(...)
      Build()
      local r = orig(...)
      AppendPercentAfterRender()
      return r
    end
    ns._durability_wrapped = true
  end
end
EnsureRenderHook()
C_Timer.After(0.05, EnsureRenderHook)
C_Timer.After(0.5, EnsureRenderHook)

-- Public API to rebuild durability display.
function ns.Durability_Rebuild()
  Build()
  if ns.RenderAll and not InCombat() then ns.RenderAll() end
end

-- Public API to refresh the chosen repair mount.
function ns.Durability_RefreshChosenMount()
  if type(refreshChosenMount) == "function" then
    refreshChosenMount()
  end
end

-- Initializes the selected mount from the database.
local function initSelectedFromDB()
  local d = DB(); d.mounts = d.mounts or {}
  local sel = d.mounts.selectedMount
  if type(sel) == "number" then
    ns.SelectedMount = sel
  else
    ns.SelectedMount = nil
  end
  refreshChosenMount()
end
initSelectedFromDB()

-- Sets the selected repair mount.
function ns.Durability_SetSelectedMount(id)
  local d = DB(); d.mounts = d.mounts or {}
  d.mounts.selectedMount = tonumber(id) or nil
  ns.SelectedMount = d.mounts.selectedMount
  refreshChosenMount()
  ns.Durability_Rebuild()
end

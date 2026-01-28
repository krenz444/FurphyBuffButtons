-- ====================================
-- \Modules\Healthstone.lua
-- ====================================
-- This module handles the display of Healthstones and Soulwells for Warlocks and other classes.

local addonName, ns = ...

clickableRaidBuffCache = clickableRaidBuffCache or {}
clickableRaidBuffCache.displayable = clickableRaidBuffCache.displayable or {}

local CAT = "HEALTHSTONE"

local ITEM_HEALTHSTONE          = 5512
local ITEM_DEMONIC_HEALTHSTONE  = 224464

local SPELL_CREATE_HEALTH       = 6201
local SPELL_DEMONIC_HEALTH      = 386689
local SPELL_SOULWELL            = 29893
local SPELL_HEALTHSTONE_USE     = 6262

local ICON_HEALTHSTONE          = 538745
local ICON_DEMONIC_HEALTHSTONE  = 538744
local ICON_SOULWELL             = 136194

local function DB() return (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {} end

local function InCombat() return InCombatLockdown() end
local function IsDeadOrGhostNow() return UnitIsDeadOrGhost("player") end
local function PlayerIsWarlock() local _,c=UnitClass("player"); return c=="WARLOCK" end
local function IsRested() return (clickableRaidBuffCache.playerInfo and clickableRaidBuffCache.playerInfo.restedXPArea) or IsResting() end
local function InInstance() return (clickableRaidBuffCache.playerInfo and clickableRaidBuffCache.playerInfo.inInstance) or select(1, IsInInstance()) end
local function IsGrouped() return IsInGroup() or IsInRaid() end

-- Retrieves exclusion sets from the database.
local function _ExSets()
  local d = DB()
  d.exclusions = d.exclusions or {}
  d.raidBuffExclusions = d.raidBuffExclusions or {}
  return d.exclusions, d.raidBuffExclusions
end

-- Checks if an ID is excluded.
local function IsExcludedID(id)
  if not id then return false end
  local ex, rb = _ExSets()
  return (ex[id] or rb[id]) and true or false
end

-- Checks if Healthstones are globally excluded.
local function IsHealthstoneGloballyExcluded()
  return IsExcludedID(ITEM_HEALTHSTONE) or IsExcludedID(ITEM_DEMONIC_HEALTHSTONE)
end

-- Counts the number of Healthstone charges in bags.
local function CountCharges(itemID)
  local ok, n = pcall(C_Item.GetItemCount, itemID, false, true)
  if ok and n then return n end
  return C_Item.GetItemCount(itemID, false) or 0
end

-- Finds the bag and slot of an item.
local function FindItemBagSlot(itemID)
  for bag=0,NUM_BAG_SLOTS do
    local slots=C_Container.GetContainerNumSlots(bag)
    if slots and slots>0 then
      for slot=1,slots do
        local id=C_Container.GetContainerItemID(bag,slot)
        if id==itemID then return bag,slot end
      end
    end
  end
end

-- Checks if there is a Warlock in the group.
-- Skipped during combat.
local function HasWarlockInGroup()
  if InCombat() then return false end -- UnitClass returns secret in combat
  if IsInRaid() then
    for i=1,GetNumGroupMembers() do
      local _,class=UnitClass("raid"..i)
      if class=="WARLOCK" then return true end
    end
  elseif IsInGroup() then
    for i=1,GetNumGroupMembers()-1 do
      local _,class=UnitClass("party"..i)
      if class=="WARLOCK" then return true end
    end
  end
  return false
end

-- Ensures the display category for Healthstones exists.
local function ensureCat()
  clickableRaidBuffCache.displayable[CAT]=clickableRaidBuffCache.displayable[CAT] or {}
  return clickableRaidBuffCache.displayable[CAT]
end

-- Clears the Healthstone display category.
local function clearCat()
  if clickableRaidBuffCache.displayable[CAT] then wipe(clickableRaidBuffCache.displayable[CAT]) end
end

ns.HealthstoneSoulwellVisible = true
-- Toggles Soulwell visibility.
local function FlipSoulwell(show)
  local new = not not show
  if ns.HealthstoneSoulwellVisible ~= new then
    ns.HealthstoneSoulwellVisible = new
  end
end

local soulwellTimer
-- Cancels any pending Soulwell wake timer.
local function CancelSoulwellWake()
  if soulwellTimer and soulwellTimer.Cancel then soulwellTimer:Cancel() end
  soulwellTimer = nil
end

-- Reads spell cooldown information.
local function ReadSpellCooldown(spellID)
  if GetSpellCooldown then
    local start, dur, enable = GetSpellCooldown(spellID)
    return start or 0, dur or 0, enable or 0
  end
  if C_Spell and C_Spell.GetSpellCooldown then
    local cd = C_Spell.GetSpellCooldown(spellID)
    if type(cd) == "table" then
      local start  = cd.startTime or 0
      local dur    = cd.duration  or 0
      local enable = (cd.isEnabled and 1) or 0
      return start, dur, enable
    end
  end
  return 0, 0, 0
end

-- Checks remaining cooldown of a spell.
local function SpellCooldownRemaining(spellID)
  local start, dur, enable = ReadSpellCooldown(spellID)
  if enable ~= 1 or not dur or dur <= 1.5 or not start or start <= 0 then
    return false, 0, 0
  end
  local endsAt = start + dur
  local left = endsAt - GetTime()
  if left < 0 then left = 0 end
  return left > 0, left, endsAt
end

-- Schedules a rebuild when Soulwell cooldown finishes.
local function ScheduleSoulwellWake(seconds)
  CancelSoulwellWake()
  if seconds and seconds > 0 then
    soulwellTimer = C_Timer.NewTimer(seconds + 0.05, function()
      if InCombat() or IsDeadOrGhostNow() then return end
      Build()
      if ns.RenderAll then ns.RenderAll() end
    end)
  end
end

-- Rebuilds the Healthstone display list.
-- Skipped during combat.
function Build(fromRender)
  if InCombat() then clearCat(); CancelSoulwellWake(); return end
  if IsDeadOrGhostNow() then clearCat(); CancelSoulwellWake(); return end
  if IsRested() then clearCat(); CancelSoulwellWake(); return end

  local out = ensureCat(); wipe(out)

  local threshold     = tonumber(DB().healthstoneThreshold) or 1
  local isLock        = PlayerIsWarlock()
  local knowsDemonic  = IsPlayerSpell and IsPlayerSpell(SPELL_DEMONIC_HEALTH) or false
  local knowsSoulwell = IsPlayerSpell and IsPlayerSpell(SPELL_SOULWELL) or false

  local hsExcluded = IsHealthstoneGloballyExcluded()

  if not isLock then
    local haveHS = CountCharges(ITEM_HEALTHSTONE)
    local haveLockInGroup = HasWarlockInGroup()
    if not haveLockInGroup and haveHS == 0 then
      CancelSoulwellWake()
      return
    end
    if (not hsExcluded) and (haveHS <= threshold) then
      out["hs:nonlock"] = {
        category  = CAT,
        icon      = ICON_HEALTHSTONE,
        quantity  = haveHS,
        showZeroCenter = true,
        id        = ITEM_HEALTHSTONE,
      }
    end
    CancelSoulwellWake()
    return
  end

  if not hsExcluded then
    if isLock and not knowsDemonic then
      local charges = CountCharges(ITEM_HEALTHSTONE)
      if charges <= threshold then
        out["hs:lock:classic"] = {
          category  = CAT,
          icon      = ICON_HEALTHSTONE,
          quantity  = charges,
          showZeroCenter = true,
          spellID   = SPELL_CREATE_HEALTH,
          rightClickSame = true,
          id        = ITEM_HEALTHSTONE,
        }
      end
    else
      local charges = CountCharges(ITEM_DEMONIC_HEALTHSTONE)
      if charges <= threshold then
        out["hs:lock:demonic"] = {
          category  = CAT,
          icon      = ICON_DEMONIC_HEALTHSTONE,
          quantity  = charges,
          showZeroCenter = true,
          spellID   = SPELL_CREATE_HEALTH,
          rightClickSame = true,
          id        = ITEM_DEMONIC_HEALTHSTONE,
        }
      end
      if not hsExcluded then
        local bag, slot = FindItemBagSlot(ITEM_HEALTHSTONE)
        if bag and slot then
          out["hs:lock:delete-old"] = {
            category   = CAT,
            icon       = ICON_HEALTHSTONE,
            quantity   = nil,
            showZeroCenter = true,
            macro      = "/run C_Container.PickupContainerItem("..bag..","..slot..")",
            specAtlas  = "common-icon-redx",
            orderHint  = 90,
            id         = ITEM_HEALTHSTONE,
          }
        end
      end
    end
  end

  do
    if IsExcludedID(SPELL_SOULWELL) then
      CancelSoulwellWake()
      return
    end
    if not knowsSoulwell then
      CancelSoulwellWake()
      return
    end
    if not ns.HealthstoneSoulwellVisible then
      CancelSoulwellWake()
      return
    end
    if not InInstance() then
      CancelSoulwellWake()
      return
    end
    if not IsGrouped() then
      CancelSoulwellWake()
      return
    end
    local onCD, left = SpellCooldownRemaining(SPELL_SOULWELL)
    if onCD then
      ScheduleSoulwellWake(left)
      return
    end
    CancelSoulwellWake()
    out["hs:lock:soulwell"] = {
      category  = CAT,
      icon      = ICON_SOULWELL,
      spellID   = SPELL_SOULWELL,
      orderHint = 100,
      isFixed   = true,
    }
  end
end

-- Public API to rebuild Healthstone display.
function ns.Healthstone_Rebuild()
  Build()
end

-- Applies visual fixups after rendering.
local function AfterRenderFixups()
  if not ns.RenderFrames then return end
  for _, btn in ipairs(ns.RenderFrames) do
    if btn:IsShown() and btn._crb_entry and btn._crb_entry.category == CAT then
      local e = btn._crb_entry
      if e.specAtlas == "common-icon-redx" and btn.rankOverlay then
        btn.rankOverlay:SetAtlas("common-icon-redx", true)
        local w,h = btn:GetWidth(), btn:GetHeight()
        if w and h and w > 0 and h > 0 then
          btn.rankOverlay:SetSize(w,h)
        end
        btn.rankOverlay:ClearAllPoints()
        btn.rankOverlay:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.rankOverlay:SetAlpha(1)
        btn.rankOverlay:Show()
      end
    end
  end
end

-- Hooks RenderAll to apply fixups.
local function EnsureRenderHook()
  if ns._healthstone_wrapped then return end
  if type(ns.RenderAll) == "function" then
    local orig = ns.RenderAll
    ns.RenderAll = function(...)
      Build(true)
      local r = orig(...)
      AfterRenderFixups()
      return r
    end
    ns._healthstone_wrapped = true
  end
end
EnsureRenderHook()
C_Timer.After(0.05, EnsureRenderHook)
C_Timer.After(0.5, EnsureRenderHook)

-- Ensures Soulwell is listed in exclusions for Warlocks.
local function EnsureSoulwellListedInExclusions()
  local root = _G.ClickableRaidData or {}
  root.ALL_RAID_BUFFS_BY_CLASS = root.ALL_RAID_BUFFS_BY_CLASS or {}
  root.ALL_RAID_BUFFS_BY_CLASS.WARLOCK = root.ALL_RAID_BUFFS_BY_CLASS.WARLOCK or {}
  local wl = root.ALL_RAID_BUFFS_BY_CLASS.WARLOCK
  if type(wl) == "table" and wl[SPELL_SOULWELL] == nil then
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(SPELL_SOULWELL)
    wl[SPELL_SOULWELL] = {
      name     = (info and info.name) or "Ritual of Souls",
      spellID  = SPELL_SOULWELL,
      check    = "player",
      target   = "player",
    }
    root.ALL_RAID_BUFFS_BY_CLASS[9] = root.ALL_RAID_BUFFS_BY_CLASS[9] or {}
    local wl9 = root.ALL_RAID_BUFFS_BY_CLASS[9]
    if wl9 and wl9[SPELL_SOULWELL] == nil then
      wl9[SPELL_SOULWELL] = wl[SPELL_SOULWELL]
    end
  end
end
C_Timer.After(0.10, EnsureSoulwellListedInExclusions)

-- Event handlers
function ns.Healthstone_OnPEW()
  FlipSoulwell(true)
  Build()
  return true
end

function ns.Healthstone_OnPlayerUpdateResting()
  Build()
  return true
end

function ns.Healthstone_OnZoneChanged()
  Build()
  return true
end

function ns.Healthstone_OnBagUpdate()
  Build()
  return true
end

function ns.Healthstone_OnBagUpdateDelayed()
  Build()
  return true
end

function ns.Healthstone_OnSpellsChanged()
  Build()
  return true
end

function ns.Healthstone_OnRegenDisabled()
  FlipSoulwell(true)
  clearCat()
  CancelSoulwellWake()
  return true
end

function ns.Healthstone_OnRegenEnabled()
  Build()
  return true
end

function ns.Healthstone_OnPlayerDead()
  clearCat()
  CancelSoulwellWake()
  return true
end

function ns.Healthstone_OnGroupRosterUpdate()
  FlipSoulwell(true)
  Build()
  return true
end

function ns.Healthstone_OnPlayerUnghost()
  FlipSoulwell(true)
  Build()
  return true
end

function ns.Healthstone_OnEncounterEnd()
  FlipSoulwell(true)
  Build()
  return true
end

-- Handles combat log events (currently disabled/restricted).
function ns.Healthstone_OnCombatLogEventUnfiltered()
  -- CLEU is restricted, this function is effectively disabled or needs alternative trigger
  return false
end

function ns.Healthstone_OnUnitSpellcastSucceeded(unit, _, spellID)
  if unit=="player" and spellID==SPELL_SOULWELL then
    FlipSoulwell(false)
    Build()
    return true
  end
  return false
end

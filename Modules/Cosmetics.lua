-- ====================================
-- \Modules\Cosmetics.lua
-- ====================================
-- This module handles the tracking and display of cosmetic items (toys, etc.).

local addonName, ns = ...

local function DB() return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {} end
local function GetCosmeticSet() local d=DB(); d.cosmetics=d.cosmetics or {}; return d.cosmetics end

-- Checks if an item is excluded by user settings.
local function IsExcluded(id)
  local d = DB()
  d.exclusions = d.exclusions or {}
  d.raidBuffExclusions = d.raidBuffExclusions or {}
  return (d.exclusions[id] or d.raidBuffExclusions[id]) and true or false
end

-- Seeds default exclusions for cosmetic items on first load.
local function SeedDefaultCosmeticExclusions()
  local d = DB()
  d.exclusions = d.exclusions or {}
  local ex = d.exclusions
  local data = _G.ClickableRaidData and _G.ClickableRaidData["COSMETIC"]
  if type(data) ~= "table" then return end
  for itemID in pairs(data) do
    if type(itemID) == "number" and ex[itemID] == nil then
      ex[itemID] = true
    end
  end
  if ns.Exclusions and ns.Exclusions.MarkDirty then ns.Exclusions.MarkDirty() end
end

local _active = nil
-- Rebuilds the set of active cosmetic items based on user settings.
function ns.Cosmetics_RebuildActive()
  _active = nil
  local enabled = GetCosmeticSet()
  local any = false
  for k, v in pairs(enabled) do if v == true then any = true; break end end
  if any then
    _active = {}
    for k, v in pairs(enabled) do if v == true then _active[k] = true end end
  end
end

-- Initialize on login.
local _login = CreateFrame("Frame")
_login:RegisterEvent("PLAYER_LOGIN")
_login:SetScript("OnEvent", function()
  SeedDefaultCosmeticExclusions()
  ns.Cosmetics_RebuildActive()
end)

clickableRaidBuffCache = clickableRaidBuffCache or {}
clickableRaidBuffCache.playerInfo = clickableRaidBuffCache.playerInfo or {}
clickableRaidBuffCache.displayable = clickableRaidBuffCache.displayable or {}

-- Ensures the display category for cosmetics exists.
local function ensureCategory()
  clickableRaidBuffCache.displayable["COSMETIC"] = clickableRaidBuffCache.displayable["COSMETIC"] or {}
  return clickableRaidBuffCache.displayable["COSMETIC"]
end

-- Updates cooldown information for an item entry.
local function applyItemCooldownFields(entry, itemID)
  local start, duration, enable = GetItemCooldown(itemID)
  if enable == 1 and duration and duration > 1.5 and start and start > 0 then
    entry.cooldownStart    = start
    entry.cooldownDuration = duration
  else
    entry.cooldownStart    = nil
    entry.cooldownDuration = nil
  end
end

-- Checks expiration time for a cosmetic buff.
local function cosmeticExpireFor(data)
  if type(data) ~= "table" then return nil end
  local ids = data.buffID
  if not ids then return nil end
  if type(ids) == "number" then ids = { ids } end
  if type(ids) ~= "table" or not next(ids) then return nil end
  if ns.GetPlayerBuffExpire then
    return ns.GetPlayerBuffExpire(ids, true, false)
  end
  return nil
end

-- Determines if an item should be shown based on its expiration time and threshold.
local function applyThreshold(entry, expireAbs, thresholdMin)
  local threshold = (thresholdMin or (DB().itemThreshold or 15)) * 60
  entry.expireTime = expireAbs
  if not expireAbs then entry.showAt = nil; return true end
  if expireAbs == math.huge then entry.showAt = nil; return false end
  local showAt = expireAbs - threshold
  if GetTime() < showAt then entry.showAt = showAt; return false else entry.showAt = nil; return true end
end

-- Gathers environment data for gate checking.
-- Skipped during combat.
local function envForGates()
  if InCombatLockdown() then return 0, false, false end
  local pi = clickableRaidBuffCache.playerInfo or {}
  local lvl = pi.playerLevel or UnitLevel("player") or 0
  local inInst = (pi.inInstance ~= nil) and pi.inInstance or select(1, IsInInstance())
  local rested = (pi.restedXPArea ~= nil) and pi.restedXPArea or IsResting()
  return lvl, inInst, rested
end

-- Checks if an item passes gating requirements.
local function passesGates(data)
  if not ns or not ns.PassesGates then return true end
  local lvl, inInst, rested = envForGates()
  return ns.PassesGates(data, lvl, inInst, rested)
end

-- Scans a specific bag for cosmetic items.
-- Skipped during combat.
local function scanBagsCosmetics(bagID)
  if InCombatLockdown() then return end
  local dataTbl = _G.ClickableRaidData and _G.ClickableRaidData["COSMETIC"]
  if type(dataTbl) ~= "table" then return end
  local cat = ensureCategory()
  if bagID == 0 then wipe(cat) end
  local numSlots = C_Container.GetContainerNumSlots(bagID)
  if numSlots == 0 then return end
  for slot = 1, numSlots do
    local itemID = C_Container.GetContainerItemID(bagID, slot)
    local data = itemID and dataTbl[itemID]
    if itemID and data and not IsExcluded(itemID) and passesGates(data) then
      if (not _active) or _active[itemID] then
        local qty = C_Item.GetItemCount(itemID, false, false, false, false) or 0
        if qty > 0 then
          local base = (ns.copyItemData and ns.copyItemData(data)) or {}
          base.category = "COSMETIC"
          base.itemID   = itemID
          base.quantity = qty
          base.macro    = "/use item:"..tostring(itemID)
          if not base.icon then
            if C_Item and C_Item.GetItemIconByID then base.icon = C_Item.GetItemIconByID(itemID)
            elseif GetItemIcon then base.icon = GetItemIcon(itemID) end
          end
          applyItemCooldownFields(base, itemID)
          local expire = cosmeticExpireFor(data)
          local allow  = applyThreshold(base, expire)
          if allow then cat[itemID] = base else cat[itemID] = nil end
        else
          cat[itemID] = nil
        end
      else
        cat[itemID] = nil
      end
    else
      if itemID and (IsExcluded(itemID) or (data and not passesGates(data))) then
        cat[itemID] = nil
      end
    end
  end
end

-- Scans all bags for cosmetic items.
-- Skipped during combat.
local function scanCosmeticsAllBags()
  if InCombatLockdown() then return end
  local dataTbl = _G.ClickableRaidData and _G.ClickableRaidData["COSMETIC"]
  if type(dataTbl) ~= "table" then return end
  wipe(ensureCategory())
  for bagID = 0, NUM_BAG_SLOTS do
    scanBagsCosmetics(bagID)
  end
end

-- Hooks scanAllBags to include cosmetics.
do
  if type(_G.scanAllBags) == "function" and not ns._cosmetics_wrapped then
    local orig = _G.scanAllBags
    _G.scanAllBags = function(...)
      local r1, r2, r3 = orig(...)
      scanCosmeticsAllBags()
      return r1, r2, r3
    end
    ns._cosmetics_wrapped = true
  end
end

-- Removes disabled or excluded items from the render list.
local function pruneRenderedDisabled()
  if not ns.RenderFrames then return end
  for i = #ns.RenderFrames, 1, -1 do
    local fr = ns.RenderFrames[i]
    if fr and fr._data and fr._data.category == "COSMETIC" then
      local id = fr._data.itemID or fr._data.id
      if id and ((_active and not _active[id]) or IsExcluded(id)) then
        if fr.Hide then fr:Hide() end
        table.remove(ns.RenderFrames, i)
      end
    end
  end
  if ns.RenderIndexByKey then
    for k, v in pairs(ns.RenderIndexByKey) do
      if type(v) == "table" and v._data and v._data.category == "COSMETIC" then
        local id = v._data.itemID or v._data.id
        if id and ((_active and not _active[id]) or IsExcluded(id)) then
          ns.RenderIndexByKey[k] = nil
        end
      end
    end
  end
end

local _pending
-- Triggers a refresh of cosmetic items.
function ns.Cosmetics_RefreshNow()
  if _pending then return end
  _pending = true
  C_Timer.After(0.05, function()
    _pending = false
    ns.Cosmetics_RebuildActive()
    wipe(ensureCategory())
    pruneRenderedDisabled()
    if type(_G.scanAllBags) == "function" then _G.scanAllBags() end
    if ns.RenderAll then ns.RenderAll()
    elseif ns.PushRender then ns.PushRender()
    elseif _G.ClickableRaidBuffs_PushRender then _G.ClickableRaidBuffs_PushRender() end
  end)
end

-- Recomputes timers for cosmetic items.
-- Skipped during combat.
local function recalcCosmeticTimers()
  if InCombatLockdown() then return end
  local cat = ensureCategory()
  local dataTbl = _G.ClickableRaidData and _G.ClickableRaidData["COSMETIC"]
  if type(dataTbl) ~= "table" then return end
  for itemID, entry in pairs(cat) do
    local data = dataTbl[itemID]
    if ((_active and not _active[itemID]) or IsExcluded(itemID) or not passesGates(data)) then
      cat[itemID] = nil
    else
      local expire = cosmeticExpireFor(data)
      local allow  = applyThreshold(entry, expire)
      if not allow then cat[itemID] = nil end
    end
  end
end

-- Handles UNIT_AURA events for cosmetics.
-- Skipped during combat.
function ns.Cosmetics_OnPlayerAura(unit, updateInfo)
  if unit ~= "player" then return end
  if InCombatLockdown() or (IsEncounterInProgress and IsEncounterInProgress()) or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then return end
  if type(recalcCosmeticTimers) == "function" then recalcCosmeticTimers() end
  if type(ns.MarkBagsDirty) == "function" then ns.MarkBagsDirty() end
  if type(ns.PokeUpdateBus) == "function" then ns.PokeUpdateBus() end
end

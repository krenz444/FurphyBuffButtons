-- ====================================
-- \Modules\WeaponEnchants.lua
-- ====================================
-- This module handles the tracking and display of temporary weapon enchants (oils, stones, etc.).

local addonName, ns = ...

local C = _G.clickableRaidBuffCache or {}
_G.clickableRaidBuffCache = C
C.playerInfo  = C.playerInfo  or {}
C.displayable = C.displayable or {}

local function DB()
  return (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {}
end

-- Constants for weapon types
local WEAPON_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or (LE_ITEM_CLASS_WEAPON) or 2
local W = (Enum and Enum.ItemWeaponSubclass) or {}

-- Helper to create a set from arguments
local function setFrom(...)
  local t = {}
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if v ~= nil then t[v] = true end
  end
  return t
end

-- Weapon subclass sets
local BLADED  = setFrom(W.Axe1H, W.Axe2H, W.Sword1H, W.Sword2H, W.Dagger, W.Polearm, W.Warglaive)
local BLUNT   = setFrom(W.Mace1H, W.Mace2H, W.Staff, W.Fist)
local NEUTRAL = setFrom(W.Bow, W.Gun, W.Crossbow, W.Wand, W.FishingPole)

-- Retrieves item info instantly (without waiting for server query).
local function GetInstantInfo(itemID)
  if not itemID then return nil end
  if C_Item and C_Item.GetItemInfoInstant then
    local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    return classID, subClassID, equipLoc
  end
  local _, _, _, equipLoc, _, classID, subClassID = GetItemInfoInstant(itemID)
  return classID, subClassID, equipLoc
end

-- Normalizes slot type strings (e.g., "1H" -> "ONEHAND").
local function NormalizeSlotType(s)
  if not s then return nil end
  s = tostring(s):gsub("%s+",""):upper():gsub("1H","ONEHAND"):gsub("2H","TWOHAND")
  return s
end

-- Mapping of inventory types to slot types and enchantability.
local ENCHANTABLE_EQUIP = {
  INVTYPE_WEAPON         = { type = "ONEHAND", enchantable = true  },
  INVTYPE_WEAPONMAINHAND = { type = "ONEHAND", enchantable = true  },
  INVTYPE_WEAPONOFFHAND  = { type = "ONEHAND", enchantable = true  },
  INVTYPE_2HWEAPON       = { type = "TWOHAND", enchantable = true  },
  INVTYPE_RANGED         = { type = "TWOHAND", enchantable = true  },
  INVTYPE_RANGEDRIGHT    = { type = "ONEHAND", enchantable = true  },
  INVTYPE_SHIELD         = { type = nil,       enchantable = false },
  INVTYPE_HOLDABLE       = { type = nil,       enchantable = false },
  INVTYPE_FISHINGPOLE    = { type = "TWOHAND", enchantable = false },
}

-- Determines the type and enchantability of the item in a given hand slot.
local function HandTypeAndEnchantable(hand)
  local slot = (hand == "mainHand") and 16 or 17
  local itemID = GetInventoryItemID("player", slot)
  if not itemID then return nil, false end
  local _, _, equipLoc = GetInstantInfo(itemID)
  if not equipLoc then return nil, false end
  local info = ENCHANTABLE_EQUIP[equipLoc]
  if not info then return nil, false end
  return info.type, info.enchantable
end

-- Checks if a subclass ID corresponds to Fist Weapons.
local function IsFistSubclass(subClassID)
  local fistID = W.Fist or 13
  return subClassID == fistID
end

-- Determines the category (Bladed, Blunt, Neutral) of the equipped weapon.
local function EquippedWeaponCategory(hand)
  local slot = (hand == "mainHand") and 16 or 17
  local itemID = GetInventoryItemID("player", slot)
  if not itemID then return nil end
  local classID, subClassID, equipLoc = GetInstantInfo(itemID)
  if not classID or not subClassID then return nil end
  if equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_HOLDABLE" then return nil end
  if classID ~= WEAPON_CLASS then return nil end
  if subClassID and BLADED[subClassID] then return "BLADED" end
  if subClassID and BLUNT[subClassID]  then return "BLUNT"  end
  return "NEUTRAL"
end

-- Determines the category of a weapon item by ID.
local function WeaponTypeForItem(itemID)
  local classID, subClassID, equipLoc = GetInstantInfo(itemID)
  if not classID then return nil end
  if equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_HOLDABLE" then return nil end
  if classID ~= WEAPON_CLASS then return nil end
  if subClassID and BLADED[subClassID] then return "BLADED" end
  if subClassID and BLUNT[subClassID]  then return "BLUNT"  end
  return "NEUTRAL"
end

local lastMHType, lastOHType
local lastBelowMH, lastBelowOH

-- Checks if an expiration time is below a threshold.
local function belowThresh(expireAbs, thresh)
  if not expireAbs then return true end
  if expireAbs == math.huge then return false end
  return (expireAbs - GetTime()) <= thresh
end

-- Updates weapon enchant status.
-- Skipped during combat.
local function _updateWeaponEnchants()
  if InCombatLockdown() then return false, false end

  C.playerInfo.weaponEnchants = C.playerInfo.weaponEnchants or {}

  local mhItem = GetInventoryItemID("player", 16)
  local ohItem = GetInventoryItemID("player", 17)

  local mhType = WeaponTypeForItem(mhItem)
  local ohType = WeaponTypeForItem(ohItem)

  C.playerInfo.mainHand = mhType
  C.playerInfo.offHand  = ohType

  local typesChanged = (mhType ~= lastMHType) or (ohType ~= lastOHType)
  lastMHType, lastOHType = mhType, ohType

  local hasMH, mhMS, _, _, hasOH, ohMS = GetWeaponEnchantInfo()
  local now = GetTime()

  local mhExpire = (mhType and hasMH and mhMS and mhMS > 0) and (now + mhMS/1000) or nil
  local ohExpire = (ohType and hasOH and ohMS and ohMS > 0) and (now + ohMS/1000) or nil

  C.playerInfo.weaponEnchants.mainhand = mhExpire
  C.playerInfo.weaponEnchants.offhand  = ohExpire

  local t = (DB().itemThreshold or 5) * 60
  local bMH = belowThresh(mhExpire, t)
  local bOH = belowThresh(ohExpire, t)
  local stateChanged = (bMH ~= lastBelowMH) or (bOH ~= lastBelowOH)
  lastBelowMH, lastBelowOH = bMH, bOH

  return typesChanged, stateChanged
end

_G.updateWeaponEnchants = _updateWeaponEnchants
ns.WeaponEnchants_Update = _updateWeaponEnchants

-- Public API to check hand type and enchantability.
function ns.WeaponEnchants_EquippedHandTypeAndEnchantable(hand)
  return HandTypeAndEnchantable(hand)
end

-- Public API to normalize slot type.
function ns.WeaponEnchants_NormalizeSlotType(s)
  return NormalizeSlotType(s)
end

-- Public API to check if a weapon matches a category.
function ns.WeaponEnchants_MatchesCategory(hand, reqCat)
  if not reqCat then return true end
  local need = tostring(reqCat):upper()
  if need == "NEUTRAL" then return true end
  local slot = (hand == "mainHand") and 16 or 17
  local itemID = GetInventoryItemID("player", slot)
  if not itemID then return false end
  local classID, subClassID, equipLoc = GetInstantInfo(itemID)
  if not classID or not subClassID or not equipLoc then return false end
  if equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_HOLDABLE" then return false end
  if classID ~= WEAPON_CLASS then return false end
  if IsFistSubclass(subClassID) then
    return (need == "BLADED" or need == "BLUNT")
  end
  if BLADED[subClassID] then return need == "BLADED" end
  if BLUNT[subClassID]  then return need == "BLUNT"  end
  if NEUTRAL[subClassID] then return need == "NEUTRAL" end
  return false
end

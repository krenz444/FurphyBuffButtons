-- ====================================
-- \Core\PlayerInfo.lua
-- ====================================
-- This file handles caching and updating of player-specific information such as level, class, resting state, and equipped weapons.

local addonName, ns = ...

-- Updates the cached player level.
-- Skipped during combat to avoid potential taint or restricted API calls.
function getPlayerLevel()
    if InCombatLockdown() then return end
    clickableRaidBuffCache.playerInfo.playerLevel = UnitLevel("player")
end

-- Updates and returns the cached player class ID.
-- Returns cached value during combat.
function getPlayerClass()
    if InCombatLockdown() then return clickableRaidBuffCache.playerInfo.playerClassId end
    local _, _, classId = UnitClass("player")
    clickableRaidBuffCache.playerInfo.playerClassId = classId
    return classId
end

-- Updates the cached resting state (is the player in a rested XP area).
-- Skipped during combat.
function restedXPGate()
    if InCombatLockdown() then return end
    clickableRaidBuffCache.playerInfo.restedXPArea = IsResting()
end

-- Updates the cached instance state (is the player in an instance).
-- Skipped during combat.
function instanceGate()
    if InCombatLockdown() then return end
    local inInstance = IsInInstance()
    clickableRaidBuffCache.playerInfo.inInstance = inInstance
end

-- Helper function to determine the type of weapons equipped (Bladed, Blunt, or Other).
-- Used for weapon enchant logic.
local function getEquippedWeaponTypes()
    local types = { mainhand = nil, offhand = nil }
    for slot, label in pairs({ [16] = "mainhand", [17] = "offhand" }) do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then
            local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
            if classID == Enum.ItemClass.Weapon then
                if subClassID == Enum.ItemWeaponSubclass.Axe1H
                or subClassID == Enum.ItemWeaponSubclass.Axe2H
                or subClassID == Enum.ItemWeaponSubclass.Sword1H
                or subClassID == Enum.ItemWeaponSubclass.Sword2H
                or subClassID == Enum.ItemWeaponSubclass.Dagger
                or subClassID == Enum.ItemWeaponSubclass.Warglaive
                or subClassID == Enum.ItemWeaponSubclass.Polearm then
                    types[label] = "BLADED"
                elseif subClassID == Enum.ItemWeaponSubclass.Mace1H
                or subClassID == Enum.ItemWeaponSubclass.Mace2H
                or subClassID == Enum.ItemWeaponSubclass.Staff
                or subClassID == Enum.ItemWeaponSubclass.Unarmed then
                    types[label] = "BLUNT"
                else
                    types[label] = "OTHER"
                end
            end
        end
    end
    return types
end

-- Updates the cached weapon types.
-- Skipped during combat.
function updateWeaponTypes()
    if InCombatLockdown() then return end
    local weapTypes = getEquippedWeaponTypes()
    clickableRaidBuffCache.playerInfo.mainHand = weapTypes.mainhand or nil
    clickableRaidBuffCache.playerInfo.offHand  = weapTypes.offhand or nil
end

-- Updates the cached weapon enchant expiration times.
-- Skipped during combat.
function updateWeaponEnchants()
    if InCombatLockdown() then return end
    local mh, mhTime, _, _, oh, ohTime = GetWeaponEnchantInfo()
    clickableRaidBuffCache.playerInfo.weaponEnchants = {
        mainhand = mh and (GetTime() + (mhTime/1000)) or nil,
        offhand  = oh and (GetTime() + (ohTime/1000)) or nil,
    }
end

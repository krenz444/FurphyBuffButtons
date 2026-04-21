-- ====================================
-- \Core\PlayerInfo.lua
-- ====================================
-- This file handles caching and updating of player-specific information such as level, class, resting state, and equipped weapons.

local addonName, ns = ...

-- Updates the cached player level.
-- Skipped during combat to avoid potential taint or restricted API calls.
function getPlayerLevel()
    if InCombatLockdown() then return end
    furphyBuffCache.playerInfo.playerLevel = UnitLevel("player")
end

-- Updates and returns the cached player class ID.
-- Returns cached value during combat.
function getPlayerClass()
    if InCombatLockdown() then return furphyBuffCache.playerInfo.playerClassId end
    local _, _, classId = UnitClass("player")

    -- Handle potential secret return from UnitClass (though usually only first return is secret)
    if issecretvalue and issecretvalue(classId) then
        -- If classId is secret, fallback to cached value if available, or 0
        return furphyBuffCache.playerInfo.playerClassId or 0
    end

    furphyBuffCache.playerInfo.playerClassId = classId
    return classId
end

-- Updates the cached resting state (is the player in a rested XP area).
-- Skipped during combat.
function restedXPGate()
    if InCombatLockdown() then return end
    furphyBuffCache.playerInfo.restedXPArea = IsResting()
end

-- Updates the cached instance state (is the player in an instance).
-- Skipped during combat.
function instanceGate()
    if InCombatLockdown() then return end
    local inInstance = IsInInstance()
    furphyBuffCache.playerInfo.inInstance = inInstance
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
    furphyBuffCache.playerInfo.mainHand = weapTypes.mainhand or nil
    furphyBuffCache.playerInfo.offHand  = weapTypes.offhand or nil
end

-- Updates the cached weapon enchant expiration times.
-- Skipped during combat.
function updateWeaponEnchants()
    if InCombatLockdown() then return end
    local mh, mhTime, _, _, oh, ohTime = GetWeaponEnchantInfo()
    -- Guard against secret values from GetWeaponEnchantInfo in M+/PvP/combat
    if issecretvalue then
        if issecretvalue(mh) then mh = nil end
        if issecretvalue(oh) then oh = nil end
        if issecretvalue(mhTime) then mhTime = nil end
        if issecretvalue(ohTime) then ohTime = nil end
    end
    furphyBuffCache.playerInfo.weaponEnchants = {
        mainhand = (mh and mhTime) and (GetTime() + (mhTime/1000)) or nil,
        offhand  = (oh and ohTime) and (GetTime() + (ohTime/1000)) or nil,
    }
end

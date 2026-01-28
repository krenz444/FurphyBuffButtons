-- ====================================
-- \Core\Buffs.lua
-- ====================================
-- This file contains helper functions for checking player and raid buffs.

local addonName, ns = ...

-- Retrieves the localized name of a spell by its ID.
function ns.GetLocalizedBuffName(spellID)
    local info = C_Spell.GetSpellInfo(spellID)
    return info and info.name or nil
end

-- List of spell IDs to exclude from name-based lookups.
local NAME_MODE_EXCLUDE = { [442522] = true }

-- Builds a lookup table of localized spell names from a list of spell IDs.
local function BuildNameLookup(spellIDs)
    local t = {}
    for _, id in ipairs(spellIDs or {}) do
        local n = ns.GetLocalizedBuffName(id)
        if n then t[n] = true end
    end
    return next(t) and t or nil
end

-- Checks if the player has any of the specified buffs and returns the expiration time.
-- Skipped during combat.
function ns.GetPlayerBuffExpire(spellIDs, nameMode, infinite)
    if InCombatLockdown() then return nil end
    local function handleAura(aura)
        if not aura then return nil end
        if infinite or aura.expirationTime == 0 then return math.huge end
        return aura.expirationTime
    end

    if nameMode then
        local nameLookup = BuildNameLookup(spellIDs)
        if not nameLookup then return nil end
        local j = 1
        while true do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", j, "HELPFUL")
            if not aura then break end
            if aura.name and nameLookup[aura.name] and not NAME_MODE_EXCLUDE[aura.spellId] then
                return handleAura(aura)
            end
            j = j + 1
        end
    else
        local spellLookup = {}
        for _, id in ipairs(spellIDs or {}) do spellLookup[id] = true end
        local j = 1
        while true do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", j, "HELPFUL")
            if not aura then break end
            if aura.spellId and spellLookup[aura.spellId] then
                return handleAura(aura)
            end
            j = j + 1
        end
    end

    return nil
end

-- Returns a list of unit IDs for all group members (raid or party).
local function GetAllGroupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units+1] = "raid"..i end
    elseif IsInGroup() then
        for i = 1, (GetNumGroupMembers() - 1) do units[#units+1] = "party"..i end
        units[#units+1] = "player"
    else
        units[#units+1] = "player"
    end
    return units
end

-- Checks if all raid members have the specified buff and returns the earliest expiration time.
-- Skipped during combat.
function ns.GetRaidBuffExpire(spellIDs, nameMode, infinite)
    if InCombatLockdown() then return nil end
    local spellLookup, nameLookup
    if nameMode then
        nameLookup = BuildNameLookup(spellIDs)
        if not nameLookup then return nil end
    else
        spellLookup = {}
        for _, id in ipairs(spellIDs or {}) do spellLookup[id] = true end
    end

    local function matches(aura)
        if not aura then return false end
        if nameLookup then
            return aura.name and nameLookup[aura.name] and not NAME_MODE_EXCLUDE[aura.spellId]
        else
            return aura.spellId and spellLookup[aura.spellId]
        end
    end

    local earliest = nil
    local units = GetAllGroupUnits()

    for _, unit in ipairs(units) do
        local hasThisBuff = false
        local j = 1
        while true do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, j, "HELPFUL")
            if not aura then break end
            if matches(aura) then
                hasThisBuff = true
                local exp = (infinite or aura.expirationTime == 0) and math.huge or aura.expirationTime
                if exp and (not earliest or exp < earliest) then earliest = exp end
                break
            end
            j = j + 1
        end
        if not hasThisBuff then return nil end
    end

    return earliest
end

-- Checks if raid members have a buff cast by the player.
-- Skipped during combat.
function ns.GetRaidBuffExpireMine(spellIDs, nameMode, infinite)
    if InCombatLockdown() then return nil end
    local playerGUID = UnitGUID("player")

    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units+1] = "raid"..i end
    else
        for i = 1, GetNumSubgroupMembers() do units[#units+1] = "party"..i end
        units[#units+1] = "player"
    end

    local spellLookup, nameLookup
    if nameMode then
        nameLookup = BuildNameLookup(spellIDs)
        if not nameLookup then return nil end
    else
        spellLookup = {}
        for _, id in ipairs(spellIDs or {}) do spellLookup[id] = true end
    end

    local function matchMine(aura)
        if not aura or not aura.sourceUnit then return false end
        if UnitGUID(aura.sourceUnit) ~= playerGUID then return false end
        if nameLookup then
            return aura.name and nameLookup[aura.name] and not NAME_MODE_EXCLUDE[aura.spellId]
        else
            return aura.spellId and spellLookup[aura.spellId]
        end
    end

    for _, unit in ipairs(units) do
        local j = 1
        while true do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, j, "HELPFUL")
            if not aura then break end
            if matchMine(aura) then
                if infinite or aura.expirationTime == 0 then
                    return math.huge
                else
                    return aura.expirationTime
                end
            end
            j = j + 1
        end
    end

    return nil
end

-- ====================================
-- \Modules\Trinkets.lua
-- ====================================
-- This module handles the tracking and display of usable trinkets.

local addonName, ns = ...

clickableRaidBuffCache = clickableRaidBuffCache or {}
clickableRaidBuffCache.playerInfo  = clickableRaidBuffCache.playerInfo  or {}
clickableRaidBuffCache.displayable = clickableRaidBuffCache.displayable or {}

-- Retrieves the player's class ID.
-- Returns nil during combat.
local function getPlayerClass()
  if InCombatLockdown() then return nil end
  local _, _, classID = UnitClass("player")
  return classID
end

-- Checks if a trinket is equipped in either slot.
local function IsTrinketEquipped(itemID)
  if not itemID then return false end
  local s13 = GetInventoryItemID("player", 13)
  if s13 and s13 == itemID then return true end
  local s14 = GetInventoryItemID("player", 14)
  if s14 and s14 == itemID then return true end
  if IsEquippedItem and IsEquippedItem(itemID) then return true end
  if C_Item and C_Item.IsEquippedItem and C_Item.IsEquippedItem(itemID) then return true end
  return false
end

-- Checks if a row in the data table corresponds to an equipped trinket.
local function IsRowKnown(data, rowKey)
  local k = data and data.isKnown
  if type(k) == "number" then
    return IsTrinketEquipped(k)
  elseif type(k) == "boolean" then
    return k
  else
    local id = (data and data.spellID) or rowKey
    return IsTrinketEquipped(id)
  end
end

-- Rebuilds the list of trinket buffs to watch for.
function ns.Trinkets_RebuildWatch()
  ns._trinketWatch = { spellId = {}, name = {} }

  local classID    = clickableRaidBuffCache.playerInfo.playerClassId or getPlayerClass()
  local classBuffs = classID and ClickableRaidData and ClickableRaidData[classID]
  if not classBuffs then return end

  local function addTable(tbl)
    if not tbl then return end
    for _, data in pairs(tbl) do
      local ids = data and data.buffID
      if ids and #ids > 0 then
        if data.nameMode then
          local n = ns.GetLocalizedBuffName and ns.GetLocalizedBuffName(ids[1]) or (C_Spell.GetSpellInfo(ids[1]) or {}).name
          if n then ns._trinketWatch.name[n] = true end
        else
          for _, id in ipairs(ids) do ns._trinketWatch.spellId[id] = true end
        end
      end
    end
  end

  addTable(classBuffs)
end

-- Handles UNIT_AURA events to update trinket status.
-- Skipped during combat.
function ns.Trinkets_OnUnitAura(unit, updateInfo)
  if InCombatLockdown() then
    return
  end

  if not unit or (unit ~= "player" and not unit:match("^party%d") and not unit:match("^raid%d")) then
    return
  end

  if not ns._trinketWatch then ns.Trinkets_RebuildWatch() end
  local watch      = ns._trinketWatch or { spellId = {}, name = {} }
  local watchSpell = watch.spellId or {}
  local watchName  = watch.name   or {}

  local function auraMatches(aura)
    if not aura then return false end
    if aura.spellId and watchSpell[aura.spellId] then return true end
    if aura.name    and watchName[aura.name]       then return true end
    return false
  end

  local shouldPoke = false
  if updateInfo then
    if updateInfo.addedAuras and not shouldPoke then
      for _, a in ipairs(updateInfo.addedAuras) do
        if auraMatches(a) then shouldPoke = true; break end
      end
    end
    if updateInfo.updatedAuraInstanceIDs and not shouldPoke then
      for k, v in pairs(updateInfo.updatedAuraInstanceIDs) do
        local id = (type(v) == "number") and v or k
        local a = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
        if auraMatches(a) then shouldPoke = true; break end
      end
    end
    if updateInfo.removedAuraInstanceIDs and not shouldPoke then
      if next(updateInfo.removedAuraInstanceIDs) ~= nil then
        shouldPoke = true
      end
    end
    if updateInfo.isFullUpdate and not shouldPoke then
      local i = 1
      while true do
        local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not a then break end
        if auraMatches(a) then shouldPoke = true; break end
        i = i + 1
      end
    end
  else
    shouldPoke = true
  end

  if shouldPoke then
    if ns.MarkAurasDirty then ns.MarkAurasDirty(unit) end
    if ns.PokeUpdateBus then ns.PokeUpdateBus() end
  end
end

-- Scans for usable trinkets and updates the displayable list.
-- Skipped during combat.
function ns.Trinkets_Scan()
  if InCombatLockdown() then return end

  clickableRaidBuffCache.displayable.TRINKETS = {}

  local playerLevel = clickableRaidBuffCache.playerInfo.playerLevel or UnitLevel("player") or 0
  local inInstance  = clickableRaidBuffCache.playerInfo.inInstance
  local rested      = clickableRaidBuffCache.playerInfo.restedXPArea
  local db          = ns.GetDB and ns.GetDB() or {}

  local threshold   = (ns.MPlus_GetEffectiveThresholdSecs and ns.MPlus_GetEffectiveThresholdSecs("spell", db.spellThreshold or 15)) or ((db.spellThreshold or 15) * 60)

  local function passesGates(data, playerLevelX, inInstanceX, restedX)
    return ns.PassesGates(data, playerLevelX, inInstanceX, restedX)
  end

  local function normalizeExpire(v)
    if v == nil then return nil end
    if v == math.huge then return math.huge end
    if type(v) ~= "number" then return nil end
    local now = GetTime()
    if v > (now + 1) then return v end
    return now + math.max(0, v)
  end

  local function CountByName(name, countRequired)
    if not name then return nil end
    local units = {}
    if IsInRaid() then
      for i = 1, GetNumGroupMembers() do local u="raid"..i; if UnitExists(u) then table.insert(units,u) end end
    elseif IsInGroup() then
      table.insert(units,"player")
      for i = 1, GetNumSubgroupMembers() do local u="party"..i; if UnitExists(u) then table.insert(units,u) end end
    else
      table.insert(units,"player")
    end
    local have, total = 0, #units
    for _, u in ipairs(units) do
      local i=1
      while true do
        local a = C_UnitAuras.GetAuraDataByIndex(u,i,"HELPFUL")
        if not a then break end
        if a.name==name then have=have+1; break end
        i=i+1
      end
    end
    if countRequired then
      return (have >= countRequired) and math.huge or nil
    else
      return (have==total) and math.huge or nil
    end
  end

  local function CountCoverageForData(data)
    local buffIDs = data and data.buffID
    if not buffIDs then return 0, 0 end

    local units = {}
    if IsInRaid() then
      for i = 1, GetNumGroupMembers() do local u="raid"..i; if UnitExists(u) then table.insert(units,u) end end
    elseif IsInGroup() then
      table.insert(units,"player")
      for i = 1, GetNumSubgroupMembers() do local u="party"..i; if UnitExists(u) then table.insert(units,u) end end
    else
      table.insert(units,"player")
    end

    local wantById
    local targetName
    if data.nameMode then
      local first = (type(buffIDs)=="table") and buffIDs[1] or buffIDs
      targetName = ns.GetLocalizedBuffName and ns.GetLocalizedBuffName(first) or (C_Spell.GetSpellInfo(first) or {}).name
    else
      wantById = {}
      if type(buffIDs)=="table" then
        for i=1,#buffIDs do local id=buffIDs[i]; if id then wantById[id]=true end end
      elseif type(buffIDs)=="number" then
        wantById[buffIDs]=true
      end
    end

    local have, total = 0, #units
    for _, u in ipairs(units) do
      local i = 1
      local found = false
      while true do
        local a = C_UnitAuras.GetAuraDataByIndex(u, i, "HELPFUL")
        if not a then break end
        if targetName then
          if a.name == targetName then found = true; break end
        else
          if a.spellId and wantById[a.spellId] then found = true; break end
        end
        i = i + 1
      end
      if found then have = have + 1 end
    end
    return have, total
  end

local function addEntry(rowKey, data, catName)
  local entry = (ns.copyItemData and ns.copyItemData(data)) or {}
  entry.category = catName
  entry.spellID  = data.spellID or rowKey

  local function buildUnits()
    local units = {}
    if data.check == "player" then
      units[1] = "player"
      return units
    end
    if IsInRaid() then
      for i = 1, GetNumGroupMembers() do local u = "raid"..i; if UnitExists(u) then units[#units+1] = u end end
    elseif IsInGroup() then
      units[#units+1] = "player"
      for i = 1, GetNumSubgroupMembers() do local u = "party"..i; if UnitExists(u) then units[#units+1] = u end end
    else
      units[#units+1] = "player"
    end
    return units
  end

  local function buildSets()
    local idSet, nameSet, nameMode
    nameMode = (data.nameMode and true) or false
    local ids = data.buffID
    if nameMode then
      nameSet = {}
      if type(ids) == "table" then
        for i = 1, #ids do
          local id = ids[i]
          if id then
            local n = (ns.GetLocalizedBuffName and ns.GetLocalizedBuffName(id)) or (C_Spell.GetSpellInfo(id) or {}).name
            if n then nameSet[n] = true end
          end
        end
      elseif type(ids) == "number" then
        local n = (ns.GetLocalizedBuffName and ns.GetLocalizedBuffName(ids)) or (C_Spell.GetSpellInfo(ids) or {}).name
        if n then nameSet[n] = true end
      end
    else
      idSet = {}
      if type(ids) == "table" then
        for i = 1, #ids do local v = ids[i]; if v then idSet[v] = true end end
      elseif type(ids) == "number" then
        idSet[ids] = true
      end
    end
    return idSet, nameSet, nameMode
  end

  local mineOnlyActive = (ns.MineOnly_IsActive and ns.MineOnly_IsActive(data)) or false

  local ex
  if mineOnlyActive then
    local units = buildUnits()
    local idSet, nameSet, nameMode = buildSets()
    local foundExpire
    for i = 1, #units do
      local u = units[i]
      local ok, expire = false, nil
      if ns.MineOnly_UnitHasBuff then
        ok, expire = ns.MineOnly_UnitHasBuff(u, idSet, nameSet, nameMode)
      end
      if ok then
        if expire and expire > 0 then
          foundExpire = expire
        else
          foundExpire = math.huge
        end
        break
      end
    end
    ex = foundExpire
  else
    if data.nameMode then
      local first = (type(data.buffID) == "table") and data.buffID[1] or data.buffID
      local spellName = (ns.GetLocalizedBuffName and ns.GetLocalizedBuffName(first)) or (C_Spell.GetSpellInfo(first) or {}).name
      local function CountByName(name, countRequired)
        if not name then return nil end
        local units = buildUnits()
        local have, total = 0, #units
        for _, u in ipairs(units) do
          local idx, matched = 1, false
          while true do
            local a = C_UnitAuras.GetAuraDataByIndex(u, idx, "HELPFUL")
            if not a then break end
            if a.name == name then matched = true; break end
            idx = idx + 1
          end
          if matched then have = have + 1 end
        end
        if countRequired then
          return (have >= countRequired) and math.huge or nil
        else
          return (have == total) and math.huge or nil
        end
      end
      ex = CountByName(spellName, data.count)
    elseif data.check == "player" then
      ex = ns.GetPlayerBuffExpire and ns.GetPlayerBuffExpire(data.buffID, data.nameMode, data.infinite) or nil
    elseif data.check == "raid" then
      ex = ns.GetRaidBuffExpire and ns.GetRaidBuffExpire(data.buffID, data.nameMode, data.infinite) or nil
    end
  end

  entry.expireTime = normalizeExpire(ex)

  local useThreshold = threshold
  if entry.spellID == 20707 then
    local ssMin = (db and db.soulstoneThreshold) or 5
    useThreshold = (ssMin or 5) * 60
  end

  if entry.expireTime and entry.expireTime ~= math.huge then
    entry.showAt = entry.expireTime - useThreshold
  else
    entry.showAt = nil
  end

  if catName == "TRINKETS" and (data.count == nil) and (data.check ~= "player") and (not entry.centerText or entry.centerText == "") then
    local units = buildUnits()
    local total, have = #units, 0
    if mineOnlyActive then
      local idSet, nameSet, nameMode = buildSets()
      for i = 1, total do
        local u = units[i]
        local ok = false
        if ns.MineOnly_UnitHasBuff then
          ok = ns.MineOnly_UnitHasBuff(u, idSet, nameSet, nameMode)
        end
        if ok then have = have + 1 end
      end
    else
      if data.nameMode then
        local nameSet = {}
        local ids = data.buffID
        if type(ids) == "table" then
          for i=1,#ids do
            local id = ids[i]
            if id then
              local n = (ns.GetLocalizedBuffName and ns.GetLocalizedBuffName(id)) or (C_Spell.GetSpellInfo(id) or {}).name
              if n then nameSet[n] = true end
            end
          end
        elseif type(ids) == "number" then
          local n = (ns.GetLocalizedBuffName and ns.GetLocalizedBuffName(ids)) or (C_Spell.GetSpellInfo(ids) or {}).name
          if n then nameSet[n] = true end
        end
        for i=1,total do
          local u = units[i]
          local idx, matched = 1, false
          while true do
            local a = C_UnitAuras.GetAuraDataByIndex(u, idx, "HELPFUL")
            if not a then break end
            if a.name and nameSet[a.name] then matched = true; break end
            idx = idx + 1
          end
          if matched then have = have + 1 end
        end
      else
        local idSet = {}
        local ids = data.buffID
        if type(ids) == "table" then
          for i=1,#ids do local v=ids[i]; if v then idSet[v]=true end end
        elseif type(ids) == "number" then
          idSet[ids] = true
        end
        for i=1,total do
          local u = units[i]
          local idx, matched = 1, false
          while true do
            local a = C_UnitAuras.GetAuraDataByIndex(u, idx, "HELPFUL")
            if not a then break end
            if a.spellId and idSet[a.spellId] then matched = true; break end
            idx = idx + 1
          end
          if matched then have = have + 1 end
        end
      end
    end
    entry.centerText = tostring(have) .. " / " .. tostring(total)
  elseif catName == "TRINKETS" and (data.count ~= nil) then
    entry.centerText = ""
  end

  local itemID = data.itemID or rowKey
  entry.itemID = itemID
  local tgt = (data.target == "player") and "player" or "target"
  entry.macro = "/use [@"..tgt.."] item:"..tostring(itemID)

  clickableRaidBuffCache.displayable[catName][rowKey] = entry
end

  local trinkets = ClickableRaidData and ClickableRaidData.TRINKETS
  if not trinkets then return end

  for rowKey, data in pairs(trinkets) do
    if data and passesGates(data, playerLevel, inInstance, rested) then
      local itemID = data.itemID or rowKey
      local include = IsTrinketEquipped(itemID)
      if include then
        addEntry(rowKey, data, "TRINKETS")
      end
    end
  end

  do
    local disp = clickableRaidBuffCache.displayable.TRINKETS or {}
    local byKey = {}
    local function hasInstanceGate(e)
      local g = e and e.gates
      if not g then return false end
      for i = 1, #g do if g[i] == "instance" then return true end end
      return false
    end
    for k, e in pairs(disp) do
      if type(e) == "table" then
        local nm = e.name
        if not nm and e.spellID then
          local si = C_Spell.GetSpellInfo(e.spellID)
          nm = si and si.name or tostring(e.spellID)
        end
        local key = tostring(e.spellID or 0) .. "|" .. tostring(nm or "")
        local grp = byKey[key]
        if not grp then
          byKey[key] = { { key = k, e = e } }
        else
          grp[#grp + 1] = { key = k, e = e }
        end
      end
    end
    for _, grp in pairs(byKey) do
      if #grp > 1 then
        local winner = 1
        if inInstance then
          for i = 1, #grp do if hasInstanceGate(grp[i].e) then winner = i; break end end
        else
          for i = 1, #grp do if not hasInstanceGate(grp[i].e) then winner = i; break end end
        end
        for i = 1, #grp do if i ~= winner then disp[grp[i].key] = nil end end
      end
    end
  end
end

-- Public API to rebuild trinket display.
function ns.Trinkets_Rebuild()
  ns.Trinkets_RebuildWatch()
end

-- Event handlers
function ns.Trinkets_OnGroupRosterUpdate()
  ns.Trinkets_RebuildWatch()
  return true
end

function ns.Trinkets_OnCombatLogEventUnfiltered()
  return false
end

-- Hooks scanRaidBuffs to include trinket scanning.
if type(scanRaidBuffs) == "function" and not ns._mergedScan then
  local _crb_orig_scanRaidBuffs = scanRaidBuffs
  scanRaidBuffs = function(...)
    _crb_orig_scanRaidBuffs(...)
    if type(ns.Trinkets_Scan) == "function" then ns.Trinkets_Scan() end
  end
  ns._mergedScan = true
end

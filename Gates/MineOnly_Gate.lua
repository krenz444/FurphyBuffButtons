-- ====================================
-- \Gates\MineOnly_Gate.lua
-- ====================================
-- Gate and utility functions for checking if buffs are cast by the player specifically.
-- Used to track personal buffs (e.g., poisons, enchants) where only player-applied
-- auras should be detected. The gate itself always passes; helper functions do the checks.

local addonName, ns = ...
ns = ns or {}

function ns.MineOnly_IsActive(data)
  if not data then return false end
  if type(data.gates) == "table" then
    for i = 1, #data.gates do
      if data.gates[i] == "mineOnly" then return true end
    end
  end
  return data.mineOnly == true
end

local function _auraMatchesMineOnly(a, idSet, nameSet, nameMode)
  if not a then return false end
  local byPlayer = a.sourceUnit and UnitIsUnit(a.sourceUnit, "player")
  if not byPlayer then return false end
  if idSet and a.spellId and idSet[a.spellId] then return true end
  if nameMode and nameSet and a.name and nameSet[a.name] then return true end
  return false
end

function ns.MineOnly_UnitHasBuff(unit, idSet, nameSet, nameMode)
  if not unit then return false, nil end
  local found, expire = false, nil
  if AuraUtil and AuraUtil.ForEachAura then
    AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(a)
      if _auraMatchesMineOnly(a, idSet, nameSet, nameMode) then
        found = true
        if a.expirationTime and a.expirationTime > 0 then expire = a.expirationTime end
        return true
      end
    end, true)
  else
    local i = 1
    while true do
      local name, _, _, _, _, expTime, _, source, _, _, spellId = UnitAura(unit, i, "HELPFUL")
      if not name then break end
      local a = { name = name, spellId = spellId, expirationTime = expTime, sourceUnit = source }
      if _auraMatchesMineOnly(a, idSet, nameSet, nameMode) then
        found = true
        if expTime and expTime > 0 then expire = expTime end
        break
      end
      i = i + 1
    end
  end
  return found, expire
end

ns.RegisterGate("mineOnly", function(ctx, data)
  return true
end)

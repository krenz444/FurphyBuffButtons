-- ====================================
-- \Gates\Map_Gate.lua
-- ====================================
-- Gates that filter icons based on the player's current map ID.
-- "map": passes only when on a specific map (positive match).
-- "notMap": passes when NOT on a specific map (negative match).

local addonName, ns = ...

local function findGateValue(data, key)
  local g = data and data.gates
  if type(g) ~= "table" then return nil end
  for i = 1, #g do
    local v = g[i]
    if type(v) == "table" and v[key] ~= nil then
      local n = tonumber(v[key])
      if n then return n end
    end
  end
  return nil
end

ns.RegisterGate("map", function(ctx, data)
  local want = findGateValue(data, "map")
  if not want then return true end
  local cur = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not cur then return false end
  return cur == want
end)

ns.RegisterGate("notMap", function(ctx, data)
  local avoid = findGateValue(data, "notMap")
  if not avoid then return true end
  local cur = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not cur then return true end
  return cur ~= avoid
end)

-- ====================================
-- \Gates\Death_Gate.lua
-- ====================================
-- Gate that only passes when the player is alive (not dead or ghost).

local addonName, ns = ...

function ns.Gate_Alive()
  return not UnitIsDeadOrGhost("player")
end

ns.RegisterGate("alive", function()
  return ns.Gate_Alive()
end)

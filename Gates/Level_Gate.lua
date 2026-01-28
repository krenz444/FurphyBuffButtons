-- ====================================
-- \Gates\Level_Gate.lua
-- ====================================
-- Gate that restricts icons based on minimum player level requirements.

local addonName, ns = ...

function ns.Gate_Level(minLevel, playerLevel)
  if not minLevel or minLevel <= 0 then return true end
  playerLevel = playerLevel or (UnitLevel and UnitLevel("player")) or 0
  return playerLevel >= minLevel
end

ns.RegisterGate("level", function(ctx, data)
  return ns.Gate_Level(data and data.minLevel, ctx.playerLevel)
end)

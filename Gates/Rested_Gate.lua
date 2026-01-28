-- ====================================
-- \Gates\Rested_Gate.lua
-- ====================================
-- Gate that only passes when the player is NOT in a rested area (inn/city).
-- Used to hide buff icons when they cannot be cast (e.g., in sanctuaries).

local addonName, ns = ...

function ns.Gate_Rested(restedFlag)
  if restedFlag == nil then
    restedFlag = IsResting and IsResting() or false
  end
  return not restedFlag
end

ns.RegisterGate("rested", function(ctx)
  return ns.Gate_Rested(ctx.rested)
end)

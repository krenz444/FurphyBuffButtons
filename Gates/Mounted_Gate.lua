-- ====================================
-- \Gates\Mounted_Gate.lua
-- ====================================
-- Gate that only passes when the player is NOT mounted.

local addonName, ns = ...

function ns.Gate_NotMounted()
  return not (IsMounted and IsMounted())
end

ns.RegisterGate("not_mounted", function()
  return ns.Gate_NotMounted()
end)

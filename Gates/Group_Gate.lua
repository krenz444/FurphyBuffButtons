-- ====================================
-- \Gates\Group_Gate.lua
-- ====================================
-- Gate that only allows icons to display when the player is in a group or raid.

local addonName, ns = ...

function ns.PassesGroupGate()
  return (IsInGroup() or IsInRaid()) and true or false
end

ns.RegisterGate("group", function()
  return ns.PassesGroupGate()
end)

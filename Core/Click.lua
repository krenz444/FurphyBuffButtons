-- ====================================
-- \Core\Click.lua
-- ====================================
-- This file handles click behavior and macro generation for the addon's buttons.

local addonName, ns = ...

ns.RenderFrames = ns.RenderFrames or {}

-- Disables mouse interaction for overlay frames to allow clicking through them.
-- Skipped during combat.
local function ClickThroughOverlays()
  if InCombatLockdown() then return end
  if ns.Overlay and ns.Overlay.EnableMouse then ns.Overlay:EnableMouse(false) end
  if ns.Hover   and ns.Hover.EnableMouse   then ns.Hover:EnableMouse(false)   end
end

-- Determines if an entry requires self-casting.
local function EntryWantsSelfCast(e)
  if not e then return false end
  return (e.target == "player") or (e.castOn == "player") or e.selfCast or e.forceSelf
end

-- Injects [@player] into macro text for self-cast actions.
local function InjectPlayerIntoMacroText(macrotext)
  if not macrotext or macrotext == "" or macrotext:find("@player", 1, true) then return macrotext end
  local out = {}
  for line in string.gmatch(macrotext, "([^\n\r]*)") do
    if line ~= "" then
      local trimmed = line:gsub("^%s+", "")
      if trimmed:lower():find("^/cast") and not trimmed:find("%[.-%]") then
        line = line:gsub("(/cast)(%s+)(.+)", "%1%2[@player] %3", 1)
      end
    end
    table.insert(out, line)
  end
  return table.concat(out, "\n")
end

-- Applies self-cast attributes to buttons if required.
-- Skipped during combat.
local function ForceSelfCastOnButtons()
  if InCombatLockdown() then return end
  for _, b in ipairs(ns.RenderFrames) do
    if b and b:IsShown() then
      local e = b._crb_entry
      local atype = (b.GetAttribute and b:GetAttribute("type")) or nil
      if EntryWantsSelfCast(e) then
        if atype == "spell" or atype == "item" then
          if b:GetAttribute("unit") ~= "player" then b:SetAttribute("unit", "player") end
        elseif atype == "macro" then
          local mt = b:GetAttribute("macrotext")
          local new = InjectPlayerIntoMacroText(mt)
          if new and new ~= mt then b:SetAttribute("macrotext", new) end
        end
      else
        if b.GetAttribute and b:GetAttribute("unit") ~= nil then b:SetAttribute("unit", nil) end
      end
    end
  end
end

-- Hook RenderAll to ensure click behaviors are applied after rendering.
do
  local wrapped
  local function EnsureHook()
    if wrapped then return end
    if type(ns.RenderAll) == "function" then
      local orig = ns.RenderAll
      ns.RenderAll = function(...)
        local ret = orig(...)
        ClickThroughOverlays()
        ForceSelfCastOnButtons()
        return ret
      end
      wrapped = true
    end
  end
  EnsureHook()
  C_Timer.After(0.05, EnsureHook)
  C_Timer.After(0.5,  EnsureHook)
end

-- Event handler to reapply click behaviors.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" then
    ClickThroughOverlays()
  elseif event == "PLAYER_REGEN_ENABLED" then
    ForceSelfCastOnButtons()
  end
end)

-- Public API to reapply click behaviors.
ns.Click_Reapply = function()
  ClickThroughOverlays()
  ForceSelfCastOnButtons()
end

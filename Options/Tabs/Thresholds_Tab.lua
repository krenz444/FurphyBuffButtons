-- ====================================
-- \Options\Tabs\Thresholds_Tab.lua
-- ====================================
-- This file creates the "Thresholds" tab in the options panel, allowing users to configure
-- time and quantity thresholds for various buffs and items.

local addonName, ns = ...
local O  = ns.Options
local NS = ns.NumberSelect

local function DB() return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {} end
local defaults = (O and O.DEFAULTS) or {}

local KNOB = { ROW_H_TOP = 90 }

-- Applies the new threshold settings and triggers a rebuild.
-- Debounced to prevent excessive updates.
function applyThresholds()
  if ns._throttleThresholdsTimer then return end
  ns._throttleThresholdsTimer = true
  C_Timer.After(0.08, function()
    ns._throttleThresholdsTimer = nil

    local d = DB()
    if ns.SetThresholds then
      ns.SetThresholds({
        spell       = d.spellThreshold       or defaults.spellThreshold,
        item        = d.itemThreshold        or defaults.itemThreshold,
        durability  = d.durabilityThreshold  or defaults.durabilityThreshold,
        healthstone = d.healthstoneThreshold or defaults.healthstoneThreshold or 1,
        soulstone   = d.soulstoneThreshold   or defaults.soulstoneThreshold   or 5,
      })
    end
    if ns.RequestRebuild then ns.RequestRebuild() end
    if ns.PushRender then ns.PushRender() elseif ns.RenderAll then ns.RenderAll() end
  end)
end

-- Registers the Thresholds section.
O.RegisterSection(function(AddSection)
  AddSection("Thresholds", function(content, Row)
    local d = DB()

    -- Helper to add a number selection widget to a row.
    local function AddNumSelectHalf(rowFrame, side, key, label, minV, maxV, stepV, defFallback)
      local cell = CreateFrame("Frame", nil, rowFrame)
      if side == "LEFT" then
        cell:SetPoint("LEFT"); cell:SetPoint("RIGHT", rowFrame, "CENTER")
      else
        cell:SetPoint("LEFT", rowFrame, "CENTER"); cell:SetPoint("RIGHT")
      end
      cell:SetPoint("TOP"); cell:SetPoint("BOTTOM")

      local defV = defaults[key] or defFallback
      local curV = (d[key] ~= nil) and d[key] or defV

      local holder = NS.Create(cell, {
        label   = label,
        min     = minV,
        max     = maxV,
        step    = stepV,
        value   = curV,
        default = defV,
        onChange = function(v) d[key] = v; applyThresholds() end,
      })
      holder:SetPoint("CENTER")
      return holder
    end

    local rowA = Row(KNOB.ROW_H_TOP)
    AddNumSelectHalf(rowA, "LEFT",  "spellThreshold", "Castable Buffs (Minutes)",      0, 120, 0.5, 15)
    AddNumSelectHalf(rowA, "RIGHT", "itemThreshold",  "Item Buffs (Minutes)",          0, 120, 0.5, 15)

    local rowB = Row(KNOB.ROW_H_TOP)
    AddNumSelectHalf(rowB, "LEFT",  "durabilityThreshold",  "Durability (%)",          0, 100, 1, 25)
    AddNumSelectHalf(rowB, "RIGHT", "healthstoneThreshold", "Healthstone (Charges)", 0, 3,   1, 1)

    local rowC = Row(KNOB.ROW_H_TOP)
    AddNumSelectHalf(rowC, "LEFT",  "soulstoneThreshold",   "Soulstone (Minutes)",       0, 120, 0.5, 5)
  end)
end)

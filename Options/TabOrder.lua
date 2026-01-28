-- ====================================
-- \Options\TabOrder.lua
-- ====================================
-- This file defines the order of tabs in the options panel.

local addonName, ns = ...
ns.Options = ns.Options or {}
local O = ns.Options

-- The order in which tabs appear in the options panel.
O.TAB_ORDER = {
  "Info",
  "Layout",
  "Thresholds",
  "Ignore",
  "Alerts",
  "Customize",
}

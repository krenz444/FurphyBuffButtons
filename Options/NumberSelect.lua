-- ====================================
-- \Options\NumberSelect.lua
-- ====================================
-- This file implements a custom number selection widget with increment/decrement arrows.

local addonName, ns = ...
ns.NumberSelect = ns.NumberSelect or {}
local O = ns.Options or {}

local LABEL_GAP_Y   = -15
local BOTTOM_PAD_Y  = 8

local POP_KEY = "CRB_NUMBERSELECT_RESET"
if not StaticPopupDialogs[POP_KEY] then
  StaticPopupDialogs[POP_KEY] = {
    text = "%s",
    button1 = YES, button2 = NO,
    OnAccept = function(self) if self.data then self.data() end end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
end
-- Shows a confirmation popup for resetting the value.
local function Confirm(msg, fn) StaticPopup_Show(POP_KEY, msg or "Reset value?", nil, fn) end

-- Resolves the font to use for the panel.
local function ResolvePanelFont()
  if O and O.ResolvePanelFont then return O.ResolvePanelFont() end
  local fallback = GameFontNormal and select(1, GameFontNormal:GetFont())
  return fallback or "Fonts\\FRIZQT__.TTF"
end

local ARROW_W, ARROW_H = 24, 24
-- Creates an arrow button.
local function makeArrow(parent, side)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(ARROW_W, ARROW_H)
  local tx = b:CreateTexture(nil, "ARTWORK")
  tx:SetAllPoints()
  tx:SetAtlas(side == "LEFT" and "common-icon-backarrow-disable" or "common-icon-forwardarrow-disable", true)
  b._atlasDisabled = side == "LEFT" and "common-icon-backarrow-disable" or "common-icon-forwardarrow-disable"
  b._atlasEnabled  = side == "LEFT" and "common-icon-backarrow"         or "common-icon-forwardarrow"
  b._tex = tx
  b:SetScript("OnEnter", function(self) if self:IsEnabled() then self._tex:SetAtlas(self._atlasEnabled, true) end end)
  b:SetScript("OnLeave", function(self) self._tex:SetAtlas(self._atlasDisabled, true) end)
  return b
end

-- Creates a number selection widget.
function ns.NumberSelect.Create(parent, args)
  args = args or {}
  local minV    = tonumber(args.min) or 0
  local maxV    = tonumber(args.max) or 999
  local step    = tonumber(args.step) or 1
  local value   = tonumber(args.value) or minV
  local defV    = tonumber(args.default) or value
  local onChange = args.onChange

  local holder = CreateFrame("Frame", nil, parent)
  local ebH = 59
  holder:SetSize(260, ebH + 32)

  local edit = CreateFrame("EditBox", nil, holder, "InputBoxTemplate")
  edit:SetAutoFocus(false)
  edit:SetFont(ResolvePanelFont(), 28, "")
  edit:SetSize(160, ebH)
  edit:SetPoint("CENTER")
  edit:SetJustifyH("CENTER")
  edit:SetClipsChildren(false)

  local reset = CreateFrame("Button", nil, edit)
  reset:SetSize(math.floor(ARROW_W * 0.7), math.floor(ARROW_H * 0.7))
  reset:SetPoint("RIGHT", edit, "RIGHT", -6, 0)
  reset:SetFrameLevel((edit:GetFrameLevel() or 1) + 5)
  reset:EnableMouse(true)
  local rtex = reset:CreateTexture(nil, "ARTWORK")
  rtex:SetAllPoints()
  rtex:SetAtlas("common-icon-undo", true)
  reset:Hide()

  reset:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(BLIZZARD_COMBAT_LOG_MENU_RESET, 1, 1, 1)
    GameTooltip:Show()
  end)
  reset:HookScript("OnLeave", function() GameTooltip:Hide() end)
  
  local left  = makeArrow(holder, "LEFT")
  local right = makeArrow(holder, "RIGHT")
  left:SetPoint("RIGHT", edit, "LEFT", -8, 0)
  right:SetPoint("LEFT", edit, "RIGHT", 8, 0)

  local lab = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  lab:SetFont(ResolvePanelFont(), (O.SIZE_LABEL or 14), "")
  lab:SetText(args.label or "")
  lab:ClearAllPoints()
  lab:SetPoint("TOP", edit, "BOTTOM", 0, -LABEL_GAP_Y)

  local function anyMouseOver()
    return holder:IsMouseOver() or edit:IsMouseOver() or left:IsMouseOver()
        or right:IsMouseOver() or reset:IsMouseOver()
  end
  local function showReset() reset:Show() end
  local function hideReset()
    C_Timer.After(0, function()
      if not anyMouseOver() then reset:Hide() end
    end)
  end
  for _, f in ipairs({holder, edit, left, right, reset}) do
    f:HookScript("OnEnter", showReset)
    f:HookScript("OnLeave", hideReset)
  end

  local function clamp(v)
    v = tonumber(v) or value
    if v < minV then v = minV end
    if v > maxV then v = maxV end
    if step and step > 0 then
      v = math.floor((v - minV)/step + 0.5)*step + minV
      if v < minV then v = minV end
      if v > maxV then v = maxV end
    end
    return v
  end
  local function apply(v, silent)
    value = clamp(v)
    edit:SetText(tostring(value))
    if onChange and not silent then onChange(value) end
  end
  apply(value, true)

  left:SetScript("OnClick",  function() if holder._enabled then apply(value - step) end end)
  right:SetScript("OnClick", function() if holder._enabled then apply(value + step) end end)
  edit:SetScript("OnEnterPressed", function(self) apply(self:GetText()); self:ClearFocus() end)
  edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self:SetText(tostring(value)) end)
  reset:SetScript("OnClick", function()
    Confirm(("Reset %s to default?"):format(args.label or "value"), function() apply(defV) end)
  end)

  local function relayout()
    local pw = (parent and parent.GetWidth and parent:GetWidth()) or 260
    local PAD = 12
    local targetW = math.min(260, math.max(140, pw - PAD*2))
    holder:SetWidth(targetW)

    local arrowsTotal = (ARROW_W * 2) + 16
    local editW = math.max(80, targetW - arrowsTotal)
    edit:SetWidth(editW)

    local labelH = lab:GetStringHeight() or (O.SIZE_LABEL or 14)
    if labelH <= 0 then labelH = (O and O.SIZE_LABEL) or 14 end

    local totalH = ebH + LABEL_GAP_Y + labelH + BOTTOM_PAD_Y
    holder:SetHeight(totalH)
  end
  holder:HookScript("OnShow", relayout)
  if parent and parent.HookScript then
    parent:HookScript("OnSizeChanged", function() if holder:IsVisible() then relayout() end end)
  end
  relayout()

  holder._enabled = true
  function holder:SetEnabled(on)
    self._enabled = (on and true or false)
    edit:SetEnabled(self._enabled)
    left:SetEnabled(self._enabled);  right:SetEnabled(self._enabled)
    local a = self._enabled and 1 or 0.35
    edit:SetAlpha(a); left:SetAlpha(a); right:SetAlpha(a); reset:SetAlpha(a); lab:SetAlpha(a)
  end
  function holder:SetValue(v, silent) apply(v, silent) end
  function holder:GetValue() return value end
  function holder:SetRange(min2, max2) minV, maxV = min2 or minV, max2 or maxV end
  function holder:SetStep(step2) step = step2 or step end
  function holder:SetDefault(def) defV = def or defV end
  function holder:LabelText(t) lab:SetText(t or "") end

  return holder
end

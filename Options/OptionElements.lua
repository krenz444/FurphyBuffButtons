-- ====================================
-- \Options\OptionElements.lua
-- ====================================
-- This file provides a library of reusable UI elements for the options panel,
-- such as checkboxes, color swatches, font pickers, and layout managers.

local addonName, ns = ...
ns.Options = ns.Options or {}
local O = ns.Options

ns.OptionElements = ns.OptionElements or {}
local OE = ns.OptionElements

ns._optionSyncers = ns._optionSyncers or {}
-- Syncs all registered option elements with the current database values.
function ns.SyncOptions()
  for i = 1, #ns._optionSyncers do
    local f = ns._optionSyncers[i]
    if type(f) == "function" then
      local ok = pcall(f)
    end
  end
end

local function DB() return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {} end
local defaults = O.DEFAULTS or {}

-- Theme constants for UI elements.
local THEME = {
  fontPath      = function() if O and O.ResolvePanelFont then return O.ResolvePanelFont() end return "Fonts\\FRIZQT__.TTF" end,
  sizeLabel     = function() return (O.SIZE_LABEL or 14) end,
  sizeEdit      = function() return (O.SIZE_EDITBOX or 14) end,

  rowH          = 52,
  rowGap        = 3,
  colGap        = 0,
  leftPad       = 12,

  valueW        = function() return (O.TEXT_VALUE_W or 34) end,
  resetW        = function() return 17 end,
  resetH        = function() return 17 end,
  checkboxBox   = function() return (O.TEXT_CHECKBOX_W or 20) end,
  swatchW       = function() return (O.TEXT_SWATCH_W or 32) end,
  swatchH       = function() return (O.TEXT_SWATCH_H or 20) end,

  cardBG        = {0.09,0.10,0.14,0.95},
  cardBR        = {0.20,0.22,0.28,1},
  wellBG        = {0.05,0.06,0.08,1},
  wellBR        = {0.22,0.24,0.30,1},
  btnBG         = {0.22,0.24,0.30,1},
  btnBR         = {0.40,0.45,0.55,1},
  tickTint      = {0.35,0.80,1.00,1},
}

-- Helper to paint a frame with a backdrop.
local function PaintBackdrop(frame, bg, br)
  frame:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
  frame:SetBackdropColor(unpack(bg or THEME.cardBG))
  frame:SetBackdropBorderColor(unpack(br or THEME.cardBR))
end

-- Helper to paint only the border of a frame.
local function PaintBorderOnly(frame, br)
  frame:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
  frame:SetBackdropColor(0,0,0,0)
  frame:SetBackdropBorderColor(unpack(br or THEME.wellBR))
end

local _pendingOptionsRefresh
local function _safeCall(f, ...) if type(f)=="function" then local ok = pcall(f, ...) return ok end return false end
-- Notifies the addon that options have changed, triggering updates.
local function NotifyChanged()
  if _pendingOptionsRefresh then return end
  _pendingOptionsRefresh = true
  C_Timer.After(0.05, function()
    _pendingOptionsRefresh = false
    if O and _safeCall(O.OnOptionChanged) then return end
    if ns and (_safeCall(ns.RequestRebuild) or _safeCall(ns.RebuildDisplayables) or _safeCall(ns.RefreshEverything) or _safeCall(ns.PushRender) or _safeCall(ns.RenderAll)) then return end
    if _G and (_safeCall(_G.ClickableRaidBuffs_Rebuild) or _safeCall(_G.ClickableRaidBuffs_ForceRefresh) or _safeCall(_G.ClickableRaidBuffs_PushRender)) then return end
  end)
end

local POPUP_KEY = "CRB_CONFIRM_RESET"
if not StaticPopupDialogs[POPUP_KEY] then
  StaticPopupDialogs[POPUP_KEY] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data) if data and data.run then data.run() end end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
  }
end
-- Shows a confirmation popup for resetting settings.
local function ConfirmReset(run, what)
  local msg = "Reset "..(what or "setting").." to default?"
  StaticPopup_Show(POPUP_KEY, msg, nil, { run = run })
end

-- Styles a button with a reset icon.
function OE.StyleButton(btn)
  if not btn._icon then
    btn._icon = btn:CreateTexture(nil, "ARTWORK")
    btn._icon:SetAtlas("common-icon-undo", true)
    btn._icon:SetPoint("CENTER")
    btn._icon:SetSize(13, 13)
    btn._icon:SetRotation(0)
  end
end

-- Raises a frame above others.
local function _raiseAbove(btn, frames)
  local top = btn:GetFrameLevel()
  for i=1,#frames do
    local f = frames[i]
    if f and f.GetFrameLevel then
      local lvl = f:GetFrameLevel() or 0
      if lvl >= top then top = lvl + 1 end
    end
  end
  btn:SetFrameLevel(top + 5)
  local p = btn:GetParent() or UIParent
  if p and p.GetFrameStrata then btn:SetFrameStrata(p:GetFrameStrata() or "MEDIUM") end
end

-- Sets tooltip font to match addon style.
local function _setTooltipFont()
  local face = (O and O.ResolvePanelFont and O.ResolvePanelFont()) or "Fonts\\FRIZQT__.TTF"
  if GameTooltipText then
    GameTooltipText._crbOld = { GameTooltipText:GetFont() }
    GameTooltipText:SetFont(face, select(2, GameTooltipText:GetFont()))
  end
  if GameTooltipHeaderText then
    GameTooltipHeaderText._crbOld = { GameTooltipHeaderText:GetFont() }
    GameTooltipHeaderText:SetFont(face, select(2, GameTooltipHeaderText:GetFont()))
  end
  if GameTooltipTextSmall then
    GameTooltipTextSmall._crbOld = { GameTooltipTextSmall:GetFont() }
    GameTooltipTextSmall:SetFont(face, select(2, GameTooltipTextSmall:GetFont()))
  end
end
-- Restores tooltip font.
local function _restoreTooltipFont()
  local function restore(obj)
    if obj and obj._crbOld then
      obj:SetFont(obj._crbOld[1], obj._crbOld[2], obj._crbOld[3])
      obj._crbOld = nil
    end
  end
  restore(GameTooltipText); restore(GameTooltipHeaderText); restore(GameTooltipTextSmall)
end

-- Creates a new reset button.
function OE.NewResetButton(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(THEME.resetW(), THEME.resetH())
  OE.StyleButton(b)
  b:EnableMouse(true)
  b:Hide()
  b:SetScript("OnShow", function(self) _raiseAbove(self, { self:GetParent() }) end)
  b:SetScript("OnEnter", function(self)
    _setTooltipFont()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(BLIZZARD_COMBAT_LOG_MENU_RESET, 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide(); _restoreTooltipFont() end)
  return b
end

-- Installs hover behavior to show/hide the reset button.
local function InstallHoverReveal(resetBtn, watched)
  local function anyOver()
    if resetBtn:IsMouseOver() then return true end
    for i = 1, #watched do
      local w = watched[i]
      if w and w.IsMouseOver and w:IsMouseOver() then return true end
    end
    return false
  end
  local function show() resetBtn:Show() end
  local function tryHide()
    C_Timer.After(0.05, function()
      if not anyOver() then resetBtn:Hide() end
    end)
  end
  local function hook(f)
    if f and f.HookScript then
      f:HookScript("OnEnter", show)
      f:HookScript("OnLeave", tryHide)
    end
  end
  for i = 1, #watched do hook(watched[i]) end
  hook(resetBtn)
end

-- Attaches a reset button to a parent frame.
function OE.AttachResetTo(parent, point, relTo, relPoint, x, y, onClick)
  local btn = OE.NewResetButton(parent)
  btn:ClearAllPoints()
  btn:SetPoint(point or "BOTTOMRIGHT", relTo or parent, relPoint or "BOTTOMRIGHT", x or 0, y or 0)
  if type(onClick) == "function" then
    btn:SetScript("OnClick", function(self) onClick(self) end)
  else
    btn:SetScript("OnClick", nil)
  end
  InstallHoverReveal(btn, { parent })
  _raiseAbove(btn, { parent })
  return btn
end

-- Creates a color swatch button.
local function NewColorSwatch(parent)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(THEME.swatchW(), THEME.swatchH())
  PaintBackdrop(b, THEME.wellBG, THEME.wellBR)
  local tex = b:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  b._paint = function(_, c) tex:SetColorTexture(c.r or 1, c.g or 1, c.b or 1, c.a or 1) end
  local border = CreateFrame("Frame", nil, b, "BackdropTemplate")
  border:SetPoint("TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", 1, -1)
  border:SetBackdrop({ edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
  border:SetBackdropBorderColor(0,0,0,1)
  return b
end

-- Creates a checkbox button.
local function NewCheckbox(parent)
  local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
  cb:SetSize(THEME.checkboxBox(), THEME.checkboxBox())
  PaintBackdrop(cb, THEME.wellBG, THEME.wellBR)

  local tick = cb:CreateTexture(nil, "ARTWORK")
  tick:SetAtlas("common-icon-checkmark", true)
  tick:SetPoint("CENTER")
  tick:SetSize(THEME.checkboxBox()-4, THEME.checkboxBox()-4)
  tick:SetVertexColor(unpack(THEME.tickTint))
  tick:Hide()
  cb._tick = tick

  local rawSetChecked = getmetatable(cb).__index.SetChecked
  function cb:SetChecked(state)
    rawSetChecked(self, state and true or false)
    self._tick:SetShown(state and true or false)
  end

  cb:SetScript("OnClick", function(self)
    local checked = self:GetChecked()
    self._tick:SetShown(checked)
    if self._onToggle then self:_onToggle(checked) end
  end)

  return cb
end

-- Layout manager for a single column flow.
local function beginFlow(parent, opts)
  local ctx = { holder = parent, y = 0, gap = (opts and opts.rowGap) or THEME.rowGap, cells = {} }
  function ctx:_place(cell, h)
    h = h or THEME.rowH
    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT", self.holder, "TOPLEFT", 0, -self.y)
    cell:SetPoint("TOPRIGHT", self.holder, "TOPRIGHT", 0, -self.y)
    cell:SetHeight(h)
    self.y = self.y + h + self.gap
    self.holder:SetHeight(self.y)
    table.insert(self.cells, cell)
  end
  return ctx
end

-- Layout manager for a grid.
local function beginGrid(parent, opts)
  local w = math.max(200, parent:GetWidth() or 700)
  local ctx = { holder = parent, col = 1, row = 1, colGap = (opts and opts.colGap) or THEME.colGap, rowGap = (opts and opts.rowGap) or THEME.rowGap, rowH = (opts and opts.rowH) or THEME.rowH, width = w, cells = {} }
  function ctx:_place(cell)
    local colW = (self.width - self.colGap) * 0.5
    local x = (self.col == 1) and 0 or (colW + self.colGap)
    local y = -((self.row - 1) * (self.rowH + self.rowGap))
    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT", self.holder, "TOPLEFT", x, y)
    cell:SetPoint("TOPRIGHT", self.holder, "TOPLEFT", x + colW, y)
    cell:SetHeight(self.rowH)
    self.col = self.col + 1
    if self.col > 2 then self.col = 1; self.row = self.row + 1 end
    local usedRows = (self.row - 1) + ((self.col==1) and 0 or 1)
    local needH = (usedRows * (self.rowH + self.rowGap))
    self.holder:SetHeight(needH)
    table.insert(self.cells, cell)
  end
  return ctx
end

-- Layout manager for a triple column grid.
local function beginTriple(parent, opts)
  local ctx = {
    holder   = parent,
    colGap   = (opts and opts.colGap) or THEME.colGap,
    rowGap   = (opts and opts.rowGap) or THEME.rowGap,
    rowH     = (opts and opts.rowH)   or THEME.rowH,
    cells    = {},
    rowsH    = {},
    occupied = {},
  }

  function ctx:_colWidth()
    local w = math.max(200, self.holder:GetWidth() or 700)
    return (w - self.colGap * 2) / 3
  end

  function ctx:_ensureRow(r)
    if not self.occupied[r] then self.occupied[r] = {false,false,false} end
    if not self.rowsH[r] then self.rowsH[r] = self.rowH end
  end

  local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end

  function ctx:_findRow(col, span, start)
    local r = start or 1
    while true do
      self:_ensureRow(r)
      local ok = true
      for c = col, col+span-1 do if self.occupied[r][c] then ok=false; break end end
      if ok then return r end
      r = r + 1
    end
  end

  function ctx:_mark(r, col, span, h)
    self:_ensureRow(r)
    for c = col, col+span-1 do self.occupied[r][c] = true end
    self.rowsH[r] = math.max(self.rowsH[r], h or self.rowH)
    local total = 0
    for i=1,#self.rowsH do total = total + self.rowsH[i] + (i>1 and self.rowGap or 0) end
    self.holder:SetHeight(total)
  end

  function ctx:_rowTopY(r)
    local y = 0
    for i=1,r-1 do y = y + self.rowsH[i] + self.rowGap end
    return -y
  end

  function ctx:_placeWithSpec(cell, args)
    local span = clamp((args and args.span) or 1, 1, 3)
    local col  = clamp((args and args.col)  or 1, 1, 3)
    if col + span - 1 > 3 then span = 3 - col + 1 end
    local h    = (args and (args.rowH or args.h)) or self.rowH
    local row  = (args and args.row) or self:_findRow(col, span, 1)

    local colW = self:_colWidth()
    local x = (col-1) * (colW + self.colGap)
    local w = colW * span + self.colGap * (span - 1)
    local y = self:_rowTopY(row)

    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT",  self.holder, "TOPLEFT", x, y)
    cell:SetPoint("TOPRIGHT", self.holder, "TOPLEFT", x + w, y)
    cell:SetHeight(h)

    table.insert(self.cells, {frame=cell, col=col, span=span, row=row, h=h})
    self:_mark(row, col, span, h)
  end

  function ctx:_reflow()
    local colW = self:_colWidth()
    local rowTop = {}
    local acc = 0
    for r=1,#self.rowsH do rowTop[r] = -acc; acc = acc + self.rowsH[r] + self.rowGap end
    for _,it in ipairs(self.cells) do
      local x = (it.col-1) * (colW + self.colGap)
      local w = colW * it.span + self.colGap * (it.span - 1)
      local y = rowTop[it.row] or 0
      it.frame:ClearAllPoints()
      it.frame:SetPoint("TOPLEFT",  self.holder, "TOPLEFT", x, y)
      it.frame:SetPoint("TOPRIGHT", self.holder, "TOPLEFT", x + w, y)
      it.frame:SetHeight(it.h)
    end
    local total = 0
    for i=1,#self.rowsH do total = total + self.rowsH[i] + (i>1 and self.rowGap or 0) end
    self.holder:SetHeight(total)
  end

  parent:HookScript("OnSizeChanged", function() ctx:_reflow() end)
  parent:HookScript("OnShow", function() C_Timer.After(0, function() ctx:_reflow() end) end)

  return ctx
end

local function clampNum(v, lo, hi)
  v = tonumber(v) or lo
  if v < lo then v = lo elseif v > hi then v = hi end
  return math.floor(v + 0.5)
end

-- Builds a text color picker cell.
local function buildTextColorCell(parent, args)
  local cell = CreateFrame("Frame", nil, parent)
  cell:EnableMouse(true)

  local sw = NewColorSwatch(cell)
  sw:ClearAllPoints()
  sw:SetPoint("CENTER", cell, "CENTER", 0, 4)

  local lab = cell:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  lab:SetFont(THEME.fontPath(), THEME.sizeLabel(), "")
  lab:SetPoint("TOP", sw, "BOTTOM", 0, -6)
  lab:SetJustifyH("CENTER")
  lab:SetText(args.label or args.colorKey or "Color")

  local reset = OE.NewResetButton(cell)
  reset:SetPoint("LEFT", sw, "RIGHT", 6, 0)

  local d  = DB()
  local key = args.colorKey
  local def = defaults[key] or { r=1,g=1,b=1,a=1 }

  local function applyColor(c)
    d[key] = { r=c.r, g=c.g, b=c.b, a=c.a or 1 }
    sw:_paint(d[key])
    if ns.SetTextColor and args.which then
      local w = tostring(args.which)
      if w=="top" or w=="bottom" or w=="center" or w=="timer" or w=="corner" then ns.SetTextColor(w, c.r, c.g, c.b, c.a) end
    end
    if args.onChange then args.onChange() end
    NotifyChanged()
  end

  sw:SetScript("OnClick", function()
    local before = d[key] or def
    ColorPickerFrame:SetupColorPickerAndShow({
      r=before.r, g=before.g, b=before.b, opacity=before.a or 1, hasOpacity=true,
      swatchFunc  = function() local r,g,b = ColorPickerFrame:GetColorRGB(); local a=ColorPickerFrame:GetColorAlpha() or 1; applyColor({r=r,g=g,b=b,a=a}) end,
      opacityFunc = function() local r,g,b = ColorPickerFrame:GetColorRGB(); local a=ColorPickerFrame:GetColorAlpha() or 1; applyColor({r=r,g=g,b=b,a=a}) end,
      cancelFunc  = function(prev) if prev then applyColor({r=prev.r,g=prev.g,b=prev.b,a=prev.opacity or 1}) end end,
    })
  end)

  reset:SetScript("OnClick", function() ConfirmReset(function() applyColor(def) end, args.label or (args.colorKey or "Color")) end)

  InstallHoverReveal(reset, { cell, sw, lab })
  _raiseAbove(reset, {cell, sw})

  applyColor(d[key] or def)
  return cell
end

-- Builds a font picker cell.
local function buildFontPickerCell(parent, args)
  local cell = CreateFrame("Frame", nil, parent)
  cell:EnableMouse(true)

  local d     = DB()
  local key   = (args and args.key) or "fontName"
  local LSM   = LibStub("LibSharedMedia-3.0")
  local names = {}
  for _, n in ipairs(LSM:List("font")) do names[#names+1] = n end
  table.sort(names)
  local defaultFont = defaults[key] or "Friz Quadrata TT"

  local ddBtn = CreateFrame("Button", nil, cell, "BackdropTemplate")
  PaintBackdrop(ddBtn, THEME.wellBG, THEME.wellBR)
  ddBtn:SetPoint("LEFT",  cell, "LEFT",  THEME.leftPad, 0)
  ddBtn:SetPoint("RIGHT", cell, "RIGHT", -THEME.leftPad, 0)
  ddBtn:SetHeight(26)

  local ddText = ddBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  ddText:SetPoint("LEFT", ddBtn, "LEFT", 8, 0)
  ddText:SetJustifyH("LEFT")

  local caret = ddBtn:CreateTexture(nil, "ARTWORK")
  caret:SetAtlas("minimal-scrollbar-arrow-bottom-down", true)
  caret:SetPoint("RIGHT", ddBtn, "RIGHT", -8, 0)

  local line = CreateFrame("Frame", nil, cell)
  line:SetPoint("TOPLEFT", ddBtn, "BOTTOMLEFT", 2, -6)
  line:SetPoint("RIGHT", cell, "RIGHT", -THEME.leftPad, 0)
  line:SetHeight(18)
  line:EnableMouse(true)

  local lab = line:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  lab:SetPoint("LEFT", line, "LEFT", 0, 0)
  lab:SetFont(THEME.fontPath(), THEME.sizeLabel(), "")
  lab:SetText((args and args.label) or key or "Font")

  local reset = OE.NewResetButton(line)
  reset:SetPoint("LEFT", lab, "RIGHT", 6, 0)

  local function applyFont(name)
    d[key] = name
    local face = LSM:Fetch("font", name) or THEME.fontPath()
    ddText:SetFont(face, THEME.sizeLabel(), "")
    ddText:SetText(name)
    if O and O.OnFontChanged then O.OnFontChanged(name) end
    NotifyChanged()
  end

  local blocker = CreateFrame("Frame", nil, UIParent)
  blocker:Hide(); blocker:SetFrameStrata("DIALOG"); blocker:SetAllPoints(UIParent); blocker:EnableMouse(true)

  local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  PaintBackdrop(menu, THEME.cardBG, THEME.cardBR)
  menu:SetFrameStrata("DIALOG"); menu:SetClampedToScreen(true); menu:Hide()

  local scroll = CreateFrame("ScrollFrame", nil, menu, "BackdropTemplate")
  scroll:SetPoint("TOPLEFT", 4, -4); scroll:SetPoint("BOTTOMRIGHT", - (4 + 18), 4)
  local content = CreateFrame("Frame", nil, scroll); scroll:SetScrollChild(content)

  local function CreateBar()
    if ns.ScrollBar and ns.ScrollBar.Create then
      local b = ns.ScrollBar.Create(menu, { width = 16, sliderWidth = 14, minThumbH = 24 })
      b:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, -4)
      b:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -4, 4)
      b:BindToScroll(scroll, content)
      return b
    end
    local b = CreateFrame("Slider", nil, menu, "BackdropTemplate")
    PaintBackdrop(b, THEME.wellBG, THEME.wellBR)
    b:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, -4)
    b:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -4, 4)
    b:SetOrientation("VERTICAL"); b:SetMinMaxValues(0,0); b:SetValue(0)
    local thumb = b:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture("Interface\\Buttons\\WHITE8x8"); thumb:SetColorTexture(0.75,0.80,0.90,1)
    thumb:SetSize(12, 24); b:SetThumbTexture(thumb)
    b:SetScript("OnValueChanged", function(_, v) scroll:SetVerticalScroll(v) end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
      local minV, maxV = b:GetMinMaxValues()
      local v = b:GetValue() - delta * 24
      if v < minV then v = minV elseif v > maxV then v = maxV end
      b:SetValue(v)
    end)
    scroll:SetScript("OnScrollRangeChanged", function(s)
      local max = math.max(0, s:GetVerticalScrollRange())
      b:SetMinMaxValues(0, max)
    end)
    return b
  end

  local bar = CreateBar()

  local itemButtons = {}
  local function rebuildMenu()
    local itemH = 22
    local visMax = 10
    local total = #names
    local w = ddBtn:GetWidth()
    local h = math.min(visMax, total) * itemH + 8
    menu:SetSize(w, h)

    for i = 1, total do
      local b = itemButtons[i]
      if not b then
        b = CreateFrame("Button", nil, content, "BackdropTemplate")
        PaintBackdrop(b, THEME.wellBG, THEME.wellBR)
        b:SetHeight(itemH)
        b._txt = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        b._txt:SetPoint("LEFT", b, "LEFT", 6, 0)
        b:SetScript("OnClick", function(self) applyFont(self._name); menu:Hide(); blocker:Hide() end)
        itemButtons[i] = b
      end
      b._name = names[i]
      local face = LibStub("LibSharedMedia-3.0"):Fetch("font", names[i]) or THEME.fontPath()
      b._txt:SetFont(face, THEME.sizeLabel(), "")
      b._txt:SetText(names[i])
      b:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -((i - 1) * itemH))
      b:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -((i - 1) * itemH))
      b:Show()
    end
    for i = total + 1, #itemButtons do itemButtons[i]:Hide() end

    content:SetSize(w - 22, total * itemH)
    local max = math.max(0, content:GetHeight() - scroll:GetHeight())
    if bar.SetMinMaxValues then bar:SetMinMaxValues(0, max) end
    if bar.SetValue then bar:SetValue(0) end
    scroll:SetVerticalScroll(0)
    if bar.UpdateThumb then bar:UpdateThumb(scroll:GetHeight(), content:GetHeight()) end
    if bar.SetEnabledState then bar:SetEnabledState(max > 0) end
  end

  local function openMenu()
    rebuildMenu()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", ddBtn, "BOTTOMLEFT", 0, -2)
    blocker:Show(); menu:Show()
    caret:SetAtlas("minimal-scrollbar-arrow-top-down", true)
    blocker:SetScript("OnMouseDown", function()
      menu:Hide(); blocker:Hide()
      caret:SetAtlas("minimal-scrollbar-arrow-bottom-down", true)
    end)
    menu:HookScript("OnHide", function()
      caret:SetAtlas("minimal-scrollbar-arrow-bottom-down", true)
    end)
  end

  ddBtn:SetScript("OnClick", function()
    if menu:IsShown() then
      menu:Hide(); blocker:Hide()
      caret:SetAtlas("minimal-scrollbar-arrow-bottom-down", true)
    else
      openMenu()
    end
  end)

  reset:SetScript("OnClick", function()
    local defApply = function() applyFont(defaultFont) end
    local what = (args and args.label) or key or "Font"
    local msg = "Reset "..what.." to default?"
    if StaticPopupDialogs["CRB_CONFIRM_RESET"] then
      StaticPopup_Show("CRB_CONFIRM_RESET", msg, nil, { run = defApply })
    else
      defApply()
    end
  end)

  InstallHoverReveal(reset, { cell, ddBtn, line, lab, ddText })
  _raiseAbove(reset, { cell, ddBtn, line })

  applyFont(d[key] or defaultFont)
  return cell
end

-- Creates a single column layout.
function OE.SingleColumn(parent, buildFn)
  local flow = beginFlow(parent)
  local api  = {}

  function api:FontPicker(args)
    local c = buildFontPickerCell(flow.holder, args); flow:_place(c, 72); return c
  end
  function api:TextColor(args)
    local c = buildTextColorCell(flow.holder, args);  flow:_place(c, THEME.rowH); return c
  end
  function api:Checkbox(args)
    local cell = CreateFrame("Frame", nil, flow.holder); cell:EnableMouse(true)
    local lab = cell:CreateFontString(nil,"ARTWORK","GameFontHighlight")
    lab:SetPoint("LEFT", THEME.leftPad, 0)
    lab:SetFont(THEME.fontPath(), THEME.sizeLabel(), "")
    lab:SetText(args.label or "")
    local cb = NewCheckbox(cell); cb:SetPoint("LEFT", lab, "RIGHT", 10, 0)
    local reset = OE.NewResetButton(cell); reset:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -4)
    local d = DB(); local key = args.key; local def = (defaults[key] ~= false)
    cb._onToggle = function(_, v) d[key]=v; if args.onChange then args.onChange(v) end; NotifyChanged() end
    local function sync()
      cb:SetChecked((DB()[key] ~= nil) and DB()[key] or def)
    end
    cb:SetChecked((d[key] ~= nil) and d[key] or def)
    cell:HookScript("OnShow", sync)
    ns._optionSyncers[#ns._optionSyncers+1] = sync
    reset:SetScript("OnClick", function() ConfirmReset(function() cb:SetChecked(def); d[key]=def; if args.onChange then args.onChange(def) end; NotifyChanged() end, args.label or key) end)
    InstallHoverReveal(reset, { cell, cb, lab }); _raiseAbove(reset, {cell, cb})
    flow:_place(cell, args and args.rowH or 34)
    return cell, cb
  end

  if type(buildFn) == "function" then buildFn(api) end
  return flow.holder
end

-- Creates a dual column layout.
function OE.DualColumn(parent, buildFn)
  local grid = beginGrid(parent)
  local api  = {}
  function api:TextColor(args)
    local c = buildTextColorCell(grid.holder, args); grid:_place(c); return c
  end
  if type(buildFn) == "function" then buildFn(api) end
  return grid.holder
end

-- Creates a triple column layout.
function OE.TripleColumn(parent, buildFn)
  local grid = beginTriple(parent)
  local api  = {}

  function api:FontPicker(args)
    local c = buildFontPickerCell(grid.holder, args); grid:_placeWithSpec(c, args or {}); return c
  end
  function api:TextColor(args)
    local c = buildTextColorCell(grid.holder, args);  grid:_placeWithSpec(c, args or {}); return c
  end
  function api:Checkbox(args)
    local cell = CreateFrame("Frame", nil, grid.holder); cell:EnableMouse(true)
    local lab = cell:CreateFontString(nil,"ARTWORK","GameFontHighlight"); lab:SetFont(THEME.fontPath(), THEME.sizeLabel(), "")
    local cb  = NewCheckbox(cell)
    local centerBelow = args and args.centerBelow
    local yOff = (args and args.yOffset) or 0
    local function layoutCentered()
      cb:ClearAllPoints(); cb:SetPoint("TOP", cell, "TOP", 0, -6 + yOff)
      lab:ClearAllPoints(); lab:SetPoint("TOP", cb, "BOTTOM", 0, -4); lab:SetJustifyH("CENTER")
    end
    local function layoutInline()
      lab:ClearAllPoints(); lab:SetPoint("LEFT", cell, "LEFT", THEME.leftPad, yOff); lab:SetJustifyH("LEFT")
      cb:ClearAllPoints();  cb:SetPoint("LEFT", lab, "RIGHT", 10, 0)
    end
    if centerBelow then layoutCentered() else layoutInline() end
    lab:SetText(args.label or "")
    local d = DB(); local key = args.key; local def = (defaults[key] ~= false)
    cb._onToggle = function(_, v) d[key]=v; if args.onChange then args.onChange(v) end; NotifyChanged() end
    local function sync()
      cb:SetChecked((DB()[key] ~= nil) and DB()[key] or def)
    end
    cb:SetChecked((d[key] ~= nil) and d[key] or def)
    cell:HookScript("OnShow", sync)
    ns._optionSyncers[#ns._optionSyncers+1] = sync
    local reset
    if not (args and args.noReset) then
      reset = OE.NewResetButton(cell); reset:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -4)
      InstallHoverReveal(reset, { cell, cb, lab }); _raiseAbove(reset, {cell, cb})
      reset:SetScript("OnClick", function() ConfirmReset(function() cb:SetChecked(def); d[key]=def; if args.onChange then args.onChange(def) end; NotifyChanged() end, args.label or key) end)
    end
    grid:_placeWithSpec(cell, args or {})
    return cell, cb
  end
  function api:Blank(args)
    local spacer = CreateFrame("Frame", nil, grid.holder)
    grid:_placeWithSpec(spacer, args or {})
    return spacer
  end

  if type(buildFn) == "function" then buildFn(api) end
  return grid.holder
end

ns.OptionElements = OE

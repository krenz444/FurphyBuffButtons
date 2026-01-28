-- ====================================
-- \Options\Title.lua
-- ====================================
-- This file creates the title section of the options panel, including the addon name,
-- author credits, logo, and copyable links (though links are currently removed).

local addonName, ns = ...
local O = ns.Options
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Configuration for the title section layout
local CFG = {
  TOP_PAD = 10,

  Row = {
    mode       = "fixed",
    fixedHeight= 85,
    bottomPad  = -20, 
    minHeight  = 5,
  },

  Title = {
    anchorTo   = "box",
    point      = "TOPLEFT",
    relPoint   = "TOPLEFT",
    x          = 12,
    y          = -10,
    fontName   = O.TITLE_FONT_NAME,
    fontSize   = O.SIZE_TITLE,
  },

  Author = {
    anchorTo   = "box",
    point      = "TOPLEFT",
    relPoint   = "TOPLEFT",
    x          = O.AUTHOR_LABEL_X or 208,
    y          = O.AUTHOR_LABEL_Y or -47,
    fontName   = O.AUTHOR_LABEL_FONT_NAME,
    fontSize   = O.AUTHOR_LABEL_SIZE or O.SIZE_COPY_LABEL,
  },

  Logo = {
    file       = "Interface\\AddOns\\"..addonName.."\\Media\\furphyLogo.tga",
    anchorTo   = "box",
    point      = "TOPRIGHT",
    relPoint   = "TOPRIGHT",
    x          = 8,
    y          = 12,
    size       = 150,
  },

  Inputs = {
    anchorTo      = "box",
    point         = "TOPLEFT",
    relPoint      = "TOPLEFT",
    x             = 20,
    y             = -85,

    rightAnchorTo = "logo",
    rightPoint    = "RIGHT",
    rightRelPoint = "RIGHT",
    rightX        = 0,
    rightY        = 0,

    layout        = "fixed",
    colGap        = 14,
    labelGap      = 6,

    minColWidth   = 280,
    maxColWidth   = 560,
    extraForText  = 220,

    equalMinCol   = 260,

    col1Width     = 175,
    col2Width     = 235,
  },

  Edit = {
    height         = 22,
    textInsets     = { 8, 8, 2, 2 },
    widthPadRight  = 26,
    checkSize      = 18,
    fontDelta      = -2,
  },
}

local SHIFT_UP = (O.SECTION_CONTENT_TOP_PAD or 36) - CFG.TOP_PAD

-- Visual feedback for copying text
local function PulseOK(ok)
  if not ok then return end
  ok:Show()
  C_Timer.After(1.0, function() if ok:IsShown() then ok:Hide() end end)
  local path = LSM and LSM.Fetch and LSM:Fetch("sound", "Alerts: |cffff7d0Ffunki.gg|r Ding Dong", true)
  if path then PlaySoundFile(path, "Master") else PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
end

-- Helper to resolve anchor frames by tag
local function anchorFrameByTag(tag, env)
  if tag == "box"    then return env.box end
  if tag == "canvas" then return env.canvas end
  if tag == "title"  then return env.title end
  if tag == "author" then return env.author end
  if tag == "logo"   then return env.logo end
  return env.canvas
end

-- Creates a copyable text field with a label
local function MakeCopyColumn(parent, labelText, urlText)
  local col = CreateFrame("Frame", nil, parent)
  col:SetHeight(CFG.Edit.height + 18)

  local lab = col:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  lab._CRB_CopyLabel = true
  lab:SetPoint("TOPLEFT", 0, 0)
  lab:SetJustifyH("LEFT")
  lab:SetText(labelText or "")
  if O and O.ResolvePanelFont then
    lab:SetFont(O.ResolvePanelFont(), O.SIZE_LABEL or 12, "")
  end

  local rowF = CreateFrame("Frame", nil, col)
  rowF:SetPoint("TOPLEFT", lab, "BOTTOMLEFT", 0, -CFG.Inputs.labelGap)
  rowF:SetPoint("RIGHT", 0, 0)
  rowF:SetHeight(CFG.Edit.height)

  local eb = CreateFrame("EditBox", nil, rowF, "InputBoxTemplate")
  eb:SetAutoFocus(false)
  eb:SetTextInsets(unpack(CFG.Edit.textInsets))
  eb:SetText(urlText or "")
  eb:SetCursorPosition(0)
  eb:SetFont(
    O.ResolvePanelFont(),
    math.max(12, (O.SIZE_EDITBOX or 14) + (CFG.Edit.fontDelta or 0)),
    ""
  )
  eb:ClearAllPoints()
  eb:SetPoint("LEFT", 0, 0)
  eb:SetPoint("RIGHT", -(CFG.Edit.widthPadRight), 0)
  eb:SetHeight(CFG.Edit.height)
  if eb.Left   then eb.Left:SetHeight(CFG.Edit.height) end
  if eb.Right  then eb.Right:SetHeight(CFG.Edit.height) end
  if eb.Middle then eb.Middle:SetHeight(CFG.Edit.height) end

  local ok = rowF:CreateTexture(nil, "ARTWORK")
  ok:SetAtlas("common-icon-checkmark", true)
  ok:SetSize(CFG.Edit.checkSize, CFG.Edit.checkSize)
  ok:SetPoint("LEFT", eb, "RIGHT", 6, 0)
  ok:Hide()

  local function SelectAll()
    eb:SetText(urlText or "")
    eb:SetFocus()
    eb:HighlightText()
    eb:SetCursorPosition(0)
  end
  local function NextTickSelect() C_Timer.After(0, SelectAll) end

  eb:SetScript("OnEditFocusGained", NextTickSelect)
  eb:SetScript("OnMouseDown",       NextTickSelect)
  eb:SetScript("OnMouseUp",         NextTickSelect)
  eb:SetScript("OnTextChanged", function(self, user) if user then NextTickSelect() end end)
  eb:SetScript("OnKeyDown", function(self, key)
    local ctrl = IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown())
    if ctrl and (key == "C" or key == "c") then
      PulseOK(ok)
      NextTickSelect()
    end
  end)

  col._labelFS = lab
  return col
end

-- Registers the title section
O.RegisterSection(function(AddSection)
  AddSection("", function(content, Row)
    local row = Row(CFG.Row.mode == "fixed" and CFG.Row.fixedHeight or 120)

    local canvas = CreateFrame("Frame", nil, row)
    canvas:SetPoint("TOPLEFT", row, "TOPLEFT", 0, SHIFT_UP)
    canvas:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)

    local box = content:GetParent()

    local title = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    do
      local anchor = anchorFrameByTag(CFG.Title.anchorTo, {box=box, canvas=canvas})
      title._CRB_Title = true
      title:SetPoint(CFG.Title.point, anchor, CFG.Title.relPoint, CFG.Title.x, CFG.Title.y)
      title:SetFont(O.GetFontPathByName(CFG.Title.fontName), CFG.Title.fontSize, "OUTLINE")
      title:SetText("|cff00ccffClickable Raid Buffs|r")
      title:SetTextColor(0.92, 0.94, 1, 1)
    end

    local author = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    do
      local anchor = anchorFrameByTag(CFG.Author.anchorTo, {box=box, canvas=canvas})
      author._CRB_AuthorLabel = true
      author:SetText(O.AUTHOR_LABEL_TEXT or "By |cffff7d0FFurphy|r\ncontinuation of addon by Funki (funki.gg)")
      author:SetFont(O.GetFontPathByName(CFG.Author.fontName), CFG.Author.fontSize, "")
      author:SetPoint(CFG.Author.point, anchor, CFG.Author.relPoint, CFG.Author.x, CFG.Author.y)
    end

    local logo = canvas:CreateTexture(nil, "ARTWORK")
    do
      local anchor = anchorFrameByTag(CFG.Logo.anchorTo, {box=box, canvas=canvas})
      logo:SetSize(CFG.Logo.size, CFG.Logo.size)
      logo:SetPoint(CFG.Logo.point, anchor, CFG.Logo.relPoint, CFG.Logo.x, CFG.Logo.y)
      logo:SetTexture(CFG.Logo.file)
    end

    local inputs = CreateFrame("Frame", nil, canvas)
    do
      local env = {box=box, canvas=canvas, title=title, author=author, logo=logo}
      local leftA   = anchorFrameByTag(CFG.Inputs.anchorTo, env)
      local rightA  = anchorFrameByTag(CFG.Inputs.rightAnchorTo, env)

      inputs:SetPoint(CFG.Inputs.point, leftA, CFG.Inputs.relPoint, CFG.Inputs.x, CFG.Inputs.y)
      inputs:SetPoint("RIGHT", rightA, CFG.Inputs.rightPoint, CFG.Inputs.rightX, CFG.Inputs.rightY)
      inputs:SetHeight(CFG.Edit.height + 18)
    end

    local function LayoutColumns()
	  local w = math.max(0, inputs:GetWidth() or 0)
	  if w <= 0 then return end
	end

    inputs:SetScript("OnShow", LayoutColumns)
    inputs:SetScript("OnSizeChanged", LayoutColumns)
    C_Timer.After(0, LayoutColumns)

    local function FitRowHeight()
      if CFG.Row.mode == "fixed" then
        row:SetHeight(CFG.Row.fixedHeight)
        return
      end
      local top    = (title and title:GetTop()) or canvas:GetTop()
      local bInput = inputs:GetBottom()
      local bLogo  = logo:GetBottom()
      if not top or (not bInput and not bLogo) then return end
      local bottom = math.min(bInput or bLogo, bLogo or bInput)
      local needed = (top - bottom) + CFG.Row.bottomPad
      row:SetHeight(math.max(CFG.Row.minHeight, needed) - SHIFT_UP)
    end
    inputs:HookScript("OnSizeChanged", function() C_Timer.After(0, FitRowHeight) end)
    C_Timer.After(0, FitRowHeight)
  end)
end)

-- ====================================
-- \Options\Panel.lua
-- ====================================
-- This file creates and manages the main options panel UI for the addon.
-- Handles tab navigation, section registration, and overall layout of the
-- addon's settings interface. Integrates with WoW's Settings API (modern)
-- and legacy InterfaceOptionsFrame. Prevents opening during combat.

local addonName, ns = ...
ns.Options = ns.Options or {}
local O = ns.Options
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Layout constants
O.LABEL_LEFT_X             = O.LABEL_LEFT_X or 12
O.ROW_LEFT_PAD             = O.ROW_LEFT_PAD or 10
O.ROW_RIGHT_PAD            = O.ROW_RIGHT_PAD or 10
O.ROW_V_GAP                = O.ROW_V_GAP or 10
O.SECTION_GAP              = O.SECTION_GAP or 12
O.SECTION_CONTENT_TOP_PAD  = O.SECTION_CONTENT_TOP_PAD or 36
O.PAGE_CONTENT_TOP_PAD     = O.PAGE_CONTENT_TOP_PAD or 0

-- Font constants
O.PANEL_FONT_NAME          = O.PANEL_FONT_NAME or "FiraSans-Regular"
O.TITLE_FONT_NAME          = O.TITLE_FONT_NAME or "FiraSans-ExtraBoldItalic"
O.AUTHOR_LABEL_FONT_NAME   = O.AUTHOR_LABEL_FONT_NAME or "FiraSans-Medium"
O.LABEL_ITALIC_FONT_NAME   = O.LABEL_ITALIC_FONT_NAME or "FiraSans-Italic"

-- Size constants
O.SIZE_TITLE               = O.SIZE_TITLE or 50
O.SIZE_SECTION_HEAD        = O.SIZE_SECTION_HEAD or 20
O.SIZE_LABEL               = O.SIZE_LABEL or 14
O.SIZE_COPY_LABEL          = O.SIZE_COPY_LABEL or 10
O.SIZE_EDITBOX             = O.SIZE_EDITBOX or 14
O.SIZE_TAB_LABEL           = O.SIZE_TAB_LABEL or 15

O.RESET_W                  = O.RESET_W or 60
O.RESET_H                  = O.RESET_H or 30

-- Author info
O.AUTHOR_LABEL_TEXT        = O.AUTHOR_LABEL_TEXT or "By |cffff7d0FFurphy|r"
O.AUTHOR_LABEL_SIZE        = O.AUTHOR_LABEL_SIZE or 17
O.AUTHOR_LABEL_X           = O.AUTHOR_LABEL_X or 335
O.AUTHOR_LABEL_Y           = O.AUTHOR_LABEL_Y or -55

-- Tab constants
O.TAB_HEIGHT               = O.TAB_HEIGHT or 24
O.TAB_COUNT				         = O.TAB_COUNT or 6

-- Helper to get font path by name
local function GetFontPathByName(name)
  if LSM and LSM.Fetch and name then
    local p = LSM:Fetch("font", name, true)
    if p then return p end
  end
  local fallback = GameFontNormal and select(1, GameFontNormal:GetFont())
  return fallback or "Fonts\\FRIZQT__.TTF"
end
O.GetFontPathByName = GetFontPathByName

-- Resolves the main panel font
function O.ResolvePanelFont()
  return GetFontPathByName(O.PANEL_FONT_NAME) or "Fonts\\FRIZQT__.TTF"
end

-- Registry for option sections
O._sections = O._sections or {}
function O.RegisterSection(builder)
  if type(builder) == "function" then
    O._sections[#O._sections+1] = builder
  end
end

-- Create the main panel frame
local panel = CreateFrame("Frame", addonName.."OptionsPanel", UIParent)
panel.name = "Clickable Raid Buffs"

-- Register with WoW Settings API
local category, categoryID
ns.OpenOptions = function()
  if InCombatLockdown and InCombatLockdown() then
    UIErrorsFrame:AddMessage("Cannot open Clickable Raid Buffs options in combat.", 1, 0.2, 0.2, 1)
    return
  end
  if Settings and Settings.OpenToCategory then
    if not categoryID and Settings.RegisterCanvasLayoutCategory then
      category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
      Settings.RegisterAddOnCategory(category)
      categoryID = category and category.ID or nil
    end
    if categoryID then
      if ns.SyncOptions then ns.SyncOptions() end
      Settings.OpenToCategory(categoryID); return
    end
  end
  if InterfaceOptionsFrame_OpenToCategory then
    if ns.SyncOptions then ns.SyncOptions() end
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  end
end
O.OpenOptions = ns.OpenOptions

if Settings and Settings.RegisterCanvasLayoutCategory then
  category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
  Settings.RegisterAddOnCategory(category)
  categoryID = category and category.ID or nil
end

-- Hide panel in combat
local combatHider = CreateFrame("Frame")
combatHider:RegisterEvent("PLAYER_REGEN_DISABLED")
combatHider:SetScript("OnEvent", function()
  if panel:IsShown() then HideUIPanel(panel) end
end)

-- Tab styling configuration
local TAB_CFG = {
  h        = O.TAB_HEIGHT or 24,
  padX     = 10,
  gap      = 8,
  bg       = {0.10,0.11,0.15,1},
  border   = {0.22,0.24,0.30,1},
  bgSel    = {0.14,0.16,0.22,1},
  borderSel= {0.20,0.65,1.00,1},
  text     = {0.85,0.90,1.00,1},
  textSel  = {1.00,1.00,1.00,1},
}

-- Styles a tab button
local function StyleTab(btn, selected)
  if not btn.bg then
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
  end
  if selected then
    btn.bg:SetColorTexture(unpack(TAB_CFG.bgSel))
    btn:SetBackdropBorderColor(unpack(TAB_CFG.borderSel))
    btn.txt:SetTextColor(unpack(TAB_CFG.textSel))
  else
    btn.bg:SetColorTexture(unpack(TAB_CFG.bg))
    btn:SetBackdropBorderColor(unpack(TAB_CFG.border))
    btn.txt:SetTextColor(unpack(TAB_CFG.text))
  end
end

-- Applies custom tab ordering
local function ApplyTabOrder(collected)
  if type(O.TAB_ORDER) ~= "table" or #O.TAB_ORDER == 0 then
    for _, it in ipairs(collected) do it.tabLabel = it.title end
    return collected
  end
  local byMatch = {}
  for idx, spec in ipairs(O.TAB_ORDER) do
    if type(spec) == "table" and spec.match then
      byMatch[spec.match] = { idx = idx, text = spec.text }
    elseif type(spec) == "string" then
      byMatch[spec] = { idx = idx, text = spec }
    end
  end
  table.sort(collected, function(a, b)
    local aa = byMatch[a.title] and byMatch[a.title].idx or math.huge
    local bb = byMatch[b.title] and byMatch[b.title].idx or math.huge
    if aa ~= bb then return aa < bb end
    return a._order < b._order
  end)
  for _, it in ipairs(collected) do
    local spec = byMatch[it.title]
    it.tabLabel = (spec and spec.text and spec.text ~= "") and spec.text or it.title
  end
  return collected
end

-- Builds the options panel UI
local function Build()
  if panel._built then return end
  panel._built = true

  local card = CreateFrame("Frame", nil, panel, "BackdropTemplate")
  card:SetPoint("TOPLEFT", 8, -8)
  card:SetPoint("BOTTOMRIGHT", -8, 8)
  card:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left=1, right=1, top=1, bottom=1 },
  })
  card:SetBackdropColor(0.06,0.07,0.10,0.96)
  card:SetBackdropBorderColor(0.18,0.20,0.26,1)

  local body = CreateFrame("Frame", addonName.."OptionsBody", card)
  body:SetPoint("TOPLEFT", 10, -10)
  body:SetPoint("BOTTOMRIGHT", -10, 10)

  local titleBox
  do
    titleBox = CreateFrame("Frame", nil, body, "BackdropTemplate")
    titleBox:SetPoint("TOPLEFT", 0, 0)
    titleBox:SetPoint("RIGHT", 0, 0)
    titleBox:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    titleBox:SetBackdropColor(0.09,0.10,0.14,0.95)
    titleBox:SetBackdropBorderColor(0.20,0.22,0.28,1)

    local content = CreateFrame("Frame", nil, titleBox)
    local topPadTitle = O.SECTION_CONTENT_TOP_PAD
    content:SetPoint("TOPLEFT", O.ROW_LEFT_PAD, -topPadTitle)
    content:SetPoint("TOPRIGHT", -O.ROW_RIGHT_PAD, -topPadTitle)

    local contentY, last = 0, nil
    local function Row(h)
      local r = CreateFrame("Frame", nil, content)
      local hh = h or 36
      r:SetHeight(hh)
      r:SetPoint("LEFT"); r:SetPoint("RIGHT")
      if not last then r:SetPoint("TOP", content, "TOP", 0, 0)
      else r:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -O.ROW_V_GAP) end
      contentY = contentY + hh + (last and O.ROW_V_GAP or 0); last = r; return r
    end

    if #O._sections >= 1 then
      local titleBuilder = O._sections[1]
      titleBuilder(function(_, inner) inner(content, Row) end)
    end

    local height = O.SECTION_CONTENT_TOP_PAD + contentY + 12
    titleBox:SetHeight(height)
    content:SetHeight(contentY)
  end

  local tabsBar = CreateFrame("Frame", nil, body)
  tabsBar:SetPoint("TOPLEFT", 0, -titleBox:GetHeight()-O.SECTION_GAP)
  tabsBar:SetPoint("TOPRIGHT", 0, -titleBox:GetHeight()-O.SECTION_GAP)
  tabsBar:SetHeight(TAB_CFG.h)

  local pagesHolder = CreateFrame("Frame", nil, body, "BackdropTemplate")
  pagesHolder:SetPoint("TOPLEFT",  tabsBar, "BOTTOMLEFT",  0, 0)
  pagesHolder:SetPoint("TOPRIGHT", tabsBar, "BOTTOMRIGHT", 0, 0)
  pagesHolder:SetPoint("BOTTOMRIGHT", 0, 0)
  pagesHolder:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
  pagesHolder:SetBackdropColor(0.09,0.10,0.14,0.95)
  pagesHolder:SetBackdropBorderColor(0.20,0.22,0.28,1)

  local pages, tabs, current = {}, {}, 0

  local function ShowPage(i)
    if i == current or not pages[i] then return end
    for k=1,#pages do if pages[k] then pages[k]:Hide() end end
    for k=1,#tabs  do if tabs[k]  then StyleTab(tabs[k], k==i) end end
    pages[i]:Show()
    current = i
  end

	local function CreateTab(parent, text, index)
		local b = CreateFrame("Button", nil, parent, "BackdropTemplate")

		local total   = tabsBar:GetWidth() or 480
		local gaps    = TAB_CFG.gap * (O.TAB_COUNT - 1)
		local each    = (total - gaps) / O.TAB_COUNT
		local w       = math.max(80, math.floor(each + 0.5))

		b:SetSize(w, TAB_CFG.h)
		b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1})
		b:SetBackdropColor(0,0,0,0)
		b:SetBackdropBorderColor(unpack(TAB_CFG.border))

		b.bg = b:CreateTexture(nil, "BACKGROUND")
		b.bg:SetAllPoints()
		b.bg:SetColorTexture(unpack(TAB_CFG.bg))

		b.txt = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		b.txt:SetPoint("CENTER")
		b.txt:SetText(text or "")
		if O and O.ResolvePanelFont then
		  b.txt:SetFont(O.ResolvePanelFont(), O.SIZE_TAB_LABEL or 12, "")
		end

		b:SetScript("OnClick", function() ShowPage(index) end)
		StyleTab(b, false)
		return b
	end

	local function AddPage(sectionTitle, buildFunc)
		local page = CreateFrame("Frame", nil, pagesHolder)
		page:SetPoint("TOPLEFT", 0, 0); page:SetPoint("TOPRIGHT", 0, 0); page:SetPoint("BOTTOMRIGHT", 0, 0)

		local content = CreateFrame("Frame", nil, page)
		local topPadPage = O.PAGE_CONTENT_TOP_PAD or O.SECTION_CONTENT_TOP_PAD
		content:SetPoint("TOPLEFT",  O.ROW_LEFT_PAD, -topPadPage)
		content:SetPoint("TOPRIGHT", -O.ROW_RIGHT_PAD, -topPadPage)
		content:SetPoint("BOTTOM", 0, 12)

		local last, contentY = nil, 0
		local function Row(h)
		  local r = CreateFrame("Frame", nil, content)
		  local hh = h or 36
		  r:SetHeight(hh); r:SetPoint("LEFT"); r:SetPoint("RIGHT")
		  if not last then r:SetPoint("TOP", content, "TOP", 0, 0)
		  else r:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -O.ROW_V_GAP) end
		  contentY = contentY + hh + (last and O.ROW_V_GAP or 0); last = r; return r
		end

		buildFunc(content, Row)

		local id = #pages+1
		pages[id] = page

		local tab = CreateTab(tabsBar, sectionTitle or ("Tab "..id), id)
		if id == 1 then
		  tab:SetPoint("LEFT", tabsBar, "LEFT", 0, 0)
		else
		  tab:SetPoint("LEFT", tabs[id-1], "RIGHT", TAB_CFG.gap, 0)
		end

		if id == O.TAB_COUNT then
		  local total = tabsBar:GetWidth() or 480
		  local w     = tab:GetWidth()
		  local used  = (w + TAB_CFG.gap) * (O.TAB_COUNT - 1)
		  local lastW = math.max(80, total - used)
		  tab:SetWidth(lastW)
		end

		tabs[id] = tab
		page:Hide()
	end

  local collected = {}
  for i = 2, #O._sections do
    local builder = O._sections[i]
    if type(builder) == "function" then
      builder(function(sectionTitle, innerBuilder)
        if sectionTitle and sectionTitle:lower():find("healthstone") then return end
        table.insert(collected, {
          title  = sectionTitle or ("Tab "..(#collected+1)),
          build  = innerBuilder,
          _order = #collected + 1,
        })
      end)
    end
  end
  ApplyTabOrder(collected)
  for _, info in ipairs(collected) do
    AddPage(info.title, info.build)
  end

  if #pages > 0 then
    ShowPage(1)
  end
end

panel:SetScript("OnShow", Build)

-- ====================================
-- \Options\Tabs\Info_Tab.lua
-- ====================================
-- This file creates the "Info" tab in the options panel, displaying addon information,
-- version, and basic controls like unlocking the frame or hiding the minimap button.

local addonName, ns = ...
ns.Options = ns.Options or {}
local O = ns.Options

-- Reads the addon version from the TOC file.
local function _readVersion()
  local v = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version"))
          or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))
  return (v and v ~= "") and v or "dev"
end

ns.VERSION = _readVersion()

local ORDER_BOX_BG  = {0.08, 0.09, 0.12, 1.00}
local TILE_BG       = {0.10, 0.115, 0.16, 1.00}
local BORDER_COL    = {0.20, 0.22, 0.28, 1.00}

local THEME = {
  fontPath    = function() if O and O.ResolvePanelFont then return O.ResolvePanelFont() end return "Fonts\\FRIZQT__.TTF" end,
  sizeLabel   = function() return (O and O.SIZE_LABEL) or 14 end,
  cardBG      = {0.09,0.10,0.14,0.95},
  cardBR      = BORDER_COL,
  wellBG      = ORDER_BOX_BG,
  wellBR      = BORDER_COL,
  rowBG       = TILE_BG,
  rowBR       = BORDER_COL,
}

-- Helper to paint a frame with a backdrop.
local function PaintBackdrop(frame, bg, br)
  frame:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
  frame:SetBackdropColor(unpack(bg))
  frame:SetBackdropBorderColor(unpack(br))
end

-- Checks if the minimap button is currently hidden.
local function GetMinimapHidden()
  local addon = LibStub("AceAddon-3.0"):GetAddon("ClickableRaidBuffs", true)
  if addon and addon.minimapDB and addon.minimapDB.profile and addon.minimapDB.profile.minimap then
    return addon.minimapDB.profile.minimap.hide and true or false
  end
  return false
end

-- Registers the Info section.
O.RegisterSection(function(AddSection)
  AddSection("Info", function(content, Row)
    local row = Row(385)

    local card = CreateFrame("Frame", nil, row, "BackdropTemplate")
    PaintBackdrop(card, THEME.cardBG, THEME.cardBR)
    card:SetPoint("TOPLEFT", 0, -8)
    card:SetPoint("BOTTOMRIGHT", 0, 0)

    local inner = CreateFrame("Frame", nil, card, "BackdropTemplate")
    inner:SetPoint("TOPLEFT", 6, -12)
    inner:SetPoint("BOTTOMRIGHT", -6, 6)
    PaintBackdrop(inner, THEME.wellBG, THEME.wellBR)

    local TOP_PAD, SIDE_PAD, BAR_WIDTH, RIGHT_GAP = 8, 10, 16, 8

    local scroll = CreateFrame("ScrollFrame", nil, inner, "BackdropTemplate")
    scroll:SetPoint("TOPLEFT",     inner, "TOPLEFT",  SIDE_PAD, -TOP_PAD)
    scroll:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -(SIDE_PAD + BAR_WIDTH + RIGHT_GAP), SIDE_PAD)

    local contentFrame = CreateFrame("Frame", nil, scroll)
    contentFrame:SetSize(1, 1)
    scroll:SetScrollChild(contentFrame)

    local icon = contentFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAtlas("Mobile-LegendaryQuestIcon", true)
    icon:SetSize(95, 95)
    icon:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -40)

    local title = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    title:SetFont(THEME.fontPath(), THEME.sizeLabel() + 4, "")
    title:SetJustifyH("LEFT")
    title:SetText(
      "NOTE:  This addon is mostly disabled in cities\n" ..
      "            and rested areas.  If icons are missing,\n" ..
      "            check whether you're in one of those areas.\n" ..
      "            Consumables only load inside instances."
    )

    local body = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    body:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -20)
    body:SetWidth(550)
    body:SetFont("Interface\\AddOns\\ClickableRaidBuffs\\Media\\Fonts\\Fira_Sans\\FiraSans-Medium.ttf", 50, "")
    body:SetJustifyH("CENTER")
    body:SetText("|cff00ccff/crb     /buff|r")

    local body2 = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    body2:SetPoint("TOP", body, "BOTTOM", 0, -20)
    body2:SetWidth(550)
    body2:SetFont("Interface\\AddOns\\ClickableRaidBuffs\\Media\\Fonts\\Fira_Sans\\FiraSans-Medium.ttf", 16, "")
    body2:SetJustifyH("LEFT")
    body2:SetText(
      "Commands:\n" ..
      "      |cFF00ccff/crb /buff|r |cffff7d0Funlock|r  -  Toggle icon lock\n" ..
      "      |cFF00ccff/crb /buff|r |cffff7d0Flock|r  -  Toggle icon lock\n" ..
      "      |cFF00ccff/crb /buff|r |cffff7d0Fminimap|r  -  Toggle minimap icon\n" ..
      "      |cFF00ccff/crb /buff|r |cffff7d0Freset|r  -  Reset all settings to default and reload UI"
    )

    local unlockCB = CreateFrame("CheckButton", nil, inner, "BackdropTemplate")
    unlockCB:SetSize(20, 20)
    unlockCB:SetPoint("BOTTOMLEFT", inner, "BOTTOMLEFT", 5, 5)
    PaintBackdrop(unlockCB, {0.05,0.06,0.08,1}, {0.22,0.24,0.30,1})

    local tick = unlockCB:CreateTexture(nil, "ARTWORK")
    tick:SetAtlas("common-icon-checkmark", true)
    tick:SetPoint("CENTER")
    tick:SetSize(16, 16)
    tick:Hide()
    unlockCB._tick = tick

    local lab = inner:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lab:SetPoint("LEFT", unlockCB, "RIGHT", 8, 0)
    lab:SetText("Unlock")
    lab:SetFont(THEME.fontPath(), THEME.sizeLabel(), "")

    unlockCB:SetScript("OnClick", function(self)
      local state = self:GetChecked()
      if self._tick then self._tick:SetShown(state) end
      if ns.ToggleMover then ns.ToggleMover(state) end
    end)

    ns.InfoTab_UpdateUnlockCheckbox = function(state)
      unlockCB:SetChecked(state and true or false)
      if unlockCB._tick then unlockCB._tick:SetShown(state and true or false) end
    end

    local hideCB = CreateFrame("CheckButton", nil, inner, "BackdropTemplate")
    hideCB:SetSize(20, 20)
    hideCB:SetPoint("LEFT", lab, "RIGHT", 16, 0)
    PaintBackdrop(hideCB, {0.05,0.06,0.08,1}, {0.22,0.24,0.30,1})

    local ver = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    ver:SetPoint("TOPLEFT", inner, "TOPLEFT", -45, -12)
    ver:SetWidth(200)
    ver:SetFont("Interface\\AddOns\\ClickableRaidBuffs\\Media\\Fonts\\Fira_Sans\\FiraSans-ExtraBold.ttf", 22, "")
    ver:SetJustifyH("RIGHT")
    ver:SetText("Version:  |cFF00ccff" .. ns.VERSION .."|r")

    local hideTick = hideCB:CreateTexture(nil, "ARTWORK")
    hideTick:SetAtlas("common-icon-checkmark", true)
    hideTick:SetPoint("CENTER")
    hideTick:SetSize(16, 16)
    hideTick:Hide()
    hideCB._tick = hideTick

    local hideLab = inner:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    hideLab:SetPoint("LEFT", hideCB, "RIGHT", 8, 0)
    hideLab:SetText("Hide Minimap Button")
    hideLab:SetFont(THEME.fontPath(), THEME.sizeLabel(), "")

    hideCB:SetScript("OnClick", function(self)
      local state = self:GetChecked()
      if self._tick then self._tick:SetShown(state) end
      local addon = LibStub("AceAddon-3.0"):GetAddon("ClickableRaidBuffs", true)
      if addon and addon.ToggleMinimapButton then
        addon:ToggleMinimapButton(state)
      end
      ns.InfoTab_UpdateMinimapCheckbox(state)
    end)

    ns.InfoTab_UpdateMinimapCheckbox = function(state)
      if state == nil then
        state = GetMinimapHidden()
      end
      hideCB:SetChecked(state and true or false)
      if hideCB._tick then hideCB._tick:SetShown(state and true or false) end
    end

    C_Timer.After(0, function()
      ns.InfoTab_UpdateMinimapCheckbox(GetMinimapHidden())
    end)
  end)
end)

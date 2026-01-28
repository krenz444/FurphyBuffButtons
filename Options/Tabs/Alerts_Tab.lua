-- ====================================
-- \Options\Tabs\Alerts_Tab.lua
-- ====================================
-- This file creates the "Alerts" tab in the options panel, allowing users to configure
-- raid alerts (announcements, sounds, visuals).

local addonName, ns = ...
ns.Options        = ns.Options or {}
ns.NumberSelect   = ns.NumberSelect or {}
ns.OptionElements = ns.OptionElements or {}
ns.ScrollBar      = ns.ScrollBar or {}

local O   = ns.Options
local NS  = ns.NumberSelect
local OE  = ns.OptionElements
local SB  = ns.ScrollBar

-- Layout constants
local K = {
  LEFT_W = 305,
  RIGHT_W = 305,
  COL_GAP = 0,
  ROW1_H = 65,
  ROW2_H = 62,
  ROW3_H = 82,
  MOTION_ROW_H = 150,
  MOTION_SPEED_Y = 60,
  MOTION_HEIGHT_Y = 60,
  MOTION_DURATION_Y = -18,
  TEXTS_TOP_GAP_AFTER_DURATION = 22,
  TEXTS_ROW_STEP = 28,
  TEXTS_EB_H = 36,
  TEXTS_LABEL_W = 200,
  TEXTS_EB_W = 0,
  TEXTS_SIDE_PAD = 8,
  TEXTS_GAP = 12,
  TEXTS_BOTTOM_PAD = 16,
  TEXTS_OUTER_PAD_LEFT = 10,
  TEXTS_OUTER_PAD_RIGHT = 10,
  ROW4_H = 156,
  ROW5_H = 30,
  LEFT_X = 0,
  TOPSTEP = 0,
  GAP_AFTER_ENABLE = -17,
  MASK_SIDE_PAD = -5,
  MASK_TOP_PAD = 20,
  MASK_BOTTOM_PAD = -6,
}

local function DB()  return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {} end
-- Retrieves raid announcer settings.
local function RAID()
  local d = DB()
  d.raidAnnouncer = d.raidAnnouncer or {}
  local r = d.raidAnnouncer
  r.enabled = (r.enabled ~= false)
  r.customText = r.customText or {}
  r.anchor = r.anchor or { x=0, y=180 }
  r.soundName = r.soundName or "Alerts: Ding Dong"
  r.fontName = r.fontName or (O.GetDefault and O.GetDefault("fontName")) or "Friz Quadrata TT"
  r.fontSize = (r.fontSize and r.fontSize > 0) and r.fontSize or 60
  r.fontColor = r.fontColor or { r=1,g=1,b=1 }
  r.disableInCombat = (r.disableInCombat == true) and true or false
  r.period = tonumber(r.period) or 0.75
  r.amplitude = tonumber(r.amplitude) or 50
  r.duration = tonumber(r.duration) or 4
  return r
end

local function LSM() local ok, lib = pcall(LibStub, "LibSharedMedia-3.0"); if ok then return lib end end
local function PanelFontPath()
  if O and O.ResolvePanelFont then return O.ResolvePanelFont() end
  local f = GameFontHighlight and select(1, GameFontHighlight:GetFont())
  return f or "Fonts\\FRIZQT__.TTF"
end
local function FS(fs, size, flags) if fs and fs.SetFont then fs:SetFont(PanelFontPath(), size or (O.SIZE_LABEL or 14), flags or "") end end

local POP_KEY = "CRB_RA_TAB_RESET"
if not StaticPopupDialogs[POP_KEY] then
  StaticPopupDialogs[POP_KEY] = {
    text = "%s",
    button1 = YES, button2 = NO,
    OnAccept = function(self, data) if data and data.run then data.run() end end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
end
local function ConfirmReset(msg, fn) StaticPopup_Show(POP_KEY, msg or "Reset setting?", nil, { run = fn }) end

local function PaintBackdrop(frame, bg, br)
  frame:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
  frame:SetBackdropColor((bg and bg[1]) or 0.05,(bg and bg[2]) or 0.06,(bg and bg[3]) or 0.08,(bg and bg[4]) or 1)
  frame:SetBackdropBorderColor((br and br[1]) or 0.22,(br and br[2]) or 0.24,(br and br[3]) or 0.30,(br and br[4]) or 1)
end

-- Builds a dropdown menu.
local function BuildDropdown(parent)
  local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
  PaintBackdrop(btn); btn:SetHeight(26)
  local text = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("LEFT", 8, 0); text:SetJustifyH("LEFT"); FS(text, 14)
  local caret = btn:CreateTexture(nil, "ARTWORK")
  caret:SetPoint("RIGHT", -8, 0); caret:SetAtlas("minimal-scrollbar-arrow-bottom-down", true)
  local blocker = CreateFrame("Frame", nil, UIParent); blocker:Hide()
  blocker:SetFrameStrata("DIALOG"); blocker:SetAllPoints(UIParent); blocker:EnableMouse(true)
  local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  PaintBackdrop(menu, {0.09,0.10,0.14,0.95}, {0.20,0.22,0.28,1})
  menu:SetFrameStrata("DIALOG"); menu:SetClampedToScreen(true); menu:Hide()
  local scroll = CreateFrame("ScrollFrame", nil, menu, "BackdropTemplate")
  scroll:SetPoint("TOPLEFT", 4, -4); scroll:SetPoint("BOTTOMRIGHT", -(4+18), 4)
  local content = CreateFrame("Frame", nil, scroll); scroll:SetScrollChild(content)
  local bar
  if ns.ScrollBar and ns.ScrollBar.Create then
    bar = ns.ScrollBar.Create(menu, { width=16, sliderWidth=14, minThumbH=22 })
    bar:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, -4)
    bar:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -4, 4)
    bar:BindToScroll(scroll, content)
  end
  return btn, text, caret, menu, blocker, scroll, content, bar
end

local function RowFrames(content, topY, height)
  local row = CreateFrame("Frame", nil, content)
  row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, topY)
  row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, topY)
  row:SetHeight(height)
  local left  = CreateFrame("Frame", nil, row)
  local right = CreateFrame("Frame", nil, row)
  left:SetPoint("TOPLEFT", 0, 0)
  left:SetSize(K.LEFT_W, height)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", K.COL_GAP, 0)
  right:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
  right:SetHeight(height)
  return row, left, right
end

local function InstallHoverRevealMulti(resetBtn, watched)
  local function anyOver()
    if resetBtn:IsMouseOver() then return true end
    for i = 1, #watched do
      local w = watched[i]
      if w and w.IsMouseOver and w:IsMouseOver() then return true end
    end
    return false
  end
  local function show() resetBtn:Show() end
  local function tryHide() C_Timer.After(0.05, function() if not anyOver() then resetBtn:Hide() end end) end
  for i = 1, #watched do
    local f = watched[i]
    if f and f.HookScript then
      f:HookScript("OnEnter", show)
      f:HookScript("OnLeave", tryHide)
    end
  end
  resetBtn:HookScript("OnEnter", show)
  resetBtn:HookScript("OnLeave", tryHide)
end

-- Builds the "Enable" checkbox row.
local function BuildEnableRow(content, startY, onToggle)
  local row = CreateFrame("Frame", nil, content)
  row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, startY)
  row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, startY)
  row:SetHeight(K.ROW1_H)
  local left = CreateFrame("Frame", nil, row)
  left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(220)
  local cb = CreateFrame("CheckButton", nil, left, "BackdropTemplate")
  cb:SetSize(20,20); PaintBackdrop(cb)
  local tick = cb:CreateTexture(nil,"ARTWORK"); tick:SetAtlas("common-icon-checkmark", true); tick:SetPoint("CENTER"); tick:SetSize(16,16); tick:Hide()
  cb._tick = tick
  cb:SetPoint("LEFT", 0, 0)
  cb:SetChecked(RAID().enabled); cb._tick:SetShown(RAID().enabled)
  cb:SetScript("OnClick", function(self)
    local on = self:GetChecked() and true or false
    if self._tick then self._tick:SetShown(on) end
    if onToggle then onToggle(on) end
  end)
  local lab = left:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  lab:SetPoint("LEFT", cb, "RIGHT", 8, 0); lab:SetText("Enable"); FS(lab, 14)
  local right = CreateFrame("Frame", nil, row)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
  right:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)
  right:SetPoint("RIGHT", row, "RIGHT", -24, 0)
  local unlockCB = CreateFrame("CheckButton", nil, right, "BackdropTemplate")
  unlockCB:SetSize(20,20); PaintBackdrop(unlockCB)
  local utick = unlockCB:CreateTexture(nil,"ARTWORK"); utick:SetAtlas("common-icon-checkmark", true); utick:SetPoint("CENTER"); utick:SetSize(16,16); utick:Hide()
  unlockCB._tick = utick
  local unlockLab = right:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  FS(unlockLab, 14); unlockLab:SetText("Unlock")
  local combatCB = CreateFrame("CheckButton", nil, right, "BackdropTemplate")
  combatCB:SetSize(20,20); PaintBackdrop(combatCB)
  local ctick = combatCB:CreateTexture(nil,"ARTWORK"); ctick:SetAtlas("common-icon-checkmark", true); ctick:SetPoint("CENTER"); ctick:SetSize(16,16); ctick:Hide()
  combatCB._tick = ctick
  local combatLab = right:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  FS(combatLab, 14); combatLab:SetText("Disable in Combat")
  combatLab:ClearAllPoints()
  combatLab:SetPoint("RIGHT", right, "RIGHT", 0, 0)
  combatCB:ClearAllPoints()
  combatCB:SetPoint("RIGHT", combatLab, "LEFT", -8, 0)
  unlockLab:ClearAllPoints()
  unlockLab:SetPoint("RIGHT", combatCB, "LEFT", -16, 0)
  unlockCB:ClearAllPoints()
  unlockCB:SetPoint("RIGHT", unlockLab, "LEFT", -8, 0)
  unlockCB:SetScript("OnClick", function(self)
    local on = self:GetChecked() and true or false
    if self._tick then self._tick:SetShown(on) end
    if ns.RaidAnnouncer_ToggleMover then ns.RaidAnnouncer_ToggleMover(on) end
  end)
  ns.RaidAnnouncer_UpdateUnlockCheckbox = function(state) unlockCB:SetChecked(state and true or false); if unlockCB._tick then unlockCB._tick:SetShown(state and true or false) end end
  local initOn = (RAID().disableInCombat == true)
  combatCB:SetChecked(initOn); if combatCB._tick then combatCB._tick:SetShown(initOn) end
  combatCB:SetScript("OnClick", function(self)
    local on = self:GetChecked() and true or false
    RAID().disableInCombat = on
    if self._tick then self._tick:SetShown(on) end
  end)
  return row, cb
end

-- Builds the sound and font selection row.
local function BuildSoundFontRow(content, startY, rightPad)
  local row, L, R = RowFrames(content, startY, K.ROW2_H)
  row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -rightPad, startY)
  local sBtn, sTxt, sCaret, sMenu, sBlock, sScroll, sContent, sBar = BuildDropdown(L)
  sBtn:SetPoint("CENTER")
  sBtn:SetWidth(260)
  L:HookScript("OnSizeChanged", function() sBtn:SetWidth(math.max(220, math.min(300, L:GetWidth() - 44))) end)
  local lib = LSM(); local sounds = {}
  if lib then local list = lib:List("sound"); for i=1,#list do sounds[#sounds+1]=list[i] end end
  table.sort(sounds)
  local function ApplySound(name) RAID().soundName = name; sTxt:SetText(name) end
  sTxt:SetText(RAID().soundName)
  local function RebuildSound()
    local total, lineH, visMax = #sounds, 22, 10
    local w  = sBtn:GetWidth()
    local h  = math.min(visMax, total) * lineH + 8
    sMenu:SetSize(w, h); sContent:SetSize(w - 22, total * lineH)
    for i=1,total do
      local b = sContent["b"..i]
      if not b then
        b = CreateFrame("Button", nil, sContent, "BackdropTemplate"); sContent["b"..i]=b
        PaintBackdrop(b); b:SetHeight(lineH)
        b._t=b:CreateFontString(nil,"ARTWORK","GameFontHighlight"); b._t:SetPoint("LEFT",6,0); FS(b._t,13)
        b:SetScript("OnClick", function(self) ApplySound(self._name); sMenu:Hide(); sBlock:Hide(); sCaret:SetAtlas("minimal-scrollbar-arrow-bottom-down", true) end)
      end
      b._name = sounds[i]; b._t:SetText(sounds[i])
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", 4, -((i-1)*lineH)); b:SetPoint("TOPRIGHT", -4, -((i-1)*lineH)); b:Show()
    end
    for i=total+1,200 do local b=sContent["b"..i]; if b then b:Hide() end end
    if sBar and sBar.UpdateThumb then sBar:UpdateThumb(sScroll:GetHeight(), sContent:GetHeight()) end
  end
  sBtn:SetScript("OnClick", function()
    if sMenu:IsShown() then sMenu:Hide(); sBlock:Hide(); sCaret:SetAtlas("minimal-scrollbar-arrow-bottom-down", true)
    else RebuildSound(); sMenu:ClearAllPoints(); sMenu:SetPoint("TOPLEFT", sBtn, "BOTTOMLEFT", 0, -2); sBlock:Show(); sMenu:Show(); sCaret:SetAtlas("minimal-scrollbar-arrow-top-down", true)
         sBlock:SetScript("OnMouseDown", function() sMenu:Hide(); sBlock:Hide(); sCaret:SetAtlas("minimal-scrollbar-arrow-bottom-down", true) end)
    end
  end)
  local lineL = CreateFrame("Frame", nil, L)
  lineL:SetPoint("TOP", sBtn, "BOTTOM", 0, -8)
  lineL:SetSize(260, 18)
  lineL:EnableMouse(true)
  L:HookScript("OnSizeChanged", function() lineL:SetWidth(sBtn:GetWidth()) end)
  local sLab = lineL:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); FS(sLab, O.SIZE_LABEL or 14)
  sLab:SetPoint("CENTER"); sLab:SetText("Sound"); sLab:SetTextColor(1,1,1)
  local preview = CreateFrame("Button", nil, lineL)
  preview:SetSize(22,22)
  preview:SetPoint("RIGHT", lineL, "RIGHT", 0, 0)
  local pv = preview:CreateTexture(nil, "ARTWORK"); pv:SetAllPoints(preview); pv:SetAtlas("chatframe-button-icon-voicechat", true)
  preview:SetScript("OnClick", function() if ns.RaidAnnouncer_PlayPreview then ns.RaidAnnouncer_PlayPreview() end end)
  local sReset = OE.NewResetButton(lineL)
  sReset:ClearAllPoints(); sReset:SetPoint("LEFT", sLab, "RIGHT", 6, 0)
  sReset:SetScript("OnClick", function()
    ConfirmReset("Reset sound to default?", function() ApplySound("Alerts: Ding Dong") end)
  end)
  InstallHoverRevealMulti(sReset, { lineL, sBtn })
  local fBtn, fTxt, fCaret, fMenu, fBlock, fScroll, fContent, fBar = BuildDropdown(R)
  fBtn:SetPoint("CENTER")
  fBtn:SetWidth(260)
  R:HookScript("OnSizeChanged", function() fBtn:SetWidth(math.max(220, math.min(300, R:GetWidth() - 24))) end)
  local libF = LSM(); local fontNames = {}
  if libF then local list = libF:List("font"); for i=1,#list do fontNames[#fontNames+1]=list[i] end end
  table.sort(fontNames)
  local function SetBtnFace(name) local face=(libF and libF:Fetch("font",name,true)) or PanelFontPath(); fTxt:SetFont(face, O.SIZE_LABEL or 14, "") end
  fTxt:SetText(RAID().fontName); SetBtnFace(RAID().fontName)
  local function ApplyFont(name)
    RAID().fontName = name; fTxt:SetText(name); SetBtnFace(name)
    if ns.RaidAnnouncer_ApplyFont then ns.RaidAnnouncer_ApplyFont() end
  end
  local function RebuildFont()
    local total, lineH, visMax = #fontNames, 22, 10
    local w  = fBtn:GetWidth()
    local h  = math.min(visMax, total) * lineH + 8
    fMenu:SetSize(w, h); fContent:SetSize(w - 22, total * lineH)
    for i=1,total do
      local b = fContent["b"..i]
      if not b then
        b = CreateFrame("Button", nil, fContent, "BackdropTemplate"); fContent["b"..i]=b
        PaintBackdrop(b); b:SetHeight(lineH)
        b._t=b:CreateFontString(nil,"ARTWORK","GameFontHighlight"); b._t:SetPoint("LEFT",6,0)
        b:SetScript("OnClick", function(self) ApplyFont(self._name); fMenu:Hide(); fBlock:Hide(); fCaret:SetAtlas("minimal-scrollbar-arrow-bottom-down", true) end)
      end
      local face = libF and libF:Fetch("font", fontNames[i]) or PanelFontPath()
      b._t:SetFont(face, O.SIZE_LABEL or 14, "")
      b._name = fontNames[i]; b._t:SetText(fontNames[i])
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", 4, -((i-1)*lineH)); b:SetPoint("TOPRIGHT", -4, -((i-1)*lineH)); b:Show()
    end
    for i=total+1,200 do local b=fContent["b"..i]; if b then b:Hide() end end
    if fBar and fBar.UpdateThumb then fBar:UpdateThumb(fScroll:GetHeight(), fContent:GetHeight()) end
  end
  fBtn:SetScript("OnClick", function()
    if fMenu:IsShown() then fMenu:Hide(); fBlock:Hide(); fCaret:SetAtlas("minimal-scrollbar-arrow-bottom-down", true)
    else RebuildFont(); fMenu:ClearAllPoints(); fMenu:SetPoint("TOPLEFT", fBtn, "BOTTOMLEFT", 0, -2); fBlock:Show(); fMenu:Show(); fCaret:SetAtlas("minimal-scrollbar-arrow-top-down", true)
         fBlock:SetScript("OnMouseDown", function() fMenu:Hide(); fBlock:Hide(); fCaret:SetAtlas("minimal-scrollbar-arrow-bottom-down", true) end)
    end
  end)
  local lineR = CreateFrame("Frame", nil, R)
  lineR:SetPoint("TOP", fBtn, "BOTTOM", 0, -8)
  lineR:SetSize(260, 18)
  lineR:EnableMouse(true)
  R:HookScript("OnSizeChanged", function() lineR:SetWidth(fBtn:GetWidth()) end)
  local fLab = lineR:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); FS(fLab, O.SIZE_LABEL or 14)
  fLab:SetPoint("CENTER"); fLab:SetText("Font"); fLab:SetTextColor(1,1,1)
  local fReset = OE.NewResetButton(lineR)
  fReset:ClearAllPoints(); fReset:SetPoint("LEFT", fLab, "RIGHT", 6, 0)
  fReset:SetScript("OnClick", function()
    local def = (O.GetDefault and O.GetDefault("fontName")) or RAID().fontName
    ConfirmReset("Reset font to default?", function() ApplyFont(def) end)
  end)
  InstallHoverRevealMulti(fReset, { lineR, fBtn })
  return row
end

-- Builds the font size and color row.
local function BuildSizeColorRow(content, startY, rightPad)
  local row, L, R = RowFrames(content, startY, K.ROW3_H)
  row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -rightPad, startY)

  local num = NS.Create(L, {
    min=16, max=128, step=1, value=RAID().fontSize or 60, default=60, label="Font Size",
    onChange=function(v)
      v = tonumber(v) or 60
      RAID().fontSize = v
      if ns.RaidAnnouncer_ApplyFont then ns.RaidAnnouncer_ApplyFont() end
    end,
  })
  num:ClearAllPoints()
  num:SetPoint("CENTER")

  local d = DB()
  d.raidAnnouncerTextColor = d.raidAnnouncerTextColor or {
    r = RAID().fontColor.r, g = RAID().fontColor.g, b = RAID().fontColor.b, a = 1
  }

  local colorHolder = CreateFrame("Frame", nil, R)
  colorHolder:SetSize(220, 72)
  colorHolder:SetPoint("CENTER")

  OE.SingleColumn(colorHolder, function(UI)
    UI:TextColor({
      label    = "Text Color",
      colorKey = "raidAnnouncerTextColor",
      which    = "raidAnnouncer",
      onChange = function()
        local c = DB().raidAnnouncerTextColor or { r=1, g=1, b=1, a=1 }
        RAID().fontColor.r, RAID().fontColor.g, RAID().fontColor.b = c.r, c.g, c.b
        if ns.RaidAnnouncer_ApplyFont then ns.RaidAnnouncer_ApplyFont() end
      end,
    })
  end)

  return row
end


-- Builds the motion settings row.
local function BuildMotionRow(content, startY, rightPad)
  local row, L, R = RowFrames(content, startY, K.MOTION_ROW_H)
  row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -rightPad, startY)

  local MIN_P, MAX_P = 0.30, 2.00

  local function periodToPercent(p)
    local clamped = math.max(MIN_P, math.min(MAX_P, tonumber(p) or 0.75))
    local t = (MAX_P - clamped) / (MAX_P - MIN_P)
    return math.floor(1 + t * 99 + 0.5)
  end

  local function percentToPeriod(s)
    local v = math.max(1, math.min(100, tonumber(s) or 75))
    local t = (v - 1) / 99
    return MAX_P - t * (MAX_P - MIN_P)
  end

  local speedSel = NS.Create(L, {
    label = "Bounce Speed",
    min = 1, max = 100, step = 1,
    value = periodToPercent(RAID().period),
    default = 70,
    onChange = function(v)
      RAID().period = percentToPeriod(v)
      if ns.RaidAnnouncer_ApplyMotion then ns.RaidAnnouncer_ApplyMotion() end
    end,
  })
  speedSel:SetPoint("CENTER", L, "CENTER", 0, K.MOTION_SPEED_Y)

  local heightSel = NS.Create(R, {
    label = "Bounce Height",
    min = 0, max = 75, step = 5,
    value = RAID().amplitude or 50, default = 50,
    onChange = function(v)
      RAID().amplitude = tonumber(v) or 50
      if ns.RaidAnnouncer_ApplyMotion then ns.RaidAnnouncer_ApplyMotion() end
    end,
  })
  heightSel:SetPoint("CENTER", R, "CENTER", 0, K.MOTION_HEIGHT_Y)

  local durationSel = NS.Create(row, {
    label = "Alert Duration (Seconds)",
    min = 1, max = 8, step = 0.5,
    value = RAID().duration or 4, default = 4,
    onChange = function(v)
      RAID().duration = tonumber(v) or 4
      if ns.RaidAnnouncer_ApplyMotion then ns.RaidAnnouncer_ApplyMotion() end
    end,
  })
  durationSel:SetPoint("CENTER", row, "CENTER", 0, K.MOTION_DURATION_Y)

  return row, K.MOTION_ROW_H, durationSel
end


local function AnnouncerKeys()
  local src = ClickableRaidData and ClickableRaidData["ANNOUNCER"]
  local keys, i = {}, 1
  if src then
    for k in pairs(src) do
      if k ~= "PORTAL" and k ~= "PORTALS" then
        keys[i] = k
        i = i + 1
      end
    end
  end
  table.sort(keys)
  return keys
end

local function DefaultTextFor(key)
  local src = ClickableRaidData and ClickableRaidData["ANNOUNCER"]
  return (src and src[key] and src[key].text) or key
end

local function LabelFor(key)
  local src = ClickableRaidData and ClickableRaidData["ANNOUNCER"]
  return (src and src[key] and src[key].label) or key
end

-- Builds the custom text settings row.
local function BuildTextsRow(parentForWidth, startY, rightPad, anchorUnder)
  local keys = AnnouncerKeys()
  local ROW_STEP   = K.TEXTS_ROW_STEP
  local EB_H       = K.TEXTS_EB_H
  local TITLE_TOP  = 36
  local BOTTOM_PAD = K.TEXTS_BOTTOM_PAD
  local totalH     = TITLE_TOP + (#keys * ROW_STEP) + BOTTOM_PAD
  K.ROW4_H = math.max(156, totalH)
  local row = CreateFrame("Frame", nil, parentForWidth)
  if anchorUnder then
    row:SetPoint("TOP", anchorUnder, "BOTTOM", 0, -K.TEXTS_TOP_GAP_AFTER_DURATION)
    row:SetPoint("LEFT", parentForWidth, "LEFT", K.TEXTS_OUTER_PAD_LEFT, 0)
    row:SetPoint("RIGHT", parentForWidth, "RIGHT", -(rightPad + K.TEXTS_OUTER_PAD_RIGHT), 0)
  else
    row:SetPoint("TOPLEFT", parentForWidth, "TOPLEFT", K.TEXTS_OUTER_PAD_LEFT, startY)
    row:SetPoint("RIGHT", parentForWidth, "RIGHT", -(rightPad + K.TEXTS_OUTER_PAD_RIGHT), 0)
  end
  row:SetHeight(K.ROW4_H)
  local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
  box:SetPoint("TOPLEFT", 0, 0); box:SetPoint("BOTTOMRIGHT", 0, 0)
  box:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
  box:SetBackdropColor(0.08,0.09,0.12,1); box:SetBackdropBorderColor(0.20,0.22,0.28,1)
  local title = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); FS(title, O.SIZE_LABEL or 14)
  title:SetPoint("TOPLEFT", K.TEXTS_SIDE_PAD+2, -10); title:SetText("Texts")
  local col = CreateFrame("Frame", nil, box)
  col:SetPoint("TOPLEFT", K.TEXTS_SIDE_PAD, -36)
  col:SetPoint("TOPRIGHT", -K.TEXTS_SIDE_PAD, -36)
  col:SetPoint("BOTTOM", 0, K.TEXTS_BOTTOM_PAD)
  local function makeRow(parent, idx, key)
    local r = CreateFrame("Frame", nil, parent)
    r:SetPoint("TOPLEFT", 0, -((idx-1)*ROW_STEP))
    r:SetPoint("RIGHT", 0, 0)
    r:SetHeight(EB_H + 2)
    local lab = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lab:SetPoint("LEFT", 2, 0); lab:SetWidth(K.TEXTS_LABEL_W); lab:SetJustifyH("RIGHT"); FS(lab, 13)
    lab:SetText(LabelFor(key)); lab:SetTextColor(1,1,1)
    local eb = CreateFrame("EditBox", nil, r, "InputBoxTemplate")
    eb:SetAutoFocus(false); eb:SetHeight(EB_H)
    eb:SetPoint("LEFT", lab, "RIGHT", K.TEXTS_GAP, 0)
    if K.TEXTS_EB_W > 0 then
      eb:SetWidth(K.TEXTS_EB_W)
    else
      eb:SetPoint("RIGHT", -6, 0)
    end
    eb:SetText(RAID().customText[key] or DefaultTextFor(key)); eb:SetCursorPosition(0); eb:SetFont(PanelFontPath(), 13, "")
    eb:SetJustifyH("LEFT"); eb:SetClipsChildren(false)
    eb:SetScript("OnEnterPressed", function(self) RAID().customText[key] = (self:GetText() ~= "" and self:GetText()) or nil; self:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", function(self) RAID().customText[key] = (self:GetText() ~= "" and self:GetText()) or nil end)
    local ebReset = OE.NewResetButton(eb)
    ebReset:ClearAllPoints(); ebReset:SetPoint("RIGHT", eb, "RIGHT", -6, 0)
    ebReset:SetScript("OnClick", function()
      ConfirmReset("Reset text for "..(LabelFor(key) or key).."?", function()
        local def = DefaultTextFor(key)
        RAID().customText[key] = nil
        eb:SetText(def); eb:SetCursorPosition(0)
      end)
    end)
    InstallHoverRevealMulti(ebReset, { eb })
  end
  for i=1,#keys do makeRow(col, i, keys[i]) end
  return row, K.ROW4_H
end

-- Registers the Alerts section.
O.RegisterSection(function(AddSection)
  AddSection("Alerts", function(content)
    local SCROLLBAR_WIDTH = 14
    local SCROLLBAR_INSET_PAD = 5
    local RIGHT_PAD = SCROLLBAR_WIDTH + SCROLLBAR_INSET_PAD + 8

    local header = CreateFrame("Frame", nil, content)
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    header:SetHeight(K.ROW1_H)

    local enableRow, enableCB = BuildEnableRow(header, 0, nil)

    local scroll = CreateFrame("ScrollFrame", nil, content)
    scroll:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(K.ROW1_H + K.GAP_AFTER_ENABLE))

    local vbar = SB.Create(content, { width = SCROLLBAR_WIDTH, sliderWidth = SCROLLBAR_WIDTH })
    vbar:SetPoint("TOPRIGHT",    content, "TOPRIGHT",    0, -(K.ROW1_H + K.GAP_AFTER_ENABLE))
    vbar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", vbar, "BOTTOMLEFT", -SCROLLBAR_INSET_PAD, 0)

    local inner = CreateFrame("Frame", nil, scroll)
    inner:SetPoint("TOPLEFT"); inner:SetSize(1, 1)
    scroll:SetScrollChild(inner)
    vbar:BindToScroll(scroll, inner)

    local y = 0
    local sectionFrames = {}

    local mask = CreateFrame("Frame", nil, content, "BackdropTemplate")
    mask:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8" })
    mask:SetBackdropColor(0,0,0,0.00)
    mask:SetFrameStrata("HIGH")
    mask:EnableMouse(true)
    mask:EnableMouseWheel(true)
    mask:SetScript("OnMouseWheel", function() end)
    mask:Hide()

    local headerRightMask = CreateFrame("Frame", nil, content, "BackdropTemplate")
    headerRightMask:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8" })
    headerRightMask:SetBackdropColor(0,0,0,0.00)
    headerRightMask:SetFrameStrata("HIGH")
    headerRightMask:EnableMouse(true)
    headerRightMask:EnableMouseWheel(true)
    headerRightMask:SetScript("OnMouseWheel", function() end)
    headerRightMask:Hide()

    local row2 = BuildSoundFontRow(inner, y, RIGHT_PAD)
    y = y - (K.ROW2_H + (O.ROW_V_GAP or 10))
    sectionFrames[#sectionFrames+1] = row2

    local row3 = BuildSizeColorRow(inner, y, RIGHT_PAD)
    y = y - (K.ROW3_H + (O.ROW_V_GAP or 10))
    sectionFrames[#sectionFrames+1] = row3

    local rowMotion, _, durationSel = BuildMotionRow(inner, y, RIGHT_PAD)
    y = y - (K.MOTION_ROW_H + (O.ROW_V_GAP or 10))
    sectionFrames[#sectionFrames+1] = rowMotion

    local textsRow = BuildTextsRow(inner, y, RIGHT_PAD, durationSel)
    local h4 = K.ROW4_H
    y = y - (h4 + (O.ROW_V_GAP or 10))
    sectionFrames[#sectionFrames+1] = textsRow

    local function Relayout()
      local h = 0
      for i=1,#sectionFrames do h = h + (sectionFrames[i]:GetHeight() or 0) + (O.ROW_V_GAP or 10) end
      inner:SetWidth(scroll:GetWidth() or content:GetWidth() or 600)
      inner:SetHeight(math.max(h, 1))
    end
    inner:HookScript("OnSizeChanged", Relayout)
    scroll:HookScript("OnSizeChanged", Relayout)
    Relayout()
    C_Timer.After(0, Relayout)

    local function layoutMasks()
      mask:ClearAllPoints()
      mask:SetPoint("LEFT",   content, "LEFT",   K.MASK_SIDE_PAD, 0)
      mask:SetPoint("RIGHT",  content, "RIGHT", -K.MASK_SIDE_PAD, 0)
      mask:SetPoint("TOP", header, "BOTTOM", 0, K.MASK_TOP_PAD)
      mask:SetPoint("BOTTOM", content, "BOTTOM", 0, K.MASK_BOTTOM_PAD)
      headerRightMask:ClearAllPoints()
      headerRightMask:SetPoint("TOPLEFT",  header, "TOPLEFT", 220+8, 0)
      headerRightMask:SetPoint("TOPRIGHT", content, "TOPRIGHT", -K.MASK_SIDE_PAD, 0)
      headerRightMask:SetPoint("BOTTOM",   header, "BOTTOM",   0, 0)
    end
    content:HookScript("OnSizeChanged", layoutMasks)
    inner:HookScript("OnSizeChanged", layoutMasks)
    layoutMasks()

    local function setEnabledUI(on)
      RAID().enabled = (on and true or false)
      enableCB:SetChecked(on and true or false); if enableCB._tick then enableCB._tick:SetShown(on and true or false) end
      local a = on and 1 or 0.40
      for i=1,#sectionFrames do sectionFrames[i]:SetAlpha(a) end
      mask:SetShown(not on)
      headerRightMask:SetShown(not on)
    end
    enableCB:SetScript("OnClick", function(self)
      local on = self:GetChecked() and true or false
      if self._tick then self._tick:SetShown(on) end
      setEnabledUI(on)
    end)

    setEnabledUI(RAID().enabled and true or false)
  end)
end)

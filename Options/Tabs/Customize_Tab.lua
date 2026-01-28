-- ====================================
-- \Options\Tabs\Customize_Tab.lua
-- ====================================
-- This file creates the "Customize" tab in the options panel, providing sub-tabs for
-- Mythic+, Hunter Pets, Tooltips, Delves, and Repair Mount settings.

local addonName, ns = ...
ns.Options        = ns.Options or {}
ns.NumberSelect   = ns.NumberSelect or {}
local O  = ns.Options
local NS = ns.NumberSelect

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
  tickTint    = {0.35,0.80,1.00,1},
  checkboxBox = function() return (O and O.TEXT_CHECKBOX_W) or 20 end,
  tabH        = 24,
  tabGap      = 6,
  cardSidePad = 6,
}

local function PaintBackdrop(frame, bg, br)
  frame:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
  frame:SetBackdropColor(unpack(bg))
  frame:SetBackdropBorderColor(unpack(br))
end

local function DB() return (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {} end
local defaults = (O and O.DEFAULTS) or {}

-- Creates a new checkbox with label and callback.
local function NewCheckbox(parent, label, initial, onToggle)
  local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
  cb:SetSize(THEME.checkboxBox(), THEME.checkboxBox())
  PaintBackdrop(cb, THEME.wellBG, THEME.wellBR)
  local tick = cb:CreateTexture(nil, "ARTWORK"); tick:SetAtlas("common-icon-checkmark", true)
  tick:SetPoint("CENTER"); tick:SetSize(THEME.checkboxBox()-4, THEME.checkboxBox()-4)
  tick:SetVertexColor(unpack(THEME.tickTint)); tick:Hide()
  cb._tick = tick
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  fs:SetFont(THEME.fontPath(), THEME.sizeLabel(), "")
  fs:SetText(label or "")
  local rawSetChecked = getmetatable(cb).__index.SetChecked
  function cb:SetChecked(state) rawSetChecked(self, state and true or false); if self._tick then self._tick:SetShown(state and true or false) end end
  cb:SetScript("OnClick", function(self) local v=self:GetChecked(); if self._tick then self._tick:SetShown(v) end; if onToggle then onToggle(v) end end)
  cb:SetChecked(initial and true or false); if cb._tick then cb._tick:SetShown(initial and true or false) end
  return cb, fs
end

-- Creates a mini tab button.
local function MakeMiniTab(parent, label)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  PaintBackdrop(b, THEME.rowBG, THEME.rowBR)
  b:SetHeight(THEME.tabH)
  local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  fs:SetFont(THEME.fontPath(), THEME.sizeLabel(), "")
  fs:SetPoint("CENTER")
  fs:SetText(label or "")
  b:SetFontString(fs)
  b._fs = fs
  b._basePad = 10
  b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.45,0.85,1,1) end)
  b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(THEME.rowBR)) end)
  return b
end

local function StyleTabSelected(b)
  if not b then return end
  b:SetBackdropColor(0.14,0.18,0.24,1)
  b:SetBackdropBorderColor(0.35,0.60,1.0,1)
end
local function StyleTabNormal(b)
  if not b then return end
  b:SetBackdropColor(unpack(THEME.rowBG))
  b:SetBackdropBorderColor(unpack(THEME.rowBR))
end

-- Triggers updates for Mythic+ settings.
local function PingMythicPlus()
  if ns and ns.MythicPlus_Recompute then ns.MythicPlus_Recompute() end
  if _G.updateWeaponEnchants then _G.updateWeaponEnchants() end
  local suppress = (ns and ns.MPlus_DisableConsumablesActive and ns.MPlus_DisableConsumablesActive()) or false
  if suppress then
    _G.clickableRaidBuffCache = _G.clickableRaidBuffCache or {}
    _G.clickableRaidBuffCache.displayable = _G.clickableRaidBuffCache.displayable or {}
    local d = _G.clickableRaidBuffCache.displayable
    d.FOOD, d.FLASK, d.MAIN_HAND, d.OFF_HAND = {}, {}, {}, {}
    if ns and ns.RenderAll then ns.RenderAll() end
    return
  end
  if type(_G.scanAllBags) == "function" then _G.scanAllBags() end
  if ns and ns.UpdateAugmentRunes then ns.UpdateAugmentRunes() end
  if ns and ns.RequestRebuild then ns.RequestRebuild() end
  if ns and ns.RenderAll then ns.RenderAll() end
end

-- Builds the Mythic+ settings panel.
local function BuildMythicPlusPanel(parent)
  local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  holder:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
  holder:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)

  local col = CreateFrame("Frame", nil, holder)
  col:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
  col:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
  col:SetHeight(160)

  local d = DB()
  local enabled = (d.mplusThresholdEnabled ~= false)

  local enableCB, enableLabel = NewCheckbox(col, "Enable Mythic+ Threshold", enabled, function(v)
    d.mplusThresholdEnabled = v and true or false
    if col._nsHolder then col._nsHolder:SetEnabled(v) end
    PingMythicPlus()
  end)
  enableCB:SetPoint("TOPLEFT", col, "TOPLEFT", 0, -4)
  enableLabel:ClearAllPoints()
  enableLabel:SetPoint("LEFT", enableCB, "RIGHT", 8, 0)

  local defV = defaults.mplusThreshold or 45
  local curV = (d.mplusThreshold ~= nil) and d.mplusThreshold or defV

  local nsHolder = NS.Create(col, {
    label   = "Mythic+ Buffs (Minutes)",
    min     = 1,
    max     = 120,
    step    = 0.5,
    value   = curV,
    default = defV,
    onChange = function(v)
      d.mplusThreshold = v
      PingMythicPlus()
    end,
  })
  nsHolder:SetPoint("TOPLEFT", enableCB, "BOTTOMLEFT", 0, -12)
  nsHolder:SetEnabled(enabled)
  col._nsHolder = nsHolder

  local cb, lab = NewCheckbox(col, "Disable Consumables after Key Starts", d.mplusDisableConsumables == true, function(v)
    d.mplusDisableConsumables = v and true or false
    PingMythicPlus()
  end)
  cb:SetPoint("TOPLEFT", nsHolder, "BOTTOMLEFT", 0, -14)
  lab:ClearAllPoints()
  lab:SetPoint("LEFT", cb, "RIGHT", 8, 0)

  return holder
end

-- Builds the Hunter Pets settings panel.
local function BuildHunterPetsPanel(parent)
  local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  holder:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
  holder:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)

  local d = DB(); d.hunterPets = d.hunterPets or {}
  local hp = d.hunterPets

  local function refresh()
    if ns.Pets_Rebuild then ns.Pets_Rebuild() end
    if ns.RenderAll then ns.RenderAll() end
  end

  local cb1, lab1 = NewCheckbox(holder, "Reverse Pet Order", hp.reverseOrder == true, function(v)
    hp.reverseOrder = v and true or false
    refresh()
  end)
  cb1:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -4)
  lab1:ClearAllPoints()
  lab1:SetPoint("LEFT", cb1, "RIGHT", 8, 0)

  local cb2, lab2 = NewCheckbox(holder, "Use Pet Ability Icon", hp.useAbilityIcon == true, function(v)
    hp.useAbilityIcon = v and true or false
    refresh()
  end)
  cb2:SetPoint("TOPLEFT", cb1, "BOTTOMLEFT", 0, -12)
  lab2:ClearAllPoints()
  lab2:SetPoint("LEFT", cb2, "RIGHT", 8, 0)

  local initTalents = (hp.displayTalentsSymbol ~= false)
  local cb3, lab3 = NewCheckbox(holder, "Display Pet Talents Symbol", initTalents, function(v)
    hp.displayTalentsSymbol = v and true or false
    refresh()
  end)
  cb3:SetPoint("TOPLEFT", cb2, "BOTTOMLEFT", 0, -12)
  lab3:ClearAllPoints()
  lab3:SetPoint("LEFT", cb3, "RIGHT", 8, 0)

  local initHover = (hp.showAbilityOnMouseover ~= false)
  local cb4, lab4 = NewCheckbox(holder, "Show Pet Ability on Mouseover", initHover, function(v)
    hp.showAbilityOnMouseover = v and true or false
    refresh()
  end)
  cb4:SetPoint("TOPLEFT", cb3, "BOTTOMLEFT", 0, -12)
  lab4:ClearAllPoints()
  lab4:SetPoint("LEFT", cb4, "RIGHT", 8, 0)

  return holder
end

-- Builds the Tooltips settings panel.
local function BuildTooltipsPanel(parent)
  local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  holder:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
  holder:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)

  local d = DB(); d.tooltips = d.tooltips or {}
  local tt = d.tooltips
  local initOn = (tt.enabled ~= false)

  local cb, lab = NewCheckbox(holder, "Enable Tooltips", initOn, function(v)
    tt.enabled = v and true or false
  end)
  cb:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -4)
  lab:ClearAllPoints()
  lab:SetPoint("LEFT", cb, "RIGHT", 8, 0)

  return holder
end

-- Builds the Delves settings panel.
local function BuildDelvesPanel(parent)
  local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  holder:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
  holder:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)

  local d = DB()
  local init = (d.delvesDisableConsumables == true)

  local cb, lab = NewCheckbox(holder, "Disable Consumables in Delves", init, function(v)
    d.delvesDisableConsumables = v and true or false
    if type(ns.Delves_Recompute) == "function" then ns.Delves_Recompute() end
  end)
  cb:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -4)
  lab:ClearAllPoints()
  lab:SetPoint("LEFT", cb, "RIGHT", 8, 0)

  return holder
end

-- Builds the Repair Mount settings panel.
local function BuildMountsPanel(parent)
  local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  holder:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
  holder:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)

  local d = DB(); d.mounts = d.mounts or {}

  local faction = select(1, UnitFactionGroup("player"))
  local ttm = (faction == "Alliance") and 280 or ((faction == "Horde") and 284 or nil)
  local ids = {1039, 460, 2237, ttm}

  local selected = tonumber(d.mounts.selectedMount or ns.SelectedMount or 0) or 0
  local cbs = {}

  local function setSelected(id)
    if not id then return end
    d.mounts.selectedMount = id
    ns.SelectedMount = id
    for _, cb in ipairs(cbs) do
      cb:SetChecked(cb._crb_id == id)
    end
    if ns.Durability_SetSelectedMount then ns.Durability_SetSelectedMount(id) end
  end

  local prevCB

  for i = 1, #ids do
    local id = ids[i]
    if id then
      local name = (C_MountJournal and C_MountJournal.GetMountInfoByID and (select(1, C_MountJournal.GetMountInfoByID(id))))
                   or ("Mount " .. tostring(id))

      local cb, lab = NewCheckbox(holder, name, selected == id, function(v)
        if v then
          setSelected(id)
        else
          if d.mounts.selectedMount == id then
            cb:SetChecked(true)
          end
        end
      end)
      cb._crb_id = id

      if not prevCB then
        cb:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -4)
      else
        cb:SetPoint("TOPLEFT", prevCB, "BOTTOMLEFT", 0, -12)
      end

      lab:ClearAllPoints()
      lab:SetPoint("LEFT", cb, "RIGHT", 8, 0)

      table.insert(cbs, cb)
      prevCB = cb
    end
  end

  return holder
end



O.RegisterSection(function(AddSection)
  AddSection("Customize", function(content, Row)
    local row = Row(385)

    local card = CreateFrame("Frame", nil, row, "BackdropTemplate")
    PaintBackdrop(card, THEME.cardBG, THEME.cardBR)
    card:SetPoint("TOPLEFT", 0, -8)
    card:SetPoint("BOTTOMRIGHT", 0, 0)

    local tabsArea = CreateFrame("Frame", nil, card, "BackdropTemplate")
    tabsArea:SetPoint("TOPLEFT",  THEME.cardSidePad, -12)
    tabsArea:SetPoint("TOPRIGHT", -THEME.cardSidePad, -12)
    tabsArea:SetHeight(THEME.tabH)

    local tabRow = CreateFrame("Frame", nil, tabsArea)
    tabRow:SetPoint("TOPLEFT", tabsArea, "TOPLEFT", 0, 0)
    tabRow:SetPoint("TOPRIGHT", tabsArea, "TOPRIGHT", 0, 0)
    tabRow:SetHeight(THEME.tabH)

    local inner = CreateFrame("Frame", nil, card, "BackdropTemplate")
    inner:SetPoint("TOPLEFT",  THEME.cardSidePad, -12 - (THEME.tabH + 4))
    inner:SetPoint("BOTTOMRIGHT", -THEME.cardSidePad, 6)
    PaintBackdrop(inner, THEME.wellBG, THEME.wellBR)

    local mythicBtn = MakeMiniTab(tabRow, "Mythic+")
    mythicBtn:SetPoint("LEFT", tabRow, "LEFT", 0, 0)
    mythicBtn._basePad = 12
    local w1 = (mythicBtn._fs:GetStringWidth() or 60) + mythicBtn._basePad*2
    mythicBtn:SetWidth(math.max(80, math.floor(w1 + 0.5)))

    local hunterBtn = MakeMiniTab(tabRow, "Hunter Pets")
    hunterBtn:SetPoint("LEFT", mythicBtn, "RIGHT", THEME.tabGap, 0)
    hunterBtn._basePad = 12
    local w2 = (hunterBtn._fs:GetStringWidth() or 60) + hunterBtn._basePad*2
    hunterBtn:SetWidth(math.max(110, math.floor(w2 + 0.5)))

    local tipsBtn = MakeMiniTab(tabRow, "Tooltips")
    tipsBtn:SetPoint("LEFT", hunterBtn, "RIGHT", THEME.tabGap, 0)
    tipsBtn._basePad = 12
    local w3 = (tipsBtn._fs:GetStringWidth() or 60) + tipsBtn._basePad*2
    tipsBtn:SetWidth(math.max(90, math.floor(w3 + 0.5)))

    local delvesBtn = MakeMiniTab(tabRow, "Delves")
    delvesBtn:SetPoint("LEFT", tipsBtn, "RIGHT", THEME.tabGap, 0)
    delvesBtn._basePad = 12
    local w4 = (delvesBtn._fs:GetStringWidth() or 60) + delvesBtn._basePad*2
    delvesBtn:SetWidth(math.max(90, math.floor(w4 + 0.5)))

    local mountsBtn = MakeMiniTab(tabRow, "Repair Mount")
    mountsBtn:SetPoint("LEFT", delvesBtn, "RIGHT", THEME.tabGap, 0)
    mountsBtn._basePad = 12
    local w5 = (mountsBtn._fs:GetStringWidth() or 60) + mountsBtn._basePad*2
    mountsBtn:SetWidth(math.max(90, math.floor(w5 + 0.5)))

    local panels = {}
    local function showPanel(key)
      for _, f in pairs(panels) do if f then f:Hide() end end
      if key == "MYTHIC" then
        if not panels.MYTHIC then panels.MYTHIC = BuildMythicPlusPanel(inner) end
        panels.MYTHIC:Show()
      elseif key == "HUNTER" then
        if not panels.HUNTER then panels.HUNTER = BuildHunterPetsPanel(inner) end
        panels.HUNTER:Show()
      elseif key == "TIPS" then
        if not panels.TIPS then panels.TIPS = BuildTooltipsPanel(inner) end
        panels.TIPS:Show()
      elseif key == "DELVES" then
        if not panels.DELVES then panels.DELVES = BuildDelvesPanel(inner) end
        panels.DELVES:Show()
      elseif key == "MOUNTS" then
        if not panels.MOUNTS then panels.MOUNTS = BuildMountsPanel(inner) end
        panels.MOUNTS:Show()
      end
    end

    local function selectTab(which)
      StyleTabNormal(mythicBtn); StyleTabNormal(hunterBtn); StyleTabNormal(tipsBtn); StyleTabNormal(delvesBtn); StyleTabNormal(mountsBtn)
      if which == "MYTHIC" then StyleTabSelected(mythicBtn) end
      if which == "HUNTER" then StyleTabSelected(hunterBtn) end
      if which == "TIPS"   then StyleTabSelected(tipsBtn)   end
      if which == "DELVES" then StyleTabSelected(delvesBtn) end
      if which == "MOUNTS" then StyleTabSelected(mountsBtn) end
      showPanel(which)
    end

    mythicBtn:SetScript("OnClick", function() selectTab("MYTHIC") end)
    hunterBtn:SetScript("OnClick", function() selectTab("HUNTER") end)
    tipsBtn:SetScript("OnClick", function() selectTab("TIPS") end)
    delvesBtn:SetScript("OnClick", function() selectTab("DELVES") end)
    mountsBtn:SetScript("OnClick", function() selectTab("MOUNTS") end)

    card:SetScript("OnShow", function() selectTab("MYTHIC") end)
  end)
end)

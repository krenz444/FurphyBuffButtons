-- ====================================
-- \Options\Tabs\Ignore_Tab.lua
-- ====================================
-- This file creates the "Ignore" tab in the options panel, allowing users to exclude
-- specific buffs, items, or categories from being tracked and displayed.

local addonName, ns = ...
ns.Options = ns.Options or {}
local O = ns.Options

local EXCLUSIONS_WINDOW_HEIGHT = (O and O.EXCLUSIONS_WINDOW_HEIGHT) or 385

local function DB()
  return (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {}
end

-- Retrieves the appropriate exclusion set (general or raid buff specific) based on the active key.
local function GetExcludedSet(activeKey)
  local d = DB()
  d.exclusions = d.exclusions or {}
  d.raidBuffExclusions = d.raidBuffExclusions or {}
  if activeKey == "RAID_BUFFS" or activeKey == "CLASS_ABILITIES" or activeKey == "TRINKET_RB" then
    return d.raidBuffExclusions
  else
    return d.exclusions
  end
end

-- Checks if an ID is excluded for a given category key.
function ns.IsExcluded(id, activeKey)
  if not id then return false end

  local d = (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {}
  d.exclusions = d.exclusions or {}
  d.raidBuffExclusions = d.raidBuffExclusions or {}

  if activeKey == "RAID_BUFFS" or activeKey == "CLASS_ABILITIES" or activeKey == "TRINKET_RB" then
    return d.raidBuffExclusions[id] and true or false
  elseif activeKey ~= nil then
    return d.exclusions[id] and true or false
  end

  return (d.exclusions[id] or d.raidBuffExclusions[id]) and true or false
end

local _pendingOptionsRefresh
local function _safeCall(f, ...) if type(f)=="function" then local ok=pcall(f, ...); return ok end return false end
-- Notifies the addon of changes to exclusions, triggering a refresh.
local function NotifyChanged()
  if _pendingOptionsRefresh then return end
  _pendingOptionsRefresh = true
  C_Timer.After(0.05, function()
    _pendingOptionsRefresh = false
    if O and _safeCall(O.OnOptionChanged) then return end
    if ns and (_safeCall(ns.RebuildDisplayables) or _safeCall(ns.RefreshEverything) or _safeCall(ns.PushRender) or _safeCall(ns.RenderAll)) then return end
    if _G and (_safeCall(_G.ClickableRaidBuffs_Rebuild) or _safeCall(_G.ClickableRaidBuffs_ForceRefresh) or _safeCall(_G.ClickableRaidBuffs_PushRender)) then return end
  end)
end

-- Applies changes immediately without a full UI reload.
local function ApplyNow_NoReload()
  _safeCall(ns.RebuildDisplayables)
  _safeCall(ns.RefreshEverything)
  _safeCall(ns.PushRender)
  _safeCall(ns.RenderAll)
end

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
  btnBG       = {0.10, 0.115, 0.16, 1.00},
  btnBR       = {0.20, 0.22, 0.28, 1.00},
  btnBGHover  = {0.14, 0.18, 0.24, 1.00},
  btnBRHover  = {0.45, 0.85, 1.00, 1.00},
}

local function PaintBackdrop(frame, bg, br)
  frame:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
  frame:SetBackdropColor(unpack(bg))
  frame:SetBackdropBorderColor(unpack(br))
end

local function tclear(t) for k in pairs(t) do k=k; t[k] = nil end end

local function NewCheckbox(parent)
  local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
  cb:SetSize(THEME.checkboxBox(), THEME.checkboxBox())
  PaintBackdrop(cb, THEME.wellBG, THEME.wellBR)
  local tick = cb:CreateTexture(nil, "ARTWORK"); tick:SetAtlas("common-icon-checkmark", true)
  tick:SetPoint("CENTER"); tick:SetSize(THEME.checkboxBox()-4, THEME.checkboxBox()-4)
  tick:SetVertexColor(unpack(THEME.tickTint)); tick:Hide()
  cb._tick = tick
  local rawSetChecked = getmetatable(cb).__index.SetChecked
  function cb:SetChecked(state) rawSetChecked(self, state and true or false); self._tick:SetShown(state and true or false) end
  cb:SetScript("OnClick", function(self) local v=self:GetChecked(); self._tick:SetShown(v); if self._onToggle then self:_onToggle(v) end end)
  cb:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.45,0.85,1,1) end)
  cb:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(THEME.wellBR)) end)
  return cb
end

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

local RANK_ATLAS = {
  [1] = "Professions-Icon-Quality-Tier1",
  [2] = "Professions-Icon-Quality-Tier2",
  [3] = "Professions-Icon-Quality-Tier3",
}

local function GetSpellIconSafe(spellID)
  if not spellID then return 134400, false end
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellID)
    if info and info.iconID then return info.iconID, false end
    if C_Spell.RequestLoadSpellData then
      C_Spell.RequestLoadSpellData(spellID)
      local tex = GetSpellTexture and GetSpellTexture(spellID)
      return tex or 134400, true
    end
  end
  local tex = GetSpellTexture and GetSpellTexture(spellID)
  return tex or 134400, false
end
local function GetItemIconSafe(itemID)
  if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(itemID), false end
  if GetItemIcon then return GetItemIcon(itemID), false end
  return 134400, false
end

local function sortItems(items)
  table.sort(items, function(a,b)
    if (a.name or "") == (b.name or "") then
      local ar, br = a.rank or 0, b.rank or 0
      if ar ~= br then return ar > br end
    end
    return (a.name or "") < (b.name or "")
  end)
end

local SPLIT_SOURCES = {
  FOOD                        = "Food_Table",
  FLASK                       = "Flask_Table",
  AUGMENT_RUNE                = "AugmentRune_Table",
  MAIN_HAND                   = "MainHand_Table",
  OFF_HAND                    = "OffHand_Table",
  ROGUE_POISONS               = "RoguePoisons_Table",
  CASTABLE_WEAPON_ENCHANTS    = "CastableWeaponEnchants_Table",
  PETS                        = "Pets_Table",
  SHAMAN_SHIELDS              = "ShamanShields_Table",
  COSMETIC                    = "CosmeticItems_Table",
}

local function getCategorySource(cat)
  local d = _G.ClickableRaidData or {}
  if type(d[cat]) == "table" then return d[cat] end
  local splitName = SPLIT_SOURCES[cat]
  if splitName and type(_G[splitName]) == "table" then return _G[splitName] end
  return nil
end

local function flattenItems(src)
  local items = {}
  for id, v in pairs(src) do
    if type(id) == "number" then
      local name  = (type(v)=="table" and v.name) or tostring(v)
      local rank  = (type(v)=="table" and v.rank) or nil
      local icon  = (type(v)=="table" and v.icon) or select(1, GetItemIconSafe(id))
      items[#items+1] = { id=id, isItem=true, name=name, rank=rank, icon=icon }
    end
  end
  sortItems(items)
  return items
end

local function _normName(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
  return s:lower()
end

local function flattenSpells(src)
  local items, requested = {}, false
  local byName = {}

  for keyID, v in pairs(src) do
    if type(keyID) == "number" then
      local spellID = (type(v)=="table" and (v.spellID or keyID)) or keyID
      local name
      if C_Spell and C_Spell.GetSpellInfo then
        name = (type(v)=="table" and (v.name or v.label)) or (C_Spell.GetSpellInfo(spellID) or {}).name or tostring(spellID)
      else
        name = (type(v)=="table" and (v.name or v.label)) or tostring(spellID)
      end
      local icon, req = (type(v)=="table" and v.icon) and v.icon or GetSpellIconSafe(spellID)
      requested = requested or req
      local rank = (type(v)=="table" and v.rank) or nil

      local nameKey = _normName(name)
      local group = byName[nameKey]
      if not group then
        local item = { id=keyID, isItem=false, spellID=spellID, name=name, icon=icon, rank=rank }
        group = { primary=item, ids={ keyID } }
        byName[nameKey] = group
        items[#items+1] = item
      else
        local found = false
        for i=1,#group.ids do if group.ids[i]==keyID then found=true; break end end
        if not found then group.ids[#group.ids+1] = keyID end
      end
    end
  end

  for _, group in pairs(byName) do
    if #group.ids > 1 then
      group.primary._dedupeIDs = group.ids
    end
  end

  sortItems(items)
  return items, requested
end

local CLASS_NAMES = {
  [1]="Warrior",[2]="Paladin",[3]="Hunter",[4]="Rogue",[5]="Priest",
  [6]="Death Knight",[7]="Shaman",[8]="Mage",[9]="Warlock",[10]="Monk",
  [11]="Druid",[12]="Demon Hunter",[13]="Evoker",
}
local CLASS_KEY_FOR_ID = { [1]="WARRIOR",[2]="PALADIN",[3]="HUNTER",[4]="ROGUE",[5]="PRIEST",[6]="DEATHKNIGHT",[7]="SHAMAN",[8]="MAGE",[9]="WARLOCK",[10]="MONK",[11]="DRUID",[12]="DEMONHUNTER",[13]="EVOKER" }

local CWE_BY_CLASS = {
  SHAMAN   = { [318038]=true, [33757]=true, [382021]=true, [462757]=true },
  PALADIN  = { [433568]=true, [433583]=true },
}

local function mergeUnique(items, add)
  if not add or #add == 0 then return items end
  local seen = {}
  for _, it in ipairs(items) do seen[it.id] = true end
  for _, it in ipairs(add) do if not seen[it.id] then items[#items+1] = it end end
  sortItems(items)
  return items
end

local function collectClassAbilitiesByClass()
  local outBlocks, requested = {}, false
  local root = _G.ClickableRaidData or {}
  local byClass = root.ALL_RAID_BUFFS_BY_CLASS

  local rogPois = getCategorySource("ROGUE_POISONS") or {}
  local rogPoisItems, reqPois = flattenSpells(rogPois)
  requested = requested or reqPois

  local cweSrc = getCategorySource("CASTABLE_WEAPON_ENCHANTS") or {}
  local cweItems, reqCwe = flattenSpells(cweSrc)
  requested = requested or reqCwe

  local function cweForClass(classKey)
    local want = {}
    local map = CWE_BY_CLASS[classKey]
    if not map then return want end
    for _, it in ipairs(cweItems) do if map[it.spellID] then want[#want+1] = it end end
    return want
  end

  local function shamanShields()
    local shamSrc = getCategorySource("SHAMAN_SHIELDS") or {}
    local add, req2 = flattenSpells(shamSrc)
    requested = requested or req2
    return add
  end

  local function makeHealthstoneEntry()
    return { id = -9102, isItem = false, name = "Healthstone", icon = 538745, spellID = 6262, _comboHS = true }
  end

  local function classIDFromKey(k)
    for id, key in pairs(CLASS_KEY_FOR_ID) do if key == k then return id end end
    return nil
  end

  local playerClassKey = select(2, UnitClass("player"))
  local playerClassID = classIDFromKey(playerClassKey) or 0

  local tmp = {}

  if type(byClass)=="table" and type(root.RAID_BUFF_CLASS_ORDER)=="table" and type(root.RAID_BUFF_CLASS_LABELS)=="table" then
    for _, classKey in ipairs(root.RAID_BUFF_CLASS_ORDER) do
      local baseTbl = byClass[classKey] or {}
      local items, req = flattenSpells(baseTbl); requested = requested or req

      if classKey == "ROGUE"   then items = mergeUnique(items, rogPoisItems) end
      if classKey == "SHAMAN"  then items = mergeUnique(items, shamanShields()); items = mergeUnique(items, cweForClass("SHAMAN")) end
      if classKey == "PALADIN" then items = mergeUnique(items, cweForClass("PALADIN")) end
      if classKey == "WARLOCK" then items[#items+1] = makeHealthstoneEntry() end

      if #items > 0 then
        local cid = classIDFromKey(classKey) or 99
        tmp[#tmp+1] = { cid = cid, block = { label = root.RAID_BUFF_CLASS_LABELS[classKey] or tostring(classKey), items = items } }
      end
    end
  elseif type(byClass)=="table" and next(byClass) then
    for classID = 1, 13 do
      local baseTbl = byClass[classID] or {}
      local items, req = flattenSpells(baseTbl); requested = requested or req
      local key = CLASS_KEY_FOR_ID[classID]

      if key == "ROGUE"   then items = mergeUnique(items, rogPoisItems) end
      if key == "SHAMAN"  then items = mergeUnique(items, shamanShields()); items = mergeUnique(items, cweForClass("SHAMAN")) end
      if key == "PALADIN" then items = mergeUnique(items, cweForClass("PALADIN")) end
      if key == "WARLOCK" then items[#items+1] = makeHealthstoneEntry() end

      if #items > 0 then
        tmp[#tmp+1] = { cid = classID, block = { label = CLASS_NAMES[classID] or ("Class "..tostring(classID)), items = items } }
      end
    end
  else
    local flat, reqAny = {}, false
    if type(root.ALL_RAID_BUFFS)=="table" then flat, reqAny = flattenSpells(root.ALL_RAID_BUFFS) end
    if #flat > 0 then outBlocks[#outBlocks+1] = { label = "All Class Abilities", items = flat } end
    if reqAny and ns.Exclusions_RefreshNow then C_Timer.After(0.35, function() ns.Exclusions_RefreshNow(true) end) end
    return outBlocks
  end

  table.sort(tmp, function(a, b)
    local ap, bp = (a.cid == playerClassID), (b.cid == playerClassID)
    if ap ~= bp then return ap end
    return (a.cid or 99) < (b.cid or 99)
  end)

  for i=1,#tmp do outBlocks[#outBlocks+1] = tmp[i].block end
  if requested and ns.Exclusions_RefreshNow then C_Timer.After(0.35, function() ns.Exclusions_RefreshNow(true) end) end
  return outBlocks
end

local function collectTrinketRaidBuffs()
  local out = {}
  local root = _G.ClickableRaidData or {}

  if type(root.ALL_TRINKETS)=="table" and next(root.ALL_TRINKETS) then
    for id, info in pairs(root.ALL_TRINKETS) do
      local itemID = (type(info)=="table" and info.itemID) or id
      if type(itemID)=="number" then
        local icon = select(1, GetItemIconSafe(itemID))
        out[#out+1] = { id = itemID, isItem = true, name = (type(info)=="table" and info.name) or "", icon = icon }
      end
    end
    sortItems(out)
    return { { label = "Trinkets", items = out } }
  end

  for classID=1,13 do
    local tbl = root[classID]
    if type(tbl)=="table" then
      for id, info in pairs(tbl) do
        if type(id)=="number" and type(info)=="table" and (info.type=="trinket" or info.topLbl==INVTYPE_TRINKET) then
          local itemID = info.itemID or id
          local icon = select(1, GetItemIconSafe(itemID))
          out[#out+1] = { id = itemID, isItem = true, name = info.name or "", icon = icon }
        end
      end
    end
  end
  sortItems(out)
  return { { label = "Trinkets", items = out } }
end

O.RegisterSection(function(AddSection)
  AddSection("Ignore", function(content, Row)
    local row = Row(EXCLUSIONS_WINDOW_HEIGHT - 6)

    local card = CreateFrame("Frame", nil, row, "BackdropTemplate")
    PaintBackdrop(card, THEME.cardBG, THEME.cardBR)
    card:SetPoint("TOPLEFT", 0, -8)
    card:SetPoint("BOTTOMRIGHT", 0, 0)

    local tabsArea = CreateFrame("Frame", nil, card, "BackdropTemplate")
    tabsArea:SetPoint("TOPLEFT",  THEME.cardSidePad, -12)
    tabsArea:SetPoint("TOPRIGHT", -THEME.cardSidePad, -12)
    tabsArea:SetHeight(THEME.tabH*2 + THEME.tabGap)

    local tabRowTop  = CreateFrame("Frame", nil, tabsArea)
    local tabRowBot  = CreateFrame("Frame", nil, tabsArea)

    tabRowTop:SetPoint("TOPLEFT", tabsArea, "TOPLEFT", 0, 0)
    tabRowTop:SetPoint("TOPRIGHT", tabsArea, "TOPRIGHT", 0, 0)
    tabRowTop:SetHeight(THEME.tabH)

    tabRowBot:SetPoint("TOPLEFT", tabsArea, "TOPLEFT", 0, -(THEME.tabH + THEME.tabGap))
    tabRowBot:SetPoint("TOPRIGHT", tabsArea, "TOPRIGHT", 0, -(THEME.tabH + THEME.tabGap))
    tabRowBot:SetHeight(THEME.tabH)

    local inner = CreateFrame("Frame", nil, card, "BackdropTemplate")
    inner:SetPoint("TOPLEFT",  THEME.cardSidePad, -12 - (THEME.tabH*2 + THEME.tabGap + 4))
    inner:SetPoint("BOTTOMRIGHT", -THEME.cardSidePad, 6)
    PaintBackdrop(inner, THEME.wellBG, THEME.wellBR)

    local SIDE_PAD  = 10
    local TOP_PAD   = 8
    local BAR_WIDTH = 16
    local RIGHT_GAP = 8

    local scroll = CreateFrame("ScrollFrame", nil, inner, "BackdropTemplate")
    scroll:SetPoint("TOPLEFT",     inner, "TOPLEFT",  SIDE_PAD, -TOP_PAD)
    scroll:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -(SIDE_PAD + BAR_WIDTH + RIGHT_GAP), SIDE_PAD)

    local contentFrame = CreateFrame("Frame", nil, scroll)
    contentFrame:SetSize(1, 1)
    scroll:SetScrollChild(contentFrame)

    local bar = (ns.ScrollBar and ns.ScrollBar.Create) and ns.ScrollBar.Create(inner, { width = BAR_WIDTH, sliderWidth = BAR_WIDTH-2, minThumbH = 24 }) or nil
    if bar then
      bar:SetPoint("TOPRIGHT",    inner, "TOPRIGHT",    -SIDE_PAD, -TOP_PAD)
      bar:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -SIDE_PAD,  SIDE_PAD)
      bar:BindToScroll(scroll, contentFrame)
    end

    local function ResetScrollToTop()
      if scroll and scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
      if bar and bar.SetValue then bar:SetValue(0) end
      scroll:UpdateScrollChildRect()
      if bar and bar.UpdateThumb then bar:UpdateThumb(scroll:GetHeight(), contentFrame:GetHeight()) end
    end

    local ROW_H, ICON_SZ = 26, 22
    local ICON_ZOOM = 0.08
    local headers, lines = {}, {}

    local headerBtns = {}

    local function clearHeaders()
      for i=1,#headers do
        local h = headers[i]
        if h then h:Hide(); h:SetParent(nil) end
      end
      for i=1,#headerBtns do
        local pair = headerBtns[i]
        if pair then
          if pair.ignore then pair.ignore:Hide(); pair.ignore:SetParent(nil) end
          if pair.enable then pair.enable:Hide(); pair.enable:SetParent(nil) end
        end
      end
      if wipe then wipe(headers) else tclear(headers) end
      if wipe then wipe(headerBtns) else tclear(headerBtns) end
    end

    local function MakeActionButton(parent, text)
      local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
      PaintBackdrop(b, THEME.btnBG or THEME.rowBG, THEME.btnBR or THEME.rowBR)
      b:SetHeight(20)

      local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      fs:SetFont(THEME.fontPath(), THEME.sizeLabel(), "")
      fs:SetPoint("CENTER")
      fs:SetText(text or "")
      b._fs = fs

      b:SetScript("OnEnter", function(self)
        local bg = THEME.btnBGHover or THEME.rowBG
        local br = THEME.btnBRHover or THEME.rowBR
        self:SetBackdropColor(unpack(bg))
        self:SetBackdropBorderColor(unpack(br))
      end)
      b:SetScript("OnLeave", function(self)
        local bg = THEME.btnBG or THEME.rowBG
        local br = THEME.btnBR or THEME.rowBR
        self:SetBackdropColor(unpack(bg))
        self:SetBackdropBorderColor(unpack(br))
      end)

      C_Timer.After(0, function()
        local w = math.max(60, math.floor((fs:GetStringWidth() or 40) + 14 + 0.5))
        b:SetWidth(w)
      end)

      return b
    end


    local function ApplyBulkExclusion(items, activeKeyForList, setOn)
      local set = GetExcludedSet(activeKeyForList)
      for i=1,#items do
        local info = items[i]
        if info then
          if info._comboHS then
            if setOn then set[5512] = true; set[224464] = true else set[5512] = nil; set[224464] = nil end
          elseif info._dedupeIDs then
            for j=1,#info._dedupeIDs do
              local k = info._dedupeIDs[j]
              if setOn then set[k] = true else set[k] = nil end
            end
          elseif info._defaultChecked then
            if setOn then set[info.id] = true else set[info.id] = false end
          else
            if setOn then set[info.id] = true else set[info.id] = nil end
          end
        end
      end
      if ns.Exclusions and ns.Exclusions.MarkDirty then ns.Exclusions.MarkDirty() end
      ApplyNow_NoReload()
      if ns.Exclusions_RefreshNow then ns.Exclusions_RefreshNow(true) end
      NotifyChanged()
    end

    local function makeHeader(y, text, itemsForBlock, activeKeyForList)
      local holder = CreateFrame("Frame", nil, contentFrame)
      holder:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -y)
      holder:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
      holder:SetHeight(22)

      local f = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      f:SetPoint("LEFT", holder, "LEFT", 0, 0)
      f:SetFont(THEME.fontPath(), THEME.sizeLabel()+2, "")
      f:SetText(text or "")

      local btnEnable = MakeActionButton(holder, "Show All")
      btnEnable:SetPoint("RIGHT", holder, "RIGHT", -2, 0)

      local btnIgnore = MakeActionButton(holder, "Hide All")
      btnIgnore:SetPoint("RIGHT", btnEnable, "LEFT", -6, 0)

      btnEnable:SetScript("OnClick", function()
        ApplyBulkExclusion(itemsForBlock or {}, activeKeyForList, false)
      end)
      btnIgnore:SetScript("OnClick", function()
        ApplyBulkExclusion(itemsForBlock or {}, activeKeyForList, true)
      end)

      headers[#headers+1] = holder
      headerBtns[#headerBtns+1] = { ignore = btnIgnore, enable = btnEnable }
      return holder, y + 22
    end

    local function makeLine(idx)
      local line = CreateFrame("Button", nil, contentFrame, "BackdropTemplate")
      PaintBackdrop(line, THEME.rowBG, THEME.rowBR)
      line:SetHeight(ROW_H)
      line:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.45,0.85,1,1)
        if self._noTT then return end

        local function ShowTipSpell(spellID)
          if not spellID or type(spellID) ~= "number" or spellID <= 0 then return false end
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          local link = (C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(spellID)) or ("spell:"..spellID)
          GameTooltip:SetHyperlink(link); GameTooltip:Show()
          if C_Spell and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(spellID) end
          return true
        end

        if self._tipSpell and ShowTipSpell(self._tipSpell) then return end

        if self._isItem then
          if self._id and self._id > 0 then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(self._id); GameTooltip:Show() end
        else
          local sid = self._spellID or self._id
          if sid and sid > 0 then if not ShowTipSpell(sid) and GameTooltip.SetSpellByID then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetSpellByID(sid); GameTooltip:Show() end end
        end
      end)
      line:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(THEME.rowBR)); GameTooltip:Hide() end)

      local icon = line:CreateTexture(nil, "ARTWORK")
      icon:SetSize(ICON_SZ, ICON_SZ)
      icon:SetPoint("LEFT", line, "LEFT", 6, 0)
      icon:SetTexCoord(ICON_ZOOM, 1-ICON_ZOOM, ICON_ZOOM, 1-ICON_ZOOM)

      local nameFS = line:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      nameFS:SetPoint("LEFT", icon, "RIGHT", 6, 0)
      nameFS:SetJustifyH("LEFT")
      nameFS:SetFont(THEME.fontPath(), THEME.sizeLabel(), "")

      local cb = NewCheckbox(line)
      cb:SetPoint("RIGHT", line, "RIGHT", -6, 0)

      line:SetScript("OnClick", function(self) cb:Click() end)
      line:EnableMouse(true)
      line:SetHitRectInsets(-4, -4, -4, -4)

      line._icon  = icon
      line._name  = nameFS
      line._cb    = cb

      lines[idx] = line
      return line
    end

    local function configureLine(line, info, nameW, activeKey)
      line._id       = info.id
      line._isItem   = info.isItem
      line._spellID  = info.spellID
      line._tipSpell = info.tipSpellID
      line._noTT     = info.noTooltip or false

      if info.icon then line._icon:SetTexture(info.icon); line._icon:Show() else line._icon:Hide() end

      local text = info.name or ""
      if info.rank and RANK_ATLAS[info.rank] then
        text = text .. " " .. ("|A:%s:16:16|a"):format(RANK_ATLAS[info.rank])
      end
      line._name:SetWidth(nameW)
      line._name:SetText(text)

      local exset = GetExcludedSet(activeKey)
      local excluded = ns.IsExcluded(info.id, activeKey)

      if info._comboHS then excluded = (exset[5512] or exset[224464]) and true or false end

      if info._dedupeIDs then
        excluded = false
        for i=1,#info._dedupeIDs do
          if exset[ info._dedupeIDs[i] ] then excluded = true; break end
        end
      end

      if info._defaultChecked then
        if exset[info.id] == nil then excluded = true else excluded = exset[info.id] and true or false end
      end

      line._cb:SetChecked(excluded)
      line._cb._onToggle = function(_, v)
        local set = GetExcludedSet(activeKey)
        if info._comboHS then
          if v then set[5512] = true; set[224464] = true else set[5512] = nil; set[224464] = nil end
        elseif info._defaultChecked then
          set[info.id] = v and true or false
        elseif info._dedupeIDs then
          for i=1,#info._dedupeIDs do
            local k = info._dedupeIDs[i]
            if v then set[k] = true else set[k] = nil end
          end
        else
          if v then set[info.id] = true else set[info.id] = nil end
        end

        if ns.Exclusions and ns.Exclusions.MarkDirty then ns.Exclusions.MarkDirty() end

        if activeKey == "PETS" and type(ns.Pets_Rebuild) == "function" then
          ns.Pets_Rebuild()
        end

        ApplyNow_NoReload()
        if ns.Exclusions_RefreshNow then ns.Exclusions_RefreshNow(true) end
        NotifyChanged()
      end
    end

    local function updateContentWidth()
      local w = scroll:GetWidth() or 400
      if w < 50 then w = 50 end
      contentFrame:SetWidth(w)
    end
    local function calcNameWidth()
      local w = contentFrame:GetWidth() or (scroll:GetWidth() or 400)
      local used = 6 + ICON_SZ + 6 + 6 + THEME.checkboxBox() + 6
      w = w - used
      if w < 50 then w = 50 end
      return w
    end

    local TAB_DEFS = {
      { key="FOOD",            label="Food" },
      { key="FOOD_HEARTY",     label="Hearty Food" },
      { key="FLASK",           label="Flasks" },
      { key="AUGMENT_RUNE",    label="Augment Runes" },
      { key="WEAPON_ENCHANTS", label="Weapon Enchants" },

      { key="CLASS_ABILITIES", label="Class Abilities" },
      { key="PETS",            label="Pets" },
      { key="TRINKET_RB",      label="Trinkets" },
      { key="UTILITY",         label="Utility" },
      { key="COSMETICS",       label="Cosmetics" },
    }
    local rowAKeys = { "FOOD","FOOD_HEARTY","FLASK","AUGMENT_RUNE","WEAPON_ENCHANTS" }
    local rowBKeys = { "CLASS_ABILITIES","PETS","TRINKET_RB","UTILITY","COSMETICS" }

    local tabButtons = {}
    local activeKey = "FOOD"

    local function placeRowButtons(rowFrame, keys)
      local prev
      for _, k in ipairs(keys) do
        local def
        for i=1,#TAB_DEFS do if TAB_DEFS[i].key==k then def=TAB_DEFS[i]; break end end
        local b = MakeMiniTab(rowFrame, def.label)
        tabButtons[k] = b
        if prev then b:SetPoint("LEFT", prev, "RIGHT", THEME.tabGap, 0) else b:SetPoint("LEFT", rowFrame, "LEFT", 0, 0) end
        prev = b
      end
    end
    placeRowButtons(tabRowTop, rowAKeys)
    placeRowButtons(tabRowBot, rowBKeys)

    local function layoutRowFill(rowFrame, keys)
      local avail = tabsArea:GetWidth() or 600
      if avail < 100 then return end
      local totalText = 0
      for _, k in ipairs(keys) do totalText = totalText + (tabButtons[k]._fs:GetStringWidth() or 0) end
      local count, gaps = #keys, (#keys-1) * THEME.tabGap
      local basePads = 0
      for _, k in ipairs(keys) do basePads = basePads + (tabButtons[k]._basePad*2) end
      local leftover = avail - (totalText + gaps + basePads)
      local extraPerSide = (leftover > 0) and (leftover / (count*2)) or 0

      for i, k in ipairs(keys) do
        local b = tabButtons[k]
        local w = (b._fs:GetStringWidth() or 0) + 2*(b._basePad + extraPerSide)
        w = math.max(50, math.floor(w + 0.5))
        b:SetWidth(w)
        b:ClearAllPoints()
        if i == 1 then b:SetPoint("LEFT", rowFrame, "LEFT", 0, 0) else b:SetPoint("LEFT", tabButtons[keys[i-1]], "RIGHT", THEME.tabGap, 0) end
      end
      local last = tabButtons[keys[#keys]]
      last:ClearAllPoints()
      local prev = tabButtons[keys[#keys-1]]
      last:SetPoint("LEFT", prev, "RIGHT", THEME.tabGap, 0)
      last:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)
    end

    local function setTabsRowOrder(selectedKey)
      local inA = {}; for _,k in ipairs(rowAKeys) do inA[k]=true end
      local selectedIsA = inA[selectedKey] == true

      if selectedIsA then
        tabRowTop:ClearAllPoints(); tabRowBot:ClearAllPoints()
        tabRowTop:SetPoint("TOPLEFT", tabsArea, "TOPLEFT", 0, 0)
        tabRowTop:SetPoint("TOPRIGHT", tabsArea, "TOPRIGHT", 0, 0)
        tabRowBot:SetPoint("TOPLEFT", tabsArea, "TOPLEFT", 0, -(THEME.tabH + THEME.tabGap))
        tabRowBot:SetPoint("TOPRIGHT", tabsArea, "TOPRIGHT", 0, -(THEME.tabH + THEME.tabGap))
      else
        tabRowTop:ClearAllPoints(); tabRowBot:ClearAllPoints()
        tabRowBot:SetPoint("TOPLEFT", tabsArea, "TOPLEFT", 0, 0)
        tabRowBot:SetPoint("TOPRIGHT", tabsArea, "TOPRIGHT", 0, 0)
        tabRowTop:SetPoint("TOPLEFT", tabsArea, "TOPLEFT", 0, -(THEME.tabH + THEME.tabGap))
        tabRowTop:SetPoint("TOPRIGHT", tabsArea, "TOPRIGHT", 0, -(THEME.tabH + THEME.tabGap))
      end

      layoutRowFill(tabRowTop, rowAKeys)
      layoutRowFill(tabRowBot, rowBKeys)
    end

    local function collectForTab(tabKey)
      if tabKey == "FOOD" or tabKey == "FOOD_HEARTY" then
        local src = getCategorySource("FOOD"); if type(src) ~= "table" then return {} end
        local plain, hearty = {}, {}
        for id, v in pairs(src) do
          if type(id) == "number" then
            local entry = { id=id, isItem=true, name=(type(v)=="table" and v.name) or tostring(v), rank=(type(v)=="table" and v.rank) or nil, icon=(type(v)=="table" and v.icon) or select(1, GetItemIconSafe(id)) }
            local heartyFlag = false
            if type(v)=="table" then
              heartyFlag = (v.hearty == true)
                or (type(v.topLbl)=="string" and v.topLbl:lower():find("hearty",1,true))
                or (type(v.btmLbl)=="string" and v.btmLbl:lower():find("hearty",1,true))
                or (v.foodType=="hearty" or v.kind=="hearty")
            end
            if heartyFlag then hearty[#hearty+1]=entry else plain[#plain+1]=entry end
          end
        end
        sortItems(plain); sortItems(hearty)
        if tabKey == "FOOD"        then return { { label="Food",        items=plain  } } end
        if tabKey == "FOOD_HEARTY" then return { { label="Hearty Food", items=hearty } } end
        return {}

      elseif tabKey == "FLASK" then
        local src = getCategorySource("FLASK") or {}
        local normal, fleeting = {}, {}
        for id, v in pairs(src) do
          if type(id) == "number" then
            local name  = (type(v)=="table" and v.name) or tostring(v)
            local rank  = (type(v)=="table" and v.rank) or nil
            local icon  = (type(v)=="table" and v.icon) or select(1, GetItemIconSafe(id))
            local isFleeting = false
            if type(v)=="table" then
              isFleeting = (v.fleeting == true)
                or (type(v.topLbl)=="string" and v.topLbl:lower():find("fleeting",1,true))
                or (type(v.btmLbl)=="string" and v.btmLbl:lower():find("fleeting",1,true))
                or (v.kind=="fleeting" or v.flaskType=="fleeting")
            end
            local entry = { id=id, isItem=true, name=name, rank=rank, icon=icon, fleeting=isFleeting }
            if isFleeting then fleeting[#fleeting+1]=entry else normal[#normal+1]=entry end
          end
        end
        sortItems(normal); sortItems(fleeting)
        local blocks = {}
        if #normal   > 0 then blocks[#blocks+1] = { label = "Flasks",          items = normal   } end
        if #fleeting > 0 then blocks[#blocks+1] = { label = "Fleeting Flasks", items = fleeting } end
        return blocks

      elseif tabKey == "AUGMENT_RUNE" then
        local src = getCategorySource("AUGMENT_RUNE") or {}
        return { { label = "Augment Runes", items = flattenItems(src) } }

      elseif tabKey == "WEAPON_ENCHANTS" then
        local mhSrc  = getCategorySource("MAIN_HAND") or {}
        local ohSrc  = getCategorySource("OFF_HAND") or {}

        local combined = {}
        local seen = {}
        local function addFrom(src)
          for id, v in pairs(src) do
            if type(id)=="number" then
              if not seen[id] then
                seen[id] = true
                local name  = (type(v)=="table" and v.name) or tostring(v)
                local rank  = (type(v)=="table" and v.rank) or nil
                local icon  = (type(v)=="table" and v.icon) or select(1, GetItemIconSafe(id))
                combined[#combined+1] = { id=id, isItem=true, name=name, rank=rank, icon=icon }
              end
            end
          end
        end
        addFrom(mhSrc); addFrom(ohSrc)
        sortItems(combined)
        local idxBW; for i=1,#combined do if (combined[i].name or ""):lower() == "bubbling wax" then idxBW = i; break end end
        if idxBW then local bw = table.remove(combined, idxBW); combined[#combined+1] = bw end
        return { { label="Weapon Enchants", items=combined } }

      elseif tabKey == "PETS" then
        local blocks = {}

        local hunterItems = {
          { id = -7001, isItem = false, name = "Hunter Pets", icon = 132161, tipSpellID = 883 },
          { id = 982,   isItem = false, spellID = 982, name = (C_Spell.GetSpellInfo and (C_Spell.GetSpellInfo(982) or {}).name) or "Revive Pet", icon = select(1, GetSpellIconSafe(982)) },
        }
        sortItems(hunterItems)
        blocks[#blocks+1] = { label = "Hunter", items = hunterItems }

        do
          local sid = 46584
          local nm  = (C_Spell.GetSpellInfo and (C_Spell.GetSpellInfo(sid) or {}).name) or tostring(sid)
          local dkItems = { { id = sid, isItem = false, spellID = sid, name = nm, icon = select(1, GetSpellIconSafe(sid)) } }
          sortItems(dkItems)
          blocks[#blocks+1] = { label = "Death Knight", items = dkItems }
        end

        local warlockSpells = { 688, 697, 691, 366222, 30146 }
        local wlItems = {}
        for _, sid in ipairs(warlockSpells) do
          local nm = (C_Spell.GetSpellInfo and (C_Spell.GetSpellInfo(sid) or {}).name) or tostring(sid)
          wlItems[#wlItems+1] = { id = sid, isItem = false, spellID = sid, name = nm, icon = select(1, GetSpellIconSafe(sid)) }
        end
        sortItems(wlItems)
        blocks[#blocks+1] = { label = "Warlock", items = wlItems }

        return blocks

      elseif tabKey == "CLASS_ABILITIES" then
        return collectClassAbilitiesByClass()

      elseif tabKey == "TRINKET_RB" then
        return collectTrinketRaidBuffs()

      elseif tabKey == "UTILITY" then
        local items = {
          { id = -9101, isItem = true,  name = "Durability",       icon = 136241, noTooltip = true },
          { id = -9103, isItem = false, name = "Runeforge Missing", icon = 135766, spellID = 50977 },
        }
        sortItems(items)
        return { { label = "Utility", items = items } }

      elseif tabKey == "COSMETICS" then
        local src = getCategorySource("COSMETIC") or {}
        local items = flattenItems(src)
        for i=1,#items do items[i]._defaultChecked = true end
        return { { label = "Cosmetics", items = items } }
      end
      return {}
    end

    local function rebuildList(activeKeyForList)
      clearHeaders()
      updateContentWidth()

      local blocks = collectForTab(activeKeyForList)
      local y, iLine = 2, 0
      local nameW = calcNameWidth()

      for i = 1, #blocks do
        local block = blocks[i]
        local _, y2 = makeHeader(y, block.label, block.items, activeKeyForList); y = y2
        for j = 1, #block.items do
          iLine = iLine + 1
          local line = lines[iLine] or makeLine(iLine)
          line:ClearAllPoints()
          line:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -y)
          line:SetPoint("RIGHT",   contentFrame, "RIGHT",   0, 0)
          line:Show()
          configureLine(line, block.items[j], nameW, activeKeyForList)
          y = y + ROW_H + 4
        end
      end
      for k = iLine + 1, #lines do lines[k]:Hide() end

      contentFrame:SetHeight(math.max(1, y))
      scroll:UpdateScrollChildRect()
      if bar and bar.UpdateThumb then bar:UpdateThumb(scroll:GetHeight(), contentFrame:GetHeight()) end
    end

    local function selectTab(key)
      activeKey = key
      for k, b in pairs(tabButtons) do if k == key then StyleTabSelected(b) else StyleTabNormal(b) end end
      setTabsRowOrder(key)
      ResetScrollToTop()
      rebuildList(key)
      ResetScrollToTop()
    end

    local function attachButtons(keys)
      for _, k in ipairs(keys) do
        local b = tabButtons[k]
        if b then b:SetScript("OnClick", function() selectTab(k) end) end
      end
    end
    attachButtons(rowAKeys)
    attachButtons(rowBKeys)

    card:SetScript("OnShow", function()
      setTabsRowOrder(activeKey or "FOOD")
      selectTab(activeKey or "FOOD")
    end)

    tabsArea:HookScript("OnSizeChanged", function()
      setTabsRowOrder(activeKey or "FOOD")
    end)

    scroll:HookScript("OnSizeChanged", function()
      C_Timer.After(0, function()
        updateContentWidth()
        local nameW = calcNameWidth()
        for i = 1, #lines do if lines[i] and lines[i]._name then lines[i]._name:SetWidth(nameW) end end
        if bar and bar.UpdateThumb then bar:UpdateThumb(scroll:GetHeight(), contentFrame:GetHeight()) end
      end)
    end)

    ns.Exclusions_RefreshNow = function(keepScroll)
      if card:IsShown() then
        setTabsRowOrder(activeKey)
        rebuildList(activeKey)
        if not keepScroll then ResetScrollToTop() end
      end
    end
  end)
end)

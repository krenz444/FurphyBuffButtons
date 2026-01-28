-- ====================================
-- \Options\Tabs\Layout_Tab.lua
-- ====================================
-- This file creates the "Layout" tab in the options panel, allowing users to configure
-- the visual layout, ordering, and appearance of the addon's icons.

local addonName, ns = ...
ns.Options        = ns.Options        or {}
ns.OptionElements = ns.OptionElements or {}
ns.NumberSelect   = ns.NumberSelect   or {}
ns.ScrollBar      = ns.ScrollBar      or {}

local O   = ns.Options
local OE  = ns.OptionElements
local NS  = ns.NumberSelect
local SB  = ns.ScrollBar

local SCROLLBAR_X_OFFSET   = 0
local SCROLLBAR_WIDTH      = 14
local SCROLLBAR_INSET_PAD  = 5

local function DB() return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {} end

-- Syncs center text color keys if they differ.
local function SyncCenterColorKeys()
  local d = DB(); if type(d) ~= "table" then return end
  local src = d.timerTextColor or d.centerTextColor
  if not src then return end
  local r,g,b,a = src.r or 1, src.g or 1, src.b or 1, (src.a ~= nil and src.a or 1)
  d.timerTextColor  = { r=r, g=g, b=b, a=a }
  d.centerTextColor = { r=r, g=g, b=b, a=a }
end

-- Applies all font settings from the database.
local function ApplyAllFonts()
  local d = DB()
  local top    = d.topSize    or (O.GetDefault and O.GetDefault("topSize"))
  local bottom = d.bottomSize or (O.GetDefault and O.GetDefault("bottomSize"))
  local center = d.timerSize  or (O.GetDefault and O.GetDefault("timerSize"))
  local fname  = d.fontName   or (O.GetDefault and O.GetDefault("fontName"))
  local topOutline    = (d.topOutline    ~= nil) and d.topOutline    or (O.GetDefault and O.GetDefault("topOutline"))
  local bottomOutline = (d.bottomOutline ~= nil) and d.bottomOutline or (O.GetDefault and O.GetDefault("bottomOutline"))
  local timerOutline  = (d.timerOutline  ~= nil) and d.timerOutline  or (O.GetDefault and O.GetDefault("timerOutline"))

  if ns.SetFontName     then ns.SetFontName(fname) end
  if ns.SetFontSizes    then ns.SetFontSizes(top, bottom, center) end
  if ns.SetFontOutlines then ns.SetFontOutlines(topOutline, bottomOutline, timerOutline) end
  if ns.RefreshFonts    then ns.RefreshFonts() end
end

-- Applies glow settings from the database.
local function ApplyGlowFromDB()
  if ns.RefreshGlow then ns.RefreshGlow()
  elseif ns.RenderAll then ns.RenderAll() end
end

-- Applies text colors.
local function ApplyTextColors()
  if ns.RefreshFonts then ns.RefreshFonts()
  elseif ns.RenderAll then ns.RenderAll() end
end

-- Applies all fonts while preserving the center text color.
local function ApplyAllFontsPreservingCenterColor()
  local d = DB()
  local c = d.centerTextColor or d.timerTextColor
  local r,g,b,a
  if type(c) == "table" then
    r = c.r or 1; g = c.g or 1; b = c.b or 1; a = (c.a ~= nil and c.a or 1)
  end

  if r then
    d.timerTextColor  = { r=r, g=g, b=b, a=a }
    d.centerTextColor = { r=r, g=g, b=b, a=a }
    if ns.RenderAll then ns.RenderAll() elseif ns.RefreshFonts then ns.RefreshFonts() end
  end

  ApplyAllFonts()
end

local POPUP_KEY = "CRB_CONFIRM_RESET_APPEAR"
if not StaticPopupDialogs[POPUP_KEY] then
  StaticPopupDialogs[POPUP_KEY] = {
    text = "%s",
    button1 = YES, button2 = NO,
    OnAccept = function(self, data) if data and data.run then data.run() end end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
  }
end
-- Shows a confirmation popup for resetting appearance settings.
local function ConfirmReset(run, what)
  if O and O.ConfirmReset then return O.ConfirmReset(run, what) end
  local msg = "Reset "..(what or "setting").." to default?"
  StaticPopup_Show(POPUP_KEY, msg, nil, { run = run })
end

local GLOW_CHECKBOX_YOFFSET = (O and O.GLOW_CHECKBOX_YOFFSET) or -8
local ROW_H_TOP = 90

-- Hides the default page header to allow custom layout.
local function HidePageHeader(content)
  local page = content and content.GetParent and content:GetParent()
  if not page then return end
  for _, reg in ipairs{ page:GetRegions() } do
    if reg and reg.GetObjectType and reg:GetObjectType()=="FontString" then reg:Hide() end
  end
end

local ORDER_KNOBS = {
  ROW_TOP_PAD      = 10,
  BOX_PAD_L        = 6,
  BOX_PAD_R        = 6,
  GRID_COLS        = 6,
  GRID_GAP         = 5,
  CELL_HEIGHT_RATIO= 0.75,
  HEADER_TOP_PAD   = 48,
  BOTTOM_PAD       = 8,
  TITLE_TOP_OFFSET = 12,
  MIN_CONTENT_W    = 300,
  MIN_CELL_W       = 64,
}

local CATEGORY_LABELS = {
  EATING="Eating", FOOD="Food", FLASK="Flask", MAIN_HAND="Main Hand", OFF_HAND="Off Hand",
  CASTABLE_WEAPON_ENCHANTS="Castable Weapon Enchants", DK_WEAPON_ENCHANTS="DK Enchants",
  ROGUE_POISONS="Poisons", AUGMENT_RUNE="Runes", RAID_BUFFS="Raid Buffs",
  SHAMAN_SHIELDS="Shaman Shields", PETS="Pets", DURABILITY="Durability",
  HEALTHSTONE="Healthstone", COSMETIC="COSMETIC",
  TRINKETS="Trinkets",
}

local ORDER_GROUPS = {
  RAIDBUFFS_GROUP      = { label = "Raid Buffs",      cats = { "RAID_BUFFS", "ROGUE_POISONS", "CASTABLE_WEAPON_ENCHANTS", "SHAMAN_SHIELDS" } },
  FOOD_GROUP           = { label = "Food",            cats = { "EATING", "FOOD" } },
  WEP_ENCH_GROUP       = { label = "Weapon Enchants", cats = { "MAIN_HAND", "OFF_HAND" } },
  FLASK_GROUP          = { label = "Flasks",          cats = { "FLASK" } },
  UTILITY_GROUP        = { label = "Utility",         cats = { "DK_WEAPON_ENCHANTS", "DURABILITY", "HEALTHSTONE" } },
  RUNES_GROUP          = { label = "Augment Runes",   cats = { "AUGMENT_RUNE" } },
  PETS_GROUP           = { label = "Pets",            cats = { "PETS" } },
  COSMETIC_GROUP       = { label = "Cosmetic",        cats = { "COSMETIC" } },
  TRINKETS_GROUP       = { label = "Trinkets",        cats = { "TRINKETS" } },
}

local function _order_catToGroup(cat) for gid, def in pairs(ORDER_GROUPS) do for _, c in ipairs(def.cats) do if c == cat then return gid end end end return cat end
local function _order_expandGroup(gid, out) local g = ORDER_GROUPS[gid]; if g then for _, c in ipairs(g.cats) do out[#out+1] = c end else out[#out+1] = gid end end
local function _order_NormalizeOrder(saved, defaults) local seen, out = {}, {}; if type(saved)=="table" then for i=1,#saved do local c=tostring(saved[i]); if not seen[c] then seen[c]=true; out[#out+1]=c end end end; for i=1,#defaults do local c=defaults[i]; if not seen[c] then seen[c]=true; out[#out+1]=c end end; return out end
local function _order_ToGroupedOrder(catOrder) local seen, gout = {}, {}; for _, c in ipairs(catOrder) do local gid=_order_catToGroup(c); if not seen[gid] then seen[gid]=true; gout[#gout+1]=gid end end; return gout end
local function _order_SaveGroupedOrder(gorder)
  local out = {}; for _, gid in ipairs(gorder) do _order_expandGroup(gid, out) end
  DB().categoryOrder = out
  if ns.SetCategoryOrder then ns.SetCategoryOrder(out) end
  if ns.RequestRebuild then ns.RequestRebuild() end
end
local function _order_groupText(gid)
  local g = ORDER_GROUPS[gid]
  if g and g.label then return g.label end
  if not g then return CATEGORY_LABELS[gid] or gid end
  local ex = {}; for _, c in ipairs(g.cats) do ex[#ex+1] = (CATEGORY_LABELS[c] or c) end
  return table.concat(ex, " + ")
end

-- Builds the "Icon Order" section with drag-and-drop functionality.
local function BuildOrderSection(content, Row)
  local K = ORDER_KNOBS

  local def = (ns.GetCategoryOrderDefaults and ns.GetCategoryOrderDefaults()) or ORDER_DEFAULTS
  if not def or type(def) ~= "table" then
    def = {}
    local orderedGroups = {
      "RAIDBUFFS_GROUP","FOOD_GROUP","WEP_ENCH_GROUP","FLASK_GROUP",
      "UTILITY_GROUP","RUNES_GROUP","PETS_GROUP","COSMETIC_GROUP","TRINKETS_GROUP",
    }
    for _, gid in ipairs(orderedGroups) do _order_expandGroup(gid, def) end
  end
  local seenRT = false; for i=1,#def do if def[i] == "TRINKETS" then seenRT = true break end end
  if not seenRT then def[#def+1] = "TRINKETS" end
  if not DB().categoryOrder then DB().categoryOrder = def end

  local defaults = (ns.GetCategoryOrderDefaults and ns.GetCategoryOrderDefaults())
                or (ns.GetCategoryOrder and ns.GetCategoryOrder())
                or def

  local hasRT = false; for i=1,#defaults do if defaults[i] == "TRINKETS" then hasRT = true break end end
  if not hasRT then defaults[#defaults+1] = "TRINKETS" end

  local atomicOrder = _order_NormalizeOrder(DB().categoryOrder, defaults)
  local gorder      = _order_ToGroupedOrder(atomicOrder)

  local usableW = (content:GetWidth() or 600) - (K.BOX_PAD_L + K.BOX_PAD_R); if usableW < K.MIN_CONTENT_W then usableW = K.MIN_CONTENT_W end
  local initCellW = (usableW - (K.GRID_COLS - 1) * K.GRID_GAP) / K.GRID_COLS; if initCellW < K.MIN_CELL_W then initCellW = K.MIN_CELL_W end
  local CELL_H = initCellW * K.CELL_HEIGHT_RATIO
  local initRows  = math.max(1, math.ceil(#gorder / K.GRID_COLS))
  local initGridH = initRows * CELL_H + (initRows - 1) * K.GRID_GAP

  local row = Row(K.ROW_TOP_PAD + K.HEADER_TOP_PAD + initGridH + K.BOTTOM_PAD)

  local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
  box:SetPoint("TOPLEFT", 0, -K.ROW_TOP_PAD)
  box:SetPoint("BOTTOMRIGHT", 0, 0)
  box:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
  box:SetBackdropColor(0.08,0.09,0.12,1); box:SetBackdropBorderColor(0.20,0.22,0.28,1)

  local title = box:CreateFontString(nil,"ARTWORK","GameFontHighlight")
  local function Face() return (O and O.ResolvePanelFont and O.ResolvePanelFont()) or "Fonts\\FRIZQT__.TTF" end
  local function FS(fs, size, flags) if fs and fs.SetFont then fs:SetFont(Face(), size or (O.SIZE_LABEL or 14), flags or "") end end
  FS(title, O.SIZE_LABEL or 14, "")
  title:SetPoint("TOPLEFT", K.BOX_PAD_L, -K.TITLE_TOP_OFFSET)
  title:SetText("Icon Order")

  if not StaticPopupDialogs["CRB_ORDER_RESET"] then
    StaticPopupDialogs["CRB_ORDER_RESET"] = {
      text = "Reset icon order to defaults?",
      button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
      OnAccept = function(self, data) if data and data.doReset then data.doReset() end end,
    }
  end

  local grid = CreateFrame("Frame", nil, box)
  grid:SetPoint("TOPLEFT", K.BOX_PAD_L, -K.HEADER_TOP_PAD)
  grid:SetPoint("RIGHT", -K.BOX_PAD_R, 0)
  grid:SetHeight(initGridH)

  local widths, xofs = {}, {}
  local tilesByGroup, tileList = {}, {}
  local draggingGid, draggingTile, hoverIdx
  local preview, anims = {}, {}

  local ghost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  ghost:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
  ghost:SetBackdropColor(0.10,0.115,0.16,0.95)
  ghost:SetBackdropBorderColor(0.20,0.22,0.28,1)
  ghost:SetFrameStrata("TOOLTIP")
  ghost.num   = ghost:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  ghost.label = ghost:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  FS(ghost.num, 16, ""); FS(ghost.label, O.SIZE_LABEL or 12, "")
  ghost.num:SetPoint("TOPLEFT", ghost, "TOPLEFT", 4, -4)
  ghost.label:SetPoint("TOPLEFT", ghost, "TOPLEFT", 6, -6)
  ghost.label:SetPoint("BOTTOMRIGHT", ghost, "BOTTOMRIGHT", -6, 6)
  ghost:Hide()

  local function updateGhost()
    if not draggingTile then return end
    local w, h = draggingTile:GetSize()
    ghost:SetSize(w, h)
    local idx = hoverIdx or 0
    ghost.num:SetText(tostring(idx))
    ghost.label:SetText(_order_groupText(draggingGid))
    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition(); cx, cy = cx/scale, cy/scale
    ghost:ClearAllPoints()
    ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
  end

  local function computeGeometry()
    local w
    if grid:GetRight() and grid:GetLeft() then w = grid:GetRight()-grid:GetLeft() else w = (content:GetWidth() or 600) - (K.BOX_PAD_L + K.BOX_PAD_R) end
    if w < K.MIN_CONTENT_W then w = K.MIN_CONTENT_W end
    local totalGaps = (K.GRID_COLS - 1) * K.GRID_GAP
    local base = math.floor((w - totalGaps) / K.GRID_COLS); if base < K.MIN_CELL_W then base = K.MIN_CELL_W end
    local rem = math.floor(w - (base * K.GRID_COLS + totalGaps) + 0.5); if rem < 0 then rem = 0 end

    wipe(widths); wipe(xofs)
    local x = 0
    for c = 1, K.GRID_COLS do
      local add = (rem > 0) and 1 or 0
      local cw = base + add
      widths[c] = cw; xofs[c] = x
      x = x + cw + (c < K.GRID_COLS and K.GRID_GAP or 0)
      if rem > 0 then rem = rem - 1 end
    end

    local CELL_H = math.floor(widths[1] * K.CELL_HEIGHT_RATIO + 0.5)

    local count = #gorder
    local rowsNow = math.max(1, math.ceil(count / K.GRID_COLS))
    local gridH = rowsNow * CELL_H + (rowsNow - 1) * K.GRID_GAP
    grid:SetHeight(gridH)
    local total = K.ROW_TOP_PAD + K.HEADER_TOP_PAD + gridH + K.BOTTOM_PAD
    row:SetHeight(total)
  end

  local function indexToRC(i) local r = math.floor((i - 1) / K.GRID_COLS); local c = ((i - 1) % K.GRID_COLS) + 1; return r, c end
  local function coordsForIndex(i) local r, c = indexToRC(i); local x = xofs[c] or 0; local y = -r * (math.floor(widths[1]*K.CELL_HEIGHT_RATIO+0.5) + K.GRID_GAP); return x, y, c end

  local function animateTo(t, tx, ty, dur)
    local p, rel, rp, x, y = t:GetPoint(1)
    if rel ~= grid then
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", grid, "TOPLEFT", tx, ty)
      return
    end
    x, y = x or tx, y or ty
    if math.abs((tx - x)) < 0.5 and math.abs((ty - y)) < 0.5 then
      t:ClearAllPoints(); t:SetPoint("TOPLEFT", grid, "TOPLEFT", tx, ty)
      anims[t] = nil
      return
    end
    local now = GetTime()
    anims[t] = { sx = x, sy = y, tx = tx, ty = ty, t0 = now, dur = dur or 0.10 }
  end

  local function tickAnimations()
    if not next(anims) then return end
    local now = GetTime()
    for t,a in pairs(anims) do
      local f = (now - a.t0) / a.dur
      if f >= 1 then
        t:ClearAllPoints(); t:SetPoint("TOPLEFT", grid, "TOPLEFT", a.tx, a.ty)
        anims[t] = nil
      else
        local u = (f*f*(3-2*f))
        local x = a.sx + (a.tx - a.sx) * u
        local y = a.sy + (a.ty - a.sy) * u
        t:ClearAllPoints(); t:SetPoint("TOPLEFT", grid, "TOPLEFT", x, y)
      end
    end
  end

  local function rebuildPreview(insertIdx)
    wipe(preview)
    if draggingGid then
      local tmp = {}
      for i = 1, #gorder do local gid = gorder[i]; if gid ~= draggingGid then tmp[#tmp+1] = gid end end
      local target = (insertIdx and math.max(1, math.min(#tmp+1, insertIdx))) or 1
      for i=1,target-1 do preview[#preview+1] = tmp[i] end
      preview[#preview+1] = draggingGid
      for i=target,#tmp do preview[#preview+1] = tmp[i] end
    else
      for i=1,#gorder do preview[i] = gorder[i] end
    end
  end

  local function applyPreview(animated)
    for i=1,#preview do
      local gid = preview[i]
      local t = tilesByGroup[gid]
      if t then
        t.num:SetText(tostring(i))
        t.label:SetText(_order_groupText(gid))
        local tx, ty, col = coordsForIndex(i)
        local w = widths[col] or widths[1] or K.MIN_CELL_W
        t:SetSize(w, math.floor(widths[1]*K.CELL_HEIGHT_RATIO+0.5))
        if animated and t ~= draggingTile then
          animateTo(t, tx, ty, 0.10)
        else
          t:ClearAllPoints(); t:SetPoint("TOPLEFT", grid, "TOPLEFT", tx, ty)
        end
      end
    end
  end

  local function cursorToIndex()
    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition(); cx, cy = cx / scale, cy / scale
    local left   = grid:GetLeft() or 0
    local top    = grid:GetTop()  or 0
    local lx = cx - left
    local ly = top - cy

    local col, accum = 1, 0
    for c=1,K.GRID_COLS do
      local w = widths[c] or 0
      if lx <= accum + w + (c < K.GRID_COLS and K.GRID_GAP or 0) then col = c; break end
      accum = accum + w + (c < K.GRID_COLS and K.GRID_GAP or 0)
    end

    local CELL_H = math.floor(widths[1]*K.CELL_HEIGHT_RATIO+0.5)
    local rowIdx = math.floor(ly / (CELL_H + K.GRID_GAP)) + 1
    if rowIdx < 1 then rowIdx = 1 end
    local maxRows = math.max(1, math.ceil(#gorder / K.GRID_COLS))
    if rowIdx > maxRows then rowIdx = maxRows end

    local idx = (rowIdx - 1) * K.GRID_COLS + col
    if idx > #gorder then idx = #gorder end
    if idx < 1 then idx = 1 end
    return idx
  end

  local function makeTile(gid)
    local t = CreateFrame("Button", nil, grid, "BackdropTemplate")
    t.groupId = gid
    t:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    t:SetBackdropColor(0.10,0.115,0.16,1)
    t:SetBackdropBorderColor(0.20,0.22,0.28,1)

    t.num   = t:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    t.label = t:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    local function FS2(fs, size, flags)
      if fs and fs.SetFont then
        local Face = (O and O.ResolvePanelFont and O.ResolvePanelFont()) or "Fonts\\FRIZQT__.TTF"
        fs:SetFont(Face, size or (O.SIZE_LABEL or 14), flags or "")
      end
    end
    FS2(t.num, 16, ""); t.num:SetPoint("TOPLEFT", t, "TOPLEFT", 4, -4)
    FS2(t.label, O.SIZE_LABEL or 12, ""); t.label:SetPoint("TOPLEFT", t, "TOPLEFT", 6, -6); t.label:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -6, 6)
    t.label:SetJustifyH("CENTER"); t.label:SetJustifyV("MIDDLE"); if t.label.SetNonSpaceWrap then t.label:SetNonSpaceWrap(true) end; if t.label.SetMaxLines then t.label:SetMaxLines(3) end

    t:SetSize((widths[1] or K.MIN_CELL_W), math.floor((widths[1] or K.MIN_CELL_W) * K.CELL_HEIGHT_RATIO + 0.5))

    t:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(_order_groupText(self.groupId), 1, 0.82, 0)
      GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)

    t:RegisterForDrag("LeftButton")
    t:SetScript("OnDragStart", function(self)
      draggingGid = self.groupId
      draggingTile = self
      self:SetAlpha(0.05)
      ghost:Show()
      hoverIdx = cursorToIndex()
      rebuildPreview(hoverIdx)
      applyPreview(true)
    end)
    t:SetScript("OnDragStop", function(self)
      if draggingTile ~= self then return end
      self:SetAlpha(1)
      ghost:Hide()
      local newOrder = {}
      for i=1,#preview do newOrder[i] = preview[i] end
      gorder = newOrder
      _order_SaveGroupedOrder(newOrder)
      draggingGid, draggingTile, hoverIdx = nil, nil, nil
      rebuildPreview(nil)
      applyPreview(false)
    end)

    return t
  end

  local function clearTiles()
    if tileList then
      for i = #tileList, 1, -1 do
        local t = tileList[i]
        anims[t] = nil
        t:Hide()
        t:SetParent(nil)
        tileList[i] = nil
      end
    end
    wipe(tilesByGroup)
    wipe(preview)
    draggingGid, draggingTile, hoverIdx = nil, nil, nil
    ghost:Hide()
  end

  local function buildTiles()
    clearTiles()
    for i = 1, #gorder do
      local gid = gorder[i]
      local t = makeTile(gid)
      tilesByGroup[gid] = t
      tileList[#tileList+1] = t
    end
    computeGeometry()
    rebuildPreview(nil)
    applyPreview(false)
  end

  grid:HookScript("OnSizeChanged", function()
    computeGeometry()
    rebuildPreview(hoverIdx)
    applyPreview(false)
  end)

  grid:SetScript("OnUpdate", function()
    if draggingTile then
      local idx = cursorToIndex()
      if idx ~= hoverIdx then
        hoverIdx = idx
        rebuildPreview(hoverIdx)
        applyPreview(true)
      end
      updateGhost()
    end
    tickAnimations()
  end)

  local function doReset()
    local defR = (ns.GetCategoryOrderDefaults and ns.GetCategoryOrderDefaults()) or def
    local hasRT2 = false; for i=1,#defR do if defR[i] == "TRINKETS" then hasRT2 = true break end end
    if not hasRT2 then defR[#defR+1] = "TRINKETS" end

    local gorderNew = _order_ToGroupedOrder(defR)
    gorder = gorderNew
    _order_SaveGroupedOrder(gorderNew)
    buildTiles()
  end
  local reset = OE.AttachResetTo(box, "BOTTOMRIGHT", box, "BOTTOMRIGHT", -10, 10, function()
    StaticPopup_Show("CRB_ORDER_RESET", nil, nil, { doReset = doReset })
  end); reset:Show()

  box._buildTiles = function() buildTiles() end
  box._reflow     = function() computeGeometry(); rebuildPreview(hoverIdx); applyPreview(false) end

  buildTiles()
end

local KNOB = {
  ROW_H_TOP        = 90,
  ROW_H_TOGGLES    = 36,
  BTN_H            = 28,
  BTN_MIN_W        = 168,
  BTN_GAP          = 8,
  ICON_MIN         = 24,   ICON_MAX = 128, ICON_STEP = 1,
  MAXROW_MIN       = 1,    MAXROW_MAX = 40, MAXROW_STEP = 1,
  SPACE_MIN        = 0,    SPACE_MAX = 50,  SPACE_STEP = 1,
}
local BORDER_SEL = {0.32,0.80,0.90,1}
local BORDER_NRM = {0.22,0.24,0.30,1}
local BG_NRM     = {0.10,0.11,0.15,1}
local BG_SEL     = {0.14,0.15,0.20,1}
local TXT_NRM    = {0.85,0.90,1.00,1}
local TXT_SEL    = {1,1,1,1}

local function _Face() return (O and O.ResolvePanelFont and O.ResolvePanelFont()) or "Fonts\\FRIZQT__.TTF" end
local function _SetFS(fs, size, flags) if fs and fs.SetFont then fs:SetFont(_Face(), size or (O.SIZE_LABEL or 14), flags or "") end end

local function _NewSelButton(parent, text)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetHeight(KNOB.BTN_H)
  b:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
  b:SetBackdropColor(unpack(BG_NRM))
  b:SetBackdropBorderColor(unpack(BORDER_NRM))
  b.txt = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  b.txt:SetPoint("CENTER")
  _SetFS(b.txt, O.SIZE_LABEL or 14, "")
  b.txt:SetText(text or "")
  function b:SetSelected(on)
    if on then
      self:SetBackdropColor(unpack(BG_SEL))
      self:SetBackdropBorderColor(unpack(BORDER_SEL))
      self.txt:SetTextColor(unpack(TXT_SEL))
    else
      self:SetBackdropColor(unpack(BG_NRM))
      self:SetBackdropBorderColor(unpack(BORDER_NRM))
      self.txt:SetTextColor(unpack(TXT_NRM))
    end
  end
  return b
end

local function _MakeButtonRow(parent, labels, onPick, getKey)
  local row = CreateFrame("Frame", nil, parent)
  row:SetAllPoints()
  local buttons, order = {}, {}

  local function visibleCount() local n=0; for i=1,#order do if order[i] then n=n+1 end end; return n end
  local function placeButtons()
    local count = visibleCount(); if count==0 then return end
    local w = math.max(KNOB.BTN_MIN_W, (row:GetWidth() or 480) / count - KNOB.BTN_GAP)
    local prev
    for i=1,#order do
      local key = order[i]
      if key then
        local b = buttons[key]
        if b then
          b:SetWidth(w)
          b:ClearAllPoints()
          if not prev then b:SetPoint("LEFT", row, "LEFT", 0, 0) else b:SetPoint("LEFT", prev, "RIGHT", KNOB.BTN_GAP, 0) end
          b:Show()
          prev = b
        end
      end
    end
  end

  function row:SetLabels(newLabels)
    wipe(order)
    local present = {}
    for i=1,#newLabels do
      local key  = newLabels[i].key
      local text = newLabels[i].text
      local b = buttons[key]
      if not b then
        b = _NewSelButton(row, text)
        buttons[key] = b
      else
        b.txt:SetText(text)
      end
      local thisKey = key
      b:SetScript("OnClick", function()
        for k, ob in pairs(buttons) do ob:SetSelected(k == thisKey) end
        if onPick then onPick(thisKey) end
      end)
      b:SetSelected(false); b:Show()
      order[#order+1] = key
      present[key] = true
    end
    for k, b in pairs(buttons) do if not present[k] then b:Hide(); b:SetSelected(false) end end
    placeButtons()
    if row.Refresh then row:Refresh() end
  end

  row:HookScript("OnSizeChanged", placeButtons)
  function row:Refresh()
    local cur = getKey and getKey() or nil
    for k, b in pairs(buttons) do b:SetSelected(cur and (k == cur) or false) end
  end

  row:SetLabels(labels)
  return row
end

local function BuildLayoutSection(content, Row)
  local d = DB()
  if d.iconSize     == nil then d.iconSize     = 50 end
  if d.maxPerRow    == nil then d.maxPerRow    = 7  end
  if d.useMaxPerRow == nil then d.useMaxPerRow = false end
  if d.hSpace       == nil then d.hSpace       = 10 end
  if d.vSpace       == nil then d.vSpace       = 35 end
  if d.style        == nil then d.style        = "HORIZONTAL" end
  if d.alignment    == nil then d.alignment    = "CENTER" end
  if d.growV        == nil then d.growV        = "DOWN" end
  if d.growH        == nil then d.growH        = "RIGHT" end
  if d.gridLTR      == nil then d.gridLTR      = true end

  local rowA = Row(KNOB.ROW_H_TOP)
  do
    local left = CreateFrame("Frame", nil, rowA)
    left:SetPoint("LEFT"); left:SetPoint("RIGHT", rowA, "CENTER")
    left:SetPoint("TOP");  left:SetPoint("BOTTOM")
    local ns1 = NS.Create(left, {
      label = "Icon Size",
      min = KNOB.ICON_MIN, max = KNOB.ICON_MAX, step = KNOB.ICON_STEP,
      value = d.iconSize, default = 50,
      onChange = function(v) d.iconSize = v; if ns.RequestRebuild then ns.RequestRebuild() end end,
    })
    ns1:SetPoint("CENTER")
  end
  do
    local right = CreateFrame("Frame", nil, rowA)
    right:SetPoint("LEFT", rowA, "CENTER"); right:SetPoint("RIGHT")
    right:SetPoint("TOP"); right:SetPoint("BOTTOM")
    local holder = CreateFrame("Frame", nil, right); holder:SetAllPoints()

    local cb = CreateFrame("CheckButton", nil, holder, "BackdropTemplate")
    cb:SetSize(20,20)
    cb:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    cb:SetBackdropColor(0.05,0.06,0.08,1)
    cb:SetBackdropBorderColor(unpack(BORDER_NRM))
    local tick = cb:CreateTexture(nil, "ARTWORK")
    tick:SetAtlas("common-icon-checkmark", true)
    tick:SetPoint("CENTER"); tick:SetSize(16,16); tick:SetVertexColor(0.35,0.80,1,1)
    cb._tick = tick

    local ns2 = NS.Create(holder, {
      label = "Max Icons Per Tier",
      min = KNOB.MAXROW_MIN, max = KNOB.MAXROW_MAX, step = KNOB.MAXROW_STEP,
      value = d.maxPerRow or 7, default = 7,
      onChange = function(v)
        d.maxPerRow = v; d.maxPerTier = v
        if ns.RequestRebuild then ns.RequestRebuild() end
      end,
    })
    ns2:SetPoint("CENTER", holder, "CENTER", 20, 0)
    cb:SetPoint("RIGHT", ns2, "LEFT", -12, 0)

    local function applyUseMax(on)
      d.useMaxPerRow = on and true or false
      d.layoutMode = d.useMaxPerRow and "GRID" or "ROW"
      ns2:SetEnabled(d.useMaxPerRow)
      if ns.RequestRebuild then ns.RequestRebuild() end
    end

    cb:SetChecked(d.useMaxPerRow and true or false); cb._tick:SetShown(d.useMaxPerRow and true or false)
    cb:SetScript("OnClick", function(self)
      local on = not not self:GetChecked()
      self._tick:SetShown(on); applyUseMax(on)
    end)
    applyUseMax(d.useMaxPerRow)
  end

  local rowB = Row(KNOB.ROW_H_TOP)
  do
    local left = CreateFrame("Frame", nil, rowB)
    left:SetPoint("LEFT"); left:SetPoint("RIGHT", rowB, "CENTER")
    left:SetPoint("TOP"); left:SetPoint("BOTTOM")
    local ns3 = NS.Create(left, {
      label = "Horizontal Spacing",
      min = KNOB.SPACE_MIN, max = KNOB.SPACE_MAX, step = KNOB.SPACE_STEP,
      value = d.hSpace or 10, default = 10,
      onChange = function(v) d.hSpace = v; if ns.RequestRebuild then ns.RequestRebuild() end end,
    })
    ns3:SetPoint("CENTER")
  end
  do
    local right = CreateFrame("Frame", nil, rowB)
    right:SetPoint("LEFT", rowB, "CENTER"); right:SetPoint("RIGHT")
    right:SetPoint("TOP"); right:SetPoint("BOTTOM")
    local ns4 = NS.Create(right, {
      label = "Vertical Spacing",
      min = KNOB.SPACE_MIN, max = KNOB.SPACE_MAX, step = KNOB.SPACE_STEP,
      value = d.vSpace or 45, default = 45,
      onChange = function(v) d.vSpace = v; if ns.RequestRebuild then ns.RequestRebuild() end end,
    })
    ns4:SetPoint("CENTER")
  end

  Row(12)

  local rowStyle = Row(KNOB.ROW_H_TOGGLES)
  local styleRow = _MakeButtonRow(rowStyle, {
    { key="HORIZONTAL", text="Horizontal Tiers" },
    { key="VERTICAL",   text="Vertical Tiers"   },
  }, function(key)
    d.style = key
    if ns.RequestRebuild then ns.RequestRebuild() end
    if content and content.RefreshSelectors then content:RefreshSelectors() end
  end, function() return (DB().style or "HORIZONTAL") end)

  local rowAlign = Row(KNOB.ROW_H_TOGGLES)
  local alignLabelsH = {
    { key="LEFT",   text="Left Align"   },
    { key="CENTER", text="Center Align" },
    { key="RIGHT",  text="Right Align"  },
  }
  local alignLabelsV = {
    { key="LEFT",   text="Top"    },
    { key="CENTER", text="Center" },
    { key="RIGHT",  text="Bottom" },
  }
  local alignRow = _MakeButtonRow(rowAlign, alignLabelsH, function(key)
    d.alignment = key
    if ns.RequestRebuild then ns.RequestRebuild() end
  end, function() return (DB().alignment or "CENTER") end)

  local rowGrow = Row(KNOB.ROW_H_TOGGLES)
  local growRow = _MakeButtonRow(rowGrow, {
    { key="UP",   text="Grow Upward"   },
    { key="DOWN", text="Grow Downward" },
  }, function(key)
    if (d.style or "HORIZONTAL") == "VERTICAL" then
      if key == "LEFT" or key == "RIGHT" then
        d.growH  = key
        d.gridLTR = (key == "RIGHT")
      end
    else
      d.growV   = key
      d.gridDown = (key == "DOWN")
    end
    if ns.RequestRebuild then ns.RequestRebuild() end
  end,
  function()
    if (DB().style or "HORIZONTAL") == "VERTICAL" then
      local gh = DB().growH
      if gh == "LEFT" or gh == "RIGHT" then
        return gh
      else
        return (DB().gridLTR == false) and "LEFT" or "RIGHT"
      end
    else
      return (DB().growV or "DOWN")
    end
  end)

  function content:RefreshSelectors()
    local curStyle = DB().style or "HORIZONTAL"
    if curStyle == "VERTICAL" then
      alignRow:SetLabels(alignLabelsV)
      growRow:SetLabels({
        { key="LEFT",  text="Grow Left"  },
        { key="RIGHT", text="Grow Right" },
      })
    else
      alignRow:SetLabels(alignLabelsH)
      growRow:SetLabels({
        { key="UP",   text="Grow Upward"   },
        { key="DOWN", text="Grow Downward" },
      })
    end
    styleRow:Refresh(); alignRow:Refresh(); growRow:Refresh()
  end

  content:HookScript("OnShow", function() content:RefreshSelectors() end)
end

local function BuildAppearanceSection(content, Row)
  local bounds = {
    tMin=O.SIZE_TOP_MIN or 8,     tMax=O.SIZE_TOP_MAX or 48,
    bMin=O.SIZE_BOTTOM_MIN or 8,  bMax=O.SIZE_BOTTOM_MAX or 48,
    cMin=O.SIZE_CENTER_MIN or 8,  cMax=O.SIZE_CENTER_MAX or 64,
  }

  local function BuildAppearanceMap()
    return {
      { type="font",       key="fontName",         label="Font",                col=1, span=2, rowH=72 },
      { type="numsel",     key="topSize",          label="Top Text Size",       min=bounds.tMin, max=bounds.tMax, step=1, col=1, span=1, rowH=ROW_H_TOP },
      { type="color",      key="topTextColor",     label="Top Text Color",      which="top",    col=1, span=1 },

      { type="blank",      col=1, span=3, rowH=16 },

      { type="checkbox",   key="glowEnabled",      label="Enable Icon Glow",    col=1, span=1, rowH=60, centerBelow=true, noReset=true, yOffset=GLOW_CHECKBOX_YOFFSET },

      { type="numsel",     key="timerSize",        label="Center Text Size",    min=bounds.cMin, max=bounds.cMax, step=1, col=2, span=1, rowH=ROW_H_TOP },
      { type="color",      key="timerTextColor",   label="Center Text Color",   which="center", col=2, span=1 },

      { type="color",      key="glowColor",        label="General Glow Color",  col=2, span=1 },

      { type="blank",      col=3, span=1, rowH=16 },
      { type="numsel",     key="bottomSize",       label="Bottom Text Size",    min=bounds.bMin, max=bounds.bMax, step=1, col=3, span=1, rowH=ROW_H_TOP },
      { type="color",      key="bottomTextColor",  label="Bottom Text Color",   which="bottom", col=3, span=1 },
      { type="color",      key="specialGlowColor", label="Special Glow Color",  col=3, span=1 },
    }
  end

  local function AddNumberSelectCell(UI, spec)
    local d = DB()
    local key  = spec.key
    local minV = spec.min or 0
    local maxV = spec.max or 100
    local step = spec.step or 1
    local defV = (O.GetDefault and O.GetDefault(key)) or d[key] or minV
    local curV = d[key] or defV

    local cell = UI:Blank({
      col  = spec.col or 1,
      span = spec.span or 1,
      rowH = spec.rowH or ROW_H_TOP
    })

    local holder = ns.NumberSelect.Create(cell, {
      label   = spec.label or key,
      min     = minV,
      max     = maxV,
      step    = step,
      value   = curV,
      default = defV,
      onChange = function(v)
        d[key] = v
        if key == "topSize" or key == "timerSize" or key == "bottomSize" then
          ApplyAllFontsPreservingCenterColor()
        else
          ApplyAllFonts()
        end
      end,
    })

    holder:ClearAllPoints()
    holder:SetPoint("CENTER", cell, "CENTER", 0, 0)
    return holder
  end

  local approxH = (72) + 3*(ROW_H_TOP + (O.ROW_V_GAP or 10)) + 8
  local rowTri = Row(approxH)
  local MAP = BuildAppearanceMap()

  local d = DB()
  if d.glowEnabled == nil then d.glowEnabled = true end

  local glowCB

  OE.TripleColumn(rowTri, function(UI)
    for _, item in ipairs(MAP) do
      if item.type == "font" then
        UI:FontPicker({
          key    = item.key or "fontName",
          label  = item.label or "Font",
          col    = item.col or 1,
          span   = item.span or 1,
          rowH   = item.rowH or 72,
          onChange = function()
            ApplyAllFontsPreservingCenterColor()
          end,
        })

      elseif item.type == "numsel" then
        AddNumberSelectCell(UI, item)

      elseif item.type == "color" then
        UI:TextColor({
          colorKey = item.key,
          label    = item.label or item.key,
          which    = item.which,
          col      = item.col or 1,
          span     = item.span or 1,
          rowH     = item.rowH,
          onChange = function()
            if item.key == "glowColor" or item.key == "specialGlowColor" then
              ApplyGlowFromDB()
            else
              SyncCenterColorKeys()
              ApplyTextColors()
            end
          end,
        })

      elseif item.type == "checkbox" then
        local cell, cb = UI:Checkbox({
          key         = item.key,
          label       = item.label or item.key,
          col         = item.col or 1,
          span        = item.span or 1,
          rowH        = item.rowH or 44,
          yOffset     = item.yOffset or 0,
          centerBelow = item.centerBelow,
          noReset     = item.noReset,
          onChange = function()
            if item.key == "glowEnabled" then
              ApplyGlowFromDB()
            end
          end,
        })
        if item.key == "glowEnabled" then
          glowCB = cb
          cb:SetChecked((DB().glowEnabled ~= false) and true or false)
        end

      elseif item.type == "blank" then
        UI:Blank({
          col   = item.col or 1,
          span  = item.span or 1,
          rowH  = item.rowH or 16,
        })
      end
    end
  end)

  content:HookScript("OnShow", function()
    if glowCB then
      glowCB:SetChecked((DB().glowEnabled ~= false) and true or false)
    end
  end)
end

O.RegisterSection(function(AddSection)
  AddSection("Layout", function(content, _RowFromPanel)
    HidePageHeader(content)

    SyncCenterColorKeys()

    local scroll = CreateFrame("ScrollFrame", nil, content)
    scroll:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

    local vbar = SB.Create(content, { width = SCROLLBAR_WIDTH, sliderWidth = SCROLLBAR_WIDTH })
    vbar:SetPoint("TOPRIGHT",    content, "TOPRIGHT",    SCROLLBAR_X_OFFSET, 0)
    vbar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", SCROLLBAR_X_OFFSET, 0)
    scroll:SetPoint("BOTTOMRIGHT", vbar, "BOTTOMLEFT", -SCROLLBAR_INSET_PAD, 0)

    local inner = CreateFrame("Frame", nil, scroll)
    inner:SetPoint("TOPLEFT"); inner:SetSize(1, 1)
    scroll:SetScrollChild(inner)

    vbar:BindToScroll(scroll, inner)

    local rows = {}
    local VSPACE = (O and O.ROW_V_GAP) or 10

    local function Relayout()
      local y = 0
      local w = (scroll:GetWidth() or content:GetWidth() or 600)
      inner:SetWidth(w)
      for i=1,#rows do
        local f = rows[i]
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, -y)
        f:SetPoint("TOPRIGHT", inner, "TOPRIGHT", 0, -y)
        y = y + (f:GetHeight() or 0) + VSPACE
      end
      inner:SetHeight(math.max(y, 1))
    end

    local function Row(h)
      local f = CreateFrame("Frame", nil, inner)
      f:SetHeight(h or 0)
      f:HookScript("OnSizeChanged", Relayout)
      rows[#rows+1] = f
      Relayout()
      return f
    end

    scroll:HookScript("OnSizeChanged", Relayout)

    BuildOrderSection(inner, Row)
    BuildLayoutSection(inner, Row)
    BuildAppearanceSection(inner, Row)

    C_Timer.After(0, Relayout)
  end)
end)

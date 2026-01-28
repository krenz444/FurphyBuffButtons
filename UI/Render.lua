-- ====================================
-- \UI\Render.lua
-- ====================================
-- This file handles the core rendering system for all addon icons.
-- Manages icon layout (horizontal/vertical/grid), positioning, textures,
-- cooldowns, glows, and all visual elements. Uses LibCustomGlow for effects.
-- Coordinates with Core/UpdateBus for state changes and UI/VisualCore for frame creation.

local addonName, ns = ...
local parent, overlay, hover = ns.RenderParent, ns.Overlay, ns.Hover
local Glow = LibStub("LibCustomGlow-1.0")

NS = ns
ns.RenderFrames = ns.RenderFrames or {}
ns.RenderIndexByKey = ns.RenderIndexByKey or {}

_G.clickableRaidBuffCache = _G.clickableRaidBuffCache or {}
local C = _G.clickableRaidBuffCache

-- Configuration for rank overlays (e.g., quality tiers).
C.rankOverlayKnobs = C.rankOverlayKnobs or {
  spec   = { scale = 0.52, x = 5,  y = -5, alpha = 1 },
  rank1  = { scale = 0.52, xMul = 0.05, yMul = -0.08, alpha = 1 },
  rank2  = { scale = 0.52, xMul = 0.16, yMul = -0.09, alpha = 1 },
  rank3  = { scale = 0.52, xMul = 0.16, yMul = -0.16, alpha = 1 },
  hearty = { scale = 0.52, xMul = 0.13, yMul = -0.20, alpha = 1 },
  fleeting = { scale = 0.42, xMul = 0.1, yMul = -0.0, alpha = 0.8 },
}

-- Generates a unique key for an entry.
local function entryKey(cat, entry)
  if cat == "MAIN_HAND" then
    return "MH:" .. tostring(entry.itemID or entry.name or "")
  elseif cat == "OFF_HAND" then
    return "OH:" .. tostring(entry.itemID or entry.name or "")
  end

  if entry.isFixed and entry.spellID then
    local suf = ""
    local b1  = (type(entry.buffID) == "table") and entry.buffID[1] or entry.buffID
    if b1 then suf = ":b" .. tostring(b1) end
    return cat .. ":spell:" .. tostring(entry.spellID) .. ":fixed" .. suf
  end

  if entry.itemID then
    return cat .. ":item:" .. tostring(entry.itemID)
  end

  if entry.spellID then
    local suf = ""
    local b1  = (type(entry.buffID) == "table") and entry.buffID[1] or entry.buffID
    if b1 then suf = ":b" .. tostring(b1) end
    return cat .. ":spell:" .. tostring(entry.spellID) .. suf
  end

  return cat .. ":name:" .. tostring(entry.name or "")
end

-- Checks if two RGBA colors are the same.
local function sameRGBA(a, b)
  if not a or not b then return false end
  return a[1]==b[1] and a[2]==b[2] and a[3]==b[3] and (a[4] or 1)==(b[4] or 1)
end

-- Enables or disables the glow effect on a button.
local function ensureGlow(btn, shouldEnable, color, size)
  if not shouldEnable then
    if btn._crb_glow_enabled then
      Glow.PixelGlow_Stop(btn)
      btn._crb_glow_enabled = false
      btn._crb_glow_rgba = nil
      btn._crb_glow_size = nil
    end
    return
  end
  local rgba = { color.r, color.g, color.b, color.a or 1 }
  local N = 8
  local frequency = 0.25
  local length = (10 / 50) * size
  local th     = ( 1.6 / 50) * size

  if btn._crb_glow_enabled then
    if not sameRGBA(btn._crb_glow_rgba, rgba) or btn._crb_glow_size ~= size then
      Glow.PixelGlow_Stop(btn)
      btn._crb_glow_enabled = false
    end
  end
  if not btn._crb_glow_enabled then
    Glow.PixelGlow_Start(btn, rgba, N, frequency, length, th, 0, 0, true)
    btn._crb_glow_enabled = true
    btn._crb_glow_rgba = rgba
    btn._crb_glow_size = size
  end
end

-- Sets the icon texture if it has changed.
local function setIconTextureIfChanged(btn, tex)
  if btn.icon._crb_tex ~= tex then
    btn.icon:SetTexture(tex or 134400)
    btn.icon._crb_tex = tex
  end
end

-- Sets the button action (macro, item, spell) if it has changed.
local function setButtonActionIfChanged(btn, actionType, value1)
  if btn._crb_action_type ~= actionType or btn._crb_action_v1 ~= value1 then
    if actionType == "macro" then
      btn:SetAttribute("type", "macro")
      btn:SetAttribute("macrotext", value1)
    elseif actionType == "item" then
      btn:SetAttribute("type", "item")
      btn:SetAttribute("item", "item:" .. tostring(value1))
    elseif actionType == "spell" then
      btn:SetAttribute("type", "spell")
      btn:SetAttribute("spell", value1)
    else
      btn:SetAttribute("type", nil)
    end
    btn._crb_action_type = actionType
    btn._crb_action_v1   = value1
  end
end

-- Calculates offsets for rank overlays.
local function knobOffsets(ks, size, defX, defY)
  if not ks then return defX, defY end
  local x = ks.x
  local y = ks.y
  if x == nil and ks.xMul then x = ks.xMul * size end
  if y == nil and ks.yMul then y = ks.yMul * size end
  if x == nil and ks.offsetX ~= nil then x = ks.offsetX end
  if y == nil and ks.offsetY ~= nil then y = ks.offsetY end
  if x == nil then x = defX end
  if y == nil then y = defY end
  return x, y
end

local _raidBuffOrderMap
-- Gets the sort order index for a raid buff spell.
local function GetRaidBuffOrderIndex(spellID)
  if not _raidBuffOrderMap then
    _raidBuffOrderMap = {}
    if ns.GetRaidBuffOrderMap then
      _raidBuffOrderMap = ns.GetRaidBuffOrderMap() or _raidBuffOrderMap
    end
    if not next(_raidBuffOrderMap) and _G.clickableRaidBuffCache and _G.ClickableRaidData then
      local classID = _G.clickableRaidBuffCache.playerInfo and _G.clickableRaidBuffCache.playerInfo.playerClassId
      local tbl = classID and _G.ClickableRaidData[classID]
      if tbl then
        local keys = {}
        for k in pairs(tbl) do if type(k)=="number" then keys[#keys+1]=k end end
        table.sort(keys)
        for i, k in ipairs(keys) do _raidBuffOrderMap[k] = i end
      end
    end
  end
  return _raidBuffOrderMap[spellID] or 9999
end

-- Sorts items based on category priority and other criteria.
local function SortItems(items, catPriority)
  table.sort(items, function(a, b)
    local ai = catPriority[a.category] or 999
    local bi = catPriority[b.category] or 999
    if ai ~= bi then return ai < bi end

    if a.category == "PETS" and b.category == "PETS" then
      local ah = tonumber(a.orderHint) or 1e9
      local bh = tonumber(b.orderHint) or 1e9
      if ah ~= bh then return ah < bh end
      local as = a.spellID or a.itemID or 0
      local bs = b.spellID or b.itemID or 0
      if as ~= bs then return as < bs end
      local af = (a.isFixed and 1 or 0)
      local bf = (b.isFixed and 1 or 0)
      if af ~= bf then return af < bf end
      return false
    end

    if a.category == "RAID_BUFFS" and b.category == "RAID_BUFFS" then
      local oa = GetRaidBuffOrderIndex(a.spellID or 0)
      local ob = GetRaidBuffOrderIndex(b.spellID or 0)
      if oa ~= ob then return oa < ob end
      local as = a.spellID or 0
      local bs = b.spellID or 0
      if as == bs then
        local sa = a.orderHint or 0
        local sb = b.orderHint or 0
        if sa ~= sb then return sa < sb end
        if (a.isFixed and not b.isFixed) then return false end
        if (b.isFixed and not a.isFixed) then return true end
        return false
      end
      return as < bs
    end

    local ka = a.itemID or a.spellID or 0
    local kb = b.itemID or b.spellID or 0
    return ka < kb
  end)
end

-- Hides all rendered icons.
function ns.HideAllRenderedIcons()
  parent:SetSize(1, 1)
  ns.Overlay:Hide()
  for _, b in ipairs(ns.RenderFrames) do
    if b:IsShown() then
      if b._crb_glow_enabled then
        Glow.PixelGlow_Stop(b)
        b._crb_glow_enabled = false
        b._crb_glow_rgba = nil
      end
      if ns.ClearCooldownVisual then ns.ClearCooldownVisual(b) end
      b._crb_key = nil
      b._crb_entry = nil
      if b.timerText       then b.timerText:SetText(""); b.timerText:Hide() end
      if b.rankOverlay     then b.rankOverlay:Hide() end
      if b.fleetingOverlay then b.fleetingOverlay:Hide() end
      b:Hide()
    end
  end
  wipe(ns.RenderIndexByKey)
end

-- Clears icons during combat (if suspended).
function ns.CombatClearIcons()
  if ns.RenderParent then
    ns.RenderParent:Hide()
  end
  ns.HideAllRenderedIcons()
end

-- Restores icons after combat.
function ns.CombatRestoreIcons()
  if ns.RenderParent then
    ns.RenderParent:Show()
  end
  if ns.RenderAll then
    ns.RenderAll()
  end
end

-- Handles combat suspension of rendering.
local _combatFrame = CreateFrame("Frame")
_combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
_combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
_combatFrame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then
    ns._combat_suspended = true
    ns.CombatClearIcons()
  else
    ns._combat_suspended = false
    ns.CombatRestoreIcons()
  end
end)

-- Resolves font path.
local function ResolveFontPath(name)
  if ns.Options and ns.Options.GetFontPathByName then
    local p = ns.Options.GetFontPathByName(name)
    if p then return p end
  end
  local fallback = GameFontNormal and select(1, GameFontNormal:GetFont())
  return fallback or "Fonts\\FRIZQT__.TTF"
end

-- Main render function.
-- Skipped during combat.
function ns.RenderAll()
  if ns._combat_suspended or ns.InCombatSuppressed then return end
  if InCombatLockdown() then return end

  local db = ns.GetDB() or {}
  local displayable = _G.clickableRaidBuffCache and _G.clickableRaidBuffCache.displayable or {}

  local eatingActive = false
  do
    local eat = displayable.EATING
    if eat then for _, _ in pairs(eat) do eatingActive = true; break end end
  end

  local orderedCats = ns.GetCategoryOrder and ns.GetCategoryOrder() or {}
  if #orderedCats == 0 then
    for cat in pairs(displayable) do table.insert(orderedCats, cat) end
    table.sort(orderedCats)
  end
  local catPriority = {}
  for i, c in ipairs(orderedCats) do catPriority[c] = i end

  local items = {}

  for _, cat in ipairs(orderedCats) do
    if not (eatingActive and cat == "FOOD") then
      local catTable = displayable[cat]
      if catTable then
        for _, entry in pairs(catTable) do
          local visible = true
          if entry.showAt then visible = (GetTime() >= entry.showAt) end
          if entry.expireTime and entry.expireTime == math.huge then visible = false end
          if visible and ns.IsDisplayableExcluded and ns.IsDisplayableExcluded(cat, entry) then
            visible = false
          end
          if visible then
            entry.category = cat
            table.insert(items, entry)
          end
        end
      end
    end
  end

  if ns._force_min_icons then
    local need = math.max(0, ns._force_min_icons - #items)
    for i = 1, need do
      table.insert(items, {
        category = "DUMMY",
        name = "Dummy"..i,
        texture = "Interface\\AddOns\\ClickableRaidBuffs\\Media\\furphyLogoIcon",
        _crb_dummy = true,
      })
    end
  end

  if #items == 0 then
    ns.RenderParent:SetSize(1, 1)
    ns.Overlay:Hide()
    for _, b in ipairs(ns.RenderFrames) do
      if b:IsShown() then
        if b._crb_glow_enabled and Glow then Glow.PixelGlow_Stop(b) end
        if ns.ClearCooldownVisual then ns.ClearCooldownVisual(b) end
        b._crb_glow_enabled = false
        b._crb_glow_rgba = nil
        b._crb_key = nil
        b._crb_entry = nil
        if b.timerText then b.timerText:SetText(""); b.timerText:Hide() end
        if b.rankOverlay then b.rankOverlay:Hide() end
        if b.fleetingOverlay then b.fleetingOverlay:Hide() end
        b:Hide()
      end
    end
    wipe(ns.RenderIndexByKey)
    return
  end

  local function GetRaidBuffOrderIndex(spellID)
    if not _raidBuffOrderMap then
      _raidBuffOrderMap = {}
      if ns.GetRaidBuffOrderMap then
        _raidBuffOrderMap = ns.GetRaidBuffOrderMap() or _raidBuffOrderMap
      end
      if not next(_raidBuffOrderMap) and _G.clickableRaidBuffCache and _G.ClickableRaidData then
        local classID = _G.clickableRaidBuffCache.playerInfo and _G.clickableRaidBuffCache.playerInfo.playerClassId
        local tbl = classID and _G.ClickableRaidData[classID]
        if tbl then
          local keys = {}
          for k in pairs(tbl) do if type(k)=="number" then keys[#keys+1]=k end end
          table.sort(keys)
          for i, k in ipairs(keys) do _raidBuffOrderMap[k] = i end
        end
      end
    end
    return _raidBuffOrderMap[spellID] or 9999
  end

  local function SortItems(list, prio)
    table.sort(list, function(a, b)
      local ai = prio[a.category] or 999
      local bi = prio[b.category] or 999
      if ai ~= bi then return ai < bi end
      if a.category == "PETS" and b.category == "PETS" then
        local ah = tonumber(a.orderHint) or 1e9
        local bh = tonumber(b.orderHint) or 1e9
        if ah ~= bh then return ah < bh end
        local as = a.spellID or a.itemID or 0
        local bs = b.spellID or b.itemID or 0
        if as ~= bs then return as < bs end
        local af = (a.isFixed and 1 or 0)
        local bf = (b.isFixed and 1 or 0)
        if af ~= bf then return af < bf end
        return false
      end
      if a.category == "RAID_BUFFS" and b.category == "RAID_BUFFS" then
        local oa = GetRaidBuffOrderIndex(a.spellID or 0)
        local ob = GetRaidBuffOrderIndex(b.spellID or 0)
        if oa ~= ob then return oa < ob end
        local as = a.spellID or 0
        local bs = b.spellID or 0
        if as == bs then
          local sa = a.orderHint or 0
          local sb = b.orderHint or 0
          if sa ~= sb then return sa < sb end
          if (a.isFixed and not b.isFixed) then return false end
          if (b.isFixed and not a.isFixed) then return true end
          return false
        end
        return as < bs
      end
      local ka = a.itemID or a.spellID or 0
      local kb = b.itemID or b.spellID or 0
      return ka < kb
    end)
  end

  SortItems(items, catPriority)

  local size         = db.iconSize or 50
  local spacingH     = math.floor(((db.hSpace or 9) / 50) * size + 0.5)
  local spacingV     = math.floor(((db.vSpace or 9) / 50) * size + 0.5)
  local style        = db.style or "HORIZONTAL"
  local useMax       = (db.useMaxPerRow == true)
  local perTierOpt   = math.max(1, db.maxPerRow or 7)
  local alignKey     = db.alignment or "CENTER"
  local growDown     = (db.growV or "DOWN") == "DOWN"
  local growRight    = (db.growH == "RIGHT") or (db.gridLTR ~= false)
  local hstep  = size + spacingH
  local vstep  = size + spacingV
  local parentW, parentH = 0, 0
  local coords = {}
  local function place(i, x, y) coords[i] = { x=x, y=y } end

  if style == "HORIZONTAL" then
    if not useMax then
      local n = #items
      local capacityCols = math.max(n, perTierOpt)
      parentW = (capacityCols > 0) and (capacityCols*size + (capacityCols-1)*spacingH) or 0
      parentH = size
      local baseLeftX = -parentW/2 + size/2
      local shiftX
      if     alignKey == "LEFT"   then shiftX = 0
      elseif alignKey == "RIGHT"  then shiftX = (capacityCols - n) * hstep
      else   shiftX = ((capacityCols - n) * hstep) / 2 end
      if alignKey == "RIGHT" then
        for j = 0, n - 1 do
          local x = baseLeftX + shiftX + ((n-1 - j)*hstep)
          place(j+1, x, 0)
        end
      else
        for j = 0, n - 1 do
          local x = baseLeftX + shiftX + (j*hstep)
          place(j+1, x, 0)
        end
      end
    else
      local rows = math.ceil(#items / perTierOpt)
      local capacityCols = perTierOpt
      parentW = (capacityCols > 0) and (capacityCols*size + (capacityCols-1)*spacingH) or 0
      parentH = (rows > 0) and (rows*vstep - (vstep - size)) or 0
      local baseLeftX = -parentW/2 + size/2
      local topY      =  parentH/2 - size/2
      local botY      = -parentH/2 + size/2
      local idx = 1
      for r = 0, rows - 1 do
        local remain = #items - idx + 1
        local take   = math.min(perTierOpt, remain)
        local shiftX
        if     alignKey == "LEFT"   then shiftX = 0
        elseif alignKey == "RIGHT"  then shiftX = (perTierOpt - take) * hstep
        else   shiftX = ((perTierOpt - take) * hstep) / 2 end
        local y = growDown and (topY - r*vstep) or (botY + r*vstep)
        if alignKey == "RIGHT" then
          for j = 0, take - 1 do
            local x = baseLeftX + shiftX + ((take-1 - j)*hstep)
            place(idx, x, y) ; idx = idx + 1
          end
        else
          for j = 0, take - 1 do
            local x = baseLeftX + shiftX + (j*hstep)
            place(idx, x, y) ; idx = idx + 1
          end
        end
      end
    end
  else
    if not useMax then
      local n = #items
      local capacityRows = math.max(n, perTierOpt)
      parentW = size
      parentH = (capacityRows > 0) and (capacityRows*vstep - (vstep - size)) or 0
      local topY      =  parentH/2 - size/2
      local rowShiftY
      if     alignKey == "LEFT"   then rowShiftY = 0
      elseif alignKey == "RIGHT"  then rowShiftY = (capacityRows - n) * vstep
      else   rowShiftY = ((capacityRows - n) * vstep) / 2 end
      for j = 0, n - 1 do
        local y = topY - (rowShiftY + j*vstep)
        place(j+1, 0, y)
      end
    else
      local columns      = math.ceil(#items / perTierOpt)
      local capacityRows = perTierOpt
      parentW = (columns > 0)      and ((columns-1)*hstep + size)      or 0
      parentH = (capacityRows > 0) and ((capacityRows-1)*vstep + size) or 0
      local colHalfSpan = (columns - 1) * hstep * 0.5
      local rowCapTop   =  parentH/2 - size/2
      local idx = 1
      for c = 0, columns - 1 do
        local colSlot = growRight and c or (columns - 1 - c)
        local x = -colHalfSpan + colSlot * hstep
        local remain = #items - idx + 1
        local take   = math.min(perTierOpt, remain)
        local rowShiftY
        if     alignKey == "LEFT"   then rowShiftY = 0
        elseif alignKey == "RIGHT"  then rowShiftY = (capacityRows - take) * vstep
        else   rowShiftY = ((capacityRows - take) * vstep) / 2 end
        for j = 0, take - 1 do
          local y = rowCapTop - (rowShiftY + j*vstep)
          place(idx, x, y)
          idx = idx + 1
        end
      end
    end
  end

  ns.RenderParent:SetSize(math.max(1, parentW), math.max(1, parentH))
  local pad = size * 2
  ns.Overlay:ClearAllPoints(); ns.Overlay:SetPoint("CENTER", ns.RenderParent, "CENTER")
  ns.Overlay:SetSize(parentW + pad, parentH + pad)
  ns.Hover:ClearAllPoints();   ns.Hover:SetPoint("CENTER", ns.RenderParent, "CENTER")
  ns.Hover:SetSize(parentW + pad, parentH + pad)

  -- Local helper functions are redefined here (duplicates of lines 56-99) for performance
  -- and scope isolation. These are called in tight loops during rendering, so local copies
  -- avoid repeated namespace lookups and maintain clean function-level encapsulation.

  local function ResolveFontPath(name)
    if ns.Options and ns.Options.GetFontPathByName then
      local p = ns.Options.GetFontPathByName(name)
      if p then return p end
    end
    local fallback = GameFontNormal and select(1, GameFontNormal:GetFont())
    return fallback or "Fonts\\FRIZQT__.TTF"
  end
  local centerFontPath = ResolveFontPath(db.fontName)
  local centerSize = math.max(1, math.floor(((db.timerSize or 28) / 50) * (db.iconSize or 50) + 0.5))
  local centerOutline = (db.centerOutline ~= false) and "OUTLINE" or ""

  local used = {}
  local general = db.glowColor or { r=0.95, g=0.95, b=0.32, a=1 }
  local special = db.specialGlowColor or { r=0.00, g=0.913725, b=1.00, a=1 }

  local function sameRGBA(a, b)
    if not a or not b then return false end
    return a[1]==b[1] and a[2]==b[2] and a[3]==b[3] and (a[4] or 1)==(b[4] or 1)
  end

  local function ensureGlow(btn, shouldEnable, color, size)
    if not shouldEnable then
      if btn._crb_glow_enabled and Glow then
        Glow.PixelGlow_Stop(btn)
        btn._crb_glow_enabled = false
        btn._crb_glow_rgba = nil
        btn._crb_glow_size = nil
      end
      return
    end
    if not Glow then return end
    local rgba = { color.r, color.g, color.b, color.a or 1 }
    local N = 8
    local frequency = 0.25
    local length = (10 / 50) * size
    local th     = ( 1.6 / 50) * size
    if btn._crb_glow_enabled then
      if not sameRGBA(btn._crb_glow_rgba, rgba) or btn._crb_glow_size ~= size then
        Glow.PixelGlow_Stop(btn)
        btn._crb_glow_enabled = false
      end
    end
    if not btn._crb_glow_enabled then
      Glow.PixelGlow_Start(btn, rgba, N, frequency, length, th, 0, 0, true)
      btn._crb_glow_enabled = true
      btn._crb_glow_rgba = rgba
      btn._crb_glow_size = size
    end
  end

  local function setIconTextureIfChanged(btn, tex)
    if btn.icon._crb_tex ~= tex then
      btn.icon:SetTexture(tex or 134400)
      btn.icon._crb_tex = tex
    end
  end

  local function setButtonActionIfChanged(btn, actionType, value1)
    if btn._crb_action_type ~= actionType or btn._crb_action_v1 ~= value1 then
      if actionType == "macro" then
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", value1)
      elseif actionType == "item" then
        btn:SetAttribute("type", "item")
        btn:SetAttribute("item", "item:" .. tostring(value1))
      elseif actionType == "spell" then
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", value1)
      else
        btn:SetAttribute("type", nil)
      end
      btn._crb_action_type = actionType
      btn._crb_action_v1   = value1
    end
  end

  local function knobOffsets(ks, size, defX, defY)
    if not ks then return defX, defY end
    local x = ks.x
    local y = ks.y
    if x == nil and ks.xMul then x = ks.xMul * size end
    if y == nil and ks.yMul then y = ks.yMul * size end
    if x == nil and ks.offsetX ~= nil then x = ks.offsetX end
    if y == nil and ks.offsetY ~= nil then y = ks.offsetY end
    if x == nil then x = defX end
    if y == nil then y = defY end
    return x, y
  end

  local ctc = db.centerTextColor or {r=1,g=1,b=1,a=1}

  local function entryKey(cat, entry)
    if cat == "MAIN_HAND" then
      return "MH:" .. tostring(entry.itemID or entry.name or "")
    elseif cat == "OFF_HAND" then
      return "OH:" .. tostring(entry.itemID or entry.name or "")
    end
    if entry.isFixed and entry.spellID then
      local suf = ""
      local b1  = (type(entry.buffID) == "table") and entry.buffID[1] or entry.buffID
      if b1 then suf = ":b" .. tostring(b1) end
      return cat .. ":spell:" .. tostring(entry.spellID) .. ":fixed" .. suf
    end
    if entry.itemID then
      return cat .. ":item:" .. tostring(entry.itemID)
    end
    if entry.spellID then
      local suf = ""
      local b1  = (type(entry.buffID) == "table") and entry.buffID[1] or entry.buffID
      if b1 then suf = ":b" .. tostring(b1) end
      return cat .. ":spell:" .. tostring(entry.spellID) .. suf
    end
    return cat .. ":name:" .. tostring(entry.name or "")
  end

  for idx, entry in ipairs(items) do
    local key = entryKey(entry.category, entry)

    local btn = ns.RenderIndexByKey[key]
    if not (btn and btn:IsShown()) then
      for i = 1, #ns.RenderFrames do
        local b = ns.RenderFrames[i]
        if not b:IsShown() then btn = b; break end
      end
      if not btn then
        local index = #ns.RenderFrames + 1
        btn = CreateFrame("Button", addonName .. "Icon" .. index, ns.RenderParent, "SecureActionButtonTemplate")
        btn:SetSize(1, 1)
        btn:RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "LeftButtonDown" or "LeftButtonUp")

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        btn.icon = icon

        btn.overlayFrame = CreateFrame("Frame", nil, btn)
        btn.overlayFrame:SetAllPoints(btn)
        btn.overlayFrame:SetFrameLevel(btn:GetFrameLevel() + 20)

        btn.rankOverlay = btn.overlayFrame:CreateTexture(nil, "ARTWORK")
        btn.rankOverlay:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2)
        btn.rankOverlay:Hide()

        btn.fleetingOverlay = btn.overlayFrame:CreateTexture(nil, "ARTWORK")
        btn.fleetingOverlay:SetPoint("CENTER", btn, "BOTTOMRIGHT", 2, -2)
        btn.fleetingOverlay:Hide()

        btn.topText = btn:CreateFontString(nil, "OVERLAY")
        btn.topText:SetPoint("BOTTOM", btn, "TOP", 0, 0)
        ns.UpdateFontString(btn.topText, "", db.fontName or "Fonts\\FRIZQT__.TTF",
            db.topSize or 14, db.topOutline ~= false, db.topTextColor or {r=1,g=1,b=1,a=1})

        btn.bottomText = btn:CreateFontString(nil, "OVERLAY")
        btn.bottomText:SetPoint("TOP", btn, "BOTTOM", 0, -5)
        ns.UpdateFontString(btn.bottomText, "", db.fontName or "Fonts\\FRIZQT__.TTF",
            db.bottomSize or 14, db.bottomOutline ~= false, db.bottomTextColor or {r=1,g=1,b=1,a=1})

        btn.centerText = btn.overlayFrame:CreateFontString(nil, "OVERLAY")
        btn.centerText:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.centerText:SetFont(centerFontPath, centerSize, centerOutline)
        btn.centerText:SetTextColor(ctc.r, ctc.g, ctc.b, ctc.a or 1)
        btn._crb_center_font_path  = centerFontPath
        btn._crb_center_font_size  = centerSize
        btn._crb_center_outline    = centerOutline

        btn.cornerText = btn:CreateFontString(nil, "OVERLAY")
        btn.cornerText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
        ns.UpdateFontString(btn.cornerText, "", db.fontName or "Fonts\\FRIZQT__.TTF",
            db.cornerSize or db.bottomSize or 14, db.cornerOutline ~= false,
            db.cornerTextColor or db.bottomTextColor or {r=1,g=1,b=1,a=1})

        btn.timerText = btn:CreateFontString(nil, "OVERLAY")
        btn.timerText:SetPoint("TOP", btn.bottomText, "BOTTOM", 0, 0)
        ns.UpdateFontString(btn.timerText, "", db.fontName or "Fonts\\FRIZQT__.TTF",
            db.bottomSize or 14, db.bottomOutline ~= false, db.bottomTextColor or {r=1,g=1,b=1,a=1})
        btn.timerText:Hide()

        btn:SetScript("OnEnter", function(self)
          local d  = (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {}
          local tt = (d.tooltips and d.tooltips.enabled ~= false)
          local entryX = self._crb_entry

          if entryX and entryX.hoverIcon and self.icon and self.icon.GetTexture then
            self._crb_icon_restore = self.icon:GetTexture()
            self.icon:SetTexture(entryX.hoverIcon)
          end

          if not tt then
            if IsShiftKeyDown() and ns.Overlay then ns.Overlay:Show() end
            return
          end

          if entryX then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local ok = false
            if entryX.itemID then
              GameTooltip:SetItemByID(entryX.itemID)
              ok = true
            elseif entryX.spellID then
              GameTooltip:SetSpellByID(entryX.spellID)
              ok = true
            end
            if not ok then
              local text = entryX.name
              if not text or text == "" then
                text = entryX.topLbl or entryX.btmLbl or entryX.category or " "
              end
              GameTooltip:SetText(tostring(text))
            end
            GameTooltip:Show()
          end

          if IsShiftKeyDown() and ns.Overlay then ns.Overlay:Show() end
        end)


        btn:SetScript("OnLeave", function(self)
          GameTooltip:Hide()

          if self.icon and self._crb_icon_restore then
            self.icon:SetTexture(self._crb_icon_restore)
            self._crb_icon_restore = nil
          end

          if not (IsShiftKeyDown() and (ns.Hover:IsMouseOver() or ns.Overlay:IsMouseOver())) then
            ns.Overlay:Hide()
          end
        end)



        ns.RenderFrames[index] = btn
      end
      ns.RenderIndexByKey[key] = btn
      btn._crb_key = key
    end

    local btn2 = ns.RenderIndexByKey[key]
    used[key] = true
    btn2._crb_entry = entry

    btn2:SetSize(size, size)
    btn2:ClearAllPoints()
    local p = coords[idx]
    btn2:SetPoint("CENTER", ns.RenderParent, "CENTER", p.x, p.y)

    if btn2._crb_center_font_size ~= centerSize or
       btn2._crb_center_font_path ~= centerFontPath or
       btn2._crb_center_outline   ~= centerOutline then
      btn2.centerText:SetFont(centerFontPath, centerSize, centerOutline)
      btn2._crb_center_font_size = centerSize
      btn2._crb_center_font_path = centerFontPath
      btn2._crb_center_outline   = centerOutline
    end
    local ctcX = db.centerTextColor or {r=1,g=1,b=1,a=1}
    if not btn2._crb_center_color or
       btn2._crb_center_color.r ~= ctcX.r or btn2._crb_center_color.g ~= ctcX.g or
       btn2._crb_center_color.b ~= ctcX.b or (btn2._crb_center_color.a or 1) ~= (ctcX.a or 1) then
      btn2.centerText:SetTextColor(ctcX.r, ctcX.g, ctcX.b, ctcX.a or 1)
      btn2._crb_center_color = {r=ctcX.r,g=ctcX.g,b=ctcX.b,a=ctcX.a}
    end

    local tex
    if entry.texture then
      tex = entry.texture
    elseif entry.icon then
      tex = entry.icon
    elseif entry.itemID then
      tex = select(5, C_Item.GetItemInfoInstant(entry.itemID)) or 134400
    elseif entry.spellID then
      local inf = C_Spell.GetSpellInfo(entry.spellID)
      tex = (inf and inf.iconID) or 134400
    else
      tex = 134400
    end
    if btn2.icon._crb_tex ~= tex then
      btn2.icon:SetTexture(tex or 134400)
      btn2.icon._crb_tex = tex
    end

    do
      local overlayAtlas, knobKey
      if entry.specAtlas then
        overlayAtlas = entry.specAtlas
        knobKey = "spec"
      elseif entry.rank == 1 then
        overlayAtlas = "Professions-Icon-Quality-Tier1"
        knobKey = "rank1"
      elseif entry.rank == 2 then
        overlayAtlas = "Professions-Icon-Quality-Tier2"
        knobKey = "rank2"
      elseif entry.rank == 3 then
        overlayAtlas = "Professions-Icon-Quality-Tier3"
        knobKey = "rank3"
      elseif entry.hearty then
        overlayAtlas = "Soulbinds_Tree_Conduit_Icon_Utility"
        knobKey = "hearty"
      end

      if overlayAtlas then
        local ks = C.rankOverlayKnobs and C.rankOverlayKnobs[knobKey]
        btn2.rankOverlay:SetAtlas(overlayAtlas, true)
        local s  = (ks and ks.scale) or 0.52
        btn2.rankOverlay:SetSize(size * s, size * s)
        btn2.rankOverlay:ClearAllPoints()
        local ox, oy = knobOffsets(ks, size, 5, -5)
        btn2.rankOverlay:SetPoint("CENTER", btn2, "TOPLEFT", ox, oy)
        btn2.rankOverlay:SetAlpha((ks and ks.alpha) or 1)
        btn2.rankOverlay:Show()
      else
        btn2.rankOverlay:Hide()
      end

      if entry.fleeting then
        local k2 = C.rankOverlayKnobs and C.rankOverlayKnobs.fleeting
        btn2.fleetingOverlay:SetAtlas("ChromieTime-32x32", true)
        local s = (k2 and k2.scale) or 0.42
        btn2.fleetingOverlay:SetSize(size * s, size * s)
        btn2.fleetingOverlay:ClearAllPoints()
        local ox, oy = knobOffsets(k2, size, 2, -2)
        btn2.fleetingOverlay:SetPoint("BOTTOMRIGHT", btn2, "BOTTOMRIGHT", ox, oy)
        btn2.fleetingOverlay:SetAlpha((k2 and k2.alpha) or 0.8)
        btn2.fleetingOverlay:Show()
      else
        btn2.fleetingOverlay:Hide()
      end
    end

    local color
    if entry.category=="FOOD" and entry.hearty then      color = special
    elseif entry.category=="FLASK" and entry.fleeting then color = special
    elseif entry.glow == "special" then color = special
    else color = general end
    ensureGlow(btn2, (db.glowEnabled ~= false), color, size)

    do
      local txtTop = entry.topLbl or ""
      if btn2._crb_topText ~= txtTop then
        btn2.topText:SetText(txtTop)
        btn2._crb_topText = txtTop
      end
    end

    if not btn2._crb_center_from_cd then
      local centerVal = ""
      if entry and entry.centerText ~= nil then
        centerVal = tostring(entry.centerText or "")
      elseif entry.category == "AUGMENT_RUNE" and entry.qty == false then
        centerVal = ""
      elseif entry.quantity and entry.quantity > 0 then
        centerVal = tostring(entry.quantity)
      elseif entry.category == "HEALTHSTONE" and entry.quantity ~= nil then
        centerVal = tostring(entry.quantity)
      else
        centerVal = ""
      end
      if btn2._crb_centerText ~= centerVal then
        btn2.centerText:SetText(centerVal)
        btn2._crb_centerText = centerVal
      end
    end

    do
      local txtBottom = entry.btmLbl
      if (not txtBottom or txtBottom == "") then
        local val = ""
        if entry.count ~= 1 or type(entry.macro) ~= "string" then
          val = ""
        else
          if string.find(entry.macro, "@target") then
            val = TARGET
          else
            local inside = entry.macro:match("%[@([^%]]+)%]")
            local name = inside or entry.macro:match("@([%w%-]+)")
            if name then
              name = tostring(name)
              local lower = string.lower(name)
              if not (lower == "target" or lower == "player" or lower == "focus" or lower == "mouseover"
                      or lower:match("^party%d+$") or lower:match("^raid%d+$")) then
                val = name
              end
            end
          end
        end
        txtBottom = val
      end
      if btn2._crb_bottomText ~= txtBottom then
        btn2.bottomText:SetText(txtBottom)
        btn2._crb_bottomText = txtBottom
      end
    end

    do
      local cornerVal = entry.qty and tostring(entry.qty) or ""
      if entry.category == "MAIN_HAND" then cornerVal = "MH"
      elseif entry.category == "OFF_HAND" then cornerVal = "OH" end
      if btn2._crb_cornerText ~= cornerVal then
        btn2.cornerText:SetText(cornerVal, "OUTLINE")
        btn2._crb_cornerText = cornerVal
      end
    end

    if ns.RefreshCooldownForButton then ns.RefreshCooldownForButton(btn2) end
    if ns.RefreshSpellCooldownForButton then ns.RefreshSpellCooldownForButton(btn2) end

    if entry.category == "EATING" then
      if ns.ApplyEatingCooldown then ns.ApplyEatingCooldown(btn2, entry) end
    elseif entry.cooldownStart and entry.cooldownDuration and entry.cooldownDuration > 0 then
      if ns.ApplyItemCooldown then ns.ApplyItemCooldown(btn2, entry) end
    else
      if ns.ClearCooldownVisual then ns.ClearCooldownVisual(btn2) end
    end

    if entry.macro then
      setButtonActionIfChanged(btn2, "macro", entry.macro)
    elseif entry.itemID then
      setButtonActionIfChanged(btn2, "item", entry.itemID)
    elseif entry.spellID then
      local castKey = (entry.spellToCast ~= nil) and entry.spellToCast or entry.spellID
      setButtonActionIfChanged(btn2, "spell", castKey)
    else
      setButtonActionIfChanged(btn2, nil, nil)
    end

    if not btn2:IsShown() then btn2:Show() end
  end

  for key, btn in pairs(ns.RenderIndexByKey) do
    if not used[key] and btn:IsShown() then
      if btn._crb_glow_enabled and Glow then
        Glow.PixelGlow_Stop(btn)
        btn._crb_glow_enabled = false
        btn._crb_glow_rgba = nil
      end
      if ns.ClearCooldownVisual then ns.ClearCooldownVisual(btn) end
      btn._crb_key = nil
      btn._crb_entry = nil
      if btn.timerText then btn.timerText:SetText(""); btn.timerText:Hide() end
      if btn.rankOverlay then btn.rankOverlay:Hide() end
      if btn.fleetingOverlay then btn.fleetingOverlay:Hide() end
      btn:Hide()
      ns.RenderIndexByKey[key] = nil
    end
  end
end

-- ====================================
-- \UI\TextStyles.lua
-- ====================================
-- This file manages the styling (font, size, color, outline) of text elements on buttons.

local addonName, ns = ...

local function InCombat() return InCombatLockdown() end
local function DB() return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {} end

-- Retrieves LibSharedMedia if available.
local function getLSM()
  local ok, LSM = pcall(LibStub, "LibSharedMedia-3.0")
  if ok and LSM then return LSM end
  return nil
end

-- Gets the font path from the database or defaults.
local function fontPathFromDB()
  local db = DB()
  local LSM = getLSM()
  if LSM then
    return LSM:Fetch("font", db.fontName or "Friz Quadrata TT")
  end
  return db.fontName or "Fonts\\FRIZQT__.TTF"
end

-- Converts boolean outline flag to string.
local function applyFlags(wantOutline) return (wantOutline and "OUTLINE") or "" end

-- Scales font size based on button size.
local function scaled(base, btn)
  local db = DB()
  local w = (btn and btn.GetWidth and btn:GetWidth()) or (db.iconSize or ns.BASE_ICON_SIZE or 50)
  if not w or w <= 0 then w = 50 end
  local baseSize = tonumber(base) or 14
  if baseSize <= 0 then baseSize = 14 end
  local px = math.floor(baseSize * (w / 50))
  if px < 1 then px = 1 end
  return px
end

-- Sets font properties only if they have changed.
local function setFontIfChanged(fs, path, size, flags)
  local curPath, curSize, curFlags = fs:GetFont()
  if curPath ~= path or curSize ~= size or (curFlags or "") ~= (flags or "") then
    fs:SetFont(path, size, flags)
  end
end

-- Sets text color only if it has changed.
local function setColorIfChanged(fs, r, g, b, a)
  local cr, cg, cb, ca = fs:GetTextColor()
  if cr ~= r or cg ~= g or cb ~= b or ca ~= a then
    fs:SetTextColor(r, g, b, a)
  end
end

-- Helper to extract color values from a table or arguments.
local function colorOr(tbl, r, g, b, a)
  if type(tbl) == "table" then
    return tbl.r or r or 1, tbl.g or g or 1, tbl.b or b or 1, tbl.a or a or 1
  end
  return r or 1, g or 1, b or 1, a or 1
end

-- Helpers to identify font strings.
local function parentOf(fs) return (fs and fs.GetParent) and fs:GetParent() or nil end
local function isCenterFS(fs)  local p=parentOf(fs); return p and p.centerText  == fs end
local function isTopFS(fs)     local p=parentOf(fs); return p and p.topText     == fs end
local function isBottomFS(fs)  local p=parentOf(fs); return p and p.bottomText  == fs end
local function isTimerFS(fs)   local p=parentOf(fs); return p and p.timerText   == fs end
local function isCornerFS(fs)  local p=parentOf(fs); return p and p.cornerText  == fs end

-- Pickers for font properties based on DB settings.
local function pickCenterSize(btn)
  local db = DB()
  local want = db.centerSize or db.timerSize or 28
  return scaled(want, btn)
end

local function pickCenterOutline()
  local db = DB()
  if db.centerOutline ~= nil then return db.centerOutline ~= false end
  if db.timerOutline  ~= nil then return db.timerOutline  ~= false end
  if db.bottomOutline ~= nil then return db.bottomOutline ~= false end
  return true
end

local function pickCenterColor()
  local db = DB()
  local c = db.centerTextColor or db.timerTextColor or { r=1,g=1,b=1,a=1 }
  local r,g,b,a = colorOr(c, 1,1,1,1)
  return r,g,b,a
end

local function pickTopSize(btn)       return scaled(DB().topSize    or 14, btn) end
local function pickTopOutline()       local v=DB().topOutline;    return (v ~= false) end
local function pickTopColor()         return colorOr(DB().topTextColor, 1,1,1,1) end

local function pickBottomSize(btn)    return scaled(DB().bottomSize or 14, btn) end
local function pickBottomOutline()    local v=DB().bottomOutline; return (v ~= false) end
local function pickBottomColor()      return colorOr(DB().bottomTextColor, 1,1,1,1) end

local function pickTimerSize(btn)     return pickBottomSize(btn) end
local function pickTimerOutline()     return pickBottomOutline() end
local function pickTimerColor()       return pickBottomColor() end

local function pickCornerSize(btn)    return scaled(DB().cornerSize or DB().bottomSize or 12, btn) end
local function pickCornerOutline()    local v=DB().cornerOutline; return (v ~= false) end
local function pickCornerColor()      return colorOr(DB().cornerTextColor, 1,1,1,1) end

-- Styling functions for specific text elements.
local function styleCenter(fs)
  local btn = parentOf(fs)
  local path = fontPathFromDB()
  local size = pickCenterSize(btn)
  local ol   = pickCenterOutline()
  setFontIfChanged(fs, path, size, applyFlags(ol))
  local r,g,b,a = pickCenterColor()
  setColorIfChanged(fs, r, g, b, a)
end

local function styleTop(fs)
  local btn = parentOf(fs)
  local path = fontPathFromDB()
  local size = pickTopSize(btn)
  local ol   = pickTopOutline()
  setFontIfChanged(fs, path, size, applyFlags(ol))
  local r,g,b,a = pickTopColor()
  setColorIfChanged(fs, r, g, b, a)
end

local function styleBottom(fs)
  local btn = parentOf(fs)
  local path = fontPathFromDB()
  local size = pickBottomSize(btn)
  local ol   = pickBottomOutline()
  setFontIfChanged(fs, path, size, applyFlags(ol))
  local r,g,b,a = pickBottomColor()
  setColorIfChanged(fs, r, g, b, a)
end

local function styleTimer(fs)
  local btn = parentOf(fs)
  local path = fontPathFromDB()
  local size = pickTimerSize(btn)
  local ol   = pickTimerOutline()
  setFontIfChanged(fs, path, size, applyFlags(ol))
  local r,g,b,a = pickTimerColor()
  setColorIfChanged(fs, r, g, b, a)
end

local function styleCorner(fs)
  local btn = parentOf(fs)
  local path = fontPathFromDB()
  local size = pickCornerSize(btn)
  local ol   = pickCornerOutline()
  setFontIfChanged(fs, path, size, applyFlags(ol))
  local r,g,b,a = pickCornerColor()
  setColorIfChanged(fs, r, g, b, a)
end

-- Dispatches styling to the correct function based on the font string.
local function styleForFS(fs)
  if not fs then return end
  if isCenterFS(fs)  then styleCenter(fs);  return end
  if isTimerFS(fs)   then styleTimer(fs);   return end
  if isTopFS(fs)     then styleTop(fs);     return end
  if isBottomFS(fs)  then styleBottom(fs);  return end
  if isCornerFS(fs)  then styleCorner(fs);  return end
end

-- Hooks UpdateFontString to apply styles automatically.
local function EnsureUFSHook()
  local cur = ns.UpdateFontString
  if type(cur) ~= "function" then return end
  if ns._textstyles_wrapped_ufs_ptr == cur then return end

  local orig = cur
  ns.UpdateFontString = function(fs, text, font, size, outlineFlag, colorTbl)
    local r = orig(fs, text, font, size, outlineFlag, colorTbl)
    styleForFS(fs)
    return r
  end

  ns._textstyles_wrapped_ufs_ptr = ns.UpdateFontString
end

EnsureUFSHook()
C_Timer.After(0.05, EnsureUFSHook)
C_Timer.After(0.5, EnsureUFSHook)

-- Restyles all text elements on a button.
local function RestyleButtonTexts(btn)
  if not btn or not btn:IsShown() then return end
  if btn.centerText  then styleForFS(btn.centerText)  end
  if btn.timerText   then styleForFS(btn.timerText)   end
  if btn.topText     then styleForFS(btn.topText)     end
  if btn.bottomText  then styleForFS(btn.bottomText)  end
  if btn.cornerText  then styleForFS(btn.cornerText)  end
end

-- Restyles all visible buttons.
-- Skipped during combat.
local function RestyleAllVisible()
  if InCombat() then return end
  local frames = ns.RenderFrames
  if not frames then return end
  for i = 1, #frames do
    local btn = frames[i]
    if btn and btn:IsShown() then
      RestyleButtonTexts(btn)
    end
  end
end

-- Hooks RenderAll to trigger restyling.
local function EnsureRenderHook()
  if ns._textstyles_renderWrapped then return end
  if type(ns.RenderAll) == "function" then
    local orig = ns.RenderAll
    ns.RenderAll = function(...)
      local r = orig(...)
      RestyleAllVisible()
      return r
    end
    ns._textstyles_renderWrapped = true
  end
end

EnsureRenderHook()
C_Timer.After(0.05, EnsureRenderHook)
C_Timer.After(0.5, EnsureRenderHook)

-- Helper to stringify values for fingerprinting.
local function S(x)
  local t = type(x)
  if t == "nil" then return "" end
  if t == "boolean" then return x and "1" or "0" end
  if t == "number" then return tostring(x) end
  if t == "string" then return x end
  return tostring(x) or ""
end

-- Helper to stringify color tables.
local function ColorS(c)
  if type(c) ~= "table" then return "" end
  local r = c.r or 0
  local g = c.g or 0
  local b = c.b or 0
  local a = c.a or 1
  return tostring(r) .. "," .. tostring(g) .. "," .. tostring(b) .. "," .. tostring(a)
end

local function CenterColorS()
  local r,g,b,a = pickCenterColor()
  return tostring(r) .. "," .. tostring(g) .. "," .. tostring(b) .. "," .. tostring(a)
end

-- Generates a fingerprint of current style settings to detect changes.
local function StyleFingerprint()
  local db = DB()
  local f = {
    S(db.fontName), S(db.iconSize),
    S(db.centerSize), S(db.timerSize), S(db.topSize), S(db.bottomSize), S(db.cornerSize),
    S(pickCenterOutline()), S(DB().topOutline ~= false), S(DB().bottomOutline ~= false), S(DB().cornerOutline ~= false),
    CenterColorS(),
    ColorS(db.topTextColor or {}),
    ColorS(db.bottomTextColor or {}),
    ColorS(db.cornerTextColor or {}),
  }
  return table.concat(f, "|")
end

-- Periodically checks for style changes and triggers a refresh.
local lastFP = StyleFingerprint()
C_Timer.NewTicker(0.5, function()
  if InCombat() then return end
  EnsureUFSHook()
  EnsureRenderHook()
  local cur = StyleFingerprint()
  if cur ~= lastFP then
    lastFP = cur
    if ns.RenderAll then ns.RenderAll() end
  end
end)

-- ====================================
-- \UI\Cooldown.lua
-- ====================================
-- This file manages the visual representation of cooldowns on buttons.

local addonName, ns = ...
ns = ns or {}
_G[addonName] = ns

local function nowPrecise() return GetTimePreciseSec() end

-- Calculates font size based on button size.
local function scaledFont(btn, base)
  local db = ns.GetDB()
  local w = (btn and btn:GetWidth()) or (db and db.iconSize) or 50
  return math.floor((base or 14) * (w / 50))
end

-- Formats time for item cooldowns.
local function fmt_center_item(seconds)
  local r = math.max(0, seconds)
  if r >= 60 then
    local m = math.floor(r / 60)
    local s = math.floor(r % 60)
    return string.format("%d:%02d", m, s)
  else
    return tostring(math.ceil(r))
  end
end

-- Formats time for eating duration.
local function fmt_center_eating(seconds)
  return tostring(math.max(0, math.ceil(seconds)))
end

-- Ensures a cooldown frame exists for the button.
local function ensureCooldown(btn)
  if btn.cooldown then return btn.cooldown end
  local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
  cd:ClearAllPoints()
  cd:SetPoint("TOPLEFT",     btn, "TOPLEFT",     1, -1)
  cd:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1,  1)
  cd:SetDrawBling(false)
  cd:SetDrawEdge(true)
  cd:SetReverse(false)
  cd:SetHideCountdownNumbers(true)
  cd:SetFrameLevel(btn:GetFrameLevel() + 1)
  if cd.SetEdgeTexture then cd:SetEdgeTexture("Interface\\Cooldown\\edge") end
  if cd.SetUseCircularEdge then cd:SetUseCircularEdge(true) end
  if cd.SetEdgeColor then cd:SetEdgeColor(1, 0.9, 0.1, 1) end
  cd:Hide()
  btn.cooldown = cd
  return cd
end

-- Sets visual properties for the cooldown swipe.
local function setSwipeVisuals(cd)
  if cd.SetSwipeColor then cd:SetSwipeColor(1, 1, 1, 0.7) end
end

-- Desaturates the button icon (greyscale).
local function desaturateOn(btn)
  if btn.icon then
    btn.icon:SetDesaturated(true)
    btn.icon:SetVertexColor(1, 1, 1, 0.9)
  end
end

-- Restores the button icon color.
local function desaturateOff(btn)
  if btn.icon then
    btn.icon:SetDesaturated(false)
    btn.icon:SetVertexColor(1, 1, 1, 1)
  end
end

-- Updates the center text of the button.
local function setCenter(btn, text)
  if not (btn and btn.centerText) then return end
  local fs = btn.centerText
  local db = (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {}
  if fs.SetDrawLayer then fs:SetDrawLayer("OVERLAY", 7) end
  ns.UpdateFontString(
    fs,
    text or "",
    db.fontName or "Fonts\\FRIZQT__.TTF",
    db.timerSize or 28,
    db.timerOutline ~= false,
    db.timerTextColor or { r = 1, g = 1, b = 1, a = 1 }
  )
end

-- Applies a cooldown visual to a button based on an item entry.
function ns.ApplyItemCooldown(btn, entry)
  if not (btn and entry) then return end
  local start   = entry.cooldownStart
  local duration= entry.cooldownDuration
  if not (start and duration and duration > 0) then return end
  local cd = ensureCooldown(btn)
  setSwipeVisuals(cd)
  if btn._crb_swipe_start ~= start or btn._crb_swipe_dur ~= duration then
    cd:SetCooldown(start, duration)
    btn._crb_swipe_start = start
    btn._crb_swipe_dur   = duration
    cd:Show()
  else
    if not cd:IsShown() then cd:Show() end
  end
  desaturateOn(btn)
  btn._crb_cd_start = start
  btn._crb_cd_dur   = duration
  btn._crb_center_from_cd = true
  if btn.centerText and btn.centerText.SetDrawLayer then
    btn.centerText:SetDrawLayer("OVERLAY", 7)
  end
end

-- Clears the cooldown visual from a button.
function ns.ClearCooldownVisual(btn)
  if not btn then return end

  if btn.cooldown then btn.cooldown:Hide() end
  local wasFromCD = btn._crb_center_from_cd == true

  btn._crb_swipe_start     = nil
  btn._crb_swipe_dur       = nil
  btn._crb_cd_start        = nil
  btn._crb_cd_dur          = nil
  btn._crb_cd_last_string  = nil
  btn._crb_center_from_cd  = nil

  desaturateOff(btn)

  local entry = btn._crb_entry
  if not btn.centerText then return end

  if entry and entry.qty == false then
    btn.centerText:SetText("")
    return
  end

  if wasFromCD and entry and entry.centerText ~= nil then
    local db = (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {}
    ns.UpdateFontString(
      btn.centerText, tostring(entry.centerText),
      db.fontName or "Fonts\\FRIZQT__.TTF",
      db.timerSize or 28,
      db.timerOutline ~= false,
      db.timerTextColor or { r = 1, g = 1, b = 1, a = 1 }
    )
  end
end

-- Updates the cooldown timer text on each tick.
function ns.CooldownTick(btn)
  if not (btn and btn._crb_cd_start and btn._crb_cd_dur) then return end
  local endAt = btn._crb_cd_start + btn._crb_cd_dur
  local rem   = endAt - GetTimePreciseSec()
  if rem > 0 then
    local text
    if btn._crb_entry and btn._crb_entry.category == "EATING" then
      text = tostring(math.max(0, math.ceil(rem + 0.05)))
    else
      local r = math.max(0, rem + 0.05)
      if r >= 60 then
        local m = math.floor(r / 60)
        local s = math.floor(r % 60)
        text = (m .. ":" .. (s < 10 and ("0" .. s) or s))
      else
        text = tostring(math.ceil(r))
      end
    end
    if text ~= btn._crb_cd_last_string then
      local fs = btn.centerText
      if fs then
        local db = (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {}
        ns.UpdateFontString(fs, text,
          db.fontName or "Fonts\\FRIZQT__.TTF",
          db.timerSize or 28,
          db.timerOutline ~= false,
          db.timerTextColor or { r=1,g=1,b=1,a=1 })
      end
      btn._crb_cd_last_string = text
    end
  else
    ns.ClearCooldownVisual(btn)
  end
end

-- Refreshes cooldown info for an item button.
function ns.RefreshCooldownForButton(btn)
  if not (btn and btn._crb_entry) then return end
  local e = btn._crb_entry
  if not e.itemID then return end
  local start, duration, enable = C_Container.GetItemCooldown(e.itemID)
  if enable == 1 and duration and duration >= 1.5 and start and start > 0 then
    e.cooldownStart    = start
    e.cooldownDuration = duration
    ns.ApplyItemCooldown(btn, e)
  else
    e.cooldownStart, e.cooldownDuration = nil, nil
    ns.ClearCooldownVisual(btn)
  end
end

-- Refreshes cooldown info for a spell button.
function ns.RefreshSpellCooldownForButton(btn)
  if not (btn and btn._crb_entry) then return end
  local e = btn._crb_entry
  if not e.spellID then return end
  local info = C_Spell.GetSpellCooldown(e.spellID)
  local start   = info and info.startTime or 0
  local duration= info and info.duration  or 0
  local enabled = info and info.isEnabled
  if enabled and start > 0 and duration and duration >= 1.5 then
    e.cooldownStart    = start
    e.cooldownDuration = duration
    ns.ApplyItemCooldown(btn, e)
  else
    e.cooldownStart, e.cooldownDuration = nil, nil
    ns.ClearCooldownVisual(btn)
  end
end

-- Refreshes cooldowns for all active buttons.
function ns.Cooldown_RefreshAll()
  local frames = ns.RenderFrames
  if not frames then return end

  for _, btn in ipairs(frames) do
    if btn:IsShown() then
      local e = btn._crb_entry

      if ns.RefreshCooldownForButton then
        ns.RefreshCooldownForButton(btn)
      end

      if ns.RefreshSpellCooldownForButton then
        ns.RefreshSpellCooldownForButton(btn)
      end

      if e and e.cooldownStart and e.cooldownDuration and e.cooldownDuration > 0 then
        ns.ApplyItemCooldown(btn, e)
      end
    end
  end

  if ns.Timer_RecomputeSchedule then
    ns.Timer_RecomputeSchedule()
  end
end

-- Hooks RefreshFonts to update center text.
local function HookRefreshFonts()
  if ns._crb_rf_wrapped then return end
  if type(ns.RefreshFonts) == "function" then
    local orig = ns.RefreshFonts
    ns.RefreshFonts = function(...)
      local r = orig(...)
      local frames = ns.RenderFrames
      if frames then
        for _, btn in ipairs(frames) do
          if btn:IsShown() and btn.centerText then
            local t = btn.centerText:GetText() or ""
            setCenter(btn, t)
          end
        end
      end
      return r
    end
    ns._crb_rf_wrapped = true
  end
end
HookRefreshFonts()
C_Timer.After(0.10, HookRefreshFonts)
C_Timer.After(1.0, HookRefreshFonts)

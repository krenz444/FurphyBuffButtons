-- ====================================
-- \UI\Timer.lua
-- ====================================
-- This file handles the display of timers on buttons (e.g., buff duration, cooldowns).

local addonName, ns = ...
ns = ns or {}

local function now() return GetTimePreciseSec() end

-- Formats remaining time into a string (e.g., "1:30").
local function fmt_bottom(remaining)
  remaining = math.max(0, remaining)
  local m = math.floor(remaining / 60)
  local s = math.floor(remaining % 60)
  if m <= 0 then
    return ("0:%02d"):format(s)
  else
    return ("%d:%02d"):format(m, s)
  end
end

-- Updates the timer text displayed below a button.
local function updateBottomTimer(btn, entry, tNow)
  local tt = btn and btn.timerText
  if not (tt and entry) then return end

  local function ensureAnchor()
    local bt = btn.bottomText
    local hasBottom = bt and bt:IsShown() and (bt:GetText() or "") ~= ""

    if hasBottom then
      if tt._crb_anchor_mode ~= "under_bottom" then
        tt:ClearAllPoints()
        tt:SetPoint("TOP", bt, "BOTTOM", 0, -2) -- small gap when both are present
        tt._crb_anchor_mode = "under_bottom"
      end
    else
      if tt._crb_anchor_mode ~= "under_button" then
        tt:ClearAllPoints()
        tt:SetPoint("TOP", btn, "BOTTOM", 0, -5) -- aligned with label position when no bottom label
        tt._crb_anchor_mode = "under_button"
      end
    end
  end

  if entry.category ~= "EATING" and entry.expireTime and entry.expireTime ~= math.huge then
    local remaining = entry.expireTime - tNow

    if entry.category == "AUGMENT_RUNE" then
      if remaining > 0 then
        ensureAnchor()
        local formatted = fmt_bottom(remaining)
        if tt:GetText() ~= formatted then
          local db = (ns.GetDB and ns.GetDB()) or {}
          ns.UpdateFontString(tt, formatted,
            db.fontName or "Fonts\\FRIZQT__.TTF",
            db.timerBottomSize or 14,
            db.timerBottomOutline ~= false,
            db.timerBottomColor or { r=1,g=1,b=1,a=1 })
        end
        if not tt:IsShown() then tt:Show() end
        return
      end
    else
      if remaining > -1 then
        ensureAnchor()
        local formatted = fmt_bottom(remaining)
        if tt:GetText() ~= formatted then
          local db = (ns.GetDB and ns.GetDB()) or {}
          ns.UpdateFontString(tt, formatted,
            db.fontName or "Fonts\\FRIZQT__.TTF",
            db.timerBottomSize or 12,
            db.timerBottomOutline ~= false,
            db.timerBottomColor or { r=1,g=1,b=1,a=1 })
        end
        if not tt:IsShown() then tt:Show() end
        return
      end
    end
  end

  if tt:IsShown() then tt:Hide() end
end


local _ticker

-- Stops the update ticker.
local function stopTicker()
  if _ticker and _ticker.Cancel then _ticker:Cancel() end
  _ticker = nil
end

-- Checks if any timers are currently active.
local function anyActive(tNow)
  local frames = ns.RenderFrames
  if not (frames and #frames > 0) then return false end
  for i=1,#frames do
    local btn = frames[i]
    if btn and btn:IsShown() then
      if btn._crb_cd_start and btn._crb_cd_dur then
        local endsAt = btn._crb_cd_start + btn._crb_cd_dur
        if endsAt - tNow > 0 then return true end
      end
      local e = btn._crb_entry
      if e and e.category ~= "EATING" and e.expireTime and e.expireTime ~= math.huge then
        local rem = e.expireTime - tNow
        if e.category == "AUGMENT_RUNE" then
          if rem > 0 then return true end
        else
          if rem > -1 then return true end
        end
      end
    end
  end
  local disp = _G.clickableRaidBuffCache and _G.clickableRaidBuffCache.displayable
  local aug  = disp and disp.AUGMENT_RUNE
  if type(aug) == "table" then
    for _, e in pairs(aug) do
      if e and e.showAt and (e.showAt - tNow) > 0 then return true end
      if e and e.showAt and (e.showAt - tNow) <= 0 then return true end
    end
  end
  return false
end

-- The ticker function that updates timers.
-- Skipped during combat.
local function tick()
  if ns._inCombat or (IsEncounterInProgress and IsEncounterInProgress()) or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) or InCombatLockdown() then
    stopTicker()
    return
  end

  local t2 = now()

  local disp = _G.clickableRaidBuffCache and _G.clickableRaidBuffCache.displayable
  local aug  = disp and disp.AUGMENT_RUNE
  if type(aug) == "table" then
    local due
    for _, e in pairs(aug) do
      if e and e.showAt and (e.showAt - t2) <= 0 then
        due = true
        break
      end
    end
    if due and type(ns.UpdateAugmentRunes) == "function" then
      ns.UpdateAugmentRunes()
    end
  end

  local frames = ns.RenderFrames
  if frames then
    for i=1,#frames do
      local btn = frames[i]
      if btn and btn:IsShown() then
        if ns.CooldownTick and btn._crb_cd_start and btn._crb_cd_dur then
          ns.CooldownTick(btn)
        end
        local e = btn._crb_entry
        if e then
          updateBottomTimer(btn, e, t2)
          if e.category ~= "EATING" and e.expireTime and e.expireTime ~= math.huge then
            if e.category == "AUGMENT_RUNE" then
              if (t2 - e.expireTime) >= 0 then
                if type(ns.UpdateAugmentRunes) == "function" then ns.UpdateAugmentRunes() end
              end
            else
              if (t2 - e.expireTime) >= 1.0 then
                btn:Hide()
              end
            end
          end
        end
      end
    end
  end

  if not anyActive(now()) then
    stopTicker()
  end
end

-- Starts or stops the timer ticker based on activity.
-- Skipped during combat.
function ns.Timer_RecomputeSchedule()
  if ns._inCombat or (IsEncounterInProgress and IsEncounterInProgress()) or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) or InCombatLockdown() then
    stopTicker()
    return
  end
  if not _ticker then
    if anyActive(now()) then
      _ticker = C_Timer.NewTicker(0.2, tick)
    end
  end
end

-- Stops the timer ticker.
function ns.Timer_Stop()
  stopTicker()
end

-- Hooks Cooldown_RefreshAll to recompute timer schedule.
do
  if type(ns.Cooldown_RefreshAll) == "function" and not ns._crb_cd_refresh_wrapped then
    local _orig = ns.Cooldown_RefreshAll
    ns.Cooldown_RefreshAll = function(...)
      local r = _orig(...)
      if ns.Timer_RecomputeSchedule then ns.Timer_RecomputeSchedule() end
      return r
    end
    ns._crb_cd_refresh_wrapped = true
  end
end

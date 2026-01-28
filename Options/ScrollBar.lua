-- ====================================
-- \Options\ScrollBar.lua
-- ====================================
-- This file implements a custom scrollbar for the options panel.

local addonName, ns = ...
ns.ScrollBar = ns.ScrollBar or {}

local CFG = {
  width          = 14, 
  sliderWidth    = 14,
  minThumbH      = 22,
  stepSmall      = 24,
  pageFrac       = 0.9,
  padTrackTop    = 2,
  padTrackBottom = 2,
}

-- Clamps a value between a minimum and maximum.
local function clamp(v, lo, hi)
  if v < lo then return lo elseif v > hi then return hi else return v end
end

-- Creates a new scrollbar frame.
function ns.ScrollBar.Create(parent, opts)
  opts = opts or {}
  local W    = opts.width       or CFG.width
  local SW   = opts.sliderWidth or CFG.sliderWidth
  local MINH = opts.minThumbH   or CFG.minThumbH
  local STEP = opts.stepSmall   or CFG.stepSmall

  local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  bar:SetWidth(W)

  local up = CreateFrame("Button", nil, bar)
  up:SetSize(W, W)
  local upTex = up:CreateTexture(nil, "ARTWORK")
  upTex:SetAtlas("minimal-scrollbar-arrow-top-down", true)
  upTex:SetPoint("CENTER")

  local down = CreateFrame("Button", nil, bar)
  down:SetSize(W, W)
  local downTex = down:CreateTexture(nil, "ARTWORK")
  downTex:SetAtlas("minimal-scrollbar-arrow-bottom-down", true)
  downTex:SetPoint("CENTER")

  up:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
  down:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)

  local track = CreateFrame("Button", nil, bar, "BackdropTemplate")
  track:SetPoint("TOP",    up,   "BOTTOM", 0, -CFG.padTrackTop)
  track:SetPoint("BOTTOM", down, "TOP",    0,  CFG.padTrackBottom)
  track:SetWidth(SW)
  track:EnableMouse(true)
  track:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8" })
  track:SetBackdropColor(0.10,0.115,0.16, 0.9)

  local slider = CreateFrame("Slider", nil, track)
  slider:SetOrientation("VERTICAL")
  slider:SetAllPoints(track)
  slider:SetObeyStepOnDrag(false)
  slider:SetMinMaxValues(0, 0)
  slider:SetValue(0)

  local thumb = slider:CreateTexture(nil, "ARTWORK")
  thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
  thumb:SetColorTexture(0.75, 0.80, 0.90, 1)
  thumb:SetWidth(SW)
  slider:SetThumbTexture(thumb)

  local core = slider:CreateTexture(nil, "OVERLAY")
  core:SetTexture("Interface\\Buttons\\WHITE8x8")
  core:SetVertexColor(0.90, 0.94, 1.00, 1)
  core:SetPoint("CENTER", thumb, "CENTER", 0, 0)
  core:SetSize(SW - 4, MINH - 4)

  function bar:SetMinMaxValues(a, b) slider:SetMinMaxValues(a, b) end
  function bar:GetMinMaxValues() return slider:GetMinMaxValues() end
  function bar:SetValue(v) slider:SetValue(v) end
  function bar:GetValue() return slider:GetValue() end
  function bar:SetValueStep(s) slider:SetValueStep(s or STEP) end
  function bar:SetEnabledState(state)
    local alpha = state and 1 or 0.35
    up:SetEnabled(state); down:SetEnabled(state)
    up:SetAlpha(alpha);   down:SetAlpha(alpha)
    slider:EnableMouse(state and true or false)
    track:EnableMouse(state and true or false)
  end
  function bar:SetScript(evt, handler)
    if evt == "OnValueChanged" then
      bar._onValue = handler
    else
      getmetatable(bar).__index.SetScript(bar, evt, handler)
    end
  end

  function bar:UpdateThumb(viewH, contentH)
    local ratio = 1
    if contentH and contentH > 0 and viewH and viewH > 0 then
      ratio = math.min(1, viewH / contentH)
    end
    local th = math.max(MINH, (track:GetHeight() - 8) * ratio)
    thumb:SetHeight(th)
    core:SetHeight(math.max(8, th - 4))
    thumb:Show(); core:Show()
  end

  function bar:BindToScroll(scroll, content)
    bar._scroll = scroll
    bar._content = content
    slider:SetScript("OnValueChanged", function(_, v)
      if bar._scroll then bar._scroll:SetVerticalScroll(v) end
      if bar._onValue then bar._onValue(bar, v) end
      local lo, hi = slider:GetMinMaxValues()
      up:SetEnabled(v > lo); down:SetEnabled(v < hi)
      up:SetAlpha(up:IsEnabled() and 1 or 0.35)
      down:SetAlpha(down:IsEnabled() and 1 or 0.35)
    end)
    scroll:SetScript("OnScrollRangeChanged", function(s)
      local max = math.max(0, s:GetVerticalScrollRange())
      slider:SetMinMaxValues(0, max)
      bar:UpdateThumb(s:GetHeight(), content:GetHeight())
      bar:SetEnabledState(max > 0)
    end)
    scroll:HookScript("OnSizeChanged", function(s)
      local max = math.max(0, s:GetVerticalScrollRange())
      slider:SetMinMaxValues(0, max)
      bar:UpdateThumb(s:GetHeight(), content:GetHeight())
      bar:SetEnabledState(max > 0)
    end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
      local lo, hi = slider:GetMinMaxValues()
      local v = slider:GetValue() - delta * STEP
      slider:SetValue(clamp(v, lo, hi))
    end)
  end

  track:SetScript("OnMouseDown", function()
    local s = bar._scroll
    local viewH = s and s:GetHeight() or 200
    local page = viewH * CFG.pageFrac
    local lo, hi = slider:GetMinMaxValues()
    local scale = bar:GetEffectiveScale()
    local _, cy = GetCursorPosition(); cy = cy / scale
    local top, bot = track:GetTop() or 0, track:GetBottom() or 0
    local frac = 0; local h = (top - bot)
    if h > 0 then frac = clamp((top - cy) / h, 0, 1) end
    local target = lo + frac * (hi - lo)
    local v = slider:GetValue()
    if target > v then v = v + page else v = v - page end
    slider:SetValue(clamp(v, lo, hi))
  end)

  bar:EnableMouseWheel(true)
  bar:SetScript("OnMouseWheel", function(_, delta)
    local lo, hi = slider:GetMinMaxValues()
    local v = slider:GetValue() - delta * STEP
    slider:SetValue(clamp(v, lo, hi))
  end)

  local function nudge(dir)
    local lo, hi = slider:GetMinMaxValues()
    slider:SetValue(clamp(slider:GetValue() + dir * STEP, lo, hi))
  end
  local activeTicker
  local function startRepeat(dir)
    nudge(dir)
    activeTicker = C_Timer.NewTicker(0.06, function() nudge(dir) end)
  end
  local function stopRepeat()
    if activeTicker then activeTicker:Cancel(); activeTicker = nil end
  end
  up:SetScript("OnMouseDown", function(_, btn)
    if btn == "LeftButton" then startRepeat(-1) end
  end)
  up:SetScript("OnMouseUp", stopRepeat)
  up:SetScript("OnHide", stopRepeat)

  down:SetScript("OnMouseDown", function(_, btn)
    if btn == "LeftButton" then startRepeat(1) end
  end)
  down:SetScript("OnMouseUp", stopRepeat)
  down:SetScript("OnHide", stopRepeat)

  return bar
end

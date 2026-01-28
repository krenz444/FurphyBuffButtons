-- ====================================
-- \Modules\Alerts.lua
-- ====================================

local addonName, ns = ...

local function DefaultSoundName() return "Alerts: |cffff7d0Ffunki.gg|r Ding Dong" end
local function DB() return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {} end
local function RAID()
  local d = DB()
  d.raidAnnouncer = d.raidAnnouncer or {}
  local r = d.raidAnnouncer
  r.enabled = (r.enabled ~= false)
  r.customText = r.customText or {}
  r.anchor = r.anchor or { x=0, y=180 }
  r.soundName = r.soundName or DefaultSoundName()
  r.fontName = r.fontName or (ns.Options and ns.Options.GetDefault and ns.Options.GetDefault("fontName"))
  r.fontSize = (r.fontSize and r.fontSize > 0) and r.fontSize or 60
  r.fontColor = r.fontColor or { r=1, g=1, b=1 }
  r.disableInCombat = (r.disableInCombat == true)
  r.period    = tonumber(r.period)    or 0.75
  r.amplitude = tonumber(r.amplitude) or 50
  r.duration  = tonumber(r.duration)  or 4
  return r
end

local function LSM() local ok, lib = pcall(LibStub, "LibSharedMedia-3.0"); if ok then return lib end end
local function PanelFace() return (ns.Options and ns.Options.ResolvePanelFont and ns.Options.ResolvePanelFont()) or "Fonts\\FRIZQT__.TTF" end
local function GetFontPath()
  local r, lib = RAID(), LSM()
  if r.fontName and lib then
    local p = lib:Fetch("font", r.fontName, true)
    if p then return p end
  end
  return PanelFace()
end
local function GetFontSize()
  local r = RAID()
  if r.fontSize and r.fontSize > 0 then return r.fontSize end
  local h = UIParent and UIParent:GetHeight() or 1080
  return math.floor(math.max(28, math.min(128, h * 0.06)))
end
local function GetFontColor() local c = RAID().fontColor; return c.r or 1, c.g or 1, c.b or 1 end

local function PlayChosenSound()
  local name, lib = RAID().soundName or DefaultSoundName(), LSM()
  if lib then
    local path = lib:Fetch("sound", name, true)
    if path then PlaySoundFile(path, "Master"); return end
  end
  PlaySound(SOUNDKIT.RAID_WARNING, "Master")
end
ns.RaidAnnouncer_PlayPreview = PlayChosenSound

local SPELL_TO_KEY = {}
local function BuildSpellMap()
  wipe(SPELL_TO_KEY)
  local src = ClickableRaidData and ClickableRaidData["ANNOUNCER"]
  if not src then return end
  for key, entry in pairs(src) do
    if entry and entry.spellID then
      for i=1,#entry.spellID do SPELL_TO_KEY[entry.spellID[i]] = key end
    end
  end
end
BuildSpellMap()

local holder, mover, moverFS
local messages = {}
local PERIOD = RAID().period or 0.75
local AMPLITUDE = RAID().amplitude or 50
local DURATION = RAID().duration or 4

local function EnsureHolder()
  if holder then return end
  holder = CreateFrame("Frame", addonName.."AnnounceHolder", UIParent)
  holder:SetSize(1,1); holder:SetClampedToScreen(true)
  local a = RAID().anchor or {x=0,y=180}
  holder:SetPoint("CENTER", UIParent, "CENTER", a.x, a.y)

  holder._osc = CreateFrame("Frame", nil, holder)
  holder._osc:SetSize(1,1)
  holder._osc:SetPoint("CENTER", holder, "CENTER", 0, 0)
end

local function RowSpacing()
  local s = GetFontSize()
  return math.max(16, math.floor(s + 8))
end

local function LayoutMessages()
  if not holder or not holder._osc then return end
  local spacing = RowSpacing()
  for i=1,#messages do
    local f = messages[i]
    f:ClearAllPoints()
    f:SetPoint("CENTER", holder._osc, "CENTER", 0, (i-1)*spacing)
  end
end

local function FreeMessage(f)
  for i=#messages,1,-1 do
    if messages[i]==f then table.remove(messages, i) break end
  end
  f:Hide(); f:SetParent(nil)
  if #messages == 0 and holder and holder._osc then
    holder:SetScript("OnUpdate", nil)
    holder._osc:ClearAllPoints()
    holder._osc:SetPoint("CENTER", holder, "CENTER", 0, 0)
  else
    LayoutMessages()
  end
end

local function IsSuppressed()
  if UnitIsDeadOrGhost("player") then return true end
  local r = RAID()
  if r.disableInCombat then
    if (InCombatLockdown()) or (IsEncounterInProgress and IsEncounterInProgress()) then
      return true
    end
  end
  return false
end

local function NewMessage(text)
  if not RAID().enabled or IsSuppressed() then return end
  EnsureHolder()
  local f = CreateFrame("Frame", nil, holder)
  f:SetSize(600, 80)
  local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  fs:SetFont(GetFontPath(), GetFontSize(), "OUTLINE")
  fs:SetPoint("CENTER")
  fs:SetTextColor(GetFontColor())
  fs:SetJustifyH("CENTER"); fs:SetJustifyV("MIDDLE"); fs:SetWordWrap(false)
  fs:SetText(text or "")
  f.fs = fs
  f.expireAt = GetTime() + DURATION

  messages[#messages+1] = f
  LayoutMessages()

  if #messages == 1 then
    local start = GetTime()
    holder:SetScript("OnUpdate", function(self)
      local tNow = GetTime()
      local offset = math.sin(((tNow - start) / (PERIOD > 0.05 and PERIOD or 0.05)) * (2*math.pi)) * AMPLITUDE
      self._osc:ClearAllPoints()
      self._osc:SetPoint("CENTER", self, "CENTER", 0, offset)

      local removed
      for i=#messages,1,-1 do
        local m = messages[i]
        if tNow >= (m.expireAt or 0) then
          FreeMessage(m)
          removed = true
        end
      end
      if removed then LayoutMessages() end
    end)
  end

  f:Show()
end

function ns.RaidAnnouncer_ApplyFont()
  local face, size = GetFontPath(), GetFontSize()
  local r,g,b = GetFontColor()
  for i=1,#messages do messages[i].fs:SetFont(face, size, "OUTLINE"); messages[i].fs:SetTextColor(r,g,b) end
  if moverFS then moverFS:SetFont(face, size, "OUTLINE"); moverFS:SetTextColor(r,g,b) end
  LayoutMessages()
end

function ns.RaidAnnouncer_ApplyMotion()
  local r = RAID()
  PERIOD    = tonumber(r.period)    or 0.75
  AMPLITUDE = tonumber(r.amplitude) or 50
  DURATION  = tonumber(r.duration)  or 4
  local now = GetTime()
  for i=1,#messages do messages[i].expireAt = now + DURATION end
end

function ns.RaidAnnouncer_TeleportMover(x, y)
  EnsureHolder()
  RAID().anchor = { x = x or 0, y = y or 180 }
  holder:ClearAllPoints()
  holder:SetPoint("CENTER", UIParent, "CENTER", RAID().anchor.x, RAID().anchor.y)
  if holder._osc then
    holder._osc:ClearAllPoints()
    holder._osc:SetPoint("CENTER", holder, "CENTER", 0, 0)
  end
  if mover then mover:ClearAllPoints(); mover:SetPoint("CENTER", holder, "CENTER") end
end

local function Nudge(dx, dy)
  local a = RAID().anchor
  a.x, a.y = (a.x or 0) + dx, (a.y or 180) + dy
  holder:ClearAllPoints()
  holder:SetPoint("CENTER", UIParent, "CENTER", a.x, a.y)
  if mover then mover:ClearAllPoints(); mover:SetPoint("CENTER", holder, "CENTER") end
end

function ns.RaidAnnouncer_ToggleMover(show)
  if not RAID().enabled then return end
  EnsureHolder()
  if show then
    if not mover then
      mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
      mover:SetSize(600, 120); mover:SetFrameStrata("DIALOG")
      mover:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
      mover:SetBackdropColor(0,0.25,0.60,0.08); mover:SetBackdropBorderColor(0.2,0.65,1,1)
      mover:SetMovable(true); mover:EnableMouse(true); mover:RegisterForDrag("LeftButton"); mover:SetClampedToScreen(true)
      mover:SetPoint("CENTER", holder, "CENTER", 0, 0)
      mover:SetScript("OnDragStart", function(self) self:StartMoving() end)
      mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cx, cy = self:GetCenter(); local ux, uy = UIParent:GetCenter()
        local dx, dy = cx-ux, cy-uy
        RAID().anchor = { x=math.floor(dx+0.5), y=math.floor(dy+0.5) }
        holder:ClearAllPoints(); holder:SetPoint("CENTER", UIParent, "CENTER", RAID().anchor.x, RAID().anchor.y)
      end)
      moverFS = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
      moverFS:SetFont(GetFontPath(), GetFontSize(), "OUTLINE")
      moverFS:SetPoint("CENTER")
      do local r,g,b = GetFontColor(); moverFS:SetTextColor(r,g,b) end
      moverFS:SetText("Clickable Raid Buffs")
      local start = GetTime()
      mover:SetScript("OnUpdate", function()
        local t = GetTime() - start
        local offset = math.sin((t / (PERIOD > 0.05 and PERIOD or 0.05)) * (2*math.pi)) * AMPLITUDE
        moverFS:ClearAllPoints(); moverFS:SetPoint("CENTER", 0, offset)
      end)
      local panelFont = (ns.Options and ns.Options.ResolvePanelFont and ns.Options.ResolvePanelFont()) or "Fonts\\FRIZQT__.TTF"
      local function makeTextButton(prev, label, onClick)
        local b = CreateFrame("Button", nil, mover, "BackdropTemplate")
        b:SetHeight(20)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("BOTTOMLEFT", mover, "BOTTOMLEFT", 6, 6) end
        b:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
        b:SetBackdropColor(0.12,0.18,0.28,0.9)
        b:SetBackdropBorderColor(0.20,0.32,0.50,1)
        local fs = b:CreateFontString(nil, "ARTWORK")
        fs:SetFont(panelFont, 12, "")
        fs:SetPoint("CENTER")
        fs:SetText(label)
        b:SetFontString(fs)
        b:SetWidth(fs:GetStringWidth() + 12)
        b:SetScript("OnClick", onClick)
        return b
      end
      local lockBtn = makeTextButton(nil, "Lock", function()
        if ns.RaidAnnouncer_UpdateUnlockCheckbox then ns.RaidAnnouncer_UpdateUnlockCheckbox(false) end
        ns.RaidAnnouncer_ToggleMover(false)
      end)
      local centerHBtn = makeTextButton(lockBtn, "Center Horizontal", function()
        ns.RaidAnnouncer_TeleportMover(0, RAID().anchor.y or 180)
      end)
      local centerVBtn = makeTextButton(centerHBtn, "Center Vertical", function()
        ns.RaidAnnouncer_TeleportMover(RAID().anchor.x or 0, 0)
      end)
      local function makeArrow(prev, dx, dy, angle)
        local b = CreateFrame("Button", nil, mover)
        b:SetSize(20, 20)
        b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
        local tex = b:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetAtlas("uitools-icon-chevron-down")
        tex:SetRotation(math.rad(angle))
        b:SetScript("OnEnter", function() tex:SetVertexColor(1,1,0) end)
        b:SetScript("OnLeave", function() tex:SetVertexColor(1,1,1) end)
        b:SetScript("OnClick", function() Nudge(dx, dy) end)
        return b
      end
      local leftBtn = makeArrow(centerVBtn, -1, 0, -90)
      local upBtn = makeArrow(leftBtn, 0, 1, 180)
      local downBtn = makeArrow(upBtn, 0, -1, 0)
      local rightBtn = makeArrow(downBtn, 1, 0, 90)
      local resetBtn = CreateFrame("Button", nil, mover)
      resetBtn:SetPoint("BOTTOMRIGHT", mover, "BOTTOMRIGHT", -6, 6)
      resetBtn:SetSize(18, 18)
      local rtex = resetBtn:CreateTexture(nil, "ARTWORK")
      rtex:SetAllPoints(resetBtn)
      rtex:SetAtlas("common-icon-undo", true)
      resetBtn:SetScript("OnClick", function()
        local KEY = "CRB_RA_CONFIRM_RESET"
        if not StaticPopupDialogs[KEY] then
          StaticPopupDialogs[KEY] = { text = "Reset announcement position to default?", button1 = YES, button2 = NO,
            OnAccept = function() ns.RaidAnnouncer_TeleportMover(0, 180) end, timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3 }
        end
        StaticPopup_Show(KEY)
      end)
    end
    mover:Show()
  else
    if mover then mover:Hide() end
  end
end

local function IsGroupUnit(u)
  if u == "player" then return true end
  if u and (string.match(u, "^party%d+$") or string.match(u, "^raid%d+$")) then return true end
  return false
end

local function ResolveText(key, spellID)
  if key == "PORTAL" then
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    return (info and info.name) or "Portal Open"
  end
  return RAID().customText[key]
    or ((ClickableRaidData and ClickableRaidData["ANNOUNCER"] and ClickableRaidData["ANNOUNCER"][key] and ClickableRaidData["ANNOUNCER"][key].text)
    or key)
end

local throttleActive, throttleTimer
local queue = {}

local function ProcessOne(key, spellID)
  local txt = ResolveText(key, spellID)
  PlayChosenSound()
  NewMessage(txt)
end

local function FlushQueue()
  throttleActive = false
  throttleTimer = nil
  if not RAID().enabled or IsSuppressed() then wipe(queue); return end
  if #queue == 0 then return end
  local items = queue
  queue = {}
  for i=1,#items do
    local it = items[i]
    ProcessOne(it.key, it.spellID)
  end
end

local recent = {}
local function AnnounceWhitelisted(spellID, srcGUID)
  if issecretvalue and issecretvalue(spellID) then return end
  if not RAID().enabled or IsSuppressed() then return end
  local inInst, instType = IsInInstance()
  if not inInst or (instType ~= "raid" and instType ~= "party") then return end
  local key = SPELL_TO_KEY[spellID]; if not key then return end
  if srcGUID then
    local t = GetTime()
    recent[srcGUID] = recent[srcGUID] or {}
    local last = recent[srcGUID][spellID]
    if last and (t - last) < 1.0 then return end
    recent[srcGUID][spellID] = t
  end
  if throttleActive then
    queue[#queue+1] = { key = key, spellID = spellID }
    return
  end
  ProcessOne(key, spellID)
  throttleActive = true
  throttleTimer = C_Timer.After(1, FlushQueue)
end

local function HandleCast(unit, spellID)
  if not IsGroupUnit(unit) then return end
  AnnounceWhitelisted(spellID, UnitGUID(unit))
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:SetScript("OnEvent", function(_, ev, arg1, arg2, arg3)
  if ev == "PLAYER_LOGIN" then
    EnsureHolder(); BuildSpellMap()
  elseif ev == "PLAYER_ENTERING_WORLD" then
    EnsureHolder()
    local a = RAID().anchor or {x=0,y=180}
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", UIParent, "CENTER", a.x, a.y)
    if holder._osc then
      holder._osc:ClearAllPoints()
      holder._osc:SetPoint("CENTER", holder, "CENTER", 0, 0)
    end
  elseif ev == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, spellID = arg1, arg3
    HandleCast(unit, spellID)
  end
end)

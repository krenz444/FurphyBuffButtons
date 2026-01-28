-- ====================================
-- \Modules\Exclusions.lua
-- ====================================
-- This module manages the exclusion list, allowing users to hide specific buffs or items.

local addonName, ns = ...

local function DB() return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {} end
local function _ExSet() local d = DB(); d.exclusions = d.exclusions or {}; return d.exclusions end

-- Checks if an ID is excluded.
function ns.IsExcluded(id)
  if not id then return false end
  local d = (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {}
  local ex = d.exclusions
  local rb = d.raidBuffExclusions
  if ex and ex[id] then return true end
  if rb and rb[id] then return true end
  return false
end

-- Checks if an ID should be considered (not excluded).
function ns.ShouldConsider(id)
  return not ns.IsExcluded(id)
end

-- Checks if a displayable entry is excluded.
function ns.IsDisplayableExcluded(cat, entry)
  local d = (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {}
  d.exclusions = d.exclusions or {}
  d.raidBuffExclusions = d.raidBuffExclusions or {}

  local id
  if cat == "SHAMAN_SHIELDS" then
    id = entry and (entry.spellID or entry.id)
  else
    id = entry and (entry.id or entry.spellID or entry.itemID)
  end
  if not id then return false end

  local useRaidBuffSet = (cat == "RAID_BUFFS" or cat == "CLASS_ABILITIES" or cat == "TRINKET_RB" or cat == "SHAMAN_SHIELDS")
  if useRaidBuffSet then
    return (d.raidBuffExclusions[id] or d.exclusions[id]) and true or false
  else
    return (d.exclusions[id] or d.raidBuffExclusions[id]) and true or false
  end
end

-- Helper to extract an ID from a frame.
local function _maybeIDFromFrame(f)
  if not f then return nil end
  if f.itemID then return f.itemID end
  if f.spellID then return f.spellID end
  if f.id     then return f.id end
  if f._data  then
    if f._data.itemID then return f._data.itemID end
    if f._data.spellID then return f._data.spellID end
    if f._data.id     then return f._data.id end
  end
  if f.key and type(f.key) ~= "string" then return f.key end
  return nil
end

-- Prunes excluded items from the render collections.
local function _pruneRenderCollections()
  local changed = false
  local RF = ns.RenderFrames
  if type(RF) == "table" then
    for i = #RF, 1, -1 do
      local fr = RF[i]
      local id = _maybeIDFromFrame(fr)
      if id and ns.IsExcluded(id) then
        if fr.Hide then fr:Hide() end
        RF[i] = nil
        changed = true
      end
    end
  end
  local RIK = ns.RenderIndexByKey
  if type(RIK) == "table" then
    for k,_ in pairs(RIK) do
      local id = (type(k)=="number") and k or nil
      if id and ns.IsExcluded(id) then
        RIK[k] = nil
        changed = true
      end
    end
  end
  return changed
end

-- Helper to wrap functions with post-execution logic.
local function _wrapOnce(tbl, key, flagKey, post)
  if not tbl or not key or tbl[flagKey] then return end
  local orig = tbl[key]
  if type(orig) ~= "function" then return end
  tbl[flagKey] = true
  tbl[key] = function(...)
    local r1, r2, r3 = orig(...)
    if type(post) == "function" then post() end
    return r1, r2, r3
  end
end

-- Wrap render functions to ensure exclusions are applied.
_wrapOnce(ns, "PushRender",          "_ex_wrap_pr1", _pruneRenderCollections)
_wrapOnce(ns, "RenderAll",           "_ex_wrap_pr2", _pruneRenderCollections)
_wrapOnce(ns, "RebuildDisplayables", "_ex_wrap_pr3", _pruneRenderCollections)
_wrapOnce(ns, "RefreshEverything",   "_ex_wrap_pr4", _pruneRenderCollections)

-- Prune on login.
local _loginF = CreateFrame("Frame")
_loginF:RegisterEvent("PLAYER_ENTERING_WORLD")
_loginF:SetScript("OnEvent", function() C_Timer.After(0, _pruneRenderCollections) end)

local _pendingRefresh
-- Triggers a refresh of exclusions and rendering.
function ns.Exclusions_RefreshNow()
  if _pendingRefresh then return end
  _pendingRefresh = true
  C_Timer.After(0.05, function()
    _pendingRefresh = false
    if type(_G.scanAllBags) == "function" then _G.scanAllBags() end
    _pruneRenderCollections()
    if ns.RenderAll then ns.RenderAll()
    elseif ns.PushRender then ns.PushRender()
    elseif _G.ClickableRaidBuffs_PushRender then _G.ClickableRaidBuffs_PushRender()
    end
  end)
end

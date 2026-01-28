-- ====================================
-- \Modules\Pets.lua
-- ====================================
-- This module handles the display of pet-related actions for Hunters (Call Pet, Revive Pet).

local addonName, ns = ...
clickableRaidBuffCache = clickableRaidBuffCache or {}
clickableRaidBuffCache.displayable = clickableRaidBuffCache.displayable or {}

local HUNTER_CLASSID = 3
local HUNTER_DISABLE_PETS_SPELL = 1223323

local function InCombat() return InCombatLockdown() end

local function DB() return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {} end
local function HPDB() local d = DB(); d.hunterPets = d.hunterPets or {}; return d.hunterPets end

-- Checks if a spell is known by the player.
local function KnowSpell(id)
  if not id then return false end
  if IsPlayerSpell then return IsPlayerSpell(id) end
  return IsSpellKnown and IsSpellKnown(id) or false
end

-- Ensures the display category for pets exists.
local function ensureDisplayCat(cat)
  clickableRaidBuffCache.displayable[cat] = clickableRaidBuffCache.displayable[cat] or {}
  return clickableRaidBuffCache.displayable[cat]
end

-- Clears the pet display category.
local function clearDisplayCat(cat)
  if clickableRaidBuffCache.displayable[cat] then wipe(clickableRaidBuffCache.displayable[cat]) end
end

-- Checks if the player has a usable pet active.
-- Assumes true in combat to avoid hiding buttons erroneously.
local function HasUsablePet()
  if InCombat() then return true end -- Assume true in combat to avoid hiding if checks fail
  if not UnitExists("pet") then return false end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("pet") then return false end
  if not UnitIsVisible("pet") then return false end
  return true
end

-- Retrieves the player's class ID.
-- Returns cached value during combat.
local function PlayerClassID()
  if InCombat() then return clickableRaidBuffCache.playerInfo and clickableRaidBuffCache.playerInfo.playerClassId end
  return (clickableRaidBuffCache.playerInfo and clickableRaidBuffCache.playerInfo.playerClassId)
         or (type(getPlayerClass)=="function" and getPlayerClass())
end

-- Mapping of Call Pet spell IDs to stable slot indices.
local CALLPET_NATURAL_SLOT = {
  [883]   = 1,
  [83242] = 2,
  [83243] = 3,
  [83244] = 4,
  [83245] = 5,
}
local function callpetNaturalSlotForSpell(sid) return CALLPET_NATURAL_SLOT[sid] end

-- Checks if a stable slot has a pet assigned.
local function hunterSlotHasPet(slotIndex)
  if not slotIndex then return false end
  local info = C_StableInfo and C_StableInfo.GetStablePetInfo and C_StableInfo.GetStablePetInfo(slotIndex)
  if not info then return false end
  local n   = info.name or info.petName or info.customName
  local cid = info.creatureID or info.displayID or info.speciesID
  return (n and n ~= "") or (cid and cid ~= 0)
end

-- Returns the atlas texture for a hunter pet spec.
local function atlasForHunterSpec(specID)
  local hp = HPDB()
  if hp.displayTalentsSymbol == false then return nil end
  if specID == 79 then return "cunning-icon-small"  end
  if specID == 74 then return "ferocity-icon-small" end
  if specID == 81 then return "tenacity-icon-small" end
  return nil
end

-- Returns the ability icon for a hunter pet spec.
local function abilityIconForSpec(specID)
  if specID == 79 then return 348567 end
  if specID == 74 then return 136224 end
  if specID == 81 then return 571585 end
  return nil
end

-- Updates cooldown information for a spell entry.
local function applySpellCooldownFields(entry, spellID)
  local info = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spellID)
  local start = info and info.startTime or 0
  local duration = info and info.duration or 0
  local enabled = info and info.isEnabled
  if enabled and start > 0 and duration and duration >= 1.5 then
    entry.cooldownStart    = start
    entry.cooldownDuration = duration
  else
    entry.cooldownStart    = nil
    entry.cooldownDuration = nil
  end
end

-- Checks if a pet spell is excluded by user settings.
local function IsExcludedPets(id)
  if type(ns.IsExcluded) == "function" then return ns.IsExcluded(id, "PETS") end
  return false
end

-- Checks if the player is a Marksmanship Hunter without the Unbreakable Bond talent.
local function IsMMWithoutUnbreakableBond()
  if PlayerClassID() ~= HUNTER_CLASSID then return false end
  if not GetSpecialization or not GetSpecializationInfo then return false end
  local spec = GetSpecialization()
  if not spec then return false end
  local specID = select(1, GetSpecializationInfo(spec))
  if specID ~= 254 then return false end
  return KnowSpell(HUNTER_DISABLE_PETS_SPELL)
end

-- Rebuilds the list of pet actions to display.
-- Skipped during combat.
local function buildPets()
  if InCombat() then return end

  local classID = PlayerClassID()
  local tbl = ClickableRaidData and ClickableRaidData["PETS"]
  if not tbl then clearDisplayCat("PETS"); return end
  if HasUsablePet() then clearDisplayCat("PETS"); return end

  local out = ensureDisplayCat("PETS")
  wipe(out)

  local hp = HPDB()

  -- Group ignore: only for Call Pet 15 (NOT Revive Pet)
  local ignoreHunterGroup = false
  if type(ns.IsExcluded) == "function" then
    ignoreHunterGroup = ns.IsExcluded(-7001, "PETS") and true or false
  end

  -- MM rule: hide only if MM (254) AND the Unbreakable Bond spell is NOT known
  local mmWithoutUnbreakable = false
  if classID == HUNTER_CLASSID and GetSpecialization and GetSpecializationInfo then
    local spec = GetSpecialization()
    if spec then
      local specID = select(1, GetSpecializationInfo(spec))
      if specID == 254 then
        local known = false
        if C_SpellBook and C_SpellBook.IsSpellKnown then
          known = C_SpellBook.IsSpellKnown(HUNTER_DISABLE_PETS_SPELL) and true or false
        elseif IsSpellKnownOrOverridesKnown then
          known = IsSpellKnownOrOverridesKnown(HUNTER_DISABLE_PETS_SPELL) and true or false
        elseif IsPlayerSpell then
          known = IsPlayerSpell(HUNTER_DISABLE_PETS_SPELL) and true or false
        elseif IsSpellKnown then
          known = IsSpellKnown(HUNTER_DISABLE_PETS_SPELL) and true or false
        end
        mmWithoutUnbreakable = not known
      end
    end
  end

  for keySpellID, row in pairs(tbl) do
    local sid = (type(keySpellID) == "number") and keySpellID or (row and row.spellID)
    if sid and KnowSpell(sid) and ns.PassesGates(row, nil, nil, nil) then
      if classID == HUNTER_CLASSID then
        local realSlot = callpetNaturalSlotForSpell(sid)
        if realSlot then
          -- Call Pet 15: suppressed by group ignore (-7001) and by MM-without-talent
          if hunterSlotHasPet(realSlot) and not ignoreHunterGroup and not mmWithoutUnbreakable then
            local e = ns.copyItemData(row)
            e.category = "PETS"

            local sinfo = C_StableInfo and C_StableInfo.GetStablePetInfo and C_StableInfo.GetStablePetInfo(realSlot)
            if sinfo and sinfo.specID then
              local atlas = atlasForHunterSpec(sinfo.specID)
              if atlas then
                e.specAtlas = atlas
                e.rankAtlas = atlas
              else
                e.specAtlas = nil
                e.rankAtlas = nil
              end

              if hp.useAbilityIcon == true then
                e.icon = abilityIconForSpec(sinfo.specID) or nil
              else
                e.icon = nil
              end

              if hp.showAbilityOnMouseover ~= false then
                e.hoverIcon = abilityIconForSpec(sinfo.specID)
              else
                e.hoverIcon = nil
              end
            else
              e.specAtlas = nil
              e.rankAtlas = nil
              e.icon      = nil
              e.hoverIcon = nil
            end

            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(sid)
            e.macro     = "/use " .. (info and info.name or "")
            e.spellID   = sid

            local displayOrder = realSlot
            if hp.reverseOrder == true then displayOrder = 6 - realSlot end
            e.orderHint = displayOrder

            applySpellCooldownFields(e, sid)
            out[sid] = e
          end
        else
          -- Revive Pet (982): independent checkbox, not affected by group ignore
          if sid == 982 and not mmWithoutUnbreakable and not IsExcludedPets(982) then
            local e = ns.copyItemData(row)
            e.category = "PETS"
            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(sid)
            e.macro     = "/use " .. (info and info.name or "Revive Pet")
            e.spellID   = sid
            e.orderHint = 99
            applySpellCooldownFields(e, sid)
            out[sid] = e
          end
        end
      else
        if not IsExcludedPets(sid) then
          local e = ns.copyItemData(row)
          e.category = "PETS"
          local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(sid)
          e.macro     = "/use " .. (info and info.name or "")
          e.spellID   = sid
          e.orderHint = sid
          e.hoverIcon = nil
          applySpellCooldownFields(e, sid)
          out[sid] = e
        end
      end
    end
  end
end

-- Public API to rebuild pet display.
function ns.Pets_Rebuild()
  if InCombat() then return end
  buildPets()
  if ns.RequestRebuild then ns.RequestRebuild() end
  if ns.RenderAll then ns.RenderAll() end
end

-- Event handlers
function ns.Pets_OnPEW() ns.Pets_Rebuild(); return true end
function ns.Pets_OnSpellsChanged() ns.Pets_Rebuild(); return true end
function ns.Pets_OnPetStableUpdate() ns.Pets_Rebuild(); return true end
function ns.Pets_OnUnitPet(unit) if unit ~= "player" then return false end ns.Pets_Rebuild(); return true end
function ns.Pets_OnSpellUpdateCooldown() if InCombat() then return false end ns.Pets_Rebuild(); return true end
function ns.Pets_OnRegenEnabled() ns.Pets_Rebuild(); return true end
function ns.Pets_OnRegenDisabled() return false end
function ns.Pets_OnMountDisplayChanged() ns.Pets_Rebuild(); return true end

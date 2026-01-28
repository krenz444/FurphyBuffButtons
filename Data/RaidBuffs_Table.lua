-- ====================================
-- \Data\RaidBuffs_Table.lua
-- ====================================
-- This file contains the core data tables defining all raid-wide buffs by class.
-- Each entry specifies spell/buff IDs, targeting rules, check types (raid/player),
-- gate conditions (rested, range, instance), and display labels.
-- Structure: RAID_<CLASS> tables keyed by primary spellID with properties:
--   - name: Spell name
--   - spellID: Cast spell ID
--   - buffID: Buff aura ID(s) to check (can be table for mutually exclusive buffs)
--   - check: "raid" (check all raid members) or "player" (self only)
--   - target: Usually "player"
--   - gates: Array of gate checks (see Gates/ folder)
--   - infinite: true for auras without duration

ClickableRaidData  = ClickableRaidData  or {}
ClickableRaidOrder = ClickableRaidOrder or {}

local playerClassID = (clickableRaidBuffCache and clickableRaidBuffCache.playerInfo and clickableRaidBuffCache.playerInfo.playerClassId)
                     or (type(getPlayerClass)=="function" and getPlayerClass())
                     or 0

-- =========================
-- Warrior (1)
-- =========================
local RAID_WARRIOR = {
  [6673]   = { name="Battle Shout",       spellID=6673,   buffID={6673},                      check="raid",   target="player", topLbl="", btmLbl="", gates={"rested", "range"} },
  [386164] = { name="Battle Stance",      spellID=386164, buffID={386196,386208,386164},      check="player", target="player", topLbl="", btmLbl="", gates={"rested"}, infinite=true },
  [386196] = { name="Berserker Stance",   spellID=386196, buffID={386196,386208,386164},      check="player", target="player", topLbl="", btmLbl="", gates={"rested"}, infinite=true },
  [386208] = { name="Defensive Stance",   spellID=386208, buffID={386196,386208,386164},      check="player", target="player", topLbl="", btmLbl="", gates={"rested"}, infinite=true },
}

-- =========================
-- Paladin (2)
-- =========================
local RAID_PALADIN = {
  [32223]  = { name="Crusader Aura",      spellID=32223,  buffID={32223,465,317920},          check="player", target="player", topLbl="", btmLbl="", gates={"rested"}, infinite=true },
  [317920] = { name="Concentration Aura", spellID=317920, buffID={32223,465,317920},          check="player", target="player", topLbl="", btmLbl="", gates={"rested"}, infinite=true },
  [465]    = { name="Devotion Aura",      spellID=465,    buffID={32223,465,317920},          check="player", target="player", topLbl="", btmLbl="", gates={"rested"}, infinite=true },
  [1465]    = { name="Devotion Aura",      spellID=465,    buffID={465},          check="player", target="player", topLbl="", btmLbl="", gates={"instance"}, infinite=true }, 			--Instance only version that encourages swapping to Devo if no Devo applied

}

-- =========================
-- Hunter (3)
-- =========================
local RAID_HUNTER = {}

-- =========================
-- Rogue (4)
-- =========================
local RAID_ROGUE = {}

-- =========================
-- Priest (5)
-- =========================
local RAID_PRIEST = {
  [21562]  = { name="Power Word: Fortitude", spellID=21562,  buffID={21562},                  check="raid",   target="player", topLbl="", btmLbl="", gates={"rested", "range"} },
  [232698] = { name="Shadowform",             spellID=232698, buffID={232698},                check="player", target="player", topLbl="", btmLbl="", gates={"rested"} },
}

-- =========================
-- Death Knight (6)
-- =========================
local RAID_DK = {}

-- =========================
-- Shaman (7)
-- =========================
local RAID_SHAMAN = {
  [462854] = { name="Skyfury",                spellID=462854, buffID={462854},                check="raid",   target="player", topLbl="", btmLbl="", gates={"rested", "range"} },
}

-- =========================
-- Mage (8)
-- =========================
local RAID_MAGE = {
  [1459]   = { name="Arcane Intellect",       spellID=1459,   buffID={1459,432778},           check="raid",   target="player", topLbl="", btmLbl="", gates={"rested", "range"} },
  [205022] = { name="Arcane Familiar",        spellID=1459,   buffID={210126},                check="player", target="player", topLbl="", btmLbl="", spellToCast=1459, gates={"rested"}, icon = 1041232, isKnown=205022 },
}

-- =========================
-- Warlock (9)
-- =========================
local RAID_WARLOCK = {
  [20707]  = { name="Soulstone",              spellID=20707,  buffID={20707},                 check="raid",   target="target", topLbl="", btmLbl=STATUS_TEXT_TARGET, count=1, gates={"instance","rested", "group", "mineOnly"} },
  [108503] = { name="Grimoire of Sacrifice",  spellID=108503, buffID={196099},                check="player", target="player", topLbl="", btmLbl="", gates={ "has_pet", "evenRested" } },
}

-- =========================
-- Monk (10)
-- =========================
local RAID_MONK = {}

-- =========================
-- Druid (11)
-- =========================
local RAID_DRUID = {
  [1126]   = { name="Mark of the Wild",       spellID=1126,   buffID={1126,432661},           check="raid",   target="player", topLbl="", btmLbl="", gates={"rested", "range"}, },
  [474750] = { name="Symbiotic Relationship", spellID=474750, buffID={474754},                check="raid",   target="",       topLbl="", btmLbl=STATUS_TEXT_TARGET, count=1, nameMode=true, gates={"rested", "group", "mineOnly"} },
}

-- =========================
-- Demoin Hunter (12)
-- =========================
local RAID_DH = {}

-- =========================
-- Evoker (13)
-- =========================
local RAID_EVOKER = {
  [364342] = { name="Blessing of the Bronze", spellID=364342, buffID={381748},                check="raid",   target="player", topLbl="", btmLbl="", gates={"rested", "range"}, nameMode=true },
  [403264] = { name="Black Attunement",       spellID=403264, buffID={403264,403265},         check="player", target="player", topLbl="+HP", btmLbl="", gates={"rested"}, infinite=true },
  [403265] = { name="Bronze Attunement",      spellID=403265, buffID={403264,403265},         check="player", target="player", topLbl="+Speed", btmLbl="", gates={"rested"}, infinite=true },
  [369459] = { name="Source of Magic",        spellID=369459, buffID={369459},                check="raid",   target="",       topLbl="", btmLbl=STATUS_TEXT_TARGET, count=1, gates={"instance","rested", "group", "mineOnly"}, role="healer" },
  [412710] = { name="Timelessness",           spellID=412710, buffID={412710},                check="raid",   target="",       topLbl="", btmLbl=STATUS_TEXT_TARGET, count=1, gates={"instance","rested", "group", "mineOnly"} }
}

-- =========================
-- Trinkets 
-- =========================
local RAID_TRINKETS = {
  [190958] = {
    name   = "So'Leah's Secret Technique",
    itemID = 190958,
    buffID = {368510},
    check  = "raid",
    target = "",
    topLbl = INVTYPE_TRINKET,
    btmLbl = STATUS_TEXT_TARGET,
    count  = 1,
    nameMode = nil,
    type   = "trinket",
    gates  = {"group","rested", "mineOnly"},
  },
  [178742] = {
    name   = "Bottled Flayedwing Toxin",
    itemID = 178742,
    buffID = {345546},
    check  = "player",
    target = "player",
    topLbl = INVTYPE_TRINKET,
    btmLbl = "",
    nameMode = true,
    type   = "trinket",
    gates  = {"group","rested", "mineOnly"},
  },
}

ClickableRaidData.RAID_TRINKETS = ClickableRaidData.RAID_TRINKETS or {}
for id, e in pairs(RAID_TRINKETS) do
  ClickableRaidData.RAID_TRINKETS[id] = e
end

local byClass = {
  [1]=RAID_WARRIOR, [2]=RAID_PALADIN, [3]=RAID_HUNTER, [4]=RAID_ROGUE,  [5]=RAID_PRIEST,
  [6]=RAID_DK,      [7]=RAID_SHAMAN,  [8]=RAID_MAGE,   [9]=RAID_WARLOCK,[10]=RAID_MONK,
  [11]=RAID_DRUID,  [12]=RAID_DH,     [13]=RAID_EVOKER,
}

local orderByClass = {
  [1]  = { 6673, 317920, 386208, 386164 },
  [2]  = { 32223, 465, 317920 },
  [5]  = { 21562, 232698 },
  [7]  = { 462854 }, 
  [8]  = { 1459, 205022 },
  [9]  = { 20707, 108503 },
  [11] = { 1126, 474750 },
  [13] = { 364342, 403264, 403265, 369459, 412710 },
}

if byClass[playerClassID] then
  ClickableRaidData[playerClassID] = ClickableRaidData[playerClassID] or {}
  for id, e in pairs(byClass[playerClassID]) do
    ClickableRaidData[playerClassID][id] = e
  end
  ClickableRaidOrder[playerClassID] = orderByClass[playerClassID]
end

if ClickableRaidData[playerClassID] then
  for id, e in pairs(RAID_TRINKETS) do
    ClickableRaidData[playerClassID][id] = e
    if ClickableRaidOrder[playerClassID] then
      table.insert(ClickableRaidOrder[playerClassID], id)
    end
  end
end

ClickableRaidData.ALL_RAID_BUFFS = ClickableRaidData.ALL_RAID_BUFFS or {}
do
  local function merge(src)
    for id, e in pairs(src) do ClickableRaidData.ALL_RAID_BUFFS[id] = e end
  end
  merge(RAID_WARRIOR); merge(RAID_PALADIN); merge(RAID_HUNTER);  merge(RAID_ROGUE);
  merge(RAID_PRIEST);  merge(RAID_DK);      merge(RAID_SHAMAN);  merge(RAID_MAGE);
  merge(RAID_WARLOCK); merge(RAID_MONK);    merge(RAID_DRUID);   merge(RAID_DH);
  merge(RAID_EVOKER);
end

ClickableRaidData.ALL_RAID_BUFFS_BY_CLASS = ClickableRaidData.ALL_RAID_BUFFS_BY_CLASS or {}
do
  local byClass = ClickableRaidData.ALL_RAID_BUFFS_BY_CLASS
  for k in pairs(byClass) do byClass[k] = nil end

  local CLASS_SETS = {
    [1]  = RAID_WARRIOR,
    [2]  = RAID_PALADIN,
    [3]  = RAID_HUNTER,
    [4]  = RAID_ROGUE,
    [5]  = RAID_PRIEST,
    [6]  = RAID_DK,
    [7]  = RAID_SHAMAN,
    [8]  = RAID_MAGE,
    [9]  = RAID_WARLOCK,
    [10] = RAID_MONK,
    [11] = RAID_DRUID,
    [12] = RAID_DH,
    [13] = RAID_EVOKER,
  }

  for classID, tbl in pairs(CLASS_SETS) do
    if type(tbl) == "table" then
      local dest = {}
      for spellID, e in pairs(tbl) do dest[spellID] = e end
      byClass[classID] = dest
    end
  end
end

ClickableRaidData.ALL_TRINKETS = ClickableRaidData.ALL_TRINKETS or {}
for id, e in pairs(RAID_TRINKETS) do
  ClickableRaidData.ALL_TRINKETS[id] = e
end

ClickableRaidData.ALL_RAID_BUFFS_BY_CLASS = {
  WARRIOR      = RAID_WARRIOR,
  PALADIN      = RAID_PALADIN,
  HUNTER       = RAID_HUNTER,
  ROGUE        = RAID_ROGUE,
  PRIEST       = RAID_PRIEST,
  DEATHKNIGHT  = RAID_DK,
  SHAMAN       = RAID_SHAMAN,
  MAGE         = RAID_MAGE,
  WARLOCK      = RAID_WARLOCK,
  MONK         = RAID_MONK,
  DRUID        = RAID_DRUID,
  DEMONHUNTER  = RAID_DH,
  EVOKER       = RAID_EVOKER,
}
ClickableRaidData.RAID_BUFF_CLASS_ORDER = {
  "WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","DEATHKNIGHT",
  "SHAMAN","MAGE","WARLOCK","MONK","DRUID","DEMONHUNTER","EVOKER",
}
ClickableRaidData.RAID_BUFF_CLASS_LABELS = {
  WARRIOR="Warrior", PALADIN="Paladin", HUNTER="Hunter", ROGUE="Rogue", PRIEST="Priest",
  DEATHKNIGHT="Death Knight", SHAMAN="Shaman", MAGE="Mage", WARLOCK="Warlock",
  MONK="Monk", DRUID="Druid", DEMONHUNTER="Demon Hunter", EVOKER="Evoker",
}

if ns and ns.RebuildRaidBuffWatch then ns.RebuildRaidBuffWatch() end

-- ====================================
-- \Data\Alerts_Table.lua
-- ====================================

FurphyBuffData = FurphyBuffData or {}

FurphyBuffData["ANNOUNCER"] = {
  FEAST = {
    spellID = { 457285, 455960, 457487, 457283, 462212, 457302, 462211, 462213,
                1259659, 1259658, 1259657, 1237104,         -- Midnight feasts
                1278895, 1278929, 1278909 },                -- Midnight hearty feasts
    text   = "Feast Down",
	label  = "Feasts",
  },

  CAULDRON = {
    spellID = { 433294, 433293, 433292, 432879, 432878, 432877,
                1240019 },                                   -- Midnight Flask Cauldron
    text   = "Cauldron Down",
	label  = "Cauldron",
  },

  HEALTHSTONES = {
    spellID = { 29893 },
    text   = "Soulwell Down",
	label  = "Healthstone",
  },

  JEEVES = {
    spellID = { 67826 },
    text   = "Jeeves Down",
	label  = "Jeeves",
  },

  REPAIR = {
    spellID = { 199109, 200205, 453942, 54711 },
    text   = "Repair Bot Down",
	label  = "Repair Bot",
  },

  SUMMON = {
    spellID = { 698 },
    text   = "Summoning Stone Down",
	label  = "Summoning Stone",
  },

  MAGE = {
    spellID = { 190336 },
    text   = "Mage Table Down",
	label  = "Mage Table",
  },

  MAILBOX = {
    spellID = { 54710, 376664, 261602 },
    text   = "Mailbox Down",
	label  = "Mailbox",
  },
  
  PORTAL = {
    spellID = { 
      176244,   --Portal: Warspear
      132626,   --Portal: Vale of Eternal Blossoms
      132620,   --Portal: Vale of Eternal Blossoms
      88346,    --Portal: Tol Barad
      88345,    --Portal: Tol Barad
      11420,    --Portal: Thunder Bluff
      10059,    --Portal: Stormwind
      176246,   --Portal: Stormshield
      32267,    --Portal: Silvermoon
      35717,    --Portal: Shattrath
      33691,    --Portal: Shattrath
      11417,    --Portal: Orgrimmar
      11416,    --Portal: Ironforge
      32266,    --Portal: Exodar
      281402,   --Portal: Dazar'alor
      11419,    --Portal: Darnassus
      53142,    --Portal: Dalaran - Northrend
      281400,   --Portal: Boralus
      11418,    --Portal: Undercity
      49360,    --Portal: Theramore
      120146,   --Ancient Portal: Dalaran
      344597,   --Portal: Oribos
      49361,    --Portal: Stonard
      395289,   --Portal: Valdrakken
      446534,   --Portal: Dornogal
      224871    --Portal: Dalaran - Broken Isles
    },
    text   = "Portal Open",
	label  = "Portals",
  },
}
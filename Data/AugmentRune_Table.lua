-- ====================================
-- ===== Data/AugmentRune_Table.lua
-- ====================================

FurphyBuffData = FurphyBuffData or {}

FurphyBuffData["AUGMENT_RUNE"] = {
  [243191] = { name="Ethereal Augment Rune", buffID={453250,1234969,1242347}, icon = 3566863, topLbl="", btmLbl="", gates={"rested"}, qty=false, consumable=false },
  [246492] = { name="Soulgorged Augment Rune", buffID={393438,453250,1234969,1242347},  icon = 1345086, topLbl="", btmLbl="", gates={"instance","rested"}, exclude={243191}, consumable=true },
  [211495] = { name="Dreambound Augment Rune", buffID={393438,453250,1234969,1242347},  icon = 348535, topLbl="", btmLbl="", gates={"rested"}, exclude={243191}, qty=false, consumable=false },
  [224572] = { name="Crystallized Augment Rune",buffID={393438,453250,1234969,1242347}, icon = 4549102,  topLbl="", btmLbl="", gates={"instance","rested"}, exclude={243191,246492}, consumable=true },

  -- Midnight Expansion
  [259085] = { name="Void-Touched Augment Rune", buffID={1264426}, icon=4549099, topLbl="", btmLbl="", gates={"instance","rested"}, consumable=true },
}

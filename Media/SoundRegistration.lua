-- ====================================
-- \Media\SoundRegistration.lua
-- ====================================

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if not LSM then return end

local BASE = "Interface\\AddOns\\FurphyBuffButtons\\Media\\Sounds\\"

LSM:Register("sound", "FBB: Clank", BASE .. "JewelcraftingFinalize.ogg")

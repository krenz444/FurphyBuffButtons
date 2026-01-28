-- ====================================
-- \UI\Fonts.lua
-- ====================================
-- This file manages font registration and retrieval for the addon.

local addonName, ns = ...
ns.FontObjects = ns.FontObjects or {}

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Registers a font with LibSharedMedia if available.
function ns.RegisterFont(name, path)
    if LSM then
        LSM:Register("font", name, path)
    end
end

-- Retrieves the file path for a registered font name.
function ns.GetFontPath(name)
    if not name then return "Fonts\\FRIZQT__.TTF" end
    if LSM then
        local p = LSM:Fetch("font", name, true)
        if p then return p end
    end
    return "Fonts\\FRIZQT__.TTF"
end

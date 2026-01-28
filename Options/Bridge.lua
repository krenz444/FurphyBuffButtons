-- ====================================
-- \Options\Bridge.lua
-- ====================================
-- This file acts as a bridge between the options UI and the core addon functionality.
-- It provides functions to update settings and trigger refreshes.

local addonName, ns = ...

-- Sets the icon size and triggers a render update.
function ns.SetIconSize(size)
    local db = ns.GetDB()
    db.iconSize = size
    if ns.RenderAll then ns.RenderAll() end
end

-- Sets the general glow color and state.
function ns.SetGlow(enabled, r, g, b, a)
    local db = ns.GetDB()
    db.glowEnabled = enabled
    db.glowColor = { r = r, g = g, b = b, a = a }
    if ns.RenderAll then ns.RenderAll() end
end

-- Sets the special glow color.
function ns.SetSpecialGlow(r, g, b, a)
    local db = ns.GetDB()
    db.specialGlowColor = { r = r, g = g, b = b, a = a }
    if ns.RenderAll then ns.RenderAll() end
end

-- Sets the font name.
function ns.SetFontName(name)
    local db = ns.GetDB()
    db.fontName = name
    if ns.RenderAll then ns.RenderAll() end
end

-- Sets font sizes for various text elements.
function ns.SetFontSizes(top, bottom, center)
    local db = ns.GetDB()
    db.topSize = top
    db.bottomSize = bottom
    db.timerSize = center
    if ns.RenderAll then ns.RenderAll() end
end

-- Sets font outlines for various text elements.
function ns.SetFontOutlines(top, bottom, center)
    local db = ns.GetDB()
    db.topOutline = top
    db.bottomOutline = bottom
    db.timerOutline = center
    if ns.RenderAll then ns.RenderAll() end
end

-- Sets text color for a specific element.
function ns.SetTextColor(which, r, g, b, a)
    local db = ns.GetDB()
    if which == "top" then
        db.topTextColor = { r = r, g = g, b = b, a = a }
    elseif which == "bottom" then
        db.bottomTextColor = { r = r, g = g, b = b, a = a }
    else
        db.timerTextColor = { r = r, g = g, b = b, a = a }
    end
    if ns.RenderAll then ns.RenderAll() end
end

-- Triggers a font refresh.
function ns.RefreshFonts()
    if ns.RenderAll then ns.RenderAll() end
end

-- Sets corner font properties.
function ns.SetCornerFont(size, outline)
    local db = ns.GetDB()
    db.cornerSize = size
    db.cornerOutline = (outline ~= false)
    if ns.RenderAll then ns.RenderAll() end
end

-- Sets corner text color.
function ns.SetCornerTextColor(r, g, b, a)
    local db = ns.GetDB()
    db.cornerTextColor = { r=r, g=g, b=b, a=a }
    if ns.RenderAll then ns.RenderAll() end
end

-- Triggers a glow refresh.
function ns.RefreshGlow()
    if ns.RenderAll then ns.RenderAll() end
end

-- Requests a full rebuild of the addon's data and display.
-- Skipped during combat.
function ns.RequestRebuild()
    if ns._inCombat or InCombatLockdown() then
        return
    end

    if type(ns.UpdateAugmentRunes) == "function" then
        ns.UpdateAugmentRunes()
    end

    if type(_G.scanRaidBuffs) == "function" then
        _G.scanRaidBuffs()
    end

    if type(_G.scanAllBags) == "function" then
        _G.scanAllBags()
    end

    if type(ns.RenderAll) == "function" then
        ns.RenderAll()
    end

    if type(ns.Timer_RecomputeSchedule) == "function" then
        ns.Timer_RecomputeSchedule()
    end
end

-- ====================================
-- \UI\Util.lua
-- ====================================
-- This file contains utility functions for UI elements.

local addonName, ns = ...

-- Generates a unique key for a display entry.
function ns.EntryKey(cat, entry)
    if cat == "MAIN_HAND" then
        return "MH:" .. tostring(entry.itemID or entry.name or "")
    elseif cat == "OFF_HAND" then
        return "OH:" .. tostring(entry.itemID or entry.name or "")
    end
    if entry.itemID then
        return cat .. ":item:" .. entry.itemID
    end
    if entry.spellID then
        return cat .. ":spell:" .. entry.spellID
    end
    return cat .. ":name:" .. tostring(entry.name or "")
end

-- Sets the icon texture only if it has changed, to avoid unnecessary updates.
function ns.SetIconTextureIfChanged(btn, tex)
    if btn.icon._crb_tex ~= tex then
        btn.icon:SetTexture(tex or 134400)
        btn.icon._crb_tex = tex
    end
end

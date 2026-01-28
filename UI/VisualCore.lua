-- ====================================
-- \UI\VisualCore.lua
-- ====================================
-- This file provides core visual utility functions, primarily for font management.

local addonName, ns = ...
local LSM = LibStub("LibSharedMedia-3.0")

ns.FontObjects = ns.FontObjects or {}

-- Resolves a font name to a file path using LibSharedMedia.
local function fontPath(name)
  if LSM then
    local ok, path = pcall(LSM.Fetch, LSM, "font", name or "Friz Quadrata TT")
    if ok and path then return path end
  end
  return name or "Fonts\\FRIZQT__.TTF"
end

-- Retrieves or creates a FontObject for the given parameters.
if not ns.GetFontObject then
  function ns.GetFontObject(fontName, size, outline)
    local key = tostring(fontName or "") .. ":" .. tostring(size or "") .. ":" .. ((outline and "OUTLINE") or "")
    local f = ns.FontObjects[key]
    if not f then
      f = CreateFont("CRB_Font_" .. key)
      f:SetFont(fontPath(fontName), tonumber(size) or 14, outline and "OUTLINE" or "")
      ns.FontObjects[key] = f
    end
    return f
  end
end

-- Updates a FontString with the specified text, font, size, outline, and color.
if not ns.UpdateFontString then
  function ns.UpdateFontString(fs, text, fontName, size, outline, color)
    if not fs then return end
    local fo = ns.GetFontObject(fontName, size, outline)
    if fs:GetFontObject() ~= fo then fs:SetFontObject(fo) end
    if fs._crb_text ~= text then
      fs:SetText(text or "")
      fs._crb_text = text
    end
    if color then
      local r,g,b,a = color.r or 1, color.g or 1, color.b or 1, color.a or 1
      local c = fs._crb_color
      if not c or c[1] ~= r or c[2] ~= g or c[3] ~= b or c[4] ~= a then
        fs:SetTextColor(r,g,b,a)
        fs._crb_color = {r,g,b,a}
      end
    end
  end
end

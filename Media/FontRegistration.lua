-- ====================================
-- \Media\FontRegistration.lua
-- ====================================
-- Registers all custom fonts with LibSharedMedia-3.0 for use throughout the addon.
-- Fonts are organized by family (Aladin, Cinzel, FiraCode, FiraSans, etc.) and
-- include various weights and styles. Used by Options/Panel.lua and UI/Render.lua.

local addon = ...
local LSM = LibStub("LibSharedMedia-3.0", true)
if not LSM then return end

local base = "Interface\\AddOns\\" .. addon .. "\\Media\\Fonts"

-- ================== Aladin ==================
LSM:Register("font", "Aladin-Regular", base .. "\\Aladin\\Aladin-Regular.ttf")

-- ================== Cinzel ==================
LSM:Register("font", "Cinzel-Regular", base .. "\\Cinzel\\Cinzel-Regular.ttf")
LSM:Register("font", "Cinzel-Black", base .. "\\Cinzel\\Cinzel-Black.ttf")
LSM:Register("font", "Cinzel-Bold", base .. "\\Cinzel\\Cinzel-Bold.ttf")
LSM:Register("font", "Cinzel-ExtraBold", base .. "\\Cinzel\\Cinzel-ExtraBold.ttf")
LSM:Register("font", "Cinzel-Medium", base .. "\\Cinzel\\Cinzel-Medium.ttf")
LSM:Register("font", "Cinzel-SemiBold", base .. "\\Cinzel\\Cinzel-SemiBold.ttf")

-- ================== FacultyGlyphic ==================
LSM:Register("font", "FacultyGlyphic-Regular", base .. "\\Faculty_Glyphic\\FacultyGlyphic-Regular.ttf")

-- ================== FiraCode ==================
LSM:Register("font", "FiraCode-Regular", base .. "\\Fira_Code\\FiraCode-Regular.ttf")
LSM:Register("font", "FiraCode-Bold", base .. "\\Fira_Code\\FiraCode-Bold.ttf")
LSM:Register("font", "FiraCode-Light", base .. "\\Fira_Code\\FiraCode-Light.ttf")
LSM:Register("font", "FiraCode-Medium", base .. "\\Fira_Code\\FiraCode-Medium.ttf")
LSM:Register("font", "FiraCode-SemiBold", base .. "\\Fira_Code\\FiraCode-SemiBold.ttf")

-- ================== FiraMono ==================
LSM:Register("font", "FiraMono-Regular", base .. "\\Fira_Mono\\FiraMono-Regular.ttf")
LSM:Register("font", "FiraMono-Bold", base .. "\\Fira_Mono\\FiraMono-Bold.ttf")
LSM:Register("font", "FiraMono-Medium", base .. "\\Fira_Mono\\FiraMono-Medium.ttf")

-- ================== FiraSans ==================
LSM:Register("font", "FiraSans-Regular", base .. "\\Fira_Sans\\FiraSans-Regular.ttf")
LSM:Register("font", "FiraSans-Black", base .. "\\Fira_Sans\\FiraSans-Black.ttf")
LSM:Register("font", "FiraSans-BlackItalic", base .. "\\Fira_Sans\\FiraSans-BlackItalic.ttf")
LSM:Register("font", "FiraSans-Bold", base .. "\\Fira_Sans\\FiraSans-Bold.ttf")
LSM:Register("font", "FiraSans-BoldItalic", base .. "\\Fira_Sans\\FiraSans-BoldItalic.ttf")
LSM:Register("font", "FiraSans-ExtraBold", base .. "\\Fira_Sans\\FiraSans-ExtraBold.ttf")
LSM:Register("font", "FiraSans-ExtraBoldItalic", base .. "\\Fira_Sans\\FiraSans-ExtraBoldItalic.ttf")
LSM:Register("font", "FiraSans-ExtraLight", base .. "\\Fira_Sans\\FiraSans-ExtraLight.ttf")
LSM:Register("font", "FiraSans-Light", base .. "\\Fira_Sans\\FiraSans-Light.ttf")
LSM:Register("font", "FiraSans-Italic", base .. "\\Fira_Sans\\FiraSans-Italic.ttf")
LSM:Register("font", "FiraSans-LightItalic", base .. "\\Fira_Sans\\FiraSans-LightItalic.ttf")
LSM:Register("font", "FiraSans-Medium", base .. "\\Fira_Sans\\FiraSans-Medium.ttf")
LSM:Register("font", "FiraSans-MediumItalic", base .. "\\Fira_Sans\\FiraSans-MediumItalic.ttf")
LSM:Register("font", "FiraSans-SemiBold", base .. "\\Fira_Sans\\FiraSans-SemiBold.ttf")
LSM:Register("font", "FiraSans-Thin", base .. "\\Fira_Sans\\FiraSans-Thin.ttf")
LSM:Register("font", "FiraSans-ThinItalic", base .. "\\Fira_Sans\\FiraSans-ThinItalic.ttf")
LSM:Register("font", "FiraSans-ExtraLightItalic", base .. "\\Fira_Sans\\FiraSans-ExtraLightItalic.ttf")
LSM:Register("font", "FiraSans-SemiBoldItalic", base .. "\\Fira_Sans\\FiraSans-SemiBoldItalic.ttf")

-- ================== MozillaText ==================
LSM:Register("font", "MozillaText-Bold", base .. "\\Mozilla_Text\\MozillaText-Bold.ttf")
LSM:Register("font", "MozillaText-ExtraLight", base .. "\\Mozilla_Text\\MozillaText-ExtraLight.ttf")
LSM:Register("font", "MozillaText-Light", base .. "\\Mozilla_Text\\MozillaText-Light.ttf")
LSM:Register("font", "MozillaText-Medium", base .. "\\Mozilla_Text\\MozillaText-Medium.ttf")
LSM:Register("font", "MozillaText-Regular", base .. "\\Mozilla_Text\\MozillaText-Regular.ttf")
LSM:Register("font", "MozillaText-SemiBold", base .. "\\Mozilla_Text\\MozillaText-SemiBold.ttf")

-- ================== Oswald ==================
LSM:Register("font", "Oswald-Bold", base .. "\\Oswald\\Oswald-Bold.ttf")
LSM:Register("font", "Oswald-ExtraLight", base .. "\\Oswald\\Oswald-ExtraLight.ttf")
LSM:Register("font", "Oswald-Light", base .. "\\Oswald\\Oswald-Light.ttf")
LSM:Register("font", "Oswald-Medium", base .. "\\Oswald\\Oswald-Medium.ttf")
LSM:Register("font", "Oswald-Regular", base .. "\\Oswald\\Oswald-Regular.ttf")
LSM:Register("font", "Oswald-SemiBold", base .. "\\Oswald\\Oswald-SemiBold.ttf")

-- ================== ProstoOne ==================
LSM:Register("font", "ProstoOne-Regular", base .. "\\Prosto_One\\ProstoOne-Regular.ttf")

-- ================== PT Sans ==================
LSM:Register("font", "PTSans-Bold", base .. "\\PT_Sans\\PTSans-Bold.ttf")
LSM:Register("font", "PTSans-BoldItalic", base .. "\\PT_Sans\\PTSans-BoldItalic.ttf")
LSM:Register("font", "PTSans-Italic", base .. "\\PT_Sans\\PTSans-Italic.ttf")
LSM:Register("font", "PTSans-Regular", base .. "\\PT_Sans\\PTSans-Regular.ttf")

-- ================== PT Sans Narrow ==================
LSM:Register("font", "PTSansNarrow-Bold", base .. "\\PT_Sans_Narrow\\PTSansNarrow-Bold.ttf")
LSM:Register("font", "PTSansNarrow-Regular", base .. "\\PT_Sans_Narrow\\PTSansNarrow-Regular.ttf")
# Clickable Raid Buffs

**Clickable Raid Buffs (CRB)** is a World of Warcraft addon that displays missing raid buffs, consumables, and temporary enchants, allowing you to click them to cast the buff or use the item directly.

**Author:** Furphy (Originally created by Funki)  
**Version:** 7.0.0

## Features

*   **Raid Buffs:** Automatically detects missing class buffs (e.g., Arcane Intellect, Power Word: Fortitude, Mark of the Wild) and provides a clickable icon to cast them.
*   **Consumables:** Tracks Flasks, Food, and Augment Runes. Shows icons when they are missing or about to expire.
*   **Weapon Enchants:** Monitors temporary weapon enchants (Oils, Stones, Windfury, Flametongue, etc.) and provides clickable icons to apply them.
*   **Utility & Class Modules:**
    *   **Healthstones:** Shows an icon to create or use Healthstones.
    *   **Hunter Pets:** Helps manage calling, reviving, and healing pets.
    *   **Shaman Shields:** Tracks Lightning Shield, Water Shield, and Earth Shield.
    *   **Rogue Poisons:** Reminds you to apply poisons.
    *   **Durability:** Displays a repair icon when durability is low, allowing you to summon a repair mount.
*   **Alerts:** Visual and audible alerts for important group events like:
    *   Repair Bots (Jeeves, Reeves, etc.)
    *   Feasts placed
    *   Mage Portals
    *   Summoning Rituals
*   **Mythic+ Support:** Special options to manage consumables and alerts during Mythic+ runs.
*   **Customizable:** Extensive options to configure icon size, position, growth direction, and more.

## Usage

The addon works out of the box with sensible defaults.

*   **Left-Click** an icon to cast the buff or use the item.
*   **Right-Click** (on some icons) to perform alternative actions (e.g., summon a different mount, cast a different spell).
*   **Minimap Button:** Click to open settings. Right-click to toggle frame lock.

### Slash Commands

*   `/crb` or `/buff` - Open the options menu.
*   `/crb unlock` - Unlock the frame to move it.
*   `/crb lock` - Lock the frame.
*   `/crb minimap` - Toggle the minimap button.
*   `/crb reset` - Reset all settings to default.

## Recent Changes (v7.0.0)

This version includes significant updates to comply with Blizzard's latest addon restrictions:

*   **Combat Log Access:** Functionality relying on the combat log has been removed to prevent errors.
*   **Protected Functions:** Adjustments made to ensure compatibility with restricted environments, particularly during combat.
*   **Recuperate:** The Recuperate module has been disabled due to API restrictions on reading unit health.

## Credits

*   **Furphy:** Current Maintainer
*   **Funki:** Original Creator
*   

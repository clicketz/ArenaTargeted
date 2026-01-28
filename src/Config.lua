local _, ns = ...
local C_ClassColor = C_ClassColor

-- constants
ns.CONSTANTS = {
    MAX_ARENA_ENEMIES = 5,
    TEXTURE_WHITE = "Interface\\BUTTONS\\WHITE8X8",
    TEXTURE_RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
    RAID_ICON_INDICES = {
        ["Star"]     = 1,
        ["Circle"]   = 2,
        ["Diamond"]  = 3,
        ["Triangle"] = 4,
        ["Moon"]     = 5,
        ["Square"]   = 6,
        ["Cross"]    = 7,
        ["Skull"]    = 8,
        ["Flag"]     = 15,
        ["Murloc"]   = 16,
    }
}

-- db defaults
ns.defaults = {
    anchor = "BOTTOMLEFT",
    relativePoint = "BOTTOMRIGHT",
    x = 2,
    y = 0,
    growDirection = "RIGHT",
    spacing = 2,
    size = 12,
    borderSize = 1,
    showIndex = false,
    fontSize = 10,
    shape = "Box",
}

-- pre-fetched colors for preview frame
ns.PREVIEW_COLORS = {
    [1] = C_ClassColor.GetClassColor("MAGE"),
    [2] = C_ClassColor.GetClassColor("ROGUE"),
    [3] = C_ClassColor.GetClassColor("DRUID"),
    [4] = C_ClassColor.GetClassColor("PALADIN"),
    [5] = C_ClassColor.GetClassColor("HUNTER"),
}

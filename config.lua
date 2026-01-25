local _, ns = ...
local C_ClassColor = C_ClassColor

-- ---------------------------------------------------------
-- Constants & Config
-- ---------------------------------------------------------

ns.CONSTANTS = {
    MAX_ARENA_ENEMIES = 5,
    TEXTURE_WHITE = "Interface\\BUTTONS\\WHITE8X8",
    TEXTURE_TRIANGLE = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
}

-- Default settings for the DB
ns.defaults = {
    anchor = "BOTTOMLEFT",
    relativePoint = "BOTTOMRIGHT",
    x = 2,
    y = 0,
    growDirection = "RIGHT",
    spacing = 2,
    size = 12,
    showIndex = false,
    fontSize = 10,
    shape = "Square",
}

-- Pre-fetched class colors for Preview/Dummy frames
ns.PREVIEW_COLORS = {
    [1] = C_ClassColor.GetClassColor("MAGE"),
    [2] = C_ClassColor.GetClassColor("ROGUE"),
    [3] = C_ClassColor.GetClassColor("DRUID"),
    [4] = C_ClassColor.GetClassColor("PALADIN"),
    [5] = C_ClassColor.GetClassColor("HUNTER"),
}

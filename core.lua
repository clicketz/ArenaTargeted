local addonName, ns = ...

local UnitExists = UnitExists
local string_match = string.match
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local UnitClass = UnitClass
local C_ClassColor = C_ClassColor
local Settings = Settings
local PixelUtil = PixelUtil
local GetPhysicalScreenSize = GetPhysicalScreenSize

-- Pre-fetch these so we don't query C_ClassColor inside the layout loop
local TEST_COLORS = {
    [1] = C_ClassColor.GetClassColor("MAGE"),
    [2] = C_ClassColor.GetClassColor("ROGUE"),
    [3] = C_ClassColor.GetClassColor("DRUID")
}

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
}

ns.containers = {}
ns.categoryID = nil
ns.pixelScale = 1

-- Returns unit class color as RGBA
local function GetUnitColor(unit)
    if UnitExists(unit) then
        local _, classFilename = UnitClass(unit)
        if classFilename then
            local color = C_ClassColor.GetClassColor(classFilename)
            if color then
                return color.r, color.g, color.b, 1
            end
        end
    end
    return nil
end

-- Round value to nearest physical pixel relative to scale
local function SnapToScale(val, px)
    return math.floor(val / px + 0.5) * px
end

-- Update layout for a specific container and its indicators
function ns.UpdateContainerLayout(container)
    local db = ns.db or ns.defaults

    -- Calculate pixel size relative to the container's effective scale
    local screenHeight = select(2, GetPhysicalScreenSize())
    local scale = container:GetEffectiveScale()
    if scale == 0 then scale = 1 end
    local px = (768.0 / screenHeight) / scale

    -- Snap container anchor to global pixel grid
    container:ClearAllPoints()
    local anchor = db.anchor or ns.defaults.anchor
    local relPoint = db.relativePoint or ns.defaults.relativePoint
    local x = db.x or ns.defaults.x
    local y = db.y or ns.defaults.y
    PixelUtil.SetPoint(container, anchor, container:GetParent(), relPoint, x, y)

    local grow = db.growDirection or ns.defaults.growDirection
    local rawSize = db.size or ns.defaults.size
    local rawSpacing = db.spacing or ns.defaults.spacing

    -- Snap dimensions to local pixel grid
    local size = SnapToScale(rawSize, px)
    local spacing = SnapToScale(rawSpacing, px)

    -- Calculate inner size for exact 1px border
    local innerSize = size - (2 * px)
    if innerSize < 0 then innerSize = 0 end

    for i, indicator in ipairs(container.arenaEnemyIndicators) do
        indicator:SetSize(size, size)
        indicator.inner:SetSize(innerSize, innerSize)

        -- Center inner texture for symmetry
        indicator.inner:ClearAllPoints()
        indicator.inner:SetPoint("CENTER", indicator, "CENTER", 0, 0)

        if db.showIndex then
            indicator.text:Show()
            indicator.text:SetText(i)
            local fName, _, fFlags = indicator.text:GetFont()
            indicator.text:SetFont(fName, db.fontSize or 10, fFlags)
        else
            indicator.text:Hide()
        end

        indicator:ClearAllPoints()

        if i == 1 then
            -- First indicator anchors to container handle
            indicator:SetPoint(anchor, container, anchor, 0, 0)
        else
            -- Anchor subsequent indicators to the previous one to prevent rounding drift
            local prev = container.arenaEnemyIndicators[i - 1]

            if grow == "RIGHT" then
                indicator:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
            elseif grow == "LEFT" then
                indicator:SetPoint("RIGHT", prev, "LEFT", -spacing, 0)
            elseif grow == "UP" then
                indicator:SetPoint("BOTTOM", prev, "TOP", 0, spacing)
            elseif grow == "DOWN" then
                indicator:SetPoint("TOP", prev, "BOTTOM", 0, -spacing)
            end
        end

        -- Apply dummy data for test containers
        if container.isTest then
            indicator:Show()
            indicator:SetAlpha(1)
            local c = TEST_COLORS[i]
            if c then
                indicator.inner:SetColorTexture(c.r, c.g, c.b, 1)
            else
                indicator.inner:SetColorTexture(1, 1, 1, 1)
            end
        end
    end
end

-- Force layout refresh for all containers
function ns.UpdateAll()
    for _, container in ipairs(ns.containers) do
        ns.UpdateContainerLayout(container)
    end
end

-- Helper to force hide all indicators (e.g. when leaving arena)
function ns.ResetIndicators()
    for _, container in ipairs(ns.containers) do
        -- Only hide indicators on real party frames, leave preview frames alone
        if not container.isTest then
            for _, indicator in ipairs(container.arenaEnemyIndicators) do
                indicator:Hide()
            end
        end
    end
end

-- Initializes a container frame and indicator pool
function ns.CreateContainer(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(1, 1)

    container.arenaEnemyIndicators = {}

    for i = 1, 3 do
        local indicator = CreateFrame("Frame", nil, container)
        indicator:SetFrameLevel(parent:GetFrameLevel() + 10)

        local border = indicator:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(0, 0, 0, 1)

        local inner = indicator:CreateTexture(nil, "ARTWORK")
        indicator.inner = inner

        local text = indicator:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("CENTER", indicator, "CENTER", 0, 0)
        indicator.text = text

        indicator:Hide()
        container.arenaEnemyIndicators[i] = indicator
    end

    container:Show()
    table.insert(ns.containers, container)

    ns.UpdateContainerLayout(container)

    return container
end

-- Resets settings to default values
function ns.ResetSettings()
    wipe(ns.db)
    for k, v in pairs(ns.defaults) do
        ns.db[k] = v
    end
    ns.UpdateAll()

    -- Update options UI if currently open
    if ns.RefreshOptionUI then ns.RefreshOptionUI() end
    print("|cff33ff99ArenaTargeted:|r Settings reset to default.")
end

function ns.SlashCommandHandler(msg)
    local command = msg:lower()

    if command == "reset" then
        ns.ResetSettings()
    else
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(ns.categoryID)
        else
            InterfaceOptionsFrame_OpenToCategory("ArenaTargeted")
        end
    end
end

-- Initializes the addon and attaches containers to party frames
function ns.Init()
    for i = 1, 5 do
        local frameName = "CompactPartyFrameMember" .. i
        local parentFrame = _G[frameName]

        if parentFrame and not parentFrame.ATPContainer then
            parentFrame.ATPContainer = ns.CreateContainer(parentFrame)
        end
    end
end

function ns.SetupSystemEvents()
    local systemListener = CreateFrame("FRAME")
    systemListener:RegisterEvent("UI_SCALE_CHANGED")
    systemListener:RegisterEvent("DISPLAY_SIZE_CHANGED")

    systemListener:SetScript("OnEvent", function()
        ns.UpdateAll()
    end)
end

function ns.SetupCombatEvents()
    local combatListener = CreateFrame("FRAME", nil, UIParent)
    -- Standard target updates
    combatListener:RegisterUnitEvent("UNIT_TARGET", "arena1", "arena2", "arena3")
    -- Handle enemies leaving the game (or stealthing/vanishing)
    combatListener:RegisterEvent("ARENA_OPPONENT_UPDATE")
    -- Handle player leaving the arena (clears stuck indicators)
    combatListener:RegisterEvent("PLAYER_ENTERING_WORLD")

    combatListener:SetScript("OnEvent", function(self, event, unit)
        if event == "PLAYER_ENTERING_WORLD" then
            ns.ResetIndicators()
            return
        end

        local arenaIndex = tonumber(string_match(unit or "", "arena(%d+)"))
        if not arenaIndex then return end

        local unitTarget = unit .. "target"
        local r, g, b = GetUnitColor(unit)

        for _, container in ipairs(ns.containers) do
            local parent = container:GetParent()

            -- Skip test containers during combat events
            if not container.isTest then
                local indicator = container.arenaEnemyIndicators[arenaIndex]

                if indicator then
                    -- If the enemy exists (r is valid) and we have a valid party unit to compare against
                    if r and parent.unit then
                        local isMatch = UnitIsUnit(unitTarget, parent.unit)
                        indicator.inner:SetColorTexture(r, g, b, 1)
                        indicator:Show()
                        indicator:SetAlphaFromBoolean(isMatch)
                    else
                        -- Enemy left or data invalid -> Hide
                        indicator:Hide()
                    end
                end
            end
        end
    end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not ArenaTargetedDB then ArenaTargetedDB = {} end
        ns.db = ArenaTargetedDB

        for k, v in pairs(ns.defaults) do
            if ns.db[k] == nil then ns.db[k] = v end
        end

        ns.SetupSystemEvents()
        ns.SetupCombatEvents()
        ns.Init()

        if ns.SetupOptions then
            ns.SetupOptions()
        end

        SLASH_ARENATARGETED1 = "/at"
        SLASH_ARENATARGETED2 = "/arenatargeted"
        SlashCmdList["ARENATARGETED"] = function(msg) ns.SlashCommandHandler(msg) end

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

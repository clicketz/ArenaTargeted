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

-- Default configuration
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
ns.testFrame = nil
ns.categoryID = nil

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

-- Updates the layout for a single container and its indicators
function ns.UpdateContainerLayout(container)
    local db = ns.db or ns.defaults

    -- Get exact size of 1 physical pixel
    local px = PixelUtil.GetPixelToUIUnitFactor()

    -- Position container handle (Snapped to pixel grid)
    container:ClearAllPoints()
    local anchor = db.anchor or ns.defaults.anchor
    local relPoint = db.relativePoint or ns.defaults.relativePoint

    -- PixelUtil.SetPoint automatically snaps the offset to the nearest physical pixel
    PixelUtil.SetPoint(container, anchor, container:GetParent(), relPoint, db.x, db.y)

    -- Update indicators
    local grow = db.growDirection or "RIGHT"
    local size = db.size or 12
    local spacing = db.spacing or 2

    for i, indicator in ipairs(container.arenaEnemyIndicators) do
        -- PixelUtil.SetSize snaps the width/height to prevent blurring
        PixelUtil.SetSize(indicator, size, size)

        -- We manually use 'px' here to ensure the border is exactly 1 physical pixel wide
        indicator.inner:ClearAllPoints()
        indicator.inner:SetPoint("TOPLEFT", indicator, "TOPLEFT", px, -px)
        indicator.inner:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -px, px)

        -- Index text
        if db.showIndex then
            indicator.text:Show()
            indicator.text:SetText(i)
            local fName, _, fFlags = indicator.text:GetFont()
            indicator.text:SetFont(fName, db.fontSize or 10, fFlags)
        else
            indicator.text:Hide()
        end

        -- Positioning
        indicator:ClearAllPoints()

        if i == 1 then
            -- Mirror anchor to ensure precise corner alignment
            PixelUtil.SetPoint(indicator, anchor, container, anchor, 0, 0)
        else
            local prev = container.arenaEnemyIndicators[i - 1]
            if grow == "RIGHT" then
                PixelUtil.SetPoint(indicator, "LEFT", prev, "RIGHT", spacing, 0)
            elseif grow == "LEFT" then
                PixelUtil.SetPoint(indicator, "RIGHT", prev, "LEFT", -spacing, 0)
            elseif grow == "UP" then
                PixelUtil.SetPoint(indicator, "BOTTOM", prev, "TOP", 0, spacing)
            elseif grow == "DOWN" then
                PixelUtil.SetPoint(indicator, "TOP", prev, "BOTTOM", 0, -spacing)
            end
        end

        -- Apply dummy data if attached to test frame
        if container:GetParent() == ns.testFrame then
            indicator:Show()
            indicator:SetAlpha(1)
            local c
            if i == 1 then
                c = C_ClassColor.GetClassColor("MAGE")
            elseif i == 2 then
                c = C_ClassColor.GetClassColor("ROGUE")
            elseif i == 3 then
                c = C_ClassColor.GetClassColor("DRUID")
            end

            if c then
                indicator.inner:SetColorTexture(c.r, c.g, c.b, 1)
            else
                indicator.inner:SetColorTexture(1, 1, 1, 1)
            end
        end
    end
end

-- Force update all containers
function ns.UpdateAll()
    for _, container in ipairs(ns.containers) do
        ns.UpdateContainerLayout(container)
    end
end

-- Initialize a new container frame
function ns.CreateContainer(parent)
    local container = CreateFrame("Frame", nil, parent)
    -- Use PixelUtil to snap the container size (probably unnecessary)
    PixelUtil.SetSize(container, 1, 1)

    container.arenaEnemyIndicators = {}

    for i = 1, 3 do
        local indicator = CreateFrame("Frame", nil, container)
        indicator:SetFrameLevel(parent:GetFrameLevel() + 10)

        -- Outer Border (Black)
        local border = indicator:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(0, 0, 0, 1)

        -- Inner Color (Inset handled in UpdateLayout)
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

-- Test Frame Management
function ns.CreateTestFrame()
    if ns.testFrame then return end

    local width, height = 100, 50
    local scale = 1

    local realFrame = _G["CompactPartyFrameMember1"]
    if realFrame and realFrame:IsVisible() then
        width, height = realFrame:GetSize()
        scale = realFrame:GetEffectiveScale() / UIParent:GetScale()
    end

    local f = CreateFrame("Frame", "ArenaTargetedTestFrame", UIParent)
    f:SetSize(width, height)
    f:SetScale(scale)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    -- Black border
    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)

    -- Class colored background
    local bg = f:CreateTexture(nil, "BORDER")
    local px = PixelUtil.GetPixelToUIUnitFactor()
    bg:SetPoint("TOPLEFT", f, "TOPLEFT", px, -px)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -px, px)

    local _, class = UnitClass("player")
    local c = C_ClassColor.GetClassColor(class or "PRIEST")
    bg:SetColorTexture(c.r, c.g, c.b, 1)

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("BOTTOM", f, "TOP", 0, 10)
    text:SetText("ArenaTargeted Test")
    text:SetTextColor(1, 1, 1, 1)

    f.ATPContainer = ns.CreateContainer(f)

    f:Hide()
    ns.testFrame = f

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
end

function ns.ToggleTestMode(enable)
    if not ns.testFrame then ns.CreateTestFrame() end

    if enable then
        ns.testFrame:Show()
        print("|cff33ff99ArenaTargeted:|r Test Mode Enabled")
    else
        ns.testFrame:Hide()
        print("|cff33ff99ArenaTargeted:|r Test Mode Disabled")
    end
    ns.UpdateAll()
end

-- Slash Command Handler
function ns.SlashCommandHandler(msg)
    local command = msg:lower()

    if command == "test" then
        local currentlyShown = ns.testFrame and ns.testFrame:IsShown()
        ns.ToggleTestMode(not currentlyShown)
    elseif command == "reset" then
        ns.db = {}
        for k, v in pairs(ns.defaults) do
            ns.db[k] = v
        end
        ns.UpdateAll()

        if ns.RefreshOptionUI then ns.RefreshOptionUI() end

        print("|cff33ff99ArenaTargeted:|r Settings reset to default.")
    else
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(ns.categoryID)
        else
            InterfaceOptionsFrame_OpenToCategory("ArenaTargeted")
        end
    end
end

-- Events & Initialization
function ns.Init()
    ns.CreateTestFrame()

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
    systemListener:RegisterEvent("PLAYER_ENTERING_WORLD")
    systemListener:RegisterEvent("GROUP_ROSTER_UPDATE")

    systemListener:SetScript("OnEvent", function()
        ns.Init()
    end)
end

function ns.SetupCombatEvents()
    local combatListener = CreateFrame("FRAME", nil, UIParent)
    combatListener:RegisterUnitEvent("UNIT_TARGET", "arena1", "arena2", "arena3")

    combatListener:SetScript("OnEvent", function(_, _, unit)
        local arenaIndex = tonumber(string_match(unit, "arena(%d+)"))
        if not arenaIndex then return end

        local unitTarget = unit .. "target"
        local r, g, b = GetUnitColor(unit)

        if r then
            for _, container in ipairs(ns.containers) do
                local parent = container:GetParent()
                if parent ~= ns.testFrame then
                    local indicator = container.arenaEnemyIndicators[arenaIndex]
                    if parent.unit then
                        local isMatch = UnitIsUnit(unitTarget, parent.unit)
                        indicator.inner:SetColorTexture(r, g, b, 1)
                        indicator:Show()
                        indicator:SetAlphaFromBoolean(isMatch)
                    else
                        indicator:Hide()
                    end
                end
            end
        else
            for _, container in ipairs(ns.containers) do
                if container:GetParent() ~= ns.testFrame then
                    local indicator = container.arenaEnemyIndicators[arenaIndex]
                    indicator:Hide()
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
        SlashCmdList["ARENATARGETED"] = function(msg) ns.SlashCommandHandler(msg) end

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

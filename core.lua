local addonName, ns = ...

local string_match = string.match
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local Settings = Settings
local PixelUtil = PixelUtil

ns.containers = {}

-- Update layout for a specific container and its indicators
function ns.UpdateContainerLayout(container)
    local db = ns.db or ns.defaults
    local px = ns.GetPixelScale(container)
    local parent = container:GetParent()

    -- Get the current Shape Definition
    local shapeName = db.shape or ns.defaults.shape
    local shapeDef = ns.shapes[shapeName] or ns.shapes["Box"]

    -- Snap container anchor to global pixel grid
    container:ClearAllPoints()
    local anchor = db.anchor or ns.defaults.anchor
    local relPoint = db.relativePoint or ns.defaults.relativePoint
    local x = db.x or ns.defaults.x
    local y = db.y or ns.defaults.y
    PixelUtil.SetPoint(container, anchor, parent, relPoint, x, y)

    local width, height = shapeDef.GetSize(db, parent, px)
    local grow = db.growDirection or ns.defaults.growDirection
    local spacing = ns.SnapToScale(db.spacing or ns.defaults.spacing, px)

    local borderSize = db.borderSize or ns.defaults.borderSize

    for i, indicator in ipairs(container.arenaEnemyIndicators) do
        indicator:SetSize(width, height)

        -- Apply shape styling (Sets the texture file/shape)
        shapeDef.Setup(indicator, width, height, px, borderSize)

        if db.showIndex then
            indicator.text:Show()
            indicator.text:SetText(i)
            local fName, _, fFlags = indicator.text:GetFont()
            indicator.text:SetFont(fName, db.fontSize or ns.defaults.fontSize, fFlags)
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

        -- Apply dummy data for preview container
        if container.isPreview then
            -- Only show the first 3 for preview to keep it clean, but backend supports 5
            local c = ns.PREVIEW_COLORS[i]
            if c and i <= 3 then
                indicator:Show()
                indicator:SetAlpha(1)
                indicator.inner:SetVertexColor(c.r, c.g, c.b, 1)
            else
                indicator:Hide()
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
        if not container.isPreview then
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

    -- Initialize for MAX_ARENA_ENEMIES (5) to ensure robustness
    for i = 1, ns.CONSTANTS.MAX_ARENA_ENEMIES do
        local indicator = CreateFrame("Frame", nil, container)
        indicator:SetFrameLevel(parent:GetFrameLevel() + 10)

        -- Indicators are purely visual, disable mouse to prevent blocking clicks
        indicator:EnableMouse(false)

        local border = indicator:CreateTexture(nil, "BACKGROUND")
        indicator.border = border

        local inner = indicator:CreateTexture(nil, "ARTWORK")
        indicator.inner = inner

        local text = indicator:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("CENTER", indicator, "CENTER", 0, 0)
        indicator.text = text

        indicator:Hide()
        container.arenaEnemyIndicators[i] = indicator
    end

    -- Need to update layout when parent size changes or scaling will be off
    if parent.HookScript then
        parent:HookScript("OnSizeChanged", function()
            ns.UpdateContainerLayout(container)
        end)
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
    -- Register all potential arena enemies (1-5)
    -- NOTE: Registering 5 because blizzard sometimes sends arena4/5 in events even in smaller brackets
    combatListener:RegisterUnitEvent("UNIT_TARGET", "arena1", "arena2", "arena3", "arena4", "arena5")
    combatListener:RegisterEvent("ARENA_OPPONENT_UPDATE")
    combatListener:RegisterEvent("PLAYER_ENTERING_WORLD")

    combatListener:SetScript("OnEvent", function(self, event, unit)
        if event == "PLAYER_ENTERING_WORLD" then
            ns.ResetIndicators()
            return
        end

        local arenaIndex = tonumber(string_match(unit or "", "arena(%d+)"))
        if not arenaIndex then return end

        local unitTarget = unit .. "target"
        local r, g, b = ns.GetUnitColor(unit)

        for _, container in ipairs(ns.containers) do
            local parent = container:GetParent()

            -- Skip preview containers during combat events
            if not container.isPreview then
                local indicator = container.arenaEnemyIndicators[arenaIndex]

                if indicator then
                    -- If the enemy exists (r is valid) and we have a valid party unit to compare against
                    if r and parent.unit then
                        -- NOTE: UnitIsUnit returns a secret value in midnight
                        local isMatch = UnitIsUnit(unitTarget, parent.unit)

                        indicator.inner:SetVertexColor(r, g, b, 1)
                        indicator:Show()

                        -- SetAlphaFromBoolean can safely handle secret values
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

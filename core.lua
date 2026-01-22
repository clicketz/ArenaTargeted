local _, ns = ...

-- Upvalues
local UnitExists = UnitExists
local string_match = string.match
local tonumber = tonumber
local ipairs = ipairs
local UnitClass = UnitClass
local C_ClassColor = C_ClassColor

ns.containers = {}

-- Returns nil if unit or class is invalid
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

function ns.CreateContainer(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(60, 20)
    container:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 2, 0)

    container.arenaEnemyIndicators = {}

    for i = 1, 3 do
        local indicator = CreateFrame("Frame", nil, container)
        indicator:SetSize(12, 12)

        -- Black Border
        local border = indicator:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(0, 0, 0, 1)

        -- Inner Class Color (Inset 1px)
        local inner = indicator:CreateTexture(nil, "ARTWORK")
        inner:SetPoint("TOPLEFT", indicator, "TOPLEFT", 1, -1)
        inner:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -1, 1)
        indicator.inner = inner

        -- Layout: Left to Right
        if i == 1 then
            indicator:SetPoint("LEFT", container, "LEFT", 0, 0)
        else
            indicator:SetPoint("LEFT", container.arenaEnemyIndicators[i - 1], "RIGHT", 2, 0)
        end

        indicator:Hide()
        container.arenaEnemyIndicators[i] = indicator
    end

    container:Show()
    table.insert(ns.containers, container)

    return container
end

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
                local indicator = container.arenaEnemyIndicators[arenaIndex]

                if parent.unit then
                    -- Patch 12.0: UnitIsUnit returns a Secret Value
                    local isMatch = UnitIsUnit(unitTarget, parent.unit)

                    indicator.inner:SetColorTexture(r, g, b, 1)
                    indicator:Show()

                    -- Use SetAlphaFromBoolean to safely handle the Secret Value
                    indicator:SetAlphaFromBoolean(isMatch)
                else
                    indicator:Hide()
                end
            end
        else
            for _, container in ipairs(ns.containers) do
                local indicator = container.arenaEnemyIndicators[arenaIndex]
                indicator:Hide()
            end
        end
    end)
end

function ns.OnInitialize()
    --ns.SetupSystemEvents()
    ns.SetupCombatEvents()
    ns.Init()
end

ns.OnInitialize()

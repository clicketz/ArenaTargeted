local addonName, ns = ...

local UnitExists = UnitExists
local UnitClass = UnitClass
local UnitHonor = UnitHonor
local UnitIsUnit = UnitIsUnit

local ARENA_INDICES = {
    ["arena1"] = 1, ["arena2"] = 2, ["arena3"] = 3, ["arena4"] = 4, ["arena5"] = 5
}

local ARENA_TARGETS = {
    ["arena1"] = "arena1target",
    ["arena2"] = "arena2target",
    ["arena3"] = "arena3target",
    ["arena4"] = "arena4target",
    ["arena5"] = "arena5target"
}

function ns.SetupCombatEvents()
    local combatListener = CreateFrame("FRAME", nil, UIParent)
    combatListener:RegisterUnitEvent("UNIT_TARGET", "arena1", "arena2", "arena3", "arena4", "arena5")
    combatListener:RegisterEvent("ARENA_OPPONENT_UPDATE")
    combatListener:RegisterEvent("PLAYER_ENTERING_WORLD")

    combatListener:SetScript("OnEvent", function(self, event, unit)
        if event == "PLAYER_ENTERING_WORLD" then
            ns.Container.ResetAll()
            return
        end

        local arenaIndex = ARENA_INDICES[unit]
        if not arenaIndex then return end

        local unitTarget = ARENA_TARGETS[unit]
        local r, g, b = ns.GetUnitColor(unit)

        local targetClass, targetHonor
        if UnitExists(unitTarget) then
            local _, classFilename = UnitClass(unitTarget)
            targetClass = classFilename
            targetHonor = UnitHonor(unitTarget)
        end

        local instances = ns.Container.instances
        local heuristicMatchFound = false

        for i = 1, #instances do
            local container = instances[i]
            local parent = container:GetParent()

            if r and parent.unit then
                local isMatch = false

                if UnitIsUnit("player", parent.unit) then
                    isMatch = UnitIsUnit(unitTarget, "player")
                else
                    if not heuristicMatchFound and targetClass then
                        local _, frameClass = UnitClass(parent.unit)

                        if frameClass == targetClass then
                            local frameHonor = UnitHonor(parent.unit)
                            if frameHonor == targetHonor then
                                isMatch = true
                                heuristicMatchFound = true
                            end
                        end
                    end
                end

                container:UpdateEnemyState(arenaIndex, r, g, b, isMatch)
            else
                container:UpdateEnemyState(arenaIndex, nil)
            end
        end
    end)
end

function ns.SetupSystemEvents()
    local systemListener = CreateFrame("FRAME")
    systemListener:RegisterEvent("UI_SCALE_CHANGED")
    systemListener:RegisterEvent("DISPLAY_SIZE_CHANGED")
    systemListener:SetScript("OnEvent", function()
        ns.Container.UpdateAll()
    end)
end

function ns.Init()
    for i = 1, 5 do
        local frameName = "CompactPartyFrameMember" .. i
        local parentFrame = _G[frameName]
        if parentFrame and not parentFrame.ATContainer then
            parentFrame.ATContainer = ns.Container.Create(parentFrame)
        end
    end
end

function ns.ResetSettings()
    wipe(ns.db)
    for k, v in pairs(ns.defaults) do
        ns.db[k] = v
    end

    ns.Container.UpdateAll()

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
            InterfaceOptionsFrame_OpenToCategory(addonName)
        end
    end
end

local function OnPlayerLogin()
    if not ArenaTargetedDB then ArenaTargetedDB = {} end
    ns.db = ArenaTargetedDB

    for k, v in pairs(ns.defaults) do
        if ns.db[k] == nil then ns.db[k] = v end
    end

    ns.SetupSystemEvents()
    ns.SetupCombatEvents()
    ns.Init()
    ns.SetupOptions()

    SLASH_ARENATARGETED1 = "/at"
    SLASH_ARENATARGETED2 = "/arenatargeted"
    SlashCmdList["ARENATARGETED"] = function(msg) ns.SlashCommandHandler(msg) end
end

EventRegistry:RegisterFrameEventAndCallback("PLAYER_LOGIN", OnPlayerLogin)

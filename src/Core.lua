local addonName, ns = ...

local UnitExists = UnitExists
local UnitClass = UnitClass
local UnitHonorLevel = UnitHonorLevel
local UnitHonor = UnitHonor
local UnitIsUnit = UnitIsUnit

local ARENA_INDICES = {
    ["arena1"] = 1,
    ["arena2"] = 2,
    ["arena3"] = 3,
}
local ARENA_TARGETS = {
    ["arena1"] = "arena1target",
    ["arena2"] = "arena2target",
    ["arena3"] = "arena3target",
}
local PARTY_INDICES = {
    ["player"] = 1,
    ["party1"] = 2,
    ["party2"] = 3,
}
local PARTY_TARGETS = {
    ["player"] = "playertarget",
    ["party1"] = "party1target",
    ["party2"] = "party2target",
}

local function GetFrameUnit(frame, frameType)
    if frame.unit then return frame.unit end

    local attrUnit = frame:GetAttribute("unit")
    if attrUnit then return attrUnit end

    return nil
end

local function OnUnitTargetUpdate(unit)
    local arenaIndex = ARENA_INDICES[unit]
    local partyIndex = PARTY_INDICES[unit]

    if not arenaIndex and not partyIndex then return end

    local sourceFrameType = arenaIndex and "party" or "arena"
    local sourceIndex = arenaIndex or partyIndex
    local unitTarget = arenaIndex and ARENA_TARGETS[unit] or PARTY_TARGETS[unit]

    local skipUpdate = false
    if sourceFrameType == "arena" and unit == "player" then
        if not ns.db.arena.showPlayer then
            skipUpdate = true
        end
    end

    local r, g, b = ns.GetUnitColor(unit)
    local targetClass, targetHeuristic

    if not skipUpdate and UnitExists(unitTarget) then
        local _, class = UnitClass(unitTarget)
        targetClass = class
        targetHeuristic = UnitHonorLevel(unitTarget)
    end

    local instances = ns.Container.instances
    local heuristicMatchFound = false

    for i = 1, #instances do
        local container = instances[i]

        if container.frameType == sourceFrameType then
            if skipUpdate then
                container:UpdateEnemyState(sourceIndex, nil)
            else
                local parent = container:GetParent()
                local frameUnit = GetFrameUnit(parent, container.frameType)

                if r and frameUnit then
                    local isMatch = false

                    if UnitIsUnit(frameUnit, unitTarget) then
                        isMatch = true
                    else
                        if not heuristicMatchFound and targetClass then
                            local _, frameClass = UnitClass(frameUnit)
                            if frameClass == targetClass then
                                local frameHeuristic = UnitHonorLevel(frameUnit)
                                if frameHeuristic == targetHeuristic then
                                    isMatch = true
                                    heuristicMatchFound = true
                                end
                            end
                        end
                    end

                    container:UpdateEnemyState(sourceIndex, r, g, b, isMatch)
                else
                    container:UpdateEnemyState(sourceIndex, nil)
                end
            end
        end
    end
end

function ns.ForceUpdateTargetStates()
    for unit in pairs(ARENA_INDICES) do OnUnitTargetUpdate(unit) end
    for unit in pairs(PARTY_INDICES) do OnUnitTargetUpdate(unit) end
end

function ns.SetupCombatEvents()
    local masterListener = CreateFrame("FRAME", nil, UIParent)
    masterListener:RegisterEvent("PLAYER_ENTERING_WORLD")
    masterListener:RegisterEvent("ARENA_OPPONENT_UPDATE")
    masterListener:RegisterEvent("GROUP_ROSTER_UPDATE")
    masterListener:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            ns.Container.ResetAll()
        end
        ns.TryInjectFrames()
        ns.Container.UpdateAll()
        ns.ForceUpdateTargetStates()
    end)

    local arenaListener = CreateFrame("FRAME", nil, UIParent)
    arenaListener:RegisterUnitEvent("UNIT_TARGET", "arena1", "arena2", "arena3")
    arenaListener:SetScript("OnEvent", function(self, event, unit)
        OnUnitTargetUpdate(unit)
    end)

    local partyListener = CreateFrame("FRAME", nil, UIParent)
    partyListener:RegisterUnitEvent("UNIT_TARGET", "player", "party1", "party2")
    partyListener:SetScript("OnEvent", function(self, event, unit)
        OnUnitTargetUpdate(unit)
    end)
end

function ns.TryInjectFrames()
    for i = 1, 5 do
        local partyFrame = _G["CompactPartyFrameMember" .. i]
        if partyFrame and not partyFrame.ATContainer then
            partyFrame.ATContainer = ns.Container.Create(partyFrame, "party")
        end
    end

    for i = 1, 5 do
        local arenaFrame = _G["CompactArenaFrameMember" .. i]
        if arenaFrame and not arenaFrame.ATContainer then
            arenaFrame.ATContainer = ns.Container.Create(arenaFrame, "arena")
        end

        local legacyArenaFrame = _G["ArenaEnemyMatchFrame" .. i] or _G["ArenaEnemyFrame" .. i]
        if legacyArenaFrame and not legacyArenaFrame.ATContainer then
            legacyArenaFrame.ATContainer = ns.Container.Create(legacyArenaFrame, "arena")
        end
    end
end

function ns.SetupSystemEvents()
    local systemListener = CreateFrame("FRAME")
    systemListener:RegisterEvent("UI_SCALE_CHANGED")
    systemListener:RegisterEvent("DISPLAY_SIZE_CHANGED")
    systemListener:SetScript("OnEvent", function()
        ns.Container.UpdateAll()
    end)
end

function ns.ResetSettings()
    wipe(ns.db.party)
    wipe(ns.db.arena)

    for k, v in pairs(ns.defaults.party) do ns.db.party[k] = v end
    for k, v in pairs(ns.defaults.arena) do ns.db.arena[k] = v end

    ns.Container.UpdateAll()
    ns.ForceUpdateTargetStates()

    ns.RefreshOptionUI()
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

    if ArenaTargetedDB.shape or ArenaTargetedDB.anchor then
        local oldDB = CopyTable(ArenaTargetedDB)
        wipe(ArenaTargetedDB)
        ArenaTargetedDB.party = oldDB
        ArenaTargetedDB.arena = CopyTable(ns.defaults.arena)
    end

    ns.db = ArenaTargetedDB

    for frameType, defaults in pairs(ns.defaults) do
        if not ns.db[frameType] then ns.db[frameType] = {} end
        for k, v in pairs(defaults) do
            if ns.db[frameType][k] == nil then ns.db[frameType][k] = v end
        end
    end

    ns.SetupSystemEvents()
    ns.SetupCombatEvents()
    ns.TryInjectFrames()
    ns.SetupOptions()

    SLASH_ARENATARGETED1 = "/at"
    SLASH_ARENATARGETED2 = "/arenatargeted"
    SlashCmdList["ARENATARGETED"] = function(msg) ns.SlashCommandHandler(msg) end
end

EventRegistry:RegisterFrameEventAndCallback("PLAYER_LOGIN", OnPlayerLogin)

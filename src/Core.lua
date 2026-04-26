local addonName, ns = ...

local UnitExists = UnitExists
local UnitClass = UnitClass
local UnitHonorLevel = UnitHonorLevel
local UnitIsUnit = UnitIsUnit

local ARENA_INDICES = {}
local ARENA_TARGETS = {}
for i = 1, ns.CONSTANTS.MAX_ARENA_ENEMIES do
    ARENA_INDICES["arena" .. i] = i
    ARENA_TARGETS["arena" .. i] = "arena" .. i .. "target"
end

local PARTY_INDICES = { ["player"] = 1 }
local PARTY_TARGETS = { ["player"] = "target" }
for i = 2, ns.CONSTANTS.MAX_PARTY_MEMBERS do
    PARTY_INDICES["party" .. (i - 1)] = i
    PARTY_TARGETS["party" .. (i - 1)] = "party" .. (i - 1) .. "target"
end

ns.testMode = false

function ns.ToggleTestMode()
    ns.testMode = not ns.testMode

    if ns.testMode then
        ns.Container.UpdateAll()
    else
        ns.Container.ResetAll()
        ns.Container.UpdateAll()
        ns.ForceUpdateTargetStates()
    end

    if ns.RefreshOptionUI then ns.RefreshOptionUI() end

    print("|cff33ff99ArenaTargeted:|r Test mode " .. (ns.testMode and "|cff00ff00ON|r" or "|cffff0000OFF|r") .. ".")
end

local function GetFrameUnit(frame, frameType)
    if frame.unit then return frame.unit end

    local attr = frame:GetAttribute("unit")
    if attr then return attr end

    local name = frame:GetName()
    if name then
        local id = name:match("%d+")
        if id then
            return frameType .. id
        end
    end

    return nil
end

local function OnUnitTargetUpdate(unit)
    if ns.testMode then return end

    local arenaIndex = ARENA_INDICES[unit]
    local partyIndex = PARTY_INDICES[unit]

    if not arenaIndex and not partyIndex then return end

    local sourceFrameType = arenaIndex and "party" or "arena"
    local sourceIndex = arenaIndex or partyIndex
    local unitTarget = arenaIndex and ARENA_TARGETS[unit] or PARTY_TARGETS[unit]

    local skipUpdate = false

    if not ns.db[sourceFrameType].enabled then
        skipUpdate = true
    end

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

    for i = 1, #instances do
        local container = instances[i]

        if container.frameType == sourceFrameType and not container.isPreview then
            if skipUpdate then
                container:UpdateEnemyState(sourceIndex, nil)
            else
                local parent = container:GetParent()
                local frameUnit = GetFrameUnit(parent, container.frameType)

                if r and frameUnit then
                    local isMatch = false

                    if frameUnit == "player" or unitTarget == "target" then
                        isMatch = UnitIsUnit(frameUnit, unitTarget)
                    elseif targetClass then
                        local _, frameClass = UnitClass(frameUnit)
                        if frameClass == targetClass then
                            local frameHeuristic = UnitHonorLevel(frameUnit)
                            if frameHeuristic == targetHeuristic then
                                isMatch = true
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

-- RegisterUnitEvent can only register up to 4 units, so we create multiple listeners if needed
local function RegisterChunkedUnitEvents(units)
    for i = 1, #units, 4 do
        local listener = CreateFrame("FRAME", nil, UIParent)
        local chunk = {}
        for j = 0, 3 do
            local u = units[i + j]
            if u then
                table.insert(chunk, u)
            end
        end
        listener:RegisterUnitEvent("UNIT_TARGET", unpack(chunk))
        listener:SetScript("OnEvent", function(self, event, unit)
            OnUnitTargetUpdate(unit)
        end)
    end
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

    local arenaUnits = {}
    for key in pairs(ARENA_INDICES) do table.insert(arenaUnits, key) end
    RegisterChunkedUnitEvents(arenaUnits)

    local partyUnits = {}
    for key in pairs(PARTY_INDICES) do table.insert(partyUnits, key) end
    RegisterChunkedUnitEvents(partyUnits)
end

function ns.TryInjectFrames()
    for i = 1, ns.CONSTANTS.MAX_PARTY_MEMBERS do
        local partyFrame = _G["CompactPartyFrameMember" .. i]
        if partyFrame and not partyFrame.ATContainer then
            partyFrame.ATContainer = ns.Container.Create(partyFrame, "party")
        end
    end

    if C_AddOns.IsAddOnLoaded("sArena_Reloaded") then
        for i = 1, ns.CONSTANTS.MAX_ARENA_ENEMIES do
            local sArenaFrame = _G["sArenaEnemyFrame" .. i]
            if sArenaFrame and not sArenaFrame.ATContainer then
                sArenaFrame.ATContainer = ns.Container.Create(sArenaFrame, "arena")
            end
        end
        return
    end

    for i = 1, ns.CONSTANTS.MAX_ARENA_ENEMIES do
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
    elseif command == "test" then
        ns.ToggleTestMode()
    else
        if InCombatLockdown() then
            print("|cff33ff99ArenaTargeted:|r Cannot open settings while in combat.")
        else
            Settings.OpenToCategory(ns.categoryID)
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

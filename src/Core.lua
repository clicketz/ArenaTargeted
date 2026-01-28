local addonName, ns = ...

local string_match = string.match
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local Settings = Settings

--[[ events ]]

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

        local arenaIndex = tonumber(string_match(unit or "", "arena(%d+)"))
        if not arenaIndex then return end

        local unitTarget = unit .. "target"
        local r, g, b = ns.GetUnitColor(unit)

        for _, container in ipairs(ns.Container.instances) do
            local parent = container:GetParent()

            if r and parent.unit then
                local isMatch = UnitIsUnit(unitTarget, parent.unit)
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

--[[ initialization & settings ]]

function ns.Init()
    for i = 1, 5 do
        local frameName = "CompactPartyFrameMember" .. i
        local parentFrame = _G[frameName]
        if parentFrame and not parentFrame.ATPContainer then
            parentFrame.ATPContainer = ns.Container.Create(parentFrame)
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
        ns.SetupOptions()

        SLASH_ARENATARGETED1 = "/at"
        SLASH_ARENATARGETED2 = "/arenatargeted"
        SlashCmdList["ARENATARGETED"] = function(msg) ns.SlashCommandHandler(msg) end

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

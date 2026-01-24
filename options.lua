local _, ns = ...
local Settings = Settings

function ns.SetupOptions()
    local panel = CreateFrame("Frame")
    panel.name = "ArenaTargeted"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("ArenaTargeted Settings")

    -- Registry for widget refresh functions
    -- We store small functions here that know how to update each specific widget
    local refreshFuncs = {}

    function ns.RefreshOptionUI()
        for _, func in ipairs(refreshFuncs) do
            func()
        end
    end

    -- Sidebar: Slash Commands
    local helpPanel = CreateFrame("Frame", nil, panel)
    helpPanel:SetSize(200, 150)
    helpPanel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -20)

    local helpTitle = helpPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    helpTitle:SetPoint("TOPLEFT", 0, 0)
    helpTitle:SetText("Slash Commands")

    local function AddCommand(cmd, desc, prev)
        local c = helpPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        c:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -12)
        c:SetText(cmd)

        local d = helpPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        d:SetPoint("TOPLEFT", c, "BOTTOMLEFT", 0, -2)
        d:SetText(desc)
        d:SetTextColor(0.6, 0.6, 0.6, 1)

        return d
    end

    local lastHelp = helpTitle
    lastHelp = AddCommand("/at", "Open this options menu", lastHelp)
    lastHelp = AddCommand("/at test", "Toggle Test Mode frame", lastHelp)
    lastHelp = AddCommand("/at reset", "Reset all settings to default", lastHelp)

    -- Widget Constructors
    local function CreateCheckbox(label, key, parent, anchorTo)
        local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -10)
        cb.Text:SetText(label)

        local function Refresh()
            local val = ns.db[key]
            if val == nil then val = ns.defaults[key] end
            cb:SetChecked(val)
        end

        Refresh()                           -- Init value
        table.insert(refreshFuncs, Refresh) -- Register for resets

        cb:SetScript("OnClick", function(self)
            ns.db[key] = self:GetChecked()
            ns.UpdateAll()
        end)
        return cb
    end

    local function CreateSlider(label, key, parent, anchorTo, minVal, maxVal, step)
        local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -30)
        slider:SetWidth(200)
        slider:SetObeyStepOnDrag(true)
        slider:SetValueStep(step)
        slider:SetMinMaxValues(minVal, maxVal)

        if slider.Low then slider.Low:SetText(minVal) end
        if slider.High then slider.High:SetText(maxVal) end

        local function Refresh()
            local val = ns.db[key]
            if val == nil then val = ns.defaults[key] or minVal end

            -- SetValue triggers OnValueChanged, which handles text and db updates
            slider:SetValue(val)

            -- Force text update just in case
            if slider.Text then slider.Text:SetText(label .. ": " .. tostring(val)) end
        end

        Refresh()                           -- Init value
        table.insert(refreshFuncs, Refresh) -- Register for resets

        slider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value / step + 0.5) * step
            ns.db[key] = value
            if self.Text then self.Text:SetText(label .. ": " .. tostring(value)) end
            ns.UpdateAll()
        end)
        return slider
    end

    local function CreateDropdown(label, key, parent, anchorTo, options)
        local fontString = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fontString:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -20)
        fontString:SetText(label)

        local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
        dd:SetPoint("LEFT", fontString, "RIGHT", 10, -2)
        UIDropDownMenu_SetWidth(dd, 120)

        local function Init(self, level)
            local info = UIDropDownMenu_CreateInfo()
            for _, opt in ipairs(options) do
                info.text = opt
                info.func = function()
                    ns.db[key] = opt
                    UIDropDownMenu_SetSelectedValue(dd, opt)
                    UIDropDownMenu_SetText(dd, opt)
                    ns.UpdateAll()
                end
                info.checked = (ns.db[key] == opt)
                UIDropDownMenu_AddButton(info, level)
            end
        end

        UIDropDownMenu_Initialize(dd, Init)

        local function Refresh()
            local val = ns.db[key] or ns.defaults[key]
            UIDropDownMenu_SetSelectedValue(dd, val)
            UIDropDownMenu_SetText(dd, val)
        end

        Refresh()                           -- Init value
        table.insert(refreshFuncs, Refresh) -- Register for resets

        return fontString
    end

    -- UI Layout
    local lastWidget = title

    -- Test Toggle
    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetSize(140, 25)
    testBtn:SetPoint("TOPLEFT", lastWidget, "BOTTOMLEFT", 0, -20)

    local isTestOn = ns.testFrame and ns.testFrame:IsShown()
    testBtn:SetText(isTestOn and "Hide Test Frame" or "Show Test Frame")

    testBtn:SetScript("OnClick", function(self)
        local currentlyShown = ns.testFrame and ns.testFrame:IsShown()
        ns.ToggleTestMode(not currentlyShown)

        if not currentlyShown then
            self:SetText("Hide Test Frame")
        else
            self:SetText("Show Test Frame")
        end
    end)
    lastWidget = testBtn

    -- Visual settings
    lastWidget = CreateCheckbox("Show Arena ID#", "showIndex", panel, lastWidget)
    lastWidget = CreateSlider("Indicator Size", "size", panel, lastWidget, 5, 30, 1)
    lastWidget = CreateSlider("Spacing", "spacing", panel, lastWidget, 0, 10, 1)

    -- Positioning settings
    local anchors = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
    lastWidget = CreateDropdown("Anchor:", "anchor", panel, lastWidget, anchors)
    lastWidget = CreateDropdown("Relative To:", "relativePoint", panel, lastWidget, anchors)

    local directions = { "RIGHT", "LEFT", "UP", "DOWN" }
    lastWidget = CreateDropdown("Grow Direction:", "growDirection", panel, lastWidget, directions)

    -- Offset adjustments
    lastWidget = CreateSlider("X Offset", "x", panel, lastWidget, -50, 50, 1)
    lastWidget = CreateSlider("Y Offset", "y", panel, lastWidget, -50, 50, 1)

    -- Register Category
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        ns.categoryID = category:GetID()
    else
        InterfaceOptions_AddCategory(panel)
    end
end

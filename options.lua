local addonName, ns = ...
local Settings = Settings
local UnitClass = UnitClass
local C_ClassColor = C_ClassColor

-- Widget Constructor: Checkbox
local function CreateCheckbox(label, key, parent, anchorTo, refreshFuncs)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -10)
    cb.Text:SetText(label)

    local function Refresh()
        local val = ns.db[key]
        if val == nil then val = ns.defaults[key] end
        cb:SetChecked(val)
    end

    Refresh()
    table.insert(refreshFuncs, Refresh)

    cb:SetScript("OnClick", function(self)
        ns.db[key] = self:GetChecked()
        ns.UpdateAll()
    end)
    return cb
end

-- Widget Constructor: Slider
local function CreateSlider(label, key, parent, anchorTo, minVal, maxVal, step, refreshFuncs)
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
        slider:SetValue(val)
        if slider.Text then slider.Text:SetText(label .. ": " .. tostring(val)) end
    end

    Refresh()
    table.insert(refreshFuncs, Refresh)

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        ns.db[key] = value
        if self.Text then self.Text:SetText(label .. ": " .. tostring(value)) end
        ns.UpdateAll()
    end)
    return slider
end

-- Widget Constructor: Dropdown
local function CreateDropdown(label, key, parent, anchorTo, options, refreshFuncs)
    local fontString = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fontString:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -20)
    fontString:SetWidth(110)
    fontString:SetJustifyH("LEFT")
    fontString:SetText(label)

    local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("LEFT", fontString, "RIGHT", 0, -2)
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

    Refresh()
    table.insert(refreshFuncs, Refresh)

    return fontString
end

local function CreateButton(label, parent, anchorTo, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 25)
    btn:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -20)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    return btn
end

-- ---------------------------------------------------------
-- Preview Frame Configuration
-- ---------------------------------------------------------

local function UpdatePreviewState(f)
    -- Default dimensions fallback
    local width, height = 120, 60
    local scale = 1

    -- Attempt to fetch real dimensions from the live UI
    local realFrame = _G["CompactPartyFrameMember1"]

    if realFrame then
        width, height = realFrame:GetSize()

        -- Calculate scale relative to parent
        -- This logic must run in OnShow to get the correct parent effective scale
        local parent = f:GetParent()
        local parentScale = parent and parent:GetEffectiveScale() or 1
        if parentScale > 0 then
            scale = realFrame:GetEffectiveScale() / parentScale
        end
    end

    f:SetSize(width, height)
    f:SetScale(scale)

    local px = ns.GetPixelScale(f)
    local w = ns.SnapToScale(width, px)
    local h = ns.SnapToScale(height, px)

    f:SetSize(w, h)

    if f.bg then
        f.bg:SetPoint("CENTER", f, "CENTER", 0, 0)
        f.bg:SetSize(w - 2 * px, h - 2 * px)
    end
end

local function CreatePreviewFrame(parent)
    local f = CreateFrame("Frame", "ArenaTargetedPreview", parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", 400, -250)

    -- Initial placeholder size
    f:SetSize(120, 60)

    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    border:SetVertexColor(0, 0, 0, 1)

    f.bg = f:CreateTexture(nil, "BORDER")

    local _, class = UnitClass("player")
    local c = C_ClassColor.GetClassColor(class or "PRIEST")
    f.bg:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    f.bg:SetVertexColor(c.r, c.g, c.b, 1)

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("BOTTOM", f, "TOP", 0, 10)
    text:SetText("Preview")
    text:SetTextColor(1, 1, 1, 1)

    -- Initialize container and flag as preview
    f.ATPContainer = ns.CreateContainer(f)
    f.ATPContainer.isPreview = true

    -- We hook OnShow because parent scales are often invalid at creation time
    f:SetScript("OnShow", function(self)
        UpdatePreviewState(self)
        ns.UpdateAll()
    end)

    -- Also run once immediately to set initial state
    UpdatePreviewState(f)

    f:Show()
    ns.UpdateAll()
end

-- ---------------------------------------------------------
-- Main Options Setup
-- ---------------------------------------------------------

function ns.SetupOptions()
    local panel = CreateFrame("Frame")
    panel.name = addonName

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(addonName)

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    version:SetText("Version: " .. tostring(C_AddOns.GetAddOnMetadata(addonName, "Version") or "Unknown"))

    local author = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    author:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -4)
    author:SetText("Author: " .. tostring(C_AddOns.GetAddOnMetadata(addonName, "Author") or "Unknown"))

    local refreshFuncs = {}
    function ns.RefreshOptionUI()
        for _, func in ipairs(refreshFuncs) do func() end
    end

    -- Slash Command Help Panel
    local helpPanel = CreateFrame("Frame", nil, panel)
    helpPanel:SetSize(200, 100)
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
    lastHelp = AddCommand("/arenatargeted", "Alias for /at", lastHelp)
    lastHelp = AddCommand("/at reset", "Reset all settings", lastHelp)

    -- Options Panel Layout
    local lastWidget = author

    lastWidget = CreateCheckbox("Show Arena ID#", "showIndex", panel, lastWidget, refreshFuncs)

    -- Indicator Size
    lastWidget = CreateSlider("Size", "size", panel, lastWidget, 5, 30, 1, refreshFuncs)

    -- Spacing
    lastWidget = CreateSlider("Spacing", "spacing", panel, lastWidget, 0, 10, 1, refreshFuncs)

    -- Indicator Shape
    local shapes = {}
    for name, _ in pairs(ns.shapes) do
        table.insert(shapes, name)
    end
    table.sort(shapes)

    lastWidget = CreateDropdown("Shape:", "shape", panel, lastWidget, shapes, refreshFuncs)

    -- Anchors
    local anchors = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
    lastWidget = CreateDropdown("Anchor:", "anchor", panel, lastWidget, anchors, refreshFuncs)
    lastWidget = CreateDropdown("Relative To:", "relativePoint", panel, lastWidget, anchors, refreshFuncs)

    -- Grow Direction
    local directions = { "RIGHT", "LEFT", "UP", "DOWN" }
    lastWidget = CreateDropdown("Grow Direction:", "growDirection", panel, lastWidget, directions, refreshFuncs)

    -- X/Y Offsets
    lastWidget = CreateSlider("X Offset", "x", panel, lastWidget, -50, 50, 1, refreshFuncs)
    lastWidget = CreateSlider("Y Offset", "y", panel, lastWidget, -50, 50, 1, refreshFuncs)

    -- Reset Button
    lastWidget = CreateButton("Reset to Defaults", panel, lastWidget, 140, function()
        ns.ResetSettings()
    end)

    -- Embed Preview Frame
    CreatePreviewFrame(panel)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        ns.categoryID = category:GetID()
    else
        InterfaceOptions_AddCategory(panel)
    end
end

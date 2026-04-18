local addonName, ns = ...
local Settings = Settings
local UnitClass = UnitClass
local C_ClassColor = C_ClassColor

--[[ widget constructors ]]

local function CreateCheckbox(label, key, dbNode, parent, anchorTo, refreshFuncs)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -10)
    cb.Text:SetText(label)

    local function Refresh()
        cb:SetChecked(dbNode[key])
    end

    Refresh()
    table.insert(refreshFuncs, Refresh)

    cb:SetScript("OnClick", function(self)
        dbNode[key] = self:GetChecked()
        ns.Container.UpdateAll()
        ns.ForceUpdateTargetStates()
    end)
    return cb
end

local function CreateSlider(label, key, dbNode, parent, anchorTo, minVal, maxVal, step, refreshFuncs)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -30)
    slider:SetWidth(200)
    slider:SetObeyStepOnDrag(true)
    slider:SetValueStep(step)
    slider:SetMinMaxValues(minVal, maxVal)

    if slider.Low then slider.Low:SetText(minVal) end
    if slider.High then slider.High:SetText(maxVal) end

    local function Refresh()
        local val = dbNode[key]
        slider:SetValue(val)
        if slider.Text then slider.Text:SetText(label .. ": " .. tostring(val)) end
    end

    Refresh()
    table.insert(refreshFuncs, Refresh)

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        dbNode[key] = value
        if self.Text then self.Text:SetText(label .. ": " .. tostring(value)) end
        ns.Container.UpdateAll()
    end)
    return slider
end

local function CreateDropdown(label, key, dbNode, parent, anchorTo, options, refreshFuncs)
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
                dbNode[key] = opt
                UIDropDownMenu_SetSelectedValue(dd, opt)
                UIDropDownMenu_SetText(dd, opt)
                ns.Container.UpdateAll()
            end
            info.checked = (dbNode[key] == opt)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dd, Init)

    local function Refresh()
        local val = dbNode[key]
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
    if anchorTo then
        btn:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -20)
    end
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    return btn
end

--[[ preview frame configuration ]]

local function UpdatePreviewState(f, frameType)
    local width, height = 120, 60
    local scale = 1

    local realFrame
    if frameType == "arena" then
        realFrame = _G["CompactArenaFrameMember1"]
    else
        realFrame = _G["CompactPartyFrameMember1"]
    end

    if realFrame then
        local rW, rH = realFrame:GetSize()
        if rW and rW > 0 then width = rW end
        if rH and rH > 0 then height = rH end

        local parentScale = f:GetParent():GetEffectiveScale() or 1
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

    if f.ATContainer then
        f.ATContainer:UpdateLayout()
    end
end

local function CreatePreviewFrame(parent, frameType)
    local bounds = CreateFrame("Frame", nil, parent)
    bounds:SetPoint("TOPLEFT", parent, "TOPLEFT", 300, -50)
    bounds:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 16)
    bounds:SetClipsChildren(true)

    local titleText = bounds:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", bounds, "TOP", 0, -10)
    titleText:SetText("Preview")
    titleText:SetTextColor(1, 1, 1, 1)

    local f = CreateFrame("Frame", nil, bounds)
    f:SetPoint("CENTER", bounds, "CENTER", 0, 0)
    f:SetSize(120, 60)

    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetTexture(ns.CONSTANTS.TEXTURE_WHITE)
    border:SetVertexColor(0, 0, 0, 1)

    f.bg = f:CreateTexture(nil, "BORDER")

    local _, class = UnitClass("player")
    local c = C_ClassColor.GetClassColor(class or "PRIEST")
    f.bg:SetTexture(ns.CONSTANTS.TEXTURE_WHITE)
    f.bg:SetVertexColor(c.r, c.g, c.b, 1)

    f.ATContainer = ns.Container.Create(f, frameType)
    f.ATContainer.isPreview = true

    parent:HookScript("OnSizeChanged", function()
        UpdatePreviewState(f, frameType)
    end)

    parent:HookScript("OnShow", function()
        UpdatePreviewState(f, frameType)
    end)

    UpdatePreviewState(f, frameType)
    f:Show()
    return f
end

--[[ main options setup ]]

local function BuildPage(pageFrame, dbNode, frameType, refreshFuncs)
    local shapes = {}
    for name, _ in pairs(ns.shapes) do table.insert(shapes, name) end
    table.sort(shapes)

    local anchors = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
    local directions = { "RIGHT", "LEFT", "UP", "DOWN" }

    local title = pageFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(pageFrame.name)

    local anchorWidget = title

    if frameType == "arena" then
        anchorWidget = CreateCheckbox("Show Player Indicator", "showPlayer", dbNode, pageFrame, anchorWidget, refreshFuncs)
    end

    anchorWidget = CreateCheckbox("Show Index#", "showIndex", dbNode, pageFrame, anchorWidget, refreshFuncs)
    anchorWidget = CreateSlider("Size", "size", dbNode, pageFrame, anchorWidget, 5, 30, 1, refreshFuncs)
    anchorWidget = CreateSlider("Border Thickness", "borderSize", dbNode, pageFrame, anchorWidget, 1, 5, 1, refreshFuncs)
    anchorWidget = CreateSlider("Spacing", "spacing", dbNode, pageFrame, anchorWidget, 0, 10, 1, refreshFuncs)
    anchorWidget = CreateDropdown("Shape:", "shape", dbNode, pageFrame, anchorWidget, shapes, refreshFuncs)
    anchorWidget = CreateDropdown("Anchor:", "anchor", dbNode, pageFrame, anchorWidget, anchors, refreshFuncs)
    anchorWidget = CreateDropdown("Relative To:", "relativePoint", dbNode, pageFrame, anchorWidget, anchors, refreshFuncs)
    anchorWidget = CreateDropdown("Grow Direction:", "growDirection", dbNode, pageFrame, anchorWidget, directions, refreshFuncs)
    anchorWidget = CreateSlider("X Offset", "x", dbNode, pageFrame, anchorWidget, -50, 50, 1, refreshFuncs)
    anchorWidget = CreateSlider("Y Offset", "y", dbNode, pageFrame, anchorWidget, -50, 50, 1, refreshFuncs)

    CreatePreviewFrame(pageFrame, frameType)

    return anchorWidget
end

function ns.SetupOptions()
    local refreshFuncs = {}
    function ns.RefreshOptionUI()
        for _, func in ipairs(refreshFuncs) do func() end
    end

    local mainPanel = CreateFrame("Frame")
    mainPanel.name = addonName

    local mainTitle = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    mainTitle:SetPoint("TOPLEFT", 16, -16)
    mainTitle:SetText(addonName)

    local version = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("TOPLEFT", mainTitle, "BOTTOMLEFT", 0, -8)
    version:SetText("Version: " .. tostring(C_AddOns.GetAddOnMetadata(addonName, "Version") or "Unknown"))

    local author = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    author:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -4)
    author:SetText("Author: " .. tostring(C_AddOns.GetAddOnMetadata(addonName, "Author") or "Unknown"))

    local helpPanel = CreateFrame("Frame", nil, mainPanel)
    helpPanel:SetSize(200, 100)
    helpPanel:SetPoint("TOPRIGHT", mainPanel, "TOPRIGHT", -20, -20)

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

    CreateButton("Reset to Defaults", mainPanel, author, 140, function()
        ns.ResetSettings()
    end)

    local partyPanel = CreateFrame("Frame")
    partyPanel.name = "Party Frames"
    partyPanel.parent = mainPanel.name
    BuildPage(partyPanel, ns.db.party, "party", refreshFuncs)

    local arenaPanel = CreateFrame("Frame")
    arenaPanel.name = "Arena Frames"
    arenaPanel.parent = mainPanel.name
    BuildPage(arenaPanel, ns.db.arena, "arena", refreshFuncs)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local mainCategory = Settings.RegisterCanvasLayoutCategory(mainPanel, mainPanel.name)
        Settings.RegisterAddOnCategory(mainCategory)
        ns.categoryID = mainCategory:GetID()

        local partyCategory = Settings.RegisterCanvasLayoutSubcategory(mainCategory, partyPanel, partyPanel.name)
        Settings.RegisterAddOnCategory(partyCategory)

        local arenaCategory = Settings.RegisterCanvasLayoutSubcategory(mainCategory, arenaPanel, arenaPanel.name)
        Settings.RegisterAddOnCategory(arenaCategory)
    else
        InterfaceOptions_AddCategory(mainPanel)
        InterfaceOptions_AddCategory(partyPanel)
        InterfaceOptions_AddCategory(arenaPanel)
    end
end

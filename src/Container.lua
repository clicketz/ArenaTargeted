local _, ns = ...

--[[ static container class ]]

ns.Container = {}
ns.Container.instances = {}

-- factory
function ns.Container.Create(parent, frameType)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(1, 1)
    container.frameType = frameType

    Mixin(container, ns.ContainerMixin)
    container:Init()

    table.insert(ns.Container.instances, container)
    return container
end

-- managers
function ns.Container.UpdateAll()
    for _, container in ipairs(ns.Container.instances) do
        container:UpdateLayout()
    end
end

function ns.Container.ResetAll()
    for _, container in ipairs(ns.Container.instances) do
        container:ResetIndicators()
    end
end

--[[ container mixin ]]

ns.ContainerMixin = {}

function ns.ContainerMixin:Init()
    self.indicators = {}

    local maxIndicators = self.frameType == "arena" and ns.CONSTANTS.MAX_PARTY_MEMBERS or ns.CONSTANTS.MAX_ARENA_ENEMIES

    for i = 1, maxIndicators do
        local indicator = CreateFrame("Frame", nil, self)
        indicator:SetFrameLevel(self:GetParent():GetFrameLevel() + 10)
        indicator:EnableMouse(false)

        Mixin(indicator, ns.IndicatorMixin)
        indicator:Init()
        indicator:SetIndex(i)

        self.indicators[i] = indicator
    end

    local parent = self:GetParent()
    parent:HookScript("OnSizeChanged", function()
        self:UpdateLayout()
    end)

    self:Show()
    self:UpdateLayout()
end

function ns.ContainerMixin:UpdateLayout()
    local db = ns.db[self.frameType]

    if db.enabled == false and not self.isPreview and not ns.testMode then
        self:Hide()
        return
    else
        self:Show()
    end

    local px = ns.GetPixelScale(self)
    local parent = self:GetParent()

    local shapeDef = ns.shapes[db.shape] or ns.shapes["Box"]

    self:ClearAllPoints()
    PixelUtil.SetPoint(self, db.anchor, parent, db.relativePoint, db.x, db.y)

    local spacing = ns.SnapToScale(db.spacing, px)

    local layoutOrder = {}
    if self.frameType == "arena" then
        for i = 2, ns.CONSTANTS.MAX_PARTY_MEMBERS do
            local isSimulated = (self.isPreview and (i <= ns.CONSTANTS.MAX_PARTY_MEMBERS)) or ns.testMode
            if isSimulated or UnitExists("party" .. (i - 1)) then
                table.insert(layoutOrder, i)
            end
        end
        if db.showPlayer ~= false then
            table.insert(layoutOrder, 1) -- Player anchored at the end
        end
    else
        for i = 1, ns.CONSTANTS.MAX_ARENA_ENEMIES do
            local isSimulated = (self.isPreview and (i <= ns.CONSTANTS.MAX_ARENA_ENEMIES)) or ns.testMode
            if isSimulated or UnitExists("arena" .. i) then
                table.insert(layoutOrder, i)
            end
        end
    end

    for _, indicator in ipairs(self.indicators) do
        indicator:Hide()
        indicator:ClearAllPoints()
    end

    local prev = nil

    for _, i in ipairs(layoutOrder) do
        local indicator = self.indicators[i]

        indicator:Setup(shapeDef, parent, px)
        indicator:UpdateIndexDisplay()

        local isPlayerHighlight = (self.frameType == "arena" and i == 1 and db.highlightPlayer)

        -- TODO: custom player highlight color?
        if isPlayerHighlight then
            indicator:SetBorderColor(1, 0.82, 0, 1) -- golden/yellow
        else
            indicator:SetBorderColor(0, 0, 0, 1)    -- black
        end

        if not prev then
            indicator:SetPoint(db.anchor, self, db.anchor, 0, 0)
        else
            if db.growDirection == "RIGHT" then
                indicator:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
            elseif db.growDirection == "LEFT" then
                indicator:SetPoint("RIGHT", prev, "LEFT", -spacing, 0)
            elseif db.growDirection == "UP" then
                indicator:SetPoint("BOTTOM", prev, "TOP", 0, spacing)
            elseif db.growDirection == "DOWN" then
                indicator:SetPoint("TOP", prev, "BOTTOM", 0, -spacing)
            end
        end

        prev = indicator

        if self.isPreview or ns.testMode then
            local c = ns.PREVIEW_COLORS[i] or ns.PREVIEW_COLORS[1]
            if c then
                indicator:Show()
                indicator:SetColor(c.r, c.g, c.b)
                indicator:SetVisible(true)
            end
        end
    end
end

function ns.ContainerMixin:ResetIndicators()
    if self.isPreview then return end

    for _, indicator in ipairs(self.indicators) do
        indicator:Hide()
    end
end

function ns.ContainerMixin:UpdateEnemyState(sourceIndex, r, g, b, isMatch)
    if self.isPreview then return end

    local indicator = self.indicators[sourceIndex]
    if indicator then
        if r then
            indicator:SetColor(r, g, b)
            indicator:SetVisible(isMatch)
        else
            indicator:Hide()
        end
    end
end

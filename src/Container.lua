local _, ns = ...

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

ns.ContainerMixin = {}

function ns.ContainerMixin:Init()
    self.indicators = {}
    self.targetStates = {}

    local maxIndicators = self.frameType == "arena" and ns.CONSTANTS.MAX_PARTY_MEMBERS or ns.CONSTANTS.MAX_ARENA_ENEMIES

    for i = 1, maxIndicators do
        local indicator = CreateFrame("Frame", nil, self)
        indicator:SetFrameLevel(self:GetParent():GetFrameLevel() + 10)
        indicator:EnableMouse(false)

        Mixin(indicator, ns.IndicatorMixin)
        indicator:Init()

        self.indicators[i] = indicator
    end

    local parent = self:GetParent()
    parent:HookScript("OnSizeChanged", function()
        self:UpdateLayout()
    end)

    self:Show()
    self:UpdateLayout()
end

function ns.ContainerMixin:GetLayoutOrder(db)
    local layoutOrder = {}
    if self.frameType == "arena" then
        for i = 2, ns.CONSTANTS.MAX_PARTY_MEMBERS do
            table.insert(layoutOrder, i)
        end
        if db.showPlayer then
            table.insert(layoutOrder, 1)
        end
    else
        for i = 1, ns.CONSTANTS.MAX_ARENA_ENEMIES do
            table.insert(layoutOrder, i)
        end
    end
    return layoutOrder
end

function ns.ContainerMixin:RenderIndicators()
    local db = ns.db[self.frameType]
    local isSimulated = self.isPreview or ns.testMode
    local layoutOrder = self:GetLayoutOrder(db)

    local activeMatches = {}

    for _, sourceIndex in ipairs(layoutOrder) do
        if isSimulated then
            local c = ns.PREVIEW_COLORS[sourceIndex] or ns.PREVIEW_COLORS
            table.insert(activeMatches, { sourceIndex = sourceIndex, r = c.r, g = c.g, b = c.b })
        else
            local state = self.targetStates[sourceIndex]
            if state then
                table.insert(activeMatches, { sourceIndex = sourceIndex, r = state.r, g = state.g, b = state.b })
            end
        end
    end

    for i, indicator in ipairs(self.indicators) do
        local match = activeMatches[i]
        if match then
            indicator:SetIndex(match.sourceIndex)
            indicator:UpdateIndexDisplay()

            if self.frameType == "arena" and match.sourceIndex == 1 and db.highlightPlayer then
                indicator:SetBorderColor(1, 0.82, 0, 1)
            else
                indicator:SetBorderColor(0, 0, 0, 1)
            end

            indicator:SetColor(match.r, match.g, match.b)
            indicator:Show()
        else
            indicator:Hide()
        end
    end
end

function ns.ContainerMixin:UpdateLayout()
    local db = ns.db[self.frameType]

    if not db.enabled and not self.isPreview and not ns.testMode then
        self:Hide()
        return
    else
        self:Show()
    end

    local px = ns.GetPixelScale(self)
    local parent = self:GetParent()
    local shapeDef = ns.shapes[db.shape] or ns.shapes["Box"]
    local spacing = ns.SnapToScale(db.spacing, px)

    self:ClearAllPoints()
    PixelUtil.SetPoint(self, db.anchor, parent, db.relativePoint, db.x, db.y)

    local prev = nil
    for _, indicator in ipairs(self.indicators) do
        indicator:ClearAllPoints()
        indicator:Setup(shapeDef, parent, px)

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
    end

    self:RenderIndicators()
end

function ns.ContainerMixin:ResetIndicators()
    if self.isPreview then return end

    wipe(self.targetStates)

    for _, indicator in ipairs(self.indicators) do
        indicator:Hide()
    end
end

function ns.ContainerMixin:UpdateEnemyState(sourceIndex, r, g, b, isMatch)
    if self.isPreview then return end

    if r and isMatch then
        self.targetStates[sourceIndex] = { r = r, g = g, b = b }
    else
        self.targetStates[sourceIndex] = nil
    end

    self:RenderIndicators()
end

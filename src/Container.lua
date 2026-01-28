local _, ns = ...

local ipairs = ipairs
local table = table
local PixelUtil = PixelUtil

--[[ static container class ]]

ns.Container = {}
ns.Container.instances = {}

-- factory
function ns.Container.Create(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(1, 1)

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

    for i = 1, ns.CONSTANTS.MAX_ARENA_ENEMIES do
        local indicator = CreateFrame("Frame", nil, self)
        indicator:SetFrameLevel(self:GetParent():GetFrameLevel() + 10)
        indicator:EnableMouse(false)

        Mixin(indicator, ns.IndicatorMixin)
        indicator:Init()

        self.indicators[i] = indicator
    end

    local parent = self:GetParent()
    if parent.HookScript then
        parent:HookScript("OnSizeChanged", function()
            self:UpdateLayout()
        end)
    end

    self:Show()
    self:UpdateLayout()
end

function ns.ContainerMixin:UpdateLayout()
    local db = ns.db or ns.defaults
    local px = ns.GetPixelScale(self)
    local parent = self:GetParent()

    local shapeName = db.shape or ns.defaults.shape
    local shapeDef = ns.shapes[shapeName] or ns.shapes["Box"]

    self:ClearAllPoints()
    local anchor = db.anchor or ns.defaults.anchor
    local relPoint = db.relativePoint or ns.defaults.relativePoint
    local x = db.x or ns.defaults.x
    local y = db.y or ns.defaults.y
    PixelUtil.SetPoint(self, anchor, parent, relPoint, x, y)

    local grow = db.growDirection or ns.defaults.growDirection
    local spacing = ns.SnapToScale(db.spacing or ns.defaults.spacing, px)

    for i, indicator in ipairs(self.indicators) do
        indicator:Setup(shapeDef, db, parent, px)

        if db.showIndex then
            indicator.text:Show()
            indicator.text:SetText(i)
            local fName, _, fFlags = indicator.text:GetFont()
            indicator.text:SetFont(fName, db.fontSize or ns.defaults.fontSize, fFlags)
        else
            indicator.text:Hide()
        end

        indicator:ClearAllPoints()
        if i == 1 then
            indicator:SetPoint(anchor, self, anchor, 0, 0)
        else
            local prev = self.indicators[i - 1]
            if grow == "RIGHT" then
                indicator:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
            elseif grow == "LEFT" then
                indicator:SetPoint("RIGHT", prev, "LEFT", -spacing, 0)
            elseif grow == "UP" then
                indicator:SetPoint("BOTTOM", prev, "TOP", 0, spacing)
            elseif grow == "DOWN" then
                indicator:SetPoint("TOP", prev, "BOTTOM", 0, -spacing)
            end
        end

        if self.isPreview then
            local c = ns.PREVIEW_COLORS[i]
            if c and i <= 3 then
                indicator:Show()
                indicator:SetColor(c.r, c.g, c.b)
                indicator:SetMatch(true)
            else
                indicator:Hide()
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

function ns.ContainerMixin:UpdateEnemyState(arenaIndex, r, g, b, isMatch)
    if self.isPreview then return end

    local indicator = self.indicators[arenaIndex]
    if indicator then
        if r then
            indicator:SetColor(r, g, b)
            indicator:SetMatch(isMatch)
        else
            indicator:Hide()
        end
    end
end

local _, ns = ...

local floor = math.floor

--[[ indicator mixin ]]

ns.IndicatorMixin = {}

function ns.IndicatorMixin:Init()
    -- border
    self.border = self:CreateTexture(nil, "BACKGROUND")
    self.border:SetBlendMode("BLEND")
    self.border:SetVertexColor(0, 0, 0, 1)

    -- inner (colored frame)
    self.inner = self:CreateTexture(nil, "ARTWORK")
    self.inner:SetBlendMode("BLEND")
    self.inner:SetVertexColor(1, 1, 1, 1)

    -- text (debug/index)
    self.text = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.text:SetPoint("CENTER", self, "CENTER", 0, 0)

    self.maskBg = nil
    self.maskFg = nil

    self:Hide()
end

function ns.IndicatorMixin:SetColor(r, g, b)
    self.inner:SetVertexColor(r, g, b, 1)
end

-- controls visibility based on targeting status
-- NOTE: isMatch is a secret value returned from UnitisUnit
function ns.IndicatorMixin:SetMatch(isMatch)
    -- always show the frame, but let the secure api handle the alpha
    -- to bypass secret issues
    self:Show()
    self:SetAlphaFromBoolean(isMatch)
end

function ns.IndicatorMixin:ResetTextureState()
    if self.maskBg then self.maskBg:Hide() end
    if self.maskFg then self.maskFg:Hide() end

    self.border:RemoveMaskTexture(self.maskBg)
    self.inner:RemoveMaskTexture(self.maskFg)

    self.border:SetTexture(ns.CONSTANTS.TEXTURE_WHITE)
    self.border:SetTexCoord(0, 1, 0, 1)

    self.inner:SetTexture(ns.CONSTANTS.TEXTURE_WHITE)
    self.inner:SetTexCoord(0, 1, 0, 1)
end

function ns.IndicatorMixin:ApplyCommonGeometry(width, height, px, borderSize)
    local inset = borderSize * px
    local innerW = math.max(0, width - (2 * inset))
    local innerH = math.max(0, height - (2 * inset))

    self.border:ClearAllPoints()
    self.border:SetAllPoints()
    self.border:Show()

    self.inner:ClearAllPoints()
    self.inner:SetPoint("CENTER", self, "CENTER", 0, 0)
    self.inner:SetSize(innerW, innerH)

    return innerW, innerH
end

function ns.IndicatorMixin:ApplyBasicShape(width, height, px, borderSize)
    self:ResetTextureState()
    self:ApplyCommonGeometry(width, height, px, borderSize)
end

function ns.IndicatorMixin:ApplyIconShape(index, width, height, px, borderSize)
    if not self.maskBg then self.maskBg = self:CreateMaskTexture() end
    if not self.maskFg then self.maskFg = self:CreateMaskTexture() end

    self:ResetTextureState()
    self.maskBg:Show()
    self.maskFg:Show()

    local innerW, innerH = self:ApplyCommonGeometry(width, height, px, borderSize)

    -- raid icons are in a 4x4 grid
    local col = (index - 1) % 4
    local row = floor((index - 1) / 4)
    local texture = ns.CONSTANTS.TEXTURE_RAID_ICONS

    -- shift mask to reveal correct icon
    self.maskBg:SetTexture(texture, "CLAMP", "CLAMP")
    self.maskBg:SetSize(width * 4, height * 4)
    self.maskBg:ClearAllPoints()
    self.maskBg:SetPoint("TOPLEFT", self, "TOPLEFT", -1 * (col * width), (row * height))

    self.maskFg:SetTexture(texture, "CLAMP", "CLAMP")
    self.maskFg:SetSize(innerW * 4, innerH * 4)
    self.maskFg:ClearAllPoints()
    self.maskFg:SetPoint("TOPLEFT", self.inner, "TOPLEFT", -1 * (col * innerW), (row * innerH))

    self.border:AddMaskTexture(self.maskBg)
    self.inner:AddMaskTexture(self.maskFg)
end

function ns.IndicatorMixin:Setup(shapeDef, db, parent, px)
    local width, height

    if shapeDef.type == "line" then
        width = ns.SnapToScale(parent:GetWidth(), px)
        local rawSize = db.size or ns.defaults.size
        local rawH = math.max(1, rawSize * shapeDef.heightFactor)
        height = ns.SnapToScale(rawH, px)
    else
        local s = ns.SnapToScale(db.size or ns.defaults.size, px)
        width, height = s, s
    end

    self:SetSize(width, height)

    local borderSize = db.borderSize or ns.defaults.borderSize

    if shapeDef.type == "icon" then
        self:ApplyIconShape(shapeDef.index, width, height, px, borderSize)
    else
        self:ApplyBasicShape(width, height, px, borderSize)
    end
end

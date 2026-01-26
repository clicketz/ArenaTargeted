local _, ns = ...

local UnitExists = UnitExists
local UnitClass = UnitClass
local C_ClassColor = C_ClassColor
local GetPhysicalScreenSize = GetPhysicalScreenSize
local select = select
local floor = math.floor

-- Calculates the size of 1 physical pixel relative to the given frame's Effective Scale.
-- @param frame The UI frame to measure against.
-- @return number The size of 1 physical pixel in logical UI units.
function ns.GetPixelScale(frame)
    local screenHeight = select(2, GetPhysicalScreenSize())
    local scale = frame:GetEffectiveScale()

    -- Safety check for 0 scale (can happen during loading/hidden frames)
    if not scale or scale == 0 then scale = 1 end

    return (768.0 / screenHeight) / scale
end

-- Snaps a value to the nearest physical pixel.
-- @param val The logical value to snap (e.g., width, height, offset).
-- @param px The pixel scale (returned from GetPixelScale).
-- @return number The snapped value.
function ns.SnapToScale(val, px)
    return floor(val / px + 0.5) * px
end

-- Returns unit class color as RGBA components.
-- @param unit The unitID to check (e.g., "arena1", "party1").
-- @return r, g, b, a (or nil if unit/class not found).
function ns.GetUnitColor(unit)
    if UnitExists(unit) then
        local _, classFilename = UnitClass(unit)
        if classFilename then
            local color = C_ClassColor.GetClassColor(classFilename)
            if color then
                return color.r, color.g, color.b, 1
            end
        end
    end
    return nil
end

-- Helper to reset texture state (File, Desaturation, Default Color)
-- @param indicator The indicator frame
-- @param texture The texture file path
-- @param desaturate Boolean to desaturate the texture
-- @param coords Optional texture coordinates {L, R, T, B}
function ns.SetupTextureState(indicator, texture, desaturate, coords)
    -- remove all potential masks from previous states
    local function ClearMask(mask)
        if mask then
            indicator.border:RemoveMaskTexture(mask)
            indicator.inner:RemoveMaskTexture(mask)
            mask:Hide()
        end
    end
    ClearMask(indicator.mask)
    ClearMask(indicator.maskBg)
    ClearMask(indicator.maskFg)

    indicator.border:SetAlpha(1)
    indicator.inner:SetAlpha(1)

    indicator.border:SetTexture(texture)
    indicator.border:SetDesaturated(desaturate)
    indicator.border:SetBlendMode("BLEND")
    indicator.border:SetVertexColor(0, 0, 0, 1) -- Always black border

    indicator.inner:SetTexture(texture)
    indicator.inner:SetDesaturated(desaturate)
    indicator.inner:SetBlendMode("BLEND")
    indicator.inner:SetVertexColor(1, 1, 1, 1) -- Always white inner (tinted later)

    if not coords then
        indicator.border:SetTexCoord(0, 1, 0, 1)
        indicator.inner:SetTexCoord(0, 1, 0, 1)
    else
        local L, R, T, B = coords[1], coords[2], coords[3], coords[4]
        indicator.border:SetTexCoord(L, R, T, B)
        indicator.inner:SetTexCoord(L, R, T, B)
    end
end

-- shifted mask with dual layers (border + inner)
-- @param indicator The indicator frame to adjust.
-- @param maskTexture The texture file containing the raid icons.
-- @param iconIndex The index of the raid icon (1-8).
-- @param width The total width of the indicator.
-- @param height The total height of the indicator.
-- @param px The pixel scale (returned from GetPixelScale).
-- @param borderSize The border size in physical pixels.
function ns.SetupShiftedMask(indicator, maskTexture, iconIndex, width, height, px, borderSize)
    if not indicator.maskBg then indicator.maskBg = indicator:CreateMaskTexture() end
    if not indicator.maskFg then indicator.maskFg = indicator:CreateMaskTexture() end

    indicator.border:SetAlpha(1)
    indicator.inner:SetAlpha(1)

    -- detach masks to allow updates
    indicator.border:RemoveMaskTexture(indicator.maskBg)
    indicator.inner:RemoveMaskTexture(indicator.maskFg)
    indicator.maskBg:Show()
    indicator.maskFg:Show()

    -- calculate grid position
    local col = (iconIndex - 1) % 4
    local row = floor((iconIndex - 1) / 4)

    -- bg mask (border)
    local bgW, bgH = width, height
    indicator.maskBg:SetTexture(maskTexture, "CLAMP", "CLAMP")
    indicator.maskBg:SetSize(bgW * 4, bgH * 4)

    local bgOffX = -1 * (col * bgW)
    local bgOffY = (row * bgH)
    indicator.maskBg:ClearAllPoints()
    indicator.maskBg:SetPoint("TOPLEFT", indicator, "TOPLEFT", bgOffX, bgOffY)

    -- fg mask (inner)
    local bSize = borderSize or 1
    local inset = bSize * px
    local fgW = width - (2 * inset)
    local fgH = height - (2 * inset)
    if fgW < 0 then fgW = 0 end
    if fgH < 0 then fgH = 0 end

    indicator.maskFg:SetTexture(maskTexture, "CLAMP", "CLAMP")
    indicator.maskFg:SetSize(fgW * 4, fgH * 4)

    local fgOffX = -1 * (col * fgW)
    local fgOffY = (row * fgH)
    -- Anchor to 'inner' because 'inner' is already positioned/inset correctly
    indicator.maskFg:ClearAllPoints()
    indicator.maskFg:SetPoint("TOPLEFT", indicator.inner, "TOPLEFT", fgOffX, fgOffY)

    -- actual border
    indicator.border:SetTexture(ns.CONSTANTS.TEXTURE_WHITE)
    indicator.border:SetTexCoord(0, 1, 0, 1)
    indicator.border:SetDesaturated(false)
    indicator.border:SetBlendMode("BLEND")
    indicator.border:SetVertexColor(0, 0, 0, 1)

    -- actual "inner" (class colored frame)
    indicator.inner:SetTexture(ns.CONSTANTS.TEXTURE_WHITE)
    indicator.inner:SetTexCoord(0, 1, 0, 1)
    indicator.inner:SetDesaturated(false)
    indicator.inner:SetBlendMode("BLEND")
    indicator.inner:SetVertexColor(1, 1, 1, 1)

    -- apply our masks
    indicator.border:AddMaskTexture(indicator.maskBg)
    indicator.inner:AddMaskTexture(indicator.maskFg)
end

-- Generic helper that centers the inner texture inside the border
-- with a specific pixel inset. Works for any shape that is centered in its file.
-- @param indicator The indicator frame to adjust.
-- @param width The total width of the indicator.
-- @param height The total height of the indicator.
-- @param px The pixel scale (returned from GetPixelScale).
-- @param borderSize The border size in physical pixels.
function ns.SetupCenteredInset(indicator, width, height, px, borderSize)
    -- Default to 1 if nil
    local bSize = borderSize or 1

    -- Calculate the inset thickness (Physical Pixels * Border Size)
    local inset = bSize * px

    -- Inner size is Total - (Inset on Left + Inset on Right)
    local innerW = width - (2 * inset)
    local innerH = height - (2 * inset)

    if innerW < 0 then innerW = 0 end
    if innerH < 0 then innerH = 0 end

    -- Ensure the border texture fills the frame
    indicator.border:ClearAllPoints()
    indicator.border:SetAllPoints()
    indicator.border:Show()

    indicator.inner:ClearAllPoints()
    indicator.inner:SetPoint("CENTER", indicator, "CENTER", 0, 0)
    indicator.inner:SetSize(innerW, innerH)
end

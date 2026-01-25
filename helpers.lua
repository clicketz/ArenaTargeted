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
function ns.SetupTextureState(indicator, texture, desaturate)
    indicator.border:SetTexture(texture)
    indicator.border:SetDesaturated(desaturate)
    indicator.border:SetVertexColor(0, 0, 0, 1) -- Always black border

    indicator.inner:SetTexture(texture)
    indicator.inner:SetDesaturated(desaturate)
    indicator.inner:SetVertexColor(1, 1, 1, 1) -- Always white inner (tinted later)
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

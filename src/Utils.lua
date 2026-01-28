local _, ns = ...

local select = select
local floor = math.floor
local GetPhysicalScreenSize = GetPhysicalScreenSize
local UnitExists = UnitExists
local UnitClass = UnitClass
local C_ClassColor = C_ClassColor

-- calculates size of 1 physical pixel relative to frame scale
function ns.GetPixelScale(frame)
    local screenHeight = select(2, GetPhysicalScreenSize())
    local scale = frame:GetEffectiveScale()

    if not scale or scale == 0 then scale = 1 end

    return (768.0 / screenHeight) / scale
end

-- snaps value to nearest physical pixel
function ns.SnapToScale(val, px)
    return floor(val / px + 0.5) * px
end

-- returns unit class color components
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

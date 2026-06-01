local _, ns = ...

-- calculates size of 1 physical pixel relative to frame scale
function ns.GetPixelScale(frame)
    local screenHeight = select(2, GetPhysicalScreenSize())
    local scale = frame:GetEffectiveScale()

    if not scale or scale == 0 then scale = 1 end

    return (768.0 / screenHeight) / scale
end

-- snaps value to nearest physical pixel
function ns.SnapToScale(val, px)
    return math.floor(val / px + 0.5) * px
end

-- returns unit class color components
function ns.GetUnitColor(unit)
    if UnitExists(unit) then
        local classFilename = UnitClassBase(unit)
        if classFilename then
            local color = C_ClassColor.GetClassColor(classFilename)
            if color then
                return color.r, color.g, color.b, 1
            end
        end
    end
    return nil
end

function ns.IsMatch(unit1, unit2)
    if not UnitExists(unit1) or not UnitExists(unit2) then return false end

    local class1 = UnitClassBase(unit1)
    local class2 = UnitClassBase(unit2)
    if not class1 or class1 ~= class2 then return false end

    return UnitHonorLevel(unit1) == UnitHonorLevel(unit2)
end

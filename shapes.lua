local _, ns = ...

-- --------------------------------------------------------------------------
-- Shape Registry
-- --------------------------------------------------------------------------
-- Each shape must define:
--   GetSize(db, parent, px): Returns width, height
--   Setup(indicator, width, height, px): Applies texture/border positioning
-- ---------------------------------------------------------------------------

local function CreateRaidIconShape(index)
    return {
        GetSize = function(db, parent, px)
            local s = ns.SnapToScale(db.size or ns.defaults.size, px)
            return s, s
        end,
        Setup = function(indicator, width, height, px, borderSize)
            -- pass borderSize so the inner texture is physically smaller
            ns.SetupCenteredInset(indicator, width, height, px, borderSize)

            -- pass borderSize so the inner mask is scaled down to match
            ns.SetupShiftedMask(indicator, ns.CONSTANTS.TEXTURE_RAID_ICONS, index, width, height, px, borderSize)
        end
    }
end

ns.shapes = {
    ["Box"] = {
        -- Box uses the 'size' slider for both Width and Height
        GetSize = function(db, parent, px)
            local s = ns.SnapToScale(db.size or ns.defaults.size, px)
            return s, s
        end,

        -- Square has a black border and inset color
        Setup = function(indicator, width, height, px, borderSize)
            ns.SetupTextureState(indicator, ns.CONSTANTS.TEXTURE_WHITE, false, nil)
            ns.SetupCenteredInset(indicator, width, height, px, borderSize)
        end
    },

    ["Line"] = {
        -- Line ignores 'size' for width (matches parent)
        -- Height is derived from 'size' divided by 4 (e.g., Size 12 = 3px height)
        GetSize = function(db, parent, px)
            local w = ns.SnapToScale(parent:GetWidth(), px)

            -- Calculate height scalar
            local rawSize = db.size or ns.defaults.size
            local rawHeight = rawSize / 4

            -- Ensure line is at least 1 logical pixel thick so it doesn't vanish
            if rawHeight < 1 then rawHeight = 1 end
            local h = ns.SnapToScale(rawHeight, px)
            return w, h
        end,
        Setup = function(indicator, width, height, px, borderSize)
            ns.SetupTextureState(indicator, ns.CONSTANTS.TEXTURE_WHITE, false, nil)
            ns.SetupCenteredInset(indicator, width, height, px, borderSize)
        end
    }
}

-- Create all raid icon shapes
for name, index in pairs(ns.CONSTANTS.RAID_ICON_INDICES) do
    ns.shapes[name] = CreateRaidIconShape(index)
end

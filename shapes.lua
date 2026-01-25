local _, ns = ...

-- ---------------------------------------------------------
-- Shape Logic Helpers
-- ---------------------------------------------------------

local function SetupIndicatorTexture(indicator, texture, desaturate)
    indicator.border:SetTexture(texture)
    indicator.border:SetDesaturated(desaturate)
    indicator.border:SetVertexColor(0, 0, 0, 1)

    indicator.inner:SetTexture(texture)
    indicator.inner:SetDesaturated(desaturate)
    indicator.inner:SetVertexColor(1, 1, 1, 1)
end

-- --------------------------------------------------------------------------
-- Shape Registry
-- --------------------------------------------------------------------------
-- Each shape must define:
--   GetSize(db, parent, px): Returns width, height
--   Setup(indicator, width, height, px): Applies texture/border positioning
-- ---------------------------------------------------------------------------

ns.shapes = {
    ["Square"] = {
        -- Square uses the 'size' slider for both Width and Height
        GetSize = function(db, parent, px)
            local s = ns.SnapToScale(db.size or ns.defaults.size, px)
            return s, s
        end,
        -- Square has a black border and inset color
        Setup = function(indicator, width, height, px)
            SetupIndicatorTexture(indicator, ns.CONSTANTS.TEXTURE_WHITE, true)
            ns.SetupCenteredInset(indicator, width, height, px)
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
        Setup = function(indicator, width, height, px)
            SetupIndicatorTexture(indicator, ns.CONSTANTS.TEXTURE_WHITE, true)
            ns.SetupCenteredInset(indicator, width, height, px)
        end
    },
    ["Triangle"] = {
        GetSize = function(db, parent, px)
            local s = ns.SnapToScale(db.size or ns.defaults.size, px)
            return s, s
        end,
        Setup = function(indicator, width, height, px)
            -- Triangles must be desaturated to be tinted correctly by SetVertexColor
            SetupIndicatorTexture(indicator, ns.CONSTANTS.TEXTURE_TRIANGLE, true)
            ns.SetupCenteredInset(indicator, width, height, px)
        end
    }
}

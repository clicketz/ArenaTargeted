local _, ns = ...

--[[
    shape registry
    defines properties for each shape type. logic handled by IndicatorMixin.
]]

ns.shapes = {
    ["Box"] = {
        type = "basic",
    },
    ["Line"] = {
        type = "line",
        heightFactor = 0.25, -- height is 1/4th of size (user-defined size)
    }
}

-- register UI-RaidTargetingIcons shapes
for name, index in pairs(ns.CONSTANTS.RAID_ICON_INDICES) do
    ns.shapes[name] = {
        type = "icon",
        index = index
    }
end

local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)
if not lib or lib._implementationMinor ~= MINOR or lib._modules.ScrollBar == MINOR then
    return
end
lib._modules.ScrollBar = MINOR

local definition = lib._roles.scrollBar or {}
lib._roles.scrollBar = definition

function definition.Validate(target, parts, options)
    assert(target and target.Track and target.Track.Thumb and target.Back and target.Forward,
        "scrollBar requires a MinimalScrollBar")
    lib._ValidateControl(parts.bounds, options)
end

function definition.Initialize(handle, options)
    lib._InitializeControl(handle, options)
    local bar, parts = handle.target, handle.parts
    parts.track, parts.thumb = bar.Track, bar.Track.Thumb
    parts.back, parts.forward = bar.Back, bar.Forward
    -- Only the template's visual callbacks dispatch to the renderer. Native
    -- scrolling, dragging, enabled-state logic, and ScrollBox binding remain.
    local function Refresh() handle:RefreshAppearance() end
    parts.thumb.OnButtonStateChanged = Refresh
    parts.back.OnButtonStateChanged = Refresh
    parts.forward.OnButtonStateChanged = Refresh
    parts.thumb.OnSizeChanged = function(_, width, height)
        handle.context:_GetRenderer().ScrollThumbSize(handle, width, height)
    end
end

function definition.ApplyAppearance(handle)
    handle.context:_GetRenderer().ScrollBar(handle)
end

function definition.Layout(handle)
end

function lib._contextPrototype:CreateScrollBar(parent, options)
    if options == nil then options = {} end
    lib._ValidateControl(parent, options)
    self:GetColor(options.colorToken or "accent")
    local bar = CreateFrame("EventFrame", options.name, parent, "MinimalScrollBar")
    if options.width then bar:SetWidth(options.width) end
    if options.height then bar:SetHeight(options.height) end
    local handle = self:RegisterComponent("scrollBar", bar, { bounds = parent }, options)
    return bar, handle
end

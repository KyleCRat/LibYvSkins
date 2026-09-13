local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)
if not lib or lib._implementationMinor ~= MINOR or lib._modules.ScrollBar == MINOR then
    return
end
lib._modules.ScrollBar = MINOR

local definition = lib._roles.scrollBar or {}
lib._roles.scrollBar = definition
local ScrollBar = lib._scrollBarPrototype or {}
lib._scrollBarPrototype = ScrollBar
ScrollBar.__index = ScrollBar
setmetatable(ScrollBar, { __index = lib._controlPrototype })

local function ValidateOptions(parent, options)
    lib._ValidateControl(parent, options)
    assert(options.anchor == nil or (type(options.anchor.GetRect) == "function"
        and options.anchor:GetEffectiveScale() == parent:GetEffectiveScale()), "scrollbar anchor must share the parent scale")
    assert(options.gutterWidth == nil or (type(options.gutterWidth) == "number" and options.gutterWidth > 0),
        "scrollbar gutterWidth must be positive")
    assert(not options.anchor or options.gutterWidth, "anchored scrollbars require gutterWidth")
    for _, key in ipairs({ "rightOffset", "topOffset", "bottomOffset" }) do
        assert(options[key] == nil or type(options[key]) == "number", "scrollbar offsets must be numeric")
    end
end

function definition.Validate(target, parts, options)
    assert(target and target.Track and target.Track.Thumb and target.Back and target.Forward,
        "scrollBar requires a MinimalScrollBar")
    ValidateOptions(parts.bounds, options)
end

function definition.Initialize(handle, options)
    lib._InitializeControl(handle, options, ScrollBar)
    local bar, parts = handle.target, handle.parts
    parts.track, parts.thumb = bar.Track, bar.Track.Thumb
    parts.back, parts.forward = bar.Back, bar.Forward
    handle.anchor, handle.gutterWidth = options.anchor, options.gutterWidth
    handle.rightOffset, handle.topOffset, handle.bottomOffset = options.rightOffset or 0, options.topOffset or 0, options.bottomOffset or 0
    handle.trackPoints = {}
    for index = 1, parts.track:GetNumPoints() do handle.trackPoints[index] = { parts.track:GetPoint(index) } end
    handle.stepperPoints = {}
    for _, button in ipairs({ parts.back, parts.forward }) do
        local points = {}
        for index = 1, button.Texture:GetNumPoints() do points[index] = { button.Texture:GetPoint(index) } end
        handle.stepperPoints[button] = points
    end
    parts.trackSurface = lib._CreateSurface(handle, parts.track, parts.track)
    parts.thumbSurface = lib._CreateSurface(handle, parts.thumb, parts.thumb)
    -- Only the template's visual callbacks dispatch to the renderer. Native
    -- scrolling, dragging, enabled-state logic, and ScrollBox binding remain.
    local function Refresh() handle:RefreshAppearance() end
    parts.thumb.OnButtonStateChanged = Refresh
    parts.back.OnButtonStateChanged = Refresh
    parts.forward.OnButtonStateChanged = Refresh
    -- Both renderers own arrow desaturation. Blizzard's OnEnable otherwise
    -- removes it after the state callback, exposing the atlas's yellow tint.
    parts.back.desaturateIfDisabled = false
    parts.forward.desaturateIfDisabled = false
    parts.thumb.OnSizeChanged = function(_, width, height)
        handle.context:_GetRenderer().ScrollThumbSize(handle, width, height)
    end
end

function definition.ApplyAppearance(handle)
    handle.context:_GetRenderer().ScrollBar(handle)
end

function definition.Layout(handle)
end

function ScrollBar:LayoutAnchor(flat)
    if not self.anchor then return end
    local right = flat and -(self.gutterWidth - self.target:GetWidth()) / 2 or self.rightOffset
    self.target:ClearAllPoints()
    PixelUtil.SetPoint(self.target, "TOPRIGHT", self.anchor, "TOPRIGHT", right, self.topOffset)
    PixelUtil.SetPoint(self.target, "BOTTOMRIGHT", self.anchor, "BOTTOMRIGHT", right, self.bottomOffset)
end

function lib._contextPrototype:CreateScrollBar(parent, options)
    if options == nil then options = {} end
    ValidateOptions(parent, options)
    self:GetColor(options.colorToken or "accent")
    local bar = CreateFrame("EventFrame", options.name, parent, "MinimalScrollBar")
    if options.width then bar:SetWidth(options.width) end
    if options.height then bar:SetHeight(options.height) end
    local handle = self:RegisterComponent("scrollBar", bar, { bounds = parent }, options)
    return bar, handle
end

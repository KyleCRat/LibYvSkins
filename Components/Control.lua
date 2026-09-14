local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)
if not lib or lib._implementationMinor ~= MINOR or lib._modules.Control == MINOR then
    return
end
lib._modules.Control = MINOR

-- Native controls keep their own visibility and input APIs. These handles own
-- only reusable presentation state, never values, gameplay, or persistence.
local Control = lib._controlPrototype or {}
lib._controlPrototype = Control
Control.__index = Control
setmetatable(Control, { __index = lib._handlePrototype })

function lib._ValidateControl(parent, options)
    assert(parent and type(parent.CreateTexture) == "function", "control parent must be a frame")
    assert(type(options) == "table", "control options must be a table")
    for _, key in ipairs({ "width", "height", "fontSize", "iconWidth", "iconHeight" }) do
        assert(options[key] == nil or (type(options[key]) == "number" and options[key] > 0),
            key .. " must be a positive number")
    end
    assert(options.font == nil or (type(options.font) == "string" and options.font ~= ""),
        "font must be a non-empty path")
    assert(options.fontFlags == nil or type(options.fontFlags) == "string", "fontFlags must be a string")
    for _, key in ipairs({ "name", "template", "iconAtlas", "atlas" }) do
        assert(options[key] == nil or (type(options[key]) == "string" and options[key] ~= ""),
            key .. " must be a non-empty string")
    end
    for _, key in ipairs({ "icon", "texture", "borderTexture" }) do
        assert(options[key] == nil or type(options[key]) == "string" or type(options[key]) == "number",
            key .. " must be a path or file ID")
    end
    assert(options.text == nil or type(options.text) == "string", "text must be a string")
    assert(options.alpha == nil or (type(options.alpha) == "number" and options.alpha >= 0 and options.alpha <= 1),
        "alpha must be between zero and one")
    local root = options.geometryRoot or parent
    assert(type(root.GetEffectiveScale) == "function" and parent:GetEffectiveScale() == root:GetEffectiveScale(),
        "control and geometryRoot must share an effective scale")
    assert(options.clip == nil or (type(options.clip.GetRect) == "function"
        and options.clip:GetEffectiveScale() == root:GetEffectiveScale()), "clip must share the control scale")
end

function lib._InitializeControl(handle, options, prototype)
    setmetatable(handle, prototype or Control)
    handle.font = options.font or handle.context._media and handle.context._media.font
    handle.fontSize = options.fontSize or 13
    handle.fontFlags = options.fontFlags or ""
    handle.fontObject = options.fontObject
    handle.alphaOwned = options.alpha ~= nil
    handle.clip = options.clip
end

function Control:RefreshGeometry()
    if self.registered ~= false then
        lib._roles[self.role].Layout(self)
        lib._LayoutSurfaces(self)
    end
end

function Control:SetShown(shown)
    if self.registered == false then return end
    self.shown = shown == true
    self.target:SetShown(self.shown)
end

function Control:SetColor(r, g, b, a)
    assert(type(r) == "number" and type(g) == "number" and type(b) == "number",
        "color requires numeric r, g, and b")
    assert(a == nil or type(a) == "number", "alpha must be numeric")
    self.r, self.g, self.b, self.a = r, g, b, a or 1
    self.usesColorToken = true
    self:RefreshAppearance()
end

function Control:GetColor()
    if self.r then
        return self.r, self.g, self.b, self.a
    end
    return self.context:GetColor(self.colorToken)
end

function lib._CreateStateTexture(parent, layer)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetAllPoints(parent)
    return texture
end

-- Library-owned button glyphs share one Flat placement policy. Preserve the
-- nominal dimensions and sampling settings for a lossless Modern round trip.
function lib._InitializeIconLayout(handle)
    local icon = handle.parts.icon
    handle.iconWidth, handle.iconHeight = icon:GetSize()
    handle.iconSnap = icon:IsSnappingToPixelGrid()
    handle.iconBias = icon:GetTexelSnappingBias()
end

function lib._LayoutCenteredIcon(handle, offsetX, offsetY)
    local metrics = handle.root.metrics
    local x, y, width, height = lib.Pixel.GetCenteredRect(
        handle.target, metrics, handle.iconWidth, handle.iconHeight
    )
    if not x then return end
    x, y = x + (offsetX or 0) * metrics.unit, y + (offsetY or 0) * metrics.unit
    local icon = handle.parts.icon
    if not handle.centeredIcon then
        icon:SetSnapToPixelGrid(false)
        icon:SetTexelSnappingBias(0)
        handle.centeredIcon = true
    end
    -- Unchanged desired geometry does not prove the client resolved the glyph.
    icon:ClearAllPoints()
    icon:SetSize(width, height)
    icon:SetPoint("BOTTOMLEFT", handle.target, "BOTTOMLEFT", x, y)
end

function lib._RestoreIconLayout(handle)
    if not handle.centeredIcon then return end
    local icon = handle.parts.icon
    icon:ClearAllPoints()
    icon:SetSize(handle.iconWidth, handle.iconHeight)
    icon:SetSnapToPixelGrid(handle.iconSnap)
    icon:SetTexelSnappingBias(handle.iconBias)
    handle.centeredIcon = false
end

function lib._HookButtonState(handle)
    local button = handle.target
    button:HookScript("OnEnter", function()
        handle.hovered = button:IsEnabled()
        handle:RefreshState()
    end)
    local function ClearInteraction()
        handle.hovered, handle.pressed = false, false
        handle:RefreshState()
    end
    button:HookScript("OnLeave", ClearInteraction)
    button:HookScript("OnHide", ClearInteraction)
    button:HookScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" and button:IsEnabled() then
            handle.pressed = true
            handle:RefreshState()
        end
    end)
    button:HookScript("OnMouseUp", function()
        handle.pressed = false
        handle.hovered = button:IsMouseOver()
        handle:RefreshState()
    end)
    button:HookScript("OnEnable", function() handle:RefreshState() end)
    button:HookScript("OnDisable", ClearInteraction)
end

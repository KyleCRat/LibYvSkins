local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or lib._modules.ExpandableHeader == MINOR
then
    return
end

lib._modules.ExpandableHeader = MINOR

local definition = lib._roles.expandableHeader or {}
lib._roles.expandableHeader = definition
local HeaderHandle = lib._expandableHeaderPrototype or {}
lib._expandableHeaderPrototype = HeaderHandle
HeaderHandle.__index = HeaderHandle
setmetatable(HeaderHandle, { __index = lib._handlePrototype })

-- Match LMS's icon-free Modern accordion; no leading icon slot is reserved.
local DEFAULT_WIDTH = 100
local DEFAULT_HEIGHT = 34
local DEFAULT_FONT_SIZE = 18
local LABEL_LEFT = 12
local ARROW_SIZE = 17
local ARROW_LABEL_GAP = 4

local function ValidateOptions(options)
    assert(
        type(options) == "table",
        "expandable header options must be a table"
    )

    for _, key in ipairs({ "width", "height", "fontSize" }) do
        assert(
            options[key] == nil
                or (type(options[key]) == "number" and options[key] > 0),
            "expandable header dimensions must be positive numbers"
        )
    end

    assert(
        options.text == nil or type(options.text) == "string",
        "header text must be a string"
    )
    assert(
        options.font == nil
            or (type(options.font) == "string" and options.font ~= ""),
        "header font must be a non-empty path"
    )
    assert(
        options.expanded == nil or type(options.expanded) == "boolean",
        "expanded must be a boolean"
    )
    assert(
        options.onClick == nil or type(options.onClick) == "function",
        "onClick must be a function"
    )
    assert(
        options.alpha == nil
            or (
                type(options.alpha) == "number"
                and options.alpha >= 0
                and options.alpha <= 1
            ),
        "header alpha must be between zero and one"
    )
end

function definition.Validate(header, parts, options)
    ValidateOptions(options)
    assert(
        header and type(header.SetNormalTexture) == "function",
        "expandable header must be a Button"
    )
    assert(
        type(parts) == "table"
            and parts.bounds
            and type(parts.bounds.GetEffectiveScale) == "function",
        "expandable header requires parts.bounds"
    )
    local root = options.geometryRoot or parts.bounds
    assert(
        type(root.GetEffectiveScale) == "function",
        "geometryRoot must be a region"
    )
    assert(
        header:GetEffectiveScale() == root:GetEffectiveScale()
            and parts.bounds:GetEffectiveScale() == root:GetEffectiveScale(),
        "expandable header, bounds, and geometryRoot must share an effective scale"
    )
    assert(
        options.clip == nil
            or (
                type(options.clip.GetRect) == "function"
                and options.clip:GetEffectiveScale()
                    == root:GetEffectiveScale()
            ),
        "clip must share the header scale"
    )
end

local function CreateStateTexture(header)
    local texture = header:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(header)
    return texture
end

function definition.Initialize(handle, options)
    setmetatable(handle, HeaderHandle)
    handle.clip = options.clip
    handle.expanded = options.expanded ~= false
    handle.hovered = false
    local header = handle.target
    local parts = handle.parts
    parts.surface = lib._CreateSurface(handle, header, header)
    parts.normal = CreateStateTexture(header)
    parts.pressed = CreateStateTexture(header)
    parts.disabled = CreateStateTexture(header)
    header:SetNormalTexture(parts.normal)
    header:SetPushedTexture(parts.pressed)
    header:SetDisabledTexture(parts.disabled)

    local arrow = header:CreateTexture(nil, "OVERLAY", nil, 2)
    parts.arrow = arrow
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)

    local label = header:CreateFontString(nil, "OVERLAY")
    parts.label = label
    header:SetFontString(label)

    if options.font then
        label:SetFont(options.font, options.fontSize or DEFAULT_FONT_SIZE)
    else
        label:SetFontObject(GameFontNormalLarge)
    end

    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetWordWrap(false)
    label:SetMaxLines(1)
    label:ClearAllPoints()
    label:SetPoint("LEFT", header, "LEFT", LABEL_LEFT, 0)
    label:SetPoint("RIGHT", arrow, "LEFT", -ARROW_LABEL_GAP, 0)

    -- Visual hooks leave native setters and consumer behavior scripts intact.
    header:HookScript("OnEnter", function()
        handle.hovered = header:IsEnabled()
        handle:RefreshAppearance()
    end)
    header:HookScript("OnLeave", function()
        handle.hovered = false
        handle:RefreshAppearance()
    end)
    header:HookScript("OnHide", function()
        handle.hovered, handle.pressed = false, false
        header:SetButtonState("NORMAL")
        handle:RefreshAppearance()
    end)
    header:HookScript("OnEnable", function()
        handle:RefreshAppearance()
    end)
    header:HookScript("OnDisable", function()
        handle.hovered, handle.pressed = false, false
        handle:RefreshAppearance()
    end)
    header:HookScript("OnMouseDown", function()
        handle.pressed = header:IsEnabled()
        handle:RefreshAppearance()
    end)
    header:HookScript("OnMouseUp", function()
        handle.pressed = false
        handle:RefreshAppearance()
    end)
end

function definition.ApplyAppearance(handle)
    local r, g, b, a = handle.context:GetColor(handle.colorToken)
    handle.parts.label:SetTextColor(
        r,
        g,
        b,
        handle.target:IsEnabled() and a or a * 0.5
    )
    handle.target:SetAlpha(handle.alpha)
    handle.context:_GetRenderer().ExpandableHeader(handle)
end

function definition.Layout(handle)
    -- Native anchors and parent visibility own this non-pixel control's bounds.
    handle.target:SetShown(handle.shown)
end

function HeaderHandle:SetExpanded(expanded)
    assert(type(expanded) == "boolean", "expanded must be a boolean")
    self.expanded = expanded
    self:RefreshAppearance()
end

function HeaderHandle:IsExpanded()
    return self.expanded
end

function HeaderHandle:RefreshGeometry()
    if self.registered ~= false then
        lib._roles[self.role].Layout(self)
        lib._LayoutSurfaces(self)
    end
end

function lib._contextPrototype:CreateExpandableHeader(parent, options)
    if options == nil then options = {} end

    ValidateOptions(options)
    assert(
        parent and type(parent.CreateTexture) == "function",
        "header parent must be a frame"
    )
    local bounds = options.bounds or parent
    local root = options.geometryRoot or bounds
    assert(
        type(bounds.GetEffectiveScale) == "function"
            and type(root.GetEffectiveScale) == "function",
        "header bounds and geometryRoot must be regions"
    )
    assert(
        parent:GetEffectiveScale() == bounds:GetEffectiveScale()
            and parent:GetEffectiveScale() == root:GetEffectiveScale(),
        "header parent, bounds, and geometryRoot must share an effective scale"
    )
    self:GetColor(options.colorToken or "accent")

    local header = CreateFrame("Button", nil, parent)
    header:SetSize(
        options.width or DEFAULT_WIDTH,
        options.height or DEFAULT_HEIGHT
    )
    header:EnableMouse(true)
    header:RegisterForClicks("LeftButtonUp")
    local handle = self:RegisterComponent(
        "expandableHeader",
        header,
        { bounds = bounds },
        options
    )
    header:SetText(options.text or "")
    header:SetScript("OnClick", options.onClick)
    return header, handle
end

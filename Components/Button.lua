local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)
if not lib or lib._implementationMinor ~= MINOR or lib._modules.Button == MINOR then
    return
end
lib._modules.Button = MINOR

local definition = lib._roles.button or {}
lib._roles.button = definition
local Button = lib._buttonPrototype or {}
lib._buttonPrototype = Button
Button.__index = Button
setmetatable(Button, { __index = lib._controlPrototype })

local function ValidateOptions(parent, options)
    lib._ValidateControl(parent, options)
    assert(options.variant == nil or options.variant == "command" or options.variant == "square",
        "button variant must be command or square")
    assert(options.selected == nil or type(options.selected) == "boolean", "selected must be boolean")
    assert(not (options.icon and options.iconAtlas), "use either icon or iconAtlas")
    assert(options.checkmarkScale == nil or (type(options.checkmarkScale) == "number" and options.checkmarkScale > 0),
        "checkmarkScale must be positive")
    assert(options.pressIcon == nil or type(options.pressIcon) == "boolean", "pressIcon must be boolean")
    assert(options.labelOffsetY == nil or type(options.labelOffsetY) == "number", "labelOffsetY must be numeric")
    for _, key in ipairs({ "iconAlpha", "disabledIconAlpha" }) do
        assert(options[key] == nil or (type(options[key]) == "number" and options[key] >= 0 and options[key] <= 1),
            key .. " must be between zero and one")
    end
end

function definition.Validate(target, parts, options)
    assert(target and type(target.IsEnabled) == "function", "button role requires a Button")
    assert(type(parts) == "table" and parts.bounds, "button role requires bounds")
    ValidateOptions(parts.bounds, options)
end

function definition.Initialize(handle, options)
    lib._InitializeControl(handle, options, Button)
    local button, parts = handle.target, handle.parts
    parts.surface = lib._CreateSurface(handle, button, button)
    handle.variant = options.variant or "command"
    handle.selected = options.selected == true
    handle.isTab = options.isTab == true
    handle.hovered, handle.pressed = false, false
    handle.pressIcon = options.pressIcon == true
    handle.iconAlpha = options.iconAlpha or 1
    handle.disabledIconAlpha = options.disabledIconAlpha or 0.5
    handle.checkmarkScale = options.checkmarkScale or 1.25
    parts.normal = lib._CreateStateTexture(button, "BACKGROUND")
    parts.hover = lib._CreateStateTexture(button, "BORDER")
    parts.pressed = lib._CreateStateTexture(button, "BORDER")
    parts.disabled = lib._CreateStateTexture(button, "BORDER")
    local label = button:CreateFontString(nil, "OVERLAY")
    parts.label = label
    button:SetFontString(label)
    button.Text = label
    label:SetPoint("CENTER", button, "CENTER", 0, options.labelOffsetY or 1)
    if handle.fontObject then
        label:SetFontObject(handle.fontObject)
    elseif handle.font then
        label:SetFont(handle.font, handle.fontSize, handle.fontFlags)
    else
        label:SetFontObject(GameFontNormal)
    end
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetWordWrap(false)
    if options.icon or options.iconAtlas then
        local icon = button:CreateTexture(nil, "OVERLAY", nil, 1)
        if options.iconAtlas then icon:SetAtlas(options.iconAtlas, false) else icon:SetTexture(options.icon) end
        icon:SetSize(options.iconWidth or 18, options.iconHeight or options.iconWidth or 18)
        parts.icon = icon
    end
    if options.checkbox then
        parts.checked = button:CreateTexture(nil, "ARTWORK")
        parts.disabledChecked = button:CreateTexture(nil, "ARTWORK")
        for _, checkmark in ipairs({ parts.checked, parts.disabledChecked }) do
            checkmark:SetPoint("CENTER", button, "CENTER", 2, 2)
            checkmark:SetScale(options.checkmarkScale or 1.25)
        end
        button:SetCheckedTexture(parts.checked)
        button:SetDisabledCheckedTexture(parts.disabledChecked)
    end
    lib._HookButtonState(handle)
end

function definition.ApplyAppearance(handle)
    handle.context:_GetRenderer().Button(handle)
end

function definition.Layout(handle)
    -- The caller owns anchors, dimensions, and native control visibility.
end

function Button:SetSelected(selected)
    assert(type(selected) == "boolean", "selected must be boolean")
    self.selected = selected
    self:RefreshAppearance()
end

function Button:RefreshState()
    if self.registered ~= false then
        self.context:_GetRenderer().ButtonState(self)
    end
end

function Button:SetVariant(variant)
    assert(variant == "command" or variant == "square", "button variant must be command or square")
    self.variant = variant
    self:RefreshAppearance()
end

local function Create(context, parent, options, checkbox, isTab)
    if options == nil then options = {} end
    ValidateOptions(parent, options)
    context:GetColor(options.colorToken or "accent")
    local button = CreateFrame(checkbox and "CheckButton" or "Button", options.name, parent, options.template)
    button:SetSize(options.width or (checkbox and 34 or 100), options.height or 34)
    button:RegisterForClicks("LeftButtonUp")
    local settings = {}
    for key, value in pairs(options) do settings[key] = value end
    settings.checkbox, settings.isTab = checkbox, isTab
    if checkbox then settings.variant = "square" end
    local handle = context:RegisterComponent("button", button, { bounds = parent }, settings)
    button:SetText(options.text or "")
    return button, handle
end

function lib._contextPrototype:CreateButton(parent, options)
    return Create(self, parent, options, false, false)
end

function lib._contextPrototype:CreateTab(parent, options)
    return Create(self, parent, options, false, true)
end

function lib._contextPrototype:CreateCheckbox(parent, options)
    return Create(self, parent, options, true, false)
end

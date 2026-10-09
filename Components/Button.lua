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

local HEADER_TAB_HEIGHT, HEADER_TAB_ATLAS_SIZE = 64, 256
local HEADER_TAB_LAYERS = {
    { key = "background", x = 0, y = 64, layer = "BACKGROUND", sublevel = 0 },
    { key = "backgroundAccent", x = 112, y = 0, layer = "BACKGROUND", sublevel = 1 },
    { key = "normal", x = 0, y = 0, layer = "BORDER" },
    { key = "hover", x = 112, y = 64, layer = "ARTWORK" },
    { key = "selected", x = 112, y = 128, layer = "ARTWORK" },
}
local HEADER_TAB_COLUMNS = {
    { start = 0, finish = 32 },
    { start = 32, finish = 33 },
    { start = 80, finish = 112 },
}
local HEADER_TAB_ROWS = {
    { start = 0, finish = 32 },
    { start = 32, finish = 33 },
    { start = 48, finish = 64 },
}

local function ValidateOptions(parent, options)
    lib._ValidateControl(parent, options)
    assert(options.variant == nil or options.variant == "command" or options.variant == "square",
        "button variant must be command or square")
    assert(options.selected == nil or type(options.selected) == "boolean", "selected must be boolean")
    assert(options.tabStyle == nil or options.tabStyle == "header", "tabStyle must be header when supplied")
    assert(not options.tabStyle or options.variant == nil or options.variant == "command",
        "header tabs use the command variant")
    assert(not (options.icon and options.iconAtlas), "use either icon or iconAtlas")
    assert(options.checkmarkScale == nil or (type(options.checkmarkScale) == "number" and options.checkmarkScale > 0),
        "checkmarkScale must be positive")
    assert(options.pressIcon == nil or type(options.pressIcon) == "boolean", "pressIcon must be boolean")
    assert(options.preserveIconColor == nil or type(options.preserveIconColor) == "boolean", "preserveIconColor must be boolean")
    assert(options.labelOffsetY == nil or type(options.labelOffsetY) == "number", "labelOffsetY must be numeric")
    for _, key in ipairs({ "iconAlpha", "disabledIconAlpha" }) do
        assert(options[key] == nil or (type(options[key]) == "number" and options[key] >= 0 and options[key] <= 1),
            key .. " must be between zero and one")
    end
end

local function GetHeaderTabUVRange(offset, slice)
    if slice.finish - slice.start == 1 then
        -- Sample the single stretch texel at its center so linear filtering
        -- cannot pull adjacent atlas pixels into the stretched edge or fill.
        local center = (offset + slice.start + 0.5) / HEADER_TAB_ATLAS_SIZE
        return center, center
    end
    return (offset + slice.start) / HEADER_TAB_ATLAS_SIZE,
        (offset + slice.finish) / HEADER_TAB_ATLAS_SIZE
end

local function CreateHeaderTabArt(button)
    local layers = {}
    -- Native texture slice margins sample the entire center band. This atlas
    -- provides separate one-texel strips, so each layer uses nine UV regions.
    for _, definition in ipairs(HEADER_TAB_LAYERS) do
        local slices = {}
        for rowIndex, row in ipairs(HEADER_TAB_ROWS) do
            local top, bottom = GetHeaderTabUVRange(definition.y, row)
            for columnIndex, column in ipairs(HEADER_TAB_COLUMNS) do
                local left, right = GetHeaderTabUVRange(definition.x, column)
                local texture = button:CreateTexture(nil, definition.layer, nil, definition.sublevel)
                texture:SetTexture(lib._headerTabTexture, "CLAMP", "CLAMP", "LINEAR")
                texture:SetTexCoord(left, right, top, bottom)
                texture:SetSnapToPixelGrid(false)
                texture:SetTexelSnappingBias(0)
                texture:SetBlendMode("BLEND")
                slices[(rowIndex - 1) * 3 + columnIndex] = texture
            end
        end
        layers[definition.key] = slices
    end
    return layers
end

local function LayoutHeaderTab(handle)
    local button = handle.target
    local visible = handle.headerTabVisible
    for index = 1, 9 do
        visible[index] = false
    end
    local originX, originY, width, height = button:GetRect()
    if not originX or not originY or not width or not height or width <= 0 or height <= 0 then return end
    local unit = handle.root.metrics.unit
    -- Relative offsets can be whole pixels while an ancestor leaves the tab
    -- between pixels. Snap absolute edges and share the joins across all layers.
    local leftPixel = math.floor(originX / unit + 0.5)
    local bottomPixel = math.floor(originY / unit + 0.5)
    local rightPixel = math.floor((originX + width) / unit + 0.5)
    local topPixel = math.floor((originY + height) / unit + 0.5)
    local pixelWidth, pixelHeight = rightPixel - leftPixel, topPixel - bottomPixel
    if pixelWidth <= 0 or pixelHeight <= 0 then return end
    local cornerPixels = math.min(
        math.max(1, math.floor(32 / unit + 0.5)),
        math.floor(pixelWidth / 2),
        math.floor(pixelHeight / 2 + 0.5)
    )
    local bottomPixels = math.min(pixelHeight - cornerPixels, math.floor(cornerPixels / 2 + 0.5))

    local columns, rows = handle.headerTabColumns, handle.headerTabRows
    columns[1], columns[2] = leftPixel, leftPixel + cornerPixels
    columns[3], columns[4] = rightPixel - cornerPixels, rightPixel
    rows[1], rows[2] = topPixel, topPixel - cornerPixels
    rows[3], rows[4] = bottomPixel + bottomPixels, bottomPixel
    for row = 1, 3 do
        local y = rows[row + 1] * unit - originY
        local drawHeight = (rows[row] - rows[row + 1]) * unit
        for column = 1, 3 do
            local x = columns[column] * unit - originX
            local drawWidth = (columns[column + 1] - columns[column]) * unit
            local index = (row - 1) * 3 + column
            -- Zero texture dimensions can restore the atlas's intrinsic size.
            -- Leave empty slices unsized; the renderer owns their visibility.
            visible[index] = drawWidth > 0 and drawHeight > 0
            if visible[index] then
                for _, slices in pairs(handle.parts.headerTab) do
                    local texture = slices[index]
                    texture:ClearAllPoints()
                    texture:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", x, y)
                    texture:SetSize(drawWidth, drawHeight)
                end
            end
        end
    end
end

function definition.Validate(target, parts, options)
    assert(target and type(target.IsEnabled) == "function", "button role requires a Button")
    assert(type(parts) == "table" and parts.bounds, "button role requires bounds")
    ValidateOptions(parts.bounds, options)
    assert(not options.tabStyle or options.isTab, "tabStyle requires a tab")
end

function definition.Initialize(handle, options)
    lib._InitializeControl(handle, options, Button)
    local button, parts = handle.target, handle.parts
    parts.surface = lib._CreateSurface(handle, button, button)
    handle.variant = options.variant or "command"
    handle.selected = options.selected == true
    handle.isTab = options.isTab == true
    handle.tabStyle = options.tabStyle
    handle.hovered, handle.pressed = false, false
    handle.pressIcon = options.pressIcon == true
    handle.preserveIconColor = options.preserveIconColor == true
    handle.iconAlpha = options.iconAlpha or 1
    handle.disabledIconAlpha = options.disabledIconAlpha or 0.5
    handle.checkmarkScale = options.checkmarkScale or 1.25
    handle.labelOffsetY = options.labelOffsetY or 1
    -- Renderers own label anchors, including press feedback. Native push/pop
    -- offsets would shift a freshly anchored label again after selection changes.
    handle.pushedTextOffsetX, handle.pushedTextOffsetY = button:GetPushedTextOffset()
    button:SetPushedTextOffset(0, 0)
    if handle.tabStyle == "header" then
        parts.headerTab = CreateHeaderTabArt(button)
        handle.headerTabColumns, handle.headerTabRows = {}, {}
        handle.headerTabVisible = {}
    else
        parts.normal = lib._CreateStateTexture(button, "BACKGROUND")
        parts.hover = lib._CreateStateTexture(button, "BORDER")
        parts.pressed = lib._CreateStateTexture(button, "BORDER")
        parts.disabled = lib._CreateStateTexture(button, "BORDER")
    end
    local label = button:CreateFontString(nil, "OVERLAY")
    parts.label = label
    button:SetFontString(label)
    button.Text = label
    label:SetPoint("CENTER", button, "CENTER", 0, handle.labelOffsetY)
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
        icon:SetPoint("CENTER", button, "CENTER", 0, 0)
        parts.icon = icon
        lib._InitializeIconLayout(handle)
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

local function ApplyCheckmarkArtwork(texture, scale)
    texture:SetAtlas("common-icon-checkmark-yellow", true)
    texture:ClearAllPoints()
    texture:SetScale(scale)
end

function definition.ApplyAppearance(handle)
    local parts = handle.parts
    if handle.fontObject then
        parts.label:SetFontObject(handle.fontObject)
    elseif handle.font then
        parts.label:SetFont(handle.font, handle.fontSize, handle.fontFlags)
    end
    handle.target:SetAlpha(handle.alpha)
    if parts.checked then
        -- Both skins retain native checked artwork; each owns its tint/anchor.
        ApplyCheckmarkArtwork(parts.checked, handle.checkmarkScale)
        ApplyCheckmarkArtwork(parts.disabledChecked, handle.checkmarkScale)
    end
    handle.context:_GetRenderer().Button(handle)
end

function definition.Layout(handle)
    local renderer = handle.context:_GetRenderer()
    if handle.parts.headerTab then
        LayoutHeaderTab(handle)
        renderer.ButtonState(handle)
    end
    -- Recompute snapped glyph geometry after scale changes, without changing
    -- the caller's button geometry or reloading fonts/atlases.
    renderer.ButtonIconLayout(handle)
end

function Button:SetSelected(selected)
    assert(type(selected) == "boolean", "selected must be boolean")
    self.selected = selected
    self:RefreshAppearance()
end

function Button:RefreshState()
    if self.registered ~= false then
        local icon = self.parts.icon
        if icon then
            local enabled = self.target:IsEnabled()
            icon:SetAlpha(enabled and (self.hovered and 1 or self.iconAlpha) or self.disabledIconAlpha)
        end
        local renderer = self.context:_GetRenderer()
        renderer.ButtonState(self)
        renderer.ButtonIconLayout(self)
    end
end

function Button:SetVariant(variant)
    assert(variant == "command" or variant == "square", "button variant must be command or square")
    assert(not self.tabStyle or variant == "command", "header tabs use the command variant")
    self.variant = variant
    self:RefreshAppearance()
end

local function Create(context, parent, options, checkbox, isTab)
    if options == nil then options = {} end
    ValidateOptions(parent, options)
    assert(not options.tabStyle or isTab, "tabStyle requires a tab")
    context:GetColor(options.colorToken or "accent")
    local button = CreateFrame(checkbox and "CheckButton" or "Button", options.name, parent, options.template)
    local defaultHeight = options.tabStyle == "header" and HEADER_TAB_HEIGHT or 34
    button:SetSize(options.width or (checkbox and 34 or 100), options.height or defaultHeight)
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

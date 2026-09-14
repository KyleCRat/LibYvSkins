local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)
if not lib or lib._implementationMinor ~= MINOR or lib._modules.Modern == MINOR then
    return
end
lib._modules.Modern = MINOR

local Modern = lib._skins.modern or {}
lib._skins.modern = Modern
local GOLD_R, GOLD_G, GOLD_B = 1, 0.82, 0
local SQUARE_ICON_OFFSET_PIXELS = 1

Modern.WindowMetrics = {
    padding = { left = 4, right = 6, top = 24, bottom = 4 },
    bodyPadding = { left = 3, right = 3, top = 3, bottom = 2 },
    titleBarHeight = 24,
}

function Modern.WindowLayout(handle)
    local frame = handle.target
    frame.TitleContainer:ClearAllPoints()
    frame.TitleContainer:SetHeight(handle.titleHeight)
    for _, point in ipairs(handle.titlePoints) do
        local x = point[4]
        if point[1] == "TOPLEFT" and not handle.layout.portrait then x = 0 end
        if point[1] == "TOPRIGHT" and handle.layout.closeButton ~= "titleBar" then x = 0 end
        frame.TitleContainer:SetPoint(point[1], frame.titleBar, point[3], x, point[5])
    end
    if handle.layout.closeButton == "titleBar" then
        frame.CloseButton:ClearAllPoints()
        frame.CloseButton:SetSize(handle.closeWidth, handle.closeHeight)
        for _, point in ipairs(handle.closePoints) do
            frame.CloseButton:SetPoint(point[1], frame.titleBar, point[3], point[4], point[5])
        end
    end
    frame.resizeButton:ClearAllPoints()
    frame.resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 3)
end

local function SetActionIconColor(icon, enabled)
    if enabled then
        icon:SetVertexColor(GOLD_R, GOLD_G, GOLD_B, 1)
    else
        icon:SetVertexColor(0.5, 0.5, 0.5, 1)
    end
end

function Modern.PopupSlider(handle)
    local popup, parts, baseline = handle.target, handle.parts.visuals, handle.baseline
    popup:SetBackdrop(baseline.backdrop)
    local color = baseline.backgroundColor
    popup:SetBackdropColor(color.r, color.g, color.b, color.a)
    popup:SetBackdropBorderColor(0, 0, 0, 1)
    color = baseline.trackColor
    parts.track:SetColorTexture(color.r, color.g, color.b, color.a)
    color = baseline.markerColor
    for _, marker in ipairs(parts.markers) do marker:SetColorTexture(color.r, color.g, color.b, color.a) end
    color = baseline.thumbColor
    parts.thumb:SetAtlas("Minimal_SliderBar_Button", false)
    parts.thumb:SetVertexColor(color.r, color.g, color.b, color.a)
    -- Font fitting can change popup geometry; defer it until the drag ends.
    if not popup:IsInteracting() then
        popup:SetFontAppearance(baseline.font, baseline.fontFlags)
    end
end

function Modern.NativeButton(handle)
    Modern.NativeButtonLayout(handle)
    handle.parts.icon:Hide()
    for _, state in ipairs(handle.parts.states) do
        local texture = state.region
        handle.target[state.setter](handle.target, texture)
        if state.atlas then texture:SetAtlas(state.atlas, false) else texture:SetTexture(state.texture) end
        texture:SetTexCoord(unpack(state.coordinates))
        texture:SetVertexColor(unpack(state.color))
        texture:SetAlpha(state.alpha)
        texture:SetBlendMode(state.blend)
    end
end

function Modern.NativeButtonLayout(handle)
    lib._RestoreIconLayout(handle)
    handle.parts.icon:SetPoint("CENTER", handle.target, "CENTER", 0, 0)
end

function Modern.ExpandableHeader(handle)
    local header, parts = handle.target, handle.parts
    local enabled = header:IsEnabled()
    parts.normal:SetAlpha(1)
    parts.pressed:SetAlpha(1)
    parts.disabled:SetAlpha(1)
    parts.arrow:SetDesaturated(false)
    parts.arrow:SetVertexColor(1, 1, 1, 1)
    parts.normal:SetAtlas(enabled and handle.hovered and "common-button-tertiary-hover" or "common-button-tertiary-normal", false)
    parts.pressed:SetAtlas("common-button-tertiary-pressed", false)
    parts.disabled:SetAtlas("common-button-tertiary-disabled", false)
    parts.arrow:SetAtlas(enabled and "common-dropdown-icon-next" or "common-dropdown-icon-next-disabled", false)
    parts.arrow:SetRotation(handle.expanded and math.pi * 1.5 or math.pi * 0.5)
    parts.arrow:ClearAllPoints()
    parts.arrow:SetPoint("RIGHT", header, "RIGHT", -12, handle.expanded and 2 or -1)
end

function Modern.Window(handle)
    local frame = handle.target
    if handle.windowPortrait ~= handle.layout.portrait then
        frame:SetBorder(handle.layout.portrait and "PortraitFrameTemplate" or "ButtonFrameTemplateNoPortrait")
        handle.windowPortrait = handle.layout.portrait
    end
    for index, region in ipairs(handle.parts.chrome) do region:SetAlpha(handle.chromeAlpha[index]) end
    frame.TopTileStreaks:Hide()
    frame.TopTileStreaks:SetAlpha(0)
    frame.Inset.Bg:SetTexture(handle.insetBackground, "REPEAT", "REPEAT")
    frame.Inset.Bg:SetHorizTile(true)
    frame.Inset.Bg:SetVertTile(true)
end

function Modern.ScrollBar(handle)
    local parts = handle.parts
    if handle.layoutSkin ~= "modern" then
        local restoreTrack = handle.layoutSkin ~= nil
        handle.layoutSkin = "modern"
        handle:LayoutAnchor(false)
        if restoreTrack then
            parts.track:ClearAllPoints()
            for _, point in ipairs(handle.trackPoints) do parts.track:SetPoint(unpack(point)) end
        end
    end
    for _, region in ipairs({ parts.track.Begin, parts.track.Middle, parts.track.End,
        parts.thumb.Begin, parts.thumb.Middle, parts.thumb.End }) do region:SetAlpha(1) end
    for _, button in ipairs({ parts.back, parts.forward }) do
        button.Texture:SetRotation(0)
        button.Texture:SetVertexColor(1, 1, 1, 1)
        button.Texture:SetDesaturated(not button:IsEnabled())
        if handle.stepperLayoutSkin and handle.stepperLayoutSkin ~= "modern" then
            button.Texture:ClearAllPoints()
            for _, point in ipairs(handle.stepperPoints[button]) do button.Texture:SetPoint(unpack(point)) end
        end
    end
    handle.stepperLayoutSkin = "modern"
    parts.track.Begin:SetAtlas("minimal-scrollbar-track-top", true)
    parts.track.Middle:SetAtlas("!minimal-scrollbar-track-middle", true)
    parts.track.End:SetAtlas("minimal-scrollbar-track-bottom", true)
    MinimalScrollBarThumbScriptsMixin.OnButtonStateChanged(parts.thumb)
    MinimalScrollBarThumbScriptsMixin.OnSizeChanged(parts.thumb, parts.thumb:GetSize())
    MinimalScrollBarStepperScriptsMixin.OnButtonStateChanged(parts.back)
    MinimalScrollBarStepperScriptsMixin.OnButtonStateChanged(parts.forward)
end

function Modern.ScrollThumbSize(handle, width, height)
    MinimalScrollBarThumbScriptsMixin.OnSizeChanged(handle.parts.thumb, width, height)
end

local BUTTON_ATLASES = {
    command = {
        normal = "common-button-tertiary-normal", hover = "common-button-tertiary-hover",
        pressed = "common-button-tertiary-pressed", disabled = "common-button-tertiary-disabled",
        selected = "common-button-tertiary-selected", selectedOutset = 3,
    },
    square = {
        normal = "common-button-tertiary-square-normal", hover = "common-button-tertiary-square-hover",
        pressed = "common-button-tertiary-square-pressed", disabled = "common-button-tertiary-square-disabled",
        selected = "common-button-tertiary-square-selected", selectedOutset = 0,
    },
}

function Modern.Button(handle)
    local button, parts = handle.target, handle.parts
    local atlases = BUTTON_ATLASES[handle.variant]
    local selected = handle.selected
    parts.label:ClearAllPoints()
    parts.normal:SetAlpha(1)
    parts.hover:SetAlpha(1)
    parts.pressed:SetAlpha(1)
    parts.disabled:SetAlpha(1)
    parts.normal:SetAtlas(selected and atlases.selected or atlases.normal, false)
    parts.hover:SetAtlas(atlases.hover, false)
    parts.pressed:SetAtlas(atlases.pressed, false)
    parts.disabled:SetAtlas(atlases.disabled, false)
    local outset = selected and atlases.selectedOutset or 0
    parts.normal:ClearAllPoints()
    parts.normal:SetPoint("TOPLEFT", button, "TOPLEFT", -outset, outset)
    parts.normal:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", outset, -outset)
    if parts.checked then
        parts.disabledChecked:SetDesaturated(true)
        parts.disabledChecked:SetVertexColor(0.5, 0.5, 0.5)
        parts.checked:SetDesaturated(false)
        parts.checked:SetVertexColor(1, 1, 1, 1)
    end
    handle:RefreshState()
end

function Modern.ButtonState(handle)
    local button, parts = handle.target, handle.parts
    local enabled, selected = button:IsEnabled(), handle.selected
    local pressed = enabled and not selected and handle.pressed
    parts.label:SetPoint("CENTER", button, "CENTER",
        pressed and handle.pushedTextOffsetX or 0,
        handle.labelOffsetY + (pressed and handle.pushedTextOffsetY or 0))
    parts.hover:SetShown(enabled and not selected and handle.hovered and not handle.pressed)
    parts.pressed:SetShown(pressed)
    parts.disabled:SetShown(not enabled)
    local r, g, b = GOLD_R, GOLD_G, GOLD_B
    if not enabled then
        r, g, b = 0.5, 0.5, 0.5
    elseif handle.isTab and not selected then
        r, g, b = 0.92, 0.92, 0.92
    elseif not handle.isTab and enabled and handle.hovered then
        r, g, b = 1, 1, 1
    end
    parts.label:SetTextColor(r, g, b, 1)
    if parts.icon then
        if handle.preserveIconColor then
            parts.icon:SetVertexColor(1, 1, 1, 1)
        else
            SetActionIconColor(parts.icon, enabled)
        end
        parts.icon:SetDesaturated(not enabled)
    end
end

function Modern.ButtonIconLayout(handle)
    local button, parts = handle.target, handle.parts
    if parts.icon then
        lib._RestoreIconLayout(handle)
        local offset = handle.pressIcon and handle.pressed and button:IsEnabled() and not handle.selected and 1 or 0
        -- Compensate for the tertiary-square atlas's heavier bottom edge.
        local y = handle.variant == "square" and SQUARE_ICON_OFFSET_PIXELS * handle.root.metrics.unit or 0
        parts.icon:SetPoint("CENTER", button, "CENTER", offset, y - offset)
    end
    if parts.checked then
        parts.checked:SetPoint("CENTER", button, "CENTER", 2, 2)
        parts.disabledChecked:SetPoint("CENTER", button, "CENTER", 2, 2)
    end
end

function Modern.Texture(handle)
    lib._ApplyTextureAppearance(handle)
end

function Modern.Text(handle)
    lib._ApplyTextAppearance(handle)
end

function Modern.Icon(handle)
    handle.parts.flatBorder:Hide()
    handle.parts.border:SetTexture(handle.borderTexture)
    if handle.alphaOwned then handle.target:SetAlpha(handle.alpha) end
    Modern.IconState(handle)
    Modern.IconColor(handle)
    if handle.crop then
        handle.target:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    Modern.IconLayout(handle)
end

function Modern.IconState(handle)
    if handle.actionIcon then
        local enabled = handle.parts.bounds:IsEnabled()
        handle.target:SetDesaturated(not enabled)
        SetActionIconColor(handle.target, enabled)
    end
end

function Modern.IconColor(handle)
    handle.parts.border:SetVertexColor(handle.r, handle.g, handle.b, handle.a)
    handle.parts.border:SetAlpha(handle.borderAlpha * handle.alpha)
end

function Modern.IconLayout(handle)
    local border, icon = handle.parts.border, handle.target
    local outset = handle.borderOutset - handle.artworkOutset
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", icon, "TOPLEFT", -outset, outset)
    border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", outset, -outset)
    Modern.IconVisibility(handle)
end

function Modern.IconVisibility(handle)
    handle.parts.border:SetShown(handle.borderShown and handle.target:IsShown())
end

function Modern.EditBox(handle)
    local editBox, parts = handle.target, handle.parts
    editBox:SetTextInsets(unpack(handle.textInsets))
    if parts.instructions then
        parts.instructions:ClearAllPoints()
        parts.instructions:SetPoint("TOPLEFT", editBox, "TOPLEFT", handle.textInsets[1], 0)
        parts.instructions:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", -handle.textInsets[2], 0)
        parts.clearButton.Icon:SetAtlas("common-search-clearbutton", false)
        parts.clearButton.Icon:SetVertexColor(1, 1, 1, 1)
    end
    parts.background:SetAtlas("common-button-tertiary-depressed-normal", false)
    parts.background:SetAlpha(1)
    if parts.focus then
        parts.focus:SetAtlas("common-button-tertiary-depressed-normal-glow", false)
        parts.focus:SetShown(editBox:HasFocus() and editBox:IsEnabled())
    end
end

local GLOW_TEXTURES = {
    topLeft = "Interface\\Common\\GlowBorder-Corner", topRight = "Interface\\Common\\GlowBorder-Corner",
    bottomLeft = "Interface\\Common\\GlowBorder-Corner", bottomRight = "Interface\\Common\\GlowBorder-Corner",
    top = "Interface\\Common\\GlowBorder-Top", bottom = "Interface\\Common\\GlowBorder-Top",
    left = "Interface\\Common\\GlowBorder-Left", right = "Interface\\Common\\GlowBorder-Left",
}

function Modern.GlowBorder(handle)
    local r, g, b, a = handle:GetColor()
    for key, edge in pairs(handle.parts.edges) do
        edge:SetTexture(GLOW_TEXTURES[key])
        edge:SetBlendMode("ADD")
        edge:SetDesaturated(true)
        edge:SetVertexColor(r, g, b, a * handle.alpha)
        edge:Show()
    end
end

function Modern.GlowBorderLayout(handle)
    local frame, edges = handle.target, handle.parts.edges
    for _, corner in ipairs({ "topLeft", "topRight", "bottomLeft", "bottomRight" }) do
        edges[corner]:SetSize(16, 16)
    end
    edges.topLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    edges.topRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    edges.bottomLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    edges.bottomRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    edges.topRight:SetTexCoord(1, 0, 0, 1)
    edges.bottomLeft:SetTexCoord(0, 1, 1, 0)
    edges.bottomRight:SetTexCoord(1, 0, 1, 0)
    edges.top:SetPoint("TOPLEFT", edges.topLeft, "TOPRIGHT", 0, 0)
    edges.top:SetPoint("BOTTOMRIGHT", edges.topRight, "BOTTOMLEFT", 0, 0)
    edges.bottom:SetPoint("TOPLEFT", edges.bottomLeft, "TOPRIGHT", 0, 0)
    edges.bottom:SetPoint("BOTTOMRIGHT", edges.bottomRight, "BOTTOMLEFT", 0, 0)
    edges.bottom:SetTexCoord(0, 1, 1, 0)
    edges.left:SetPoint("TOPLEFT", edges.topLeft, "BOTTOMLEFT", 0, 0)
    edges.left:SetPoint("BOTTOMRIGHT", edges.bottomLeft, "TOPRIGHT", 0, 0)
    edges.right:SetPoint("TOPLEFT", edges.topRight, "BOTTOMLEFT", 0, 0)
    edges.right:SetPoint("BOTTOMRIGHT", edges.bottomRight, "TOPRIGHT", 0, 0)
    edges.right:SetTexCoord(1, 0, 0, 1)
end

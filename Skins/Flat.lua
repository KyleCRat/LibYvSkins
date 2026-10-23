local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or lib._modules.Flat == MINOR
then
    return
end

lib._modules.Flat = MINOR

local Flat = lib._skins.flat or {}
lib._skins.flat = Flat
local TEXT_OFFSET_Y = -1
local SCROLL_TRACK_INSET = 15
local CHECKMARK_OFFSET_PIXELS = 1

Flat.WindowMetrics = {
    padding = {
        left = 8,
        right = 8,
        top = 8,
        bottom = 8,
    },
    bodyPadding = {
        left = 2,
        right = 2,
        top = 2,
        bottom = 2,
    },
    titleBarHeight = 24,
}

function Flat.WindowLayout(handle)
    local frame = handle.target
    frame.TitleContainer:ClearAllPoints()
    frame.TitleContainer:SetPoint("TOPLEFT", frame.titleBar, "TOPLEFT", 4, 0)
    local right = handle.layout.closeButton == "titleBar"
            and handle.layout.titleBar.height + 4
        or 4
    frame.TitleContainer:SetPoint(
        "BOTTOMRIGHT",
        frame.titleBar,
        "BOTTOMRIGHT",
        -right,
        0
    )

    if handle.layout.closeButton == "titleBar" then
        frame.CloseButton:ClearAllPoints()
        frame.CloseButton:SetSize(
            handle.layout.titleBar.height,
            handle.layout.titleBar.height
        )
        frame.CloseButton:SetPoint("RIGHT", frame.titleBar, "RIGHT", 0, 0)
    end

    frame.resizeButton:ClearAllPoints()
    frame.resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
end

-- Neutral framing follows the RaidGroupManager flat palette. Accent is per
-- context; item rarity, money, binding, and other semantic colors stay intact.
local function Paint(surface, background, border, alpha)
    if surface.background then
        surface.background:SetVertexColor(
            background,
            background,
            background,
            alpha or 0.95
        )
    end

    surface.border:SetColor(border, border, border, 1)
end

local function State(handle, surface)
    local enabled = handle.target:IsEnabled()
    local background = not enabled and 0.07
        or (handle.pressed and 0.06 or (handle.hovered and 0.18 or 0.10))

    if enabled and handle.selected then background = 0.12 end

    Paint(
        surface,
        background,
        not enabled and 0.25 or (handle.hovered and 0.7 or 0.45)
    )

    if enabled and handle.selected then
        surface.border:SetColor(handle.context:GetColor(handle.colorToken))
    end
end

local function HideButtonArt(parts)
    parts.normal:SetAlpha(0)

    if parts.hover then parts.hover:SetAlpha(0) end

    parts.pressed:SetAlpha(0)
    parts.disabled:SetAlpha(0)
end

function Flat.Button(handle)
    if handle.parts.headerTab then
        for _, slices in pairs(handle.parts.headerTab) do
            for _, texture in ipairs(slices) do
                texture:Hide()
            end
        end
    else
        HideButtonArt(handle.parts)
    end

    handle.parts.label:ClearAllPoints()
    handle.parts.label:SetPoint(
        "CENTER",
        handle.target,
        "CENTER",
        0,
        handle.labelOffsetY + TEXT_OFFSET_Y
    )

    if handle.parts.checked then
        -- Keep Blizzard's checkmark dimensions; its optical offset is separate.
        handle.parts.checked:SetDesaturated(true)
        handle.parts.checked:SetVertexColor(
            handle.context:GetColor(handle.colorToken)
        )
        handle.parts.disabledChecked:SetDesaturated(true)
        handle.parts.disabledChecked:SetVertexColor(0.5, 0.5, 0.5)
    end

    handle:RefreshState()
end

function Flat.ButtonState(handle)
    local enabled = handle.target:IsEnabled()
    State(handle, handle.parts.surface)
    local icon = handle.parts.icon

    if icon then
        icon:SetDesaturated(not enabled or not handle.preserveIconColor)

        if handle.preserveIconColor then
            icon:SetVertexColor(1, 1, 1, 1)
        else
            icon:SetVertexColor(handle.context:GetColor(handle.colorToken))
        end
    end

    if enabled and handle.selected then
        handle.parts.label:SetTextColor(
            handle.context:GetColor(handle.colorToken)
        )
    else
        local c = enabled and 0.92 or 0.5
        handle.parts.label:SetTextColor(c, c, c, 1)
    end
end

function Flat.ButtonIconLayout(handle)
    if handle.parts.icon then
        local offset = handle.pressIcon
                and handle.pressed
                and handle.target:IsEnabled()
                and not handle.selected
                and 1
            or 0
        lib._LayoutCenteredIcon(handle, offset, -offset)
    end

    if handle.parts.checked then
        local y = 2
            - lib.Pixel.GetPhysicalSize(
                handle.parts.checked,
                CHECKMARK_OFFSET_PIXELS
            )
        handle.parts.checked:SetPoint("CENTER", handle.target, "CENTER", 2, y)
        handle.parts.disabledChecked:SetPoint(
            "CENTER",
            handle.target,
            "CENTER",
            2,
            y
        )
    end
end

function Flat.EditBox(handle)
    handle.parts.background:SetAlpha(0)

    if handle.parts.focus then handle.parts.focus:Hide() end

    local edit = handle.target
    local insets = handle.textInsets
    local textOffsetY = handle.parts.instructions and 0 or TEXT_OFFSET_Y
    edit:SetTextInsets(
        insets[1],
        insets[2],
        insets[3] - textOffsetY * 2,
        insets[4]
    )

    if handle.parts.instructions then
        handle.parts.instructions:ClearAllPoints()
        handle.parts.instructions:SetPoint(
            "TOPLEFT",
            edit,
            "TOPLEFT",
            insets[1],
            textOffsetY
        )
        handle.parts.instructions:SetPoint(
            "BOTTOMRIGHT",
            edit,
            "BOTTOMRIGHT",
            -insets[2],
            textOffsetY
        )
        handle.parts.clearButton:SetPoint("RIGHT", edit, "RIGHT", -4, 0)
        handle.parts.clearButton.Icon:SetTexture(lib._media.close)
        handle.parts.clearButton.Icon:SetVertexColor(
            handle.context:GetColor(handle.colorToken)
        )
    end

    Paint(
        handle.parts.surface,
        edit:IsEnabled() and 0.14 or 0.07,
        edit:IsEnabled() and 0.45 or 0.25
    )

    if edit:IsEnabled() and edit:HasFocus() then
        handle.parts.surface.border:SetColor(
            handle.context:GetColor(handle.colorToken)
        )
    end
end

function Flat.ExpandableHeader(handle)
    HideButtonArt(handle.parts)
    State(handle, handle.parts.surface)
    handle.parts.arrow:SetTexture(
        handle.expanded and lib._media.caretDown or lib._media.caretUp
    )
    handle.parts.arrow:SetTexCoord(0, 1, 0, 1)
    handle.parts.arrow:SetRotation(0)
    handle.parts.arrow:ClearAllPoints()
    handle.parts.arrow:SetPoint("RIGHT", handle.target, "RIGHT", -12, 0)
    handle.parts.arrow:SetDesaturated(true)
    handle.parts.arrow:SetVertexColor(
        handle.context:GetColor(handle.colorToken)
    )
end

function Flat.Window(handle)
    local frame = handle.target

    for _, region in ipairs(handle.parts.chrome) do
        region:SetAlpha(0)
    end

    if handle.layout.portrait then frame.PortraitContainer:SetAlpha(1) end

    frame.TopTileStreaks:SetAlpha(0)
    Paint(handle.parts.surface, 0.05, 0, 0.95)
    Paint(handle.parts.bodySurface, 0.035, 0.3, 0.95)
end

function Flat.Icon(handle)
    if handle.alphaOwned then handle.target:SetAlpha(handle.alpha) end

    if handle.crop then handle.target:SetTexCoord(0.08, 0.92, 0.08, 0.92) end

    handle.parts.border:Hide()
    Flat.IconState(handle)
    Flat.IconColor(handle)
    Flat.IconVisibility(handle)
end

function Flat.IconState(handle)
    if handle.actionIcon then
        handle.target:SetDesaturated(true)
        handle.target:SetVertexColor(handle.context:GetColor(handle.colorToken))
    end
end

function Flat.IconColor(handle)
    handle.parts.flatBorder:SetColor(
        handle.r,
        handle.g,
        handle.b,
        handle.a * handle.borderAlpha * handle.alpha
    )
end

function Flat.IconVisibility(handle)
    if handle.borderShown and handle.target:IsVisible() then
        -- Preserve the outer footprint and outside-art inset at small
        -- effective scales so pixel rounding cannot place the stroke over
        -- the image.
        local outset = math.max(
            handle.borderOutset,
            handle.root.metrics.unit * 3
        ) - handle.artworkOutset
        handle.parts.flatBorder:Layout(
            handle.root.metrics,
            1,
            handle.clip,
            outset
        )
    else
        handle.parts.flatBorder:Hide()
    end
end

Flat.IconLayout = Flat.IconVisibility

function Flat.Texture(handle)
    lib._ApplyTextureAppearance(handle)
end

function Flat.Text(handle)
    lib._ApplyTextAppearance(handle)
end

function Flat.GlowBorder(handle)
    for _, edge in pairs(handle.parts.edges) do
        edge:Hide()
    end

    local r, g, b, a = handle:GetColor()
    handle.parts.surface.border:SetColor(r, g, b, a * handle.alpha)
end

function Flat.GlowBorderLayout(_handle) end

function Flat.NativeButton(handle)
    for _, state in ipairs(handle.parts.states) do
        state.region:SetAlpha(0)
    end

    local icon = handle.parts.icon

    if handle.kind == "close" then
        icon:SetTexture(lib._media.close)
        icon:SetTexCoord(0, 1, 0, 1)
    else
        -- Keep Blizzard's resize glyph, but no surrounding native button art.
        local state = handle.parts.states[1]

        if state then
            if state.atlas then
                icon:SetAtlas(state.atlas, false)
            else
                icon:SetTexture(state.texture)
            end

            icon:SetTexCoord(unpack(state.coordinates))
        end
    end

    icon:SetDesaturated(true)
    icon:SetVertexColor(handle.context:GetColor(handle.colorToken))
    icon:SetAlpha(handle.target:IsEnabled() and 1 or 0.5)
    icon:Show()
    Flat.NativeButtonLayout(handle)

    if handle.kind ~= "resize" then State(handle, handle.parts.surface) end
end

function Flat.NativeButtonLayout(handle)
    if handle.kind == "close" then
        lib._LayoutCenteredIcon(handle)
    else
        lib._RestoreIconLayout(handle)
        handle.parts.icon:SetPoint("CENTER", handle.target, "CENTER", 0, 0)
    end
end

function Flat.ScrollBar(handle)
    local parts = handle.parts

    if handle.layoutSkin ~= "flat" then
        handle.layoutSkin = "flat"
        handle:LayoutAnchor(true)
        parts.track:ClearAllPoints()
        parts.track:SetPoint(
            "TOP",
            handle.target,
            "TOP",
            0,
            -SCROLL_TRACK_INSET
        )
        parts.track:SetPoint(
            "BOTTOM",
            handle.target,
            "BOTTOM",
            0,
            SCROLL_TRACK_INSET
        )
    end

    for _, region in ipairs({
        parts.track.Begin,
        parts.track.Middle,
        parts.track.End,
        parts.thumb.Begin,
        parts.thumb.Middle,
        parts.thumb.End,
    }) do
        region:SetAlpha(0)
    end

    Paint(parts.trackSurface, 0.04, 0.12)
    Paint(
        parts.thumbSurface,
        parts.thumb.down and 0.4 or (parts.thumb.over and 0.55 or 0.3),
        0.1
    )

    for index, button in ipairs({ parts.back, parts.forward }) do
        button.Texture:SetTexture(
            index == 1 and lib._media.caretUp or lib._media.caretDown
        )
        button.Texture:SetTexCoord(0, 1, 0, 1)
        button.Texture:SetSize(12, 12)
        -- Change the resting anchor only; Blizzard owns pressed-point offsets.
        if handle.stepperLayoutSkin ~= "flat" then
            button.Texture:ClearAllPoints()
            button.Texture:SetPoint("CENTER", button, "CENTER", 0, 0)
        end

        button.Texture:SetRotation(0)
        button.Texture:SetDesaturated(true)
        local r, g, b, a = handle.context:GetColor(handle.colorToken)
        button.Texture:SetVertexColor(
            r,
            g,
            b,
            a * (button:IsEnabled() and (button.over and 1 or 0.7) or 0.3)
        )
    end

    handle.stepperLayoutSkin = "flat"
end

function Flat.ScrollThumbSize(handle)
    lib._LayoutSurfaces(handle)
end

function Flat.PopupSlider(handle)
    local popup, parts = handle.target, handle.parts.visuals
    popup:SetBackdrop(nil)
    Paint(handle.parts.surface, 0.05, 0)
    parts.track:SetColorTexture(0.3, 0.3, 0.3, 1)

    for _, marker in ipairs(parts.markers) do
        marker:SetColorTexture(0.6, 0.6, 0.6, 1)
    end

    parts.thumb:SetColorTexture(handle.context:GetColor("accent"))
    parts.thumb:SetVertexColor(1, 1, 1, 1)
end

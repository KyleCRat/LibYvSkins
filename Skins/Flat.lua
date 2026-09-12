local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)
if not lib or lib._implementationMinor ~= MINOR or lib._modules.Flat == MINOR then
    return
end
lib._modules.Flat = MINOR

local Flat = lib._skins.flat or {}
lib._skins.flat = Flat
local Modern = lib._skins.modern

-- Neutral framing follows the RaidGroupManager flat palette. Accent is per
-- context; item rarity, money, binding, and other semantic colors stay intact.
local function Paint(surface, background, border, alpha)
    if surface.background then surface.background:SetVertexColor(background, background, background, alpha or 0.95) end
    surface.border:SetColor(border, border, border, 1)
end

local function State(handle, surface)
    local enabled = handle.target:IsEnabled()
    local background = not enabled and 0.07 or (handle.pressed and 0.06 or (handle.hovered and 0.18 or 0.10))
    if enabled and handle.selected then background = 0.12 end
    Paint(surface, background, not enabled and 0.25 or (handle.hovered and 0.7 or 0.45))
    if enabled and handle.selected then surface.border:SetColor(handle.context:GetColor(handle.colorToken)) end
end

local function HideButtonArt(parts)
    parts.normal:SetAlpha(0)
    if parts.hover then parts.hover:SetAlpha(0) end
    parts.pressed:SetAlpha(0)
    parts.disabled:SetAlpha(0)
end

function Flat.Button(handle)
    Modern.Button(handle)
    HideButtonArt(handle.parts)
    if handle.parts.checked then
        for _, checkmark in ipairs({ handle.parts.checked, handle.parts.disabledChecked }) do
            checkmark:SetScale(1)
            checkmark:SetSize(16, 16)
            checkmark:ClearAllPoints()
            checkmark:SetPoint("CENTER", handle.target, "CENTER", 0, 0)
        end
        handle.parts.checked:SetDesaturated(true)
        handle.parts.checked:SetVertexColor(handle.context:GetColor(handle.colorToken))
    end
    Flat.ButtonState(handle)
end

function Flat.ButtonState(handle)
    Modern.ButtonState(handle)
    State(handle, handle.parts.surface)
    if handle.target:IsEnabled() and handle.selected then
        handle.parts.label:SetTextColor(handle.context:GetColor(handle.colorToken))
    else
        local c = handle.target:IsEnabled() and 0.92 or 0.5
        handle.parts.label:SetTextColor(c, c, c, 1)
    end
end

function Flat.EditBox(handle)
    Modern.EditBox(handle)
    handle.parts.background:SetAlpha(0)
    if handle.parts.focus then handle.parts.focus:Hide() end
    local edit = handle.target
    Paint(handle.parts.surface, edit:IsEnabled() and 0.14 or 0.07, edit:IsEnabled() and 0.45 or 0.25)
    if edit:IsEnabled() and edit:HasFocus() then
        handle.parts.surface.border:SetColor(handle.context:GetColor(handle.colorToken))
    end
end

function Flat.ExpandableHeader(handle)
    Modern.ExpandableHeader(handle)
    HideButtonArt(handle.parts)
    State(handle, handle.parts.surface)
    handle.parts.arrow:SetDesaturated(true)
    handle.parts.arrow:SetVertexColor(handle.context:GetColor(handle.colorToken))
end

function Flat.Window(handle)
    local frame = handle.target
    for _, region in ipairs(handle.parts.chrome) do region:SetAlpha(0) end
    frame.TopTileStreaks:SetAlpha(0)
    Paint(handle.parts.surface, 0.05, 0, 0.95)
end

function Flat.Icon(handle)
    if handle.alphaOwned then handle.target:SetAlpha(handle.alpha) end
    if handle.crop then handle.target:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    handle.parts.border:Hide()
    Flat.IconColor(handle)
    Flat.IconVisibility(handle)
end

function Flat.IconColor(handle)
    handle.parts.flatBorder:SetColor(handle.r, handle.g, handle.b, handle.a * handle.borderAlpha * handle.alpha)
end

function Flat.IconVisibility(handle)
    if handle.borderShown and handle.target:IsVisible() then
        handle.parts.flatBorder:Layout(handle.root.metrics, 2, handle.clip)
    else
        handle.parts.flatBorder:Hide()
    end
end

Flat.IconLayout = Flat.IconVisibility
Flat.Texture = Modern.Texture
Flat.Text = Modern.Text

function Flat.GlowBorder(handle)
    for _, edge in pairs(handle.parts.edges) do edge:Hide() end
    local r, g, b, a = handle:GetColor()
    handle.parts.surface.border:SetColor(r, g, b, a * handle.alpha)
end

function Flat.GlowBorderLayout(handle)
end

function Flat.NativeButton(handle)
    for _, state in ipairs(handle.parts.states) do state.region:SetAlpha(0) end
    local icon = handle.parts.icon
    if handle.kind == "close" then
        icon:SetAtlas("common-icon-redx", false)
    else
        -- Keep Blizzard's resize glyph, but no surrounding native button art.
        local state = handle.parts.states[1]
        if state then
            if state.atlas then icon:SetAtlas(state.atlas, false) else icon:SetTexture(state.texture) end
            icon:SetTexCoord(unpack(state.coordinates))
        end
        icon:SetDesaturated(true)
    end
    icon:SetAlpha(handle.target:IsEnabled() and 1 or 0.5)
    icon:Show()
    State(handle, handle.parts.surface)
end

function Flat.ScrollBar(handle)
    local parts = handle.parts
    for _, region in ipairs({ parts.track.Begin, parts.track.Middle, parts.track.End,
        parts.thumb.Begin, parts.thumb.Middle, parts.thumb.End }) do region:SetAlpha(0) end
    Paint(parts.trackSurface, 0.04, 0.12)
    Paint(parts.thumbSurface, parts.thumb.down and 0.4 or (parts.thumb.over and 0.55 or 0.3), 0.1)
    for index, button in ipairs({ parts.back, parts.forward }) do
        button.Texture:SetAtlas("common-dropdown-icon-next", false)
        button.Texture:SetSize(12, 12)
        button.Texture:SetRotation(index == 1 and math.pi * 0.5 or math.pi * 1.5)
        button.Texture:SetDesaturated(true)
        local c = button:IsEnabled() and (button.over and 1 or 0.7) or 0.3
        button.Texture:SetVertexColor(c, c, c, 1)
    end
end

function Flat.ScrollThumbSize(handle)
    lib._LayoutSurfaces(handle)
end

function Flat.PopupSlider(handle)
    local popup, parts = handle.target, handle.parts.visuals
    popup:SetBackdrop(nil)
    Paint(handle.parts.surface, 0.05, 0)
    parts.track:SetColorTexture(0.3, 0.3, 0.3, 1)
    for _, marker in ipairs(parts.markers) do marker:SetColorTexture(0.6, 0.6, 0.6, 1) end
    parts.thumb:SetColorTexture(handle.context:GetColor("accent"))
    parts.thumb:SetVertexColor(1, 1, 1, 1)
end

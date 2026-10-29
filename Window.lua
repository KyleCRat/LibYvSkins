local MAJOR, MINOR = "LibYvSkins-1.0", 2
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or lib._modules.Window == MINOR
then
    return
end

lib._modules.Window = MINOR

local Context = lib._contextPrototype

local DEFAULT_INSET_BACKGROUND =
    "Interface\\FrameGeneral\\UIFrameMidnightBackground"
local EDGES = { "left", "right", "top", "bottom" }

-- Layout is consumer-owned data. Skins supply only default measurements.
local function Number(value, fallback, nonnegative)
    if value == nil then return fallback end

    assert(
        type(value) == "number"
            and value == value
            and math.abs(value) < math.huge,
        "layout measurements must be finite numbers"
    )
    assert(
        not nonnegative or value >= 0,
        "layout sizes and padding must be nonnegative"
    )
    return value
end

local function Edges(value, defaults, nonnegative)
    assert(
        value == nil or type(value) == "number" or type(value) == "table",
        "edges require a number or table"
    )
    local result = {}

    for _, edge in ipairs(EDGES) do
        local amount = value

        if type(value) == "table" then amount = value[edge] end

        result[edge] =
            Number(amount, defaults and defaults[edge] or 0, nonnegative)
    end

    return result
end

local function Section(value, defaultHeight)
    assert(
        value == nil or value == false or type(value) == "table",
        "sections require a table or false"
    )
    value = value or {}
    return {
        height = Number(value.height, defaultHeight or 0, true),
        gap = Number(value.gap, 0, true),
        margin = Edges(value.margin),
    }
end

local function ResolveLayout(spec, skin)
    assert(type(spec) == "table", "window layout must be a table")
    local metrics = lib._skins[skin].WindowMetrics
    local header, footer = Section(spec.header), Section(spec.footer)
    local titleBar =
        Section(spec.titleBar, spec.titleBar and metrics.titleBarHeight or 0)
    assert(
        header.height
            >= titleBar.height
                + titleBar.margin.top
                + titleBar.margin.bottom,
        "Header height must include its Title Bar"
    )
    local padding = Edges(spec.padding, metrics.padding, true)

    if titleBar.height > 0 and metrics.titleBarAtWindowEdge then
        -- Native title artwork stays at the outer edge even when content has
        -- padding. Keep the declared Header allocation and honor explicit margins.
        titleBar.margin = Edges(spec.titleBar.margin, {
            left = -padding.left - header.margin.left,
            right = -padding.right - header.margin.right,
            top = -padding.top - header.margin.top,
        })
    end

    local body = spec.body or {}
    assert(type(body) == "table", "Body layout must be a table")
    local close = spec.closeButton

    if close == nil then close = titleBar.height > 0 and "titleBar" or false end

    assert(
        close == false or close == "titleBar" or close == "manual",
        "invalid Close button placement"
    )
    assert(
        close ~= "titleBar" or titleBar.height > 0,
        "Close placement requires a Title Bar"
    )
    assert(
        spec.portrait == nil or type(spec.portrait) == "boolean",
        "portrait visibility must be boolean"
    )
    return {
        padding = padding,
        header = header,
        footer = footer,
        titleBar = titleBar,
        body = {
            padding = Edges(body.padding, metrics.bodyPadding, true),
            margin = Edges(body.margin),
        },
        closeButton = close,
        portrait = spec.portrait == true,
    }
end

local function SectionExtent(section)
    if section.height == 0 then return 0 end

    return section.height
        + section.margin.top
        + section.margin.bottom
        + section.gap
end

local function BodyInsets(layout)
    local outer, body = layout.padding, layout.body
    return outer.left + body.margin.left + body.padding.left,
        outer.right + body.margin.right + body.padding.right,
        outer.top
            + SectionExtent(layout.header)
            + body.margin.top
            + body.padding.top,
        outer.bottom
            + SectionExtent(layout.footer)
            + body.margin.bottom
            + body.padding.bottom
end

local definition = lib._roles.window or {}
lib._roles.window = definition

function definition.Validate(target, _parts, _options)
    assert(
        target and target.Inset and target.TopTileStreaks,
        "window role requires a library window"
    )
end

function definition.Initialize(handle, options)
    lib._InitializeControl(handle, options)
    handle.insetBackground = options.insetBackground or DEFAULT_INSET_BACKGROUND
    handle.minWidth = options.minWidth
    handle.onLayout, handle.getMinimumWidth =
        options.onLayout, options.getMinimumWidth
    handle.movable, handle.resizable =
        options.movable ~= false, options.resizable ~= false
    handle.layouts = {}

    for skin in pairs(lib._skins) do
        handle.layouts[skin] = ResolveLayout(
            options.layouts and options.layouts[skin] or options.layout or {},
            skin
        )
    end

    local frame = handle.target
    handle.parts.surface = lib._CreateSurface(handle, frame, frame)
    handle.parts.bodySurface =
        lib._CreateSurface(handle, frame.Inset, frame.Inset)
    handle.parts.chrome = {
        frame.Bg,
        frame.NineSlice,
        frame.Inset.Bg,
        frame.Inset.NineSlice,
        frame.PortraitContainer,
    }
    handle.chromeAlpha = {}

    for index, region in ipairs(handle.parts.chrome) do
        handle.chromeAlpha[index] = region:GetAlpha()
    end

    handle.closePoints = {}

    for index = 1, frame.CloseButton:GetNumPoints() do
        handle.closePoints[index] = { frame.CloseButton:GetPoint(index) }
    end

    handle.closeWidth, handle.closeHeight = frame.CloseButton:GetSize()
    handle.titlePoints = {}

    for index = 1, frame.TitleContainer:GetNumPoints() do
        handle.titlePoints[index] = { frame.TitleContainer:GetPoint(index) }
    end

    handle.titleHeight = frame.TitleContainer:GetHeight()
end

function definition.ApplyAppearance(handle)
    handle.context:_LayoutWindow(handle)
    handle.context:_GetRenderer().Window(handle)
end

function definition.Layout(_handle) end

function Context:GetWindowBodyWidthOverhead(frame)
    if frame then
        local left, right = BodyInsets(self._components[frame].layout)
        return left + right
    end

    local metrics = self:_GetRenderer().WindowMetrics
    return metrics.padding.left
        + metrics.padding.right
        + metrics.bodyPadding.left
        + metrics.bodyPadding.right
end

function Context:GetWindowBodyReserve(frame)
    local handle = self._components[frame]
    local _, _, top, bottom = BodyInsets(handle.layout)
    local minimum = top + bottom

    for _, layout in pairs(handle.layouts) do
        local _, _, candidateTop, candidateBottom = BodyInsets(layout)
        minimum = math.min(minimum, candidateTop + candidateBottom)
    end

    return top + bottom - minimum
end

function Context:GetWindowMinimumWidth(frame)
    local handle = self._components[frame]
    local width = handle.getMinimumWidth and handle.getMinimumWidth(frame) or 0
    return math.max(handle.minWidth, width)
end

function Context:SetWindowLayout(frame, layout, skin)
    local handle =
        assert(self._components[frame], "window must belong to this context")
    assert(handle.role == "window", "layout requires a window")
    assert(
        not InCombatLockdown()
            and not handle.moving
            and not frame.resizeButton:IsActive(),
        "window layout cannot change during combat or a window drag"
    )
    assert(skin == nil or lib._skins[skin], "unknown layout skin")
    local resolved = {}

    for id in pairs(lib._skins) do
        if not skin or skin == id then
            resolved[id] = ResolveLayout(layout, id)
        end
    end

    for id, value in pairs(resolved) do
        handle.layouts[id] = value
    end

    self:_LayoutWindow(handle)
    handle:RefreshAppearance()
    self:RefreshGeometry(frame)
end

function Context:_LayoutWindow(handle)
    local frame = handle.target
    local skin = self:GetAppliedSkin()
    local layout = handle.layouts[skin]

    if handle.layout == layout then return end

    handle.layout = layout
    local padding, header, footer, body =
        layout.padding, layout.header, layout.footer, layout.body

    frame.header:ClearAllPoints()
    frame.header:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        padding.left + header.margin.left,
        -padding.top - header.margin.top
    )
    frame.header:SetPoint(
        "TOPRIGHT",
        frame,
        "TOPRIGHT",
        -padding.right - header.margin.right,
        -padding.top - header.margin.top
    )
    frame.header:SetHeight(header.height)
    frame.header:SetShown(header.height > 0)

    frame.footer:ClearAllPoints()
    frame.footer:SetPoint(
        "BOTTOMLEFT",
        frame,
        "BOTTOMLEFT",
        padding.left + footer.margin.left,
        padding.bottom + footer.margin.bottom
    )
    frame.footer:SetPoint(
        "BOTTOMRIGHT",
        frame,
        "BOTTOMRIGHT",
        -padding.right - footer.margin.right,
        padding.bottom + footer.margin.bottom
    )
    frame.footer:SetHeight(footer.height)
    frame.footer:SetShown(footer.height > 0)

    frame.Inset:ClearAllPoints()
    frame.Inset:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        padding.left + body.margin.left,
        -padding.top - SectionExtent(header) - body.margin.top
    )
    frame.Inset:SetPoint(
        "BOTTOMRIGHT",
        frame,
        "BOTTOMRIGHT",
        -padding.right - body.margin.right,
        padding.bottom + SectionExtent(footer) + body.margin.bottom
    )
    frame.body:ClearAllPoints()
    frame.body:SetPoint(
        "TOPLEFT",
        frame.Inset,
        "TOPLEFT",
        body.padding.left,
        -body.padding.top
    )
    frame.body:SetPoint(
        "BOTTOMRIGHT",
        frame.Inset,
        "BOTTOMRIGHT",
        -body.padding.right,
        body.padding.bottom
    )

    local title = layout.titleBar
    frame.titleBar:ClearAllPoints()
    frame.titleBar:SetPoint(
        "TOPLEFT",
        frame.header,
        "TOPLEFT",
        title.margin.left,
        -title.margin.top
    )
    frame.titleBar:SetPoint(
        "TOPRIGHT",
        frame.header,
        "TOPRIGHT",
        -title.margin.right,
        -title.margin.top
    )
    frame.titleBar:SetHeight(title.height)
    frame.titleBar:SetShown(title.height > 0)
    frame.TitleContainer:SetShown(title.height > 0)
    frame.CloseButton:SetShown(layout.closeButton ~= false)
    frame.PortraitContainer:SetShown(layout.portrait)
    frame.resizeButton:SetShown(handle.resizable)
    -- Native art-specific title/close/grip offsets are renderer-owned, not a
    -- toolbar policy. Manual Close placement remains entirely consumer-owned.
    self:_GetRenderer().WindowLayout(handle)

    if handle.onLayout then handle.onLayout(frame) end
end

-- Register only non-action backgrounds. Child buttons retain their own native
-- hit areas and drag handlers; there is no click-through overlay or polling.
function Context:RegisterWindowDragRegion(frame, region)
    local handle =
        assert(self._components[frame], "window must belong to this context")
    assert(
        handle.role == "window" and handle.startMove,
        "window must be initialized before registering drag regions"
    )
    assert(
        region and type(region.RegisterForDrag) == "function",
        "drag region must be a frame"
    )

    if handle.dragRegions[region] then return end

    assert(
        not region:GetScript("OnDragStart")
            and not region:GetScript("OnDragStop"),
        "drag region already owns a drag action"
    )
    handle.dragRegions[region] = true
    region:EnableMouse(true)
    region:RegisterForDrag("LeftButton")
    region:HookScript("OnDragStart", handle.startMove)
    region:HookScript("OnDragStop", handle.stopMove)
end

local function ValidateOptions(parent, options)
    assert(
        parent and type(parent.GetEffectiveScale) == "function",
        "window parent must be a frame"
    )
    assert(type(options) == "table", "window options must be a table")
    assert(
        options.name == nil
            or (type(options.name) == "string" and options.name ~= ""),
        "window name must be a non-empty string"
    )
    assert(
        options.title == nil or type(options.title) == "string",
        "window title must be a string"
    )
    assert(
        options.compactHeader == nil,
        "use explicit window layouts instead of compactHeader"
    )

    for _, key in ipairs({ "minWidth", "minHeight" }) do
        assert(
            type(options[key]) == "number" and options[key] > 0,
            "windows require positive minimum dimensions"
        )
    end

    assert(
        options.maxWidth == nil
            or (
                type(options.maxWidth) == "number"
                and options.maxWidth >= options.minWidth
            ),
        "window maxWidth must be at least minWidth"
    )
    assert(
        options.maxHeight == nil
            or (
                type(options.maxHeight) == "number"
                and options.maxHeight >= options.minHeight
            ),
        "window maxHeight must be at least minHeight"
    )

    for _, key in ipairs({
        "onMoveStopped",
        "onResizeStopped",
        "onLayout",
        "getMinimumWidth",
    }) do
        assert(
            options[key] == nil or type(options[key]) == "function",
            "window callbacks must be functions"
        )
    end

    for _, key in ipairs({ "movable", "resizable" }) do
        assert(
            options[key] == nil or type(options[key]) == "boolean",
            "window behavior options must be boolean"
        )
    end

    assert(
        options.layouts == nil or type(options.layouts) == "table",
        "layouts must be a table"
    )
    assert(
        options.layout == nil or type(options.layout) == "table",
        "layout must be a table"
    )

    for skin, layout in pairs(options.layouts or {}) do
        assert(lib._skins[skin], "unknown layout skin")
        assert(type(layout) == "table", "window layout must be a table")
    end

    for skin in pairs(lib._skins) do
        ResolveLayout(
            options.layouts and options.layouts[skin] or options.layout or {},
            skin
        )
    end
end

function Context:CreateWindow(parent, options)
    ValidateOptions(parent, options)
    local frame =
        CreateFrame("Frame", options.name, parent, "ButtonFrameTemplate")
    frame:Hide()
    frame:SetFrameStrata(options.strata or "HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(options.movable ~= false)
    frame:EnableMouse(true)
    frame:SetResizable(options.resizable ~= false)
    frame:SetResizeBounds(
        options.minWidth,
        options.minHeight,
        options.maxWidth,
        options.maxHeight
    )
    frame:SetSize(options.minWidth, options.minHeight)
    frame:SetTitle(options.title or "")

    if options.portrait then
        frame:SetPortraitToAsset(options.portrait)
        frame:SetPortraitTexCoord(0, 1, 0, 1)
    end

    frame.header = CreateFrame("Frame", nil, frame)
    frame.titleBar = CreateFrame("Frame", nil, frame.header)
    frame.body = CreateFrame("Frame", nil, frame)
    frame.footer = CreateFrame("Frame", nil, frame)
    frame.TitleContainer:SetParent(frame.titleBar)
    -- Reparenting resets the title's level below the native NineSlice. Restore
    -- Blizzard's chrome ordering relative to this window, including nested ones.
    frame:SetFrameLevelsFromBaseLevel(frame:GetFrameLevel())

    frame.resizeButton =
        CreateFrame("Button", nil, frame, "PanelResizeButtonTemplate")
    frame.resizeButton:Init(
        frame,
        options.minWidth,
        options.minHeight,
        options.maxWidth,
        options.maxHeight
    )

    local root = self:_GetGeometryRoot(frame)
    local handle =
        self:RegisterComponent("window", frame, { bounds = frame }, options)
    root.window = handle
    self:_LayoutWindow(handle)
    self:RegisterComponent(
        "nativeButton",
        frame.CloseButton,
        { bounds = frame },
        { geometryRoot = frame, kind = "close" }
    )
    self:RegisterComponent(
        "nativeButton",
        frame.resizeButton,
        { bounds = frame },
        { geometryRoot = frame, kind = "resize" }
    )

    local function RefreshGeometry()
        self:RefreshGeometry(frame)
    end

    frame:HookScript("OnShow", RefreshGeometry)
    frame:HookScript("OnSizeChanged", RefreshGeometry)
    frame.body:HookScript("OnShow", RefreshGeometry)
    frame.body:HookScript("OnSizeChanged", RefreshGeometry)

    local onMoveStopped, onResizeStopped =
        options.onMoveStopped, options.onResizeStopped

    local function StartMove()
        if not handle.movable or InCombatLockdown() or handle.moving then
            return
        end

        handle.moving = true
        frame:StartMoving()
    end

    local function StopMove()
        if not handle.moving then return end

        handle.moving = false
        frame:StopMovingOrSizing()

        if onMoveStopped then onMoveStopped(frame) end

        RefreshGeometry()
        self:RetryPendingSkin()
    end

    handle.startMove, handle.stopMove, handle.dragRegions =
        StartMove, StopMove, {}

    for _, drag in ipairs({
        frame,
        frame.titleBar,
        frame.TitleContainer,
        frame.header,
        frame.body,
        frame.footer,
        frame.Inset,
    }) do
        self:RegisterWindowDragRegion(frame, drag)
    end

    frame.resizeButton:SetOnResizeStoppedCallback(function()
        frame.resizeButton:UnregisterEvent("GLOBAL_MOUSE_UP")
        handle.resizeMouseButton = nil

        if onResizeStopped then onResizeStopped(frame) end

        RefreshGeometry()
        self:RetryPendingSkin()
    end)
    frame.resizeButton:HookScript("OnMouseDown", function(button, mouseButton)
        if button:IsActive() then
            handle.resizeSequence = (handle.resizeSequence or 0) + 1
            handle.resizeMouseButton = mouseButton
            button:RegisterEvent("GLOBAL_MOUSE_UP")
        end
    end)
    frame.resizeButton:HookScript(
        "OnEvent",
        function(button, event, mouseButton)
            if
                event ~= "GLOBAL_MOUSE_UP"
                or mouseButton ~= handle.resizeMouseButton
            then
                return
            end

            local sequence = handle.resizeSequence
            -- Let native mouse-up finish first; an outside release may not reach the grip.
            C_Timer.After(0, function()
                if button:IsActive() and handle.resizeSequence == sequence then
                    button:OnMouseUp()
                    local appearance = self._components[button]
                    appearance.pressed = false
                    appearance:RefreshAppearance()
                end
            end)
        end
    )
    frame:HookScript("OnHide", function()
        if handle.moving then StopMove() end

        if frame.resizeButton:IsActive() then frame.resizeButton:OnMouseUp() end
    end)
    return frame
end

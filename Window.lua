local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)
if not lib or lib._implementationMinor ~= MINOR or lib._modules.Window == MINOR then
    return
end
lib._modules.Window = MINOR

local Context = lib._contextPrototype

-- Modern chrome geometry. Content and footer interiors belong to the consumer.
local INSET_LEFT, INSET_RIGHT, INSET_TOP, INSET_BOTTOM = 4, -6, -60, 34
local CONTENT_LEFT, CONTENT_RIGHT, CONTENT_TOP, CONTENT_BOTTOM = 3, -3, -3, 2
local HEADER_LEFT, HEADER_RIGHT, HEADER_TOP, HEADER_HEIGHT = 58, -6, -28, 28
local FOOTER_LEFT, FOOTER_RIGHT, FOOTER_BOTTOM, FOOTER_HEIGHT = 3, -15, 4, 28
local RESIZE_RIGHT, RESIZE_BOTTOM = -2, 3
local COMPACT_HEADER_HEIGHT, CONTROL_SIZE, CONTROL_GAP = 36, 28, 2
local COMPACT_PADDING, SEARCH_MIN_WIDTH = 8, 96
local DEFAULT_INSET_BACKGROUND = "Interface\\FrameGeneral\\UIFrameMidnightBackground"

local definition = lib._roles.window or {}
lib._roles.window = definition

function definition.Validate(target, parts, options)
    assert(target and target.Inset and target.TopTileStreaks, "window role requires a library window")
end

function definition.Initialize(handle, options)
    lib._InitializeControl(handle, options)
    handle.insetBackground = options.insetBackground or DEFAULT_INSET_BACKGROUND
    handle.compactHeader = options.compactHeader == true
    handle.minWidth = options.minWidth
    local frame = handle.target
    handle.parts.surface = lib._CreateSurface(handle, frame, frame)
    handle.parts.chrome = {
        frame.Bg, frame.NineSlice, frame.Inset.Bg, frame.Inset.NineSlice, frame.PortraitContainer,
    }
    handle.chromeAlpha = {}
    for index, region in ipairs(handle.parts.chrome) do handle.chromeAlpha[index] = region:GetAlpha() end
    handle.closePoints = {}
    for index = 1, frame.CloseButton:GetNumPoints() do
        handle.closePoints[index] = { frame.CloseButton:GetPoint(index) }
    end
    handle.closeWidth, handle.closeHeight = frame.CloseButton:GetSize()
end

function definition.ApplyAppearance(handle)
    handle.context:_GetRenderer().Window(handle)
end

function definition.Layout(handle)
end

function Context:GetWindowChromeWidth()
    return INSET_LEFT - INSET_RIGHT + CONTENT_LEFT - CONTENT_RIGHT
end

function Context:IsWindowCompact(frame)
    local handle = self._components[frame]
    return handle.compactHeader and self:GetAppliedSkin() ~= "modern"
end

function Context:GetWindowContentReserve(frame)
    -- Prewarm the largest viewport, even when starting with Modern chrome.
    if self._components[frame].compactHeader and not self:IsWindowCompact(frame) then
        return -INSET_TOP - COMPACT_HEADER_HEIGHT
    end
    return 0
end

function Context:GetWindowMinimumWidth(frame)
    local handle = self._components[frame]
    local width = SEARCH_MIN_WIDTH
    for _, control in ipairs(handle.headerControls or {}) do
        if control:IsShown() then width = width + control:GetWidth() + CONTROL_GAP end
    end
    if self:IsWindowCompact(frame) then
        width = width + 2 * COMPACT_PADDING + CONTROL_SIZE + CONTROL_GAP
    else
        width = width + HEADER_LEFT - HEADER_RIGHT
    end
    return math.max(handle.minWidth, width)
end

function Context:SetHeaderControls(frame, controls, search)
    local handle = assert(self._components[frame], "window must belong to this context")
    assert(handle.role == "window" and type(controls) == "table" and search, "header requires controls and search")
    handle.headerControls, handle.search = controls, search
    self:LayoutHeader(frame)
end

function Context:LayoutHeader(frame)
    local handle = self._components[frame]
    if not handle.headerControls then return end
    local previous
    for _, control in ipairs(handle.headerControls) do
        if control:IsShown() then
            control:ClearAllPoints()
            if previous then
                control:SetPoint("LEFT", previous, "RIGHT", CONTROL_GAP, 0)
            else
                control:SetPoint("LEFT", frame.header, "LEFT", 0, 0)
            end
            previous = control
        end
    end
    local search = handle.search
    search:ClearAllPoints()
    if previous then
        search:SetPoint("TOPLEFT", previous, "TOPRIGHT", CONTROL_GAP, 0)
        search:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", CONTROL_GAP, 0)
    else
        search:SetPoint("TOPLEFT", frame.header, "TOPLEFT", 0, 0)
        search:SetHeight(CONTROL_SIZE)
    end
    if self:IsWindowCompact(frame) then
        search:SetPoint("RIGHT", frame.CloseButton, "LEFT", -CONTROL_GAP, 0)
    else
        search:SetPoint("RIGHT", frame.header, "RIGHT", 0, 0)
    end
end

function Context:_LayoutWindow(handle)
    local frame = handle.target
    local compact = self:IsWindowCompact(frame)
    if handle.layoutCompact == compact then return end
    handle.layoutCompact = compact
    frame.Inset:ClearAllPoints()
    frame.Inset:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET_LEFT, compact and -COMPACT_HEADER_HEIGHT or INSET_TOP)
    frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)
    frame.header:ClearAllPoints()
    frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", compact and COMPACT_PADDING or HEADER_LEFT,
        compact and -(COMPACT_HEADER_HEIGHT - CONTROL_SIZE) / 2 or HEADER_TOP)
    frame.header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", compact and -COMPACT_PADDING or HEADER_RIGHT,
        compact and -(COMPACT_HEADER_HEIGHT - CONTROL_SIZE) / 2 or HEADER_TOP)
    frame.header:SetHeight(CONTROL_SIZE)
    frame.TitleContainer:SetShown(not compact)
    frame.headerDrag:SetShown(compact)
    local close = frame.CloseButton
    close:ClearAllPoints()
    if compact then
        close:SetSize(CONTROL_SIZE, CONTROL_SIZE)
        close:SetPoint("RIGHT", frame.header, "RIGHT", 0, 0)
    else
        close:SetSize(handle.closeWidth, handle.closeHeight)
        for _, point in ipairs(handle.closePoints) do close:SetPoint(unpack(point)) end
    end
    self:LayoutHeader(frame)
end

local function ValidateOptions(parent, options)
    assert(parent and type(parent.GetEffectiveScale) == "function", "window parent must be a frame")
    assert(type(options) == "table", "window options must be a table")
    assert(options.name == nil or (type(options.name) == "string" and options.name ~= ""),
        "window name must be a non-empty string")
    assert(options.title == nil or type(options.title) == "string", "window title must be a string")
    assert(options.compactHeader == nil or type(options.compactHeader) == "boolean", "compactHeader must be boolean")
    for _, key in ipairs({ "minWidth", "minHeight" }) do
        assert(type(options[key]) == "number" and options[key] > 0, "windows require positive minimum dimensions")
    end
    assert(options.maxWidth == nil or (type(options.maxWidth) == "number" and options.maxWidth >= options.minWidth),
        "window maxWidth must be at least minWidth")
    assert(options.maxHeight == nil or (type(options.maxHeight) == "number" and options.maxHeight >= options.minHeight),
        "window maxHeight must be at least minHeight")
    for _, key in ipairs({ "onMoveStopped", "onResizeStopped" }) do
        assert(options[key] == nil or type(options[key]) == "function", "window callbacks must be functions")
    end
end

function Context:CreateWindow(parent, options)
    ValidateOptions(parent, options)
    local frame = CreateFrame("Frame", options.name, parent, "ButtonFrameTemplate")
    frame:Hide()
    frame:SetFrameStrata(options.strata or "HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(options.minWidth, options.minHeight, options.maxWidth, options.maxHeight)
    frame:SetSize(options.minWidth, options.minHeight)
    frame:SetTitle(options.title or "")
    if options.portrait then
        frame:SetPortraitToAsset(options.portrait)
        frame:SetPortraitTexCoord(0, 1, 0, 1)
    end

    -- Keep Blizzard's outer background, native title/portrait, and close button.
    frame.Inset:ClearAllPoints()
    frame.Inset:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET_LEFT, INSET_TOP)
    frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)

    frame.header = CreateFrame("Frame", nil, frame)
    frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", HEADER_LEFT, HEADER_TOP)
    frame.header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", HEADER_RIGHT, HEADER_TOP)
    frame.header:SetHeight(HEADER_HEIGHT)

    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", CONTENT_LEFT, CONTENT_TOP)
    frame.content:SetPoint("BOTTOMRIGHT", frame.Inset, "BOTTOMRIGHT", CONTENT_RIGHT, CONTENT_BOTTOM)

    frame.footer = CreateFrame("Frame", nil, frame)
    frame.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", FOOTER_LEFT, FOOTER_BOTTOM)
    frame.footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", FOOTER_RIGHT, FOOTER_BOTTOM)
    frame.footer:SetHeight(FOOTER_HEIGHT)

    frame.resizeButton = CreateFrame("Button", nil, frame, "PanelResizeButtonTemplate")
    frame.resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", RESIZE_RIGHT, RESIZE_BOTTOM)
    frame.resizeButton:Init(frame, options.minWidth, options.minHeight, options.maxWidth, options.maxHeight)

    frame.headerDrag = CreateFrame("Frame", nil, frame)
    frame.headerDrag:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.headerDrag:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.headerDrag:SetHeight(COMPACT_HEADER_HEIGHT)
    frame.headerDrag:SetFrameLevel(frame:GetFrameLevel())
    frame.headerDrag:Hide()
    local root = self:_GetGeometryRoot(frame)
    local handle = self:RegisterComponent("window", frame, { bounds = frame }, options)
    root.window = handle
    self:_LayoutWindow(handle)
    self:RegisterComponent("nativeButton", frame.CloseButton, { bounds = frame }, { geometryRoot = frame, kind = "close" })
    self:RegisterComponent("nativeButton", frame.resizeButton, { bounds = frame }, { geometryRoot = frame, kind = "resize" })
    local function RefreshGeometry()
        self:RefreshGeometry(frame)
    end
    frame:HookScript("OnShow", RefreshGeometry)
    frame:HookScript("OnSizeChanged", RefreshGeometry)
    frame.content:HookScript("OnShow", RefreshGeometry)
    frame.content:HookScript("OnSizeChanged", RefreshGeometry)

    local onMoveStopped, onResizeStopped = options.onMoveStopped, options.onResizeStopped
    local function StartMove()
        handle.moving = true
        frame:StartMoving()
    end
    local function StopMove()
        handle.moving = false
        frame:StopMovingOrSizing()
        if onMoveStopped then
            onMoveStopped(frame)
        end
        RefreshGeometry()
        self:RetryPendingSkin()
    end
    for _, drag in ipairs({ frame.TitleContainer, frame.headerDrag }) do
        drag:EnableMouse(true)
        drag:RegisterForDrag("LeftButton")
        drag:SetScript("OnDragStart", StartMove)
        drag:SetScript("OnDragStop", StopMove)
    end
    frame.resizeButton:SetOnResizeStoppedCallback(function()
        if onResizeStopped then
            onResizeStopped(frame)
        end
        RefreshGeometry()
        self:RetryPendingSkin()
    end)
    frame:HookScript("OnHide", function()
        if handle.moving then StopMove() end
        if frame.resizeButton:IsActive() then frame.resizeButton:OnMouseUp() end
    end)
    return frame
end

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
local DEFAULT_INSET_BACKGROUND = "Interface\\FrameGeneral\\UIFrameMidnightBackground"

function Context:GetWindowChromeWidth()
    return INSET_LEFT - INSET_RIGHT + CONTENT_LEFT - CONTENT_RIGHT
end

local function ValidateOptions(parent, options)
    assert(parent and type(parent.GetEffectiveScale) == "function", "window parent must be a frame")
    assert(type(options) == "table", "window options must be a table")
    assert(options.name == nil or (type(options.name) == "string" and options.name ~= ""),
        "window name must be a non-empty string")
    assert(options.title == nil or type(options.title) == "string", "window title must be a string")
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
    frame.TopTileStreaks:Hide()
    frame.TopTileStreaks:SetAlpha(0)
    frame.Inset.Bg:SetTexture(options.insetBackground or DEFAULT_INSET_BACKGROUND, "REPEAT", "REPEAT")
    frame.Inset.Bg:SetHorizTile(true)
    frame.Inset.Bg:SetVertTile(true)
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

    local root = self:_GetGeometryRoot(frame)
    root.window = true
    local function RefreshGeometry()
        self:RefreshGeometry(frame)
    end
    frame:HookScript("OnShow", RefreshGeometry)
    frame:HookScript("OnSizeChanged", RefreshGeometry)
    frame.content:HookScript("OnShow", RefreshGeometry)
    frame.content:HookScript("OnSizeChanged", RefreshGeometry)

    local onMoveStopped, onResizeStopped = options.onMoveStopped, options.onResizeStopped
    frame.TitleContainer:EnableMouse(true)
    frame.TitleContainer:RegisterForDrag("LeftButton")
    frame.TitleContainer:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    frame.TitleContainer:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if onMoveStopped then
            onMoveStopped(frame)
        end
        RefreshGeometry()
    end)
    frame.resizeButton:SetOnResizeStoppedCallback(function()
        if onResizeStopped then
            onResizeStopped(frame)
        end
        RefreshGeometry()
    end)
    return frame
end

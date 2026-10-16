local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)
if not lib or lib._implementationMinor ~= MINOR or lib._modules.Pixel == MINOR then
    return
end
lib._modules.Pixel = MINOR

local Pixel = lib.Pixel
local Border = lib._borderPrototype
Border.__index = Border

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local EPSILON = 0.00001
Pixel._displayRevision = Pixel._displayRevision or 0

local function GetFactor()
    if not Pixel._factor then
        Pixel._factor = PixelUtil.GetPixelToUIUnitFactor()
    end
    return Pixel._factor
end

function Pixel.InvalidateDisplay()
    Pixel._factor = nil
    Pixel._displayRevision = Pixel._displayRevision + 1
end

-- Layout rounding is deliberately distinct from a physical stroke thickness.
function Pixel.Round(region, value, minPixels)
    return PixelUtil.GetNearestPixelSize(value, region:GetEffectiveScale(), minPixels)
end

function Pixel.GetPhysicalSize(region, pixels)
    return pixels * GetFactor() / region:GetEffectiveScale()
end

function Pixel.UpdateMetrics(metrics, root)
    metrics.scale = root:GetEffectiveScale()
    metrics.unit = GetFactor() / metrics.scale
    metrics.displayRevision = Pixel._displayRevision
    return metrics
end

function Pixel.PrepareTexture(texture)
    texture:SetColorTexture(1, 1, 1, 1)
    texture:SetBlendMode("BLEND")
    texture:SetSnapToPixelGrid(false)
    texture:SetTexelSnappingBias(0)
end

local function InnerRect(bounds, metrics, leftInset, rightInset, topInset, bottomInset)
    local left, bottom, width, height = bounds:GetRect()
    if not left or not bottom or not width or not height or width <= 0 or height <= 0 then
        return
    end

    local unit = metrics.unit
    -- Round absolute screen edges inward, not just their relative offsets.
    -- Fractional ancestors/scroll origins must not leave a half-pixel stroke.
    return ceil((left + (leftInset or 0)) / unit - EPSILON),
        ceil((bottom + (bottomInset or 0)) / unit - EPSILON),
        floor((left + width - (rightInset or 0)) / unit + EPSILON),
        floor((bottom + height - (topInset or 0)) / unit + EPSILON),
        left, bottom
end

local function CenteredSize(size, span)
    -- Equal integer margins require matching odd/even pixel counts. Choose
    -- the nearest positive size with that parity (larger on an exact tie).
    local parity = span % 2
    return max(parity == 0 and 2 or 1, floor((size - parity) / 2 + 0.5) * 2 + parity)
end

function Pixel.GetCenteredRect(bounds, metrics, width, height)
    local left, bottom, right, top, originX, originY = InnerRect(bounds, metrics)
    if not left or right <= left or top <= bottom then return end
    local unit = metrics.unit
    local pixelWidth = CenteredSize(width / unit, right - left)
    local pixelHeight = CenteredSize(height / unit, top - bottom)
    -- Use the border's snapped absolute bounds, not the unsnapped frame center.
    return (left + (right - left - pixelWidth) / 2) * unit - originX,
        (bottom + (top - bottom - pixelHeight) / 2) * unit - originY,
        pixelWidth * unit, pixelHeight * unit
end

local function DrawRect(texture, bounds, metrics, left, bottom, right, top, originX, originY, clip)
    if clip then
        local clipLeft, clipBottom, clipRight, clipTop = InnerRect(clip, metrics)
        if not clipLeft then
            texture:Hide()
            return false
        end
        left, bottom = max(left, clipLeft), max(bottom, clipBottom)
        right, top = min(right, clipRight), min(top, clipTop)
    end
    if right <= left or top <= bottom then
        texture:Hide()
        return false
    end

    local unit = metrics.unit
    texture:ClearAllPoints()
    texture:SetPoint("BOTTOMLEFT", bounds, "BOTTOMLEFT", left * unit - originX, bottom * unit - originY)
    texture:SetSize((right - left) * unit, (top - bottom) * unit)
    texture:Show()
    return true
end

function Pixel.LayoutLine(texture, bounds, metrics, options)
    local left, bottom, right, top, originX, originY = InnerRect(
        bounds, metrics, options.left, options.right, options.top, options.bottom
    )
    local thickness = options.thickness
    if not left or thickness <= 0 then
        texture:Hide()
        return false
    end

    -- Apply physical insets after snapping the layout bounds. Connected strokes
    -- can then reserve exactly the adjoining stroke's thickness at every scale.
    local pixelInsets = options.pixelInsets
    if pixelInsets then
        left, right = left + pixelInsets.left, right - pixelInsets.right
        bottom, top = bottom + pixelInsets.bottom, top - pixelInsets.top
    end
    if right <= left or top <= bottom then
        texture:Hide()
        return false
    end

    if options.orientation == "vertical" then
        if right - left < thickness then
            texture:Hide()
            return false
        end
        if options.align == "start" then
            right = min(right, left + thickness)
        elseif options.align == "end" then
            left = max(left, right - thickness)
        else
            left = floor((left + right - thickness) / 2 + 0.5)
            right = left + thickness
        end
    else
        if top - bottom < thickness then
            texture:Hide()
            return false
        end
        if options.align == "start" then
            bottom = max(bottom, top - thickness)
        elseif options.align == "end" then
            top = min(top, bottom + thickness)
        else
            bottom = floor((bottom + top - thickness) / 2 + 0.5)
            top = bottom + thickness
        end
    end
    return DrawRect(texture, bounds, metrics, left, bottom, right, top, originX, originY, options.clip)
end

function Pixel.LayoutFill(texture, bounds, metrics, inset, clip)
    local left, bottom, right, top, x, y = InnerRect(bounds, metrics)
    if not left then
        texture:Hide()
        return
    end
    inset = inset or 0
    DrawRect(texture, bounds, metrics, left + inset, bottom + inset, right - inset, top - inset, x, y, clip)
end

function Border:SetColor(r, g, b, a)
    for index = 1, 4 do
        self.edges[index]:SetVertexColor(r, g, b, a or 1)
    end
end

function Border:Hide()
    for index = 1, 4 do
        self.edges[index]:Hide()
    end
end

local function ValidateBorder(thickness, outset)
    assert(type(thickness) == "number" and thickness >= 0 and thickness == floor(thickness),
        "border thickness must be a non-negative integer number of physical pixels")
    assert(outset == nil or (type(outset) == "number" and outset >= 0), "border outset must be non-negative")
end

local function AnchorEdge(texture, bounds, first, second, x1, y1, x2, y2, size, horizontal)
    texture:ClearAllPoints()
    texture:SetPoint(first, bounds, first, x1, y1)
    texture:SetPoint(second, bounds, second, x2, y2)
    if horizontal then texture:SetHeight(size) else texture:SetWidth(size) end
    texture:Show()
end

function Border:LayoutRelative(metrics, thickness, outset)
    ValidateBorder(thickness, outset)
    outset = outset or 0
    local unit = metrics.unit
    local width, height = self.bounds:GetSize()
    local pixelWidth = width and floor((width + outset * 2) / unit + 0.5)
    local pixelHeight = height and floor((height + outset * 2) / unit + 0.5)
    if not pixelWidth or not pixelHeight or thickness == 0
        or pixelWidth < thickness * 2 or pixelHeight < thickness * 2 then
        self:Hide()
        return
    end

    -- The caller owns pixel alignment. Relative edges follow movement/size
    -- changes without re-snapping native float readback or retaining offsets
    -- measured before final placement. Horizontal strokes own the corners.
    local size = thickness * unit
    local inset = size - outset
    AnchorEdge(self.edges[1], self.bounds, "TOPLEFT", "TOPRIGHT", -outset, outset, outset, outset, size, true)
    AnchorEdge(self.edges[2], self.bounds, "BOTTOMLEFT", "BOTTOMRIGHT", -outset, -outset, outset, -outset, size, true)
    if pixelHeight == thickness * 2 then
        self.edges[3]:Hide()
        self.edges[4]:Hide()
    else
        AnchorEdge(self.edges[3], self.bounds, "TOPLEFT", "BOTTOMLEFT", -outset, -inset, -outset, inset, size, false)
        AnchorEdge(self.edges[4], self.bounds, "TOPRIGHT", "BOTTOMRIGHT", outset, -inset, outset, inset, size, false)
    end
end

function Border:Layout(metrics, thickness, clip, outset)
    ValidateBorder(thickness, outset)
    outset = outset or 0
    local left, bottom, right, top, originX, originY = InnerRect(self.bounds, metrics, -outset, -outset, -outset, -outset)
    if not left or thickness == 0 or right - left < thickness * 2 or top - bottom < thickness * 2 then
        self:Hide()
        return
    end

    -- Horizontal edges own the corners; vertical edges never overlap them.
    DrawRect(self.edges[1], self.bounds, metrics, left, top - thickness, right, top, originX, originY, clip)
    DrawRect(self.edges[2], self.bounds, metrics, left, bottom, right, bottom + thickness, originX, originY, clip)
    DrawRect(self.edges[3], self.bounds, metrics, left, bottom + thickness, left + thickness, top - thickness, originX, originY, clip)
    DrawRect(self.edges[4], self.bounds, metrics, right - thickness, bottom + thickness, right, top - thickness, originX, originY, clip)
end

function Pixel.CreateBorder(parent, bounds, layer, sublevel)
    assert(parent and type(parent.CreateTexture) == "function", "border parent must create textures")
    assert(bounds and type(bounds.GetRect) == "function", "border bounds must be a region")
    local border = setmetatable({ bounds = bounds, edges = {} }, Border)
    for index = 1, 4 do
        local texture = parent:CreateTexture(nil, layer or "BORDER", nil, sublevel or 0)
        Pixel.PrepareTexture(texture)
        texture:Hide()
        border.edges[index] = texture
    end
    return border
end

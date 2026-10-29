local MAJOR, MINOR = "LibYvSkins-1.0", 2
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or lib._modules.Separator == MINOR
then
    return
end

lib._modules.Separator = MINOR

local definition = lib._roles.separator or {}
lib._roles.separator = definition

function definition.Validate(texture, parts, options)
    assert(
        texture and type(texture.SetColorTexture) == "function",
        "separator target must be a texture"
    )
    assert(
        type(parts) == "table"
            and parts.bounds
            and type(parts.bounds.GetRect) == "function",
        "separator requires parts.bounds"
    )
    local root = options.geometryRoot or parts.bounds
    assert(
        type(root.GetEffectiveScale) == "function",
        "geometryRoot must be a region"
    )
    assert(
        texture:GetEffectiveScale() == root:GetEffectiveScale()
            and parts.bounds:GetEffectiveScale() == root:GetEffectiveScale(),
        "separator texture, bounds, and geometryRoot must share an effective scale"
    )
    assert(
        options.orientation == nil
            or options.orientation == "horizontal"
            or options.orientation == "vertical",
        "separator orientation must be horizontal or vertical"
    )
    assert(
        options.align == nil
            or options.align == "start"
            or options.align == "center"
            or options.align == "end",
        "separator align must be start, center, or end"
    )
    local thickness = options.thickness or 1
    assert(
        type(thickness) == "number"
            and thickness >= 0
            and thickness == math.floor(thickness),
        "separator thickness must be a non-negative integer number of physical pixels"
    )
    assert(
        options.pixelInsets == nil or type(options.pixelInsets) == "table",
        "separator pixelInsets must be a table"
    )

    for _, key in ipairs({ "left", "right", "top", "bottom" }) do
        assert(
            options[key] == nil
                or (type(options[key]) == "number" and options[key] >= 0),
            "separator insets must be non-negative UI units"
        )

        if options.pixelInsets then
            local value = options.pixelInsets[key]
            assert(
                value == nil
                    or (
                        type(value) == "number"
                        and value >= 0
                        and value == math.floor(value)
                    ),
                "separator pixelInsets must be non-negative integer numbers of physical pixels"
            )
        end
    end

    if options.clip then
        assert(
            type(options.clip.GetRect) == "function"
                and options.clip:GetEffectiveScale()
                    == root:GetEffectiveScale(),
            "separator clip must be a region with the same effective scale"
        )
    end

    assert(
        options.alpha == nil
            or (
                type(options.alpha) == "number"
                and options.alpha >= 0
                and options.alpha <= 1
            ),
        "separator alpha must be between zero and one"
    )

    if options.modernLayout ~= nil then
        local modern = options.modernLayout
        assert(
            type(modern) == "table" and modern.modernLayout == nil,
            "modernLayout must be a non-nested layout table"
        )
        definition.Validate(
            texture,
            { bounds = modern.bounds or parts.bounds },
            modern
        )
    end
end

local function CopyGeometry(options)
    local geometry = {
        orientation = options.orientation or "horizontal",
        align = options.align or "center",
        thickness = options.thickness or 1,
        left = options.left or 0,
        right = options.right or 0,
        top = options.top or 0,
        bottom = options.bottom or 0,
        clip = options.clip,
    }

    if options.pixelInsets then
        geometry.pixelInsets = {
            left = options.pixelInsets.left or 0,
            right = options.pixelInsets.right or 0,
            top = options.pixelInsets.top or 0,
            bottom = options.pixelInsets.bottom or 0,
        }
    end

    return geometry
end

function definition.Initialize(handle, options)
    handle.geometry = CopyGeometry(options)

    if options.modernLayout then
        handle.modernBounds = options.modernLayout.bounds or handle.parts.bounds
        handle.modernGeometry = CopyGeometry(options.modernLayout)
    end

    lib.Pixel.PrepareTexture(handle.target)
end

function definition.Layout(handle)
    if
        handle.modernGeometry
        and handle.context:GetAppliedSkin() == "modern"
    then
        lib.Pixel.LayoutLine(
            handle.target,
            handle.modernBounds,
            handle.root.metrics,
            handle.modernGeometry
        )
    else
        lib.Pixel.LayoutLine(
            handle.target,
            handle.parts.bounds,
            handle.root.metrics,
            handle.geometry
        )
    end
end

function definition.ApplyAppearance(handle)
    local r, g, b, a = handle.context:GetColor(handle.colorToken)
    handle.target:SetVertexColor(r, g, b, a * handle.alpha)
end

function lib._contextPrototype:CreateSeparator(parent, options)
    options = options or {}
    assert(
        parent and type(parent.CreateTexture) == "function",
        "separator parent must create textures"
    )
    local texture = parent:CreateTexture(
        nil,
        options.layer or "BORDER",
        nil,
        options.sublevel or 0
    )
    local handle = self:RegisterComponent(
        "separator",
        texture,
        { bounds = options.bounds or parent },
        options
    )
    return texture, handle
end

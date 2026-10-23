assert(
    _VERSION == "Lua 5.1",
    "Run this suite with Lua 5.1 from the library root"
)
local H = dofile("tests/harness.lua")
local passed = 0

-- A consumer fixture deliberately declares the former inventory-window
-- arrangement. It is not a library default or a required toolbar structure.
local EXAMPLE_LAYOUTS = {
    modern = {
        padding = {
            left = 4,
            right = 6,
            top = 0,
            bottom = 4,
        },
        header = { height = 56, gap = 4 },
        titleBar = {
            height = 24,
            margin = { left = -4, right = -6 },
        },
        footer = {
            height = 28,
            gap = 2,
            margin = { left = -1, right = 9 },
        },
        portrait = true,
    },
    flat = {
        padding = 8,
        header = { height = 28, gap = 4 },
        footer = {
            height = 24,
            gap = 4,
            margin = { right = 16 },
        },
        closeButton = "manual",
    },
}

local function LayoutExampleToolbar(window)
    if not window.toolbar then return end

    local context, compact =
        window.exampleContext, not window.titleBar:IsShown()
    window.toolbar:ClearAllPoints()
    window.toolbar:SetPoint(
        "TOPLEFT",
        window.header,
        "TOPLEFT",
        compact and 0 or 54,
        compact and 0 or -28
    )
    window.toolbar:SetPoint(
        "TOPRIGHT",
        window.header,
        "TOPRIGHT",
        0,
        compact and 0 or -28
    )
    local items = {}

    for index, item in ipairs(window.exampleItems) do
        items[index] = item
    end

    items[#items + 1] = {
        control = window.exampleSearch,
        stretch = true,
        minWidth = 96,
    }

    if compact then
        window.CloseButton:SetSize(28, 28)
        items[#items + 1] = window.CloseButton
    end

    context:SetToolbarItems(window.toolbar, items, compact and 4 or 2)
end

local function SetExampleToolbar(context, window, items, search)
    window.exampleContext, window.exampleItems, window.exampleSearch =
        context, items, search
    search:SetHeight(28)
    window.toolbar = context:CreateToolbar(window.header, { height = 28 })
    LayoutExampleToolbar(window)
end

local function ExampleMinimumWidth(window)
    if not window.toolbar then return 0 end

    return window.exampleContext:GetToolbarMinimumWidth(window.toolbar)
        + (window.titleBar:IsShown() and 64 or 16)
end

local function Test(name, callback)
    local success, message = pcall(callback)

    if not success then error(name .. ": " .. tostring(message), 0) end

    passed = passed + 1
    print("PASS " .. name)
end

Test(
    "two contexts isolate colors, registrations, and geometry roots",
    function()
        local state = H.New()
        local lib = state:Load()
        local colors = { accent = { r = 0.1, g = 0.2, b = 0.3 } }
        local first = lib:CreateContext("First", { tokens = colors })
        local second = lib:CreateContext("Second")
        H.Equal(lib:CreateContext("First"), first)
        colors.accent.r = 0.8
        H.Near(first:GetColor("accent"), 0.1)
        local rootA = state:Region(0.11, 0.17, 120, 24, 0.75)
        local rootB = state:Region(0.31, 0.07, 100, 24, 1.25)
        local a, b = rootA:CreateTexture(), rootB:CreateTexture()
        local handleA = first:RegisterComponent(
            "separator",
            a,
            { bounds = rootA },
            { alpha = 0.5 }
        )
        local handleB =
            second:RegisterComponent("separator", b, { bounds = rootB })
        H.Equal(
            first:RegisterComponent("separator", a, { bounds = rootA }),
            handleA
        )
        H.Equal(state.regions, 2)
        first:SetTokens({ accent = { r = 0.6, g = 0.5, b = 0.4 } })
        H.Equal(a.color[1], 0.6)
        H.Equal(a.color[4], 0.5)
        H.Equal(b.color[1], 1)
        handleB:SetAlpha(0.2)
        H.Equal(b.color[4], 0.2)
        H.Equal(a.color[4], 0.5)
        H.Equal(a._libYvSkins, nil)
        H.Aligned(a, state.height)
        H.Aligned(b, state.height)
    end
)

Test(
    "physical thickness and layout rounding are different operations",
    function()
        local state = H.New()
        local Pixel = state:Load().Pixel

        for _, height in ipairs({ 1080, 1440, 2160 }) do
            state.height = height
            Pixel.InvalidateDisplay()

            for _, frameScale in ipairs({ 0.5, 0.75, 1, 1.25, 1.5 }) do
                for _, uiScale in ipairs({ 0.64, 0.9, 1 }) do
                    local root =
                        state:Region(0, 0, 100, 24, frameScale * uiScale)

                    for _, pixels in ipairs({ 1, 2 }) do
                        H.Near(
                            Pixel.GetPhysicalSize(root, pixels)
                                * root.scale
                                / (768 / height),
                            pixels
                        )
                    end

                    for _, value in ipairs({ -13.17, -0.2, 0, 0.4, 17.41 }) do
                        H.Near(
                            Pixel.Round(root, value),
                            state.env.PixelUtil.GetNearestPixelSize(
                                value,
                                root.scale
                            )
                        )
                    end
                end
            end
        end
    end
)

Test(
    "lines align fractional/negative origins, both axes and all alignments",
    function()
        local state = H.New()
        local lib = state:Load()
        local context = lib:CreateContext("Lines")

        for _, height in ipairs({ 1080, 1440, 2160 }) do
            state.height = height
            lib.Pixel.InvalidateDisplay()

            for _, scale in ipairs({ 0.32, 0.5, 0.75, 1, 1.25, 1.5 }) do
                for _, origin in ipairs({ -91.27, -0.3, 0, 10.47 }) do
                    local bounds =
                        state:Region(origin, origin + 0.13, 103, 27, scale)

                    for _, orientation in ipairs({ "horizontal", "vertical" }) do
                        for _, align in ipairs({ "start", "center", "end" }) do
                            local texture = bounds:CreateTexture()
                            context:RegisterComponent(
                                "separator",
                                texture,
                                { bounds = bounds },
                                {
                                    orientation = orientation,
                                    align = align,
                                    left = 2,
                                    right = 2,
                                    top = 1,
                                    bottom = 1,
                                }
                            )
                            H.Aligned(texture, height)
                            local l, b, r, t = H.Rect(texture, height)
                            H.Near(
                                orientation == "vertical" and r - l or t - b,
                                1
                            )
                            local factor = scale / (768 / height)
                            assert(l >= (origin + 2) * factor - 0.00001)
                            assert(r <= (origin + 101) * factor + 0.00001)
                            context:UnregisterComponent(texture)
                        end
                    end
                end
            end
        end
    end
)

Test(
    "perpendicular separators join without gaps or overlap at every scale",
    function()
        local state = H.New()
        local lib = state:Load()
        local context = lib:CreateContext("Joins")

        for _, height in ipairs({ 1080, 1440, 2160 }) do
            state.height = height
            lib.Pixel.InvalidateDisplay()

            for _, uiScale in ipairs({ 0.64, 0.9, 1 }) do
                for _, origin in ipairs({ -91.27, -0.3, 0, 10.47 }) do
                    local bounds =
                        state:Region(origin, origin + 0.13, 300, 24, uiScale)
                    local verticalBounds = state:Region(
                        origin + 51.17,
                        bounds.bottom,
                        6,
                        24,
                        uiScale
                    )
                    local horizontal = bounds:CreateTexture()
                    local vertical = verticalBounds:CreateTexture()
                    context:RegisterComponent(
                        "separator",
                        horizontal,
                        { bounds = bounds },
                        { align = "end" }
                    )
                    context:RegisterComponent(
                        "separator",
                        vertical,
                        { bounds = verticalBounds },
                        {
                            geometryRoot = bounds,
                            orientation = "vertical",
                            top = 1,
                            pixelInsets = { bottom = 1 },
                            clip = bounds,
                        }
                    )

                    for _, frameScale in ipairs({
                        0.5,
                        0.75,
                        1,
                        1.2,
                        1.25,
                        1.3,
                        1.5,
                    }) do
                        bounds.scale = frameScale * uiScale
                        verticalBounds.scale = bounds.scale
                        context:RefreshGeometry(bounds)
                        H.Aligned(horizontal, height)
                        H.Aligned(vertical, height)
                        local _, horizontalBottom, _, horizontalTop =
                            H.Rect(horizontal, height)
                        local verticalLeft, verticalBottom, verticalRight =
                            H.Rect(vertical, height)
                        H.Near(horizontalTop - horizontalBottom, 1)
                        H.Near(verticalRight - verticalLeft, 1)
                        H.Near(
                            verticalBottom,
                            horizontalTop,
                            "separator join has a gap or overlap"
                        )
                    end

                    context:UnregisterComponent(horizontal)
                    context:UnregisterComponent(vertical)
                end
            end
        end
    end
)

Test(
    "pixel insets are copied, combine with layout insets, and hide exhausted bounds",
    function()
        local state = H.New()
        local lib = state:Load()
        local context = lib:CreateContext("Insets")
        local bounds = state:Region(-0.17, 2.23, 100, 24, 1.5)
        local factor = bounds.scale / (768 / state.height)
        local left = math.ceil((bounds.left + 2) * factor)
        local right = math.floor((bounds.left + bounds.width - 3) * factor)
        local bottom = math.ceil((bounds.bottom + 1) * factor)
        local top = math.floor((bounds.bottom + bounds.height - 2) * factor)

        for _, orientation in ipairs({ "horizontal", "vertical" }) do
            for _, align in ipairs({ "start", "end" }) do
                local texture = bounds:CreateTexture()
                local pixelInsets = {
                    left = 1,
                    right = 2,
                    top = 3,
                    bottom = 4,
                }
                local handle = context:RegisterComponent(
                    "separator",
                    texture,
                    { bounds = bounds },
                    {
                        orientation = orientation,
                        align = align,
                        left = 2,
                        right = 3,
                        top = 2,
                        bottom = 1,
                        pixelInsets = pixelInsets,
                        clip = bounds,
                    }
                )
                pixelInsets.left, pixelInsets.right, pixelInsets.top, pixelInsets.bottom =
                    1000, 1000, 1000, 1000
                handle:RefreshGeometry()
                H.Aligned(texture, state.height)
                local l, b, r, t = H.Rect(texture, state.height)

                if orientation == "horizontal" then
                    H.Near(l, left + 1)
                    H.Near(r, right - 2)
                    H.Near(
                        align == "start" and t or b,
                        align == "start" and top - 3 or bottom + 4
                    )
                else
                    H.Near(b, bottom + 4)
                    H.Near(t, top - 3)
                    H.Near(
                        align == "start" and l or r,
                        align == "start" and left + 1 or right - 2
                    )
                end

                context:UnregisterComponent(texture)
            end
        end

        local texture = bounds:CreateTexture()
        context:RegisterComponent(
            "separator",
            texture,
            { bounds = bounds },
            { pixelInsets = { bottom = 1000 } }
        )
        H.Equal(texture:IsShown(), false)
    end
)

Test(
    "four-edge borders have two-pixel strokes without overlapping corners",
    function()
        local state = H.New()
        local Pixel = state:Load().Pixel

        for _, height in ipairs({ 1080, 1440, 2160 }) do
            state.height = height
            Pixel.InvalidateDisplay()

            for _, scale in ipairs({ 0.5, 0.75, 1, 1.25, 1.5 }) do
                local bounds = state:Region(-3.17, 2.23, 23, 29, scale)
                local border = Pixel.CreateBorder(bounds, bounds)
                local metrics = Pixel.UpdateMetrics({}, bounds)
                border:Layout(metrics, 2)
                border:SetColor(1, 0.5, 0, 0.7)
                local rects = {}

                for index, edge in ipairs(border.edges) do
                    H.Aligned(edge, height)
                    rects[index] = { H.Rect(edge, height) }
                    local rect = rects[index]
                    H.Near(
                        index <= 2 and rect[4] - rect[2] or rect[3] - rect[1],
                        2
                    )
                    H.Equal(edge.color[4], 0.7)
                end

                for a = 1, 4 do
                    for b = a + 1, 4 do
                        local x, y = rects[a], rects[b]
                        assert(
                            math.min(x[3], y[3]) - math.max(x[1], y[1])
                                    < 0.00001
                                or math.min(x[4], y[4])
                                        - math.max(x[2], y[2])
                                    < 0.00001,
                            "border corners overlap"
                        )
                    end
                end

                local count = state.regions

                for _ = 1, 10 do
                    border:Layout(metrics, 2)
                end

                H.Equal(state.regions, count)
                border:Layout(metrics, 0)

                for _, edge in ipairs(border.edges) do
                    H.Equal(edge:IsShown(), false)
                end
            end
        end
    end
)

Test(
    "relative borders preserve caller size through float noise, movement and resize",
    function()
        local state = H.New()
        local Pixel = state:Load().Pixel

        local function Check(border, bounds, unit, thickness, outset)
            local left, bottom, width, height = bounds:GetRect()
            local size = thickness * unit
            local expected = {
                {
                    left - outset,
                    bottom + height + outset - size,
                    width + outset * 2,
                    size,
                },
                { left - outset, bottom - outset, width + outset * 2, size },
                {
                    left - outset,
                    bottom - outset + size,
                    size,
                    height + outset * 2 - size * 2,
                },
                {
                    left + width + outset - size,
                    bottom - outset + size,
                    size,
                    height + outset * 2 - size * 2,
                },
            }

            for index, edge in ipairs(border.edges) do
                H.Equal(edge:IsShown(), true)
                local actual = { edge:GetRect() }

                for coordinate = 1, 4 do
                    H.Near(
                        actual[coordinate] / unit,
                        expected[index][coordinate] / unit
                    )
                end
            end
        end

        for _, height in ipairs({ 1080, 1440, 2160 }) do
            state.height = height
            Pixel.InvalidateDisplay()

            for _, scale in ipairs({ 0.64, 0.85, 1 }) do
                local bounds = state:Region(0, 0, 1, 1, scale)
                local metrics = Pixel.UpdateMetrics({}, bounds)
                local unit = metrics.unit
                bounds.width, bounds.height = 18 * unit, 53 * unit
                local border = Pixel.CreateBorder(bounds, bounds)
                local regions = state.regions

                for _, origin in ipairs({ -1024, 0, 350, 1601 }) do
                    for _, noise in ipairs({ -0.0002, 0, 0.0002 }) do
                        bounds.left, bounds.bottom =
                            (origin + noise) * unit, (origin - noise) * unit

                        for _, outset in ipairs({ 0, 2 * unit }) do
                            border:LayoutRelative(metrics, 1, outset)
                            Check(border, bounds, unit, 1, outset)
                            bounds.left, bounds.bottom =
                                bounds.left + 5 * unit, bounds.bottom - 3 * unit
                            bounds.width, bounds.height = 19 * unit, 54 * unit
                            Check(border, bounds, unit, 1, outset)
                            bounds.width, bounds.height = 18 * unit, 53 * unit
                        end
                    end
                end

                H.Equal(state.regions, regions)
            end
        end
    end
)

Test(
    "relative border contracts, minimum sizes and switching layout modes",
    function()
        local state = H.New()
        local Pixel = state:Load().Pixel
        local bounds = state:Region(0, 0, 100, 100, 0.64)
        local metrics = Pixel.UpdateMetrics({}, bounds)
        local border = Pixel.CreateBorder(bounds, bounds)

        for _, thickness in ipairs({ -1, 0.5, "1", false }) do
            H.Fails(function()
                border:LayoutRelative(metrics, thickness)
            end)
        end

        for _, outset in ipairs({ -1, "1", false }) do
            H.Fails(function()
                border:LayoutRelative(metrics, 1, outset)
            end)
        end

        border:LayoutRelative(metrics, 0)

        for _, edge in ipairs(border.edges) do
            H.Equal(edge:IsShown(), false)
        end

        bounds.width = metrics.unit
        border:LayoutRelative(metrics, 1)

        for _, edge in ipairs(border.edges) do
            H.Equal(edge:IsShown(), false)
        end

        bounds.width, bounds.height = 2 * metrics.unit, 2 * metrics.unit
        border:LayoutRelative(metrics, 1)

        for index, edge in ipairs(border.edges) do
            H.Equal(edge:IsShown(), index <= 2)
        end

        bounds.width, bounds.height = 18 * metrics.unit, 53 * metrics.unit
        border:LayoutRelative(metrics, 2)
        border:Layout(metrics, 1)

        for _, edge in ipairs(border.edges) do
            H.Aligned(edge, state.height)
        end

        border:LayoutRelative(metrics, 2)
        border:SetColor(1, 0.5, 0, 0.7)

        for _, edge in ipairs(border.edges) do
            H.Equal(edge:IsShown(), true)
            H.Equal(edge.color[4], 0.7)
            H.Aligned(edge, state.height)
        end

        border:Hide()

        for _, edge in ipairs(border.edges) do
            H.Equal(edge:IsShown(), false)
        end
    end
)

Test(
    "clipping keeps strokes out of the scrollbar gutter and hides offscreen lines",
    function()
        local state = H.New()
        local lib = state:Load()
        local context = lib:CreateContext("Clip")
        local bounds = state:Region(10.21, 20.31, 300, 33, 0.83)
        local clip = state:Region(11.1, 10, 267, 100, 0.83)
        local texture = bounds:CreateTexture()
        local handle = context:RegisterComponent(
            "separator",
            texture,
            { bounds = bounds },
            { clip = clip }
        )
        H.Aligned(texture, state.height)
        local l, _, r = H.Rect(texture, state.height)
        assert(l >= clip.left * clip.scale / (768 / state.height))
        assert(
            r <= (clip.left + clip.width) * clip.scale / (768 / state.height)
        )
        bounds.bottom = -100
        handle:RefreshGeometry()
        H.Equal(texture:IsShown(), false)
        bounds.bottom = 20.31
        handle:RefreshGeometry()
        H.Equal(texture:IsShown(), true)
    end
)

Test(
    "scroll refreshes allocate no regions/hooks and reuse cached root metrics",
    function()
        local state = H.New()
        local lib = state:Load()
        local context = lib:CreateContext("Scroll")
        local root = state:Region(0, 0, 500, 600, 0.7)
        local row = state:Region(0.13, 40.17, 500, 33, 0.7)
        local texture = row:CreateTexture()
        local handle = context:RegisterComponent(
            "separator",
            texture,
            { bounds = row },
            { geometryRoot = root }
        )
        local count, reads = state.regions, state.factorReads

        for _ = 1, 100 do
            row.bottom = row.bottom - 0.13
            handle:RefreshGeometry()
            H.Aligned(texture, state.height)
        end

        H.Equal(state.regions, count)
        H.Equal(state.factorReads, reads)
        H.Equal(state.hooks, 0)

        for _, frame in ipairs(state.frames) do
            H.Equal(frame.scripts.OnUpdate, nil)
        end
    end
)

Test(
    "hidden and recycled components retain state and receive the next geometry revision",
    function()
        local state = H.New()
        local lib = state:Load()
        local context = lib:CreateContext("Pool")
        local root = state:Region(1.17, 4.23, 100, 24, 0.75)
        local texture = root:CreateTexture()
        local handle =
            context:RegisterComponent("separator", texture, { bounds = root })
        handle:SetShown(false)
        root.scale = 1.25
        context:RefreshGeometry(root)
        H.Equal(texture:IsShown(), false)
        handle:SetShown(true)
        H.Aligned(texture, state.height)
        local _, b, _, t = H.Rect(texture, state.height)
        H.Near(t - b, 1)
        root:Hide()
        context:RefreshGeometry(root)
        H.Equal(texture:IsShown(), false)
        root:Show()
        context:RefreshGeometry(root)
        H.Equal(texture:IsShown(), true)
        root.unresolved = true
        context:RefreshGeometry(root)
        H.Equal(texture:IsShown(), false)
        root.unresolved = nil
        context:RefreshGeometry(root)
        H.Equal(texture:IsShown(), true)
        context:UnregisterComponent(texture)
        handle:SetShown(true)
        H.Equal(texture:IsShown(), false)
        H.Equal(next(context._roots), nil)
        H.Equal(next(context._components), nil)
    end
)

Test(
    "display events coalesce once across consumers and refresh live instances",
    function()
        local state = H.New()
        local lib = state:Load()
        local first, second =
            lib:CreateContext("First"), lib:CreateContext("Second")
        local root = state:Region(2.17, 4.31, 100, 24, 0.93)
        local a, b = root:CreateTexture(), root:CreateTexture()
        first:RegisterComponent("separator", a, { bounds = root })
        second:RegisterComponent("separator", b, { bounds = root })
        state.height = 2160
        lib._displayEventFrame.scripts.OnEvent()
        lib._displayEventFrame.scripts.OnEvent()
        H.Equal(#state.timers, 1)
        state:Flush()
        H.Aligned(a, state.height)
        H.Aligned(b, state.height)
        H.Equal(#state.timers, 0)
    end
)

Test("one consumer keeps independent scales for two windows", function()
    local state = H.New()
    local lib = state:Load()
    local context = lib:CreateContext("Windows")
    local first = state:Region(11.13, 21.71, 90, 24, 0.5)
    local second = state:Region(211.19, 26.77, 110, 24, 1.5)
    local a, b = first:CreateTexture(), second:CreateTexture()
    local handleA =
        context:RegisterComponent("separator", a, { bounds = first })
    local handleB =
        context:RegisterComponent("separator", b, { bounds = second })
    local originalUnit = handleB.root.metrics.unit
    first.scale = 0.9
    context:RefreshGeometry(first)
    H.Aligned(a, state.height)
    H.Aligned(b, state.height)
    H.Equal(handleB.root.metrics.unit, originalUnit)
    assert(handleA.root.metrics.unit ~= handleB.root.metrics.unit)
    context:UnregisterComponent(a)
    context:UnregisterComponent(a)
    handleB:RefreshGeometry()
    H.Equal(b:IsShown(), true)
end)

Test(
    "tiny and zero-thickness shapes hide rather than drawing fractional strokes",
    function()
        local state = H.New()
        local lib = state:Load()
        local context = lib:CreateContext("Tiny")
        local bounds = state:Region(0.13, 0.17, 0.01, 0.01, 1)
        local texture = bounds:CreateTexture()
        context:RegisterComponent("separator", texture, { bounds = bounds })
        H.Equal(texture:IsShown(), false)
        bounds.width, bounds.height = 100, 24
        context:UnregisterComponent(texture)
        context:RegisterComponent(
            "separator",
            texture,
            { bounds = bounds },
            { thickness = 0 }
        )
        H.Equal(texture:IsShown(), false)
        local border = lib.Pixel.CreateBorder(bounds, bounds)
        bounds.width = 0.1
        border:Layout(lib.Pixel.UpdateMetrics({}, bounds), 2)

        for _, edge in ipairs(border.edges) do
            H.Equal(edge:IsShown(), false)
        end
    end
)

Test(
    "invalid roles, parts, scales, tokens, and thicknesses fail at registration",
    function()
        local state = H.New()
        local lib = state:Load()
        H.Fails(function()
            lib:CreateContext("")
        end)
        local context = lib:CreateContext("Contracts")
        local root = state:Region(0, 0, 100, 24, 1)
        local texture = root:CreateTexture()
        H.Fails(function()
            context:RegisterComponent("missing", texture, { bounds = root })
        end)
        H.Fails(function()
            context:RegisterComponent("separator", texture, {})
        end)

        for _, options in ipairs({
            { thickness = -1 },
            { thickness = 0.5 },
            { orientation = "diagonal" },
            { align = "outside" },
            { colorToken = "missing" },
            { left = -1 },
            { alpha = 2 },
        }) do
            H.Fails(function()
                context:RegisterComponent(
                    "separator",
                    texture,
                    { bounds = root },
                    options
                )
            end)
        end

        for _, value in ipairs({ false, 1, "1" }) do
            H.Fails(function()
                context:RegisterComponent(
                    "separator",
                    texture,
                    { bounds = root },
                    { pixelInsets = value }
                )
            end)
        end

        for _, edge in ipairs({ "left", "right", "top", "bottom" }) do
            for _, value in ipairs({ -1, 0.5, "1", false }) do
                H.Fails(function()
                    context:RegisterComponent(
                        "separator",
                        texture,
                        { bounds = root },
                        { pixelInsets = { [edge] = value } }
                    )
                end)
            end
        end

        H.Fails(function()
            context:SetTokens({ accent = { r = "bad", g = 0, b = 0 } })
        end)
        H.Equal(context:GetColor("accent"), 1)
        local differentScale = state:Region(0, 0, 100, 24, 0.75)
        H.Fails(function()
            context:RegisterComponent(
                "separator",
                texture,
                { bounds = differentScale }
            )
        end)
    end
)

Test(
    "mixed/equal MINOR embeds preserve contexts, handles, prototypes, and singleton event subscriptions",
    function()
        for _, order in ipairs({
            { 1, 2 },
            { 2, 1 },
            { 1, 1 },
            { 2, 2 },
        }) do
            local state = H.New()
            local lib = state:Load(order[1])
            local context = lib:CreateContext("Existing")
            local root = state:Region(-0.17, 0.21, 100, 24, 0.83)
            local texture = root:CreateTexture()
            local handle = context:RegisterComponent(
                "separator",
                texture,
                { bounds = root }
            )
            local border = lib.Pixel.CreateBorder(root, root)
            local eventFrame = lib._displayEventFrame
            local oldContextMethod, oldPixelMethod =
                context.RefreshGeometry, lib.Pixel.LayoutLine
            local oldHandleMethod = handle.RefreshGeometry
            local count = state.regions
            state:Load(order[2])
            H.Equal(state.lib, lib)
            H.Equal(lib:CreateContext("Existing"), context)
            H.Equal(lib._displayEventFrame, eventFrame)
            H.Equal(#state.frames, 2)
            H.Equal(lib._implementationMinor, math.max(order[1], order[2]))
            H.Equal(
                context:RegisterComponent(
                    "separator",
                    texture,
                    { bounds = root }
                ),
                handle
            )

            if order[2] > order[1] then
                assert(context.RefreshGeometry ~= oldContextMethod)
                assert(handle.RefreshGeometry ~= oldHandleMethod)
                assert(lib.Pixel.LayoutLine ~= oldPixelMethod)
            else
                H.Equal(context.RefreshGeometry, oldContextMethod)
                H.Equal(lib.Pixel.LayoutLine, oldPixelMethod)
            end
            -- Late files from an older copy cannot register over the chosen one.
            local pixelMethod = lib.Pixel.LayoutLine
            state:Load(
                1,
                { "Components/Separator.lua", "Context.lua", "Pixel.lua" }
            )

            if math.max(order[1], order[2]) == 2 then
                H.Equal(lib.Pixel.LayoutLine, pixelMethod)
            end

            context:RefreshGeometry()
            border:Layout(lib.Pixel.UpdateMetrics({}, root), 2)
            border:LayoutRelative(lib.Pixel.UpdateMetrics({}, root), 2)
            H.Equal(border.edges[1]:IsShown(), true)
            H.Aligned(texture, state.height)
            H.Equal(state.regions, count)
        end
    end
)

Test(
    "window factory creates raw frames with canonical Modern chrome",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Windows")
        local parent = state:Region(0, 0, 1024, 768, 1)
        local window = context:CreateWindow(parent, {
            name = "TestWindow",
            title = "Inventory",
            portrait = "test-icon",
            insetBackground = "test-tile",
            minWidth = 420,
            minHeight = 360,
            maxWidth = 900,
            layouts = EXAMPLE_LAYOUTS,
        })
        H.Equal(window:GetObjectType(), "Frame")
        H.Equal(window.template, "ButtonFrameTemplate")
        H.Equal(window:GetParent(), parent)
        H.Equal(window:GetName(), "TestWindow")
        H.Equal(window:IsShown(), false)
        H.Equal(window.title, "Inventory")
        H.Equal(window.portrait, "test-icon")
        H.Equal(window.Bg.texture[1], "native-outer-background")
        H.Equal(window.Inset.Bg.texture[1], "test-tile")
        H.Equal(window.Inset.Bg.texture[2], "REPEAT")
        H.Equal(window.Inset.Bg.horizTile, true)
        H.Equal(window.Inset.Bg.vertTile, true)
        H.Equal(window.TopTileStreaks:IsShown(), false)
        H.Equal(window.resizeButton.target, window)
        H.Equal(window.resizeButton.initCount, 1)
        H.Equal(window.resizeButton.maxWidth, 900)
        H.Equal(
            window.points,
            nil,
            "the library must not choose or persist a window position"
        )
        window:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 21.17, 17.23)
        local left, bottom = window:GetRect()

        for _, width in ipairs({ 420, 730, 900 }) do
            window:SetSize(width, 500)
            local cl, cb, cw, ch = window.body:GetRect()
            H.Near(cl, left + 7)
            H.Near(cb, bottom + 36)
            H.Near(cw, width - context:GetWindowBodyWidthOverhead(window))
            H.Near(ch, 500 - 99)
            local hl, hb, hw, hh = window.header:GetRect()
            H.Near(hl, left + 4)
            H.Near(hb, bottom + 500 - 56)
            H.Near(hw, width - 10)
            H.Equal(hh, 56)
            local fl, fb, fw, fh = window.footer:GetRect()
            H.Near(fl, left + 3)
            H.Near(fb, bottom + 4)
            H.Near(fw, width - 18)
            H.Equal(fh, 28)
        end
    end
)

Test(
    "created windows refresh child strokes without an addon adapter",
    function()
        local state = H.New()
        local lib = state:Load()
        local context = lib:CreateContext("Owner")
        local other = lib:CreateContext("Other")
        local parent = state:Region(0, 0, 1024, 768, 1)
        local first =
            context:CreateWindow(parent, { minWidth = 420, minHeight = 360 })
        local second =
            other:CreateWindow(parent, { minWidth = 520, minHeight = 420 })
        first:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0.13, 0.21)
        second:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 501.17, 20.19)
        local options = {
            geometryRoot = first,
            align = "end",
            layer = "ARTWORK",
            sublevel = 1,
        }
        local texture, handle = context:CreateSeparator(first.body, options)
        local otherTexture, otherHandle =
            other:CreateSeparator(second.body, { geometryRoot = second })
        H.Equal(texture:GetObjectType(), "Texture")
        H.Equal(handle.target, texture)
        H.Equal(texture.layer, "ARTWORK")
        H.Equal(texture.sublevel, 1)
        H.Equal(
            options.bounds,
            nil,
            "the factory must not mutate caller options"
        )
        H.Equal(handle.root.region, first)
        H.Equal(texture:IsShown(), false)
        first:Show()
        second:Show()
        local otherUnit = otherHandle.root.metrics.unit
        local frames, regions, hooks = #state.frames, state.regions, state.hooks

        for _, scale in ipairs({ 0.5, 0.75, 1, 1.25, 1.5 }) do
            first:SetScale(scale)
            context:RefreshGeometry(first)
            first:SetSize(600, 500)
            H.Aligned(texture, state.height)
            local _, b, _, t = H.Rect(texture, state.height)
            H.Near(t - b, 1)
            H.Equal(otherHandle.root.metrics.unit, otherUnit)
        end

        first.body:Hide()
        context:RefreshGeometry(first)
        H.Equal(texture:IsShown(), false)
        first.body:Show()
        H.Equal(texture:IsShown(), true)
        H.Equal(otherTexture:IsShown(), true)
        H.Equal(#state.frames, frames)
        H.Equal(state.regions, regions)
        H.Equal(state.hooks, hooks)
        context:UnregisterComponent(texture)
        assert(
            context._roots[first],
            "a window owns its geometry root even with no strokes"
        )
        local replacement =
            context:CreateSeparator(first.body, { geometryRoot = first })
        H.Aligned(replacement, state.height)
    end
)

Test(
    "window callbacks preserve native movement, resize, close and consumer scripts",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Callbacks")
        local parent = state:Region(0, 0, 1024, 768, 1)
        local moved, resized, shown, closed = 0, 0, 0, 0
        local window = context:CreateWindow(parent, {
            minWidth = 420,
            minHeight = 360,
            layouts = EXAMPLE_LAYOUTS,
            onMoveStopped = function(target)
                H.Equal(target.moving, false)
                moved = moved + 1
            end,
            onResizeStopped = function(target)
                H.Equal(target.sizing, false)
                target:SetSize(500, 400)
                resized = resized + 1
            end,
        })
        window:SetPoint("CENTER", parent, "CENTER", 0.17, 0.23)
        local texture =
            context:CreateSeparator(window.body, { geometryRoot = window })
        window:SetScript("OnShow", function()
            shown = shown + 1
        end)
        window:Show()
        H.Equal(
            texture:IsShown(),
            true,
            "consumer SetScript must not replace library hooks"
        )
        window.TitleContainer:RunScript("OnDragStart")
        H.Equal(window.moving, true)
        window.TitleContainer:RunScript("OnDragStop")
        H.Equal(moved, 1)
        window.resizeButton:RunScript("OnMouseDown")
        H.Equal(window.sizing, true)
        window.resizeButton:RunScript("OnMouseUp")
        H.Equal(resized, 1)
        H.Near(window:GetWidth(), 500)
        H.Aligned(texture, state.height)
        window.CloseButton:RunScript("OnClick")
        H.Equal(window:IsShown(), false)
        window.CloseButton:SetScript("OnClick", function()
            closed = closed + 1
        end)
        window:Show()
        window.CloseButton:RunScript("OnClick")
        H.Equal(closed, 1)
        H.Equal(
            window:IsShown(),
            true,
            "domain close behavior must remain directly replaceable"
        )
        H.Equal(shown, 2)
    end
)

Test("window resize finishes once when released outside the grip", function()
    local state = H.New()
    local context = state:Load():CreateContext("ResizeRelease")
    local parent = state:Region(0, 0, 1024, 768, 1)
    local stopped = 0
    local window = context:CreateWindow(parent, {
        minWidth = 400,
        minHeight = 300,
        onResizeStopped = function(target)
            H.Equal(target.sizing, false)
            stopped = stopped + 1
        end,
    })
    window:Show()
    local grip = window.resizeButton

    grip:RunScript("OnMouseDown", "LeftButton")
    H.Equal(grip.events.GLOBAL_MOUSE_UP, true)
    grip:RunScript("OnEvent", "GLOBAL_MOUSE_UP", "RightButton")
    state:Flush()
    H.Equal(
        grip:IsActive(),
        true,
        "another mouse button must not stop the resize"
    )
    grip:RunScript("OnEvent", "GLOBAL_MOUSE_UP", "LeftButton")
    state:Flush()
    H.Equal(stopped, 1)
    H.Equal(grip:IsActive(), false)
    H.Equal(grip.events.GLOBAL_MOUSE_UP, nil)
    H.Equal(context._components[grip].pressed, false)

    -- Native mouse-up can run before or after the global event.
    for _, globalFirst in ipairs({ true, false }) do
        grip:RunScript("OnMouseDown", "LeftButton")

        if globalFirst then
            grip:RunScript("OnEvent", "GLOBAL_MOUSE_UP", "LeftButton")
        end

        grip:RunScript("OnMouseUp", "LeftButton")

        if not globalFirst then
            grip:RunScript("OnEvent", "GLOBAL_MOUSE_UP", "LeftButton")
        end

        local nativeStops = stopped
        state:Flush()
        H.Equal(stopped, nativeStops, "native completion must not fire twice")
        H.Equal(grip.events.GLOBAL_MOUSE_UP, nil)
    end

    H.Equal(stopped, 3)

    grip:RunScript("OnMouseDown", "LeftButton")
    grip:RunScript("OnEvent", "GLOBAL_MOUSE_UP", "LeftButton")
    grip:RunScript("OnMouseDown", "LeftButton")
    state:Flush()
    H.Equal(grip:IsActive(), true, "an old release must not stop a new resize")
    H.Equal(stopped, 3)
    grip:RunScript("OnEvent", "GLOBAL_MOUSE_UP", "LeftButton")
    state:Flush()
    H.Equal(stopped, 4)

    grip:RunScript("OnMouseDown", "LeftButton")
    grip:RunScript("OnEvent", "GLOBAL_MOUSE_UP", "LeftButton")
    window:Hide()
    state:Flush()
    H.Equal(stopped, 5, "hiding must finish the resize once")
    H.Equal(grip:IsActive(), false)
    H.Equal(grip.events.GLOBAL_MOUSE_UP, nil)
end)

Test("invalid window contracts fail before allocating frames", function()
    local state = H.New()
    local context = state:Load():CreateContext("Validation")
    local parent = state:Region(0, 0, 1024, 768, 1)
    local frames = #state.frames
    H.Fails(function()
        context:CreateWindow(parent, nil)
    end)
    H.Fails(function()
        context:CreateWindow(nil, { minWidth = 400, minHeight = 300 })
    end)

    for _, options in ipairs({
        {},
        { minWidth = 0, minHeight = 300 },
        { minWidth = 400 },
        {
            minWidth = 400,
            minHeight = 300,
            maxWidth = 300,
        },
        {
            minWidth = 400,
            minHeight = 300,
            maxHeight = 200,
        },
        {
            minWidth = 400,
            minHeight = 300,
            onMoveStopped = true,
        },
        {
            minWidth = 400,
            minHeight = 300,
            onResizeStopped = false,
        },
        {
            minWidth = 400,
            minHeight = 300,
            name = "",
        },
        {
            minWidth = 400,
            minHeight = 300,
            title = true,
        },
    }) do
        H.Fails(function()
            context:CreateWindow(parent, options)
        end)
    end

    H.Equal(#state.frames, frames)
end)

Test(
    "window instances survive mixed MINOR embeds without duplicate lifecycle hooks",
    function()
        for _, order in ipairs({
            { 1, 2 },
            { 2, 1 },
            { 1, 1 },
            { 2, 2 },
        }) do
            local state = H.New()
            local lib = state:Load(order[1])
            local context = lib:CreateContext("Windows")
            local parent = state:Region(0, 0, 1024, 768, 1)
            local window = context:CreateWindow(
                parent,
                { minWidth = 400, minHeight = 300 }
            )
            window:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -0.17, 4.31)
            local texture, handle =
                context:CreateSeparator(window.body, { geometryRoot = window })
            local factory = context.CreateWindow
            local frames, regions, hooks =
                #state.frames, state.regions, state.hooks
            state:Load(order[2])

            if order[2] > order[1] then
                assert(context.CreateWindow ~= factory)
            else
                H.Equal(context.CreateWindow, factory)
            end

            local selectedFactory = context.CreateWindow
            state:Load(1, { "Window.lua" })

            if math.max(order[1], order[2]) == 2 then
                H.Equal(context.CreateWindow, selectedFactory)
            end

            window:SetScale(1.3)
            window:Show()
            H.Aligned(texture, state.height)
            H.Equal(context._roots[window], handle.root)
            H.Equal(window.resizeButton.initCount, 1)
            H.Equal(#state.frames, frames)
            H.Equal(state.regions, regions)
            H.Equal(state.hooks, hooks)
        end
    end
)

Test(
    "expandable headers use icon-free Modern art with native text and click access",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Headers")
        local parent = state:Region(0, 0, 400, 31, 1)
        local before = state.regions
        local header, handle = context:CreateExpandableHeader(parent, {
            height = 31,
            text = "Consumable (2)",
            expanded = false,
            font = "test-font",
            fontSize = 18,
        })
        header:SetAllPoints(parent)
        H.Equal(header:GetObjectType(), "Button")
        H.Equal(header:GetWidth(), 400)
        H.Equal(header:GetHeight(), 31)
        H.Equal(header:GetText(), "Consumable (2)")
        H.Equal(header.clickButtons[1], "LeftButtonUp")
        H.Equal(
            header:GetNormalTexture().atlas,
            "common-button-tertiary-normal"
        )
        H.Equal(
            header:GetPushedTexture().atlas,
            "common-button-tertiary-pressed"
        )
        H.Equal(
            header:GetDisabledTexture().atlas,
            "common-button-tertiary-disabled"
        )
        H.Equal(
            state.regions - before,
            10,
            "Modern art plus one preallocated five-region Flat surface"
        )
        H.Equal(
            handle.parts.icon,
            nil,
            "no leading icon or icon-space reservation"
        )
        H.Equal(
            handle.parts.divider,
            nil,
            "the Modern bar needs no separate divider"
        )
        local label, arrow = header:GetFontString(), handle.parts.arrow
        H.Equal(label.points.LEFT[1], header)
        H.Equal(label.points.LEFT[3], 12)
        H.Equal(label.points.RIGHT[1], arrow)
        H.Equal(label.font[1], "test-font")
        H.Equal(label.font[2], 18)
        H.Equal(label.wordWrap, false)
        H.Equal(arrow.atlas, "common-dropdown-icon-next")
        H.Equal(arrow:GetWidth(), 17)
        H.Equal(arrow.points.RIGHT[3], -12)
        H.Equal(arrow.points.RIGHT[4], -1)
        H.Near(arrow.rotation, math.pi * 0.5)
        handle:SetExpanded(true)
        H.Equal(arrow.points.RIGHT[4], 2)
        H.Near(arrow.rotation, math.pi * 1.5)
        H.Equal(handle:IsExpanded(), true)
        local clicks = 0
        header:SetScript("OnClick", function(button, mouseButton)
            H.Equal(button, header)
            H.Equal(mouseButton, "LeftButton")
            clicks = clicks + 1
        end)
        header:RunScript("OnClick", "LeftButton")
        H.Equal(clicks, 1)
        H.Equal(
            handle:IsExpanded(),
            true,
            "only the consumer changes authoritative expansion state"
        )
        header:SetText("Pinned (3)")
        H.Equal(label:GetText(), "Pinned (3)")
    end
)

Test(
    "header native states and pooling retain no stale hover or pressed art",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Pool")
        local parent = state:Region(0, 0, 400, 31, 1)
        parent:Hide()
        local header, handle = context:CreateExpandableHeader(parent)
        H.Equal(
            header:IsShown(),
            true,
            "a hidden parent must not permanently hide a newly initialized header"
        )
        H.Equal(header:IsVisible(), false)
        parent:Show()
        H.Equal(header:IsVisible(), true)
        local enters = 0
        header:SetScript("OnEnter", function()
            enters = enters + 1
        end)
        header:RunScript("OnEnter")
        H.Equal(enters, 1)
        H.Equal(header:GetNormalTexture().atlas, "common-button-tertiary-hover")
        header:SetEnabled(false)
        H.Equal(handle.parts.arrow.atlas, "common-dropdown-icon-next-disabled")
        H.Equal(handle.parts.label.textColor[4], 0.5)
        H.Equal(
            header:GetNormalTexture().atlas,
            "common-button-tertiary-normal"
        )
        header:SetEnabled(true)
        H.Equal(handle.parts.arrow.atlas, "common-dropdown-icon-next")
        H.Equal(handle.parts.label.textColor[4], 1)
        local frames, regions, hooks, reads =
            #state.frames, state.regions, state.hooks, state.factorReads

        for _ = 1, 100 do
            header:RunScript("OnEnter")
            header:SetButtonState("PUSHED")
            handle:SetExpanded(false)
            handle:SetShown(false)
            H.Equal(header:GetButtonState(), "NORMAL")
            H.Equal(handle.hovered, false)
            handle:SetExpanded(true)
            header:SetText("Next group")
            handle:SetShown(true)
            H.Equal(
                header:GetNormalTexture().atlas,
                "common-button-tertiary-normal"
            )
        end

        H.Equal(#state.frames, frames)
        H.Equal(state.regions, regions)
        H.Equal(state.hooks, hooks)
        H.Equal(state.factorReads, reads)
        context:UnregisterComponent(header)
        handle:SetShown(true)
        header:RunScript("OnEnter")
        H.Equal(header:IsShown(), false)
        H.Equal(context._components[header], nil)
    end
)

Test(
    "header tokens and opacity remain isolated from other consumers and geometry",
    function()
        local state = H.New()
        local lib = state:Load()
        local first = lib:CreateContext("First")
        local second = lib:CreateContext("Second")
        local parent = state:Region(0, 0, 400, 31, 1)
        local header, handle = first:CreateExpandableHeader(parent)
        local other, otherHandle = second:CreateExpandableHeader(parent)
        local texture = first:CreateSeparator(parent)
        header:SetAllPoints(parent)
        local anchors = header.points
        first:SetTokens({ accent = { r = 0.1, g = 0.4, b = 0.8, a = 0.7 } })
        H.Equal(handle.parts.label.textColor[1], 0.1)
        H.Equal(handle.parts.label.textColor[4], 0.7)
        H.Equal(texture.color[1], 0.1)
        H.Equal(otherHandle.parts.label.textColor[1], 1)
        handle:SetAlpha(0.3)
        H.Equal(header.alpha, 0.3)
        H.Equal(other.alpha, 1)
        handle:SetShown(false)
        first:RefreshGeometry()
        first:SetTokens({ accent = { r = 1, g = 0, b = 0 } })
        H.Equal(header:IsShown(), false)
        H.Equal(
            header.points,
            anchors,
            "appearance and geometry refreshes must preserve consumer anchors"
        )
    end
)

Test(
    "invalid expandable header options fail before allocating controls",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Contracts")
        local parent = state:Region(0, 0, 400, 31, 1)
        local frames, regions = #state.frames, state.regions
        H.Fails(function()
            context:CreateExpandableHeader(nil)
        end)

        for _, options in ipairs({
            false,
            { width = 0 },
            { height = -1 },
            { fontSize = "18" },
            { text = false },
            { font = "" },
            { expanded = 1 },
            { onClick = true },
            { alpha = 2 },
            { colorToken = "missing" },
            { geometryRoot = {} },
            { geometryRoot = state:Region(0, 0, 400, 31, 0.5) },
        }) do
            H.Fails(function()
                context:CreateExpandableHeader(parent, options)
            end)
        end

        H.Equal(#state.frames, frames)
        H.Equal(state.regions, regions)
        local _, handle = context:CreateExpandableHeader(parent)
        H.Fails(function()
            handle:SetExpanded(1)
        end)
    end
)

Test(
    "header handles and visual hooks survive mixed and equal MINOR loading",
    function()
        for _, order in ipairs({
            { 1, 2 },
            { 2, 1 },
            { 1, 1 },
            { 2, 2 },
        }) do
            local state = H.New()
            local lib = state:Load(order[1])
            local context = lib:CreateContext("Upgrade")
            local parent = state:Region(0, 0, 400, 31, 1)
            local clicks = 0
            local header, handle = context:CreateExpandableHeader(parent, {
                onClick = function()
                    clicks = clicks + 1
                end,
            })
            local method = handle.SetExpanded
            local frames, regions, hooks =
                #state.frames, state.regions, state.hooks
            state:Load(order[2])

            if order[2] > order[1] then
                assert(handle.SetExpanded ~= method)
            else
                H.Equal(handle.SetExpanded, method)
            end

            local selected = handle.SetExpanded
            state:Load(1, { "Components/ExpandableHeader.lua" })
            H.Equal(handle.SetExpanded, selected)
            handle:SetExpanded(false)
            header:RunScript("OnEnter")
            H.Equal(
                header:GetNormalTexture().atlas,
                "common-button-tertiary-hover"
            )
            header:RunScript("OnClick", "LeftButton")
            H.Equal(clicks, 1)
            context:SetTokens({ accent = { r = 0.2, g = 0.3, b = 0.4 } })
            H.Equal(handle.parts.label.textColor[1], 0.2)
            H.Equal(#state.frames, frames)
            H.Equal(state.regions, regions)
            H.Equal(state.hooks, hooks)
        end
    end
)

Test(
    "command and square buttons preserve native access, visual states, and pooling",
    function()
        local state = H.New()
        local context =
            state:Load():CreateContext("Controls", { font = "test-font" })
        local parent = state.env.CreateFrame("Frame")
        local button, appearance = context:CreateButton(parent, {
            variant = "square",
            width = 28,
            height = 28,
            icon = "test-icon",
            text = "Action",
        })
        H.Equal(button:GetText(), "Action")
        H.Equal(
            appearance.parts.normal.atlas,
            "common-button-tertiary-square-normal"
        )
        local clicks = 0
        button:SetScript("OnClick", function()
            clicks = clicks + 1
        end)
        button:RunScript("OnClick")
        H.Equal(clicks, 1)
        button:RunScript("OnEnter")
        H.Equal(appearance.parts.hover:IsShown(), true)
        button:RunScript("OnMouseDown", "LeftButton")
        H.Equal(appearance.parts.pressed:IsShown(), true)
        H.Equal(appearance.parts.hover:IsShown(), false)
        button:Hide()
        button:Show()
        H.Equal(appearance.parts.pressed:IsShown(), false)
        button:SetEnabled(false)
        H.Equal(appearance.parts.disabled:IsShown(), true)
        H.Equal(appearance.parts.icon.alpha, 0.5)
        H.Equal(button.Text.textColor[1], 0.5)
        H.Equal(button.Text.textColor[3], 0.5)
        button:SetEnabled(true)
        appearance:SetVariant("command")
        H.Equal(appearance.parts.normal.atlas, "common-button-tertiary-normal")
        context:UnregisterComponent(button)
        appearance:SetShown(true)
        H.Equal(button:IsShown(), false)
    end
)

Test(
    "selected tabs keep their full-sized outsets and take precedence over hover and press",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Tabs")
        local parent = state.env.CreateFrame("Frame")
        local button, appearance = context:CreateTab(parent, {
            text = "Character",
            width = 108,
            height = 28,
        })
        appearance:SetSelected(true)
        button:RunScript("OnEnter")
        button:RunScript("OnMouseDown", "LeftButton")
        H.Equal(
            appearance.parts.normal.atlas,
            "common-button-tertiary-selected"
        )
        H.Equal(appearance.parts.normal.points.TOPLEFT[3], -3)
        H.Equal(appearance.parts.normal.points.BOTTOMRIGHT[4], -3)
        H.Equal(appearance.parts.hover:IsShown(), false)
        H.Equal(appearance.parts.pressed:IsShown(), false)
        appearance:SetSelected(false)
        H.Equal(appearance.parts.normal.points.TOPLEFT[3], 0)
        H.Equal(button.Text.textColor[1], 0.92)
    end
)

Test(
    "header tabs load all nine atlas slices per layer from the winning media root",
    function()
        local rectangles = {
            { 0, 32, 0, 32 },
            { 32.5, 32.5, 0, 32 },
            { 80, 112, 0, 32 },
            { 0, 32, 32.5, 32.5 },
            { 32.5, 32.5, 32.5, 32.5 },
            { 80, 112, 32.5, 32.5 },
            { 0, 32, 48, 64 },
            { 32.5, 32.5, 48, 64 },
            { 80, 112, 48, 64 },
        }

        for _, addonName in ipairs({
            "AirAuras",
            "AnotherConsumer",
            "LibYvSkins-1.0",
        }) do
            local state = H.New()
            state.addonName = addonName
            local lib = state:Load()
            state.addonName = "LaterConsumer"
            state:Load()
            local context = lib:CreateContext("HeaderMedia")
            local parent = state:Region(0, 0, 500, 200, 1)
            local button, handle = context:CreateTab(parent, {
                tabStyle = "header",
                text = "Display",
                width = 116,
            })
            button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
            handle:RefreshGeometry()
            H.Equal(
                button:GetHeight(),
                64,
                "header artwork renders at its full size by default"
            )
            H.Near(handle.parts.headerTab.normal[1]:GetWidth(), 32)
            H.Near(handle.parts.headerTab.normal[3]:GetWidth(), 32)
            H.Near(handle.parts.headerTab.normal[1]:GetHeight(), 32)
            H.Near(handle.parts.headerTab.normal[7]:GetHeight(), 16)
            H.Equal(button:GetText(), "Display")
            H.Equal(button.clickButtons[1], "LeftButtonUp")

            for _, name in ipairs({ "normal", "hover", "pressed", "disabled" }) do
                H.Equal(
                    handle.parts[name],
                    nil,
                    "header tabs must not allocate unused tertiary artwork"
                )
            end

            local folder = addonName == "LibYvSkins-1.0" and ""
                or "Libs\\LibYvSkins-1.0\\"
            local atlas = "Interface\\AddOns\\"
                .. addonName
                .. "\\"
                .. folder
                .. "Media\\Textures\\common-header-tab\\common-header-tab-atlas.tga"

            for name, origin in pairs({
                background = { 0, 64 },
                backgroundAccent = { 112, 0 },
                normal = { 0, 0 },
                hover = { 112, 64 },
                selected = { 112, 128 },
            }) do
                H.Equal(#handle.parts.headerTab[name], 9)

                for index, rectangle in ipairs(rectangles) do
                    local texture = handle.parts.headerTab[name][index]
                    H.Equal(texture:GetTexture(), atlas)
                    H.Equal(texture.texture[2], "CLAMP")
                    H.Equal(texture.texture[3], "CLAMP")
                    H.Equal(
                        texture.texture[4],
                        "LINEAR",
                        "scaled artwork must retain smooth diagonals and glow gradients"
                    )
                    H.Near(
                        texture.texCoord[1],
                        (origin[1] + rectangle[1]) / 256
                    )
                    H.Near(
                        texture.texCoord[2],
                        (origin[1] + rectangle[2]) / 256
                    )
                    H.Near(
                        texture.texCoord[3],
                        (origin[2] + rectangle[3]) / 256
                    )
                    H.Near(
                        texture.texCoord[4],
                        (origin[2] + rectangle[4]) / 256
                    )
                end
            end

            local layers = handle.parts.headerTab
            H.Equal(layers.backgroundAccent[1].layer, "BACKGROUND")
            H.Equal(
                layers.backgroundAccent[1].sublevel
                    > layers.background[1].sublevel,
                true,
                "the accent must sit above the fill and below the border and glow layers"
            )
        end
    end
)

Test(
    "header tabs align every slice to physical pixels through movement resizing and scale changes",
    function()
        local state = H.New()
        local lib = state:Load()
        local context = lib:CreateContext("HeaderGeometry")
        local parent = state:Region(20.25, 30.5, 500, 200, 0.8)
        local button, handle =
            context:CreateTab(parent, { tabStyle = "header", width = 116 })
        button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0.37, -0.29)
        local regions, hooks = state.regions, state.hooks

        for _, slices in pairs(handle.parts.headerTab) do
            for _, texture in ipairs(slices) do
                texture.SetTexture = function()
                    error("geometry refresh must reuse loaded artwork")
                end

                texture.SetTexCoord = function()
                    error("resizing must retain the authored atlas slices")
                end

                local setSize = texture.SetSize

                texture.SetSize = function(self, width, height)
                    H.Equal(
                        width > 0 and height > 0,
                        true,
                        "empty slices must be hidden, never sized to zero"
                    )
                    setSize(self, width, height)
                end
            end
        end

        for _, screenHeight in ipairs({ 1080, 1440, 2160 }) do
            state.height = screenHeight

            for _, scale in ipairs({ 0.5, 0.711111, 0.8, 1, 1.25 }) do
                parent.scale = scale
                lib:RefreshDisplay()

                for _, origin in ipairs({ -30.125, 0.25, 20.5 }) do
                    parent.left, parent.bottom = origin, origin + 0.375
                    context:RefreshGeometry()

                    for _, height in ipairs({ 32, 34, 48, 64, 80.5, 112.75 }) do
                        button:SetHeight(height)

                        for _, width in ipairs({
                            116,
                            300.25,
                            40.1,
                            20.5,
                            180.9,
                        }) do
                            button:SetWidth(width)
                            local bx, by, br, bt = H.Rect(button, screenHeight)
                            local snappedLeft, snappedBottom =
                                math.floor(bx + 0.5), math.floor(by + 0.5)
                            local snappedRight, snappedTop =
                                math.floor(br + 0.5), math.floor(bt + 0.5)

                            for _, slices in pairs(handle.parts.headerTab) do
                                local rectangles, area = {}, 0

                                for index, texture in ipairs(slices) do
                                    if
                                        handle.parts.headerTab.normal[index]:IsShown()
                                    then
                                        H.Aligned(texture, screenHeight)
                                        local x, y, right, top =
                                            H.Rect(texture, screenHeight)
                                        H.Equal(
                                            right > x and top > y,
                                            true,
                                            "visible slices must have positive dimensions"
                                        )
                                        H.Equal(
                                            x >= snappedLeft - 0.00001
                                                and y
                                                    >= snappedBottom - 0.00001,
                                            true
                                        )
                                        H.Equal(
                                            right <= snappedRight + 0.00001
                                                and top
                                                    <= snappedTop + 0.00001,
                                            true
                                        )

                                        for _, rectangle in ipairs(rectangles) do
                                            local overlapWidth = math.min(
                                                right,
                                                rectangle[3]
                                            ) - math.max(
                                                x,
                                                rectangle[1]
                                            )
                                            local overlapHeight = math.min(
                                                top,
                                                rectangle[4]
                                            ) - math.max(
                                                y,
                                                rectangle[2]
                                            )
                                            H.Equal(
                                                overlapWidth <= 0.00001
                                                    or overlapHeight
                                                        <= 0.00001,
                                                true,
                                                "slices must not overlap"
                                            )
                                        end

                                        rectangles[#rectangles + 1] =
                                            { x, y, right, top }
                                        area = area + (right - x) * (top - y)
                                    else
                                        H.Equal(
                                            texture:IsShown(),
                                            false,
                                            "collapsed slices must stay hidden in every layer"
                                        )
                                    end
                                end

                                H.Near(
                                    area,
                                    (snappedRight - snappedLeft)
                                        * (snappedTop - snappedBottom),
                                    "slices must cover the tab without gaps or overflow"
                                )
                                local lx, ly, lr, lt =
                                    H.Rect(slices[1], screenHeight)
                                local rx, ry, rr, rt =
                                    H.Rect(slices[9], screenHeight)
                                H.Equal(math.abs(lx - bx) <= 0.50001, true)
                                H.Equal(math.abs(ry - by) <= 0.50001, true)
                                H.Equal(math.abs(rr - br) <= 0.50001, true)
                                H.Equal(math.abs(lt - bt) <= 0.50001, true)
                                H.Near(
                                    lr - lx,
                                    rr - rx,
                                    "left and right corners must remain symmetric"
                                )
                                H.Near(
                                    lr - lx,
                                    lt - ly,
                                    "top corners must stay square at compact heights"
                                )
                                H.Equal(
                                    math.abs((rt - ry) - (rr - rx) / 2)
                                        <= 0.50001,
                                    true,
                                    "bottom corners must retain their authored proportions within pixel rounding"
                                )
                                local pixelsPerUnit = scale
                                    / (768 / screenHeight)

                                if width >= 64 and height >= 64 then
                                    H.Equal(
                                        math.abs((lr - lx) - 32 * pixelsPerUnit)
                                            <= 0.50001,
                                        true,
                                        "corner width must stay fixed when the tab grows"
                                    )
                                    H.Equal(
                                        math.abs((lt - ly) - 32 * pixelsPerUnit)
                                            <= 0.50001,
                                        true,
                                        "top corner height must stay fixed when the tab grows"
                                    )
                                    H.Equal(
                                        math.abs((rt - ry) - 16 * pixelsPerUnit)
                                            <= 0.75001,
                                        true,
                                        "bottom corner height must stay fixed when the tab grows"
                                    )
                                end
                            end

                            H.Equal(
                                button:GetWidth(),
                                width,
                                "snapping must not resize the caller's button"
                            )
                            H.Equal(button:GetHeight(), height)
                        end
                    end
                end
            end
        end

        H.Equal(state.regions, regions)
        H.Equal(state.hooks, hooks)
    end
)

Test(
    "collapsed header slices stay hidden through interactions and return when space is available",
    function()
        local state = H.New()
        state.height = 768
        local context = state:Load():CreateContext("CollapsedHeader")
        local parent = state:Region(0, 0, 500, 200, 1)
        local button, handle = context:CreateTab(parent, {
            tabStyle = "header",
            width = 116,
            height = 34,
        })
        button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
        handle:RefreshGeometry()
        local layers = handle.parts.headerTab
        H.Equal(
            layers.normal[4]:GetHeight() > 0,
            true,
            "compact tabs must leave room for the vertical stretch"
        )
        local regions, hooks = state.regions, state.hooks

        local function CheckHidden(indices)
            for _, slices in pairs(layers) do
                for _, index in ipairs(indices) do
                    H.Equal(slices[index]:IsShown(), false)
                end
            end
        end

        for _, size in ipairs({
            {
                width = 64,
                height = 64,
                collapsed = { 2, 5, 8 },
            },
            {
                width = 116,
                height = 2,
                collapsed = { 4, 5, 6 },
            },
            {
                width = 0,
                height = 34,
                collapsed = {
                    1,
                    2,
                    3,
                    4,
                    5,
                    6,
                    7,
                    8,
                    9,
                },
            },
            {
                width = 116,
                height = 0,
                collapsed = {
                    1,
                    2,
                    3,
                    4,
                    5,
                    6,
                    7,
                    8,
                    9,
                },
            },
        }) do
            button:SetSize(size.width, size.height)
            CheckHidden(size.collapsed)
            button:RunScript("OnEnter")
            CheckHidden(size.collapsed)
            button:RunScript("OnMouseDown", "LeftButton")
            CheckHidden(size.collapsed)
            handle:SetSelected(true)
            CheckHidden(size.collapsed)
            button:SetEnabled(false)
            CheckHidden(size.collapsed)
            button:SetEnabled(true)
            button:Hide()
            button:Show()
            CheckHidden(size.collapsed)
            context:RequestSkin("flat")
            state:Flush()
            CheckHidden({
                1,
                2,
                3,
                4,
                5,
                6,
                7,
                8,
                9,
            })
            context:RequestSkin("modern")
            state:Flush()
            CheckHidden(size.collapsed)
            button:SetSize(116, 64)

            for index = 1, 9 do
                H.Equal(layers.normal[index]:IsShown(), true)
                H.Equal(layers.selected[index]:IsShown(), true)
            end

            handle:SetSelected(false)
        end

        parent.unresolved = true
        context:RefreshGeometry()
        handle:SetSelected(true)
        CheckHidden({
            1,
            2,
            3,
            4,
            5,
            6,
            7,
            8,
            9,
        })
        parent.unresolved = false
        context:RefreshGeometry()

        for index = 1, 9 do
            H.Equal(layers.selected[index]:IsShown(), true)
        end

        H.Equal(state.regions, regions)
        H.Equal(state.hooks, hooks)
    end
)

Test(
    "header artwork realigns after its window moves without changing the caller's anchors",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("HeaderWindow")
        local parent = state:Region(0, 0, 1000, 800, 0.83)
        local window =
            context:CreateWindow(parent, { minWidth = 400, minHeight = 300 })
        window:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10.25, 30.5)
        local button, handle = context:CreateTab(
            window.body,
            { tabStyle = "header", geometryRoot = window }
        )
        button:SetPoint("TOPLEFT", window.body, "TOPLEFT", 12, -54)
        window:Show()
        window:RunScript("OnDragStart", "LeftButton")
        window:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 43.73, 67.11)
        window:RunScript("OnDragStop", "LeftButton")

        for _, slices in pairs(handle.parts.headerTab) do
            for _, texture in ipairs(slices) do
                H.Aligned(texture, state.height)
            end
        end

        H.Equal(button.points.TOPLEFT[3], 12)
        H.Equal(button.points.TOPLEFT[4], -54)
    end
)

Test(
    "header tab states preserve selection and reset pooled interactions without loading more artwork",
    function()
        local state = H.New()
        local context =
            state:Load():CreateContext("HeaderStates", { font = "test-font" })
        local parent = state:Region(0, 0, 500, 200, 1)
        local button, handle =
            context:CreateTab(parent, { tabStyle = "header" })
        button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
        handle:RefreshGeometry()
        local layers = handle.parts.headerTab
        H.Equal(layers.background[1]:IsShown(), true)
        H.Equal(
            layers.backgroundAccent[1]:IsShown(),
            true,
            "idle tabs retain their inner border"
        )
        H.Near(layers.backgroundAccent[1].color[1], 53 / 255)
        H.Near(layers.backgroundAccent[1].color[2], 47 / 255)
        H.Near(layers.backgroundAccent[1].color[3], 44 / 255)
        H.Near(layers.normal[1].color[1], 162 / 255)
        H.Near(layers.normal[1].color[2], 161 / 255)
        H.Near(layers.normal[1].color[3], 158 / 255)
        H.Equal(layers.normal[1]:IsShown(), true)
        H.Equal(layers.hover[1]:IsShown(), false)
        H.Equal(layers.selected[1]:IsShown(), false)
        H.Equal(
            handle.parts.label.points.CENTER[4],
            -2,
            "header labels need their own optical center"
        )
        local fonts, atlases, regions, hooks =
            state.fontWrites, state.atlasWrites, state.regions, state.hooks

        for _, slices in pairs(layers) do
            for _, texture in ipairs(slices) do
                texture.SetTexture = function()
                    error("interaction must reuse loaded artwork")
                end
            end
        end

        for _ = 1, 10 do
            button:RunScript("OnEnter")
            H.Equal(layers.hover[1]:IsShown(), true)
            H.Equal(layers.backgroundAccent[1]:IsShown(), true)
            H.Equal(
                layers.hover[1].color[4],
                1,
                "enabled hover must preserve the artwork's full opacity"
            )
            button:RunScript("OnMouseDown", "LeftButton")
            H.Equal(layers.hover[1]:IsShown(), true)
            H.Equal(
                layers.hover[1].color[4],
                1,
                "press feedback must not dim the glow"
            )
            H.Equal(handle.parts.label.points.CENTER[4], -3)
            button:Hide()
            button:Show()
            H.Equal(layers.hover[1]:IsShown(), false)
            H.Equal(handle.parts.label.points.CENTER[4], -2)
        end

        H.Equal(state.fontWrites, fonts)
        H.Equal(state.atlasWrites, atlases)
        button:RunScript("OnMouseDown", "LeftButton")
        handle:SetSelected(true)
        H.Equal(layers.selected[1]:IsShown(), true)
        H.Equal(layers.backgroundAccent[1]:IsShown(), true)
        H.Equal(
            layers.selected[1].color[4],
            1,
            "selection must preserve the artwork's full opacity"
        )
        H.Near(layers.selected[1].color[1], 243 / 255)
        H.Near(layers.selected[1].color[2], 221 / 255)
        H.Near(layers.selected[1].color[3], 131 / 255)
        H.Equal(layers.hover[1]:IsShown(), false)
        H.Equal(
            handle.parts.label.points.CENTER[3],
            0,
            "selected labels must not retain a pressed offset"
        )
        H.Equal(handle.parts.label.points.CENTER[4], -2)
        H.Equal(button.Text.textColor[1], 1)
        button:RunScript("OnMouseUp", "LeftButton")
        button:SetEnabled(false)
        H.Equal(layers.selected[1]:IsShown(), true)
        H.Equal(layers.hover[1]:IsShown(), false)
        H.Equal(button.Text.textColor[1], 0.5)
        H.Equal(layers.normal[1].color[4] < 1, true)
        H.Equal(layers.backgroundAccent[1].color[4] < 1, true)
        H.Equal(layers.selected[1].color[4] < 1, true)
        H.Equal(handle.parts.label.points.CENTER[4], -2)
        button:SetEnabled(true)
        handle:SetSelected(false)
        H.Equal(layers.selected[1]:IsShown(), false)
        H.Equal(state.regions, regions)
        H.Equal(state.hooks, hooks)
    end
)

Test(
    "header tabs survive skin round trips and mixed library loading with their click owner intact",
    function()
        for _, order in ipairs({
            { 1, 2 },
            { 2, 1 },
            { 1, 1 },
        }) do
            local state = H.New()
            local context = state:Load(order[1]):CreateContext("HeaderUpgrade")
            local parent = state:Region(0, 0, 400, 200, 1)
            local button, handle = context:CreateTab(
                parent,
                { tabStyle = "header", selected = true }
            )
            button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
            local labelY = handle.parts.label.points.CENTER[4]
            local clicks = 0

            local click = function()
                clicks = clicks + 1
            end

            button:SetScript("OnClick", click)
            local frames, regions, hooks =
                #state.frames, state.regions, state.hooks
            context:RequestSkin("flat")
            state:Load(order[2])
            state:Load(1, {
                "Components/Button.lua",
                "Skins/Modern.lua",
                "Skins/Flat.lua",
            })
            state:Flush()

            for _, slices in pairs(handle.parts.headerTab) do
                for _, texture in ipairs(slices) do
                    H.Equal(texture:IsShown(), false)
                end
            end

            H.Equal(handle.parts.surface.background:IsShown(), true)
            context:RequestSkin("modern")
            state:Flush()
            H.Equal(handle.parts.surface.background:IsShown(), false)
            H.Equal(handle.parts.headerTab.normal[1]:IsShown(), true)
            H.Equal(handle.parts.headerTab.backgroundAccent[1]:IsShown(), true)
            H.Equal(handle.parts.headerTab.selected[1]:IsShown(), true)
            H.Equal(
                handle.parts.label.points.CENTER[4],
                labelY,
                "skin changes must preserve the header baseline"
            )
            H.Equal(handle.parts.normal, nil)
            H.Equal(button:GetScript("OnClick"), click)
            button:RunScript("OnClick", "LeftButton")
            H.Equal(clicks, 1)
            H.Equal(#state.frames, frames)
            H.Equal(state.regions, regions)
            H.Equal(state.hooks, hooks)
        end
    end
)

Test(
    "header tab options reject incompatible factories and variants before allocating controls",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("HeaderContracts")
        local parent = state.env.CreateFrame("Frame")
        local frames, regions = #state.frames, state.regions
        H.Fails(function()
            context:CreateButton(parent, { tabStyle = "header" })
        end)
        H.Fails(function()
            context:CreateCheckbox(parent, { tabStyle = "header" })
        end)
        H.Fails(function()
            context:CreateTab(parent, { tabStyle = "other" })
        end)
        H.Fails(function()
            context:CreateTab(
                parent,
                { tabStyle = "header", variant = "square" }
            )
        end)
        H.Equal(#state.frames, frames)
        H.Equal(state.regions, regions)
        local _, handle = context:CreateTab(parent, { tabStyle = "header" })
        H.Fails(function()
            handle:SetVariant("square")
        end)
        H.Equal(handle.variant, "command")
    end
)

Test(
    "button labels keep their baseline through selection, release, and skin changes",
    function()
        local state = H.New()
        state:PopupLibrary()
        local context = state:Load():CreateContext("LabelStates")
        local button, appearance =
            context:CreateTab(state.env.CreateFrame("Frame"), {
                text = "Character",
                labelOffsetY = 3,
            })

        local function CheckLabel(x, y)
            H.Equal(appearance.parts.label.points.CENTER[3], x)
            H.Equal(appearance.parts.label.points.CENTER[4], y)
            local nativeX, nativeY = button:GetPushedTextOffset()
            H.Equal(nativeX, 0)
            H.Equal(nativeY, 0)
        end

        CheckLabel(0, 3)
        button:RunScript("OnMouseDown", "LeftButton")
        CheckLabel(1, 2)
        context:RefreshAppearance()
        CheckLabel(1, 2)
        appearance:SetSelected(true)
        CheckLabel(0, 3)
        button:RunScript("OnMouseUp", "LeftButton")
        CheckLabel(0, 3)
        appearance:SetSelected(false)
        button:RunScript("OnMouseDown", "LeftButton")
        button:SetEnabled(false)
        CheckLabel(0, 3)
        button:SetEnabled(true)

        context:RequestSkin("flat")
        state:Flush()
        CheckLabel(0, 2)
        button:RunScript("OnMouseDown", "LeftButton")
        CheckLabel(0, 2)
        appearance:SetSelected(true)
        context:RefreshAppearance()
        CheckLabel(0, 2)
        button:RunScript("OnMouseUp", "LeftButton")
        CheckLabel(0, 2)

        context:RequestSkin("modern")
        state:Flush()
        CheckLabel(0, 3)
        appearance:SetSelected(false)
        button:RunScript("OnMouseDown", "LeftButton")
        CheckLabel(1, 2)
        button:RunScript("OnMouseUp", "LeftButton")
        CheckLabel(0, 3)
    end
)

Test(
    "checkboxes retain checked and disabled-checked state during appearance refresh",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Checks")
        local button, appearance = context:CreateCheckbox(
            state.env.CreateFrame("Frame"),
            { checkmarkScale = 1 }
        )
        button:SetChecked(true)
        button:SetEnabled(false)
        context:RefreshAppearance()
        H.Equal(button:GetChecked(), true)
        H.Equal(button.checkedTexture.atlas, "common-icon-checkmark-yellow")
        H.Equal(button.disabledCheckedTexture.desaturated, true)
        H.Equal(appearance.parts.disabled:IsShown(), true)
    end
)

Test(
    "search construction preserves clear, focus, typed values, and tuned native icon anchors",
    function()
        local state = H.New()
        local context =
            state:Load():CreateContext("Search", { font = "test-font" })
        local search, appearance = context:CreateSearchBox(
            state.env.CreateFrame("Frame"),
            { fontSize = 13 }
        )
        search:SetText("retained query")
        search:SetFocus()
        context:RefreshAppearance()
        H.Equal(search:GetText(), "retained query")
        H.Equal(search:HasFocus(), true)
        H.Equal(appearance.parts.focus:IsShown(), true)
        H.Equal(search.searchIcon.points.LEFT[3], 7)
        H.Equal(search.searchIcon.points.LEFT[4], 1)
        H.Equal(search.clearButton.points.RIGHT[3], -4)
        H.Equal(search.clearButton.points.RIGHT[4], 1)
        H.Equal(
            search.Background.atlas,
            "common-button-tertiary-depressed-normal"
        )
        search.clearButton:RunScript("OnClick")
        H.Equal(search:GetText(), "")
        H.Equal(search:HasFocus(), false)
        H.Equal(appearance.parts.focus:IsShown(), false)
    end
)

Test(
    "presentation refresh preserves pooled semantic content, visibility, and icon state",
    function()
        local state = H.New()
        local context = state:Load():CreateContext(
            "Regions",
            { font = "test-font", iconBorder = "custom-border" }
        )
        local parent = state.env.CreateFrame("Frame")
        local text = context:CreateText(parent)
        text:SetText("semantic text")
        text:SetTextColor(0.7, 0.2, 0.9)
        local accent = context:CreateTexture(
            parent,
            { texture = "marker", colorToken = "accent" }
        )
        local icon, appearance = context:CreateIcon(parent)
        icon:SetTexture("item")
        icon:SetDesaturated(true)
        appearance:SetBorderColor(0.2, 0.3, 0.4, 0.8)
        appearance:SetBorderAlpha(0.4)
        icon:Hide()
        appearance:SetBorderShown(false)
        accent:Hide()
        local frames, regions, hooks = #state.frames, state.regions, state.hooks

        for _ = 1, 100 do
            context:SetTokens({ accent = { r = 0.3, g = 0.4, b = 0.5 } })
        end

        H.Equal(text:GetText(), "semantic text")
        H.Equal(text.textColor[1], 0.7)
        H.Equal(accent.color[1], 0.3)
        H.Equal(accent:IsShown(), false)
        H.Equal(icon.texture[1], "item")
        H.Equal(icon.desaturated, true)
        H.Equal(appearance.parts.border.color[1], 0.2)
        H.Equal(appearance.parts.border.alpha, 0.4)
        H.Equal(appearance.parts.border:IsShown(), false)
        H.Equal(#state.frames, frames)
        H.Equal(state.regions, regions)
        H.Equal(state.hooks, hooks)
    end
)

Test(
    "new control factories and preexisting handles survive mixed copies without extra regions or hooks",
    function()
        for _, order in ipairs({
            { 1, 2 },
            { 2, 1 },
            { 1, 1 },
        }) do
            local state = H.New()
            local context = state:Load(order[1]):CreateContext(
                "First",
                { iconBorder = "custom-border" }
            )
            local other = state.lib:CreateContext(
                "Second",
                { iconBorder = "other-border" }
            )
            local parent = state.env.CreateFrame("Frame")
            local _button, handle = context:CreateTab(parent)
            local edit = context:CreateEditBox(parent)
            local _icon, iconHandle = other:CreateIcon(parent)
            edit:SetText("retained")
            local frames, regions, hooks =
                #state.frames, state.regions, state.hooks
            state:Load(order[2])
            state:Load(1, { "Components/Button.lua", "Skins/Modern.lua" })
            handle:SetSelected(true)
            context:RefreshAppearance()
            H.Equal(
                handle.parts.normal.atlas,
                "common-button-tertiary-selected"
            )
            H.Equal(edit:GetText(), "retained")
            H.Equal(iconHandle.parts.border.texture[1], "other-border")
            H.Equal(#state.frames, frames)
            H.Equal(state.regions, regions)
            H.Equal(state.hooks, hooks)
        end
    end
)

Test(
    "hover and press refresh state without repeating fonts or atlas lookups",
    function()
        local state = H.New()
        local context =
            state:Load():CreateContext("States", { font = "test-font" })
        local button = context:CreateButton(
            state.env.CreateFrame("Frame"),
            { icon = "icon", pressIcon = true }
        )
        local fonts, atlases = state.fontWrites, state.atlasWrites

        for _ = 1, 100 do
            button:RunScript("OnEnter")
            button:RunScript("OnMouseDown", "LeftButton")
            button:RunScript("OnMouseUp", "LeftButton")
            button:RunScript("OnLeave")
        end

        H.Equal(state.fontWrites, fonts)
        H.Equal(state.atlasWrites, atlases)
    end
)

Test(
    "native window close and resize art restores without replacing actions",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Chrome")
        local window = context:CreateWindow(
            state.env.CreateFrame("Frame"),
            { minWidth = 400, minHeight = 300 }
        )
        local close, resize =
            window.CloseButton:GetNormalTexture(),
            window.resizeButton:GetNormalTexture()
        local click, drag =
            window.CloseButton:GetScript("OnClick"),
            window.resizeButton:GetScript("OnMouseDown")
        close:SetAtlas("different")
        close:SetAlpha(0.1)
        resize:SetTexture("different")
        context:RefreshAppearance()
        H.Equal(close:GetAtlas(), "native-close")
        H.Equal(close:GetAlpha(), 1)
        H.Equal(resize:GetTexture(), "native-resize")
        H.Equal(window.CloseButton:GetScript("OnClick"), click)
        H.Equal(window.resizeButton:GetScript("OnMouseDown"), drag)
    end
)

Test(
    "scrollbars dispatch visuals and retain native drag and click scripts",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Scroll")
        local bar, _appearance =
            context:CreateScrollBar(state.env.CreateFrame("Frame"))
        local thumb = bar.Track.Thumb
        thumb:OnButtonStateChanged()
        thumb:OnSizeChanged(16, 70)
        thumb:RunScript("OnDragStart")
        bar.Forward:RunScript("OnClick")
        H.Equal(thumb.nativeStateCalls, 2)
        H.Equal(thumb.nativeSize[2], 70)
        H.Equal(thumb.dragging, true)
        H.Equal(bar.Forward.clicked, true)
        H.Equal(bar.Track.Middle:GetAtlas(), "!minimal-scrollbar-track-middle")
        bar:Hide()
        context:RefreshAppearance()
        context:RefreshGeometry()
        H.Equal(bar:IsShown(), false)
    end
)

Test(
    "icons pair border visibility and never revive unregistered pooled visuals",
    function()
        local state = H.New()
        local context =
            state:Load():CreateContext("Icon", { iconBorder = "border" })
        local icon, appearance =
            context:CreateIcon(state.env.CreateFrame("Frame"))
        appearance:SetShown(false)
        H.Equal(appearance.parts.border:IsShown(), false)
        appearance:SetShown(true)
        H.Equal(appearance.parts.border:IsShown(), true)
        context:UnregisterComponent(icon)
        appearance:SetShown(true)
        appearance:SetBorderShown(true)
        H.Equal(icon:IsShown(), false)
        H.Equal(appearance.parts.border:IsShown(), false)
    end
)

Test(
    "glow borders keep animation opacity and reuse all regions on refresh",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Glow")
        local glow, appearance =
            context:CreateGlowBorder(state.env.CreateFrame("Frame"))
        glow:SetAlpha(0.35)
        local regions = state.regions
        context:SetTokens({ accent = { r = 0.2, g = 0.4, b = 0.8 } })
        context:RefreshGeometry()
        H.Equal(appearance.parts.edges.top.color[3], 0.8)
        H.Equal(glow:GetAlpha(), 0.35)
        H.Equal(state.regions, regions)
    end
)

Test(
    "popup integration uses declared parts and preserves external values and drag state",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Popup")
        state:PopupLibrary()
        local popup, appearance =
            context:CreatePopupSlider(state.env.CreateFrame("Button"), {})
        local parts = popup:GetVisualParts()
        popup:SetValue(125)
        popup.dragging = true
        popup:Show()
        context:RefreshAppearance()
        H.Equal(context:GetPopupSliderSupport(), true)
        H.Equal(appearance.parts.visuals, parts)
        H.Equal(parts.thumb:GetAtlas(), "Minimal_SliderBar_Button")
        H.Equal(popup:GetValue(), 125)
        H.Equal(popup:IsInteracting(), true)
        popup.dragging = false
        popup:SetFontAppearance("external-font", "")
        popup.dragging = true
        context:RefreshAppearance()
        H.Equal(parts.font, "external-font")
        popup.dragging = false
        popup:Hide()
        H.Equal(parts.font, "original-font")
    end
)

Test(
    "missing and legacy popup libraries keep Modern optional and expose unsupported styling",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("LegacyPopup")
        local button = state.env.CreateFrame("Button")
        H.Equal(context:CreatePopupSlider(button, {}), nil)
        state:PopupLibrary(true)
        local popup, appearance, reason = context:CreatePopupSlider(button, {})
        H.Equal(popup:GetValue(), 100)
        H.Equal(appearance, nil)
        H.Equal(type(reason), "string")
        H.Equal(context:GetPopupSliderSupport(), false)
    end
)

Test(
    "invalid control factory options fail before allocating frames or regions",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("InvalidControls")
        local parent = state.env.CreateFrame("Frame")
        local frames, regions = #state.frames, state.regions

        for _, factory in ipairs({
            "CreateButton",
            "CreateTab",
            "CreateCheckbox",
            "CreateEditBox",
            "CreateSearchBox",
            "CreateIcon",
            "CreateText",
            "CreateTexture",
            "CreateScrollBar",
            "CreateGlowBorder",
        }) do
            H.Fails(function()
                context[factory](context, parent, false)
            end)
            H.Fails(function()
                context[factory](context, parent, { colorToken = "missing" })
            end)
        end

        H.Fails(function()
            context:CreateIcon(parent)
        end)
        H.Fails(function()
            context:CreateButton(parent, { iconAlpha = 2 })
        end)
        H.Fails(function()
            context:CreateSearchBox(parent, { focusGlow = "yes" })
        end)
        H.Equal(#state.frames, frames)
        H.Equal(state.regions, regions)
    end
)

Test(
    "second-consumer example constructs independent windows and raw controls",
    function()
        local state = H.New()
        local lib = state:Load()
        state.env.UIParent = state:Region(0, 0, 1920, 1080, 1)
        state:PopupLibrary()
        local fixture = assert(loadfile("examples/PixelHarness.lua"))
        setfenv(fixture, state.env)()
        local first, second =
            lib:CreateContext("PixelHarnessA"),
            lib:CreateContext("PixelHarnessB")
        assert(first ~= second)
        local roles = {}

        for _, handle in pairs(first._components) do
            roles[handle.role] = true
        end

        for _, role in ipairs({
            "window",
            "button",
            "editBox",
            "icon",
            "glowBorder",
            "scrollBar",
            "popupSlider",
        }) do
            assert(roles[role], "example must exercise " .. role)
        end

        first:SetTokens({ accent = { r = 0.4, g = 0.5, b = 0.6 } })
        H.Equal(second:GetColor("accent"), 1)
    end
)

Test(
    "region factories preserve requested bounds and separate semantic colors from opacity",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Dimensions")
        local parent = state.env.CreateFrame("Frame")
        local texture, _appearance = context:CreateTexture(parent, {
            texture = "symbol",
            width = 16,
            height = 12,
            alpha = 0.6,
        })
        local text, textAppearance =
            context:CreateText(parent, { width = 80, height = 20 })
        text:SetTextColor(0.5, 0.7, 0.9)
        textAppearance:SetAlpha(0.4)
        context:RefreshAppearance()
        H.Equal(texture:GetWidth(), 16)
        H.Equal(texture:GetHeight(), 12)
        H.Equal(texture:GetAlpha(), 0.6)
        H.Equal(text:GetWidth(), 80)
        H.Equal(text:GetHeight(), 20)
        H.Equal(text:GetAlpha(), 0.4)
        H.Equal(text.textColor[3], 0.9)
    end
)

Test(
    "each renderer constructs and refreshes controls without invoking or aliasing another skin",
    function()
        for _, skin in ipairs({ "modern", "flat" }) do
            local state = H.New()
            local lib = state:Load()
            local context = lib:CreateContext("IndependentRenderer", {
                font = "test-font",
                iconBorder = "test-border",
                tokens = { accent = { r = 0.1, g = 0.8, b = 0.9 } },
            })
            context:RequestSkin(skin)
            state:Flush()
            local renderer = lib._skins[skin]
            local other = lib._skins[skin == "modern" and "flat" or "modern"]

            for method, implementation in pairs(other) do
                H.Equal(
                    renderer[method] == implementation,
                    false,
                    "renderers must not alias sibling methods"
                )

                if type(implementation) == "function" then
                    other[method] = function()
                        error("inactive skin renderer was invoked")
                    end
                end
            end

            -- Construct directly in the selected skin, without another renderer
            -- first supplying its fonts, opacity, artwork, or visual state.
            local parent = state:Region(0, 0, 800, 600, 1)
            local window = context:CreateWindow(parent, {
                minWidth = 400,
                minHeight = 300,
                layouts = EXAMPLE_LAYOUTS,
                onLayout = LayoutExampleToolbar,
            })
            window:SetPoint("CENTER", parent, "CENTER", 0, 0)
            local button, buttonHandle = context:CreateButton(window.header, {
                geometryRoot = window,
                variant = "square",
                icon = lib:GetIconTexture("plus"),
                alpha = 0.7,
            })
            local search = context:CreateSearchBox(
                window.header,
                { geometryRoot = window, alpha = 0.6 }
            )
            SetExampleToolbar(context, window, { button }, search)
            local check, checkHandle =
                context:CreateCheckbox(window.footer, { geometryRoot = window })
            local edit =
                context:CreateEditBox(window.body, { geometryRoot = window })
            local header, headerHandle = context:CreateExpandableHeader(
                window.body,
                { geometryRoot = window, alpha = 0.8 }
            )
            local tab, tabHandle = context:CreateTab(
                window.body,
                { geometryRoot = window, text = "Tab" }
            )
            local titleTab, titleTabHandle = context:CreateTab(window.body, {
                geometryRoot = window,
                tabStyle = "header",
                text = "Display",
                height = 34,
            })
            titleTab:SetPoint("TOPLEFT", window.body, "TOPLEFT", 12, -12)
            local icon =
                context:CreateIcon(window.body, { geometryRoot = window })
            icon:SetTexture("item-art")
            icon:SetVertexColor(0.2, 0.3, 0.4, 1)
            local text = context:CreateText(
                window.body,
                { geometryRoot = window, text = "Label" }
            )
            local texture = context:CreateTexture(
                window.body,
                { geometryRoot = window, colorToken = "accent" }
            )
            context:CreateScrollBar(window.body, { geometryRoot = window })
            context:CreateGlowBorder(window.body, { geometryRoot = window })
            window:Show()
            check:SetChecked(true)
            edit:SetText("keep me")
            edit:SetFocus()
            search:SetText("search")
            tabHandle:SetSelected(true)
            titleTabHandle:SetSelected(true)
            headerHandle:SetExpanded(false)
            context:RefreshAppearance()
            context:RefreshGeometry(window)
            window.CloseButton:RunScript("OnEnter")
            window.resizeButton:RunScript("OnEnter")

            H.Equal(buttonHandle.parts.label.font[1], "test-font")
            H.Equal(search.font[1], "test-font")
            H.Equal(search.Instructions.font[1], "test-font")
            H.Equal(edit.font[1], "test-font")
            H.Equal(text.font[1], "test-font")
            H.Near(button:GetAlpha(), 0.7)
            H.Near(search:GetAlpha(), 0.6)
            H.Near(header:GetAlpha(), 0.8)
            H.Equal(check:GetChecked(), true)
            H.Equal(
                checkHandle.parts.checked:GetAtlas(),
                "common-icon-checkmark-yellow"
            )
            H.Equal(edit:GetText(), "keep me")
            H.Equal(edit:HasFocus(), true)
            H.Equal(search:GetText(), "search")
            H.Equal(tab:GetText(), "Tab")
            H.Equal(titleTab:GetText(), "Display")
            H.Equal(titleTabHandle.parts.label.font[1], "test-font")
            H.Equal(titleTabHandle.parts.normal, nil)
            H.Equal(
                titleTabHandle.parts.surface.background:IsShown(),
                skin == "flat"
            )

            for name, slices in pairs(titleTabHandle.parts.headerTab) do
                for _, slice in ipairs(slices) do
                    H.Equal(
                        slice:IsShown(),
                        skin == "modern" and name ~= "hover"
                    )
                end
            end

            H.Equal(headerHandle:IsExpanded(), false)
            H.Near(headerHandle.parts.label.textColor[1], 0.1)
            H.Near(texture.colorTexture[1], 0.1)
            H.Near(icon.color[1], 0.2)
            H.Equal(
                buttonHandle.parts.normal:GetAtlas(),
                skin == "modern" and "common-button-tertiary-square-normal"
                    or nil
            )

            local fonts, atlases, regions, hooks =
                state.fontWrites, state.atlasWrites, state.regions, state.hooks
            button:RunScript("OnEnter")
            button:RunScript("OnMouseDown", "LeftButton")
            button:RunScript("OnMouseUp", "LeftButton")
            button:RunScript("OnLeave")
            button:SetEnabled(false)
            H.Equal(buttonHandle.parts.icon:GetAlpha(), 0.5)
            titleTab:RunScript("OnEnter")
            titleTab:RunScript("OnMouseDown", "LeftButton")
            titleTab:RunScript("OnMouseUp", "LeftButton")
            titleTab:SetEnabled(false)
            titleTab:SetHeight(48)
            H.Equal(state.fontWrites, fonts)
            H.Equal(state.atlasWrites, atlases)
            H.Equal(state.regions, regions)
            H.Equal(state.hooks, hooks)
        end
    end
)

Test(
    "Flat selection is coalesced, context-local, combat deferred, and cancellable",
    function()
        local state = H.New()
        local lib = state:Load()
        local first, second =
            lib:CreateContext("First"), lib:CreateContext("Second")
        local before, applied = 0, 0
        first:SetSkinCallbacks({
            beforeApply = function()
                before = before + 1
            end,
            onApplied = function()
                applied = applied + 1
            end,
        })
        first:RequestSkin("flat")
        first:RequestSkin("modern")
        first:RequestSkin("flat")
        H.Equal(#state.timers, 1)
        H.Equal(first:GetAppliedSkin(), "modern")
        state.combat = true
        state:Flush()
        local requested, current, reason = first:GetSkinStatus()
        H.Equal(requested, "flat")
        H.Equal(current, "modern")
        H.Equal(reason, "combat")
        H.Equal(#state.timers, 0, "no combat polling")
        H.Equal(before, 0)
        state.combat = false
        lib._skinEventFrame:RunScript("OnEvent", "PLAYER_REGEN_ENABLED")
        state:Flush()
        H.Equal(first:GetAppliedSkin(), "flat")
        H.Equal(second:GetAppliedSkin(), "modern")
        H.Equal(before, 1)
        H.Equal(applied, 1)
        first:RequestSkin("modern")
        first:RequestSkin("flat")
        state:Flush()
        H.Equal(
            applied,
            1,
            "returning to the applied skin cancels pending work"
        )
        H.Equal(select(3, first:GetSkinStatus()), nil)
        H.Fails(function()
            first:RequestSkin("missing")
        end)
    end
)

Test(
    "two windows round-trip compact chrome without replacing controls or changing outer geometry",
    function()
        local state = H.New()
        local context = state:Load():CreateContext(
            "Windows",
            { font = "test-font", iconBorder = "border" }
        )
        local parent = state:Region(0, 0, 1920, 1080, 1)
        local windows = {}

        for index = 1, 2 do
            local window = context:CreateWindow(parent, {
                minWidth = 420,
                minHeight = 360,
                layouts = EXAMPLE_LAYOUTS,
                onLayout = LayoutExampleToolbar,
            })
            window:SetPoint(
                "BOTTOMLEFT",
                parent,
                "BOTTOMLEFT",
                13.17 + index * 100,
                19.31
            )
            window:SetScale(index == 1 and 0.75 or 1.5)
            window:SetSize(700, 600)
            local cog = context:CreateButton(window.header, {
                geometryRoot = window,
                variant = "square",
                width = 28,
                height = 28,
            })
            local scale = context:CreateButton(window.header, {
                geometryRoot = window,
                variant = "square",
                width = 28,
                height = 28,
            })
            local tab, tabHandle = context:CreateTab(window.header, {
                geometryRoot = window,
                text = "Character",
                width = 108,
                height = 28,
                selected = true,
            })
            local search = context:CreateSearchBox(
                window.header,
                { geometryRoot = window }
            )
            SetExampleToolbar(context, window, { cog, scale, tab }, search)
            window:Show()
            search:SetText("keystone")
            search:SetFocus()
            windows[index] = {
                frame = window,
                search = search,
                tab = tabHandle,
                height = window.body:GetHeight(),
                close = window.CloseButton:GetScript("OnClick"),
                width = window:GetWidth(),
                left = window:GetRect(),
                resize = window.resizeButton:GetScript("OnMouseDown"),
            }
            H.Equal(context:GetWindowBodyReserve(window), 19)
        end

        local frames, regions, hooks = #state.frames, state.regions, state.hooks

        for _ = 1, 3 do
            context:RequestSkin("flat")
            state:Flush()

            for _, data in ipairs(windows) do
                local frame = data.frame
                H.Equal(frame.TitleContainer:IsShown(), false)
                H.Equal(frame.PortraitContainer:GetAlpha(), 0)
                H.Equal(frame.body:GetHeight(), data.height + 19)
                H.Equal(frame.CloseButton:GetWidth(), 28)
                H.Equal(data.search:GetHeight(), 28)
                H.Equal(data.search:GetText(), "keystone")
                H.Equal(data.search:HasFocus(), true)
                H.Equal(frame:GetWidth(), data.width)
                H.Equal(frame:GetRect(), data.left)
                H.Equal(context:GetWindowBodyReserve(frame), 0)
                data.tab.target:RunScript("OnEnter")
                data.tab.target:RunScript("OnMouseDown", "LeftButton")
                H.Equal(data.tab.selected, true)
                H.Equal(
                    data.tab.parts.surface.background.color[1],
                    0.12,
                    "selected state wins over hover/press"
                )
                H.Equal(data.tab.parts.normal:GetAlpha(), 0)
                H.Equal(frame.CloseButton:GetScript("OnClick"), data.close)
                H.Equal(
                    frame.resizeButton:GetScript("OnMouseDown"),
                    data.resize
                )

                for _, edge in
                    ipairs(
                        context._components[frame].parts.surface.border.edges
                    )
                do
                    H.Aligned(edge, state.height)
                end
            end

            context:RequestSkin("modern")
            state:Flush()

            for _, data in ipairs(windows) do
                H.Equal(data.frame.TitleContainer:IsShown(), true)
                H.Equal(data.frame.PortraitContainer:GetAlpha(), 1)
                H.Equal(data.frame.body:GetHeight(), data.height)
                H.Equal(data.frame.CloseButton:GetWidth(), 24)
                H.Equal(data.tab.parts.normal:GetAlpha(), 1)
                H.Equal(
                    data.tab.parts.normal:GetAtlas(),
                    "common-button-tertiary-selected"
                )
                H.Equal(data.search:HasFocus(), true)
            end
        end

        H.Equal(#state.frames, frames)
        H.Equal(state.regions, regions)
        H.Equal(state.hooks, hooks)
    end
)

Test(
    "Flat surfaces and one-pixel icon borders stay aligned through scrolling and display scales",
    function()
        local state = H.New()
        local lib = state:Load()
        local context = lib:CreateContext("Pixels", { iconBorder = "border" })
        local parent = state:Region(0.31, -7.13, 400, 300, 1)
        local icon, iconHandle = context:CreateIcon(parent)
        local edit, editHandle = context:CreateEditBox(parent)
        icon:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 20)
        edit:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 50, 20)
        iconHandle:SetBorderColor(0.2, 0.6, 0.9, 0.8)
        iconHandle:SetBorderAlpha(0.5)
        icon:SetDesaturated(true)
        context:RequestSkin("flat")
        state:Flush()
        local frames, regions, hooks, fonts, atlases =
            #state.frames,
            state.regions,
            state.hooks,
            state.fontWrites,
            state.atlasWrites

        for _, height in ipairs({ 1080, 1440, 2160 }) do
            state.height = height

            for _, scale in ipairs({ 0.32, 0.5, 0.75, 1, 1.25, 1.5 }) do
                parent.scale = scale
                lib:RefreshDisplay()

                for _ = 1, 40 do
                    parent.bottom = parent.bottom + 0.13
                    iconHandle:RefreshGeometry()
                    editHandle:RefreshGeometry()
                    local iconLeft, iconBottom, iconRight, iconTop =
                        H.Rect(icon, height)
                    H.Equal(icon:GetWidth(), 23)
                    H.Equal(icon:GetHeight(), 23)

                    for edgeIndex, edge in
                        ipairs(iconHandle.parts.flatBorder.edges)
                    do
                        H.Aligned(edge, height)
                        local left, bottom, right, top = H.Rect(edge, height)
                        H.Near(
                            edgeIndex < 3 and top - bottom or right - left,
                            1
                        )
                        H.Near(edge.color[4], 0.4)

                        if edgeIndex == 1 then
                            assert(
                                bottom >= iconTop - 0.00001,
                                "top stroke must remain above the art"
                            )
                        elseif edgeIndex == 2 then
                            assert(
                                top <= iconBottom + 0.00001,
                                "bottom stroke must remain below the art"
                            )
                        elseif edgeIndex == 3 then
                            assert(
                                right <= iconLeft + 0.00001,
                                "left stroke must remain outside the art"
                            )
                        else
                            assert(
                                left >= iconRight - 0.00001,
                                "right stroke must remain outside the art"
                            )
                        end
                    end

                    for edgeIndex, edge in
                        ipairs(editHandle.parts.surface.border.edges)
                    do
                        H.Aligned(edge, height)
                        local left, bottom, right, top = H.Rect(edge, height)
                        H.Near(
                            edgeIndex < 3 and top - bottom or right - left,
                            1
                        )
                    end
                end
            end
        end

        H.Equal(icon.desaturated, true)
        H.Equal(#state.frames, frames)
        H.Equal(state.regions, regions)
        H.Equal(state.hooks, hooks)
        H.Equal(state.fontWrites, fonts)
        H.Equal(state.atlasWrites, atlases)
        iconHandle:SetShown(false)

        for _, edge in ipairs(iconHandle.parts.flatBorder.edges) do
            H.Equal(edge:IsShown(), false)
        end

        iconHandle:SetShown(true)

        for _, edge in ipairs(iconHandle.parts.flatBorder.edges) do
            H.Equal(edge:IsShown(), true)
        end

        context:RequestSkin("modern")
        state:Flush()
        H.Equal(iconHandle.parts.border:IsShown(), true)
        H.Equal(iconHandle.parts.flatBorder.edges[1]:IsShown(), false)
    end
)

Test(
    "icon outsets preserve footer footprints and clip at viewport edges without overlapping corners",
    function()
        local state = H.New()
        local lib = state:Load()
        local context =
            lib:CreateContext("IconBounds", { iconBorder = "border" })
        local parent = state:Region(0.17, 0.31, 300, 200, 1)
        local clip = state:Region(0, 0, 180, 180, 1)
        local icon, handle = context:CreateIcon(parent, {
            width = 18,
            clip = clip,
            borderLayer = "BORDER",
            borderSublevel = 2,
        })
        icon:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 20, 20)
        context:RequestSkin("flat")
        state:Flush()
        local modernLeft, modernBottom, modernRight, modernTop =
            H.Rect(handle.parts.border, state.height)
        local border = handle.parts.flatBorder

        for index, edge in ipairs(border.edges) do
            H.Equal(edge.layer, "BORDER")
            H.Equal(edge.sublevel, 2)
            H.Aligned(edge, state.height)
            local left, bottom, right, top = H.Rect(edge, state.height)
            assert(
                left >= modernLeft
                    and bottom >= modernBottom
                    and right <= modernRight
                    and top <= modernTop
            )

            for otherIndex = index + 1, #border.edges do
                local l, b, r, t =
                    H.Rect(border.edges[otherIndex], state.height)
                assert(
                    math.min(right, r) <= math.max(left, l) + 0.00001
                        or math.min(top, t) <= math.max(bottom, b) + 0.00001,
                    "border corners must not overlap"
                )
            end
        end

        icon:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 166, -5)
        handle:RefreshGeometry()
        local clipLeft, clipBottom, clipRight, clipTop =
            H.Rect(clip, state.height)

        for _, edge in ipairs(border.edges) do
            if edge:IsShown() then
                local left, bottom, right, top = H.Rect(edge, state.height)
                assert(
                    left >= clipLeft
                        and bottom >= clipBottom
                        and right <= clipRight
                        and top <= clipTop
                )
            end
        end

        H.Fails(function()
            border:Layout(handle.root.metrics, 2, nil, -1)
        end)
        H.Fails(function()
            border:Layout(handle.root.metrics, 2, nil, "3")
        end)
    end
)

Test(
    "moving resizing and scaling park skin changes until their end notifications",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Interactions")
        state:PopupLibrary()
        local parent = state:Region(0, 0, 1920, 1080, 1)
        local window = context:CreateWindow(parent, {
            minWidth = 420,
            minHeight = 360,
            layouts = EXAMPLE_LAYOUTS,
            onLayout = LayoutExampleToolbar,
        })
        local popup = context:CreatePopupSlider(window, {})
        window:Show()
        window.TitleContainer:RunScript("OnDragStart")
        context:RequestSkin("flat")
        state:Flush()
        H.Equal(select(3, context:GetSkinStatus()), "interaction")
        H.Equal(#state.timers, 0)
        window.TitleContainer:RunScript("OnDragStop")
        state:Flush()
        H.Equal(context:GetAppliedSkin(), "flat")
        window.resizeButton:RunScript("OnMouseDown")
        context:RequestSkin("modern")
        state:Flush()
        H.Equal(context:GetAppliedSkin(), "flat")
        window.resizeButton:RunScript("OnMouseUp")
        state:Flush()
        H.Equal(context:GetAppliedSkin(), "modern")
        popup.dragging = true
        popup:Show()
        context:RequestSkin("flat")
        state:Flush()
        H.Equal(select(3, context:GetSkinStatus()), "interaction")
        H.Equal(popup:IsShown(), true)
        H.Equal(#state.timers, 0)
        popup.dragging = false
        popup:Hide()
        state:Flush()
        H.Equal(context:GetAppliedSkin(), "flat")
        H.Equal(popup:GetValue(), 100)
    end
)

Test(
    "legacy popup contracts reject Flat before changing any component",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Legacy")
        state:PopupLibrary(true)
        context:CreatePopupSlider(state.env.CreateFrame("Button"), {})
        local _button, handle =
            context:CreateButton(state.env.CreateFrame("Frame"))
        context:RequestSkin("flat")
        state:Flush()
        H.Equal(context:GetAppliedSkin(), "modern")
        H.Equal(select(3, context:GetSkinStatus()), "unavailable")
        H.Equal(handle.parts.normal:GetAtlas(), "common-button-tertiary-normal")
        context:RequestSkin("modern")
        H.Equal(select(3, context:GetSkinStatus()), nil)
    end
)

Test(
    "Flat button focus checkbox and accordion states restore cleanly and reuse pooled art",
    function()
        local state = H.New()
        state.atlasSizes["common-icon-checkmark-yellow"] = { 24, 24 }
        local context =
            state:Load():CreateContext("States", { font = "test-font" })
        local parent = state:Region(0, 0, 500, 400, 1)
        local button, buttonHandle =
            context:CreateButton(parent, { icon = "icon" })
        local check, checkHandle =
            context:CreateCheckbox(parent, { checkmarkScale = 0.75 })
        local edit, editHandle = context:CreateEditBox(parent)
        local header, headerHandle = context:CreateExpandableHeader(parent)
        button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
        check:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 40)
        edit:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 80)
        header:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 120)
        check:SetChecked(true)
        local checkWidth, checkHeight = checkHandle.parts.checked:GetSize()
        edit:SetFocus()
        headerHandle:SetExpanded(false)
        context:RequestSkin("flat")
        state:Flush()
        H.Equal(check:GetChecked(), true)
        H.Equal(checkHandle.parts.checked:GetScale(), 0.75)
        H.Equal(checkHandle.parts.checked:GetWidth(), checkWidth)
        H.Equal(checkHandle.parts.checked:GetHeight(), checkHeight)
        H.Equal(
            checkHandle.parts.checked:GetAtlas(),
            "common-icon-checkmark-yellow"
        )
        H.Equal(checkHandle.parts.checked.points.CENTER[3], 2)
        H.Near(
            checkHandle.parts.checked.points.CENTER[4],
            2 - state.lib.Pixel.GetPhysicalSize(checkHandle.parts.checked, 1)
        )
        H.Equal(editHandle.parts.focus:IsShown(), false)
        H.Equal(editHandle.parts.surface.border.edges[1].color[1], 1)
        local fonts, atlases, regions, hooks =
            state.fontWrites, state.atlasWrites, state.regions, state.hooks

        for _ = 1, 100 do
            button:RunScript("OnEnter")
            button:RunScript("OnMouseDown", "LeftButton")
            button:RunScript("OnMouseUp", "LeftButton")
            button:RunScript("OnLeave")
        end

        H.Equal(state.fontWrites, fonts)
        H.Equal(state.atlasWrites, atlases)
        H.Equal(state.regions, regions)
        H.Equal(state.hooks, hooks)
        button:SetEnabled(false)
        H.Equal(buttonHandle.parts.surface.border.edges[1].color[1], 0.25)
        header:RunScript("OnMouseDown", "LeftButton")
        header:Hide()
        H.Equal(headerHandle.pressed, false)
        headerHandle:SetShown(true)
        H.Equal(headerHandle:IsExpanded(), false)
        context:RequestSkin("modern")
        state:Flush()
        H.Equal(check:GetChecked(), true)
        H.Equal(checkHandle.parts.checked:GetScale(), 0.75)
        H.Equal(edit:HasFocus(), true)
        H.Equal(editHandle.parts.focus:IsShown(), true)
        H.Equal(headerHandle.parts.normal:GetAlpha(), 1)
        H.Equal(button:IsEnabled(), false)
    end
)

Test(
    "Flat scrollbar popup and glow restoration preserves native actions and hidden states",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("ExternalArt")
        state:PopupLibrary()
        local parent = state:Region(0, 0, 500, 400, 1)
        local bar, _barHandle = context:CreateScrollBar(parent)
        local popup, popupHandle = context:CreatePopupSlider(
            state.env.CreateFrame("Button", nil, parent),
            {}
        )
        popup:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 40, 80)
        popup:SetSize(48, 180)
        local glow, glowHandle = context:CreateGlowBorder(parent)
        glow:SetAlpha(0.35)
        local nativeDrag = bar.Track.Thumb:GetScript("OnDragStart")
        context:RequestSkin("flat")
        state:Flush()
        H.Equal(bar.Track.Middle:GetAlpha(), 0)
        H.Equal(bar.Track.Thumb.Middle:GetAlpha(), 0)
        H.Equal(bar.Track.Thumb:GetScript("OnDragStart"), nativeDrag)
        bar.Track.Thumb:OnSizeChanged(8, 100)
        bar.Track.Thumb:RunScript("OnDragStart")
        bar.Forward:RunScript("OnClick")
        H.Equal(bar.Track.Thumb.dragging, true)
        H.Equal(bar.Forward.clicked, true)
        popup:Show()
        state:Flush()
        H.Equal(popup:GetBackdrop(), nil)
        H.Equal(popupHandle.parts.surface.background:IsShown(), true)
        H.Equal(glowHandle.parts.edges.top:IsShown(), false)
        H.Equal(glowHandle.parts.surface.border.edges[1]:IsShown(), true)
        bar:Hide()
        context:RequestSkin("modern")
        state:Flush()
        H.Equal(popup:IsShown(), false)
        H.Equal(popup:GetBackdrop().bgFile, "native-background")
        H.Equal(
            popup:GetVisualParts().thumb:GetAtlas(),
            "Minimal_SliderBar_Button"
        )
        H.Equal(bar:IsShown(), false)
        H.Equal(bar.Track.Middle:GetAlpha(), 1)
        H.Equal(bar.Track.Thumb.Middle:GetAlpha(), 1)
        H.Equal(bar.Back.Texture.rotation, 0)
        H.Equal(glow:GetAlpha(), 0.35)
        H.Equal(glowHandle.parts.edges.top:IsShown(), true)
        H.Equal(glowHandle.parts.surface.border.edges[1]:IsShown(), false)
    end
)

Test(
    "compact windows have symmetric padding, an outlined inset and left-aligned controls",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Spacing")
        local parent = state:Region(0, 0, 1920, 1080, 1)
        local window = context:CreateWindow(parent, {
            minWidth = 300,
            minHeight = 200,
            layouts = EXAMPLE_LAYOUTS,
            onLayout = LayoutExampleToolbar,
        })
        window:SetSize(700, 500)
        window:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 13, 27)
        local button =
            context:CreateButton(window.header, { width = 28, height = 28 })
        local search = context:CreateSearchBox(window.header)
        SetExampleToolbar(context, window, { button }, search)
        window:Show()
        H.Equal(context:GetWindowBodyWidthOverhead(window), 16)
        context:RequestSkin("flat")
        state:Flush()
        local left, bottom, width, height = window:GetRect()
        local hLeft, hBottom, hWidth, hHeight = window.header:GetRect()
        H.Near(hLeft - left, 8)
        H.Near(left + width - hLeft - hWidth, 8)
        H.Near(bottom + height - hBottom - hHeight, 8)
        local fLeft, fBottom, fWidth, fHeight = window.footer:GetRect()
        H.Near(fLeft - left, 8)
        H.Near(
            left + width - fLeft - fWidth,
            24,
            "footer reserves the corner grip plus outer padding"
        )
        H.Near(fBottom - bottom, 8)
        H.Near(fHeight, 24)
        local iLeft, iBottom, iWidth, iHeight = window.Inset:GetRect()
        H.Near(iLeft - left, 8)
        H.Near(left + width - iLeft - iWidth, 8)
        H.Near(hBottom - iBottom - iHeight, 4)
        H.Near(iBottom - fBottom - fHeight, 4)
        H.Near(button:GetRect() - hLeft, 0)
        H.Equal(context:GetWindowBodyWidthOverhead(window), 20)
        local contentSurface = context._components[window].parts.bodySurface

        for _, edge in ipairs(contentSurface.border.edges) do
            H.Equal(edge:IsShown(), true)
            H.Aligned(edge, state.height)
        end

        H.Equal(
            context._components[window.resizeButton].parts.surface,
            nil,
            "resize glyph has no box"
        )
        context:RequestSkin("modern")
        state:Flush()
        H.Equal(window.header.points.TOPLEFT[3], 4)
        H.Equal(window.header.points.TOPLEFT[4], 0)
        H.Near(window.toolbar:GetRect() - window:GetRect(), 58)
        H.Equal(window.footer.points.BOTTOMLEFT[3], 3)
        H.Equal(window.footer.points.BOTTOMLEFT[4], 4)
        H.Equal(window.footer.points.BOTTOMRIGHT[3], -15)
        H.Equal(context:GetWindowBodyWidthOverhead(window), 16)

        for _, edge in ipairs(contentSurface.border.edges) do
            H.Equal(edge:IsShown(), false)
        end
    end
)

Test(
    "background dragging works in both skins without claiming child actions or moving in combat",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("BackgroundDrag")
        local parent = state:Region(0, 0, 1920, 1080, 1)
        local stops, clicks = 0, 0
        local window = context:CreateWindow(parent, {
            minWidth = 300,
            minHeight = 200,
            layouts = EXAMPLE_LAYOUTS,
            onLayout = LayoutExampleToolbar,
            onMoveStopped = function()
                stops = stops + 1
            end,
        })
        local region = state.env.CreateFrame("Frame", nil, window.body)

        local mouseUp = function()
            clicks = clicks + 1
        end

        region:SetScript("OnMouseUp", mouseUp)
        context:RegisterWindowDragRegion(window, region)
        local hooks = state.hooks
        context:RegisterWindowDragRegion(window, region)
        H.Equal(state.hooks, hooks, "registration is idempotent")
        H.Equal(region:GetScript("OnMouseUp"), mouseUp)
        local action = state.env.CreateFrame("Button", nil, region)

        local pickup = function(self)
            self.pickedUp = true
        end

        action:SetScript("OnDragStart", pickup)
        H.Fails(function()
            context:RegisterWindowDragRegion(window, action)
        end)
        H.Equal(action:GetScript("OnDragStart"), pickup)

        for _, skin in ipairs({ "modern", "flat" }) do
            context:RequestSkin(skin)
            state:Flush()
            window:Show()

            for _, background in ipairs({
                window,
                window.TitleContainer,
                window.header,
                window.Inset,
                window.body,
                window.footer,
                region,
            }) do
                background:RunScript("OnDragStart", "LeftButton")
                H.Equal(window.moving, true)
                local before = stops
                background:RunScript("OnDragStop", "LeftButton")
                background:RunScript("OnDragStop", "LeftButton")
                H.Equal(stops, before + 1)
                H.Equal(window.moving, false)
            end

            action:RunScript("OnDragStart", "LeftButton")
            H.Equal(action.pickedUp, true)
            H.Equal(window.moving, false)
            state.combat = true
            region:RunScript("OnDragStart", "LeftButton")
            H.Equal(window.moving, false)
            state.combat = false
            region:RunScript("OnDragStart", "LeftButton")
            window:Hide()
            H.Equal(window.moving, false)
        end

        region:RunScript("OnMouseUp")
        H.Equal(clicks, 1)
    end
)

Test(
    "Flat text baselines and action colors restore without tinting semantic item art",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Optics", {
            iconBorder = "border",
            tokens = { accent = { r = 0.1, g = 0.8, b = 0.9 } },
        })
        local parent = state:Region(0, 0, 1920, 1080, 1)
        local window = context:CreateWindow(parent, {
            minWidth = 400,
            minHeight = 300,
            layouts = EXAMPLE_LAYOUTS,
            onLayout = LayoutExampleToolbar,
        })
        local _tab, tabHandle = context:CreateTab(window.header)
        local search = context:CreateSearchBox(window.header)
        local minus, minusHandle = context:CreateButton(
            window.footer,
            { icon = state.lib:GetIconTexture("minus") }
        )
        local purchase = state.env.CreateFrame("Button", nil, window.footer)
        local purchaseIcon = context:CreateIcon(purchase, {
            actionIcon = true,
            crop = false,
            width = 18,
        })
        purchaseIcon:SetTexture(state.lib:GetIconTexture("plus"))
        local item = context:CreateIcon(window.body)
        item:SetVertexColor(0.8, 0.7, 0.6, 0.9)
        item:SetDesaturated(true)
        local clearClick = search.clearButton:GetScript("OnClick")
        window:Show()
        search:SetText("potion")
        search:SetFocus()
        context:RequestSkin("flat")
        state:Flush()
        H.Equal(tabHandle.parts.label.points.CENTER[4], 0)
        H.Equal(select(3, search:GetTextInsets()), 0)
        H.Equal(search.Instructions.points.TOPLEFT[4], 0)
        H.Equal(search.Instructions.points.BOTTOMRIGHT[4], 0)
        H.Equal(search.clearButton.points.RIGHT[4], 0)

        for _, icon in ipairs({
            minusHandle.parts.icon,
            purchaseIcon,
            search.clearButton.Icon,
            context._components[window.CloseButton].parts.icon,
        }) do
            H.Near(icon.color[1], 0.1)
            H.Near(icon.color[2], 0.8)
            H.Near(icon.color[3], 0.9)
        end

        H.Equal(purchaseIcon.desaturated, true)
        purchase:SetEnabled(false)
        purchase:SetEnabled(true)
        H.Equal(purchaseIcon.desaturated, true)
        minus:SetEnabled(false)
        H.Equal(minusHandle.parts.icon:GetAlpha(), 0.5)
        H.Equal(search.clearButton:GetScript("OnClick"), clearClick)
        H.Equal(search.clearButton.Icon:GetAlpha(), 0.5)
        H.Equal(search:GetText(), "potion")
        H.Equal(search:HasFocus(), true)
        H.Near(item.color[1], 0.8)
        H.Equal(item.desaturated, true)
        context:RequestSkin("modern")
        state:Flush()
        H.Equal(tabHandle.parts.label.points.CENTER[4], 1)
        H.Equal(select(3, search:GetTextInsets()), 0)
        H.Equal(search.Instructions.points.TOPLEFT[4], 0)
        H.Equal(search.clearButton.Icon.color[1], 1)
        H.Equal(search.clearButton.points.RIGHT[4], 1)
        H.Equal(minusHandle.parts.icon.color[1], 0.5)
        minus:SetEnabled(true)
        minus:RunScript("OnEnter")

        for _, icon in ipairs({ minusHandle.parts.icon, purchaseIcon }) do
            H.Equal(icon.color[1], 1)
            H.Near(icon.color[2], 0.82)
            H.Equal(icon.color[3], 0)
        end

        H.Equal(purchaseIcon.color[1], 1)
        H.Equal(purchaseIcon.desaturated, false)
        purchase:SetEnabled(false)
        H.Equal(purchaseIcon.desaturated, true)
        H.Equal(purchaseIcon.color[1], 0.5)
        H.Near(item.color[1], 0.8)
        H.Equal(item.desaturated, true)
    end
)

Test(
    "Flat steppers center directional glyphs and restore native size and anchors",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("ScrollCenter")
        local parent = state:Region(0, 0, 500, 400, 1)
        local bar, _handle = context:CreateScrollBar(parent)
        bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -2)
        bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 2)
        context:RequestSkin("flat")
        state:Flush()

        for _, button in ipairs({ bar.Back, bar.Forward }) do
            local bx, by, bw, bh = button:GetRect()
            local x, y, width, height = button.Texture:GetRect()
            H.Near(x + width / 2, bx + bw / 2)
            H.Near(y + height / 2, by + bh / 2)
            H.Equal(width, 12)
            H.Equal(height, 12)
            H.Equal(button:GetWidth(), 17, "native hit area remains intact")
            button:RunScript("OnMouseDown")
            local pressedX, pressedY = button.Texture:GetRect()
            H.Near(pressedX - x, 1)
            H.Near(pressedY - y, -1)
            button:RunScript("OnMouseUp")
            H.Near(button.Texture:GetRect(), x)
        end

        context:RequestSkin("modern")
        state:Flush()

        for _, button in ipairs({ bar.Back, bar.Forward }) do
            H.Equal(button.Texture:GetWidth(), 17)
            H.Equal(button.Texture:GetHeight(), 11)
            H.Equal(button.Texture:GetNumPoints(), 1)
            H.Equal(button.Texture.points.TOPLEFT[3], 0)
            H.Equal(button.Texture.points.TOPLEFT[4], 0)
            H.Equal(button.Texture.rotation, 0)
            H.Equal(button.Texture:GetAtlas(), "native-stepper")
            local x, y = button.Texture:GetRect()
            button:RunScript("OnMouseDown")
            local pressedX, pressedY = button.Texture:GetRect()
            H.Near(pressedX - x, 1)
            H.Near(pressedY - y, -1)
            button:RunScript("OnMouseUp")
        end
    end
)

Test(
    "owned close media follows the winning loader and restores native Modern artwork",
    function()
        for _, addonName in ipairs({
            "YvBags",
            "AnotherConsumer",
            "LibYvSkins-1.0",
        }) do
            local state = H.New()
            state.addonName = addonName
            local lib = state:Load()
            local context = lib:CreateContext("CloseMedia")
            local window = context:CreateWindow(
                state.env.CreateFrame("Frame"),
                { minWidth = 300, minHeight = 200 }
            )
            local handle = context._components[window.CloseButton]
            local native = window.CloseButton:GetNormalTexture()
            local nativeAtlas, nativeTexture =
                native:GetAtlas(), native:GetTexture()
            local folder = addonName == "LibYvSkins-1.0" and ""
                or "Libs\\LibYvSkins-1.0\\"
            local expected = "Interface\\AddOns\\"
                .. addonName
                .. "\\"
                .. folder
                .. "Media\\Textures\\Vertex-Close.tga"
            state.addonName = "LaterConsumer"
            state:Load()
            H.Equal(
                lib:GetIconTexture("close"),
                expected,
                "a skipped library copy cannot replace the media root"
            )

            for name, filename in pairs({
                search = "Vertex-Search.tga",
                clone = "Vertex-Clone.tga",
                folder = "Folder.tga",
                caretUp = "Vertex-Caret-Up.tga",
                caretDown = "Vertex-Caret-Down.tga",
                lock = "Vertex-Lock.tga",
                unlock = "Vertex-Unlock.tga",
                visible = "Visible.tga",
                hidden = "Hidden.tga",
                advanced = "Advanced.tga",
                advancedDisabled = "Advanced-Disabled.tga",
            }) do
                local path = "Interface\\AddOns\\"
                    .. addonName
                    .. "\\"
                    .. folder
                    .. "Media\\Textures\\"
                    .. filename
                H.Equal(
                    lib:GetIconTexture(name),
                    path,
                    "action glyphs must use the winning embedded or standalone media root"
                )
            end

            context:RequestSkin("flat")
            state:Flush()
            H.Equal(handle.parts.icon:GetTexture(), expected)
            H.Equal(handle.parts.icon:GetAtlas(), nil)
            H.Equal(handle.parts.icon:IsShown(), true)
            context:RequestSkin("modern")
            state:Flush()
            H.Equal(handle.parts.icon:IsShown(), false)
            H.Equal(native:GetAtlas(), nativeAtlas)
            H.Equal(native:GetTexture(), nativeTexture)
            H.Equal(native:GetAlpha(), 1)
        end
    end
)

Test(
    "Flat action glyphs stay centered with a separate native checkmark offset",
    function()
        local state = H.New()
        state.atlasSizes["common-icon-checkmark-yellow"] = { 24, 24 }
        local context = state:Load():CreateContext("IconBaseline")
        local parent = state:Region(0, 0, 1920, 1080, 1)
        local window = context:CreateWindow(parent, {
            minWidth = 300,
            minHeight = 200,
            layouts = EXAMPLE_LAYOUTS,
            onLayout = LayoutExampleToolbar,
        })
        window:SetSize(700, 500)
        window:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10.31, 20.13)
        local button, handle = context:CreateButton(window.header, {
            icon = "action",
            text = "Action",
            width = 28,
            height = 28,
            pressIcon = true,
            geometryRoot = window,
        })
        local check, checkHandle = context:CreateCheckbox(
            window.footer,
            { checkmarkScale = 0.75, geometryRoot = window }
        )
        button:SetPoint("CENTER", window.header, "CENTER", 0, 0)
        check:SetPoint("CENTER", window.footer, "CENTER", 0, 0)
        window:Show()
        context:RequestSkin("flat")
        state:Flush()
        local textY = handle.parts.label.points.CENTER[4]
        local closeHandle = context._components[window.CloseButton]

        local function CheckCentered(appearance, height)
            local icon = appearance.parts.icon
            local edges = appearance.parts.surface.border.edges
            local left, _, right, top = H.Rect(edges[1], height)
            local _, bottom = H.Rect(edges[2], height)
            local iconLeft, iconBottom, iconRight, iconTop =
                H.Rect(icon, height)
            H.Aligned(icon, height)
            H.Near(
                iconLeft - left,
                right - iconRight,
                "horizontal margins differ"
            )
            H.Near(
                iconBottom - bottom,
                top - iconTop,
                "vertical margins differ"
            )
            local unit = appearance.root.metrics.unit
            assert(
                math.abs((icon:GetWidth() - appearance.iconWidth) / unit)
                    <= 1.00001
            )
            assert(
                math.abs((icon:GetHeight() - appearance.iconHeight) / unit)
                    <= 1.00001
            )
            H.Equal(icon:IsSnappingToPixelGrid(), false)
            H.Equal(icon:GetTexelSnappingBias(), 0)
        end

        for _, height in ipairs({ 1080, 1440, 2160 }) do
            state.height = height
            state.lib.Pixel.InvalidateDisplay()

            for _, scale in ipairs({ 0.5, 0.75, 1, 1.25, 1.5 }) do
                window:SetScale(scale)
                context:RefreshGeometry(window)

                for _ = 1, 3 do
                    local left, bottom = H.Rect(handle.parts.icon, height)
                    button:RunScript("OnEnter")
                    button:RunScript("OnMouseDown", "LeftButton")
                    local pressedLeft, pressedBottom =
                        H.Rect(handle.parts.icon, height)
                    H.Near(
                        pressedLeft - left,
                        1,
                        "pressed offset is one physical pixel"
                    )
                    H.Near(pressedBottom - bottom, -1)
                    button:RunScript("OnMouseUp", "LeftButton")
                    button:RunScript("OnLeave")
                    CheckCentered(handle, height)
                    local checkY = 2
                        - state.lib.Pixel.GetPhysicalSize(
                            checkHandle.parts.checked,
                            1
                        )
                    H.Near(checkHandle.parts.checked.points.CENTER[4], checkY)
                    H.Near(
                        checkHandle.parts.disabledChecked.points.CENTER[4],
                        checkY
                    )
                    CheckCentered(closeHandle, height)
                    H.Equal(handle.parts.label.points.CENTER[4], textY)
                end
            end
        end

        context:RequestSkin("modern")
        state:Flush()
        H.Equal(handle.parts.icon.points.CENTER[4], 0)
        H.Equal(checkHandle.parts.checked.points.CENTER[4], 2)
        H.Equal(closeHandle.parts.icon.points.CENTER[4], 0)

        for _, appearance in ipairs({ handle, closeHandle }) do
            H.Near(appearance.parts.icon:GetWidth(), appearance.iconWidth)
            H.Near(appearance.parts.icon:GetHeight(), appearance.iconHeight)
            H.Equal(appearance.parts.icon:GetNumPoints(), 1)
            H.Equal(
                appearance.parts.icon:IsSnappingToPixelGrid(),
                appearance.iconSnap
            )
            H.Equal(
                appearance.parts.icon:GetTexelSnappingBias(),
                appearance.iconBias
            )
        end
    end
)

Test(
    "Flat grip is flush with the window corner and footer reserves clearance",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("FooterClearance")
        local parent = state:Region(0, 0, 1920, 1080, 1)

        for _, compact in ipairs({ true, false }) do
            context:RequestSkin("modern")
            state:Flush()
            local window = context:CreateWindow(parent, {
                minWidth = 300,
                minHeight = 200,
                layouts = compact and EXAMPLE_LAYOUTS
                    or {
                        modern = EXAMPLE_LAYOUTS.modern,
                        flat = EXAMPLE_LAYOUTS.modern,
                    },
            })
            window:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 20)
            window:SetSize(700, 500)
            window:Show()
            context:RequestSkin("flat")
            state:Flush()
            local wx, wy, ww = window:GetRect()
            local gx, gy, gw = window.resizeButton:GetRect()
            H.Near(gx + gw, wx + ww)
            H.Near(gy, wy)

            if compact then
                local fx, _, fw = window.footer:GetRect()
                H.Near(
                    gx - (fx + fw),
                    8,
                    "footer leaves padding before the grip"
                )
            end

            context:RequestSkin("modern")
            state:Flush()
            H.Equal(window.resizeButton.points.BOTTOMRIGHT[3], -2)
            H.Equal(window.resizeButton.points.BOTTOMRIGHT[4], 3)
            H.Equal(window.footer.points.BOTTOMRIGHT[3], -15)
        end
    end
)

Test(
    "Flat scrollbar centers in its gutter and halves arrow gaps without changing native input",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("ScrollbarGutter")
        local parent = state:Region(0, 0, 500, 400, 1)
        local bar, handle = context:CreateScrollBar(parent, {
            anchor = parent,
            gutterWidth = 22,
            rightOffset = -8,
            topOffset = -2,
            bottomOffset = 2,
        })
        H.Equal(bar.points.TOPRIGHT[3], -8)
        H.Equal(bar.Track.points.TOP[4], -19)
        local drag, click =
            bar.Track.Thumb:GetScript("OnDragStart"),
            bar.Forward:GetScript("OnClick")

        for _ = 1, 3 do
            context:RequestSkin("flat")
            state:Flush()
            local x, _, width = bar:GetRect()
            local px, _, pw = parent:GetRect()
            H.Near(x + width / 2, px + pw - 11)
            local _, trackY, _, trackHeight = bar.Track:GetRect()
            local _, backY = bar.Back.Texture:GetRect()
            local _, forwardY, _, forwardHeight = bar.Forward.Texture:GetRect()
            H.Near(backY - (trackY + trackHeight), 3.5)
            H.Near(trackY - (forwardY + forwardHeight), 3.5)
            H.Equal(bar.Track.Thumb:GetScript("OnDragStart"), drag)
            H.Equal(bar.Forward:GetScript("OnClick"), click)
            H.Equal(handle.layoutSkin, "flat")
            context:RequestSkin("modern")
            state:Flush()
            H.Equal(bar.points.TOPRIGHT[3], -8)
            H.Equal(bar.points.TOPRIGHT[4], -2)
            H.Equal(bar.points.BOTTOMRIGHT[4], 2)
            H.Equal(bar.Track.points.TOP[4], -19)
            H.Equal(bar.Track.points.BOTTOM[4], 19)
        end
    end
)

Test(
    "explicit title layout is retained across skins and toolbar minimums follow shown widths",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Layout")
        local parent = state:Region(0, 0, 1920, 1080, 1)
        local window = context:CreateWindow(parent, {
            minWidth = 100,
            minHeight = 200,
            layout = EXAMPLE_LAYOUTS.modern,
            onLayout = LayoutExampleToolbar,
            getMinimumWidth = ExampleMinimumWidth,
        })
        local tab =
            context:CreateTab(window.header, { width = 300, height = 28 })
        local search = context:CreateSearchBox(window.header)
        SetExampleToolbar(context, window, { tab }, search)
        H.Equal(context:GetWindowMinimumWidth(window), 462)
        context:RequestSkin("flat")
        state:Flush()
        H.Equal(window.titleBar:IsShown() == false, false)
        H.Equal(window.TitleContainer:IsShown(), true)
        tab:Hide()
        context:LayoutToolbar(window.toolbar)
        H.Equal(context:GetWindowMinimumWidth(window), 160)
        tab:SetWidth(400)
        tab:Show()
        context:LayoutToolbar(window.toolbar)
        H.Equal(context:GetWindowMinimumWidth(window), 562)
    end
)

Test(
    "pending skin changes and Flat instances survive mixed MINOR loading without duplicate hooks",
    function()
        for _, order in ipairs({
            { 1, 2 },
            { 2, 1 },
            { 1, 1 },
        }) do
            local state = H.New()
            local context = state:Load(order[1]):CreateContext("Upgrade")
            local _button, handle = context:CreateTab(
                state.env.CreateFrame("Frame"),
                { selected = true }
            )
            context:RequestSkin("flat")
            local frames, regions, hooks =
                #state.frames, state.regions, state.hooks
            state:Load(order[2])
            state:Flush()
            H.Equal(context:GetAppliedSkin(), "flat")
            H.Equal(handle.selected, true)
            H.Equal(handle.parts.normal:GetAlpha(), 0)
            context:RequestSkin("modern")
            state:Flush()
            H.Equal(handle.parts.normal:GetAlpha(), 1)
            H.Equal(#state.frames, frames)
            H.Equal(state.regions, regions)
            H.Equal(state.hooks, hooks)
        end
    end
)

Test(
    "late legacy popups fall back atomically without forgetting the requested skin",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("LateLegacy")
        local button, handle =
            context:CreateButton(state.env.CreateFrame("Frame"))
        context:RequestSkin("flat")
        state:Flush()
        state:PopupLibrary(true)
        context:CreatePopupSlider(button, {})
        state:Flush()
        local requested, applied, reason = context:GetSkinStatus()
        H.Equal(requested, "flat")
        H.Equal(applied, "modern")
        H.Equal(reason, "unavailable")
        H.Equal(handle.parts.normal:GetAlpha(), 1)
        H.Equal(handle.parts.normal:GetAtlas(), "common-button-tertiary-normal")
    end
)

Test(
    "window sections are optional and explicit layouts preserve structure across skins",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("FlexibleShell")
        local parent = state:Region(0, 0, 900, 700, 1)
        local bare = context:CreateWindow(parent, {
            minWidth = 300,
            minHeight = 200,
            movable = false,
            resizable = false,
        })
        bare:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
        bare:Show()
        H.Equal(bare.header:IsShown(), false)
        H.Equal(bare.footer:IsShown(), false)
        H.Equal(bare.titleBar:IsShown(), false)
        H.Equal(bare.CloseButton:IsShown(), false)
        H.Equal(bare.resizeButton:IsShown(), false)
        H.Equal(
            context:GetWindowMinimumWidth(bare),
            300,
            "no implicit search minimum"
        )
        bare:RunScript("OnDragStart")
        H.Equal(bare.moving, nil)

        local layout = {
            padding = 10,
            header = { height = 80, gap = 6 },
            titleBar = { height = 24 },
            body = { padding = 0 },
            footer = { height = 60, gap = 8 },
        }
        local callbacks = 0
        local window = context:CreateWindow(parent, {
            minWidth = 300,
            minHeight = 200,
            layout = layout,
            onLayout = function()
                callbacks = callbacks + 1
            end,
        })
        window:SetSize(600, 400)
        window:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
        window:Show()
        local body, title, footer = window.body, window.titleBar, window.footer
        H.Equal(body:GetHeight(), 226)
        H.Equal(context:GetWindowBodyReserve(window), 0)
        H.Equal(title:GetParent(), window.header)
        H.Equal(window.TitleContainer:GetParent(), title)
        H.Equal(
            window.TitleContainer.points.TOPLEFT[3],
            0,
            "no portrait leaves no icon reservation"
        )
        local frames, regions, hooks = #state.frames, state.regions, state.hooks
        context:RequestSkin("flat")
        state:Flush()
        H.Equal(title:IsShown(), true, "Flat does not imply no Title Bar")
        H.Equal(footer:GetHeight(), 60, "Flat does not imply a short Footer")
        H.Equal(body:GetHeight(), 226)
        H.Equal(context:GetWindowBodyWidthOverhead(window), 20)
        layout.footer.height = 100
        context:RefreshAppearance()
        H.Equal(footer:GetHeight(), 60, "caller layout tables are detached")
        context:SetWindowLayout(window, layout, "flat")
        H.Equal(body:GetHeight(), 186)
        H.Equal(context:GetWindowBodyReserve(window), 40)
        context:RequestSkin("modern")
        state:Flush()
        H.Equal(body:GetHeight(), 226)
        H.Equal(footer:GetHeight(), 60)
        body:Hide()
        context:SetWindowLayout(window, {
            padding = 10,
            body = { padding = 0 },
            header = false,
            footer = false,
        })
        H.Equal(window.header:IsShown(), false)
        H.Equal(window.footer:IsShown(), false)
        H.Equal(body:GetHeight(), 380)
        H.Equal(
            body:IsShown(),
            false,
            "layout must not reveal consumer-hidden Body content"
        )
        H.Equal(window.body, body)
        H.Equal(window.titleBar, title)
        H.Equal(#state.frames, frames)
        H.Equal(state.regions, regions)
        H.Equal(state.hooks, hooks)
        H.Equal(callbacks, 5)

        state.combat = true
        H.Fails(function()
            context:SetWindowLayout(window, layout)
        end)
        state.combat = false
        window:RunScript("OnDragStart")
        H.Fails(function()
            context:SetWindowLayout(window, layout)
        end)
        window:RunScript("OnDragStop")
        local count = #state.frames

        for _, invalid in ipairs({
            { padding = -1 },
            { header = { height = -1 } },
            {
                header = { height = 10 },
                titleBar = { height = 24 },
            },
            { closeButton = "titleBar" },
            { body = { padding = { left = math.huge } } },
        }) do
            H.Fails(function()
                context:CreateWindow(parent, {
                    minWidth = 300,
                    minHeight = 200,
                    layout = invalid,
                })
            end)
        end

        H.Equal(#state.frames, count)
    end
)

Test(
    "Modern window chrome stays at the border with padded content and nested windows",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Chrome")
        local parent = state:Region(0, 0, 1200, 900, 1)

        for _, padding in ipairs({ 0, 8, 12, 24 }) do
            local window = context:CreateWindow(parent, {
                title = "Choose icon",
                minWidth = 520,
                minHeight = 540,
                layout = {
                    padding = padding,
                    header = { height = 150, gap = 8 },
                    titleBar = { height = 24 },
                    footer = { height = 34, gap = 12 },
                },
            })
            window:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 30, 40)
            window:Show()

            for _, scale in ipairs({ 0.75, 1, 1.5 }) do
                window:SetScale(scale)
                window:SetSize(600, 560)
                local left, bottom, width, height = window:GetRect()
                local titleLeft, titleBottom, titleWidth, titleHeight =
                    window.titleBar:GetRect()
                H.Near(titleLeft, left)
                H.Near(titleWidth, width)
                H.Near(titleBottom + titleHeight, bottom + height)
                local _, textBottom, _, textHeight =
                    window.TitleContainer:GetRect()
                H.Near(textBottom + textHeight, bottom + height - 1)
                local closeLeft, closeBottom, closeWidth, closeHeight =
                    window.CloseButton:GetRect()
                H.Near(closeLeft + closeWidth, left + width + 1)
                H.Near(closeBottom + closeHeight, bottom + height)
                H.Equal(closeWidth, 24)
                H.Equal(
                    window.TitleContainer:GetFrameLevel()
                        > window.NineSlice:GetFrameLevel(),
                    true
                )
                H.Equal(
                    window.CloseButton:GetFrameLevel()
                        > window.NineSlice:GetFrameLevel(),
                    true
                )
                H.Near(window.Bg:GetRect(), left + 7)
                H.Near(
                    window.header:GetRect(),
                    left + padding,
                    "content keeps its own padding"
                )
            end

            parent = window
        end
    end
)

Test(
    "window chrome retains explicit margins, portrait insets and manual Close placement",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("ChromeLayouts")
        local parent = state:Region(0, 0, 1200, 900, 1)
        local layout = {
            padding = {
                left = 9,
                right = 6,
                top = 0,
                bottom = 4,
            },
            header = {
                height = 70,
                gap = 4,
                margin = {
                    left = 3,
                    top = 5,
                    right = 2,
                },
            },
            titleBar = { height = 24 },
        }
        local window = context:CreateWindow(parent, {
            minWidth = 520,
            minHeight = 540,
            layout = layout,
        })
        window:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 30, 40)
        window:Show()
        local left, bottom, width, height = window:GetRect()
        H.Near(window.titleBar:GetRect(), left)
        local _, titleBottom, _, titleHeight = window.titleBar:GetRect()
        H.Near(titleBottom + titleHeight, bottom + height)

        layout.header.margin = nil
        layout.titleBar.margin = { left = -9, right = -6 }
        layout.portrait = true
        context:SetWindowLayout(window, layout)
        H.Near(
            window.titleBar:GetRect(),
            left,
            "existing full-bleed layouts keep their position"
        )
        H.Equal(window.titleBar:GetWidth(), width)
        H.Near(window.Bg:GetRect(), left + 2)
        H.Near(window.TitleContainer:GetRect(), left + 58)
        H.Equal(window.PortraitContainer:IsShown(), true)

        layout.titleBar.margin = {
            left = 10,
            top = 3,
            right = 12,
        }
        layout.portrait = false
        layout.closeButton = "manual"
        window.CloseButton:ClearAllPoints()
        window.CloseButton:SetSize(28, 28)
        window.CloseButton:SetPoint(
            "BOTTOMRIGHT",
            window,
            "BOTTOMRIGHT",
            -20,
            20
        )
        context:SetWindowLayout(window, layout)
        local frames, regions, hooks = #state.frames, state.regions, state.hooks

        for _, skin in ipairs({ "flat", "modern", "flat", "modern" }) do
            context:RequestSkin(skin)
            state:Flush()
            H.Near(window.titleBar:GetRect(), left + 19)
            H.Near(window.titleBar:GetWidth(), width - 37)
            H.Equal(window.CloseButton.points.BOTTOMRIGHT[1], window)
            H.Equal(window.CloseButton.points.BOTTOMRIGHT[3], -20)
            H.Equal(window.CloseButton.points.BOTTOMRIGHT[4], 20)
            H.Equal(window.CloseButton:GetWidth(), 28)
            H.Equal(window.CloseButton:GetParent(), window)
            H.Equal(
                window.TitleContainer:GetFrameLevel()
                    > window.NineSlice:GetFrameLevel(),
                true
            )
        end

        H.Near(window.Bg:GetRect(), left + 7)
        H.Equal(window.PortraitContainer:IsShown(), false)
        H.Equal(#state.frames, frames)
        H.Equal(state.regions, regions)
        H.Equal(state.hooks, hooks)
        window.CloseButton:RunScript("OnClick")
        H.Equal(window:IsShown(), false)
    end
)

Test(
    "padded window title placement follows skins without reallocating content",
    function()
        for _, order in ipairs({
            { 1, 2 },
            { 2, 1 },
            { 1, 1 },
        }) do
            local state = H.New()
            local context = state:Load(order[1]):CreateContext("ChromeUpgrade")
            local parent = state:Region(0, 0, 1200, 900, 1)
            local window = context:CreateWindow(parent, {
                minWidth = 520,
                minHeight = 540,
                layout = {
                    padding = 12,
                    header = { height = 150 },
                    titleBar = { height = 24 },
                },
            })
            window:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 30, 40)
            local title = window.TitleContainer
            local bodyLeft, bodyBottom = window.Inset:GetRect()
            local frames, regions, hooks =
                #state.frames, state.regions, state.hooks
            state:Load(order[2])
            context:RequestSkin("flat")
            state:Flush()
            local left, bottom, width, height = window.titleBar:GetRect()
            H.Equal(left, 42)
            H.Equal(bottom + height, 568)
            H.Equal(width, 496)
            context:RequestSkin("modern")
            state:Flush()
            left, bottom, width, height = window.titleBar:GetRect()
            H.Equal(left, 30)
            H.Equal(bottom + height, 580)
            H.Equal(width, 520)
            H.Equal(window.TitleContainer, title)
            H.Equal(
                title:GetFrameLevel() > window.NineSlice:GetFrameLevel(),
                true
            )
            local newBodyLeft, newBodyBottom = window.Inset:GetRect()
            H.Equal(newBodyLeft, bodyLeft)
            H.Equal(newBodyBottom, bodyBottom)
            H.Equal(#state.frames, frames)
            H.Equal(state.regions, regions)
            H.Equal(state.hooks, hooks)
        end
    end
)

Test(
    "toolbars accept arbitrary controls, a flexible middle, and search-free rows without layout churn",
    function()
        local state = H.New()
        local context = state:Load():CreateContext("Toolbars")
        local parent = state:Region(0, 0, 900, 700, 1)
        local toolbar = context:CreateToolbar(parent, { height = 24, gap = 6 })
        toolbar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
        toolbar:SetWidth(300)
        local leading =
            context:CreateButton(toolbar, { width = 40, height = 20 })
        local flexible =
            context:CreateEditBox(toolbar, { width = 80, height = 22 })
        local trailing =
            context:CreateButton(toolbar, { width = 30, height = 18 })
        local items = {
            leading,
            {
                control = flexible,
                stretch = true,
                minWidth = 50,
            },
            trailing,
        }
        context:SetToolbarItems(toolbar, items)
        H.Equal(context:GetToolbarMinimumWidth(toolbar), 132)
        H.Equal(flexible:GetWidth(), 218)
        H.Equal(flexible:GetRect(), 46)
        H.Equal(trailing:GetRect(), 270)
        H.Equal(
            flexible:GetHeight(),
            22,
            "toolbar arrangement does not resize control heights"
        )
        items[2].minWidth = 500
        H.Equal(context:GetToolbarMinimumWidth(toolbar), 132)
        flexible:SetText("retain")
        flexible:SetFocus()
        local frames, regions, hooks = #state.frames, state.regions, state.hooks
        leading:Hide()

        for _ = 1, 20 do
            context:LayoutToolbar(toolbar)
        end

        H.Equal(context:GetToolbarMinimumWidth(toolbar), 86)
        H.Equal(flexible:GetWidth(), 264)
        H.Equal(flexible:GetRect(), 0)
        H.Equal(flexible:GetText(), "retain")
        H.Equal(flexible:HasFocus(), true)
        H.Equal(#state.frames, frames)
        H.Equal(state.regions, regions)
        H.Equal(state.hooks, hooks)
        leading:Show()
        context:SetToolbarItems(toolbar, { leading, trailing }, 0)
        H.Equal(context:GetToolbarMinimumWidth(toolbar), 70)
        H.Equal(trailing:GetRect(), 40)
        H.Fails(function()
            context:SetToolbarItems(toolbar, { leading, leading })
        end)
        H.Fails(function()
            context:SetToolbarItems(toolbar, {
                { control = leading, stretch = true },
                { control = flexible, stretch = true },
            })
        end)
        H.Equal(
            context:GetToolbarMinimumWidth(toolbar),
            70,
            "invalid updates leave existing layout intact"
        )
        state:Load(2)
        context:LayoutToolbar(toolbar)
        H.Equal(context:GetToolbarMinimumWidth(toolbar), 70)
        local other = state.lib:CreateContext("OtherToolbarOwner")
        H.Fails(function()
            other:LayoutToolbar(toolbar)
        end)
    end
)

print(passed .. " library tests passed")

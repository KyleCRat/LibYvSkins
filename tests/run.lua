assert(_VERSION == "Lua 5.1", "Run this suite with Lua 5.1 from the library root")
local H = dofile("tests/harness.lua")
local passed = 0

local function Test(name, callback)
    local success, message = pcall(callback)
    if not success then
        error(name .. ": " .. tostring(message), 0)
    end
    passed = passed + 1
    print("PASS " .. name)
end

Test("two contexts isolate colors, registrations, and geometry roots", function()
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
    local handleA = first:RegisterComponent("separator", a, { bounds = rootA }, { alpha = 0.5 })
    local handleB = second:RegisterComponent("separator", b, { bounds = rootB })
    H.Equal(first:RegisterComponent("separator", a, { bounds = rootA }), handleA)
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
end)

Test("physical thickness and layout rounding are different operations", function()
    local state = H.New()
    local Pixel = state:Load().Pixel
    for _, height in ipairs({ 1080, 1440, 2160 }) do
        state.height = height
        Pixel.InvalidateDisplay()
        for _, frameScale in ipairs({ 0.5, 0.75, 1, 1.25, 1.5 }) do
            for _, uiScale in ipairs({ 0.64, 0.9, 1 }) do
                local root = state:Region(0, 0, 100, 24, frameScale * uiScale)
                for _, pixels in ipairs({ 1, 2 }) do
                    H.Near(Pixel.GetPhysicalSize(root, pixels) * root.scale / (768 / height), pixels)
                end
                for _, value in ipairs({ -13.17, -0.2, 0, 0.4, 17.41 }) do
                    H.Near(Pixel.Round(root, value), state.env.PixelUtil.GetNearestPixelSize(value, root.scale))
                end
            end
        end
    end
end)

Test("lines align fractional/negative origins, both axes and all alignments", function()
    local state = H.New()
    local lib = state:Load()
    local context = lib:CreateContext("Lines")
    for _, height in ipairs({ 1080, 1440, 2160 }) do
        state.height = height
        lib.Pixel.InvalidateDisplay()
        for _, scale in ipairs({ 0.32, 0.5, 0.75, 1, 1.25, 1.5 }) do
            for _, origin in ipairs({ -91.27, -0.3, 0, 10.47 }) do
                local bounds = state:Region(origin, origin + 0.13, 103, 27, scale)
                for _, orientation in ipairs({ "horizontal", "vertical" }) do
                    for _, align in ipairs({ "start", "center", "end" }) do
                        local texture = bounds:CreateTexture()
                        context:RegisterComponent("separator", texture, { bounds = bounds }, {
                            orientation = orientation, align = align, left = 2, right = 2, top = 1, bottom = 1,
                        })
                        H.Aligned(texture, height)
                        local l, b, r, t = H.Rect(texture, height)
                        H.Near(orientation == "vertical" and r - l or t - b, 1)
                        local factor = scale / (768 / height)
                        assert(l >= (origin + 2) * factor - 0.00001)
                        assert(r <= (origin + 101) * factor + 0.00001)
                        context:UnregisterComponent(texture)
                    end
                end
            end
        end
    end
end)

Test("perpendicular separators join without gaps or overlap at every scale", function()
    local state = H.New()
    local lib = state:Load()
    local context = lib:CreateContext("Joins")
    for _, height in ipairs({ 1080, 1440, 2160 }) do
        state.height = height
        lib.Pixel.InvalidateDisplay()
        for _, uiScale in ipairs({ 0.64, 0.9, 1 }) do
            for _, origin in ipairs({ -91.27, -0.3, 0, 10.47 }) do
                local bounds = state:Region(origin, origin + 0.13, 300, 24, uiScale)
                local verticalBounds = state:Region(origin + 51.17, bounds.bottom, 6, 24, uiScale)
                local horizontal = bounds:CreateTexture()
                local vertical = verticalBounds:CreateTexture()
                context:RegisterComponent("separator", horizontal, { bounds = bounds }, { align = "end" })
                context:RegisterComponent("separator", vertical, { bounds = verticalBounds }, {
                    geometryRoot = bounds, orientation = "vertical", top = 1,
                    pixelInsets = { bottom = 1 }, clip = bounds,
                })
                for _, frameScale in ipairs({ 0.5, 0.75, 1, 1.2, 1.25, 1.3, 1.5 }) do
                    bounds.scale = frameScale * uiScale
                    verticalBounds.scale = bounds.scale
                    context:RefreshGeometry(bounds)
                    H.Aligned(horizontal, height)
                    H.Aligned(vertical, height)
                    local _, horizontalBottom, _, horizontalTop = H.Rect(horizontal, height)
                    local verticalLeft, verticalBottom, verticalRight = H.Rect(vertical, height)
                    H.Near(horizontalTop - horizontalBottom, 1)
                    H.Near(verticalRight - verticalLeft, 1)
                    H.Near(verticalBottom, horizontalTop, "separator join has a gap or overlap")
                end
                context:UnregisterComponent(horizontal)
                context:UnregisterComponent(vertical)
            end
        end
    end
end)

Test("pixel insets are copied, combine with layout insets, and hide exhausted bounds", function()
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
            local pixelInsets = { left = 1, right = 2, top = 3, bottom = 4 }
            local handle = context:RegisterComponent("separator", texture, { bounds = bounds }, {
                orientation = orientation, align = align, left = 2, right = 3, top = 2, bottom = 1,
                pixelInsets = pixelInsets, clip = bounds,
            })
            pixelInsets.left, pixelInsets.right, pixelInsets.top, pixelInsets.bottom = 1000, 1000, 1000, 1000
            handle:RefreshGeometry()
            H.Aligned(texture, state.height)
            local l, b, r, t = H.Rect(texture, state.height)
            if orientation == "horizontal" then
                H.Near(l, left + 1)
                H.Near(r, right - 2)
                H.Near(align == "start" and t or b, align == "start" and top - 3 or bottom + 4)
            else
                H.Near(b, bottom + 4)
                H.Near(t, top - 3)
                H.Near(align == "start" and l or r, align == "start" and left + 1 or right - 2)
            end
            context:UnregisterComponent(texture)
        end
    end
    local texture = bounds:CreateTexture()
    context:RegisterComponent("separator", texture, { bounds = bounds }, { pixelInsets = { bottom = 1000 } })
    H.Equal(texture:IsShown(), false)
end)

Test("four-edge borders have two-pixel strokes without overlapping corners", function()
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
                H.Near(index <= 2 and rect[4] - rect[2] or rect[3] - rect[1], 2)
                H.Equal(edge.color[4], 0.7)
            end
            for a = 1, 4 do
                for b = a + 1, 4 do
                    local x, y = rects[a], rects[b]
                    assert(math.min(x[3], y[3]) - math.max(x[1], y[1]) < 0.00001
                        or math.min(x[4], y[4]) - math.max(x[2], y[2]) < 0.00001, "border corners overlap")
                end
            end
            local count = state.regions
            for _ = 1, 10 do border:Layout(metrics, 2) end
            H.Equal(state.regions, count)
            border:Layout(metrics, 0)
            for _, edge in ipairs(border.edges) do H.Equal(edge:IsShown(), false) end
        end
    end
end)

Test("clipping keeps strokes out of the scrollbar gutter and hides offscreen lines", function()
    local state = H.New()
    local lib = state:Load()
    local context = lib:CreateContext("Clip")
    local bounds = state:Region(10.21, 20.31, 300, 33, 0.83)
    local clip = state:Region(11.1, 10, 267, 100, 0.83)
    local texture = bounds:CreateTexture()
    local handle = context:RegisterComponent("separator", texture, { bounds = bounds }, { clip = clip })
    H.Aligned(texture, state.height)
    local l, _, r = H.Rect(texture, state.height)
    assert(l >= clip.left * clip.scale / (768 / state.height))
    assert(r <= (clip.left + clip.width) * clip.scale / (768 / state.height))
    bounds.bottom = -100
    handle:RefreshGeometry()
    H.Equal(texture:IsShown(), false)
    bounds.bottom = 20.31
    handle:RefreshGeometry()
    H.Equal(texture:IsShown(), true)
end)

Test("scroll refreshes allocate no regions/hooks and reuse cached root metrics", function()
    local state = H.New()
    local lib = state:Load()
    local context = lib:CreateContext("Scroll")
    local root = state:Region(0, 0, 500, 600, 0.7)
    local row = state:Region(0.13, 40.17, 500, 33, 0.7)
    local texture = row:CreateTexture()
    local handle = context:RegisterComponent("separator", texture, { bounds = row }, { geometryRoot = root })
    local count, reads = state.regions, state.factorReads
    for index = 1, 100 do
        row.bottom = row.bottom - 0.13
        handle:RefreshGeometry()
        H.Aligned(texture, state.height)
    end
    H.Equal(state.regions, count)
    H.Equal(state.factorReads, reads)
    H.Equal(state.hooks, 0)
    for _, frame in ipairs(state.frames) do H.Equal(frame.scripts.OnUpdate, nil) end
end)

Test("hidden and recycled components retain state and receive the next geometry revision", function()
    local state = H.New()
    local lib = state:Load()
    local context = lib:CreateContext("Pool")
    local root = state:Region(1.17, 4.23, 100, 24, 0.75)
    local texture = root:CreateTexture()
    local handle = context:RegisterComponent("separator", texture, { bounds = root })
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
end)

Test("display events coalesce once across consumers and refresh live instances", function()
    local state = H.New()
    local lib = state:Load()
    local first, second = lib:CreateContext("First"), lib:CreateContext("Second")
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
end)

Test("one consumer keeps independent scales for two windows", function()
    local state = H.New()
    local lib = state:Load()
    local context = lib:CreateContext("Windows")
    local first = state:Region(11.13, 21.71, 90, 24, 0.5)
    local second = state:Region(211.19, 26.77, 110, 24, 1.5)
    local a, b = first:CreateTexture(), second:CreateTexture()
    local handleA = context:RegisterComponent("separator", a, { bounds = first })
    local handleB = context:RegisterComponent("separator", b, { bounds = second })
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

Test("tiny and zero-thickness shapes hide rather than drawing fractional strokes", function()
    local state = H.New()
    local lib = state:Load()
    local context = lib:CreateContext("Tiny")
    local bounds = state:Region(0.13, 0.17, 0.01, 0.01, 1)
    local texture = bounds:CreateTexture()
    context:RegisterComponent("separator", texture, { bounds = bounds })
    H.Equal(texture:IsShown(), false)
    bounds.width, bounds.height = 100, 24
    context:UnregisterComponent(texture)
    context:RegisterComponent("separator", texture, { bounds = bounds }, { thickness = 0 })
    H.Equal(texture:IsShown(), false)
    local border = lib.Pixel.CreateBorder(bounds, bounds)
    bounds.width = 0.1
    border:Layout(lib.Pixel.UpdateMetrics({}, bounds), 2)
    for _, edge in ipairs(border.edges) do H.Equal(edge:IsShown(), false) end
end)

Test("invalid roles, parts, scales, tokens, and thicknesses fail at registration", function()
    local state = H.New()
    local lib = state:Load()
    H.Fails(function() lib:CreateContext("") end)
    local context = lib:CreateContext("Contracts")
    local root = state:Region(0, 0, 100, 24, 1)
    local texture = root:CreateTexture()
    H.Fails(function() context:RegisterComponent("missing", texture, { bounds = root }) end)
    H.Fails(function() context:RegisterComponent("separator", texture, {}) end)
    for _, options in ipairs({ { thickness = -1 }, { thickness = 0.5 }, { orientation = "diagonal" },
        { align = "outside" }, { colorToken = "missing" }, { left = -1 }, { alpha = 2 } }) do
        H.Fails(function() context:RegisterComponent("separator", texture, { bounds = root }, options) end)
    end
    for _, value in ipairs({ false, 1, "1" }) do
        H.Fails(function()
            context:RegisterComponent("separator", texture, { bounds = root }, { pixelInsets = value })
        end)
    end
    for _, edge in ipairs({ "left", "right", "top", "bottom" }) do
        for _, value in ipairs({ -1, 0.5, "1", false }) do
            H.Fails(function()
                context:RegisterComponent("separator", texture, { bounds = root }, { pixelInsets = { [edge] = value } })
            end)
        end
    end
    H.Fails(function() context:SetTokens({ accent = { r = "bad", g = 0, b = 0 } }) end)
    H.Equal(context:GetColor("accent"), 1)
    local differentScale = state:Region(0, 0, 100, 24, 0.75)
    H.Fails(function() context:RegisterComponent("separator", texture, { bounds = differentScale }) end)
end)

Test("mixed/equal MINOR embeds preserve contexts, handles, prototypes, and one event frame", function()
    for _, order in ipairs({ { 1, 2 }, { 2, 1 }, { 1, 1 }, { 2, 2 } }) do
        local state = H.New()
        local lib = state:Load(order[1])
        local context = lib:CreateContext("Existing")
        local root = state:Region(-0.17, 0.21, 100, 24, 0.83)
        local texture = root:CreateTexture()
        local handle = context:RegisterComponent("separator", texture, { bounds = root })
        local border = lib.Pixel.CreateBorder(root, root)
        local eventFrame = lib._displayEventFrame
        local oldContextMethod, oldPixelMethod = context.RefreshGeometry, lib.Pixel.LayoutLine
        local oldHandleMethod = handle.RefreshGeometry
        local count = state.regions
        state:Load(order[2])
        H.Equal(state.lib, lib)
        H.Equal(lib:CreateContext("Existing"), context)
        H.Equal(lib._displayEventFrame, eventFrame)
        H.Equal(#state.frames, 1)
        H.Equal(lib._implementationMinor, math.max(order[1], order[2]))
        H.Equal(context:RegisterComponent("separator", texture, { bounds = root }), handle)
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
        state:Load(1, { "Components/Separator.lua", "Context.lua", "Pixel.lua" })
        if math.max(order[1], order[2]) == 2 then H.Equal(lib.Pixel.LayoutLine, pixelMethod) end
        context:RefreshGeometry()
        border:Layout(lib.Pixel.UpdateMetrics({}, root), 2)
        H.Aligned(texture, state.height)
        H.Equal(state.regions, count)
    end
end)

Test("window factory creates raw frames with canonical Modern chrome", function()
    local state = H.New()
    local context = state:Load():CreateContext("Windows")
    local parent = state:Region(0, 0, 1024, 768, 1)
    local window = context:CreateWindow(parent, {
        name = "TestWindow", title = "Inventory", portrait = "test-icon",
        insetBackground = "test-tile", minWidth = 420, minHeight = 360, maxWidth = 900,
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
    H.Equal(window.points, nil, "the library must not choose or persist a window position")
    window:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 21.17, 17.23)
    local left, bottom = window:GetRect()
    for _, width in ipairs({ 420, 730, 900 }) do
        window:SetSize(width, 500)
        local cl, cb, cw, ch = window.content:GetRect()
        H.Near(cl, left + 7)
        H.Near(cb, bottom + 36)
        H.Near(cw, width - context:GetWindowChromeWidth())
        H.Near(ch, 500 - 99)
        local hl, hb, hw, hh = window.header:GetRect()
        H.Near(hl, left + 58)
        H.Near(hb, bottom + 500 - 56)
        H.Near(hw, width - 64)
        H.Equal(hh, 28)
        local fl, fb, fw, fh = window.footer:GetRect()
        H.Near(fl, left + 3)
        H.Near(fb, bottom + 4)
        H.Near(fw, width - 18)
        H.Equal(fh, 28)
    end
end)

Test("created windows refresh child strokes without an addon adapter", function()
    local state = H.New()
    local lib = state:Load()
    local context = lib:CreateContext("Owner")
    local other = lib:CreateContext("Other")
    local parent = state:Region(0, 0, 1024, 768, 1)
    local first = context:CreateWindow(parent, { minWidth = 420, minHeight = 360 })
    local second = other:CreateWindow(parent, { minWidth = 520, minHeight = 420 })
    first:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0.13, 0.21)
    second:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 501.17, 20.19)
    local options = { geometryRoot = first, align = "end", layer = "ARTWORK", sublevel = 1 }
    local texture, handle = context:CreateSeparator(first.content, options)
    local otherTexture, otherHandle = other:CreateSeparator(second.content, { geometryRoot = second })
    H.Equal(texture:GetObjectType(), "Texture")
    H.Equal(handle.target, texture)
    H.Equal(texture.layer, "ARTWORK")
    H.Equal(texture.sublevel, 1)
    H.Equal(options.bounds, nil, "the factory must not mutate caller options")
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
    first.content:Hide()
    context:RefreshGeometry(first)
    H.Equal(texture:IsShown(), false)
    first.content:Show()
    H.Equal(texture:IsShown(), true)
    H.Equal(otherTexture:IsShown(), true)
    H.Equal(#state.frames, frames)
    H.Equal(state.regions, regions)
    H.Equal(state.hooks, hooks)
    context:UnregisterComponent(texture)
    assert(context._roots[first], "a window owns its geometry root even with no strokes")
    local replacement = context:CreateSeparator(first.content, { geometryRoot = first })
    H.Aligned(replacement, state.height)
end)

Test("window callbacks preserve native movement, resize, close and consumer scripts", function()
    local state = H.New()
    local context = state:Load():CreateContext("Callbacks")
    local parent = state:Region(0, 0, 1024, 768, 1)
    local moved, resized, shown, closed = 0, 0, 0, 0
    local window = context:CreateWindow(parent, {
        minWidth = 420, minHeight = 360,
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
    local texture = context:CreateSeparator(window.content, { geometryRoot = window })
    window:SetScript("OnShow", function() shown = shown + 1 end)
    window:Show()
    H.Equal(texture:IsShown(), true, "consumer SetScript must not replace library hooks")
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
    window.CloseButton:SetScript("OnClick", function() closed = closed + 1 end)
    window:Show()
    window.CloseButton:RunScript("OnClick")
    H.Equal(closed, 1)
    H.Equal(window:IsShown(), true, "domain close behavior must remain directly replaceable")
    H.Equal(shown, 2)
end)

Test("invalid window contracts fail before allocating frames", function()
    local state = H.New()
    local context = state:Load():CreateContext("Validation")
    local parent = state:Region(0, 0, 1024, 768, 1)
    local frames = #state.frames
    H.Fails(function() context:CreateWindow(parent, nil) end)
    H.Fails(function() context:CreateWindow(nil, { minWidth = 400, minHeight = 300 }) end)
    for _, options in ipairs({ {}, { minWidth = 0, minHeight = 300 }, { minWidth = 400 },
        { minWidth = 400, minHeight = 300, maxWidth = 300 }, { minWidth = 400, minHeight = 300, maxHeight = 200 },
        { minWidth = 400, minHeight = 300, onMoveStopped = true },
        { minWidth = 400, minHeight = 300, onResizeStopped = false },
        { minWidth = 400, minHeight = 300, name = "" }, { minWidth = 400, minHeight = 300, title = true } }) do
        H.Fails(function() context:CreateWindow(parent, options) end)
    end
    H.Equal(#state.frames, frames)
end)

Test("window instances survive mixed MINOR embeds without duplicate lifecycle hooks", function()
    for _, order in ipairs({ { 1, 2 }, { 2, 1 }, { 1, 1 }, { 2, 2 } }) do
        local state = H.New()
        local lib = state:Load(order[1])
        local context = lib:CreateContext("Windows")
        local parent = state:Region(0, 0, 1024, 768, 1)
        local window = context:CreateWindow(parent, { minWidth = 400, minHeight = 300 })
        window:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -0.17, 4.31)
        local texture, handle = context:CreateSeparator(window.content, { geometryRoot = window })
        local factory = context.CreateWindow
        local frames, regions, hooks = #state.frames, state.regions, state.hooks
        state:Load(order[2])
        if order[2] > order[1] then assert(context.CreateWindow ~= factory)
        else H.Equal(context.CreateWindow, factory) end
        local selectedFactory = context.CreateWindow
        state:Load(1, { "Window.lua" })
        if math.max(order[1], order[2]) == 2 then H.Equal(context.CreateWindow, selectedFactory) end
        window:SetScale(1.3)
        window:Show()
        H.Aligned(texture, state.height)
        H.Equal(context._roots[window], handle.root)
        H.Equal(window.resizeButton.initCount, 1)
        H.Equal(#state.frames, frames)
        H.Equal(state.regions, regions)
        H.Equal(state.hooks, hooks)
    end
end)

Test("expandable headers use icon-free Modern art with native text and click access", function()
    local state = H.New()
    local context = state:Load():CreateContext("Headers")
    local parent = state:Region(0, 0, 400, 31, 1)
    local before = state.regions
    local header, handle = context:CreateExpandableHeader(parent, {
        height = 31, text = "Consumable (2)", expanded = false, font = "test-font", fontSize = 18,
    })
    header:SetAllPoints(parent)
    H.Equal(header:GetObjectType(), "Button")
    H.Equal(header:GetWidth(), 400)
    H.Equal(header:GetHeight(), 31)
    H.Equal(header:GetText(), "Consumable (2)")
    H.Equal(header.clickButtons[1], "LeftButtonUp")
    H.Equal(header:GetNormalTexture().atlas, "common-button-tertiary-normal")
    H.Equal(header:GetPushedTexture().atlas, "common-button-tertiary-pressed")
    H.Equal(header:GetDisabledTexture().atlas, "common-button-tertiary-disabled")
    H.Equal(state.regions - before, 5, "only three backgrounds, the state arrow, and text are created")
    H.Equal(handle.parts.icon, nil, "no leading icon or icon-space reservation")
    H.Equal(handle.parts.divider, nil, "the Modern bar needs no separate divider")
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
    H.Equal(handle:IsExpanded(), true, "only the consumer changes authoritative expansion state")
    header:SetText("Pinned (3)")
    H.Equal(label:GetText(), "Pinned (3)")
end)

Test("header native states and pooling retain no stale hover or pressed art", function()
    local state = H.New()
    local context = state:Load():CreateContext("Pool")
    local parent = state:Region(0, 0, 400, 31, 1)
    parent:Hide()
    local header, handle = context:CreateExpandableHeader(parent)
    H.Equal(header:IsShown(), true, "a hidden parent must not permanently hide a newly initialized header")
    H.Equal(header:IsVisible(), false)
    parent:Show()
    H.Equal(header:IsVisible(), true)
    local enters = 0
    header:SetScript("OnEnter", function() enters = enters + 1 end)
    header:RunScript("OnEnter")
    H.Equal(enters, 1)
    H.Equal(header:GetNormalTexture().atlas, "common-button-tertiary-hover")
    header:SetEnabled(false)
    H.Equal(handle.parts.arrow.atlas, "common-dropdown-icon-next-disabled")
    H.Equal(handle.parts.label.textColor[4], 0.5)
    H.Equal(header:GetNormalTexture().atlas, "common-button-tertiary-normal")
    header:SetEnabled(true)
    H.Equal(handle.parts.arrow.atlas, "common-dropdown-icon-next")
    H.Equal(handle.parts.label.textColor[4], 1)
    local frames, regions, hooks, reads = #state.frames, state.regions, state.hooks, state.factorReads
    for index = 1, 100 do
        header:RunScript("OnEnter")
        header:SetButtonState("PUSHED")
        handle:SetExpanded(false)
        handle:SetShown(false)
        H.Equal(header:GetButtonState(), "NORMAL")
        H.Equal(handle.hovered, false)
        handle:SetExpanded(true)
        header:SetText("Next group")
        handle:SetShown(true)
        H.Equal(header:GetNormalTexture().atlas, "common-button-tertiary-normal")
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
end)

Test("header tokens and opacity remain isolated from other consumers and geometry", function()
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
    H.Equal(header.points, anchors, "appearance and geometry refreshes must preserve consumer anchors")
end)

Test("invalid expandable header options fail before allocating controls", function()
    local state = H.New()
    local context = state:Load():CreateContext("Contracts")
    local parent = state:Region(0, 0, 400, 31, 1)
    local frames, regions = #state.frames, state.regions
    H.Fails(function() context:CreateExpandableHeader(nil) end)
    for _, options in ipairs({ false, { width = 0 }, { height = -1 }, { fontSize = "18" },
        { text = false }, { font = "" }, { expanded = 1 }, { onClick = true },
        { alpha = 2 }, { colorToken = "missing" }, { geometryRoot = {} },
        { geometryRoot = state:Region(0, 0, 400, 31, 0.5) } }) do
        H.Fails(function() context:CreateExpandableHeader(parent, options) end)
    end
    H.Equal(#state.frames, frames)
    H.Equal(state.regions, regions)
    local _, handle = context:CreateExpandableHeader(parent)
    H.Fails(function() handle:SetExpanded(1) end)
end)

Test("header handles and visual hooks survive mixed and equal MINOR loading", function()
    for _, order in ipairs({ { 1, 2 }, { 2, 1 }, { 1, 1 }, { 2, 2 } }) do
        local state = H.New()
        local lib = state:Load(order[1])
        local context = lib:CreateContext("Upgrade")
        local parent = state:Region(0, 0, 400, 31, 1)
        local clicks = 0
        local header, handle = context:CreateExpandableHeader(parent, {
            onClick = function() clicks = clicks + 1 end,
        })
        local method = handle.SetExpanded
        local frames, regions, hooks = #state.frames, state.regions, state.hooks
        state:Load(order[2])
        if order[2] > order[1] then assert(handle.SetExpanded ~= method)
        else H.Equal(handle.SetExpanded, method) end
        local selected = handle.SetExpanded
        state:Load(1, { "Components/ExpandableHeader.lua" })
        H.Equal(handle.SetExpanded, selected)
        handle:SetExpanded(false)
        header:RunScript("OnEnter")
        H.Equal(header:GetNormalTexture().atlas, "common-button-tertiary-hover")
        header:RunScript("OnClick", "LeftButton")
        H.Equal(clicks, 1)
        context:SetTokens({ accent = { r = 0.2, g = 0.3, b = 0.4 } })
        H.Equal(handle.parts.label.textColor[1], 0.2)
        H.Equal(#state.frames, frames)
        H.Equal(state.regions, regions)
        H.Equal(state.hooks, hooks)
    end
end)

Test("command and square buttons preserve native access, visual states, and pooling", function()
    local state = H.New()
    local context = state:Load():CreateContext("Controls", { font = "test-font" })
    local parent = state.env.CreateFrame("Frame")
    local button, appearance = context:CreateButton(parent, {
        variant = "square", width = 28, height = 28, icon = "test-icon", text = "Action",
    })
    H.Equal(button:GetText(), "Action")
    H.Equal(appearance.parts.normal.atlas, "common-button-tertiary-square-normal")
    local clicks = 0
    button:SetScript("OnClick", function() clicks = clicks + 1 end)
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
end)

Test("selected tabs keep their full-sized outsets and take precedence over hover and press", function()
    local state = H.New()
    local context = state:Load():CreateContext("Tabs")
    local parent = state.env.CreateFrame("Frame")
    local button, appearance = context:CreateTab(parent, { text = "Character", width = 108, height = 28 })
    appearance:SetSelected(true)
    button:RunScript("OnEnter")
    button:RunScript("OnMouseDown", "LeftButton")
    H.Equal(appearance.parts.normal.atlas, "common-button-tertiary-selected")
    H.Equal(appearance.parts.normal.points.TOPLEFT[3], -3)
    H.Equal(appearance.parts.normal.points.BOTTOMRIGHT[4], -3)
    H.Equal(appearance.parts.hover:IsShown(), false)
    H.Equal(appearance.parts.pressed:IsShown(), false)
    appearance:SetSelected(false)
    H.Equal(appearance.parts.normal.points.TOPLEFT[3], 0)
    H.Equal(button.Text.textColor[1], 0.92)
end)

Test("checkboxes retain checked and disabled-checked state during appearance refresh", function()
    local state = H.New()
    local context = state:Load():CreateContext("Checks")
    local button, appearance = context:CreateCheckbox(state.env.CreateFrame("Frame"), { checkmarkScale = 1 })
    button:SetChecked(true)
    button:SetEnabled(false)
    context:RefreshAppearance()
    H.Equal(button:GetChecked(), true)
    H.Equal(button.checkedTexture.atlas, "common-icon-checkmark-yellow")
    H.Equal(button.disabledCheckedTexture.desaturated, true)
    H.Equal(appearance.parts.disabled:IsShown(), true)
end)

Test("search construction preserves clear, focus, typed values, and tuned native icon anchors", function()
    local state = H.New()
    local context = state:Load():CreateContext("Search", { font = "test-font" })
    local search, appearance = context:CreateSearchBox(state.env.CreateFrame("Frame"), { fontSize = 13 })
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
    H.Equal(search.Background.atlas, "common-button-tertiary-depressed-normal")
    search.clearButton:RunScript("OnClick")
    H.Equal(search:GetText(), "")
    H.Equal(search:HasFocus(), false)
    H.Equal(appearance.parts.focus:IsShown(), false)
end)

Test("presentation refresh preserves pooled semantic content, visibility, and icon state", function()
    local state = H.New()
    local context = state:Load():CreateContext("Regions", { font = "test-font", iconBorder = "custom-border" })
    local parent = state.env.CreateFrame("Frame")
    local text = context:CreateText(parent)
    text:SetText("semantic text")
    text:SetTextColor(0.7, 0.2, 0.9)
    local accent = context:CreateTexture(parent, { texture = "marker", colorToken = "accent" })
    local icon, appearance = context:CreateIcon(parent)
    icon:SetTexture("item")
    icon:SetDesaturated(true)
    appearance:SetBorderColor(0.2, 0.3, 0.4, 0.8)
    appearance:SetBorderAlpha(0.4)
    icon:Hide()
    appearance:SetBorderShown(false)
    accent:Hide()
    local frames, regions, hooks = #state.frames, state.regions, state.hooks
    for index = 1, 100 do context:SetTokens({ accent = { r = 0.3, g = 0.4, b = 0.5 } }) end
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
end)

Test("new control factories and preexisting handles survive mixed copies without extra regions or hooks", function()
    for _, order in ipairs({ { 1, 2 }, { 2, 1 }, { 1, 1 } }) do
        local state = H.New()
        local context = state:Load(order[1]):CreateContext("First", { iconBorder = "custom-border" })
        local other = state.lib:CreateContext("Second", { iconBorder = "other-border" })
        local parent = state.env.CreateFrame("Frame")
        local button, handle = context:CreateTab(parent)
        local edit = context:CreateEditBox(parent)
        local icon, iconHandle = other:CreateIcon(parent)
        edit:SetText("retained")
        local frames, regions, hooks = #state.frames, state.regions, state.hooks
        state:Load(order[2])
        state:Load(1, { "Components/Button.lua", "Skins/Modern.lua" })
        handle:SetSelected(true)
        context:RefreshAppearance()
        H.Equal(handle.parts.normal.atlas, "common-button-tertiary-selected")
        H.Equal(edit:GetText(), "retained")
        H.Equal(iconHandle.parts.border.texture[1], "other-border")
        H.Equal(#state.frames, frames)
        H.Equal(state.regions, regions)
        H.Equal(state.hooks, hooks)
    end
end)

Test("hover and press refresh state without repeating fonts or atlas lookups", function()
    local state = H.New()
    local context = state:Load():CreateContext("States", { font = "test-font" })
    local button = context:CreateButton(state.env.CreateFrame("Frame"), { icon = "icon", pressIcon = true })
    local fonts, atlases = state.fontWrites, state.atlasWrites
    for index = 1, 100 do
        button:RunScript("OnEnter")
        button:RunScript("OnMouseDown", "LeftButton")
        button:RunScript("OnMouseUp", "LeftButton")
        button:RunScript("OnLeave")
    end
    H.Equal(state.fontWrites, fonts)
    H.Equal(state.atlasWrites, atlases)
end)

Test("native window close and resize art restores without replacing actions", function()
    local state = H.New()
    local context = state:Load():CreateContext("Chrome")
    local window = context:CreateWindow(state.env.CreateFrame("Frame"), { minWidth = 400, minHeight = 300 })
    local close, resize = window.CloseButton:GetNormalTexture(), window.resizeButton:GetNormalTexture()
    local click, drag = window.CloseButton:GetScript("OnClick"), window.resizeButton:GetScript("OnMouseDown")
    close:SetAtlas("different")
    close:SetAlpha(0.1)
    resize:SetTexture("different")
    context:RefreshAppearance()
    H.Equal(close:GetAtlas(), "native-close")
    H.Equal(close:GetAlpha(), 1)
    H.Equal(resize:GetTexture(), "native-resize")
    H.Equal(window.CloseButton:GetScript("OnClick"), click)
    H.Equal(window.resizeButton:GetScript("OnMouseDown"), drag)
end)

Test("scrollbars dispatch visuals and retain native drag and click scripts", function()
    local state = H.New()
    local context = state:Load():CreateContext("Scroll")
    local bar, appearance = context:CreateScrollBar(state.env.CreateFrame("Frame"))
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
end)

Test("icons pair border visibility and never revive unregistered pooled visuals", function()
    local state = H.New()
    local context = state:Load():CreateContext("Icon", { iconBorder = "border" })
    local icon, appearance = context:CreateIcon(state.env.CreateFrame("Frame"))
    appearance:SetShown(false)
    H.Equal(appearance.parts.border:IsShown(), false)
    appearance:SetShown(true)
    H.Equal(appearance.parts.border:IsShown(), true)
    context:UnregisterComponent(icon)
    appearance:SetShown(true)
    appearance:SetBorderShown(true)
    H.Equal(icon:IsShown(), false)
    H.Equal(appearance.parts.border:IsShown(), false)
end)

Test("glow borders keep animation opacity and reuse all regions on refresh", function()
    local state = H.New()
    local context = state:Load():CreateContext("Glow")
    local glow, appearance = context:CreateGlowBorder(state.env.CreateFrame("Frame"))
    glow:SetAlpha(0.35)
    local regions = state.regions
    context:SetTokens({ accent = { r = 0.2, g = 0.4, b = 0.8 } })
    context:RefreshGeometry()
    H.Equal(appearance.parts.edges.top.color[3], 0.8)
    H.Equal(glow:GetAlpha(), 0.35)
    H.Equal(state.regions, regions)
end)

Test("popup integration uses declared parts and preserves external values and drag state", function()
    local state = H.New()
    local context = state:Load():CreateContext("Popup")
    state:PopupLibrary()
    local popup, appearance = context:CreatePopupSlider(state.env.CreateFrame("Button"), {})
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
end)

Test("missing and legacy popup libraries keep Modern optional and expose unsupported styling", function()
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
end)

Test("invalid control factory options fail before allocating frames or regions", function()
    local state = H.New()
    local context = state:Load():CreateContext("InvalidControls")
    local parent = state.env.CreateFrame("Frame")
    local frames, regions = #state.frames, state.regions
    for _, factory in ipairs({ "CreateButton", "CreateTab", "CreateCheckbox", "CreateEditBox",
        "CreateSearchBox", "CreateIcon", "CreateText", "CreateTexture", "CreateScrollBar", "CreateGlowBorder" }) do
        H.Fails(function() context[factory](context, parent, false) end)
        H.Fails(function() context[factory](context, parent, { colorToken = "missing" }) end)
    end
    H.Fails(function() context:CreateIcon(parent) end)
    H.Fails(function() context:CreateButton(parent, { iconAlpha = 2 }) end)
    H.Fails(function() context:CreateSearchBox(parent, { focusGlow = "yes" }) end)
    H.Equal(#state.frames, frames)
    H.Equal(state.regions, regions)
end)

Test("second-consumer example constructs independent windows and raw controls", function()
    local state = H.New()
    local lib = state:Load()
    state.env.UIParent = state:Region(0, 0, 1920, 1080, 1)
    state:PopupLibrary()
    local fixture = assert(loadfile("examples/PixelHarness.lua"))
    setfenv(fixture, state.env)()
    local first, second = lib:CreateContext("PixelHarnessA"), lib:CreateContext("PixelHarnessB")
    assert(first ~= second)
    local roles = {}
    for target, handle in pairs(first._components) do roles[handle.role] = true end
    for _, role in ipairs({ "window", "button", "editBox", "icon", "glowBorder", "scrollBar", "popupSlider" }) do
        assert(roles[role], "example must exercise " .. role)
    end
    first:SetTokens({ accent = { r = 0.4, g = 0.5, b = 0.6 } })
    H.Equal(second:GetColor("accent"), 1)
end)

Test("region factories preserve requested bounds and separate semantic colors from opacity", function()
    local state = H.New()
    local context = state:Load():CreateContext("Dimensions")
    local parent = state.env.CreateFrame("Frame")
    local texture, appearance = context:CreateTexture(parent, {
        texture = "symbol", width = 16, height = 12, alpha = 0.6,
    })
    local text, textAppearance = context:CreateText(parent, { width = 80, height = 20 })
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
end)

print(passed .. " library tests passed")

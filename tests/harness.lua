local Harness = {}

local function Read(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

function Harness.New()
    local state = { height = 1440, factorReads = 0, regions = 0, hooks = 0, timers = {}, frames = {} }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.strmatch = string.match
    env.GameFontNormalLarge = {}
    env.LibStub = nil
    local stub = assert(loadstring(Read("tests/fixtures/LibStub.lua"), "@LibStub.lua"))
    setfenv(stub, env)()

    env.PixelUtil = {}
    function env.PixelUtil.GetPixelToUIUnitFactor()
        state.factorReads = state.factorReads + 1
        return 768 / state.height
    end
    function env.PixelUtil.GetNearestPixelSize(value, scale, minPixels)
        local unit = 768 / state.height / scale
        local pixels = math.floor(value / unit + 0.5)
        if minPixels then
            pixels = value < 0 and math.min(pixels, -minPixels) or math.max(pixels, minPixels)
        end
        return pixels * unit
    end
    env.C_Timer = { After = function(_, callback) state.timers[#state.timers + 1] = callback end }

    local Region = {}
    Region.__index = Region
    function Region:GetEffectiveScale()
        return self.scale or (self.localScale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1)
    end
    function Region:SetScale(value) self.localScale = value end
    function Region:GetScale() return self.localScale or 1 end
    function Region:IsShown() return self.shown ~= false end
    function Region:IsVisible() return self:IsShown() and (not self.parent or self.parent:IsVisible()) end
    function Region:Show()
        local changed = not self:IsShown()
        self.shown = true
        if changed then self:RunScript("OnShow") end
    end
    function Region:Hide()
        local changed = self:IsShown()
        self.shown = false
        if changed then self:RunScript("OnHide") end
    end
    function Region:SetShown(value) if value then self:Show() else self:Hide() end end
    function Region:SetColorTexture(...) self.colorTexture = { ... } end
    function Region:SetVertexColor(...) self.color = { ... } end
    function Region:SetBlendMode(value) self.blend = value end
    function Region:SetSnapToPixelGrid(value) self.snap = value end
    function Region:SetTexelSnappingBias(value) self.bias = value end
    function Region:SetAlpha(value) self.alpha = value end
    function Region:SetTexture(...) self.texture = { ... } end
    function Region:SetAtlas(atlas, useAtlasSize) self.atlas, self.useAtlasSize = atlas, useAtlasSize end
    function Region:SetRotation(value) self.rotation = value end
    function Region:SetFont(...) self.font = { ... } end
    function Region:SetFontObject(value) self.fontObject = value end
    function Region:SetTextColor(...) self.textColor = { ... } end
    function Region:SetJustifyH(value) self.justifyH = value end
    function Region:SetJustifyV(value) self.justifyV = value end
    function Region:SetWordWrap(value) self.wordWrap = value end
    function Region:SetMaxLines(value) self.maxLines = value end
    function Region:SetFontString(value) self.fontString = value end
    function Region:GetFontString() return self.fontString end
    function Region:SetText(value)
        if self.fontString then self.fontString:SetText(value) else self.text = value end
    end
    function Region:GetText() return self.fontString and self.fontString:GetText() or self.text end
    function Region:SetNormalTexture(value) self.normalTexture = value end
    function Region:GetNormalTexture() return self.normalTexture end
    function Region:SetPushedTexture(value) self.pushedTexture = value end
    function Region:GetPushedTexture() return self.pushedTexture end
    function Region:SetDisabledTexture(value) self.disabledTexture = value end
    function Region:GetDisabledTexture() return self.disabledTexture end
    function Region:SetButtonState(value) self.buttonState = value end
    function Region:GetButtonState() return self.buttonState or "NORMAL" end
    function Region:IsEnabled() return self.enabled ~= false end
    function Region:SetEnabled(value)
        local changed = self:IsEnabled() ~= value
        self.enabled = value
        if changed then self:RunScript(value and "OnEnable" or "OnDisable") end
    end
    function Region:RegisterForClicks(...) self.clickButtons = { ... } end
    function Region:SetHorizTile(value) self.horizTile = value end
    function Region:SetVertTile(value) self.vertTile = value end
    function Region:ClearAllPoints() self.points = nil end
    function Region:SetPoint(point, relativeTo, relativePoint, x, y)
        self.points = self.points or {}
        self.points[point] = { relativeTo, relativePoint, x or 0, y or 0 }
    end
    function Region:SetAllPoints(region)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
        self:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0)
    end
    function Region:SetSize(width, height)
        self.width, self.height = width, height
        self:RunScript("OnSizeChanged", width, height)
    end
    function Region:SetWidth(value) self:SetSize(value, self.height) end
    function Region:SetHeight(value) self:SetSize(self.width, value) end
    local function PointFactors(point)
        local x = point:find("LEFT") and 0 or (point:find("RIGHT") and 1 or 0.5)
        local y = point:find("BOTTOM") and 0 or (point:find("TOP") and 1 or 0.5)
        return x, y
    end
    function Region:GetRect()
        if self.unresolved then return end
        if self.points then
            local xs, ys = {}, {}
            for point, anchor in pairs(self.points) do
                local relativeTo = anchor[1]
                local left, bottom, width, height = relativeTo:GetRect()
                if not left or not bottom or not width or not height then return end
                local x, y = PointFactors(point)
                local relativeX, relativeY = PointFactors(anchor[2])
                local factor = relativeTo:GetEffectiveScale() / self:GetEffectiveScale()
                xs[x] = (left + width * relativeX) * factor + anchor[3]
                ys[y] = (bottom + height * relativeY) * factor + anchor[4]
            end
            local width = xs[0] and xs[1] and xs[1] - xs[0] or self.width
            local height = ys[0] and ys[1] and ys[1] - ys[0] or self.height
            if not width or not height then return end
            local left = xs[0] or (xs[1] and xs[1] - width) or (xs[0.5] and xs[0.5] - width / 2)
            local bottom = ys[0] or (ys[1] and ys[1] - height) or (ys[0.5] and ys[0.5] - height / 2)
            return left, bottom, width, height
        end
        return self.left, self.bottom, self.width, self.height
    end
    function Region:GetWidth() local _, _, width = self:GetRect() return width or self.width end
    function Region:GetHeight() local _, _, _, height = self:GetRect() return height or self.height end
    function Region:CreateTexture(_, layer, _, sublevel)
        state.regions = state.regions + 1
        return setmetatable({ parent = self, layer = layer, sublevel = sublevel }, Region)
    end
    function Region:CreateFontString(_, layer)
        state.regions = state.regions + 1
        return setmetatable({ parent = self, layer = layer, frameType = "FontString" }, Region)
    end
    function Region:RegisterEvent(event) self.events[event] = true end
    function Region:SetScript(script, callback) self.scripts[script] = callback end
    function Region:GetScript(script) return self.scripts[script] end
    function Region:HookScript(script, callback)
        state.hooks = state.hooks + 1
        self.scriptHooks[script] = self.scriptHooks[script] or {}
        table.insert(self.scriptHooks[script], callback)
    end
    function Region:RunScript(script, ...)
        if self.scripts and self.scripts[script] then self.scripts[script](self, ...) end
        for _, callback in ipairs(self.scriptHooks and self.scriptHooks[script] or {}) do callback(self, ...) end
    end
    function Region:GetName() return self.name end
    function Region:GetParent() return self.parent end
    function Region:GetObjectType() return self.frameType or "Texture" end
    function Region:SetFrameStrata(value) self.strata = value end
    function Region:SetToplevel(value) self.toplevel = value end
    function Region:SetClampedToScreen(value) self.clamped = value end
    function Region:SetMovable(value) self.movable = value end
    function Region:EnableMouse(value) self.mouseEnabled = value end
    function Region:SetResizable(value) self.resizable = value end
    function Region:SetResizeBounds(...) self.resizeBounds = { ... } end
    function Region:SetTitle(value) self.title = value end
    function Region:SetPortraitToAsset(value) self.portrait = value end
    function Region:SetPortraitTexCoord(...) self.portraitTexCoord = { ... } end
    function Region:RegisterForDrag(...) self.dragButtons = { ... } end
    function Region:StartMoving() self.moving = true end
    function Region:StartSizing() self.sizing = true end
    function Region:StopMovingOrSizing() self.moving, self.sizing = false, false end
    function Region:Init(target, minWidth, minHeight, maxWidth, maxHeight)
        assert(self.template == "PanelResizeButtonTemplate")
        self.target, self.initCount = target, (self.initCount or 0) + 1
        self.minWidth, self.minHeight, self.maxWidth, self.maxHeight = minWidth, minHeight, maxWidth, maxHeight
        local original = target:GetScript("OnSizeChanged")
        target:SetScript("OnSizeChanged", function(...)
            if original then original(...) end
        end)
    end
    function Region:SetOnResizeStoppedCallback(callback) self.resizeStoppedCallback = callback end
    function Region:SetMaxWidth(value) self.maxWidth = value end
    function env.CreateFrame(frameType, name, parent, template)
        local frame = setmetatable({ events = {}, scripts = {}, scriptHooks = {},
            frameType = frameType, name = name, parent = parent, template = template }, Region)
        state.frames[#state.frames + 1] = frame
        if template == "ButtonFrameTemplate" then
            frame.Inset = env.CreateFrame("Frame", nil, frame)
            frame.Inset.Bg = frame.Inset:CreateTexture()
            frame.TopTileStreaks = frame:CreateTexture()
            frame.Bg = frame:CreateTexture()
            frame.Bg:SetTexture("native-outer-background")
            frame.TitleContainer = env.CreateFrame("Frame", nil, frame)
            frame.CloseButton = env.CreateFrame("Button", nil, frame)
            frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)
        elseif template == "PanelResizeButtonTemplate" then
            frame:SetScript("OnMouseDown", function(self) self.target:StartSizing() end)
            frame:SetScript("OnMouseUp", function(self)
                self.target:StopMovingOrSizing()
                self.resizeStoppedCallback(self.target)
            end)
        end
        return frame
    end
    function state:Region(left, bottom, width, height, scale)
        return setmetatable({ left = left, bottom = bottom, width = width, height = height, scale = scale }, Region)
    end
    function state:Flush()
        local pending = self.timers
        self.timers = {}
        for _, callback in ipairs(pending) do callback() end
    end
    function state:Load(minor, files)
        if not files then
            files = {}
            for path in Read("embed.xml"):gmatch('<Script%s+file="([^"]+)"') do
                files[#files + 1] = path:gsub("\\", "/")
            end
            assert(#files > 0, "embed.xml must declare runtime files")
        end
        for _, path in ipairs(files) do
            local source = Read(path)
            if minor then
                source = source:gsub('local MAJOR, MINOR = "LibYvSkins%-1%.0", %d+',
                    'local MAJOR, MINOR = "LibYvSkins-1.0", ' .. minor, 1)
            end
            local chunk = assert(loadstring(source, "@" .. path))
            setfenv(chunk, env)()
        end
        self.lib = env.LibStub("LibYvSkins-1.0")
        return self.lib
    end
    state.env = env
    return state
end

function Harness.Equal(actual, expected, message)
    assert(actual == expected, (message or "values differ") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end

function Harness.Near(actual, expected, message)
    assert(math.abs(actual - expected) < 0.00001,
        (message or "values differ") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end

function Harness.Fails(callback)
    assert(not pcall(callback), "expected an invalid contract to fail")
end

function Harness.Rect(texture, height)
    local left, bottom, width, size = texture:GetRect()
    local scale = texture:GetEffectiveScale() / (768 / height)
    return left * scale, bottom * scale, (left + width) * scale, (bottom + size) * scale
end

function Harness.Aligned(texture, height)
    for _, edge in ipairs({ Harness.Rect(texture, height) }) do
        Harness.Near(edge, math.floor(edge + 0.5), "screen edge is not on a whole pixel")
    end
end

return Harness

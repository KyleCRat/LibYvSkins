local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)
if not lib or lib._implementationMinor ~= MINOR or lib._modules.Context == MINOR then
    return
end
lib._modules.Context = MINOR

local Context = lib._contextPrototype
local Handle = lib._handlePrototype
Context.__index = Context
Handle.__index = Handle

local function CopyColors(tokens, destination)
    for key, color in pairs(tokens) do
        assert(type(key) == "string" and type(color) == "table", "tokens must contain named colors")
        assert(type(color.r) == "number" and type(color.g) == "number" and type(color.b) == "number",
            "color tokens require numeric r, g, and b values")
        assert(color.a == nil or type(color.a) == "number", "color alpha must be numeric")
        destination[key] = { r = color.r, g = color.g, b = color.b, a = color.a or 1 }
    end
end

function lib:CreateContext(addonName, options)
    assert(type(addonName) == "string" and addonName ~= "", "addonName must be a non-empty string")
    if self._contexts[addonName] then
        return self._contexts[addonName]
    end
    options = options or {}
    assert(type(options) == "table", "context options must be a table")
    assert(options.font == nil or (type(options.font) == "string" and options.font ~= ""), "font must be a path")
    assert(options.iconBorder == nil or type(options.iconBorder) == "string" or type(options.iconBorder) == "number",
        "iconBorder must be a texture path or file ID")
    local tokens = { accent = { r = 1, g = 1, b = 1, a = 1 } }
    CopyColors(options.tokens or {}, tokens)
    local context = setmetatable({
        addonName = addonName,
        _tokens = tokens,
        _components = {},
        _roots = {},
        _media = { font = options.font, iconBorder = options.iconBorder },
        appearanceRevision = 1,
    }, Context)
    self._contexts[addonName] = context
    return context
end

function Context:_GetRenderer()
    return lib._skins.modern
end

function Context:RefreshAppearance()
    self.appearanceRevision = self.appearanceRevision + 1
    for _, handle in pairs(self._components) do
        handle:RefreshAppearance()
    end
end

function Context:GetColor(token)
    local color = self._tokens[token]
    assert(color, "unknown appearance color token: " .. tostring(token))
    return color.r, color.g, color.b, color.a
end

function Context:SetTokens(tokens)
    local colors = {}
    CopyColors(self._tokens, colors)
    CopyColors(tokens, colors)
    self._tokens = colors
    self:RefreshAppearance()
end

function Context:_GetGeometryRoot(region)
    local root = self._roots[region]
    if not root then
        root = {
            region = region,
            metrics = lib.Pixel.UpdateMetrics({}, region),
            handles = {},
        }
        self._roots[region] = root
    end
    return root
end

function Context:RegisterComponent(role, target, parts, options)
    local definition = lib._roles[role]
    assert(definition, "unsupported appearance role: " .. tostring(role))
    options = options or {}
    definition.Validate(target, parts, options)
    local geometryRoot = options.geometryRoot or parts.bounds
    local existing = self._components[target]
    if existing then
        assert(existing.role == role and existing.parts.bounds == parts.bounds
            and existing.root.region == geometryRoot, "component registration cannot change ownership")
        return existing
    end
    local colorToken = options.colorToken or "accent"
    self:GetColor(colorToken)
    local root = self:_GetGeometryRoot(geometryRoot)
    local handle = setmetatable({
        context = self,
        role = role,
        target = target,
        parts = { bounds = parts.bounds },
        root = root,
        colorToken = colorToken,
        alpha = options.alpha or 1,
        shown = true,
    }, Handle)
    definition.Initialize(handle, options)
    self._components[target] = handle
    root.handles[handle] = true
    handle:RefreshAppearance()
    handle:RefreshGeometry()
    return handle
end

function Context:UnregisterComponent(target)
    local handle = self._components[target]
    if not handle then
        return
    end
    local definition = lib._roles[handle.role]
    if definition.OnUnregister then
        definition.OnUnregister(handle)
    end
    handle.target:Hide()
    self._components[target] = nil
    handle.root.handles[handle] = nil
    if not handle.root.window and not next(handle.root.handles) then
        self._roots[handle.root.region] = nil
    end
    handle.registered = false
end

local function RefreshRoot(root)
    -- The consumer lays out its parents first. Refresh scale metrics once,
    -- then only declared visual children; never reposition the parent itself.
    lib.Pixel.UpdateMetrics(root.metrics, root.region)
    for handle in pairs(root.handles) do
        handle:RefreshGeometry()
    end
end

function Context:RefreshGeometry(geometryRoot)
    if geometryRoot then
        local root = self._roots[geometryRoot]
        if root then
            RefreshRoot(root)
        end
    else
        for _, root in pairs(self._roots) do
            RefreshRoot(root)
        end
    end
end

function Handle:RefreshAppearance()
    if self.registered == false then
        return
    end
    lib._roles[self.role].ApplyAppearance(self)
    self.appearanceRevision = self.context.appearanceRevision
end

function Handle:SetAlpha(alpha)
    assert(type(alpha) == "number" and alpha >= 0 and alpha <= 1, "alpha must be between zero and one")
    self.alpha = alpha
    self.alphaOwned = true
    self:RefreshAppearance()
end

function Handle:SetShown(shown)
    self.shown = shown == true
    self:RefreshGeometry()
end

function Handle:RefreshGeometry()
    if self.registered == false then
        return
    end
    if not self.shown or not self.parts.bounds:IsVisible() then
        self.target:Hide()
        return
    end
    if self.root.metrics.displayRevision ~= lib.Pixel._displayRevision then
        lib.Pixel.UpdateMetrics(self.root.metrics, self.root.region)
    end
    lib._roles[self.role].Layout(self)
end

function lib:RefreshDisplay()
    self.Pixel.InvalidateDisplay()
    for _, context in pairs(self._contexts) do
        context:RefreshGeometry()
    end
end

function lib:ScheduleDisplayRefresh()
    if self._displayRefreshPending then
        return
    end
    self._displayRefreshPending = true
    C_Timer.After(0, function()
        lib._displayRefreshPending = false
        lib:RefreshDisplay()
    end)
end

-- One event subscription per LibStub family, not per addon/window/pool member.
if not lib._displayEventFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UI_SCALE_CHANGED")
    frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function()
        lib:ScheduleDisplayRefresh()
    end)
    lib._displayEventFrame = frame
end

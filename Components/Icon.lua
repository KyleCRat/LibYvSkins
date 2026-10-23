local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or lib._modules.Icon == MINOR
then
    return
end

lib._modules.Icon = MINOR

local definition = lib._roles.icon or {}
lib._roles.icon = definition
local Icon = lib._iconPrototype or {}
lib._iconPrototype = Icon
Icon.__index = Icon
setmetatable(Icon, { __index = lib._controlPrototype })

local function ValidateOptions(parent, options)
    lib._ValidateControl(parent, options)
    assert(
        options.actionIcon == nil or type(options.actionIcon) == "boolean",
        "actionIcon must be boolean"
    )
    assert(
        not options.actionIcon or type(parent.IsEnabled) == "function",
        "action icons require a button parent"
    )
    assert(
        options.borderOutset == nil
            or (
                type(options.borderOutset) == "number"
                and options.borderOutset >= 0
            ),
        "borderOutset must be non-negative"
    )
    assert(
        options.artworkOutset == nil
            or (
                type(options.artworkOutset) == "number"
                and options.artworkOutset >= 0
                and options.artworkOutset <= (options.borderOutset or 3)
            ),
        "artworkOutset must be between zero and borderOutset"
    )
end

function definition.Validate(target, parts, options)
    assert(
        target and type(target.SetTexCoord) == "function",
        "icon role requires a Texture"
    )
    assert(type(parts) == "table" and parts.bounds, "icon role requires bounds")
    ValidateOptions(parts.bounds, options)
end

function definition.Initialize(handle, options)
    lib._InitializeControl(handle, options, Icon)
    handle.borderTexture = options.borderTexture
        or (handle.context._media and handle.context._media.iconBorder)
    handle.borderOutset = options.borderOutset or 3
    handle.artworkOutset = options.artworkOutset or 0

    if handle.artworkOutset > 0 then
        local width, height = handle.target:GetSize()
        local growth = handle.artworkOutset * 2
        handle.target:SetSize(width + growth, height + growth)
    end

    handle.crop = options.crop ~= false
    handle.actionIcon = options.actionIcon == true
    handle.r, handle.g, handle.b, handle.a = 1, 1, 1, 1
    handle.borderAlpha, handle.borderShown = 1, true
    handle.parts.border = handle.target:GetParent():CreateTexture(
        nil,
        options.borderLayer or "OVERLAY",
        nil,
        options.borderSublevel or 0
    )
    handle.parts.flatBorder = lib.Pixel.CreateBorder(
        handle.target:GetParent(),
        handle.target,
        options.borderLayer or "OVERLAY",
        options.borderSublevel or 0
    )
    handle.target:GetParent():HookScript("OnShow", function()
        handle:RefreshGeometry()
    end)

    if handle.actionIcon then
        local function RefreshState()
            if handle.registered ~= false then
                handle.context:_GetRenderer().IconState(handle)
            end
        end

        handle.parts.bounds:HookScript("OnEnable", RefreshState)
        handle.parts.bounds:HookScript("OnDisable", RefreshState)
    end
end

function definition.ApplyAppearance(handle)
    handle.context:_GetRenderer().Icon(handle)
end

function definition.OnUnregister(handle)
    handle.parts.border:Hide()
    handle.parts.flatBorder:Hide()
end

function definition.Layout(handle)
    handle.context:_GetRenderer().IconLayout(handle)
end

function Icon:SetBorderColor(r, g, b, a)
    assert(
        type(r) == "number" and type(g) == "number" and type(b) == "number",
        "border color must be numeric"
    )
    assert(a == nil or type(a) == "number", "border alpha must be numeric")
    self.r, self.g, self.b, self.a = r, g, b, a or 1
    -- Frequent semantic updates do not reload an atlas or change crop/layout.
    self.context:_GetRenderer().IconColor(self)
end

function Icon:SetBorderAlpha(alpha)
    assert(
        type(alpha) == "number" and alpha >= 0 and alpha <= 1,
        "border alpha must be between zero and one"
    )
    self.borderAlpha = alpha
    self.context:_GetRenderer().IconColor(self)
end

function Icon:SetBorderShown(shown)
    self.borderShown = shown == true

    if self.registered ~= false then
        self.context:_GetRenderer().IconVisibility(self)
    end
end

function Icon:SetShown(shown)
    lib._controlPrototype.SetShown(self, shown)

    if self.registered ~= false then
        self.context:_GetRenderer().IconVisibility(self)
    end
end

function lib._contextPrototype:CreateIcon(parent, options)
    if options == nil then options = {} end

    ValidateOptions(parent, options)
    self:GetColor(options.colorToken or "accent")
    assert(
        options.borderTexture or (self._media and self._media.iconBorder),
        "icon requires a context or component border texture"
    )
    local icon = parent:CreateTexture(
        nil,
        options.layer or "ARTWORK",
        nil,
        options.sublevel or 0
    )
    icon:SetSize(options.width or 23, options.height or options.width or 23)
    local handle =
        self:RegisterComponent("icon", icon, { bounds = parent }, options)
    return icon, handle
end

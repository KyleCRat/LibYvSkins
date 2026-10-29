local MAJOR, MINOR = "LibYvSkins-1.0", 2
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or lib._modules.Regions == MINOR
then
    return
end

lib._modules.Regions = MINOR

-- Semantic content/color stays on the raw region unless a context color token
-- is explicitly requested. Appearance refresh never changes text or artwork.
-- Renderers may share these neutral operations, never another skin's painting.
function lib._ApplyTextureAppearance(handle)
    if handle.usesColorToken then
        local r, g, b, a = handle:GetColor()

        if handle.isSolid then
            handle.target:SetColorTexture(r, g, b, a * handle.alpha)
        else
            handle.target:SetVertexColor(r, g, b, a * handle.alpha)
        end
    elseif handle.alphaOwned then
        handle.target:SetAlpha(handle.alpha)
    end
end

function lib._ApplyTextAppearance(handle)
    if handle.font then
        handle.target:SetFont(handle.font, handle.fontSize, handle.fontFlags)
    end

    if handle.usesColorToken then
        local r, g, b, a = handle:GetColor()
        handle.target:SetTextColor(r, g, b, a * handle.alpha)
    elseif handle.alphaOwned then
        handle.target:SetAlpha(handle.alpha)
    end
end

for _, role in ipairs({ "text", "texture" }) do
    local definition = lib._roles[role] or {}
    lib._roles[role] = definition

    function definition.Validate(target, parts, options)
        assert(
            target and type(target.SetAlpha) == "function",
            "region role requires a region"
        )
        assert(
            type(parts) == "table" and parts.bounds,
            "region role requires bounds"
        )
        lib._ValidateControl(parts.bounds, options)
    end

    function definition.Initialize(handle, options)
        lib._InitializeControl(handle, options)
        handle.usesColorToken = options.colorToken ~= nil
        handle.isSolid = not options.texture and not options.atlas
    end

    function definition.ApplyAppearance(handle)
        local renderer = handle.context:_GetRenderer()

        if handle.role == "text" then
            renderer.Text(handle)
        else
            renderer.Texture(handle)
        end
    end

    function definition.Layout(_handle) end
end

function lib._contextPrototype:CreateText(parent, options)
    if options == nil then options = {} end

    lib._ValidateControl(parent, options)
    self:GetColor(options.colorToken or "accent")
    local text = parent:CreateFontString(nil, options.layer or "OVERLAY")
    text:SetFontObject(GameFontHighlight)
    text:SetTextColor(1, 1, 1)
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    text:SetMaxLines(1)

    if options.width then text:SetWidth(options.width) end

    if options.height then text:SetHeight(options.height) end

    local handle =
        self:RegisterComponent("text", text, { bounds = parent }, options)
    text:SetText(options.text or "")
    return text, handle
end

function lib._contextPrototype:CreateTexture(parent, options)
    if options == nil then options = {} end

    lib._ValidateControl(parent, options)
    assert(
        not (options.texture and options.atlas),
        "use either texture or atlas"
    )
    self:GetColor(options.colorToken or "accent")
    local texture = parent:CreateTexture(
        nil,
        options.layer or "ARTWORK",
        nil,
        options.sublevel or 0
    )

    if options.texture then
        texture:SetTexture(options.texture)
    elseif options.atlas then
        texture:SetAtlas(options.atlas, false)
    else
        texture:SetColorTexture(1, 1, 1, 1)
    end

    if options.width then texture:SetWidth(options.width) end

    if options.height then texture:SetHeight(options.height) end

    local handle =
        self:RegisterComponent("texture", texture, { bounds = parent }, options)
    return texture, handle
end

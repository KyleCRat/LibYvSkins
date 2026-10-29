local MAJOR, MINOR = "LibYvSkins-1.0", 2
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or lib._modules.NativeButton == MINOR
then
    return
end

lib._modules.NativeButton = MINOR

-- Constructor-owned native close/resize controls retain their exact Blizzard
-- art once. Future renderers can replace visuals without replacing actions.
local definition = lib._roles.nativeButton or {}
lib._roles.nativeButton = definition
local SLOTS = { "Normal", "Pushed", "Highlight", "Disabled" }

function definition.Validate(target, _parts, _options)
    assert(
        target and type(target.GetNormalTexture) == "function",
        "nativeButton requires a Button"
    )
end

function definition.Initialize(handle, options)
    lib._InitializeControl(handle, options)
    handle.kind = options.kind

    if handle.kind ~= "resize" then
        handle.parts.surface =
            lib._CreateSurface(handle, handle.target, handle.target)
    end

    handle.parts.icon = handle.target:CreateTexture(nil, "OVERLAY")
    handle.parts.icon:SetSize(16, 16)
    handle.parts.icon:SetPoint("CENTER", handle.target, "CENTER", 0, 0)
    lib._InitializeIconLayout(handle)
    handle.parts.icon:Hide()
    handle.parts.states = {}

    for _, slot in ipairs(SLOTS) do
        local texture = handle.target["Get" .. slot .. "Texture"](handle.target)

        if texture then
            handle.parts.states[#handle.parts.states + 1] = {
                setter = "Set" .. slot .. "Texture",
                region = texture,
                atlas = texture:GetAtlas(),
                texture = texture:GetTexture(),
                coordinates = { texture:GetTexCoord() },
                alpha = texture:GetAlpha(),
                color = { texture:GetVertexColor() },
                blend = texture:GetBlendMode(),
            }
        end
    end

    local function Refresh()
        handle:RefreshAppearance()
    end

    handle.target:HookScript("OnEnter", function()
        handle.hovered = true
        Refresh()
    end)
    handle.target:HookScript("OnLeave", function()
        handle.hovered = false
        Refresh()
    end)
    handle.target:HookScript("OnMouseDown", function()
        handle.pressed = true
        Refresh()
    end)
    handle.target:HookScript("OnMouseUp", function()
        handle.pressed = false
        Refresh()
    end)
    handle.target:HookScript("OnHide", function()
        handle.hovered, handle.pressed = false, false
        Refresh()
    end)
    handle.target:HookScript("OnEnable", Refresh)
    handle.target:HookScript("OnDisable", Refresh)
end

function definition.ApplyAppearance(handle)
    handle.context:_GetRenderer().NativeButton(handle)
end

function definition.Layout(handle)
    handle.context:_GetRenderer().NativeButtonLayout(handle)
end

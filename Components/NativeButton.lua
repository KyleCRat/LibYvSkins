local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)
if not lib or lib._implementationMinor ~= MINOR or lib._modules.NativeButton == MINOR then
    return
end
lib._modules.NativeButton = MINOR

-- Constructor-owned native close/resize controls retain their exact Blizzard
-- art once. Future renderers can replace visuals without replacing actions.
local definition = lib._roles.nativeButton or {}
lib._roles.nativeButton = definition
local SLOTS = { "Normal", "Pushed", "Highlight", "Disabled" }

function definition.Validate(target, parts, options)
    assert(target and type(target.GetNormalTexture) == "function", "nativeButton requires a Button")
end

function definition.Initialize(handle, options)
    lib._InitializeControl(handle, options)
    handle.parts.states = {}
    for _, slot in ipairs(SLOTS) do
        local texture = handle.target["Get" .. slot .. "Texture"](handle.target)
        if texture then
            handle.parts.states[#handle.parts.states + 1] = {
                setter = "Set" .. slot .. "Texture", region = texture,
                atlas = texture:GetAtlas(), texture = texture:GetTexture(),
                coordinates = { texture:GetTexCoord() }, alpha = texture:GetAlpha(),
                color = { texture:GetVertexColor() }, blend = texture:GetBlendMode(),
            }
        end
    end
end

function definition.ApplyAppearance(handle)
    handle.context:_GetRenderer().NativeButton(handle)
end

function definition.Layout(handle)
end

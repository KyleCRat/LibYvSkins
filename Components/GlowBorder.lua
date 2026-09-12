local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)
if not lib or lib._implementationMinor ~= MINOR or lib._modules.GlowBorder == MINOR then
    return
end
lib._modules.GlowBorder = MINOR

local definition = lib._roles.glowBorder or {}
lib._roles.glowBorder = definition

function definition.Validate(target, parts, options)
    lib._ValidateControl(target, options)
end

function definition.Initialize(handle, options)
    lib._InitializeControl(handle, options)
    handle.parts.surface = lib._CreateSurface(handle, handle.target, handle.target, true)
    handle.parts.edges = {}
    for _, key in ipairs({ "topLeft", "topRight", "bottomLeft", "bottomRight", "top", "bottom", "left", "right" }) do
        handle.parts.edges[key] = handle.target:CreateTexture(nil, "BORDER")
    end
end

function definition.ApplyAppearance(handle)
    handle.context:_GetRenderer().GlowBorder(handle)
end

function definition.Layout(handle)
    handle.context:_GetRenderer().GlowBorderLayout(handle)
end

function lib._contextPrototype:CreateGlowBorder(parent, options)
    if options == nil then options = {} end
    lib._ValidateControl(parent, options)
    self:GetColor(options.colorToken or "accent")
    local frame = CreateFrame("Frame", options.name, parent)
    frame:SetAllPoints(parent)
    local handle = self:RegisterComponent("glowBorder", frame, { bounds = parent }, options)
    return frame, handle
end

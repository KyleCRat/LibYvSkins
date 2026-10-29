local MAJOR, MINOR = "LibYvSkins-1.0", 2
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or lib._modules.ModernSettings == MINOR
then
    return
end

lib._modules.ModernSettings = MINOR

local definition = lib._roles.settingsTab or {}
lib._roles.settingsTab = definition

function definition.Validate(target, parts, options)
    assert(
        target
            and type(target.SetTabAppearance) == "function"
            and type(target.RefreshTabGeometry) == "function",
        "settings tabs require the LMS tab presentation API"
    )
    lib._ValidateControl(parts.bounds, options)
end

function definition.Initialize(handle, options)
    lib._InitializeControl(handle, options)
end

function definition.ApplyAppearance(handle)
    handle.context:_GetRenderer().SettingsTab(handle)
end

function definition.Layout(handle)
    handle.target:RefreshTabGeometry()
end

-- The caller creates the LMS control. This adapter owns only its appearance;
-- selection, input commits, navigation and geometry remain with LMS.
function lib._contextPrototype:StyleSettingsTab(tab, options)
    return self:RegisterComponent("settingsTab", tab, { bounds = tab }, options)
end

local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)
if not lib or lib._implementationMinor ~= MINOR or lib._modules.Surface == MINOR then
    return
end
lib._modules.Surface = MINOR

-- Allocate flat art once with its owner, including hidden pooled controls.
function lib._CreateSurface(handle, parent, bounds, borderOnly)
    local surface = { bounds = bounds, border = lib.Pixel.CreateBorder(parent, bounds, "BORDER", 1) }
    if not borderOnly then
        surface.background = parent:CreateTexture(nil, "BACKGROUND", nil, -5)
        lib.Pixel.PrepareTexture(surface.background)
        surface.background:Hide()
    end
    if not handle.surfaces then
        handle.surfaces = {}
        local function Refresh() handle:RefreshGeometry() end
        handle.target:HookScript("OnShow", Refresh)
        handle.target:HookScript("OnSizeChanged", Refresh)
    end
    handle.surfaces[#handle.surfaces + 1] = surface
    return surface
end

function lib._LayoutSurfaces(handle)
    if not handle.surfaces then return end
    local flat = handle.context:GetAppliedSkin() == "flat"
    for _, surface in ipairs(handle.surfaces) do
        if flat and surface.bounds:IsVisible() then
            surface.border:Layout(handle.root.metrics, 1, handle.clip)
            if surface.background then
                lib.Pixel.LayoutFill(surface.background, surface.bounds, handle.root.metrics, 1, handle.clip)
            end
        else
            surface.border:Hide()
            if surface.background then surface.background:Hide() end
        end
    end
end

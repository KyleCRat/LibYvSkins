local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)
if not lib or lib._implementationMinor ~= MINOR or lib._modules.PopupSlider == MINOR then
    return
end
lib._modules.PopupSlider = MINOR

-- Explicit external-library boundary; consumers still use a creation-first API.
local definition = lib._roles.popupSlider or {}
lib._roles.popupSlider = definition

local function CopyColor(color)
    return { r = color.r, g = color.g, b = color.b, a = color.a or 1 }
end

function definition.Validate(target, parts, options)
    assert(target and type(target.GetVisualParts) == "function" and type(target.SetFontAppearance) == "function"
        and type(target.IsInteracting) == "function",
        "LibPopupSlider requires its public presentation API")
end

function definition.Initialize(handle, options)
    lib._InitializeControl(handle, options)
    local parts = handle.target:GetVisualParts()
    handle.parts.visuals = parts
    handle.parts.surface = lib._CreateSurface(handle, handle.target, handle.target)
    handle.baseline = {
        backdrop = handle.target:GetBackdrop(),
        backgroundColor = CopyColor(parts.backgroundColor),
        trackColor = CopyColor(parts.trackColor), markerColor = CopyColor(parts.markerColor),
        thumbColor = CopyColor(parts.thumbColor), font = parts.font, fontFlags = parts.fontFlags,
    }
    handle.target:HookScript("OnShow", function()
        handle:RefreshAppearance()
        -- The external popup positions itself after OnShow, once per drag.
        C_Timer.After(0, function() handle:RefreshGeometry() end)
    end)
    handle.target:HookScript("OnHide", function()
        handle:RefreshAppearance()
        handle.context:RetryPendingSkin()
    end)
end

function definition.ApplyAppearance(handle)
    handle.context:_GetRenderer().PopupSlider(handle)
end

function definition.Layout(handle)
end

function lib._contextPrototype:CreatePopupSlider(button, options)
    local popupLibrary = LibStub("LibPopupSlider-1.0", true)
    if not popupLibrary then return nil end
    local popup = popupLibrary:Create(button, options)
    if type(popup.GetVisualParts) ~= "function" or type(popup.SetFontAppearance) ~= "function"
        or type(popup.IsInteracting) ~= "function" then
        -- An equal-MINOR released embed can mask the development copy. Keep
        -- its native Modern popup usable, and expose the missing capability
        -- so later skin selection can reject an incomplete visual transition.
        self._popupSliderUnavailable = "The loaded LibPopupSlider does not expose its presentation API."
        self:RetryPendingSkin()
        return popup, nil, self._popupSliderUnavailable
    end
    local handle = self:RegisterComponent("popupSlider", popup, { bounds = popup }, { geometryRoot = popup })
    return popup, handle
end

function lib._contextPrototype:GetPopupSliderSupport()
    return self._popupSliderUnavailable == nil, self._popupSliderUnavailable
end

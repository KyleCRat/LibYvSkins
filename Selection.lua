local MAJOR, MINOR = "LibYvSkins-1.0", 2
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or lib._modules.Selection == MINOR
then
    return
end

lib._modules.Selection = MINOR

local Context = lib._contextPrototype

function Context:GetAppliedSkin()
    return self._appliedSkin or "modern"
end

function Context:GetSkinStatus()
    return self._requestedSkin or "modern",
        self:GetAppliedSkin(),
        self._pendingSkinReason
end

function Context:SetSkinCallbacks(callbacks)
    assert(type(callbacks) == "table", "skin callbacks must be a table")

    for key, callback in pairs(callbacks) do
        assert(
            (
                key == "beforeApply"
                or key == "onApplied"
                or key == "onStatusChanged"
            ) and type(callback) == "function",
            "unsupported skin callback"
        )
    end

    self._skinCallbacks = callbacks
end

local function Notify(context, event)
    local callback = context._skinCallbacks and context._skinCallbacks[event]

    if callback then callback(context) end
end

local function SetPending(context, reason)
    context._pendingSkinReason = reason
    Notify(context, "onStatusChanged")
end

function Context:_ApplyPendingSkin()
    local context = self
    context._skinScheduled = false
    local requested = context._requestedSkin or "modern"
    local unavailable

    if requested ~= "modern" and not context:GetPopupSliderSupport() then
        requested, unavailable = "modern", true
    end

    if requested == context:GetAppliedSkin() then
        SetPending(context, unavailable and "unavailable" or nil)
        return
    end

    if InCombatLockdown() then
        SetPending(context, "combat")
        return
    end

    for _, handle in pairs(context._components) do
        if
            (
                handle.role == "window"
                and (handle.moving or handle.target.resizeButton:IsActive())
            )
            or (handle.role == "popupSlider" and handle.target:IsInteracting())
        then
            SetPending(context, "interaction")
            return
        end
    end

    Notify(context, "beforeApply")
    context._applyingSkin = true

    for _, handle in pairs(context._components) do
        if handle.role == "popupSlider" then handle.target:Hide() end
    end

    context._appliedSkin = requested
    -- Resolve canonical chrome before painting any of its children. Both
    -- windows change in this one callback, without hiding them or their lists.
    for _, root in pairs(context._roots) do
        if root.window then context:_LayoutWindow(root.window) end
    end

    context:RefreshAppearance()
    context:RefreshGeometry()
    Notify(context, "onApplied")
    context._applyingSkin = false
    SetPending(context, unavailable and "unavailable" or nil)
end

function Context:RetryPendingSkin()
    if self._skinScheduled or self._applyingSkin then return end

    local applied = self:GetAppliedSkin()
    local unsupported = applied ~= "modern" and not self:GetPopupSliderSupport()

    if (self._requestedSkin or "modern") == applied and not unsupported then
        return
    end

    self._skinScheduled = true
    C_Timer.After(0, function()
        self:_ApplyPendingSkin()
    end)
end

function Context:RequestSkin(skin)
    assert(skin == "modern" or skin == "flat", "skin must be modern or flat")
    self._requestedSkin = skin

    if skin == self:GetAppliedSkin() then
        SetPending(self, nil)
    else
        SetPending(self, "queued")
        self:RetryPendingSkin()
    end
end

if not lib._skinEventFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function()
        for _, context in pairs(lib._contexts) do
            context:RetryPendingSkin()
        end
    end)
    lib._skinEventFrame = frame
end

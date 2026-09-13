local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)
if not lib or lib._implementationMinor ~= MINOR or lib._modules.EditBox == MINOR then
    return
end
lib._modules.EditBox = MINOR

local definition = lib._roles.editBox or {}
lib._roles.editBox = definition

function definition.Validate(target, parts, options)
    assert(target and type(target.SetAutoFocus) == "function", "editBox role requires an EditBox")
    assert(type(parts) == "table" and parts.bounds, "editBox requires bounds")
    lib._ValidateControl(parts.bounds, options)
end

function definition.Initialize(handle, options)
    lib._InitializeControl(handle, options)
    local editBox, parts = handle.target, handle.parts
    parts.surface = lib._CreateSurface(handle, editBox, editBox)
    if options.search then
        parts.background = editBox.Background
        parts.instructions = editBox.Instructions
        parts.searchIcon, parts.clearButton = editBox.searchIcon, editBox.clearButton
        parts.searchIcon:ClearAllPoints()
        parts.searchIcon:SetPoint("LEFT", editBox, "LEFT", 7, 1)
        parts.clearButton:ClearAllPoints()
        parts.clearButton:SetPoint("RIGHT", editBox, "RIGHT", -4, 1)
        parts.instructions:ClearAllPoints()
        parts.instructions:SetPoint("TOPLEFT", editBox, "TOPLEFT", 25, 0)
        parts.instructions:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", -23, 0)
        editBox:SetTextInsets(25, 23, 0, 0)
    else
        parts.background = lib._CreateStateTexture(editBox, "BACKGROUND")
        editBox:SetTextInsets(8, 8, 0, 0)
    end
    handle.textInsets = { editBox:GetTextInsets() }
    if options.focusGlow ~= false then
        parts.focus = editBox:CreateTexture(nil, "BORDER")
        parts.focus:SetPoint("TOPLEFT", editBox, "TOPLEFT", -2, 3)
        parts.focus:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 2, -1)
        parts.focus:Hide()
    end
    local function Refresh() handle:RefreshAppearance() end
    editBox:HookScript("OnEditFocusGained", Refresh)
    editBox:HookScript("OnEditFocusLost", Refresh)
    editBox:HookScript("OnEnable", Refresh)
    editBox:HookScript("OnDisable", Refresh)
end

function definition.ApplyAppearance(handle)
    handle.context:_GetRenderer().EditBox(handle)
end

function definition.Layout(handle)
end

local function Create(context, parent, options, search)
    if options == nil then options = {} end
    lib._ValidateControl(parent, options)
    assert(options.focusGlow == nil or type(options.focusGlow) == "boolean", "focusGlow must be boolean")
    context:GetColor(options.colorToken or "accent")
    local template = search and "SearchBoxNineSliceTemplate" or "InputBoxScriptTemplate"
    local editBox = CreateFrame("EditBox", options.name, parent, template)
    editBox:SetSize(options.width or 320, options.height or 34)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlight)
    editBox:SetJustifyV("MIDDLE")
    local settings = {}
    for key, value in pairs(options) do settings[key] = value end
    settings.search = search
    local handle = context:RegisterComponent("editBox", editBox, { bounds = parent }, settings)
    return editBox, handle
end

function lib._contextPrototype:CreateSearchBox(parent, options)
    return Create(self, parent, options, true)
end

function lib._contextPrototype:CreateEditBox(parent, options)
    return Create(self, parent, options, false)
end

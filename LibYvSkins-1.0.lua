local addonName = ...
local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then
    return
end

-- Owned media follows the canonical embed folder, without stack-path inference
-- (WoW truncates long source paths). Standalone packages use the library root.
local libraryFolder = addonName == MAJOR and "" or "Libs\\" .. MAJOR .. "\\"
local texturePath = "Interface\\AddOns\\" .. addonName .. "\\" .. libraryFolder .. "Media\\Textures\\"
lib._headerTabTexture = texturePath .. "common-header-tab\\common-header-tab-atlas.tga"
lib._media = {
    close = texturePath .. "Vertex-Close.tga",
    clone = texturePath .. "Vertex-Clone.tga",
    lock = texturePath .. "Vertex-Lock.tga",
    unlock = texturePath .. "Vertex-Unlock.tga",
    visible = texturePath .. "Visible.tga",
    hidden = texturePath .. "Hidden.tga",
    advanced = texturePath .. "Advanced.tga",
    advancedDisabled = texturePath .. "Advanced-Disabled.tga",
    settings = texturePath .. "Vertex-Settings.tga",
    gear = texturePath .. "Vertex-Gear.tga",
    scale = texturePath .. "Vertex-Scale.tga",
    plus = texturePath .. "Vertex-Plus.tga",
    minus = texturePath .. "Vertex-Minus.tga",
    arrowUp = texturePath .. "Vertex-Arrow.tga",
    arrowDown = texturePath .. "Vertex-Arrow-Down.tga",
    arrowLeft = texturePath .. "Vertex-Arrow-Left.tga",
    arrowRight = texturePath .. "Vertex-Arrow-Right.tga",
    caretUp = texturePath .. "Vertex-Caret-Up.tga",
    caretDown = texturePath .. "Vertex-Caret-Down.tga",
    caretLeft = texturePath .. "Vertex-Caret-Left.tga",
    caretRight = texturePath .. "Vertex-Caret-Right.tga",
}

function lib:GetIconTexture(name)
    local texture = self._media[name]
    assert(texture, "unknown icon texture: " .. tostring(name))
    return texture
end

-- Persistent prototypes keep existing handles valid across compatible embeds.
lib._implementationMinor = MINOR
lib._modules = lib._modules or {}
lib._contexts = lib._contexts or {}
lib._roles = lib._roles or {}
lib._skins = lib._skins or {}
lib._contextPrototype = lib._contextPrototype or {}
lib._handlePrototype = lib._handlePrototype or {}
lib._borderPrototype = lib._borderPrototype or {}
lib.Pixel = lib.Pixel or {}

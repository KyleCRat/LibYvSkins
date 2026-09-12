local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then
    return
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

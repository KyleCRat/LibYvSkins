-- Development-only: load after embed.xml in an in-game harness, not a release.
local Skins = LibStub("LibYvSkins-1.0")

local function CreateFixture(name, color, offset, scale)
    local context = Skins:CreateContext(name, { tokens = { accent = color } })
    local panel = context:CreateWindow(UIParent, {
        title = name, minWidth = 280, minHeight = 220,
    })
    panel:SetScale(scale)
    panel:SetPoint("CENTER", UIParent, "CENTER", offset + 0.17, 0.23)
    local text = panel.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOP", 0, -8)
    text:SetText(name .. " - 1px line / 2px border")
    local expanded = true
    local header, appearance = context:CreateExpandableHeader(panel.content, {
        geometryRoot = panel, height = 31, text = "Accordion preview", expanded = expanded,
    })
    header:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 8, -28)
    header:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -8, -28)
    header:SetScript("OnClick", function()
        expanded = not expanded
        appearance:SetExpanded(expanded)
    end)
    context:CreateSeparator(panel.content, { geometryRoot = panel, left = 8, right = 8 })
    local border = Skins.Pixel.CreateBorder(panel.content, panel.content)
    border:SetColor(color.r, color.g, color.b)
    local metrics = {}
    local function Refresh()
        context:RefreshGeometry(panel)
        Skins.Pixel.UpdateMetrics(metrics, panel)
        border:Layout(metrics, 2)
    end
    panel:HookScript("OnSizeChanged", Refresh)
    panel:HookScript("OnShow", Refresh)
    panel:RegisterEvent("UI_SCALE_CHANGED")
    panel:RegisterEvent("DISPLAY_SIZE_CHANGED")
    panel:SetScript("OnEvent", function()
        C_Timer.After(0, function()
            -- Low-level border handles are refreshed by their consumer. Do not
            -- depend on the order of this fixture's and the library's timers.
            Skins.Pixel.InvalidateDisplay()
            Refresh()
        end)
    end)
    Refresh()
    panel:Show()
    return panel
end

CreateFixture("PixelHarnessA", { r = 0.15, g = 0.88, b = 1 }, -180, 0.75)
CreateFixture("PixelHarnessB", { r = 1, g = 0.65, b = 0.1 }, 180, 1.25)

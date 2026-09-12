-- Development-only: load after embed.xml in an in-game harness, not a release.
local Skins = LibStub("LibYvSkins-1.0")

local function CreateFixture(name, color, offset, scale)
    local context = Skins:CreateContext(name, {
        tokens = { accent = color }, font = "Fonts\\FRIZQT__.TTF",
        iconBorder = "Interface\\Buttons\\UI-Quickslot2",
    })
    local panel = context:CreateWindow(UIParent, {
        title = name, minWidth = 340, minHeight = 390, compactHeader = true,
    })
    panel:SetScale(scale)
    panel:SetPoint("CENTER", UIParent, "CENTER", offset + 0.17, 0.23)
    local search = context:CreateSearchBox(panel.header, { geometryRoot = panel, height = 28 })
    context:SetHeaderControls(panel, {}, search)
    search.Instructions:SetText("Search preview")
    local text = context:CreateText(panel.content, {
        geometryRoot = panel, colorToken = "accent", text = name .. " - native controls",
    })
    text:SetPoint("TOP", panel.content, "TOP", 0, -8)
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
    local tab, tabAppearance = context:CreateTab(panel.content, {
        geometryRoot = panel, text = "Selected tab", width = 140, height = 28, selected = true,
    })
    tab:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 4, -10)
    tab:SetScript("OnClick", function() tabAppearance:SetSelected(not tabAppearance.selected) end)
    local checkbox = context:CreateCheckbox(panel.content, { geometryRoot = panel, width = 28, height = 28 })
    checkbox:SetPoint("LEFT", tab, "RIGHT", 8, 0)
    checkbox:SetChecked(true)
    local input = context:CreateEditBox(panel.content, { geometryRoot = panel, width = 240, height = 28 })
    input:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", 0, -10)
    input:SetText("Focus and edit this text")
    local icon, iconAppearance = context:CreateIcon(panel.content, { geometryRoot = panel })
    icon:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 4, -14)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
    iconAppearance:SetBorderColor(0.64, 0.21, 0.93)
    local glow = context:CreateGlowBorder(panel.content, { geometryRoot = panel })
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", -4, -12)
    glow:SetSize(240, 38)
    local bar = context:CreateScrollBar(panel.content, { geometryRoot = panel })
    bar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -10)
    bar:SetPoint("BOTTOMRIGHT", panel.content, "BOTTOMRIGHT", -8, 12)
    local scaleButton = context:CreateButton(panel.footer, {
        geometryRoot = panel, text = "Scale", width = 88, height = 28,
    })
    scaleButton:SetPoint("LEFT", panel.footer, "LEFT", 8, 0)
    local skinButton = context:CreateButton(panel.footer, {
        geometryRoot = panel, text = "Switch skin", width = 110, height = 28,
    })
    skinButton:SetPoint("LEFT", scaleButton, "RIGHT", 4, 0)
    skinButton:SetScript("OnClick", function()
        context:RequestSkin(context:GetAppliedSkin() == "modern" and "flat" or "modern")
    end)
    local popup = context:CreatePopupSlider(scaleButton, {
        minValue = 50, maxValue = 150, step = 5, label = "Scale",
        onValueChanged = function(value)
            panel:SetScale(value / 100)
            context:RefreshGeometry(panel)
        end,
    })
    if popup then popup:SetValue(scale * 100, true) end
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

CreateFixture("PixelHarnessA", { r = 0.15, g = 0.88, b = 1 }, -220, 0.75)
CreateFixture("PixelHarnessB", { r = 1, g = 0.65, b = 0.1 }, 220, 1.25)

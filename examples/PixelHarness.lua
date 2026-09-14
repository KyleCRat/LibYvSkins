-- Development-only: load after embed.xml in an in-game harness, not a release.
local Skins = LibStub("LibYvSkins-1.0")

local function CreateFixture(name, color, offset, scale)
    local context = Skins:CreateContext(name, {
        tokens = { accent = color }, font = "Fonts\\FRIZQT__.TTF",
        iconBorder = "Interface\\Buttons\\UI-Quickslot2",
    })
    local panel = context:CreateWindow(UIParent, {
        title = name, minWidth = 340, minHeight = 430,
        -- This consumer retains its Title Bar under both skins and uses a
        -- two-row Footer. Neither arrangement is inferred from the skin.
        layout = {
            padding = 8, header = { height = 60, gap = 8 },
            titleBar = { height = 24 }, footer = { height = 64, gap = 8 },
        },
    })
    panel:SetScale(scale)
    panel:SetPoint("CENTER", UIParent, "CENTER", offset + 0.17, 0.23)
    local toolbar = context:CreateToolbar(panel.header, { height = 28 })
    toolbar:SetPoint("TOPLEFT", panel.header, "TOPLEFT", 0, -32)
    toolbar:SetPoint("TOPRIGHT", panel.header, "TOPRIGHT", 0, -32)
    local search = context:CreateSearchBox(toolbar, { geometryRoot = panel, height = 28 })
    context:SetToolbarItems(toolbar, { { control = search, stretch = true, minWidth = 96 } })
    search.Instructions:SetText("Search preview")
    local text = context:CreateText(panel.body, {
        geometryRoot = panel, colorToken = "accent", text = name .. " - native controls",
    })
    text:SetPoint("TOP", panel.body, "TOP", 0, -8)
    local expanded = true
    local header, appearance = context:CreateExpandableHeader(panel.body, {
        geometryRoot = panel, height = 31, text = "Accordion preview", expanded = expanded,
    })
    header:SetPoint("TOPLEFT", panel.body, "TOPLEFT", 8, -28)
    header:SetPoint("TOPRIGHT", panel.body, "TOPRIGHT", -8, -28)
    header:SetScript("OnClick", function()
        expanded = not expanded
        appearance:SetExpanded(expanded)
    end)
    local tab, tabAppearance = context:CreateTab(panel.body, {
        geometryRoot = panel, text = "Selected tab", width = 140, height = 28, selected = true,
    })
    tab:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 4, -10)
    tab:SetScript("OnClick", function() tabAppearance:SetSelected(not tabAppearance.selected) end)
    local checkbox = context:CreateCheckbox(panel.body, { geometryRoot = panel, width = 28, height = 28 })
    checkbox:SetPoint("LEFT", tab, "RIGHT", 8, 0)
    checkbox:SetChecked(true)
    local input = context:CreateEditBox(panel.body, { geometryRoot = panel, width = 240, height = 28 })
    input:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", 0, -10)
    input:SetText("Focus and edit this text")
    local icon, iconAppearance = context:CreateIcon(panel.body, { geometryRoot = panel })
    icon:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 4, -14)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
    iconAppearance:SetBorderColor(0.64, 0.21, 0.93)
    local glow = context:CreateGlowBorder(panel.body, { geometryRoot = panel })
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", -4, -12)
    glow:SetSize(240, 38)
    local bar = context:CreateScrollBar(panel.body, { geometryRoot = panel })
    bar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -10)
    bar:SetPoint("BOTTOMRIGHT", panel.body, "BOTTOMRIGHT", -8, 12)
    local scaleButton = context:CreateButton(panel.footer, {
        geometryRoot = panel, text = "Scale", width = 88, height = 28,
    })
    local skinButton = context:CreateButton(panel.footer, {
        geometryRoot = panel, text = "Switch skin", width = 110, height = 28,
    })
    local footerToolbar = context:CreateToolbar(panel.footer, { height = 28 })
    footerToolbar:SetPoint("TOPLEFT", panel.footer, "TOPLEFT", 0, 0)
    footerToolbar:SetPoint("TOPRIGHT", panel.footer, "TOPRIGHT", 0, 0)
    context:SetToolbarItems(footerToolbar, { scaleButton, skinButton })
    local status = context:CreateText(panel.footer, { text = "Title Bar retained in both skins", geometryRoot = panel })
    status:SetPoint("TOPLEFT", footerToolbar, "BOTTOMLEFT", 0, -8)
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
    context:CreateSeparator(panel.body, { geometryRoot = panel, left = 8, right = 8 })
    local border = Skins.Pixel.CreateBorder(panel.body, panel.body)
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

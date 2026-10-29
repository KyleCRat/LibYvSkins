return function(H, Test)
    Test(
        "LMS tab styling is explicit and preserves consumer behavior",
        function()
            local state = H.New()
            local library = state:Load()
            H.Equal(state.env.LibStub("LibModernSettings-1.0", true), nil)
            local context = library:CreateContext("Settings", {
                tokens = { accent = { r = 0.1, g = 0.2, b = 0.3 } },
                font = "consumer-font",
            })
            local other = library:CreateContext("Other")
            local function tab()
                local control = state.env.CreateFrame("Button")
                control:SetSize(116, 32)
                control.selected = true
                control.click = function() end

                function control:SetTabAppearance(options)
                    self.appearance = options
                end

                function control:RefreshTabGeometry()
                    self.geometryUpdates = (self.geometryUpdates or 0) + 1
                end

                return control
            end
            local first, second = tab(), tab()
            local click = first.click
            local handle = context:StyleSettingsTab(first)
            other:StyleSettingsTab(second)
            H.Equal(context:StyleSettingsTab(first), handle)
            H.Equal(first.appearance.mode, "header")
            H.Equal(first.appearance.font, "consumer-font")
            context:RequestSkin("flat")
            state:Flush()
            H.Equal(first.appearance.mode, "flat")
            H.Equal(first.appearance.colors.flatAccent[1], 0.1)
            H.Equal(second.appearance.mode, "header")
            context:SetTokens({ accent = { r = 0.6, g = 0.5, b = 0.4 } })
            H.Equal(first.appearance.colors.selectedText[1], 0.6)
            H.Equal(first.selected, true)
            H.Equal(first.click, click)
            H.Equal(first:GetWidth(), 116)
            H.Equal(first:IsEnabled(), true)
            local previousGeometry = first.geometryUpdates
            state:Load(library._implementationMinor + 1)
            context:RequestSkin("modern")
            state:Flush()
            H.Equal(first.appearance.mode, "header")
            H.Equal(first.appearance.texture, nil)
            H.Equal(first.geometryUpdates > previousGeometry, true)
            H.Equal(first.selected, true)
            H.Fails(function()
                context:StyleSettingsTab(state.env.CreateFrame("Button"))
            end)
        end
    )
end

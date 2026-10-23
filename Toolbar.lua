local MAJOR, MINOR = "LibYvSkins-1.0", 1
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or lib._modules.Toolbar == MINOR
then
    return
end

lib._modules.Toolbar = MINOR

local Context = lib._contextPrototype

local function IsSize(value)
    return type(value) == "number" and value >= 0 and value < math.huge
end

local function GetToolbar(context, toolbar)
    return assert(
        context._toolbars and context._toolbars[toolbar],
        "toolbar must belong to this context"
    )
end

-- A toolbar is an optional row helper, not a window region or a skin policy.
-- One flexible-width control can separate fixed leading and trailing controls.
function Context:CreateToolbar(parent, options)
    options = options or {}
    assert(type(options) == "table", "toolbar options must be a table")
    assert(
        parent and type(parent.GetEffectiveScale) == "function",
        "toolbar parent must be a frame"
    )
    local height, gap = options.height, options.gap

    if height == nil then height = 28 end

    if gap == nil then gap = 4 end

    assert(
        IsSize(height) and height > 0,
        "toolbar height must be finite and positive"
    )
    assert(IsSize(gap), "toolbar gap must be finite and nonnegative")
    local toolbar = CreateFrame("Frame", nil, parent)
    toolbar:SetHeight(height)
    self._toolbars = self._toolbars or {}
    self._toolbars[toolbar] = {
        gap = gap,
        items = {},
    }
    return toolbar
end

function Context:SetToolbarItems(toolbar, items, gap)
    local data = GetToolbar(self, toolbar)
    assert(type(items) == "table", "toolbar items must be an ordered list")
    assert(
        gap == nil or IsSize(gap),
        "toolbar gap must be finite and nonnegative"
    )
    local result, controls, stretch = {}, {}, false

    for _, entry in ipairs(items) do
        assert(
            type(entry) == "table",
            "toolbar entries must be controls or descriptors"
        )
        local control = entry.control or entry
        assert(
            type(control) == "table"
                and type(control.GetWidth) == "function"
                and type(control.ClearAllPoints) == "function",
            "toolbar items require controls"
        )
        assert(
            not controls[control],
            "a toolbar cannot contain a control twice"
        )
        controls[control] = true
        local flexible = entry.control and entry.stretch == true
        assert(
            not entry.control
                or entry.stretch == nil
                or type(entry.stretch) == "boolean",
            "stretch must be boolean"
        )
        assert(
            not flexible or not stretch,
            "a toolbar supports one flexible-width control"
        )
        local minWidth = entry.control and entry.minWidth or 0
        assert(
            IsSize(minWidth),
            "toolbar minimum widths must be finite and nonnegative"
        )
        result[#result + 1] = {
            control = control,
            stretch = flexible,
            minWidth = minWidth,
        }
        stretch = stretch or flexible
    end

    data.items, data.gap = result, gap or data.gap
    self:LayoutToolbar(toolbar)
end

function Context:GetToolbarMinimumWidth(toolbar)
    local data = GetToolbar(self, toolbar)
    local width, count = 0, 0

    for _, item in ipairs(data.items) do
        if item.control:IsShown() then
            width = width
                + (
                    item.stretch and item.minWidth
                    or math.max(item.minWidth, item.control:GetWidth())
                )
            count = count + 1
        end
    end

    return width + math.max(0, count - 1) * data.gap
end

function Context:LayoutToolbar(toolbar)
    local data = GetToolbar(self, toolbar)
    local previous, flexible, flexibleIndex

    for index, item in ipairs(data.items) do
        local control = item.control

        if control:IsShown() then
            control:ClearAllPoints()

            if item.stretch then
                flexible, flexibleIndex = control, index
                break
            end

            control:SetPoint(
                "LEFT",
                previous or toolbar,
                previous and "RIGHT" or "LEFT",
                previous and data.gap or 0,
                0
            )
            previous = control
        end
    end

    if not flexible then return end

    local following

    for index = #data.items, flexibleIndex + 1, -1 do
        local control = data.items[index].control

        if control:IsShown() then
            control:ClearAllPoints()
            control:SetPoint(
                "RIGHT",
                following or toolbar,
                following and "LEFT" or "RIGHT",
                following and -data.gap or 0,
                0
            )
            following = control
        end
    end

    flexible:SetPoint(
        "LEFT",
        previous or toolbar,
        previous and "RIGHT" or "LEFT",
        previous and data.gap or 0,
        0
    )
    flexible:SetPoint(
        "RIGHT",
        following or toolbar,
        following and "LEFT" or "RIGHT",
        following and -data.gap or 0,
        0
    )
end

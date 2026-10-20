# LibYvSkins

Creation-first windows and appearance primitives for World of Warcraft addons,
by Yvairel.
MIT licensed. LibStub API family: `LibYvSkins-1.0`, implementation MINOR `1`.
No release has been tagged yet.

This development snapshot implements live Modern/Flat selection, windows,
controls, icon surfaces, list accents, and pixel primitives. YvBags is the first
native consumer: it builds on library-created frames, not existing-window
adapters. The optional EllesmereUI provider remains a subsequent phase.
Consumers own preference storage; the library owns no SavedVariables, inventory
logic, or third-party styling. YvBags' Modern and Flat MVP appearances have
passed in-game review. The subsequent window-layout refactor and broader
release validation still need consumer smoke testing.

## Embedding

Load LibStub before `embed.xml`. Runtime files are Lua 5.1 and use Blizzard's
`PixelUtil` and normal texture/frame APIs. The inspected client source is
Retail 12.1.0.69497; in-game validation is required before release, including
any additional client versions advertised by a consumer.

Window chrome was rechecked against Retail 12.1.5.70448 (`f54dee9`):
`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml` supplies native title,
close and border geometry; its Lua portrait helpers adjust background insets.
`Blizzard_SharedXML/PortraitFrame.lua` supplies `SetFrameLevelsFromBaseLevel`
to restore native chrome ordering after reparenting the title.

The Git repository is unversioned (`LibYvSkins`); the embed directory follows
the API family (`LibYvSkins-1.0`). Embed it at `Libs/LibYvSkins-1.0`, including
its `Media` directory. Owned textures resolve from the winning embed's addon
name (or the `LibYvSkins-1.0` root when loaded standalone), not the consumer
context name. Centered 64x64 Vertex glyphs are bundled with the library; no
other addon supplies them at runtime. The first intended release tag is `1.0.0`.
Only increment MINOR when preparing a subsequent published implementation,
not for each development change. Preserve all split-file guards: old embeds
must not replace modules from the newer implementation selected by LibStub.

## Contexts And Windows

Create one stable context per consuming addon. Repeating its name returns the
existing context without replacing its tokens or registrations. Tokens are
copied; contexts never share a selected appearance or mutate each other's media.

```lua
local Skins = LibStub("LibYvSkins-1.0")
local context = Skins:CreateContext("MyAddon", {
    tokens = { accent = { r = 0.15, g = 0.88, b = 1 } },
    font = "Fonts\\FRIZQT__.TTF",
    iconBorder = "Interface\\Buttons\\UI-Quickslot2",
})

local window = context:CreateWindow(UIParent, {
    name = "MyAddonWindow", title = "My Addon",
    minWidth = 420, minHeight = 360, maxWidth = 1000,
    -- This structure is retained under either skin.
    layout = {
        padding = 8,
        header = { height = 60, gap = 8 },
        titleBar = { height = 24 },
        footer = { height = 48, gap = 8 },
    },
    onMoveStopped = function(frame)
        -- Save the ordinary frame's point/size through the addon's own DB.
    end,
    onResizeStopped = function(frame)
        -- The native resize operation has already stopped.
    end,
})
window:SetSize(600, 500)
window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
window:Show()
```

`CreateWindow` returns an ordinary `ButtonFrameTemplate` Frame, initially hidden
and unpositioned. `minWidth` and `minHeight` are required positive numbers;
optional maxima must be at least their matching minima. `name`, `title`,
`portrait`, `insetBackground`, and `strata` customize presentation; the default
strata is `HIGH`, and the default tiled inset is Blizzard's Midnight background.
Modern retains the original outer background; Flat uses a neutral solid surface.

### Window Vocabulary And Ownership

- **Window:** the whole movable/resizable container.
- **Header:** everything above the primary Body, including any Title Bar,
  toolbars, tabs, or custom content. It is not a synonym for a toolbar.
- **Title Bar:** an optional row inside Header containing the window's title.
  **Title** means the text itself; dragging is not restricted to this row.
- **Toolbar:** an optional row helper for controls, usable in any section.
- **Body:** the primary working area, which fills the remaining space. It does
  not imply a list, scrolling, or any specific addon content.
- **Footer:** an optional lower section; it may contain multiple rows.
- **Control:** an individual button, input, checkbox, etc., not a section.
- **Layout:** section presence, dimensions, and arrangement, chosen by the addon.
- **Skin/renderer:** visual treatment, asset-specific offsets, and default
  measurements. Selecting Flat does not inherently remove a Title Bar.

Padding is internal space, margin is external space, gap separates siblings,
and a visual offset corrects artwork without changing its control's layout.
The window shell is the library's container/layout machinery, not another
visible section. Qualify nested headers, e.g. Window Header versus List Header.

The constructor owns these public frame parts and their outer anchors:

- `window.header`: complete upper section; populate its interior freely.
- `window.titleBar`: optional row inside Header, containing native TitleContainer.
- `window.body`: primary viewport; mount a list or other addon content here.
- `window.footer`: footer area; its interior remains consumer-owned.
- `window.resizeButton`: native `PanelResizeButtonTemplate`, initialized once.
- `window.Inset`, `TitleContainer`, and `CloseButton`: original native parts.

`window:SetTitle(text)` retains its native direct access. `movable = false`
disables background moving; `resizable = false` hides the native grip and
disables resizing. Both default to true. Close placement is declared by layout.

### Explicit Window Layout

`layout` is the complete fallback specification for every skin. Optional
`layouts = { modern = {...}, flat = {...} }` replaces it for named skins; these
are complete specifications, not deep merges. All nested measurements are
copied during construction. Omitted Header/Footer/Title Bar sections are absent;
an empty specification creates a Body-only shell with skin-default padding.

- `padding`: window padding, as one nonnegative UI-unit number or independent
  `left`, `right`, `top`, `bottom` values. Omitted edges use skin defaults.
- `header` / `footer`: tables with `height`, `gap`, and optional `margin` edges,
  or false. Height zero removes the section and its margins/gap. Header gap is
  below Header; Footer gap is above Footer. Neither section wraps automatically.
- `titleBar`: false or `{ height = ..., margin = ... }`. Height defaults to the
  skin's title measurement. Its height and explicit vertical margins must fit
  inside Header's declared height; it does not consume a second allocation
  outside Header. Modern defaults its left/right/top margins to extend through
  content padding and Header margins to the native window edge, keeping the
  title and Close aligned with the border. Flat stays inside the padded Header.
  Explicit margin edges override these defaults, including zero.
- `body`: optional `padding` within the inset border and `margin` outside it.
  Body otherwise fills between the upper/lower sections. Header/Footer interiors
  remain addon-owned; the shell does not infer padding from their children.
- Margins accept independent edges or a uniform number; negative margins allow
  intentional full-bleed artwork. Omitted margin edges are zero except for
  Modern's Title Bar defaults above.
- `portrait`: explicitly show the supplied native portrait; default false.
- `closeButton`: `"titleBar"`, `"manual"`, or false. The default follows the
  declared Title Bar, not the skin. Manual placement shows the same native
  Close button but leaves its anchors and size to the addon, e.g. as a toolbar
  item. Renderers still own its visual treatment and native scripts stay intact.

`onLayout(window)` runs after section anchors are applied, during construction
and after changing layout/skin. Use it to arrange existing addon-owned content;
initial construction precedes creation of those controls. Ordinary resizing
flows through anchors and does not repeatedly invoke this callback.

`SetWindowLayout(window, specification, skin)` replaces a complete specification.
Omit `skin` to replace all skin variants. It updates Body allocation without
recreating controls, moving/resizing the outer window, or revealing hidden Body
content. Explicit layout changes are rejected during combat or window drags.
For measured custom headers/footers, submit their new heights through this API,
not by resizing the library's section frames directly. Consumers remain
responsible for minimum window bounds and prewarming protected content before
an explicit layout change that increases its viewport.

Non-action window backgrounds support native dragging outside combat in both
skins; optional `onMoveStopped(frame)` and
`onResizeStopped(frame)` run after movement ends. Resize completion also handles
releases outside the grip without duplicating the native completion callback.
The library owns no saved
position, scale, or size: consumers restore/persist these and call
`context:RefreshGeometry(window)` after explicit scale/position changes.
Consumers also own client-position-saving policy (`SetDontSavePosition` /
`SetUserPlaced`) and may directly replace `CloseButton`'s `OnClick`, such as
closing a native bank session. No input/value getters are wrapped.

`context:RegisterWindowDragRegion(window, region)` adds an addon-created
background, such as an empty ScrollBox or a tooltip-only money display, to the
same movement lifecycle. Registration is idempotent, preserves other scripts,
and rejects regions that already own drag handlers. Register backgrounds only:
child item/action buttons retain their own clicks and drags. No click-through
overlay, global mouse propagation, or polling is installed.

The factory installs show/size geometry hooks once and preserves consumer
scripts. A window retains its geometry root for its lifetime, even without
registered strokes. `context:GetWindowBodyWidthOverhead(window)` returns the current
horizontal Body overhead for consumer size constraints without duplicating
inset constants; omitting the window returns the active skin's default overhead. Do not
reposition the library's slots from addon refresh handlers.
There is no `RegisterWindow` or arbitrary existing-window skinning API.

### Optional Toolbars And Minimum Measurements

```lua
local toolbar = context:CreateToolbar(window.header, { height = 28, gap = 4 })
toolbar:SetPoint("TOPLEFT", window.header, "TOPLEFT", 0, -32)
toolbar:SetPoint("TOPRIGHT", window.header, "TOPRIGHT", 0, -32)
local action = context:CreateButton(toolbar, { text = "Apply", width = 80, height = 28 })
local input = context:CreateEditBox(toolbar, { height = 28 })
context:SetToolbarItems(toolbar, {
    action,
    { control = input, stretch = true, minWidth = 96 },
})
```

Toolbar creation returns a raw Frame. The caller chooses its parent and anchors;
multiple toolbars can occupy any section. Ordered items may be raw controls or
`{ control = frame, stretch = true, minWidth = number }` descriptors. At most one
control stretches horizontally; fixed controls before/after it are leading and
trailing. With no stretch item, controls align left. No search field is required.
Controls keep their heights and are vertically centered. The helper does not
reparent controls, install input scripts, or decide which controls are visible.
Removing an item from the arrangement does not hide it.

`SetToolbarItems(toolbar, items, gap)` copies the list and optionally replaces
the gap. `LayoutToolbar(toolbar)` reapplies it after caller-driven visibility or
width changes; it allocates no regions/hooks and does no font/atlas work.
`GetToolbarMinimumWidth(toolbar)` measures shown controls and flexible minimums.
The caller must provide sufficient width; the helper does not wrap or hide items.

Window `getMinimumWidth(window)` is an optional addon callback that combines
its toolbar/custom-content minimums and outer spacing. `GetWindowMinimumWidth`
returns the greater of that result and constructor `minWidth`; without the
callback there is no implicit toolbar/search requirement. Consumers apply this
measurement to their native resize bounds.

`GetWindowBodyReserve(window)` reports additional viewport height available
under the largest declared skin layout, for protected-row prewarming. It is
calculated from section/margin/padding totals rather than a hardcoded skin delta.

This unreleased API replaces `compactHeader`, `SetHeaderControls`, `LayoutHeader`,
`IsWindowCompact`, `window.content`, and the old chrome/content measurement names.
YvBags is the only current consumer and has been converted with the library;
no SavedVariables migration or release-version bump is involved.

## Skin Selection

`context:RequestSkin("modern" / "flat")` records the latest request and
coalesces its application onto the next frame. `GetAppliedSkin()` reports the
active renderer. `GetSkinStatus()` returns requested ID, applied ID, and an
optional pending reason: `queued`, `combat`, `interaction`, or `unavailable`.
Requesting the applied skin cancels a pending change. Persistence belongs to
the addon, not this library, and independent contexts can choose different skins.

Transitions wait for combat to end or library-window moving/resizing and
supported popup drags to finish. End notifications retry once; there is no
polling loop. An inactive popup closes before applying. Legacy popup contracts
reject Flat before changing any component, leaving Modern applied.

`SetSkinCallbacks({ beforeApply = fn, onApplied = fn, onStatusChanged = fn })`
registers consumer hooks, each receiving the context. Use `beforeApply` to
cancel column gestures and prewarm any additional native viewport rows after
window size changes; count active rows toward that budget. Use `onApplied`
for presentation-only resize constraints and `onStatusChanged` for Settings
status. Never rebuild inventory/providers or commit geometry just to reskin.

YvBags explicitly declares a Title Bar plus Toolbar for Modern, and a Toolbar
with Close for Flat. Its 28-unit toolbar, 24/28-unit footers, search minimum,
footer grip clearance, and per-skin arrangement live in that addon, not library
policy. The development example instead retains its Title Bar and a two-row
Footer in both skins, demonstrating a different consumer structure.

Flat surfaces use preallocated, screen-snapped, nonoverlapping one-physical-
pixel edges. Icon borders use one physical pixel outside the artwork, keeping
the Modern border footprint where possible and expanding at small effective
scales to leave the art unobscured. Generic action glyphs, focus, and selected
states use the context accent, with neutral surfaces and disabled states.
Checkboxes retain their native checkmark atlas and scale, with a separate
one-physical-pixel downward offset in Flat. Button and close glyphs center
within the same snapped bounds as their borders. Their rendered dimensions
match the bounds' odd/even pixel counts, adjusting at most one physical pixel
per axis for equal integer margins. Modern restores nominal dimensions and
texture snapping; text alignment remains independent. Flat close and search-clear
controls use `Vertex-Close.tga`; accordion and scrollbar carets use dedicated
directional textures without rotation or the previous optical offsets.
The resize grip has no surrounding surface.
Semantic text/icon colors, input values, focus, checked/expanded state, and
hidden pool members survive round trips. Flat controls/icons can receive an
optional same-scale `clip` region for pixel-snapped viewport clipping.

## Native Controls And Visual Handles

Every component factory returns the raw WoW control/region first and its stable
appearance handle second. Call `SetText`, `GetText`, `SetChecked`, `SetEnabled`,
`SetScript`, and other native behavior directly. Handles hold presentation state,
not control values or a second layout/field abstraction. LMS remains independent.

```lua
local tab, appearance = context:CreateTab(window.header, {
    geometryRoot = window, text = "Character", width = 108, height = 28,
})
tab:SetPoint("LEFT", window.header, "LEFT", 0, 0)
appearance:SetSelected(true)
tab:SetScript("OnClick", function()
    -- Consumer selects a view, then reports selection through the handle.
end)

local search = context:CreateSearchBox(window.header, {
    geometryRoot = window, width = 220, height = 28, fontSize = 13,
    focusGlow = false,
})
search:SetPoint("LEFT", tab, "RIGHT", 4, 0)
search:HookScript("OnTextChanged", function(input)
    -- Consumer filters its own data using input:GetText().
end)
```

| Factory | Modern presentation / state |
| --- | --- |
| `CreateButton` | Regular tertiary command or `variant = "square"`; hover, press, disabled art. Handle: `SetVariant("command" / "square")`. |
| `CreateTab` | Regular tertiary selected state with a 3-unit outset, or nine-slice header artwork with `tabStyle = "header"`. `SetSelected(boolean)` takes precedence over hover and press. |
| `CreateCheckbox` | Square tertiary CheckButton with native checked/disabled-checked textures. Use raw `SetChecked` / `GetChecked`. |
| `CreateEditBox` | Tertiary-depressed input with native input scripts and optional focus glow. No value-commit policy. |
| `CreateSearchBox` | Same background, preserving native search/placeholder/clear behavior and tuned icon anchors. |
| `CreateScrollBar` | Native `MinimalScrollBar`, with only its visual callbacks dispatched to the renderer. Bind ScrollBox/scroll behavior normally. |
| `CreateText` | Raw FontString; context font and optional color token, otherwise consumer-owned semantic text color. |
| `CreateTexture` | Raw Texture; initial `texture` path/file ID or `atlas`, otherwise a solid surface. Optional token tint. |
| `CreateIcon` | Raw icon Texture with a sibling textured border; semantic border color and visibility live on its handle. |
| `CreateGlowBorder` | Eight-part Modern accent glow. Consumer owns activation and any AnimationGroup on the returned Frame. |

Common options include `geometryRoot`, `width`, `height`, `font`, `fontSize`,
`fontFlags`, and `alpha` where applicable. Descendants share their window's
geometry root and effective scale. Defaults for ordinary buttons/inputs are
100/320 units wide and 34 high; checkboxes are 34 square. Fonts default to the
context font at size 13, or the corresponding native FontObject when omitted.
For buttons, `fontObject` takes precedence over the custom font.

`LibYvSkins:GetIconTexture(name)` returns a bundled Vertex texture path for
`close`, `clone`, `folder`, `lock`, `unlock`, `visible`, `hidden`, `advanced`, `advancedDisabled`,
`settings`, `gear`, `scale`, `plus`, `minus`,
`arrowUp`, `arrowDown`, `arrowLeft`, `arrowRight`, `caretUp`, `caretDown`,
`caretLeft`, or `caretRight`.
The up-arrow asset is named `Vertex-Arrow.tga`. Unknown names raise an error.
Use these paths with existing button, texture, or icon factories; directional
variants do not need rotation or flipped UVs.

Buttons accept `text`, either `icon` or `iconAtlas`, `iconWidth` / `iconHeight`
(18), `iconAlpha` (1), `disabledIconAlpha` (0.5), `pressIcon` (false), and
`labelOffsetY` (1, with skin-specific optical adjustments). `template` may supply native behavior, such as
`DisabledTooltipButtonTemplate`; use behavior-only templates without competing
art. `button.Text` and the handle's `parts.label` refer to its native FontString;
`parts.icon` is present when requested. Button glyphs use gold in Modern and
the context accent in Flat. Set `preserveIconColor = true` for multicolor
artwork that should skip both tints; disabled desaturation and hover/disabled
alpha still apply. It defaults to false.
Checkbox `checkmarkScale` defaults to 1.25. Input `focusGlow` defaults to true.
Caller-owned anchors and dimensions
remain independent of input values and visual state.

`CreateTab(parent, { tabStyle = "header", text = "Display" })` opts into the
bundled header atlas in Modern. It defaults to 64 UI units high; the effective
UI scale determines its physical size. Corners retain their size as width and
height increase, while the edges and fill stretch. Compact tabs reduce the
corners proportionally in both dimensions. A dark grey background accent sits
above the fill and beneath the border and gold highlights.
Slice boundaries snap to physical screen pixels; linear filtering keeps the
antialiased corners and glow smooth when scaled. Caller-owned button anchors
and dimensions stay intact. Header tabs use the command variant and retain the usual
`SetSelected` handle and native click/enabled APIs. Flat renders these tabs with
its standard flat surfaces.
Omitting `tabStyle` retains the existing tertiary tab appearance.

Scrollbars optionally accept `anchor` and a positive `gutterWidth` to let the
renderer own their outer anchors. The gutter is inside the anchor's right edge:
Flat centers the native bar in it; Modern uses `rightOffset` (default 0).
`topOffset` and `bottomOffset` (both default 0) apply in both skins. The anchor
must share the parent's effective scale. Flat shortens the gaps between the
arrows and track; Modern restores the template's track anchors. Native thumb,
stepper, drag, and ScrollBox behavior remain unchanged. Without `anchor`, the
caller retains ownership of outer scrollbar placement.

Text/texture factories accept `layer`; textures/icons also accept `sublevel`.
Text and texture colors are consumer-owned unless `colorToken` is supplied.
For token-colored regions, `alpha` multiplies the color opacity without taking
over the raw region's animation alpha. Semantic text, artwork, desaturation,
and visibility survive context refreshes.

Icons require a context `iconBorder` or an explicit `borderTexture`. Defaults
are 23 units square, `borderOutset = 3`, and cropped item UVs (0.08–0.92).
Optional `artworkOutset` (default 0, at most `borderOutset`) expands the initial
artwork dimensions by that many UI units on each edge while retaining the
border footprint in both skins. For example, width 18 with `artworkOutset = 1`
creates 20x20 artwork within the same border. Anchor the returned icon by its
center to retain placement; its native dimensions include the expansion.
Use `crop = false` for atlases. `borderLayer` / `borderSublevel` set layering.
For a button-parented action glyph rather than item artwork, set
`actionIcon = true`: Flat applies the context accent; Modern uses gold when
enabled and gray when disabled, following the parent's desaturation state.
Alpha remains caller-owned. Ordinary icons keep their semantic colors
and desaturation unchanged.
Call `SetBorderColor(r, g, b, a)`, `SetBorderAlpha(alpha)`, and
`SetBorderShown(boolean)` on the handle. `handle:SetShown` updates the icon and
border together; when directly hiding the raw icon, hide its sibling border
through the handle too. Keep handles for pooled rows instead of unregistering
and reconstructing controls on each item assignment.

## Presentation Refresh And Renderer Ownership

`context:RefreshAppearance()` refreshes registered visual state in place;
`SetTokens` merges copied colors and uses the same path. Neither operation
changes values, clears input focus, replaces providers, queries inventory,
rebinds secure buttons, or allocates another set of regions/hooks. Frequent
button hover/press changes use state-only rendering without font/atlas writes.
Pooled hidden components stay hidden. The library has no per-frame update loop.

`Components/` owns construction, declared visual parts, and state handles;
`Skins/Modern.lua` and `Skins/Flat.lua` own generic art and rendering. The window factory also
registers its own native close/resize art for presentation refresh, retaining
Blizzard's input scripts. Consumers supply semantic media and native behavior,
not frame-tree discovery maps or competing hover/selected atlas writers.

## Optional Scale Popup

`context:CreatePopupSlider(button, options)` forwards options to the optional
`LibPopupSlider-1.0` and returns its raw popup plus an appearance handle. The
library adapter uses only the popup's public `GetVisualParts`, `IsInteracting`,
and `SetFontAppearance` APIs. Native values, formatting, drag lifetime, and
fitting stay with LibPopupSlider. Appearance refresh defers font refitting until
the current drag ends.

When LibPopupSlider is absent, the factory returns nil. If an older embed lacks
the presentation APIs, it returns the original working Modern popup, a nil
handle, and a reason. `context:GetPopupSliderSupport()` returns false and that
reason after encountering such a popup. Flat selection rejects an incomplete
transition rather than leaving that popup partially styled. An old
equal-MINOR embed may win during development; verify the loaded implementation
when testing, and publish the owned popup API before releasing skins that rely
on it. The adapter never accesses undocumented popup fields.

## Expandable Headers

`context:CreateExpandableHeader(parent, options)` returns an ordinary Button
and its appearance handle. The Modern bar matches LMS's tertiary accordion
style, with a right-aligned yellow arrow: down when collapsed, up when expanded.
There is no leading icon slot, reserved icon spacing, or separate divider.

```lua
local expanded = true
local header, appearance = context:CreateExpandableHeader(window.body, {
    geometryRoot = window, width = 400, height = 31,
    text = "Consumables (2)", expanded = expanded,
})
header:SetPoint("TOPLEFT", window.body, "TOPLEFT", 0, 0)
header:SetScript("OnClick", function()
    expanded = not expanded
    appearance:SetExpanded(expanded)
    -- The consumer shows/hides its content or updates its list model here.
end)
```

Options include `text`, `expanded` (default true), `width` / `height` (100 / 34
UI units), optional `font` path with `fontSize` (18), `colorToken` (`accent`),
`alpha`, and optional `onClick(button, mouseButton)`. Without a custom font,
the label uses `GameFontNormalLarge`. Text starts at the ordinary 12-unit
button inset, without an icon or its gap. The caller owns the button's anchors.

Use native `SetText`, `GetText`, `GetFontString`, `SetEnabled`, and `SetScript`
directly. Visual hooks preserve consumer scripts, and native Button textures
own pressed/disabled rendering. `appearance:SetExpanded(boolean)` updates
only the arrow; `IsExpanded()` reads that visual state. A click never changes
expansion automatically or rebuilds content: the consumer remains authoritative.

For pooled rows, clear the text and reset expansion, and use
`appearance:SetShown(false)` / `SetShown(true)` on reset/render. Hiding clears
hover and pressed feedback. Controls and hooks are allocated once; parent
anchors and visibility handle Modern scrolling without per-row pixel refreshes.
Flat headers/icons need `handle:RefreshGeometry()` after visible-row placement
so their physical borders remain aligned at fractional scroll origins.
Context token changes recolor labels without changing layout or other addons.

## Separators

```lua
local texture, divider = context:CreateSeparator(window.body, {
    geometryRoot = window,
    orientation = "horizontal",
    align = "end", -- bottom for horizontal, right for vertical
    thickness = 1, -- physical pixels, not UI layout units
    left = 2, right = 2, top = 0, bottom = 0, -- positive UI-unit insets
    alpha = 0.55,
    colorToken = "accent",
    -- bounds defaults to the parent; clip is an optional extra region.
})
```

`CreateSeparator` returns the raw Texture and its stable appearance handle.
Optional `layer` / `sublevel` choose its draw layer (default `BORDER`, `0`).
The factory owns construction and registration; consumers supply placement
and visual options, not prebuilt texture maps. Never register a native secure
item button or use its table to store appearance metadata.

`geometryRoot`, `bounds`, the texture, and optional `clip` must inherit the
same effective scale. Use a separate geometry root for differently scaled
subtrees. Pixel refreshes draw only custom regions, never move/resize a root.

| Method | Contract |
| --- | --- |
| `context:CreateWindow(parent, options)` | Create a Header/Body/Footer shell using explicit consumer layouts. |
| `context:SetWindowLayout(window, layout, skin)` | Replace one or all copied layout variants and recalculate Body space. |
| `context:CreateToolbar(parent, options)` | Create an optional, independently anchored control row. |
| `context:SetToolbarItems(toolbar, items, gap)` | Arrange shown controls with an optional flexible-width item. |
| `context:CreateSeparator(parent, options)` | Create and register a texture together; return the Texture and handle. |
| `context:CreateExpandableHeader(parent, options)` | Create an icon-free Modern accordion Button and its expansion appearance handle. |
| `context:RegisterComponent(role, target, parts, options)` | Low-level constructor backend and explicit external visual extension point, not the primary consumer path. Repeating identical ownership returns its handle without reapplying options. |
| `context:UnregisterComponent(target)` | Hide the owned visual and remove tracking; repeated unregister is harmless. Does not destroy WoW textures or restore external styling. |
| `context:GetColor(token)` | Return `r, g, b, a` without exposing the stored color table. |
| `context:SetTokens(colors)` | Merge copied named colors and refresh registered visuals, without changing geometry. |
| `context:RefreshAppearance()` | Reapply this context's presentation without changing native values, scripts, or domain data. |
| `context:RefreshGeometry(root)` | After parent layout, refresh that root's cached scale and registered custom geometry. Omit the root to refresh the context. Hidden visuals remain hidden. |
| `handle:RefreshGeometry()` | Realign only this stroke using cached root metrics, suitable for visible-row scroll/layout callbacks. |
| `handle:RefreshAppearance()` | Reapply role-owned art, state, color tokens, and opacity without changing layout. |
| `handle:SetAlpha(alpha)` | Set visual opacity without changing its color meaning. |
| `handle:SetShown(boolean)` | Set logical visibility; reset pooled rows to false and restore to true on render. |

`orientation` is `horizontal` (default) or `vertical`. `align` is `start`,
`center` (default), or `end`; start/end mean top/bottom horizontally and
left/right vertically. The default thickness is one physical pixel; zero
hides a stroke. Recycled rows keep their existing handles and regions.

Optional `pixelInsets = { left = 0, right = 0, top = 0, bottom = 0 }` adds
non-negative integer physical-pixel insets after the UI-unit insets and edge
snapping. Omitted edges are zero; the table is copied at registration. For
example, a vertical separator sharing the bottom edge of a one-pixel horizontal
stroke uses `pixelInsets = { bottom = 1 }` to meet it without gaps or overlap
at any scale. A UI-unit bottom inset would instead grow with the frame scale.

Optional `modernLayout` supplies a separate complete geometry definition for
Modern: `bounds` (defaults to the component bounds), `orientation`, `align`,
`thickness`, UI-unit insets, `pixelInsets`, and `clip`. Omitted geometry fields
use the normal constructor defaults, not the outer definition. This keeps
texture-aware Modern spacing independent of Flat's edge joins; switching skins
selects the cached layout without replacing the separator or its visibility state.

## Pixel Primitives

- `Skins.Pixel.Round(region, uiUnits, minPixels)` delegates layout rounding
  to Blizzard PixelUtil. It is not a physical-thickness conversion.
- `Skins.Pixel.GetPhysicalSize(region, pixels)` returns
  `pixels * PixelUtil.GetPixelToUIUnitFactor() / effectiveScale`.
- `Skins.Pixel.UpdateMetrics(metrics, root)` updates a caller-owned metrics
  table for repeated drawing at that root's effective scale.
- `Skins.Pixel.GetCenteredRect(bounds, metrics, width, height)` returns
  relative bottom-left `x, y, width, height` in UI units for a centered glyph.
  Nominal dimensions are rounded to the bounds' odd/even physical-pixel counts,
  giving equal whole-pixel margins within the same inward-snapped border bounds.
  It returns nil when bounds are unresolved or have no drawable area; it does
  not change the region. Refresh metrics/layout after scale or position changes.
- `Skins.Pixel.CreateBorder(parent, bounds, layer, sublevel)` creates four
  solid edge textures and returns a stable border handle. Call
  `border:Layout(metrics, physicalPixels, optionalClip, optionalOutset)`,
  `border:SetColor(r, g, b, a)`, and `border:Hide()` as needed. Horizontal edges
  own corners so translucent edges never overlap. `optionalOutset` expands
  the bounds in non-negative UI units before snapping; it defaults to zero.
  Border handles are low-level
  primitives: their consumer is responsible for refreshing layout/metrics.
- `border:LayoutRelative(metrics, physicalPixels, optionalOutset)` attaches the
  same strokes directly to caller-aligned bounds, without rounding screen edges
  again. Use this when the consumer already owns whole-pixel size and placement.
  Movement and resizing follow anchors without position-dependent corrections;
  refresh after changing scale or crossing the minimum drawable size (twice the
  thickness). Thickness is a non-negative integer number of physical pixels;
  outset is non-negative UI units and defaults to zero. Zero thickness and too-small
  bounds hide all edges. Horizontal strokes own the corners. This mode does not
  clip or align fractional ancestors; use `Layout` for those cases. Both methods
  reuse the same edge textures and may be alternated on one handle.

Absolute drawing rounds screen edges inward to whole pixels, compensating for
fractional window or scroll origins without moving the original frame. Clips
also round inward; partially visible strokes never bleed into adjacent areas.
Texture texel snapping/bias is disabled because these bounds are already aligned.

One library-owned event frame coalesces `UI_SCALE_CHANGED`,
`DISPLAY_SIZE_CHANGED`, and `PLAYER_ENTERING_WORLD` into a next-frame refresh
across contexts. Library-created windows refresh on show/size and move/resize
completion. Consumers explicitly call `RefreshGeometry` after other scale/
position/layout changes. For ScrollBox callbacks, refresh only visible handles
after placement, not the entire context. The library installs no per-separator
hooks or `OnUpdate`.

## Renderer Ownership

Renderers are peers: a skin must not call or alias another skin's renderer
methods, or rely on that skin having painted a control first. Shared component
setup owns configured fonts, opacity, and native checkmark artwork; neutral
text/texture operations also live with their components. Each renderer owns
its own artwork, tints, surfaces, and optical offsets. Button state refreshes
remain separate from font/atlas setup. This keeps changes to Modern from
silently changing Flat and gives future renderers the same independent boundary.

## Verification And Examples

Run from this repository root with Lua 5.1:

```powershell
lua tests/run.lua
```

The suite loads runtime files in `embed.xml` order and includes its own
public-domain LibStub fixture. It does not depend on a sibling addon checkout.
It covers independent consumers/scales, both axes, fractional/negative origins,
1080p/1440p/4K physical conversion, connected strokes, physical insets,
clipping, borders, pooled state, window constructors/slots/lifecycle, icon-free
accordion layout, button/tab/checkbox/search states, semantic icon colors,
scrollbar and popup boundaries, raw control access, display coalescing,
allocation-free refreshes, Modern/Flat round trips, symmetric compact geometry,
native title/Close placement with padded and nested windows, chrome layering,
portrait background insets and explicit/manual placement,
background dragging with separate action controls, text baselines, action
colors, outside icon borders, native checkmark sizes and stepper offsets,
combat/drag deferral and cancellation, and old-first/new-first/equal-MINOR loading.
Renderer-isolation checks construct and exercise controls in each skin while
every inactive renderer method throws, and reject cross-skin function aliases.
Simulated MINORs are applied in memory; source version numbers are not edited.

`examples/PixelHarness.lua` is a development-only in-game visual fixture with
two independent consumers exercising windows, controls, icons, scrollbars,
glows, and the optional scale popup. It is not loaded by the runtime embed or packaged.
Mocks cannot establish in-game visual quality or secure-frame safety.

# LibYvSkins

Creation-first windows and appearance primitives for World of Warcraft addons,
by Yvairel.
MIT licensed. LibStub API family: `LibYvSkins-1.0`, implementation MINOR `1`.
No release has been tagged yet.

This development snapshot implements Modern windows, controls, icon surfaces,
list accents, and pixel primitives. YvBags is the first native consumer: it
builds on library-created frames, not existing-window adapters. Modern/Flat
selection and the optional EllesmereUI provider remain subsequent phases.
There is no skin preference, SavedVariables, inventory logic, or third-party
styling in this snapshot. The expanded Modern integration awaits in-game review.

## Embedding

Load LibStub before `embed.xml`. Runtime files are Lua 5.1 and use Blizzard's
`PixelUtil` and normal texture/frame APIs. The inspected client source is
Retail 12.1.0.69497; in-game validation is required before release, including
any additional client versions advertised by a consumer.

The Git repository is unversioned (`LibYvSkins`); the embed directory follows
the API family (`LibYvSkins-1.0`). The first intended release tag is `1.0.0`.
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
The original outer background remains intact.

The constructor owns these public frame parts and their outer anchors:

- `window.header`: toolbar area; populate it with the addon's controls.
- `window.content`: content viewport; mount a list or other addon content here.
- `window.footer`: footer area; its interior remains consumer-owned.
- `window.resizeButton`: native `PanelResizeButtonTemplate`, initialized once.
- `window.Inset`, `TitleContainer`, and `CloseButton`: original native parts.

The title supports native movement; optional `onMoveStopped(frame)` and
`onResizeStopped(frame)` run after movement ends. The library owns no saved
position, scale, or size: consumers restore/persist these and call
`context:RefreshGeometry(window)` after explicit scale/position changes.
Consumers also own client-position-saving policy (`SetDontSavePosition` /
`SetUserPlaced`) and may directly replace `CloseButton`'s `OnClick`, such as
closing a native bank session. No input/value getters are wrapped.

The factory installs show/size geometry hooks once and preserves consumer
scripts. A window retains its geometry root for its lifetime, even without
registered strokes. `context:GetWindowChromeWidth()` returns the horizontal
content overhead for consumer size constraints without duplicating inset
constants. Do not reposition the library's slots from addon refresh handlers.
There is no `RegisterWindow` or arbitrary existing-window skinning API.

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
| `CreateTab` | Regular tertiary selected state with a 3-unit outset. `SetSelected(boolean)` takes precedence over hover and press. |
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

Buttons accept `text`, either `icon` or `iconAtlas`, `iconWidth` / `iconHeight`
(18), `iconAlpha` (1), `disabledIconAlpha` (0.5), `pressIcon` (false), and
`labelOffsetY` (1). `template` may supply native behavior, such as
`DisabledTooltipButtonTemplate`; use behavior-only templates without competing
art. `button.Text` and the handle's `parts.label` refer to its native FontString;
`parts.icon` is present when requested. Checkbox `checkmarkScale` defaults to
1.25. Input `focusGlow` defaults to true. Caller-owned anchors and dimensions
remain independent of input values and visual state.

Text/texture factories accept `layer`; textures/icons also accept `sublevel`.
Text and texture colors are consumer-owned unless `colorToken` is supplied.
For token-colored regions, `alpha` multiplies the color opacity without taking
over the raw region's animation alpha. Semantic text, artwork, desaturation,
and visibility survive context refreshes.

Icons require a context `iconBorder` or an explicit `borderTexture`. Defaults
are 23 units square, `borderOutset = 3`, and cropped item UVs (0.08–0.92).
Use `crop = false` for atlases. `borderLayer` / `borderSublevel` set layering.
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
`Skins/Modern.lua` owns generic art and its rendering. The window factory also
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
reason after encountering such a popup. Future skin selection must reject an
incomplete transition rather than leaving that popup partially styled. An old
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
local header, appearance = context:CreateExpandableHeader(window.content, {
    geometryRoot = window, width = 400, height = 31,
    text = "Consumables (2)", expanded = expanded,
})
header:SetPoint("TOPLEFT", window.content, "TOPLEFT", 0, 0)
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
anchors and visibility handle scrolling without per-row pixel refreshes.
Context token changes recolor labels without changing layout or other addons.

## Separators

```lua
local texture, divider = context:CreateSeparator(window.content, {
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
| `context:CreateWindow(parent, options)` | Create a canonical Modern shell with directly accessible frame parts. |
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

## Pixel Primitives

- `Skins.Pixel.Round(region, uiUnits, minPixels)` delegates layout rounding
  to Blizzard PixelUtil. It is not a physical-thickness conversion.
- `Skins.Pixel.GetPhysicalSize(region, pixels)` returns
  `pixels * PixelUtil.GetPixelToUIUnitFactor() / effectiveScale`.
- `Skins.Pixel.UpdateMetrics(metrics, root)` updates a caller-owned metrics
  table for repeated drawing at that root's effective scale.
- `Skins.Pixel.CreateBorder(parent, bounds, layer, sublevel)` creates four
  solid edge textures and returns a stable border handle. Call
  `border:Layout(metrics, physicalPixels, optionalClip)`,
  `border:SetColor(r, g, b, a)`, and `border:Hide()` as needed. Horizontal edges
  own corners so translucent edges never overlap. Border handles are low-level
  primitives: their consumer is responsible for refreshing layout/metrics.

Drawing rounds absolute screen edges inward to whole pixels, compensating for
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
allocation-free refreshes, and old-first/new-first/equal-MINOR module loading.
Simulated MINORs are applied in memory; source version numbers are not edited.

`examples/PixelHarness.lua` is a development-only in-game visual fixture with
two independent consumers exercising windows, controls, icons, scrollbars,
glows, and the optional scale popup. It is not loaded by the runtime embed or packaged.
Mocks cannot establish in-game visual quality or secure-frame safety.

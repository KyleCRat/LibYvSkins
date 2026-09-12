# LibYvSkins

Creation-first windows and appearance primitives for World of Warcraft addons,
by Yvairel.
MIT licensed. LibStub API family: `LibYvSkins-1.0`, implementation MINOR `1`.
No release has been tagged yet.

This development snapshot implements the canonical Modern window constructor,
pixel foundation, and separator factory. YvBags is the first native consumer:
it builds on library-created frames, not existing-window adapters. The remaining
control factories, Modern/Flat selection, and optional EllesmereUI provider are
subsequent phases. There is no skin preference, SavedVariables, inventory logic,
or third-party styling in this snapshot.

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
| `context:RegisterComponent(role, target, parts, options)` | Low-level constructor backend and explicit external visual extension point, not the primary consumer path. Repeating identical ownership returns its handle without reapplying options. Only `separator` is implemented so far. |
| `context:UnregisterComponent(target)` | Hide the owned visual and remove tracking; repeated unregister is harmless. Does not destroy WoW textures or restore external styling. |
| `context:GetColor(token)` | Return `r, g, b, a` without exposing the stored color table. |
| `context:SetTokens(colors)` | Merge copied named colors and refresh registered visuals, without changing geometry. |
| `context:RefreshGeometry(root)` | After parent layout, refresh that root's cached scale and registered custom geometry. Omit the root to refresh the context. Hidden visuals remain hidden. |
| `handle:RefreshGeometry()` | Realign only this stroke using cached root metrics, suitable for visible-row scroll/layout callbacks. |
| `handle:RefreshAppearance()` | Reapply its color token and opacity. |
| `handle:SetAlpha(alpha)` | Set stroke opacity, including hover/pressed feedback, without changing its color meaning. |
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
clipping, borders, pooled state, window constructors/slots/lifecycle, raw control
access, display coalescing, and old-first/new-first/equal-MINOR module loading.
Simulated MINORs are applied in memory; source version numbers are not edited.

`examples/PixelHarness.lua` is a development-only in-game visual fixture with
two independent consumers. It is not loaded by the runtime embed or packaged.
Mocks cannot establish in-game visual quality or secure-frame safety.

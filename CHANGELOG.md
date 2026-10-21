# Changelog

## Unreleased

### Added
- Added `border:LayoutRelative` for consumers that already align their frames
  to physical pixels. Strokes follow movement and resizing without a second
  screen-edge rounding pass or stale position offsets; existing clipped border
  drawing keeps its inward-snapping behavior.
- Added opt-in `tabStyle = "header"` to `CreateTab`, with adjustable width and
  height, proportional corners, centered labels and pixel-aligned artwork.
  Compact tabs keep their artwork within their bounds; the default height is
  64 UI units. Border and accent colors match Blizzard's side tabs, with bright
  pale-gold highlights and smooth scaling. Flat uses its existing selected-tab
  treatment.
- Added icon `artworkOutset` to enlarge artwork inside its existing Modern/Flat
  border footprint without resizing the parent control or adding regions.
- Added bundled centered Vertex control glyphs and `GetIconTexture(name)` for
  consumers, including search, close, folder, clone, lock/unlock, visible/hidden, advanced on/off
  and dedicated arrow/caret icons.
  Added button `preserveIconColor` for multicolor artwork that must retain its
  native colors.
  Command and action-icon glyphs share Modern's gold tint and Flat's accent
  tint; Modern disabled glyphs remain neutral gray.
- Added shared background dragging and explicit non-action drag-region
  registration without intercepting child actions.
- Added a Flat renderer, one-physical-pixel surfaces and icon borders,
  and shared toolbar layout/minimum measurements.
- Added requested/applied skin state, coalesced live transitions, combat and
  move/resize/popup-drag deferral, and consumer lifecycle/status callbacks.
- Added Modern button, tab, checkbox, search/edit-box, scrollbar, text, texture,
  icon, and glow constructors with raw controls and reusable visual-state handles.
  Context appearance refreshes preserve values, focus, semantic item colors,
  and pooled visibility without rebuilding controls or installing new hooks.
- Centralized Modern rendering, including constructor-owned native close/resize
  art. Button hover/press updates reuse state without font/atlas lookups.
- Added an optional LibPopupSlider adapter using its public visual-parts,
  interaction, and font APIs. Preserve value/drag ownership, defer font fitting
  during drags, and report legacy embeds that lack presentation support.
- Added a Modern expandable-header constructor matching LMS's full-width
  tertiary bar and right-side state arrow, without a leading icon slot or
  divider. Raw text/click/enabled APIs remain accessible; appearance handles
  own expansion visuals, context recoloring, and pooled hover/pressed cleanup.
- Added a window constructor with raw Header/Body/Footer and optional Title Bar
  parts, native close/resize controls, move/resize callbacks, and window-owned
  pixel refreshes. Releasing a resize outside the grip still completes it once.
  Consumers build directly on the library's frame structure.
- Added isolated per-addon appearance contexts, stable separator handles,
  context-owned color tokens, and explicit geometry/appearance refresh paths.
  A direct separator factory creates and registers each visual in one call.
- Added scale-aware layout rounding, physical-pixel stroke conversion,
  absolute screen-aligned solid separators, clipped four-edge borders without
  overlapping corners, optional physical-pixel insets for gapless separator
  joins, and shared display/scale invalidation.
- Added Lua 5.1 constructor/lifecycle, contract, pixel-geometry, pooling,
  context-isolation, and mixed/equal-MINOR load-order tests.

### Changed
- Separated window structure from skins. Consumers declare optional section
  heights, spacing, Title Bar/portrait visibility, and Close placement; Body
  fills the remainder. Added copied per-skin layouts, explicit layout updates,
  generic minimum-width callbacks, and calculated viewport prewarm reserves.
- Replaced the search-specific header helper with independent toolbars usable
  in any section, with fixed controls and an optional flexible-width control.
  Converted the development example to retain a Title Bar and two-row Footer
  in both skins; added optional-section and non-search toolbar coverage.
- Replaced the unreleased `compactHeader`, header-helper, and content-naming
  contracts together with the sole consumer. No release/MINOR bump or saved-data
  migration is required; renderer artwork and optical corrections are retained.
- Decoupled Modern and Flat rendering. Shared component setup owns fonts,
  opacity, native checkmark artwork, and plain-region styling; each skin
  paints its own appearance without invoking or aliasing another renderer.
  Preserved existing visuals, input state, and lightweight button-state updates.
- Added renderer-isolation coverage for cold construction and refresh with
  every inactive-skin renderer method disabled.

### Fixed
- Keep Modern window titles and Close buttons aligned with native border
  artwork regardless of content padding. Restore native title layering after
  reparenting and adjust the outer background when the portrait is hidden.
  Explicit title margins and manual Close placement remain supported.
- Removed the Flat glyph-position cache so existing layout/state refreshes
  always reapply anchors and size. Retained pixel alignment and separate
  sampling setup without adding polling. Kept alignment and skin-restoration
  coverage while removing mock-only glyph-recovery assertions.
- Kept selected button labels at their resting baseline. Modern retains its
  press offset only while actively pressed and unselected; Flat labels stay
  stationary. Raised Flat button labels and search text/placeholders by one
  UI pixel and lowered the search clear button by one UI pixel, leaving
  Modern, other edit boxes, and other icons unchanged. Native release offsets
  no longer compete with renderer anchors.
- Raised Modern tertiary-square button glyphs by one physical pixel to balance
  the atlas's bottom-heavy border, without changing Flat or press feedback.
- Reduced compact footers to 24 units with a 4-unit content gap and matching
  8-unit outer padding, updated viewport reserves, and preserved Modern footer
  dimensions.
- Left-aligned compact toolbar controls without a reserved drag slot and matched
  their gaps to the content-section spacing, preserving Modern toolbar spacing.
- Kept Flat scrollbar arrows accent-colored when wheel scrolling enables them;
  native enable callbacks no longer undo renderer-owned desaturation. Centered
  directional carets replace the rotated atlas and top-arrow compensation,
  while retaining native press behavior.
- Allowed separate Modern separator bounds/insets so textured frame spacing
  remains intact without changing Flat's pixel-aligned joins.
- Normalized compact outer padding and section gaps, outlined the content inset,
  reserved footer clearance beside the flush corner grip, and updated width
  constraints and viewport reserves while restoring Modern geometry.
- Corrected Flat text alignment, preserved native checkmark sizing, and used
  accent colors consistently for generic action glyphs without recoloring item art.
  Button and close glyphs now share their borders' pixel-snapped bounds and
  parity-aware dimensions for equal margins, restoring nominal dimensions and
  texture sampling in Modern. Only the native checkmark retains its separate
  one-physical-pixel downward adjustment. Flat accordion and search-clear
  glyphs also use the bundled artwork.
- Reduced Flat icon borders to one physical pixel outside the artwork,
  preserved container-icon footprints, centered Flat scrollbars in optional
  caller-defined gutters, tightened arrow-to-track gaps, and removed the
  resize-grip box.
- Added regression coverage for Modern restoration, background/action dragging,
  native stepper press offsets, owned media load order, corner/footer clearance,
  and glyph/border placement across scales and clips.

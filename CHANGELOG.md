# Changelog

## Unreleased

### Added
- Added icon `artworkOutset` to enlarge artwork inside its existing Modern/Flat
  border footprint without resizing the parent control or adding regions.
- Added bundled centered Vertex control glyphs and `GetIconTexture(name)` for
  consumers, including dedicated arrow/caret directions. Added button
  `preserveIconColor` for multicolor artwork that must retain its native colors.
  Command and action-icon glyphs share Modern's gold tint and Flat's accent
  tint; Modern disabled glyphs remain neutral gray.
- Added shared background dragging and explicit non-action drag-region
  registration without intercepting child actions.
- Added a Flat renderer, one-physical-pixel surfaces and icon borders,
  opt-in compact window chrome, and shared toolbar layout/minimum measurements.
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
- Added a canonical Modern window constructor with raw header/content/footer
  parts, native close/resize controls, move/resize callbacks, and window-owned
  pixel refreshes. Consumers build directly on the library's frame structure.
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
- Decoupled Modern and Flat rendering. Shared component setup owns fonts,
  opacity, native checkmark artwork, and plain-region styling; each skin
  paints its own appearance without invoking or aliasing another renderer.
  Preserved existing visuals, input state, and lightweight button-state updates.
- Added renderer-isolation coverage for cold construction and refresh with
  every inactive-skin renderer method disabled.

### Fixed
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

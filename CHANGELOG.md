# Changelog

## Unreleased

### Added
- Added a Flat renderer, one-physical-pixel surfaces and two-pixel icon borders,
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

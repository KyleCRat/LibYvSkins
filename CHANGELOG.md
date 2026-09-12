# Changelog

## Unreleased

### Added
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

# Assist Brand Assets

`assist-icon.png` is the canonical Assist logo artwork supplied by the product owner.
`../Assist.icns`, the web icon, and the favicon are size-specific derivatives of
this artwork.

`assist-menu-bar.png` is a transparent monochrome derivative of the central brand
mark. macOS renders it as a template image so it automatically follows the menu
bar foreground color in light and dark appearances. Regenerate it from the
canonical icon with:

```sh
swift apps/macos/scripts/generate_menu_bar_icon.swift \
  apps/macos/Sources/Assist/Resources/Brand/assist-icon.png \
  apps/macos/Sources/Assist/Resources/Brand/assist-menu-bar.png
```

This folder contains only Assist's own brand artwork. Product UI icons use the
bundled Hugeicons assets documented in `../Icons/README.md`.

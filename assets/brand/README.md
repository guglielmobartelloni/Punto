# Punto — visual identity

Original vector artwork: a white controller and coral cursor on a graphite background. No lettering, so the icon remains readable in the Dock.

- `Punto.png`: 1024 × 1024 preview with transparency.
- `Punto.svg`: editable vector source.
- `scripts/generate-brand-icon.swift`: native macOS resolution generator.

The build generates `build/AppIcon.icns` and includes it in **Punto.app**. Generated iconsets and ICNS files are not tracked in Git.

Regenerate the preview from the project root:

```sh
swift scripts/generate-brand-icon.swift assets/brand/Punto.iconset
iconutil -c icns assets/brand/Punto.iconset -o assets/brand/Punto.icns
cp assets/brand/Punto.iconset/icon_512x512@2x.png assets/brand/Punto.png
```

The application bundle and executable are named Punto. The original bundle ID and signing certificate are retained for preference and signing compatibility. No trademark or domain availability search has been performed for the name.

# Punto — identità visiva

Icona vettoriale originale: controller bianco e cursore corallo su fondo grafite. Senza testo, per restare leggibile nel Dock.

- `Punto.png`: preview 1024 × 1024, con trasparenza.
- `Punto.svg`: sorgente vettoriale modificabile.
- `scripts/generate-brand-icon.swift`: generatore delle risoluzioni native macOS.

La build genera `build/AppIcon.icns` e la include nel bundle. Iconset e ICNS generati non sono tracciati in Git.

Rigenerazione della preview dalla radice del progetto:

```sh
swift scripts/generate-brand-icon.swift assets/brand/Punto.iconset
iconutil -c icns assets/brand/Punto.iconset -o assets/brand/Punto.icns
cp assets/brand/Punto.iconset/icon_512x512@2x.png assets/brand/Punto.png
```

Il nome visualizzato è Punto. Bundle ID, percorso e certificato di firma rimangono quelli originali di PadMac per preservare preferenze e permessi. Non è stata effettuata una verifica di disponibilità commerciale, marchio o dominio per il nome.

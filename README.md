# Parts Stock

Cross-platform Flutter desktop app that converts raw supplier price lists into
ready-to-upload CSV files (`Brand, SKU, Price, Quantity, Description`),
applying configurable price margins, size-based chunking, and a JSON config
that can be edited from the UI or dropped next to a source CSV.

> Primary target is **Windows 10/11 (x64)**. macOS and Linux are also supported
> for development. The chrome follows the WiseWater Connect aesthetic — deep
> blue accents, Cupertino widgets on every platform; Material survives only as
> a glyph icon set.

## Features

- **Streaming CSV → CSV converter** that handles large files (tens of MB) without
  loading them into memory.
- **Batch mode** — drop in many files at once, each is processed in isolation
  and written into `output/` next to the executable.
- **Flexible output schema** — every output column is either pulled from the
  source CSV by header name or hard-coded.
- **Pricing rules** — ordered list of `[min; max) → multiplier` rules. The
  first rule that matches wins.
- **Deduplication** by an arbitrary column (e.g. `sku`).
- **Chunk size** in MB — when a part hits the limit the converter rolls over
  to a new file (`*_part2.csv`, `*_part3.csv`, …).
- **Sidecar `config.txt`** — when a CSV is added the app looks for a
  `config.txt` in the same folder and offers to apply it. Same JSON shape as
  the in-app config.
- **Import / export config** from the settings page; one-tap reset to defaults.
- **Light / dark theme** that follows the system brightness, overridable in
  settings.

## Quick start (Windows)

Prerequisites on the developer machine:

- Visual Studio 2022 with the **Desktop development with C++** workload
- Flutter SDK 3.41+ (`flutter doctor` should report Windows as OK)
- Once: `flutter config --enable-windows-desktop`

```powershell
git pull
flutter pub get
flutter run -d windows                    # debug build
flutter build windows --release           # release build
```

The release bundle lands in:

```
build\windows\x64\runner\Release\
```

Copy the **whole** folder to a target machine — `parts_stock.exe` runs without
installation. On first launch an `output\` folder is created next to the
executable; converted price lists are written there.

> Montserrat and RobotoFlex are bundled as `assets/fonts/*.ttf`, so the app
> renders correctly without an internet connection.

## Other platforms

```bash
flutter run -d macos     # development on macOS
flutter run -d linux     # development on Linux
```

On macOS the default output folder is `Parts Stock.app/Contents/MacOS/output`,
which lives inside the sandboxed bundle. On a daily-driver Mac it is more
convenient to open *Settings → Output folder* once and point at, say,
`~/Documents/parts-stock/output/`.

## Architecture

```
lib/
├─ main.dart
└─ src/
   ├─ app/                       ← shell, theme, AppState
   │  ├─ app.dart
   │  ├─ app_state.dart
   │  └─ theme/
   │      ├─ app_text_styles.dart  (AppStyleScope + Montserrat / RobotoFlex)
   │      ├─ app_theme.dart        (CupertinoThemeData + AppTokens)
   │      └─ app_theme_preset.dart (color palette)
   ├─ core/
   │  ├─ models/                 ← ConverterConfig, ColumnMapping, MarginRule…
   │  └─ services/               ← ConfigStorage, CsvConverter
   ├─ features/                  ← one folder per page
   │  ├─ convert/
   │  ├─ mappings/
   │  ├─ margins/
   │  └─ settings/
   └─ shared/widgets/            ← AppButton, AppTextField, AppToast, BrandMark …
```

## Where the config lives

The active config is stored in the OS *Application Support* directory:

| Platform | Path |
| --- | --- |
| Windows | `%APPDATA%\com.partsstock\Parts Stock\config.json` |
| macOS   | `~/Library/Application Support/com.partsstock.app/config.json` |
| Linux   | `~/.local/share/parts_stock/config.json` |

The *Export to file…* button in settings dumps the same payload as a
`config.txt`, ready to be placed next to a CSV — the app will offer to apply
it on the next conversion run.

## Branding & icons

Vector source: `assets/branding/logo.svg`. A single script rebuilds every
derived asset (in-app logo, Windows ICO, the full macOS `AppIcon.appiconset`
and the Linux PNG):

```bash
python3 tool/generate_app_icon.py
```

It writes:

- `assets/branding/app_icon_256.png` (rendered inside the app's `BrandMark`)
- `windows/runner/resources/app_icon.ico` (16 / 24 / 32 / 48 / 64 / 128 / 256 px)
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png`
  (16 / 32 / 64 / 128 / 256 / 512 / 1024)
- `linux/app_icon.png` (256 px)

Requires `rsvg-convert` (`brew install librsvg`) and Pillow (`pip install Pillow`).

## Stack

- Flutter 3.41 / Dart 3.11 (Cupertino-only UI)
- `csv` for streaming CSV read / write
- `file_picker` + `file_selector` for native dialogs
- `path_provider` for config storage paths
- Bundled Montserrat and RobotoFlex font assets

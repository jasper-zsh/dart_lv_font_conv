# dart_lv_font_conv

A Dart port of the `lv_font_conv` tool for converting fonts to LVGL (Light and Versatile Graphics Library) format.

## Features

- Convert TrueType fonts to LVGL font format
- Support for Unicode character ranges
- Font size customization
- BPP (bits per pixel) configuration
- Optimized for embedded systems using LVGL

## Getting started

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  dart_lv_font_conv: ^1.0.0
```

Then run `dart pub get` to install the package.

## Usage

```dart
import 'package:dart_lv_font_conv/dart_lv_font_conv.dart';

void main() async {
  final converter = FontConverter();
  await converter.convert(
    inputFont: 'path/to/font.ttf',
    outputFile: 'output.c',
    size: 16,
    bpp: 4,
  );
}
```

## Additional information

This project is a Dart port of the original `lv_font_conv` C project. It aims to provide the same functionality while being more accessible to Dart developers.

For more information about LVGL, visit: https://lvgl.io/

Contributions are welcome! Please feel free to submit issues and pull requests.

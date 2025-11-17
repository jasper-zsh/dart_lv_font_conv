# Intro

This is a dart project, translated from `lv_font_conv` project, used for convert font for lvgl.

`lib` folder is mapped to `lv_font_conv/lib`.

Skip `freetype` because WASM is not supported in dart.

# Rules
You **MUST** follow these rules:
- Make best effort to keep the folder structure same as origin project.
- Check the logic in original project when you create or edit **ANY** code, make sure they are matched.

# Commands

- Build: `dart pub get`
- Lint: `dart analyze`
- Test: `dart test`
- Run single test: `dart test test/dart_lv_font_conv_test.dart`

# Code Style

- Use `package:lints/recommended.yaml` for linting rules
- Follow Dart naming conventions: camelCase for variables, PascalCase for types
- Use strong typing with explicit type annotations where helpful
- Import order: dart libraries, package imports, local imports
- Use `library` directive in main library file
- Write tests using `package:test` with `group` and `test` functions
- Include doc comments (`///`) for public APIs

# Test
Use `fonts/NotoSansSC-Regular.ttf` for testing.
If this file does not exists, ask user to put there.

You should generate fonts with both lv_font_conv and this project, compare the results to make sure this project works properly.
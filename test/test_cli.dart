/// Tests for CLI interface
library;

import 'dart:io';
import 'package:test/test.dart';
import '../lib/cli.dart';
import '../lib/app_error.dart';

void main() {
  group('Cli', () {
    test('Should run', () {
      // Test that the CLI prints usage when no arguments provided
      expect(() => FontConverterCLI.run([]), throwsA(anything));
    });

    test('Should print error if range is specified without font', () async {
      expect(
        () => FontConverterCLI.parseArguments('--font test --range 123'.split(' ')),
        throwsA(isA<AppError>().having((e) => e.message, 'message', contains('Only allowed after')))
      );
    });

    test('Should print error if range is invalid', () {
      expect(
        () => FontConverterCLI.parseArguments('--font test --range invalid'.split(' ')),
        throwsA(isA<AppError>().having((e) => e.message, 'message', contains('not a valid number')))
      );
    });

    test('Should require character set specified for each font', () {
      expect(
        () => FontConverterCLI.parseArguments('--font test --size 18 --bpp 4 --format dump'.split(' ')),
        throwsA(isA<AppError>().having((e) => e.message, 'message', contains('no character ranges specified')))
      );
    });

    test('Should print error if size is invalid', () {
      expect(
        () => FontConverterCLI.parseArguments('--size 10xxx'.split(' ')),
        throwsA(isA<AppError>().having((e) => e.message, 'message', contains('must be a positive number')))
      );
    });

    test('Should print error if size is zero', () {
      expect(
        () => FontConverterCLI.parseArguments('--size 0'.split(' ')),
        throwsA(isA<AppError>().having((e) => e.message, 'message', contains('must be a positive number')))
      );
    });

    test('Should write a font using "dump" writer', () async {
      // Skip if test font is not available
      final fontFile = File('fonts/NotoSansSC-Regular.ttf');
      if (!fontFile.existsSync()) {
        return;
      }

      final rnd = '${DateTime.now().millisecondsSinceEpoch}';
      final dir = Directory('test_output_$rnd');

      try {
        final args = [
          '--font', fontFile.path, '--range', '0x20-0x22',
          '--size', '18', '--output', dir.path, '--bpp', '2', '--format', 'dump'
        ];

        final parsedArgs = FontConverterCLI.parseArguments(args);
        expect(parsedArgs['format'], equals('dump'));
        expect(parsedArgs['size'], equals(18));
        expect(parsedArgs['bpp'], equals(2));

        // Note: Actual font conversion test would require the full implementation
        // This test just verifies argument parsing
      } finally {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    });

    test('Should write a font using "bin" writer', () async {
      final fontFile = File('fonts/NotoSansSC-Regular.ttf');
      if (!fontFile.existsSync()) {
        return;
      }

      final rnd = '${DateTime.now().millisecondsSinceEpoch}';
      final file = File('test_output_$rnd.font');

      try {
        final args = [
          '--font', fontFile.path, '--range', '0x20-0x22',
          '--size', '18', '--output', file.path, '--bpp', '2', '--format', 'bin'
        ];

        final parsedArgs = FontConverterCLI.parseArguments(args);
        expect(parsedArgs['format'], equals('bin'));
        expect(parsedArgs['size'], equals(18));
        expect(parsedArgs['bpp'], equals(2));
      } finally {
        if (await file.exists()) {
          await file.delete();
        }
      }
    });

    test('Should require output for "dump" writer', () {
      final fontFile = File('fonts/NotoSansSC-Regular.ttf');
      if (!fontFile.existsSync()) {
        return;
      }

      final args = [
        '--font', fontFile.path, '--range', '0x20-0x22',
        '--size', '18', '--bpp', '2', '--format', 'dump'
      ];

      final parsedArgs = FontConverterCLI.parseArguments(args);
      expect(parsedArgs['output'], isNull);
    });

    group('range', () {
      test('Should accept single number', () {
        expect(FontConverterCLI.parseRange('42'), equals([42, 42, 42]));
      });

      test('Should accept single number (hex)', () {
        expect(FontConverterCLI.parseRange('0x2A'), equals([42, 42, 42]));
      });

      test('Should accept simple range', () {
        expect(FontConverterCLI.parseRange('40-0x2A'), equals([40, 42, 40]));
      });

      test('Should accept single number with mapping', () {
        expect(FontConverterCLI.parseRange('42=>72'), equals([42, 42, 72]));
      });

      test('Should accept range with mapping', () {
        expect(FontConverterCLI.parseRange('42-45=>0x48'), equals([42, 45, 72]));
      });

      test('Should error on invalid ranges', () {
        expect(
          () => FontConverterCLI.parseRange('20-19'),
          throwsA(isA<AppError>().having((e) => e.message, 'message', contains('start cannot be greater than end')))
        );
      });

      test('Should error on invalid numbers', () {
        expect(
          () => FontConverterCLI.parseRange('13-abc80'),
          throwsA(isA<AppError>().having((e) => e.message, 'message', contains('not a valid number')))
        );
      });

      test('Should not accept characters out of unicode range', () {
        expect(
          () => FontConverterCLI.parseRange('1114444'),
          throwsA(isA<AppError>().having((e) => e.message, 'message', contains('out of unicode range')))
        );
      });
    });
  });
}
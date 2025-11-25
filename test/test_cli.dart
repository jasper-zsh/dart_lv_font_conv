library;

import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../lib/cli.dart';
import '../lib/convert.dart';

void main() {
  final scriptPath = p.join(
    Directory.current.path,
    'bin',
    'dart_lv_font_conv.dart',
  );
  final font = File('fonts/NotoSansSC-Regular.ttf');

  if (!font.existsSync()) {
    throw StateError('Test font not found: ${font.path}');
  }

  group('Cli', () {
    test('Should run', () {
      final result = Process.runSync('dart', ['run', scriptPath]);
      final out = '${result.stdout}${result.stderr}'.toLowerCase();
      expect(out.startsWith('usage'), isTrue);
    });

    test('Should print error if range is specified without font', () async {
      expect(
        () => FontConverterCLI.parseArguments(
          '--range 123 --font test'.split(' '),
        ),
        throwsA(predicate((e) => '$e'.contains('Only allowed after'))),
      );
    });

    test('Should print error if range is invalid', () {
      expect(
        () => FontConverterCLI.parseArguments(
          '--font test --range invalid'.split(' '),
        ),
        throwsA(
          predicate(
            (e) =>
                '$e'.contains('invalid range value') ||
                '$e'.contains('not a number'),
          ),
        ),
      );
    });

    test('Should require character set specified for each font', () {
      expect(
        () => FontConverterCLI.parseArguments(
          '--font test --size 18 --bpp 4 --format dump'.split(' '),
        ),
        throwsA(
          predicate(
            (e) =>
                '$e'.contains('You need to specify either') ||
                '$e'.contains('no character ranges'),
          ),
        ),
      );
    });

    test('Should print error if size is invalid', () {
      expect(
        () => FontConverterCLI.parseArguments('--size 10xxx'.split(' ')),
        throwsA(
          predicate(
            (e) =>
                '$e'.contains('invalid positive_int value') ||
                '$e'.contains('must be a positive number'),
          ),
        ),
      );
    });

    test('Should print error if size is zero', () {
      expect(
        () => FontConverterCLI.parseArguments('--size 0'.split(' ')),
        throwsA(
          predicate(
            (e) =>
                '$e'.contains('invalid positive_int value') ||
                '$e'.contains('must be a positive number'),
          ),
        ),
      );
    });

    test('Should write a font using "dump" writer', () async {
      final rnd = Random().nextInt(0xFFFFFF).toRadixString(16);
      final dir = Directory(p.join(Directory.current.path, rnd));

      try {
        final args = [
          '--font',
          font.path,
          '--range',
          '0x20-0x22',
          '--size',
          '18',
          '-o',
          dir.path,
          '--bpp',
          '2',
          '--format',
          'dump',
        ];

        final parsedArgs = FontConverterCLI.parseArguments(args);
        final files = await convert(parsedArgs);

        for (final entry in files.entries) {
          final filePath = p.join(dir.path, entry.key);
          final outFile = File(filePath);
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(entry.value);
        }

        List<String> written = <String>[];
        if (dir.existsSync()) {
          written = dir.listSync().map((e) => p.basename(e.path)).toList();
          written.sort();
        }

        expect(
          written,
          equals(['20.png', '21.png', '22.png', 'font_info.json']),
        );
      } finally {
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      }
    });

    test('Should write a font using "bin" writer', () async {
      final rnd = '${Random().nextInt(0xFFFFFF)}.font';
      final file = File(p.join(Directory.current.path, rnd));

      try {
        final args = [
          '--font',
          font.path,
          '--range',
          '0x20-0x22',
          '--size',
          '18',
          '-o',
          file.path,
          '--bpp',
          '2',
          '--format',
          'bin',
        ];

        final parsedArgs = FontConverterCLI.parseArguments(args);
        final files = await convert(parsedArgs);

        for (final entry in files.entries) {
          final outFile = File(entry.key);
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(entry.value);
        }

        final targetPath = files.keys.single;
        final targetFile = File(targetPath);
        final contents = targetFile.readAsBytesSync();
        final head = String.fromCharCodes(contents.sublist(4, 8));
        expect(head, equals('head'));
      } finally {
        for (final path in [file.path, '${file.path}.bin']) {
          final f = File(path);
          if (f.existsSync()) {
            f.deleteSync();
          }
        }
      }
    });

    test('Should require output for "dump" writer', () {
      expect(
        () => FontConverterCLI.parseArguments([
          '--font',
          font.path,
          '--range',
          '0x20-0x22',
          '--size',
          '18',
          '--bpp',
          '2',
          '--format',
          'dump',
        ]),
        throwsA(predicate((e) => '$e'.contains('Output is required for'))),
      );
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
        expect(
          FontConverterCLI.parseRange('42-45=>0x48'),
          equals([42, 45, 72]),
        );
      });

      test('Should error on invalid ranges', () {
        expect(
          () => FontConverterCLI.parseRange('20-19'),
          throwsA(predicate((e) => '$e'.contains('Invalid range'))),
        );
      });

      test('Should error on invalid numbers', () {
        expect(
          () => FontConverterCLI.parseRange('13-abc80'),
          throwsA(
            predicate(
              (e) =>
                  '$e'.contains('not a number') ||
                  '$e'.contains('not a valid number'),
            ),
          ),
        );
      });

      test('Should not accept characters out of unicode range', () {
        expect(
          () => FontConverterCLI.parseRange('1114444'),
          throwsA(predicate((e) => '$e'.contains('out of unicode'))),
        );
      });
    });
  });
}

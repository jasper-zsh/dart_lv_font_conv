#!/usr/bin/env dart

import 'package:dart_lv_font_conv/cli.dart';

void main(List<String> arguments) async {
  final cli = FontConverterCLI();
  await cli.run(arguments);
}
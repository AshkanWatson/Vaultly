import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads real fonts (when available on the machine) so widget tests and
/// screenshots use realistic text metrics instead of the square test font.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFonts();
  await testMain();
}

Future<void> _family(String family, List<String> paths) async {
  final files = paths.map(File.new).where((f) => f.existsSync()).toList();
  if (files.isEmpty) return;
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  const inter = '/usr/share/fonts/opentype/inter';
  final sans = [
    '$inter/Inter-Regular.otf',
    '$inter/Inter-Medium.otf',
    '$inter/Inter-SemiBold.otf',
    '$inter/Inter-Bold.otf',
  ];
  for (final f in [
    'Roboto',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    '.SF UI Text',
    '.SF UI Display',
  ]) {
    await _family(f, sans);
  }
  const mono = ['/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'];
  await _family('monospace', mono);
  await _family('Menlo', mono);

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    await _family('MaterialIcons', [
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
    ]);
  }
  final pubCache = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final hosted = Directory('$pubCache/hosted/pub.dev');
  if (!hosted.existsSync()) return;
  final cupertino = hosted
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.contains('cupertino_icons-'))
      .map((d) => '${d.path}/assets/CupertinoIcons.ttf')
      .toList();
  await _family('packages/cupertino_icons/CupertinoIcons', cupertino);
}

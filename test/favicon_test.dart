import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/data/favicon_service.dart';

final _png = Uint8List.fromList(
    [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 1, 2, 3]);
final _ico = Uint8List.fromList([0, 0, 1, 0, 1, 0, 16, 16, 0, 0, 0, 0, 9]);

Future<HttpServer> _serve(Map<String, (String, List<int>)> routes) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) {
    final r = routes[req.uri.path];
    if (r == null) {
      req.response.statusCode = 404;
    } else {
      req.response.headers.contentType = ContentType.parse(r.$1);
      req.response.add(r.$2);
    }
    req.response.close();
  });
  return server;
}

void main() {
  // flutter_test fakes all HTTP by default; these tests use a local server.
  setUpAll(() => HttpOverrides.global = null);

  test('parses <link rel> icons, preferring apple-touch-icon, skipping SVG', () {
    final base = Uri.parse('https://example.com/login');
    final links = FaviconService.iconLinks('''
      <link rel="stylesheet" href="/a.css">
      <link rel="icon" type="image/svg+xml" href="/icon.svg">
      <link rel="shortcut icon" href='/fav.png'>
      <LINK REL=apple-touch-icon HREF=https://cdn.example.com/touch.png>
    ''', base);
    expect(links.map((u) => u.toString()), [
      'https://cdn.example.com/touch.png',
      'https://example.com/fav.png',
    ]);
  });

  test('recognises only real bitmap formats', () {
    expect(FaviconService.isSupportedImage(_png), isTrue);
    expect(FaviconService.isSupportedImage(_ico), isTrue);
    expect(
        FaviconService.isSupportedImage(
            Uint8List.fromList('<html><body>nope</body>'.codeUnits)),
        isFalse);
  });

  test('downloads the icon declared in the page', () async {
    final server = await _serve({
      '/': ('text/html', '<link rel="icon" href="/static/i.png">'.codeUnits),
      '/static/i.png': ('image/png', _png),
    });
    final bytes = await FaviconService()
        .fetch(Uri.parse('http://127.0.0.1:${server.port}/'));
    expect(bytes, _png);
    await server.close(force: true);
  });

  test('falls back to /favicon.ico and ignores non-images', () async {
    final server = await _serve({
      '/': ('text/html', '<link rel="icon" href="/fake.png">'.codeUnits),
      '/fake.png': ('text/html', '<html>not an image</html>'.codeUnits),
      '/favicon.ico': ('image/x-icon', _ico),
    });
    final bytes = await FaviconService()
        .fetch(Uri.parse('http://127.0.0.1:${server.port}/'));
    expect(bytes, _ico);
    await server.close(force: true);
  });

  test('returns null when nothing is available or the host is unreachable',
      () async {
    final server = await _serve({});
    expect(
        await FaviconService()
            .fetch(Uri.parse('http://127.0.0.1:${server.port}/')),
        isNull);
    await server.close(force: true);
    expect(
        await FaviconService(timeout: const Duration(seconds: 1))
            .fetchForUrl('not a url ://'),
        isNull);
  });

  test('rejects oversized icons', () async {
    final big = Uint8List(FaviconService.maxIconBytes + 10)
      ..setAll(0, _png);
    final server = await _serve({'/favicon.ico': ('image/png', big)});
    expect(
        await FaviconService()
            .fetch(Uri.parse('http://127.0.0.1:${server.port}/')),
        isNull);
    await server.close(force: true);
  });
}

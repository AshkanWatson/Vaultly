import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Downloads a website's icon directly from the website itself (never via a
/// third-party favicon service, so nobody else learns which sites you use).
///
/// Called once when an item is saved; the bytes are stored encrypted in the
/// vault, so browsing the vault never touches the network.
class FaviconService {
  FaviconService({this.timeout = const Duration(seconds: 6)});

  final Duration timeout;

  static const int maxHtmlBytes = 512 * 1024;
  static const int maxIconBytes = 200 * 1024;

  /// Returns icon bytes for the site at [siteUrl] (e.g. `github.com` or
  /// `https://github.com/login`), or null if none could be found.
  Future<Uint8List?> fetchForUrl(String siteUrl) async {
    var u = siteUrl.trim();
    if (u.isEmpty) return null;
    if (!u.contains('://')) u = 'https://$u';
    final parsed = Uri.tryParse(u);
    if (parsed == null || parsed.host.isEmpty) return null;
    if (parsed.scheme != 'https' && parsed.scheme != 'http') return null;
    return fetch(Uri(scheme: parsed.scheme, host: parsed.host, port: parsed.hasPort ? parsed.port : null, path: '/'));
  }

  Future<Uint8List?> fetch(Uri origin) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = 'Mozilla/5.0 (Vaultly icon fetcher)';
    try {
      final candidates = <Uri>[];
      final html = await _get(client, origin, maxHtmlBytes);
      if (html != null) {
        candidates.addAll(iconLinks(
            utf8.decode(html.bytes, allowMalformed: true), html.finalUri));
      }
      candidates.add(origin.resolve('/apple-touch-icon.png'));
      candidates.add(origin.resolve('/favicon.ico'));

      for (final c in candidates) {
        if (c.scheme != 'https' && c.scheme != 'http') continue;
        final r = await _get(client, c, maxIconBytes);
        if (r != null && isSupportedImage(r.bytes)) return r.bytes;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<({Uint8List bytes, Uri finalUri})?> _get(
      HttpClient client, Uri uri, int limit) async {
    try {
      final req = await client.getUrl(uri).timeout(timeout);
      req.followRedirects = true;
      req.maxRedirects = 4;
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) {
        await res.drain<void>();
        return null;
      }
      final b = BytesBuilder(copy: false);
      await for (final chunk in res.timeout(timeout)) {
        b.add(chunk);
        if (b.length > limit) return null;
      }
      final finalUri =
          res.redirects.isEmpty ? uri : uri.resolveUri(res.redirects.last.location);
      return (bytes: b.toBytes(), finalUri: finalUri);
    } catch (_) {
      return null;
    }
  }

  /// Extracts icon URLs from `<link rel=...>` tags, best first
  /// (apple-touch-icon is usually the largest).
  static List<Uri> iconLinks(String html, Uri base) {
    final found = <(int, Uri)>[];
    for (final m in RegExp(r'<link\b[^>]*>', caseSensitive: false).allMatches(html)) {
      final tag = m.group(0)!;
      final rel = _attr(tag, 'rel')?.toLowerCase();
      final href = _attr(tag, 'href');
      if (rel == null || href == null || href.isEmpty) continue;
      if (href.toLowerCase().endsWith('.svg') ||
          (_attr(tag, 'type')?.contains('svg') ?? false)) {
        continue; // Flutter can't decode SVG without extra dependencies.
      }
      final int rank;
      if (rel.contains('apple-touch-icon')) {
        rank = 0;
      } else if (rel.split(RegExp(r'\s+')).contains('icon')) {
        rank = 1;
      } else {
        continue;
      }
      final uri = Uri.tryParse(href);
      if (uri != null) found.add((rank, base.resolveUri(uri)));
    }
    found.sort((a, b) => a.$1 - b.$1);
    return found.map((e) => e.$2).toList();
  }

  static String? _attr(String tag, String name) {
    final m = RegExp('\\b$name\\s*=\\s*("([^"]*)"|\'([^\']*)\'|([^\\s>]+))',
            caseSensitive: false)
        .firstMatch(tag);
    if (m == null) return null;
    return (m.group(2) ?? m.group(3) ?? m.group(4))?.trim();
  }

  /// Only accept real bitmap images (PNG, JPEG, GIF, WebP, ICO, BMP).
  static bool isSupportedImage(Uint8List b) {
    if (b.length < 12) return false;
    bool starts(List<int> sig) {
      for (var i = 0; i < sig.length; i++) {
        if (b[i] != sig[i]) return false;
      }
      return true;
    }

    return starts([0x89, 0x50, 0x4E, 0x47]) || // PNG
        starts([0xFF, 0xD8, 0xFF]) || // JPEG
        starts([0x47, 0x49, 0x46, 0x38]) || // GIF
        (starts([0x52, 0x49, 0x46, 0x46]) &&
            b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) || // WebP
        starts([0x00, 0x00, 0x01, 0x00]) || // ICO
        starts([0x42, 0x4D]); // BMP
  }
}

import '../../data/vault_item.dart';
import '../crypto/encoding.dart';
import '../crypto/secure_random.dart';
import 'csv.dart';

class CsvImportResult {
  const CsvImportResult(this.items, this.source, this.skipped);
  final List<VaultItem> items;
  final String source;
  final int skipped;
}

/// Imports password CSV exports from other managers and browsers.
///
/// Recognised (by header names): Apple Passwords / iCloud Keychain, Chrome /
/// Edge / Brave, Firefox, Safari, LastPass, Bitwarden, 1Password, Dashlane,
/// Proton Pass, and Vaultly's own CSV export.
class CsvImporter {
  CsvImporter._();

  static const _title = ['title', 'name', 'item name'];
  static const _url = [
    'url', 'login_uri', 'website', 'web site', 'origin', 'urls', 'login url',
  ];
  static const _user = [
    'username', 'login_username', 'login', 'user', 'email', 'user name',
    'login name',
  ];
  static const _pass = ['password', 'login_password', 'pass'];
  static const _notes = ['notes', 'note', 'extra', 'comments', 'comment'];
  static const _otp = [
    'otpauth', 'totp', 'login_totp', 'otp', 'otpurl', 'one-time password',
    'otp auth',
  ];
  static const _fav = ['favorite', 'fav', 'favourite'];

  static int _col(List<String> header, List<String> names) {
    for (final n in names) {
      final i = header.indexOf(n);
      if (i >= 0) return i;
    }
    return -1;
  }

  static String _source(List<String> h) {
    if (h.contains('otpauth')) return 'Apple Passwords';
    if (h.contains('login_uri')) return 'Bitwarden';
    if (h.contains('grouping') && h.contains('extra')) return 'LastPass';
    if (h.contains('httprealm')) return 'Firefox';
    if (h.contains('otpurl')) return 'Proton Pass';
    if (h.contains('note') && h.contains('name')) return 'Chrome';
    return 'CSV';
  }

  static CsvImportResult parse(String text, {DateTime? now}) {
    final rows = Csv.parse(text);
    if (rows.isEmpty) throw const FormatException('The CSV file is empty');
    final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
    final ci = (
      title: _col(header, _title),
      url: _col(header, _url),
      user: _col(header, _user),
      pass: _col(header, _pass),
      notes: _col(header, _notes),
      otp: _col(header, _otp),
      fav: _col(header, _fav),
      type: _col(header, ['type']),
    );
    if (ci.pass < 0 && ci.user < 0) {
      throw const FormatException(
          'No "username" or "password" column found in this CSV');
    }
    final ts = now ?? DateTime.now();
    final items = <VaultItem>[];
    var skipped = 0;
    String cell(List<String> r, int i) =>
        i >= 0 && i < r.length ? r[i].trim() : '';

    for (final r in rows.skip(1)) {
      final type = cell(r, ci.type).toLowerCase();
      final password = ci.pass >= 0 && ci.pass < r.length ? r[ci.pass] : '';
      final user = cell(r, ci.user);
      final url = cell(r, ci.url);
      final notes = cell(r, ci.notes);
      var title = cell(r, ci.title);
      final isNote = type == 'note' || type == 'securenote' ||
          (password.isEmpty && user.isEmpty && url == 'http://sn');
      if (password.isEmpty && user.isEmpty && notes.isEmpty) {
        skipped++;
        continue;
      }
      final urls = url.isEmpty || url == 'http://sn'
          ? <String>[]
          : url
              .split(RegExp(r'[,\s]+'))
              .where((u) => u.isNotEmpty)
              .toList();
      if (title.isEmpty && urls.isNotEmpty) title = VaultItem.hostOf(urls[0]);
      final otp = cell(r, ci.otp);
      final fav = cell(r, ci.fav).toLowerCase();
      items.add(VaultItem(
        id: newItemId(),
        kind: isNote ? ItemKind.note : ItemKind.login,
        title: title,
        username: user,
        password: password,
        urls: urls,
        notes: notes,
        otpAuth: otp.isEmpty ? null : otp,
        favorite: fav == '1' || fav == 'true' || fav == 'yes',
        createdAt: ts,
        updatedAt: ts,
      ));
    }
    return CsvImportResult(items, _source(header), skipped);
  }

  /// Exports in the Apple Passwords CSV layout, which every major password
  /// manager can import.
  static String export(Iterable<VaultItem> items) => Csv.encode([
        ['Title', 'URL', 'Username', 'Password', 'Notes', 'OTPAuth'],
        for (final i in items.where((i) => !i.isDeleted))
          [
            i.displayTitle,
            i.urls.join(' '),
            i.username,
            i.password,
            i.notes,
            i.otpAuth ?? '',
          ],
      ]);
}

/// Random 128-bit item id.
String newItemId() => hex(SecureRandomSource.bytes(16));

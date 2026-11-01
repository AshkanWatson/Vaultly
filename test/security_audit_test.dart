import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/core/security/security_audit.dart';
import 'package:vaultly/data/vault_item.dart';

VaultItem _i(String id, String pw, {bool deleted = false}) => VaultItem(
      id: id,
      title: id,
      password: pw,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      deletedAt: deleted ? DateTime(2026) : null,
    );

void main() {
  test('finds weak and reused passwords, ignoring deleted items', () {
    final report = SecurityReport.of([
      _i('a', 'password'),
      _i('b', 'Xk9#mP2\$vL8@qR4!'),
      _i('c', 'Xk9#mP2\$vL8@qR4!'),
      _i('d', 'unique-Strong-Passphrase-42-zebra'),
      _i('e', 'unique-Strong-Passphrase-42-zebra', deleted: true),
    ]);
    expect(report.weak.map((i) => i.item.id), ['a']);
    expect(report.reused.map((i) => i.item.id), ['b', 'c']);
    expect(report.forItem('d'), isNull);
  });
}

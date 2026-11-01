import '../../data/vault_item.dart';
import 'password_strength.dart';

class SecurityIssue {
  const SecurityIssue(this.item, {this.weak = false, this.reusedWith = 0});
  final VaultItem item;
  final bool weak;

  /// Number of *other* items sharing this password.
  final int reusedWith;
  bool get reused => reusedWith > 0;
}

/// Offline security recommendations (Apple Passwords' "Security" view).
/// Breach checks would require network access, so Vaultly deliberately
/// doesn't do them.
class SecurityReport {
  SecurityReport(this.issues);

  final List<SecurityIssue> issues;

  Iterable<SecurityIssue> get weak => issues.where((i) => i.weak);
  Iterable<SecurityIssue> get reused => issues.where((i) => i.reused);
  int get count => issues.length;

  static SecurityReport of(Iterable<VaultItem> items) {
    final logins = items
        .where((i) => !i.isDeleted && i.kind == ItemKind.login && i.hasPassword)
        .toList();
    final byPassword = <String, int>{};
    for (final i in logins) {
      byPassword[i.password] = (byPassword[i.password] ?? 0) + 1;
    }
    final issues = <SecurityIssue>[];
    for (final i in logins) {
      final weak = PasswordStrength.evaluate(i.password).level.isWeak;
      final reusedWith = byPassword[i.password]! - 1;
      if (weak || reusedWith > 0) {
        issues.add(SecurityIssue(i, weak: weak, reusedWith: reusedWith));
      }
    }
    issues.sort((a, b) => a.item.displayTitle
        .toLowerCase()
        .compareTo(b.item.displayTitle.toLowerCase()));
    return SecurityReport(issues);
  }

  SecurityIssue? forItem(String id) {
    for (final i in issues) {
      if (i.item.id == id) return i;
    }
    return null;
  }
}

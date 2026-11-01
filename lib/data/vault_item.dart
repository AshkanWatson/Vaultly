import '../core/passkey/passkey_credential.dart';

enum ItemKind { login, wifi, note }

extension ItemKindLabel on ItemKind {
  String get label => switch (this) {
        ItemKind.login => 'Password',
        ItemKind.wifi => 'Wi-Fi Network',
        ItemKind.note => 'Secure Note',
      };
}

class PasswordHistoryEntry {
  const PasswordHistoryEntry(this.password, this.changedAt);
  final String password;
  final DateTime changedAt;

  Map<String, dynamic> toJson() =>
      {'p': password, 't': changedAt.millisecondsSinceEpoch};

  factory PasswordHistoryEntry.fromJson(Map<String, dynamic> j) =>
      PasswordHistoryEntry(j['p'] as String,
          DateTime.fromMillisecondsSinceEpoch(j['t'] as int));
}

/// A single vault entry. Everything here lives only inside the encrypted
/// vault payload; nothing is ever written to disk in plaintext.
class VaultItem {
  VaultItem({
    required this.id,
    this.kind = ItemKind.login,
    this.title = '',
    this.username = '',
    this.password = '',
    List<String>? urls,
    this.notes = '',
    this.otpAuth,
    this.passkey,
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    List<PasswordHistoryEntry>? passwordHistory,
  })  : urls = urls ?? const [],
        passwordHistory = passwordHistory ?? const [];

  final String id;
  final ItemKind kind;
  final String title;
  final String username;
  final String password;
  final List<String> urls;
  final String notes;

  /// `otpauth://totp/...` URI or a bare base32 secret.
  final String? otpAuth;
  final PasskeyCredential? passkey;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Set when moved to "Recently Deleted". Purged after 30 days.
  final DateTime? deletedAt;
  final List<PasswordHistoryEntry> passwordHistory;

  bool get isDeleted => deletedAt != null;
  bool get hasPasskey => passkey != null;
  bool get hasOtp => otpAuth != null && otpAuth!.trim().isNotEmpty;
  bool get hasPassword => password.isNotEmpty;

  /// Display name, falling back to the first website's host.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (urls.isNotEmpty) return hostOf(urls.first);
    if (passkey != null) return passkey!.rpId;
    return 'Untitled';
  }

  /// Hosts this item can be used on (normalised, without `www.`).
  Iterable<String> get hosts => urls.map(hostOf).where((h) => h.isNotEmpty);

  static String hostOf(String url) {
    var u = url.trim();
    if (u.isEmpty) return '';
    if (!u.contains('://')) u = 'https://$u';
    final host = Uri.tryParse(u)?.host.toLowerCase() ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  VaultItem copyWith({
    ItemKind? kind,
    String? title,
    String? username,
    String? password,
    List<String>? urls,
    String? notes,
    String? otpAuth,
    bool clearOtp = false,
    PasskeyCredential? passkey,
    bool clearPasskey = false,
    bool? favorite,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool restore = false,
    List<PasswordHistoryEntry>? passwordHistory,
  }) =>
      VaultItem(
        id: id,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        username: username ?? this.username,
        password: password ?? this.password,
        urls: urls ?? this.urls,
        notes: notes ?? this.notes,
        otpAuth: clearOtp ? null : (otpAuth ?? this.otpAuth),
        passkey: clearPasskey ? null : (passkey ?? this.passkey),
        favorite: favorite ?? this.favorite,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: restore ? null : (deletedAt ?? this.deletedAt),
        passwordHistory: passwordHistory ?? this.passwordHistory,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'username': username,
        'password': password,
        'urls': urls,
        'notes': notes,
        if (otpAuth != null) 'otp': otpAuth,
        if (passkey != null) 'passkey': passkey!.toJson(),
        'fav': favorite,
        'created': createdAt.millisecondsSinceEpoch,
        'updated': updatedAt.millisecondsSinceEpoch,
        if (deletedAt != null) 'deleted': deletedAt!.millisecondsSinceEpoch,
        if (passwordHistory.isNotEmpty)
          'history': passwordHistory.map((e) => e.toJson()).toList(),
      };

  factory VaultItem.fromJson(Map<String, dynamic> j) => VaultItem(
        id: j['id'] as String,
        kind: ItemKind.values.firstWhere((k) => k.name == j['kind'],
            orElse: () => ItemKind.login),
        title: j['title'] as String? ?? '',
        username: j['username'] as String? ?? '',
        password: j['password'] as String? ?? '',
        urls: (j['urls'] as List?)?.cast<String>() ?? const [],
        notes: j['notes'] as String? ?? '',
        otpAuth: j['otp'] as String?,
        passkey: j['passkey'] == null
            ? null
            : PasskeyCredential.fromJson(
                (j['passkey'] as Map).cast<String, dynamic>()),
        favorite: j['fav'] as bool? ?? false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['created'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(j['updated'] as int),
        deletedAt: j['deleted'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(j['deleted'] as int),
        passwordHistory: (j['history'] as List?)
                ?.map((e) => PasswordHistoryEntry.fromJson(
                    (e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

class GeneratedPassword {
  const GeneratedPassword(this.value, this.createdAt);
  final String value;
  final DateTime createdAt;

  Map<String, dynamic> toJson() =>
      {'v': value, 't': createdAt.millisecondsSinceEpoch};

  factory GeneratedPassword.fromJson(Map<String, dynamic> j) =>
      GeneratedPassword(
          j['v'] as String, DateTime.fromMillisecondsSinceEpoch(j['t'] as int));
}

/// The decrypted vault contents.
class VaultData {
  VaultData({List<VaultItem>? items, List<GeneratedPassword>? generated})
      : items = items ?? [],
        generated = generated ?? [];

  final List<VaultItem> items;

  /// Recently generated passwords (like LastPass' generator history) so a
  /// password created on a sign-up form is never lost.
  final List<GeneratedPassword> generated;

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'generated': generated.map((e) => e.toJson()).toList(),
      };

  factory VaultData.fromJson(Map<String, dynamic> j) => VaultData(
        items: (j['items'] as List? ?? [])
            .map((e) => VaultItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        generated: (j['generated'] as List? ?? [])
            .map((e) =>
                GeneratedPassword.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

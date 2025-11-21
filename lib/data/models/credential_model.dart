class Credential {
  final String id;
  final String title;
  final String username;
  final String password;
  final int updatedAt;
  final bool isDeleted;

  Credential({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.updatedAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'password': password,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Credential.fromMap(Map<String, dynamic> map) {
    return Credential(
      id: map['id'],
      // We assume data coming into the model is already decrypted or raw
      // The Repository handles the encryption/decryption transformation
      title: map['title'],
      username: map['username'],
      password: map['password'],
      updatedAt: map['updated_at'],
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }
}
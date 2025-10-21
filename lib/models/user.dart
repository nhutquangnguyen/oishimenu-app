import '../core/utils/parse_utils.dart';

class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id']?.toString() ?? '',
      email: stringFromDynamic(map['email']),
      fullName: stringFromDynamic(map['full_name']),
      role: stringFromDynamic(map['role']) == '' ? 'staff' : stringFromDynamic(map['role']),
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id.isEmpty ? null : int.tryParse(id),
      'email': email,
      'full_name': fullName,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUser && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AppUser(id: $id, email: $email, fullName: $fullName, role: $role)';
  }
}
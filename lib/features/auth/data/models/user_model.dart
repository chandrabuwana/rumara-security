import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/user.dart';
import 'role_model.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  @JsonKey(name: 'Id')
  final String id;

  @JsonKey(name: 'Role', defaultValue: [])
  final List<RoleModel> role;

  @JsonKey(name: 'Username', defaultValue: '')
  final String username;

  @JsonKey(name: 'FullName', defaultValue: '')
  final String fullName;

  @JsonKey(name: 'Mail', defaultValue: '')
  final String mail;

  const UserModel({
    required this.id,
    required this.role,
    required this.username,
    required this.fullName,
    required this.mail,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  User toEntity() {
    return User(
      id: id,
      email: mail,
      name: fullName,
      phoneNumber: null,
      profileImageUrl: null,
      isEmailVerified: true,
      isBiometricEnabled: false,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
      username: username,
      roles: role.map((r) => r.id).toList(), // Use role ID instead of nama
    );
  }

  /// Get primary role ID (first role in the list)
  String get primaryRoleId => role.isNotEmpty ? role.first.id : 'AGT';

  /// Get primary role name (first role in the list)
  String get primaryRoleName => role.isNotEmpty ? role.first.nama : 'Anggota';
}

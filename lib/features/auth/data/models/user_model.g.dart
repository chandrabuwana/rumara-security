// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => $checkedCreate(
      'UserModel',
      json,
      ($checkedConvert) {
        final val = UserModel(
          id: $checkedConvert('Id', (v) => v as String),
          role: $checkedConvert(
              'Role',
              (v) => (v as List<dynamic>? ?? const [])
                  .map((e) => RoleModel.fromJson(e as Map<String, dynamic>))
                  .toList()),
          username: $checkedConvert('Username', (v) => v as String? ?? ''),
          fullName: $checkedConvert('FullName', (v) => v as String? ?? ''),
          mail: $checkedConvert('Mail', (v) => v as String? ?? ''),
        );
        return val;
      },
      fieldKeyMap: const {
        'id': 'Id',
        'role': 'Role',
        'username': 'Username',
        'fullName': 'FullName',
        'mail': 'Mail'
      },
    );

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
      'Id': instance.id,
      'Role': instance.role.map((e) => e.toJson()).toList(),
      'Username': instance.username,
      'FullName': instance.fullName,
      'Mail': instance.mail,
    };

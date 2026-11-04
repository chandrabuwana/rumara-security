// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_response_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginDataModel _$LoginDataModelFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'LoginDataModel',
      json,
      ($checkedConvert) {
        final val = LoginDataModel(
          user: $checkedConvert(
              'User', (v) => UserModel.fromJson(v as Map<String, dynamic>)),
          expiredAt: $checkedConvert('ExpiredAt', (v) => v as String? ?? ''),
          rawToken: $checkedConvert('RawToken', (v) => v as String? ?? ''),
          refreshToken: $checkedConvert('RefreshToken', (v) => v as String? ?? ''),
        );
        return val;
      },
      fieldKeyMap: const {
        'user': 'User',
        'expiredAt': 'ExpiredAt',
        'rawToken': 'RawToken',
        'refreshToken': 'RefreshToken'
      },
    );

Map<String, dynamic> _$LoginDataModelToJson(LoginDataModel instance) =>
    <String, dynamic>{
      'User': instance.user.toJson(),
      'ExpiredAt': instance.expiredAt,
      'RawToken': instance.rawToken,
      'RefreshToken': instance.refreshToken,
    };

LoginResponseModel _$LoginResponseModelFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'LoginResponseModel',
      json,
      ($checkedConvert) {
        final val = LoginResponseModel(
          data: $checkedConvert(
              'Data',
              (v) => v == null
                  ? null
                  : LoginDataModel.fromJson(v as Map<String, dynamic>)),
          code: $checkedConvert('Code', (v) => (v as num?)?.toInt() ?? 0),
          succeeded: $checkedConvert('Succeeded', (v) => v as bool? ?? false),
          message: $checkedConvert('Message', (v) => v as String? ?? ''),
          description: $checkedConvert('Description', (v) => v as String? ?? ''),
        );
        return val;
      },
      fieldKeyMap: const {
        'data': 'Data',
        'code': 'Code',
        'succeeded': 'Succeeded',
        'message': 'Message',
        'description': 'Description'
      },
    );

Map<String, dynamic> _$LoginResponseModelToJson(LoginResponseModel instance) =>
    <String, dynamic>{
      'Data': instance.data?.toJson(),
      'Code': instance.code,
      'Succeeded': instance.succeeded,
      'Message': instance.message,
      'Description': instance.description,
    };

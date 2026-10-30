// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'role_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoleModel _$RoleModelFromJson(Map<String, dynamic> json) => $checkedCreate(
      'RoleModel',
      json,
      ($checkedConvert) {
        final val = RoleModel(
          id: $checkedConvert('Id', (v) => v as String),
          nama: $checkedConvert('Nama', (v) => v as String? ?? ''),
        );
        return val;
      },
      fieldKeyMap: const {'id': 'Id', 'nama': 'Nama'},
    );

Map<String, dynamic> _$RoleModelToJson(RoleModel instance) => <String, dynamic>{
      'Id': instance.id,
      'Nama': instance.nama,
    };

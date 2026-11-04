import 'package:json_annotation/json_annotation.dart';

part 'role_model.g.dart';

@JsonSerializable()
class RoleModel {
  @JsonKey(name: 'Id')
  final String id;
  
  @JsonKey(name: 'Nama', defaultValue: '')
  final String nama;

  const RoleModel({
    required this.id,
    required this.nama,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) =>
      _$RoleModelFromJson(json);

  Map<String, dynamic> toJson() => _$RoleModelToJson(this);
}

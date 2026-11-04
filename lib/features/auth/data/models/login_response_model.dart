import 'package:json_annotation/json_annotation.dart';
import 'user_model.dart';
import 'auth_token_model.dart';

part 'login_response_model.g.dart';

@JsonSerializable()
class LoginDataModel {
  @JsonKey(name: 'User')
  final UserModel user;
  
  @JsonKey(name: 'ExpiredAt')
  final String expiredAt;
  
  @JsonKey(name: 'RawToken')
  final String rawToken;
  
  @JsonKey(name: 'RefreshToken')
  final String refreshToken;

  const LoginDataModel({
    required this.user,
    required this.expiredAt,
    required this.rawToken,
    required this.refreshToken,
  });

  factory LoginDataModel.fromJson(Map<String, dynamic> json) =>
      _$LoginDataModelFromJson(json);

  Map<String, dynamic> toJson() => _$LoginDataModelToJson(this);

  AuthTokenModel get authToken => AuthTokenModel(
        rawToken: rawToken,
        refreshToken: refreshToken,
        expiredAt: expiredAt,
      );
}

@JsonSerializable()
class LoginResponseModel {
  @JsonKey(name: 'Data')
  final LoginDataModel? data;
  
  @JsonKey(name: 'Code')
  final int code;
  
  @JsonKey(name: 'Succeeded')
  final bool succeeded;
  
  @JsonKey(name: 'Message', defaultValue: '')
  final String message;
  
  @JsonKey(name: 'Description', defaultValue: '')
  final String description;

  const LoginResponseModel({
    this.data,
    required this.code,
    required this.succeeded,
    required this.message,
    required this.description,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$LoginResponseModelToJson(this);
}

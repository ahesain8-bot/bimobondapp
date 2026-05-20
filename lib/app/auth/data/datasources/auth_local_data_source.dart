import 'dart:convert';
import 'package:bimobondapp/app/auth/data/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AuthLocalDataSource {
  Future<void> saveTokens({required String authToken, required String deviceToken});
  Future<String?> getAuthToken();
  Future<String?> getDeviceToken();
  Future<void> saveUser(UserModel user);
  Future<UserModel?> getUser();
  Future<void> clearAuthData();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;
  static const String _userKey = 'CACHED_USER';
  static const String _tokenKey = 'AUTH_TOKEN';
  static const String _deviceTokenKey = 'DEVICE_TOKEN';

  AuthLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<void> saveTokens({required String authToken, required String deviceToken}) async {
    await sharedPreferences.setString(_tokenKey, authToken);
    await sharedPreferences.setString(_deviceTokenKey, deviceToken);
  }

  @override
  Future<String?> getAuthToken() async {
    return sharedPreferences.getString(_tokenKey);
  }

  @override
  Future<String?> getDeviceToken() async {
    return sharedPreferences.getString(_deviceTokenKey);
  }

  @override
  Future<void> saveUser(UserModel user) async {
    final userJson = jsonEncode(user.toJson());
    await sharedPreferences.setString(_userKey, userJson);
  }

  @override
  Future<UserModel?> getUser() async {
    final userJson = sharedPreferences.getString(_userKey);
    if (userJson != null) {
      return UserModel.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  @override
  Future<void> clearAuthData() async {
    await sharedPreferences.remove(_userKey);
    await sharedPreferences.remove(_tokenKey);
    await sharedPreferences.remove(_deviceTokenKey);
  }
}

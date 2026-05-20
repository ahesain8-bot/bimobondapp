import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleCubit extends Cubit<Locale> {
  static const String _localePrefKey = 'locale_pref';
  final SharedPreferences _prefs;

  LocaleCubit(this._prefs) : super(_loadLocale(_prefs));

  static Locale _loadLocale(SharedPreferences prefs) {
    final langCode = prefs.getString(_localePrefKey);
    if (langCode == null) return const Locale('ar'); // Default to Arabic
    return Locale(langCode);
  }

  void changeLanguage(String langCode) {
    _prefs.setString(_localePrefKey, langCode);
    emit(Locale(langCode));
  }
}

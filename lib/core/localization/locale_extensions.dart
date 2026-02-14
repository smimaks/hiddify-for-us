import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hiddify/gen/translations.g.dart';

extension AppLocaleX on AppLocale {
  String get preferredFontFamily => Platform.isWindows ? 'Emoji' : '';

  Locale get flutterLocale => const Locale('ru');

  String get languageCode => 'ru';

  String get localeName => 'Русский';
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:localpkg/logger.dart';

Future<Map> getSettings() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  Map settings = {
    "verbose": prefs.getBool("verbose") ?? false,
  };
  print("settings: ${jsonEncode(settings)}");
  return settings;
}
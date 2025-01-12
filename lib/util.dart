import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:localpkg/logger.dart';

Future<Map> getSettings() async {
  print("getting settings...");
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  List history = [];
  try {
    history = jsonDecode(prefs.getString("history") ?? jsonEncode(history));
  } catch (e) {
    print("history fetch error: $e");
  }

  List pinned = [];
  try {
    pinned = jsonDecode(prefs.getString("pins") ?? jsonEncode(pinned));
  } catch (e) {
    print("pins fetch error: $e");
  }

  Map settings = {
    "verbose": prefs.getBool("verbose") ?? false,
    "history": history,
    "pins": pinned,
    "consoleFontSize": prefs.getDouble("consoleFontSize") ?? 12,
  };

  return settings;
}
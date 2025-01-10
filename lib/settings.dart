import 'package:flutter/material.dart';
import 'package:localpkg/dialogue.dart';
import 'package:localpkg/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trafficlightsimulator/util.dart';
import 'package:trafficlightsimulator/var.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  Map? settings;

  @override
  void initState() {
    init();
    super.initState();
  }

  void init() async {
    print("initializing...");
    refresh();
  }

  void refresh() async {
    settings = await getSettings();
    setState(() {});
    print("refreshing...");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: settings == null ? Center(child: CircularProgressIndicator()) : Column(
        children: [
          AboutSettings(context: context, version: version, beta: beta, about: description, instructionsAction: () {
            showDialogue(context: context, title: "Instructions", text: instructions);
          }),
          SettingTitle(title: "Debug"),
          Setting(
            title: "Verbose Mode",
            desc: "Shows application logs in the console.",
            text: settings!["verbose"] ? "On" : "Off",
            action: () async {
              bool? response = await showConfirmDialogue(context: context, title: "Turn on Verbose Mode?", onOff: true);
              if (response == null) {
                return;
              }
              final SharedPreferences prefs = await SharedPreferences.getInstance();
              prefs.setBool("verbose", response);
              refresh();
            }
          ),
        ],
      ),
    );
  }
}
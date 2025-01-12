import 'package:flutter/material.dart';
import 'package:localpkg/dialogue.dart';
import 'package:localpkg/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ping/util.dart';
import 'package:ping/var.dart';

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
      body: settings == null ? Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        child: Column(
          children: [
            AboutSettings(context: context, version: version, beta: beta, about: description, instructionsAction: () {
              showDialogue(context: context, title: "Instructions", content: Text(instructions));
            }),
            SettingTitle(title: "Data"),
            Setting(
              title: "Clear History",
              desc: "Clears all history. This cannot be undone.",
              action: () async {
                bool? response = await showConfirmDialogue(context: context, title: "Are you sure?", description: "Are you sure you want to clear your history? This cannot be undone.");
                if (response == null) {
                  return;
                }
                final SharedPreferences prefs = await SharedPreferences.getInstance();
                prefs.setString("history", "[]");
                refresh();
                showConstantDialogue(context: context, title: "Reopen required", message: "Please close and reopen the app for your changes to take effect.");
              },
            ),
            Setting(
              title: "Clear Pins",
              desc: "Clears all pins. This cannot be undone.",
              action: () async {
                bool? response = await showConfirmDialogue(context: context, title: "Are you sure?", description: "Are you sure you want to clear your pins? This cannot be undone.");
                if (response == null) {
                  return;
                }
                final SharedPreferences prefs = await SharedPreferences.getInstance();
                prefs.setString("pins", "[]");
                refresh();
                showConstantDialogue(context: context, title: "Reopen required", message: "Please close and reopen the app for your changes to take effect.");
              },
            ),
            Setting(
              title: "Clear All Settings & Data",
              desc: "Clears all settings, data, history, and pins. This cannot be undone.",
              action: () async {
                bool? response = await showConfirmDialogue(context: context, title: "Are you sure?", description: "Are you sure you want to clear all your settings, data, history, and pins? This cannot be undone.");
                if (response == null) {
                  return;
                }
                final SharedPreferences prefs = await SharedPreferences.getInstance();
                prefs.clear();
                refresh();
                showConstantDialogue(context: context, title: "Reopen required", message: "Please close and reopen the app for your changes to take effect.");
              },
            ),
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
      ),
    );
  }
}
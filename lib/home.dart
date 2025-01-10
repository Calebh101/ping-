import 'dart:convert';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:localpkg/dialogue.dart';
import 'package:localpkg/functions.dart';
import 'package:localpkg/logger.dart' as logger;
import 'package:localpkg/widgets.dart';
import 'package:http/http.dart' as http;

class Home extends StatefulWidget {
  final bool home;
  final Map? item;

  const Home({
    super.key,
    required this.home,
    this.item,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
  };

  List<Map> history = [
    {
      "url": "localhost:5000/api/launch/check?service=all",
      "method": "PING",
      "time": 1736539658398,
    },
  ];

  final TextEditingController urlController = TextEditingController();
  final TextEditingController headerController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final urlKey = GlobalKey<FormState>();
  final headerKey = GlobalKey<FormState>();
  final bodyKey = GlobalKey<FormState>();

  bool useUrl = true;
  bool useHeaders = false;
  bool useBody = false;

  Uri? url;
  Map<String, String>? headers;
  Map? body = {};
  Ping? ping;

  bool ready = false;
  bool verbose = false;

  String log = "Loading...";
  String response = "Waiting...";
  String method = "GET";

  List methods = ["GET", "POST", "OPTIONS", "PING"];

  @override
  void initState() {
    print("initializing...");
    headers = defaultHeaders;
    if (widget.item != null) {
      method = widget.item?["method"];
      url = Uri.tryParse(widget.item?["url"]);
      body = widget.item?["body"] ?? body;
      headers = widget.item?["headers"] ?? defaultHeaders;
    }
    urlController.text = "${url ?? ""}";
    headerController.text = jsonEncode(headers);
    bodyController.text = jsonEncode(body);
    if (verbose) {
      print("verbose mode");
      addLog("Running in verbose mode...");
    }
    super.initState();
    start();
  }

  void start() {
    print("starting...");
    ready = true;
    print("application ready");
    addLog("Ready!");
  }

  void print(dynamic input, {String? code, bool? trace, bool add = true}) {
    logger.print("$input", code: code);
    if (verbose && add) {
      addLog("VERBOSE: $input");
    }
  }

  void warn(dynamic input, {String? code, bool? trace}) {
    logger.warn("$input", code: code);
    if (verbose) {
      addLog("WARNING: $input");
    }
  }

  void error(dynamic input, {String? code, bool? trace}) {
    logger.error("$input", code: code);
    if (verbose) {
      addLog("ERROR: $input");
    }
  }

  void refresh() {
    print("refreshing...", add: false);
    switch (method) {
      case 'GET':
        useUrl = true;
        useBody = false;
        useHeaders = true;
        break;
      case 'POST':
        useUrl = true;
        useBody = true;
        useHeaders = true;
        break;
      case 'OPTIONS':
        useUrl = true;
        useBody = false;
        useHeaders = true;
        break;
      case 'PING':
        useUrl = true;
        useBody = false;
        useHeaders = false;
        break;
    }
    setState(() {});
  }

  void addLog(String logS, {bool setState = true, bool spacer = false}) {
    //print("new log: $log", add: false);
    log += "\n${spacer ? "\n" : ""}$logS";
    if (setState) {
      refresh();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        double scroll = scrollController.position.maxScrollExtent;
        print('setting scroll position from ${scrollController.position.pixels} to $scroll', add: false);
        scrollController.jumpTo(scroll);
      } else {
        print("scrollController not initialized");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print("building scaffold...");
    return Scaffold(
      appBar: AppBar(
        title: DropdownButton(
          value: method,
          hint: Text('Method'),
          onChanged: (dynamic newMethod) {
            method = newMethod;
            refresh();
          },
          items: methods.map<DropdownMenuItem>((dynamic value) {
            return DropdownMenuItem(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
        centerTitle: true,
        leading: widget.home == true ? IconButton(
          icon: Icon(Icons.settings),
          onPressed: () {},
        ) : IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          if (widget.home)
          PopupMenuButton(
            icon: Icon(Icons.history),
            onSelected: (Map value) {
              navigate(context: context, page: Home(home: false, item: value));
            },
            itemBuilder: (BuildContext context) {
              return history.map((item) {
                return PopupMenuItem(
                  value: item,
                  child: Text("${formatTime(input: item["time"])}: ${item["method"]} ${item['url']}"),
                );
              }).toList();
            },
          ),
          if (widget.home)
          IconButton(
            icon: Icon(Icons.push_pin),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Section(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (useUrl)
                    InputBox(type: Uri, item: "URL", phrase: "Enter a valid URL", function: (Uri value) {
                      url = value;
                    }, key: urlKey, controller: urlController),
                    if (useHeaders)
                    InputBox(type: Map<String, String>, item: "Headers", phrase: "Enter valid JSON headers", function: (Map<String, String> value) {
                      headers = value;
                    }, key: headerKey, controller: headerController, multiline: true),
                    if (useBody)
                    InputBox(type: Map, item: "Body", phrase: "Enter a valid JSON body", function: (Map value) {
                      body = value;
                    }, key: bodyKey, controller: bodyController, multiline: true),
                  ],
                ),
              ),
            ),
            Section(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: SelectableText(
                              log,
                              textAlign: TextAlign.left,
                              style: GoogleFonts.robotoMono(
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Tooltip(
                        message: "Start the request",
                        child: IconButton(
                          icon: Icon(Icons.play_arrow_rounded),
                          onPressed: () {
                            print("starting request...");
                            print("running pre-flight checks...");
                            bool pass = true;
                            Uri? urlS = Uri.tryParse(addHttpPrefix(urlController.text));
                            if (useUrl) {
                              if (urlS == null) {
                                print("null check failed on url");
                                pass = false;
                                addLog("Please enter a valid url.");
                              }
                            }
                            if (useBody) {
                              if (!validator(value: bodyController.text, type: Map)) {
                                print("validator failed on body");
                                pass = false;
                                addLog("Please enter a valid JSON body.");
                              }
                            }
                            if (useHeaders) {
                              if (!validator(value: headerController.text, type: Map<String, String>)) {
                                print("validator failed on headers");
                                pass = false;
                                addLog("Please enter valid JSON headers.");
                              }
                            }
                            if (pass == false) {
                              return;
                            }
                            
                            print("starting service...");
                            addLog("Fetching...");
                            fetch(method: method, url: urlS!, headers: advancedJsonParse(headerController.text) ?? defaultHeaders, body: tryJsonParse(bodyController.text) ?? {});
                          },
                          color: Colors.green,
                          iconSize: 36,
                        ),
                      ),
                      if (method == "PING")
                      Tooltip(
                        message: "Stop the request",
                        child: IconButton(
                          icon: Icon(Icons.stop_rounded),
                          onPressed: () {
                            ping?.stop();
                          },
                          color: Colors.red,
                          iconSize: 36,
                        ),
                      ),
                      Tooltip(
                        message: "Copy most recent response to clipboard",
                        child: IconButton(
                          icon: Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: response));
                            showSnackBar(context, "Copied response to clipboard!");
                          },
                          color: Colors.blue,
                          iconSize: 26,
                        ),
                      ),
                      Tooltip(
                        message: "Export entire log as a text file",
                        child: IconButton(
                          icon: Icon(Icons.ios_share),
                          onPressed: () {
                            shareText(content: log, filename: "log.txt");
                          },
                          color: Colors.blue,
                          iconSize: 26,
                        ),
                      ),
                      if (verbose)
                      Tooltip(
                        message: "Refresh the log",
                        child: IconButton(
                          icon: Icon(Icons.refresh),
                          onPressed: () {
                            addLog("Refreshing the log...");
                            refresh();
                          },
                          color: Colors.blue,
                          iconSize: 26,
                        ),
                      ),
                      Tooltip(
                        message: "Clear the console",
                        child: IconButton(
                          icon: Icon(Icons.cleaning_services),
                          onPressed: () {
                            addLog("Clearing console...");
                            log = "Console cleared!";
                            refresh();
                          },
                          color: Colors.blue,
                          iconSize: 26,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map? tryJsonParse(String value) {
    try {
      return jsonDecode(value);
    } catch (e) {
      return null;
    }
  }

  Map<String, String>? advancedJsonParse(String value) {
    Map? output = tryJsonParse(value);
    if (output == null) {
      return null;
    }
    try {
      return output.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      return null;
    }
  }

  Map<String, String>? toMapStringString(Map? value) {
    if (value == null) {
      return null;
    }
    try {
      return value.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      return null;
    }
  }

  bool validator({required dynamic value, required Type type}) {
    try {
      if (value == null) {
        return false;
      }
      if (type == Map) {
        try {
          jsonDecode(value);
          return true;
        } catch (e) {
          print("validator failed: $e");
          return false;
        }
      } else if (type == Map<String, String>) {
        try {
          Map input = jsonDecode(value);
          if (toMapStringString(input) == null) {
            return false;
          }
          return true;
        } catch (e) {
          print("validator failed: $e");
          return false;
        }
      } else if (type == Uri) {
        if ((Uri.tryParse(value)?.isAbsolute ?? false) || value == "localhost") {
          value = addHttpPrefix(value);
          return false;
        } else {
          return false;
        }
      } else {
        error("Invalid expected type: $type\nValidator is not configured to handle this type.");
        return false;
      }
    } catch (e) {
      error("Error checking $value for type $type: $e");
      return false;
    }
  }

  Future<void> pingServer({required Uri url}) async {
    String uri = url.host.replaceAll("localhost", "127.0.0.1");
    List pings = [];
    print("pinging url: $uri");
    addLog("Pinging URL: $uri");
    addLog("Press stop to stop ping and see summary.");
    ping = Ping(uri);
    print('running ping command: ${ping!.command}');
    ping!.stream.listen((event) {
      pings.add("ping $uri: $event");
      response = pings.join('\n');
      print("ping $uri: $event");
      addLog("ping $uri: $event");
    });
  }

  Future<void> fetch({required String method, required Uri url, required Map body, required Map<String, String> headers}) async {
    if (method == 'PING') {
      print("changing route for ping");
      return pingServer(url: url);
    }
    print("making request with method $method...");
    http.Response? responseS;
    print("fetching response...");
    try {
      switch (method) {
        case 'GET': 
          responseS = await http.get(url);
          break;
        case 'POST':
          responseS = await http.post(
            url,
            body: body,
          );
          break;
        case 'OPTIONS':
          var request = http.Request('OPTIONS', url);
          request.headers.addAll(headers);
          http.StreamedResponse responseSS = await request.send();
          print("found response: ${responseSS.statusCode}");
          response = jsonEncode({
            "status": responseSS.statusCode,
            "headers": responseSS.headers,
          });
          addLog("Response status: ${responseSS.statusCode}");
          addLog("Response headers: ${jsonEncode(responseSS.headers)}", spacer: true);
          break;
        default:
          throw Exception("Unknown/unhandled method: $method");
      }
      if (method == 'OPTIONS') {
        return;
      }
      if (responseS == null) {
        throw Exception("Response is null.");
      }
      print("found response: ${responseS.statusCode}");
      response = jsonEncode({
        "status": responseS.statusCode,
        "headers": responseS.headers,
        "body": responseS.body,
      });
      addLog("Response status: ${responseS.statusCode}");
      addLog("Response headers: ${jsonEncode(responseS.headers)}", spacer: true);
      addLog("Response data: ${responseS.body}", spacer: true);
    } catch (error) {
      print("response failed: $error");
      addLog('Request failed: $error');
    }
  }

  Widget InputBox({
    required String item,
    @Deprecated("Form and validator use has been removed.")
    required String phrase,
    required Type type,
    required Function function,
    @Deprecated("Form and validator use has been removed.")
    required GlobalKey<FormState> key,
    required TextEditingController controller,
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: item,
          border: OutlineInputBorder(),
        ),
        maxLines: multiline ? null : 1,
      ),
    );
  }
}

String formatTime({
  required int input,
  /// amount of time that your input holds
  /// 1: milliseconds
  /// 2: seconds
  /// 3: minutes
  int mode = 1,
  /// type of output
  /// 1: hh:mm:ss
  /// 2: hh:mm
  /// 3: mm:ss
  int output = 2,
  bool army = false,
}) {
  int ms = input;
  switch (mode) {
    case 1:
      ms = input;
      break;
    case 2:
      ms = input % 1000;
      break;
    case 3:
      ms = input % (1000 * 60);
      break;
    default:
      logger.error("Invalid mode: $mode");
      break;
  }

  DateTime time = DateTime.fromMillisecondsSinceEpoch(ms);
  int hour = time.hour;
  int minute = time.minute;
  int second = time.second;
  int roundedHour = hour;
  if (army == false) {
    if (hour > 12) {
      roundedHour = hour - 12;
    }
  }
  String formatted = "$roundedHour:${minute.toString().padLeft(2, '0')}${output == 1 || output == 3 ? (":${second.toString().padLeft(2, '0')}"): ""}${!army ? (" ${hour >= 12 ? "PM" : "AM"}") : ""}";
  return formatted;
}
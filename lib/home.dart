import 'dart:convert';
import 'dart:io';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:localpkg/dialogue.dart';
import 'package:localpkg/functions.dart';
import 'package:localpkg/logger.dart' as logger;
import 'package:localpkg/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ping/settings.dart';
import 'package:ping/util.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

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

  List history = [];
  List pins = [];

  final TextEditingController urlController = TextEditingController();
  final TextEditingController headerController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();
  final TextEditingController messageController = TextEditingController();
  final TextEditingController typeController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final urlKey = GlobalKey<FormState>();
  final headerKey = GlobalKey<FormState>();
  final bodyKey = GlobalKey<FormState>();

  bool useUrl = true;
  bool useHeaders = true;
  bool useBody = false;

  Uri? url;
  Map<String, String>? headers;
  Map? body = {};
  Map settings = {};

  Ping? ping;
  WebSocketChannel? currentSocket;
  socket_io.Socket? currentSocketIo;

  bool loading = false;
  bool ready = false;
  bool verbose = false;
  bool requestStreamActive = false;

  String log = "Loading...";
  String response = "Waiting...";
  String method = "GET";
  String messageFormat = "plaintext";

  List methods = ["GET", "POST", "OPTIONS", "PING", "WebSocket", "Socket.io"];
  List messageFormats = ["plaintext", "JSON"];

  @override
  void initState() {
    print("initializing...");
    headers = defaultHeaders;
    if (widget.item != null) {
      method = widget.item?["method"];
      url = Uri.tryParse(widget.item!["url"]);
      body = jsonDecode(widget.item!["body"]);
      headers = toMapStringString(jsonDecode(widget.item!["headers"]));
    }
    urlController.text = "${url ?? ""}";
    headerController.text = jsonEncode(headers);
    bodyController.text = jsonEncode(body);
    typeController.text = "message";
    if (verbose) {
      print("verbose mode");
      addLog("Starting verbose mode...");
    }
    super.initState();
    start();
  }

  void start() async {
    print("starting...");
    methodHandler();
    settings = await getSettings();
    history = settings["history"];
    pins = settings["pins"];
    ready = true;
    print("application ready");
    addLog("[g]Ready!");
  }

  void print(dynamic input, {String? code, bool trace = false, bool add = true}) {
    logger.print("$input", code: code, trace: trace);
    if (verbose && add) {
      addLog("VERBOSE: $input", verbose: true);
    }
  }

  void warn(dynamic input, {String? code, bool trace = false, bool add = true}) {
    logger.warn("$input", code: code, trace: trace);
    if (verbose && add) {
      addLog("[y]WARNING: $input", verbose: true);
    }
  }

  void error(dynamic input, {String? code, bool trace = false, bool add = true}) {
    logger.error("$input", code: code, trace: trace);
    if (verbose && add) {
      addLog("[r]ERROR: $input", verbose: true);
    }
  }

  void methodHandler() {
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
      case 'WebSocket':
        useUrl = true;
        useBody = false;
        useHeaders = false;
        break;
      case 'Socket.io':
        useUrl = true;
        useBody = false;
        useHeaders = false;
        break;
    }
  }

  Future<void> save() async {
    print("saving settings...");
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("history", jsonEncode(history));
    prefs.setString("pins", jsonEncode(pins));
    print("saved settings");
  }

  void refresh({bool mini = false}) async {
    if (mini == true) {
      setState(() {});
      return;
    }
    print("refreshing...");
    await save();
    settings = await getSettings();
    verbose = settings["verbose"];
    history = settings["history"];
    pins = settings["pins"];
    print("retrieved settings");
    methodHandler();
    setState(() {});
  }

  void addLog(String logS, {bool spacer = false, bool verbose = false}) {
    log += "\n${verbose ? "[z]" : ""}${spacer ? "\n" : ""}$logS";
    print("scrollController: ${scrollController.runtimeType}", add: false);
    double scroll = 0;
    double current = 0;
    bool jumpScroll = false;
    try {
      if (scrollController.hasClients) {
        scroll = scrollController.position.maxScrollExtent;
        current = scrollController.position.pixels;
        if (scroll == current) {
          jumpScroll = true;
        }
        print("scroll: $current,$scroll,$jumpScroll", add: false);
      } else {
        throw Exception("scrollController not initialized");
      }
    } catch (e) {
      print("scrollController variable error: $e");
    }
    refresh(mini: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (scrollController.hasClients) {
          if (jumpScroll) {
            scroll = scrollController.position.maxScrollExtent;
            print('setting scroll position from ${scrollController.position.pixels} to $scroll', add: false);
            scrollController.jumpTo(scroll);
          }
        } else {
          throw Exception("scrollController not initialized");
        }
      } catch (e) {
        print("scrollController goto error: $e", add: false);
      }
    });
  }

  List<TextSpan> parseString(String input) {
    final lines = input.split('\n');
    final count = lines.length;
    return lines.asMap().entries.map((entry) {
      int index = entry.key;
      String line = entry.value;
      Color? color;

      if (line.startsWith('[b]')) { // blue
        color = Colors.blue;
      } else if (line.startsWith('[r]')) { // red
        color = Colors.red;
      } else if (line.startsWith('[g]')) { // green
        color = Colors.green;
      } else if (line.startsWith('[y]')) {
        color = Colors.yellow;
      } else if (line.startsWith('[z]')) {
        color = Colors.grey;
      }

      line = line.substring(color != null ? 3 : 0);
      return TextSpan(
        text: "$line${index == count ? "" : "\n"}",
        style: TextStyle(color: color),
      );
    }).toList();
  }

  String removeColors(String text) {
    return text.replaceAll("[r]", "").replaceAll("[g]", "").replaceAll("[b]", "").replaceAll("[y]", "").replaceAll("[z]", "");
  }

  Map? getItem({bool includeTime = false}) {
    try {
      Map data = {
        "url": urlController.text,
        "body": bodyController.text,
        "headers": headerController.text,
        "method": method,
      };
      if (includeTime) {
        data["time"] = DateTime.now().millisecondsSinceEpoch;
      }
      return data;
    } catch (e) {
      return null;
    }
  }

  bool pinned() {
    return equalTo(pins);
  }

  bool equalTo(List compareTo) {
    Map? item = getItem();
    if (item == null) {
      return false;
    }
    return compareTo.any((map) => equalCondition(map, item));
  }

  bool equalCondition(Map map, Map item) {
    return map['url'] == item['url'] && map['body'] == item['body'] && map['headers'] == item['headers'] && map['method'] == item['method'];
  }

  bool isSocket() {
    return method == "WebSocket" || method == "Socket.io";
  }

  @override
  Widget build(BuildContext context) {
    bool isPinned = pinned();
    if (method != "PING" && !isSocket()) {
      requestStreamActive = false;
    }
    return Scaffold(
      appBar: AppBar(
        title: DropdownButton(
          value: method,
          hint: Text('Method'),
          onChanged: (dynamic newMethod) {
            if (requestStreamActive) {
              addLog("[r]Please stop your current request to switch methods.");
              return;
            }
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
          onPressed: () {
            navigate(context: context, page: Settings());
          },
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
            onSelected: (dynamic value) {
              navigate(context: context, page: Home(home: false, item: value));
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  child: Text("See all history"),
                  onTap: () {
                    showDialogue(context: context, title: "All History", content: ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        Map item = history[index];
                        return ListTile(
                          title: Text(
                            "${formatTime(input: item["time"])} ${DateTime.fromMillisecondsSinceEpoch(item["time"]).toString().substring(5, 10).replaceAll("-", "/")}",
                          ),
                          subtitle: Text(
                            "${item["method"]} ${item['url']}",
                          ),
                          onTap: () {
                            navigate(context: context, page: Home(home: false, item: item));
                          },
                        );
                      },
                    ), fullscreen: true);
                  },
                ),
                ...history.take(10).map((item) {
                  print(item);
                  return PopupMenuItem(
                    value: item,
                    child: Text("${formatTime(input: item["time"])} ${DateTime.fromMillisecondsSinceEpoch(item["time"]).toString().substring(5, 10).replaceAll("-", "/")}: ${item["method"]} ${item['url']}"),
                  );
                }),
              ];
            },
          ),
          if (widget.home)
          PopupMenuButton(
            icon: Icon(Icons.push_pin),
            onSelected: (dynamic value) {
              navigate(context: context, page: Home(home: false, item: value));
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  child: Text("See all pins"),
                  onTap: () {
                    editPins(context: context, pins: pins);
                  },
                ),
                ...pins.take(10).map((item) {
                  return PopupMenuItem(
                    value: item,
                    child: Text("${item["method"]} ${item['url']}"),
                  );
                }),
              ];
            },
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
                    InputBox(item: "URL", controller: urlController),
                    if (useHeaders)
                    InputBox(item: "Headers", controller: headerController, multiline: true),
                    if (useBody)
                    InputBox(item: "Body", controller: bodyController, multiline: true),
                    if (isSocket())
                    Row(
                      children: [
                        Expanded(
                          child: InputBox(item: "Message", controller: messageController, multiline: true),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            String message = messageController.text;
                            String type = typeController.text;
                            if (message == "") {
                              print("no message");
                              return;
                            }
                            if (type == "") {
                              type == "message";
                            }
                            if (!requestStreamActive) {
                              print("request not in progress");
                              return;
                            }
                            print("sending message... ($type)");
                            if (method == "WebSocket") {
                              currentSocket!.sink.add(message);
                            } else if (method == "Socket.io") {
                              print("finding format $messageFormat...");
                              switch (messageFormat) {
                                case 'JSON':
                                  try {
                                    Map messageS = jsonDecode(message);
                                    currentSocketIo!.emit(type, messageS);
                                  } catch (e) {
                                    print("message to messageS(JSON) failed");
                                    addLog("[r]Please enter a valid JSON message to use the JSON format.");
                                  }
                                  return;
                                default:
                                  currentSocketIo!.emit(type, message);
                              }
                            } else {
                              throw Exception("Method $method not configured to send messages");
                            }
                            print('message sent', add: false);
                            addLog("[g]Message sent!");
                            messageController.clear();
                          },
                          child: Icon(Icons.send),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.all(8.0),
                            shape: CircleBorder(),
                          ),
                        ),
                      ],
                    ),
                    if (method == "Socket.io")
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<String>(
                            hint: Text("Message Format"),
                            value: messageFormat,
                            items: messageFormats.map((item) {
                              return DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              messageFormat = value!;
                              refresh(mini: true);
                            },
                          ),
                        ),
                        Expanded(
                          child: InputBox(item: "Message Type", controller: typeController, multiline: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Section(
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: loading ? CircularProgressIndicator() : SizedBox.shrink(),
                  ),
                  Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.topLeft,
                                child: SelectableText.rich(
                                  TextSpan(
                                    style: GoogleFonts.robotoMono(
                                      textStyle: TextStyle(
                                        fontSize: settings["consoleFontSize"],
                                      ),
                                    ),
                                    children: parseString(log),
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
                          if (!requestStreamActive)
                          Tooltip(
                            message: "Start the request",
                            child: IconButton(
                              icon: Icon(Icons.play_arrow_rounded),
                              onPressed: () {
                                print("starting request...");
                                print("running pre-flight checks...");
                  
                                if (requestStreamActive) {
                                  print("IconButton: ping already in progress");
                                  return;
                                }
                  
                                bool pass = validate();
                                Uri? urlS = Uri.tryParse(addHttpPrefix(urlController.text, defaultPrefix: isSocket() ? "ws" : "http"));
                                
                                if (pass == false) {
                                  return;
                                }
                                
                                print("starting service...");
                                addLog("[b]Fetching...");
                                loading = true;
                                refresh(mini: true);
                                fetch(method: method, url: urlS!, headers: advancedJsonParse(headerController.text) ?? defaultHeaders, body: tryJsonParse(bodyController.text) ?? {});
                              },
                              color: Colors.green,
                              iconSize: 36,
                            ),
                          ),
                          if (requestStreamActive)
                          Tooltip(
                            message: "Stop the request",
                            child: IconButton(
                              icon: Icon(Icons.stop_rounded),
                              onPressed: () {
                                if (method == "PING") {
                                  print("stopping ping...");
                                  ping?.stop();
                                } else if (method == "WebSocket") {
                                  print("closing socket (sink.close)...");
                                  currentSocket!.sink.close();
                                  refresh();
                                } else if (method == "Socket.io") {
                                  print("closing socket (disconnect)...");
                                  currentSocketIo!.disconnect();
                                } else {
                                  throw Exception("Method $method not handled for stop");
                                }
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
                                addLog("[g]Copied most response to clipboard!");
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
                          Tooltip(
                            message: isPinned ? "Remove from your pins" : "Add to your pins",
                            child: IconButton(
                              icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                              onPressed: () {
                                Map? item = getItem();
                                if (item != null) {
                                  if (pinned()) {
                                    pins.removeWhere((map) => equalCondition(map, item));
                                    addLog("[g]Removed from pins!");
                                  } else {
                                    pins.add(item);
                                    addLog("[g]Added to pins!");
                                  }
                                  refresh();
                                } else {
                                  print("item is null");
                                  validate();
                                }
                              },
                              color: Colors.blue,
                              iconSize: 26,
                            ),
                          ),
                          Tooltip(
                            message: "Refresh the screen",
                            child: IconButton(
                              icon: Icon(Icons.refresh),
                              onPressed: () {
                                addLog("[b]Refreshing...");
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
                                addLog("[b]Clearing console...");
                                log = "[g]Console cleared!";
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

  bool validate() {
    bool pass = true;
    if (useUrl) {
      if (urlController.text == "") {
        print("null check failed on url");
        pass = false;
        addLog("[r]Please enter a valid url.");
      }
    }

    if (useBody) {
      if (!validator(value: bodyController.text, type: Map)) {
        print("validator failed on body");
        pass = false;
        addLog("[r]Please enter a valid JSON body.");
      }
    }

    if (useHeaders) {
      if (!validator(value: headerController.text, type: Map<String, String>)) {
        print("validator failed on headers");
        pass = false;
        addLog("[r]Please enter valid JSON headers.");
      }
    }

    return pass;
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
          value = addHttpPrefix(value, defaultPrefix: isSocket() ? "ws" : "http");
          return true;
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

  bool validipv4(String ip) {
    final ipv4Regex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)$'
    );
    return ipv4Regex.hasMatch(ip);
  }

  bool validipv6(String ip) {
    final ipv6Regex = RegExp(
      r'^(?:[A-Fa-f0-9]{1,4}:){7}[A-Fa-f0-9]{1,4}$|'
      r'^(?:[A-Fa-f0-9]{1,4}:){1,7}:$|'
      r'^:(?::[A-Fa-f0-9]{1,4}){1,7}$|'
      r'^(?:[A-Fa-f0-9]{1,4}:){1,6}:[A-Fa-f0-9]{1,4}$|'
      r'^(?:[A-Fa-f0-9]{1,4}:){1,5}(:[A-Fa-f0-9]{1,4}){1,2}$|'
      r'^(?:[A-Fa-f0-9]{1,4}:){1,4}(:[A-Fa-f0-9]{1,4}){1,3}$|'
      r'^(?:[A-Fa-f0-9]{1,4}:){1,3}(:[A-Fa-f0-9]{1,4}){1,4}$|'
      r'^(?:[A-Fa-f0-9]{1,4}:){1,2}(:[A-Fa-f0-9]{1,4}){1,5}$|'
      r'^[A-Fa-f0-9]{1,4}:((:[A-Fa-f0-9]{1,4}){1,6})$|'
      r'^:((:[A-Fa-f0-9]{1,4}){1,7}|:)$|'
      r'^[A-Fa-f0-9]{1,4}:((:[A-Fa-f0-9]{1,4}){1,7}|:)$'
    );
    return ipv6Regex.hasMatch(ip);
  }

  void pingServer({required Uri url}) async {
    print("ping in progress: $requestStreamActive");
    if (requestStreamActive) {
      print("pingServer: ping already in progress");
      return;
    } else {
      requestStreamActive = true;
    }
    String uri = url.host.replaceAll("localhost", "127.0.0.1");
    try {
      if (!validipv4(uri) && !validipv6(uri)) {
        print("finding ipv4 address...");
        List addresses = await InternetAddress.lookup(uri, type: InternetAddressType.IPv4);
        InternetAddress address = addresses.first;
        uri = address.address;
        print("found $uri ($address)");
      }
    } catch (e) {
      error("error finding address for $uri: $e");
      requestStreamActive = false;
      addLog("[r]We could not find an IPv4 address for $uri.");
      loading = false;
      refresh(mini: true);
      return;
    }
    List pings = ["Pinging $uri ($url)", ""];
    List times = [];
    print("pinging url: $uri");
    addLog("Press stop to stop ping and see ping summary.");
    ping = Ping(uri, ipv6: validipv6(uri));
    print('running ping command: ${ping!.command}');
    ping!.stream.listen((event) {
      print("ping $uri: $event", add: false);
      bool isSummary = event.summary != null;
      bool isError = event.error != null;
      String summary = "NOT AVAILABLE";
      String text = "NOT AVAILABLE";

      if (isSummary) {
        print("summary received");
        pings.add("");
        requestStreamActive = false;
        loading = false;
        refresh(mini: true);
        PingSummary pingSummary = event.summary!;
        int transmitted = pingSummary.transmitted;
        int received = pingSummary.received;
        int time = times.reduce((a, b) => a + b);
        int average = time ~/ times.length;
        int success = ((received / transmitted) * 100).toInt();
        print("time,average: $time,$average");
        summary = "${getColorForPing(average)}Total time: ${time}ms\n${getColorForPing(average)}Average time: ${average}ms\nTransmitted: $transmitted\nReceived: $received\n${success == 100 ? "[g]" : (success == 0 ? "[r]" : "[y]")}Package loss: ${100 - success}%";
      } else {
        if (event.response?.time?.inMilliseconds != null) {
          times.add(event.response!.time!.inMilliseconds);
        }
      }

      if (isError) {
        loading = false;
        refresh(mini: true);
        PingError error = event.error!;
        text = "[r]Ping $uri (#${event.response?.seq}): ${error.error.message}";
      } else if (isSummary) {
        loading = false;
        refresh(mini: true);
        text = "Ping $uri Summary:\n$summary";
      } else {
        text = "${getColorForPing(event.response?.time?.inMilliseconds)}Ping $uri (#${event.response?.seq}): ${event.response?.time?.inMilliseconds}ms";
      }

      addLog(text, spacer: isSummary);
      pings.add(removeColors(text));
      response = pings.join('\n');
    });
  }

  String getColorForPing(int? ping) {
    if (ping == null) {
      return "";
    }
    if (ping < 100) {
      return "[g]";
    } else if (ping < 300) {
      return "[y]";
    } else {
      return "[r]";
    }
  }

  void socket(int mode, Uri url) {
    print("socket in progress: $requestStreamActive");
    if (requestStreamActive) {
      print("socket: socket already in progress");
      return;
    } else {
      requestStreamActive = true;
      refresh(mini: true);
    }
    print("socket: $mode,$url");
    currentSocket = null;
    try {
      if (mode == 1) {
        addLog("[b]Connecting to WebSocket $url...");
        currentSocket = WebSocketChannel.connect(url);
        loading = false;
        refresh(mini: true);
        addLog("[b]Listening...");
        currentSocket?.stream.listen(
          (message) {
            addLog("Received message: $message");
          },
          onDone: () {
            addLog("[y]Closed socket");
            requestStreamActive = false;
          },
          onError: (error) {
            print("socket error ($mode,$url): $error");
            addLog("[r]Unable to connect to socket");
          },
        );
      } else if (mode == 2) {
          String host = url.host;
          int? port = url.port;
          String path = url.path;
          String uri = "http://$host:$port";

          print("connecting at host,port,path,url: $host,$port,$path,$uri");
        addLog("[b]Connecting to WebSocket $path${path == "" ? "" : "/path"}...");
          currentSocketIo = socket_io.io(
            uri,
            socket_io.OptionBuilder()
              .disableAutoConnect()
              .setTransports(['websocket'])
              .build(),
          );

          if (path != "") {
            print("adding path $path to socket");
            currentSocketIo?.io.options?['path'] = path;
          }

          currentSocketIo?.connect();

          currentSocketIo?.onConnect((_) {
            print('socket connected');
            addLog("[b]Listening...");
            loading = false;
            refresh(mini: true);
          });

          currentSocketIo?.on('message', (data) {
            addLog("Received message: $data");
          });

          currentSocketIo?.onDisconnect((_) {
            addLog("[y]Closed socket");
            currentSocketIo?.dispose();
            requestStreamActive = false;
          });

          currentSocketIo?.onError((error) {
            print("socket error: $error");
            addLog("[r]Unable to connect to socket");
          });
        }
    } catch (e) {
      print("socket (mode $mode) error: $e");
      addLog("Unable to connect to socket");
      requestStreamActive = false;
      loading = false;
      refresh();
    }
  }

  void fetch({required String method, required Uri url, required Map body, required Map<String, String> headers}) async {
    history.insert(0, getItem(includeTime: true));
    if (method == 'PING') {
      print("changing route for ping");
      return pingServer(url: url);
    }
    if (method == 'WebSocket' || method == 'Socket.io') {
      print("changing route for websocket/socket.io");
      return socket(method == 'WebSocket' ? 1 : 2, url);
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
          loading = false;
          refresh(mini: true);
          response = jsonEncode({
            "status": responseSS.statusCode,
            "headers": responseSS.headers,
          });
          String color = responseSS.statusCode == 200 ? "[g]" : "[y]";
          addLog("${color}Response status: ${responseSS.statusCode}");
          addLog("Response headers: ${jsonEncode(responseSS.headers)}", spacer: true);
          return;
        default:
          throw Exception("Unknown/unhandled method: $method");
      }
      print("found response: ${responseS.statusCode}");
      loading = false;
      refresh(mini: true);
      response = jsonEncode({
        "status": responseS.statusCode,
        "headers": responseS.headers,
        "body": responseS.body,
      });
      String color = responseS.statusCode == 200 ? "[g]" : "[y]";
      addLog("${color}Response status: ${responseS.statusCode}");
      addLog("Response headers: ${jsonEncode(responseS.headers)}", spacer: true);
      addLog("Response data: ${responseS.body}", spacer: true);
    } catch (error) {
      print("request failed: $error");
      addLog('[r]Request failed');
      loading = false;
      refresh(mini: true);
    }
  }

  Widget InputBox({
    required String item,
    @Deprecated("Form and validator use has been removed.")
    String phrase = "",
    @Deprecated("Form and validator use has been removed.")
    Type? type,
    @Deprecated("Form and validator use has been removed.")
    Function? function,
    @Deprecated("Form and validator use has been removed.")
    GlobalKey<FormState>? key,
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
        onChanged: (text) {
          refresh(mini: true);
        },
      ),
    );
  }

  Future<bool?> editPins({
    required BuildContext context,
    required List pins,
  }) {
    String title = "Manage Pins";
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(title),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.95,
                child: ReorderableListView.builder(
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final item = pins.removeAt(oldIndex);
                      pins.insert(newIndex, item);
                      save();
                    });
                  },
                  itemCount: pins.length,
                  itemBuilder: (context, index) {
                    Map item = pins[index];
                    return ListTile(
                      key: Key("pin$index"),
                      leading: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            pins.removeAt(index);
                            refresh();
                          });
                        },
                      ),
                      title: Text(
                        "${item["method"]} ${item['url']}",
                      ),
                      onTap: () {
                        navigate(context: context, page: Home(home: false, item: item));
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop(true); 
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
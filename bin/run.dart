import "dart:async";
import "dart:io";
import "dart:convert";

import "package:dslink/dslink.dart";
import "package:syscall/readline.dart" deferred as Readline;
import "package:dslink/worker.dart";

import "package:path/path.dart" as pathlib;

LinkProvider link;

readlineWorker(Worker worker) async {
  await worker.init(methods: {
    "readline": (String prompt) async {
      await Readline.loadLibrary();

      if (Platform.isWindows) {
        stdout.write("> ");
        return stdin.readLineSync();
      } else {
        try {
          return Readline.Readline.readLine(prompt, addToHistory: true);
        } catch (e) {
          stdout.write("> ");
          return stdin.readLineSync();
        }
      }
    }
  });
}

WorkerSocket readline = createWorker(readlineWorker);
Directory shellDir;

main(List<String> argv) async {
  var home = Platform.environment["HOME"];
  if (home == null) {
    home = Platform.isWindows ? "C:\\" : "/";
  }
  var dir = new Directory(pathlib.join(home, ".dsash"));

  if (!(await dir.exists())) {
    await dir.create(recursive: true);
  }

  shellDir = dir;

  Directory.current = shellDir;

  updateLogLevel("OFF");

  await readline.init();

  link = new LinkProvider(argv, "Shell-", isRequester: true, isResponder: false, defaultLogLevel: "OFF");
  await link.connect();

  Requester requester = await link.onRequesterReady;

  while (true) {
    var line = await readline.callMethod("readline", "> ");

    if (line.trim().isEmpty) continue;
    var split = line.split(" ");

    var cmd = split[0];
    var args = split.skip(1).toList();

    if (["list", "ls", "l"].contains(cmd)) {
      if (args.length == 0) {
        args = ["/"];
      }

      var path = interpretPath(args[0]);
      RequesterListUpdate update = await requester.list(path).first;

      var node = update.node;
      var name = node.configs.containsKey(r"$name") ? node.configs[r"$name"] : node.name;

      print("Name: ${name}");
      print("Configs:");
      for (var key in node.configs.keys) {
        print("  ${key}: ${node.configs[key]}");
      }

      if (node.attributes.isNotEmpty) {
        print("Attributes:");
        for (var key in node.attributes.keys) {
          print("  ${key}: ${node.attributes[key]}");
        }
      }

      if (node.children.isNotEmpty) {
        print("Children:");
        for (var id in node.children.keys) {
          RemoteNode child = node.getChild(id);
          var cn = child.configs.containsKey(r"$name") ? child.configs[r"$name"] : child.name;
          print("  - ${cn}${cn != child.name ? ' (${child.name})' : ''}");
        }
      }
    } else if (["value", "val", "v"].contains(cmd)) {
      if (args.length == 0) {
        print("Usage: ${cmd} <path>");
        continue;
      }

      var path = interpretPath(args.join(" "));
      var completer = new Completer<ValueUpdate>.sync();
      ReqSubscribeListener listener;

      listener = requester.subscribe(path, (ValueUpdate update) {
        listener.cancel();
        completer.complete(update);
      });

      try {
        ValueUpdate update = await completer.future.timeout(new Duration(seconds: 5), onTimeout: () {
          listener.cancel();
          throw new Exception("ERROR: Timed out while attempting to get the value.");
        });
        print(update.value);
      } catch (e) {
        print(e.toString());
      }
    } else if (["set", "s"].contains(cmd)) {
      if (args.length < 2) {
        print("Usage: ${cmd} <path> <value>");
        continue;
      }

      var path = interpretPath(args[0]);
      var value = parseInputValue(args.skip(1).join(" "));
      await requester.set(path, value);
    } else if (["cd"].contains(cmd)) {
      String path;
      if (args.length == 0) {
        path = "/";
      } else {
        path = args.join(" ");
      }

      cwd = interpretPath(path);
    } else if (["cwd", "pwd"].contains(cmd)) {
      print("Working Directory: ${cwd}");
    } else if (["q", "quit", "exit", "end", "finish", "done"].contains(cmd)) {
      exit(0);
    } else if (["?", "help"].contains(cmd)) {
      if (args.length == 0) {
        print("Commands:");
        for (var c in HELPS.keys) {
          print("${c}: ${HELPS[c]}");
        }
      } else {
        var cmds = ALIASES.keys.expand((x) => x).toList();
        if (!cmds.contains(args[0])) {
          print("Unknown Command: ${args[0]}");
        } else {
          var n = ALIASES.keys.firstWhere((x) => x.contains(args[0]));
          var c = ALIASES[n];
          if (!HELPS.containsKey(c)) {
            print("No Help Found.");
          } else {
            print("${HELPS[c]}");
          }
        }
      }
    } else if (["i", "invoke", "call"].contains(cmd)) {
      if (args.length == 0) {
        print("Usage: ${cmd} <path> [values]");
        continue;
      }

      try {
        var path = interpretPath(args[0]);
        var value = args.length > 1 ? parseInputValue(args.skip(1).join(" ")) : {};

        List<RequesterInvokeUpdate> updates = await requester.invoke(path, value).toList();

        if (updates.length == 1 && updates.first.rows.length == 1) { // Single Row of Values
          var update = updates.first;
          var rows = update.rows;
          var values = rows.first;

          if (update.columns.isNotEmpty) {
            var i = 0;
            for (var x in update.columns) {
              print("${x.name}: ${values[i]}");
              i++;
            }
          } else if (update.columns.isEmpty && values.isNotEmpty) {
            print(values);
          }
        } else {
          var c = updates.last.columns;
          var x = [];
          for (var update in updates) {
            x.addAll(update.updates);
          }
          print(buildTableTree(c, x));
        }
      } catch (e) {
        print(e);
      }
    }
  }
}

String interpretPath(String input) {
  if (input.startsWith("/")) {
    input = input.substring(1);
  }

  input = "${cwd}/${input}";

  return pathlib.normalize(input);
}

const Map<List<String>, String> ALIASES = const {
  const ["ls", "l", "list"]: "ls",
  const ["value", "val", "v"]: "value",
  const ["set", "s"]: "set",
  const ["cwd", "pwd"]: "pwd",
  const ["i", "invoke", "call"]: "invoke",
  const ["help", "?"]: "help",
  const ["cd"]: "cd",
  const ["q", "quit", "exit", "finsh", "done"]: "exit"
};

const Map<String, String> HELPS = const {
  "ls": "List Configs, Attributes, and Children of Nodes",
  "invoke": "Invoke an Action",
  "set": "Set a Value",
  "pwd": "Print the Working Directory",
  "help": "Get Help",
  "cd": "Change Working Directory",
  "exit": "Exit the Tool"
};

String cwd = "/";

String encodePrettyJson(input) => new JsonEncoder.withIndent("  ").convert(input);

dynamic parseInputValue(String input) {
  var number = num.parse(input, (_) => null);
  if (number != null) {
    return number;
  }

  var lower = input.toLowerCase();

  if (lower == "true" || lower == "false") {
    return lower == "true";
  }

  try {
    return JSON.decode(input);
  } catch (e) {}

  if (KEY_VALUE_PAIRS.hasMatch(input)) {
    var m = {};
    var matches = KEY_VALUE_PAIRS.allMatches(input);

    for (var match in matches) {
      m[match.group(1)] = parseInputValue(match.group(2));
    }

    return m;
  }

  return input;
}

RegExp KEY_VALUE_PAIRS = new RegExp(r'([A-Za-z]+)=(?:\"(.+)\"|([^\s]+))');

class Icon {
  static const String CHECKMARK = "\u2713";
  static const String BALLOT_X = "\u2717";
  static const String VERTICAL_LINE = "\u23D0";
  static const String HORIZONTAL_LINE = "\u23AF";
  static const String LEFT_VERTICAL_LINE = "\u23B8";
  static const String LOW_LINE = "\uFF3F";
  static const String PIPE_VERTICAL = "\u2502";
  static const String PIPE_LEFT_HALF_VERTICAL = "\u2514";
  static const String PIPE_LEFT_VERTICAL = "\u251C";
  static const String PIPE_HORIZONTAL = "\u2500";
  static const String PIPE_BOTH = "\u252C";
  static const String HEAVY_VERTICAL_BAR = "\u275A";
  static const String REFRESH = "\u27F3";
  static const String HEAVY_CHECKMARK = "\u2714";
  static const String HEAVY_BALLOT_X = "\u2718";
  static const String STAR = "\u272D";
}

String buildTableTree(List<TableColumn> columns, List<List<dynamic>> rows) {
  List<Map<String, dynamic>> nodes = [];
  var map = {
    "label": "Result",
    "nodes": nodes
  };

  var i = 0;
  for (var row in rows) {
    var n = [];

    var x = 0;
    for (var value in row) {
      String name;
      if (x >= columns.length) {
        name = "";
      } else {
        name = columns[x].name;
      }

      n.add({
        "label": name,
        "nodes": [value.toString()]
      });
      x++;
    }

    nodes.add({
      "label": i.toString(),
      "nodes": n
    });
    i++;
  }

  return createTreeView(map);
}

String createTreeView(input, {String prefix: '', Map opts}) {
  if (input is String) {
    input = {
      "label": input
    };
  }

  var label = input.containsKey("label") ? input['label'] : "";
  var nodes = input.containsKey("nodes") ? input['nodes'] : [];

  var lines = label.split("\n");
  var splitter = '\n' + prefix + (nodes.isNotEmpty ? Icon.PIPE_VERTICAL : ' ') + ' ';

  return prefix + lines.join(splitter) + '\n' + nodes.map((node) {
    var last = nodes.last == node;
    var more = node is Map && node.containsKey("nodes") && node['nodes'] is List && node['nodes'].isNotEmpty;
    var prefix_ = prefix + (last ? ' ' : Icon.PIPE_VERTICAL) + ' ';

    return prefix
    + (last ? Icon.PIPE_LEFT_HALF_VERTICAL : Icon.PIPE_LEFT_VERTICAL) + Icon.PIPE_HORIZONTAL
    + (more ? Icon.PIPE_BOTH : Icon.PIPE_HORIZONTAL) + ' '
    + createTreeView(node, prefix: prefix_, opts: opts).substring(prefix.length + 2);
  }).join('');
}


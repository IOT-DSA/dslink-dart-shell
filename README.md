# DSA Shell

A Command Line Shell for DSA

## Installation

```bash
$ curl https://raw.githubusercontent.com/IOT-DSA/dslink-dart-shell/master/tool/install.sh > install.sh && bash install.sh; rm install.sh
```

Make sure `${HOME}/bin` is on your PATH, and that [Dart](https://www.dartlang.org/downloads/) is installed.

## Usage

```
# Run the Shell. This connects to a broker on localhost:8080
$ dsash
# Run the Shell with a specified broker.
$ dsash --broker http://my.broker.com/conn
# Discover a Broker and Connect the Shell to it.
$ dsash --discover
```

Commands:
ls: List Configs, Attributes, and Children of Nodes
invoke: Invoke an Action
set: Set a Value
pwd: Print the Working Directory
help: Get Help
cd: Change Working Directory
exit: Exit the Tool

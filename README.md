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

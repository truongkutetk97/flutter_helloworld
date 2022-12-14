// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: equal_elements_in_set

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:dart_ping/dart_ping.dart';

void main() {
  debugPrint("Process started");

  runApp(const MyApp());
  debugPrint("Process ended");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Welcome to Flutter',
      home: Scaffold(
        appBar: AppBar(
          title: const Center(
            child: Text(
              "MQTT Client Debug Console",
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // body: const InputFormWidget(),
        body: Column(
          children: [InputFormWidget()],
        ),
      ),
    );
    // );
  }
}

class ConsoleWidget extends StatefulWidget {
  final int data;
  const ConsoleWidget({Key? key, required this.data}) : super(key: key);

  @override
  State<ConsoleWidget> createState() => ConsoleWindows();
}

class ConsoleWindows extends State<ConsoleWidget> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final client = MqttServerClient.withPort('34.126.97.74', '', 1883);
  int pongCount = -1;
  String streamData = "NA";
  int once = 1;

  @override
  Widget build(BuildContext context) {
    debugPrint("ConsoleWindows ${widget.data}");
    final int state = widget.data;
    if (state == 2 && once == 1) {
      once = 0;
      debugPrint("Connecting to mqtt server");
      streamData += "\nNA";
      clientConnect();
      debugPrint("Connect has ended");
    }
    // return Column(
    //   key: _formKey,
    //   crossAxisAlignment: CrossAxisAlignment.start,
    //   children: <Widget>[
    //     Align(
    //       alignment: Alignment.centerLeft,
    //       widthFactor: (MediaQuery.of(context).size.width) /
    //           21, //max value is 20, offset by 1
    //       child: Text(streamData),
    //     ),
    //   ],
    // );
    // return ListView.builder(
    //     itemBuilder: (context, i) => Padding(
    //         padding: const EdgeInsets.symmetric(vertical: 38.0),
    //         child: Text(streamData)));
    return ListView(
      scrollDirection: Axis.vertical,
      reverse: true,
      children: [Text(streamData)],
    );
  }

  void clientConnect() async {
    debugPrint("clientConnect clientConnect clientConnect clientConnect");
    client.logging(on: true);
    client.setProtocolV311();
    client.keepAlivePeriod = 20;
    client.connectTimeoutPeriod = 2000; // milliseconds
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onSubscribed = onSubscribed;
    client.pongCallback = pong;
    client.autoReconnect = true;

    final connMess = MqttConnectMessage()
        .withClientIdentifier('Mqtt_MyClientUniqueId')
        .withWillTopic(
            'willtopic') // If you set this you must set a will message
        .withWillMessage('My Will message')
        .startClean() // Non persistent session for testing
        .withWillQos(MqttQos.atLeastOnce);
    debugPrint('EXAMPLE::Mosquitto client connecting....');
    client.connectionMessage = connMess;

    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      // Raised by the client when connection fails.
      debugPrint('EXAMPLE::client exception - $e');
      client.disconnect();
    } on SocketException catch (e) {
      // Raised by the socket layer
      debugPrint('EXAMPLE::socket exception - $e');
      client.disconnect();
    }

    /// Check we are connected
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      debugPrint('EXAMPLE::Mosquitto client connected');
    } else {
      /// Use status here rather than state if you also want the broker return code.
      debugPrint(
          'EXAMPLE::ERROR Mosquitto client connection failed - disconnecting, status is ${client.connectionStatus}');
      client.disconnect();
      exit(-1);
    }

    /// Ok, lets try a subscription
    debugPrint('EXAMPLE::Subscribing to the test/lol topic');
    const topic = '/b/#'; // Not a wildcard topic
    client.subscribe(topic, MqttQos.atMostOnce);

    /// The client has a change notifier object(see the Observable class) which we then listen to to get
    /// notifications of published updates to each subscribed topic.
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      /// The above may seem a little convoluted for users only interested in the
      /// payload, some users however may be interested in the received publish message,
      /// lets not constrain ourselves yet until the package has been in the wild
      /// for a while.
      /// The payload is a byte buffer, this will be specific to the topic
      // debugPrint(
      //     'EXAMPLE::Change notification:: topic is <${c[0].topic}>, payload is <-- $pt -->');
      // debugPrint('');
      setState(() {
        streamData += "\n---${c[0].topic}$pt";
      });
    });

    /// If needed you can listen for published messages that have completed the publishing
    /// handshake which is Qos dependant. Any message received on this stream has completed its
    /// publishing handshake with the broker.
    client.published!.listen((MqttPublishMessage message) {
      debugPrint(
          'EXAMPLE::Published notification:: topic is ${message.variableHeader!.topicName}, with Qos ${message.header!.qos}');
    });
  }

  void onDisconnected() {
    streamData += "\nClient has disconnected, retry after 5s";
    debugPrint(
        'EXAMPLE::OnDisconnected client callback - Client disconnection');
    if (client.connectionStatus!.disconnectionOrigin ==
        MqttDisconnectionOrigin.solicited) {
      debugPrint(
          'EXAMPLE::OnDisconnected callback is solicited, this is correct');
    } else {
      debugPrint(
          'EXAMPLE::OnDisconnected callback is unsolicited or none, this is incorrect - exiting');
      exit(-1);
    }
    if (pongCount == 3) {
      debugPrint('EXAMPLE:: Pong count is correct');
    } else {
      debugPrint(
          'EXAMPLE:: Pong count is incorrect, expected 3. actual $pongCount');
    }
  }

  /// The successful connect callback
  void onConnected() {
    streamData += "\nClient has connected";
    debugPrint(
        'EXAMPLE::OnConnected client callback - Client connection was successful');
  }

  /// Pong callback
  void pong() {
    streamData += "\nPingPong message";
    debugPrint('EXAMPLE::Ping response client callback invoked');
    pongCount++;
  }

  void onSubscribed(String topic) {
    streamData += "\nClient has subscribed to wildcard /b/# ";
    debugPrint('EXAMPLE::Subscription confirmed for topic $topic');
  }
}

class InputFormWidget extends StatefulWidget {
  const InputFormWidget({Key? key}) : super(key: key);

  @override
  State<InputFormWidget> createState() => MyCustomForm();
}

class MyCustomForm extends State<InputFormWidget> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  List<int> ipStat = [0, 0, 0, 0, 0, 0];
  int state = 0;
  String buttonText = "Connect";
  int connectionStat = 0; //1 connected
  int newWidgetCreated = 0;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Form(
        key: _formKey,
        child: Column(
          // crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            TextFormField(
              decoration: const InputDecoration(
                label: Center(
                  child: Text("Enter server address  "),
                ),
                hintText: 'Example: 34.126.97.74,8884',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                // contentPadding: EdgeInsets.zero,
                // alignLabelWithHint: true,
              ),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              validator: (String? value) {
                if (value?.length == 0) {
                  value = '34.126.97.74,8884';
                }
                debugPrint("checking ipaddress");
                ipStat = checkIpAddress(value);
                int ipValid = ipStat[0];
                debugPrint("ipstat =  $ipValid");
                if (value == null || value.isEmpty || ipValid == 0) {
                  debugPrint("return invalid validator");
                  return 'Please enter valid IP address:port';
                }
                return null;
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    buttonText = "Connecting";
                  });

                  // Validate will return true if the form is valid, or false if
                  // the form is invalid.
                  if (_formKey.currentState!.validate()) {
                    // Process data.
                    debugPrint("IP has valid");
                    String targetIp =
                        '${ipStat[1]}.${ipStat[2]}.${ipStat[3]}.${ipStat[4]}';
                    debugPrint(targetIp);
                    String fakeIp = "192.168.3.3";
                    final stream = Ping(targetIp, count: 3, timeout: 2);
                    debugPrint("Pinging google.com");
                    int pingCount = 0;
                    stream.stream.listen((d) {
                      debugPrint(d.toString());
                      Future.delayed(Duration(seconds: 3), () {
                        pingCount += 1;
                        int? time = d.response?.time?.inMilliseconds;
                        debugPrint("rsult$pingCount = $time");
                        if (time != null) {
                          setState(() {
                            buttonText = "Connected";
                            connectionStat = 2;
                          });
                          if (newWidgetCreated == 0) {
                            newWidgetCreated = 1;
                          }

                          debugPrint("Connectedddddddd");
                        } else if (pingCount == 3) {
                          setState(() {
                            buttonText = "Timeout, Retry?";
                          });
                        } else if (d.error?.error == ErrorType.unknownHost) {
                          setState(() {
                            buttonText = "Timeout, Retry?";
                          });
                        }
                        debugPrint(d.error?.error.toString());
                      });
                    });
                    debugPrint("Pinging google.com done");
                    FocusManager.instance.primaryFocus?.unfocus();
                  } else {
                    _formKey.currentState?.reset();
                    _formKey.currentState!.validate();
                  }
                },
                child: Text(buttonText),
              ),
            ),
            Container(
              constraints: BoxConstraints.expand(
                height: Theme.of(context).textTheme.headline4!.fontSize! * 1.1 +
                    // 505.0,
                    (MediaQuery.of(context).size.height) -
                    290,
              ),
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.centerLeft,
              child: ConsoleWidget(data: connectionStat),
            ),
            // Expanded(
            //   flex: 2,
            //   child: ConsoleWidget(data: connectionStat),
            // ),
            // ConsoleWidget(data: connectionStat),
          ],
        ),
      ),
    );
  }
}

List<int> checkIpAddress(String? inputValue) {
  //IPaddress should be in format a.a.a.a:b
  dynamic ret;
  String tempStr;
  ret = [0, 0, 0, 0, 0, 0];

  if (inputValue == null) {
    debugPrint("Input null");
    return ret;
  }
  int index = inputValue.indexOf(".");
  if (index == -1) {
    debugPrint("Input invalid");
    return ret;
  }
  int ip1 = int.parse(inputValue.substring(0, index).trim());

  tempStr = inputValue.substring(index + 1).trim();
  index = tempStr.indexOf(".");
  if (index == -1) {
    debugPrint("Input invalid");
    return ret;
  }
  int ip2 = int.parse(tempStr.substring(0, index).trim());

  tempStr = tempStr.substring(index + 1).trim();
  index = tempStr.indexOf(".");
  if (index == -1) {
    debugPrint("Input invalid");
    return ret;
  }
  int ip3 = int.parse(tempStr.substring(0, index).trim());

  tempStr = tempStr.substring(index + 1).trim();
  index = tempStr.indexOf(",");
  if (index == -1) {
    debugPrint("Input invalid");
    return ret;
  }
  int ip4 = int.parse(tempStr.substring(0, index).trim());

  int port = int.parse(tempStr.substring(index + 1).trim());
  if (port == 0 || port > 9999) {
    debugPrint("Input invalid");
    return ret;
  }
  debugPrint("Success get Ip Address: $ip1.$ip2.$ip3.$ip4:$port ");
  // List parts = [inputValue.substring(0,index).trim(),inputValue.substring(idx+1)]

  return [1, ip1, ip2, ip3, ip4, port];
}
// final client = MqttServerClient.withPort('34.126.97.74', '', 1883);

// var pongCount = 0; // Pong counter

// Future<int> main() async {
//   /// A websocket URL must start with ws:// or wss:// or Dart will throw an exception, consult your websocket MQTT broker
//   /// for details.
//   /// To use websockets add the following lines -:
//   /// client.useWebSocket = true;
//   /// client.port = 80;  ( or whatever your WS port is)
//   /// There is also an alternate websocket implementation for specialist use, see useAlternateWebSocketImplementation
//   /// Note do not set the secure flag if you are using wss, the secure flags is for TCP sockets only.
//   /// You can also supply your own websocket protocol list or disable this feature using the websocketProtocols
//   /// setter, read the API docs for further details here, the vast majority of brokers will support the client default
//   /// list so in most cases you can ignore this.
//   /// Set logging on if needed, defaults to off
//   client.logging(on: true);

//   /// Set the correct MQTT protocol for mosquito
//   client.setProtocolV311();

//   /// If you intend to use a keep alive you must set it here otherwise keep alive will be disabled.
//   client.keepAlivePeriod = 20;

//   /// The connection timeout period can be set if needed, the default is 5 seconds.
//   client.connectTimeoutPeriod = 2000; // milliseconds

//   /// Add the unsolicited disconnection callback
//   client.onDisconnected = onDisconnected;

//   /// Add the successful connection callback
//   client.onConnected = onConnected;

//   /// Add a subscribed callback, there is also an unsubscribed callback if you need it.
//   /// You can add these before connection or change them dynamically after connection if
//   /// you wish. There is also an onSubscribeFail callback for failed subscriptions, these
//   /// can fail either because you have tried to subscribe to an invalid topic or the broker
//   /// rejects the subscribe request.
//   client.onSubscribed = onSubscribed;

//   /// Set a ping received callback if needed, called whenever a ping response(pong) is received
//   /// from the broker.
//   client.pongCallback = pong;

//   /// Create a connection message to use or use the default one. The default one sets the
//   /// client identifier, any supplied username/password and clean session,
//   /// an example of a specific one below.
//   final connMess = MqttConnectMessage()
//       .withClientIdentifier('Mqtt_MyClientUniqueId')
//       .withWillTopic('willtopic') // If you set this you must set a will message
//       .withWillMessage('My Will message')
//       .startClean() // Non persistent session for testing
//       .withWillQos(MqttQos.atLeastOnce);
//   debugPrint('EXAMPLE::Mosquitto client connecting....');
//   client.connectionMessage = connMess;

//   /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
//   /// in some circumstances the broker will just disconnect us, see the spec about this, we however will
//   /// never send malformed messages.
//   try {
//     await client.connect();
//   } on NoConnectionException catch (e) {
//     // Raised by the client when connection fails.
//     debugPrint('EXAMPLE::client exception - $e');
//     client.disconnect();
//   } on SocketException catch (e) {
//     // Raised by the socket layer
//     debugPrint('EXAMPLE::socket exception - $e');
//     client.disconnect();
//   }

//   /// Check we are connected
//   if (client.connectionStatus!.state == MqttConnectionState.connected) {
//     debugPrint('EXAMPLE::Mosquitto client connected');
//   } else {
//     /// Use status here rather than state if you also want the broker return code.
//     debugPrint(
//         'EXAMPLE::ERROR Mosquitto client connection failed - disconnecting, status is ${client.connectionStatus}');
//     client.disconnect();
//     exit(-1);
//   }

//   /// Ok, lets try a subscription
//   debugPrint('EXAMPLE::Subscribing to the test/lol topic');
//   const topic = '/b/#'; // Not a wildcard topic
//   client.subscribe(topic, MqttQos.atMostOnce);

//   /// The client has a change notifier object(see the Observable class) which we then listen to to get
//   /// notifications of published updates to each subscribed topic.
//   client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
//     final recMess = c![0].payload as MqttPublishMessage;
//     final pt =
//         MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

//     /// The above may seem a little convoluted for users only interested in the
//     /// payload, some users however may be interested in the received publish message,
//     /// lets not constrain ourselves yet until the package has been in the wild
//     /// for a while.
//     /// The payload is a byte buffer, this will be specific to the topic
//     debugPrint(
//         'EXAMPLE::Change notification:: topic is <${c[0].topic}>, payload is <-- $pt -->');
//     debugPrint('');
//   });

//   /// If needed you can listen for published messages that have completed the publishing
//   /// handshake which is Qos dependant. Any message received on this stream has completed its
//   /// publishing handshake with the broker.
//   client.published!.listen((MqttPublishMessage message) {
//     debugPrint(
//         'EXAMPLE::Published notification:: topic is ${message.variableHeader!.topicName}, with Qos ${message.header!.qos}');
//   });

//   /// Lets publish to our topic
//   /// Use the payload builder rather than a raw buffer
//   /// Our known topic to publish to
//   const pubTopic = 'Dart/Mqtt_client/testtopic';
//   final builder = MqttClientPayloadBuilder();
//   builder.addString('Hello from mqtt_client');

//   /// Subscribe to it
//   debugPrint('EXAMPLE::Subscribing to the Dart/Mqtt_client/testtopic topic');
//   client.subscribe(pubTopic, MqttQos.exactlyOnce);

//   /// Publish it
//   debugPrint('EXAMPLE::Publishing our topic');
//   client.publishMessage(pubTopic, MqttQos.exactlyOnce, builder.payload!);

//   /// Ok, we will now sleep a while, in this gap you will see ping request/response
//   /// messages being exchanged by the keep alive mechanism.
//   debugPrint('EXAMPLE::Sleeping....');
//   await MqttUtilities.asyncSleep(60);

//   /// Finally, unsubscribe and exit gracefully
//   debugPrint('EXAMPLE::Unsubscribing');
//   client.unsubscribe(topic);

//   /// Wait for the unsubscribe message from the broker if you wish.
//   await MqttUtilities.asyncSleep(2);
//   debugPrint('EXAMPLE::Disconnecting');
//   client.disconnect();
//   debugPrint('EXAMPLE::Exiting normally');
//   return 0;
// }

// /// The subscribed callback
// void onSubscribed(String topic) {
//   debugPrint('EXAMPLE::Subscription confirmed for topic $topic');
// }

// /// The unsolicited disconnect callback
// void onDisconnected() {
//   debugPrint('EXAMPLE::OnDisconnected client callback - Client disconnection');
//   if (client.connectionStatus!.disconnectionOrigin ==
//       MqttDisconnectionOrigin.solicited) {
//     debugPrint(
//         'EXAMPLE::OnDisconnected callback is solicited, this is correct');
//   } else {
//     debugPrint(
//         'EXAMPLE::OnDisconnected callback is unsolicited or none, this is incorrect - exiting');
//     exit(-1);
//   }
//   if (pongCount == 3) {
//     debugPrint('EXAMPLE:: Pong count is correct');
//   } else {
//     debugPrint(
//         'EXAMPLE:: Pong count is incorrect, expected 3. actual $pongCount');
//   }
// }

// /// The successful connect callback
// void onConnected() {
//   debugPrint(
//       'EXAMPLE::OnConnected client callback - Client connection was successful');
// }

// /// Pong callback
// void pong() {
//   debugPrint('EXAMPLE::Ping response client callback invoked');
//   pongCount++;
// }

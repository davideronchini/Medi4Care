import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whatsapp_unilink/whatsapp_unilink.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late BluetoothConnection connection;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isListening = false;
  String _data = '';

  int distanceForward = 0;
  int distanceSide = 0;
  String side = 's';

  bool isFall = false;
  late LocationData _currentLocation;
  late bool _serviceEnabled;
  late PermissionStatus _permissionGranted;

  @override
  void initState() {
    super.initState();

    _getLocation();
  }

  @override
  void dispose() {
    if (_isConnected) connection.finish(); // Closing connection

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    if (width > height) height = width;

    // Listening data from Arduino
    if (!_isListening) {
      _getData(context);
    }

    return SafeArea(
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.only(
              top: 0.0, left: 0.05 * width, right: 0.05 * width, bottom: 0.0),
          physics: const BouncingScrollPhysics(),
          children: [
            Padding(
              padding: EdgeInsets.only(top: height * 0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: width * 0.15,
                    height: height * 0.05,
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      child: Image.asset(
                        'assets/icons/logo.png',
                        width: height * 0.05,
                        height: height * 0.05,
                      ),
                    ),
                  ),
                  Container(
                    width: width * 0.45,
                    height: height * 0.05,
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      child: Image.asset(
                        'assets/icons/title.png',
                        width: height * 0.15,
                        height: height * 0.05,
                      ),
                    ),
                  ),
                  Container(
                    width: width * 0.3,
                    height: height * 0.05,
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      child: FloatingActionButton(
                        onPressed: () {
                          _bluetoothConnectDevice();
                          setState(() => _isConnecting = true);
                        },
                        child: _isConnecting
                            ? Padding(
                                padding: EdgeInsets.all(height * 0.02),
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : Image.asset(
                                'assets/icons/power.png',
                                width: height * 0.045,
                                height: height * 0.045,
                              ),
                        backgroundColor: const Color(0xff0D858B),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0)),
                      ),
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: height * 0.08),
              child: Container(
                width: width * 0.8,
                height: height * 0.175,
                decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xff00B2CA))),
                alignment: Alignment.topLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(
                          top: height * 0.03, left: height * 0.03),
                      padding: EdgeInsets.all(height * 0.01),
                      height: height * 0.05,
                      width: height * 0.05,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        color: const Color(0xffA9E5ED),
                      ),
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/icons/arrow_up.png',
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(height * 0.03),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const FittedBox(
                            child: Text("Sensore distanza frontale: ",
                                style: TextStyle(
                                    fontFamily: 'Lato', fontSize: 16.0)),
                          ),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 3.0),
                                child: Text(
                                    (distanceForward * 0.01)
                                            .toStringAsFixed(2) +
                                        " mt",
                                    style: const TextStyle(
                                        fontFamily: 'Lato',
                                        fontSize: 14.0,
                                        color: Color(0xff6C6F7A))),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: height * 0.04),
              child: Container(
                width: width * 0.8,
                height: height * 0.175,
                decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xff00B2CA))),
                alignment: Alignment.topLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        _sendData(side == 's' ? 'd' : 's');

                        if (side == 's') {
                          setState(() => side = 'd');
                        } else {
                          setState(() => side = 's');
                        }
                      },
                      child: Container(
                        margin: EdgeInsets.only(
                            top: height * 0.03, left: height * 0.03),
                        padding: EdgeInsets.all(height * 0.01),
                        height: height * 0.05,
                        width: height * 0.05,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.0),
                          color: const Color(0xffA9E5ED),
                        ),
                        alignment: Alignment.center,
                        child: Transform.rotate(
                          angle: side == 's' ? -44.7 : 44.7,
                          child: Image.asset(
                            'assets/icons/arrow_up.png',
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(height * 0.03),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const FittedBox(
                            child: Text("Sensore distanza laterale: ",
                                style: TextStyle(
                                    fontFamily: 'Lato', fontSize: 16.0)),
                          ),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 3.0),
                                child: Text(
                                    (distanceSide * 0.01).toStringAsFixed(2) +
                                        " mt",
                                    style: const TextStyle(
                                        fontFamily: 'Lato',
                                        fontSize: 14.0,
                                        color: Color(0xff6C6F7A))),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: height * 0.04),
              child: Container(
                width: width * 0.8,
                height: height * 0.095,
                decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xff00B2CA))),
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(height * 0.03),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const FittedBox(
                        child: Text("Sensore caduta: ",
                            style:
                                TextStyle(fontFamily: 'Lato', fontSize: 16.0)),
                      ),
                      Image.asset(
                        'assets/icons/danger.png',
                        width: height * 0.045,
                        height: height * 0.045,
                        color: isFall
                            ? const Color(0xffFFA500)
                            : const Color(0xff6C6F7A),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _bluetoothConnectDevice() async {
    if (!_isConnected) {
      try {
        await BluetoothConnection.toAddress('98:D3:31:70:91:B7')
            .then((_connection) {
          // Connected to the device
          setState(() {
            connection = _connection;
            _isConnected = true;
            _isConnecting = false;
          });
          _showToast(context, "Connected", true);
        });
      } catch (exception) {
        // Ignore error
        // Cannot connect, exception occured
        setState(() {
          _isConnected = false;
          _isConnecting = false;
        });
        _showToast(context, "Connection Failed", false);
      }
    } else if (!connection.isConnected) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
      _showToast(context, "Disconnected", false);
    } else {
      try {
        // Closing connection
        connection.finish().whenComplete(() {
          setState(() {
            _isConnected = false;
            _isConnecting = false;
          });

          _showToast(context, "Disconnected", false);
        });
      } catch (e) {
        setState(() => _isConnecting = false);
        _showToast(context, "Disconnection Failed", false);
      }
    }
  }

  Future<void> _sendData(String text) async {
    if (_isConnected) {
      try {
        connection.output.add(ascii.encode(text));
        await connection.output.allSent;
      } catch (e) {
        // Ignore error
        if (!connection.isConnected) {
          // Notify state
          setState(() => _isConnected = false);
        }
      }
    }
  }

  void _getData(BuildContext context) {
    if (_isConnected) {
      try {
        setState(() => _isListening = true);
        connection.input!.listen((Uint8List data) {
          String value = ascii.decode(data).toString();

          if (value != '0' || value != ' ') {
            _data += value;

            if (_data.contains('f')) {

              // gets location details
              double? latitude = 0.0;
              double? longitude = 0.0;
              if (_serviceEnabled &&
                  _permissionGranted == PermissionStatus.granted) {
                latitude = _currentLocation.latitude;
                longitude = _currentLocation.longitude;
              }

              if (latitude != 0.0 && longitude != 0.0) {
                _sendWhatAppMessage(context,
                    "Aiuto! Sono caduto. Per sapere dove mi trovo inserisci queste cordinate su google maps: $latitude,$longitude");
              } else {
                _sendWhatAppMessage(context,
                    "Aiuto! Sono caduto. Mi dispiace ma non riesco a mandarti la posizione");
              }

              setState(() {
                _data = '';
                isFall = true;
              });
            } else if (_data.contains(';') && _data.split(';').length > 1) {

              _data = _data.split(';')[0]; // remove the ";"
              setState(() {
                distanceForward = int.parse(_data.split(',')[0]);
                distanceSide = int.parse(_data.split(',')[1]);
                _data = '';
              });
            } else {
              setState(() => _data = '');
            }
          }
        }).onDone(() {
          //print('debug: Disconnected by remote request');
          setState(() {
            _isListening = false;
            _data = '';
          });
          _showToast(context, "Disconnected", false);
        });
      } catch (exception) {
        //print('debug: Cannot connect, exception occured');
        setState(() {
          _isListening = false;
          _data = '';
        });
        _showToast(context, "Disconnected", false);
      }
    }
  }

  void _showToast(BuildContext context, String text, bool isPositive) {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(text),
          action: SnackBarAction(
              label: isPositive ? '✅' : '❌',
              textColor: Colors.white,
              onPressed: scaffold.hideCurrentSnackBar),
        ),
      );
    } catch (exception) {}
  }

  void _getLocation() async {
    Location location = Location();

    // checks serviceEnabled
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    // Asks for permission
    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _currentLocation = await location.getLocation();
  }

  void _sendWhatAppMessage(BuildContext context, String text) async {
    String phoneNumber = "+39-(342)1964045";
    final link = WhatsAppUnilink(
      phoneNumber: phoneNumber,
      text: text,
    );
    await launch('$link').onError((error, stackTrace) {
      _showToast(context, "Cannot send the message", false);
      return false;
    }).whenComplete(() => _showToast(context, "Message sent correctly", true));
  }
}

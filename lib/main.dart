import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'flutter_blue_app.dart';

void main() {
//  runApp(BluetoothApp());
  runApp(FlutterBlueApp());
}

class BluetoothApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StreamBuilder<BluetoothState>(
        stream: FlutterBlue.instance.state,
        initialData: BluetoothState.unknown,
        builder: (c, snapshot) {
          final state = snapshot.data;
          if(state == BluetoothState.on) {
            return MyHomePage(title: 'Flutter BLE Demo');
          } else {
            return BluetoothOffScreen(state: state);
          }
        })
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key key, this.state}) : super(key: key);

  final BluetoothState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state != null ? state.toString().substring(15) : 'not available'}.',
              style: Theme.of(context)
                  .primaryTextTheme
                  .subtitle1
                  .copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  final List<BluetoothDevice> devicesList = new List<BluetoothDevice>();
  final Map<Guid, List<int>> readValues = new Map<Guid, List<int>>();

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  BluetoothDevice _connectedDevice;
  List<BluetoothService> _services;
  final _writeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('Console Message Using Print');

    widget.flutterBlue.connectedDevices
    .asStream().listen((List<BluetoothDevice> devices) {
      for(BluetoothDevice device in devices) {
        _addDeviceToList(device);
        print('Flutter bluetooth : Connected devices');
      }
    });
    widget.flutterBlue.scanResults.listen((List<ScanResult> results) {
      for(ScanResult result in results) {
        _addDeviceToList(result.device);
        print('Flutter bluetooth : scan results '+result.device.toString());
      }
    });
    widget.flutterBlue.startScan();
  }

  _addDeviceToList(final BluetoothDevice device) {
    if (!widget.devicesList.contains(device)) {
      setState(() {
        widget.devicesList.add(device);
      });
    }
  }

  ListView _buildListViewOfDevices() {
    List<Container> containers = new List<Container>();
    for(BluetoothDevice device in widget.devicesList) {
      containers.add(
        Container(
          height: 50,
          child: Row(
            children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  Text(device.name == "" ? '(unknown device)' : device.name)
                ],
              ),
            ),
            FlatButton(
              color: Colors.blue,
              child: Text(
                'Connect',
                style: TextStyle(color: Colors.white)
              ),
              onPressed: () async {
                widget.flutterBlue.stopScan();
                try {
                  await device.connect(timeout: Duration(seconds: 60), autoConnect: true);
                } catch (e) {
                  if (e.code != 'already_connected') {
                    throw e;
                  }
                } finally {
                  _services = await device.discoverServices();
                }
                setState(() {
                  _connectedDevice = device;
                });
              },
            )
            ],
          ),
        )
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers
      ],
    );
  }

  ListView _buildView() {
    if (_connectedDevice != null) {
      return _buildConnectDeviceView();
    }
    return _buildListViewOfDevices();
  }

  ListView _buildConnectDeviceView() {
    List<Container> containers = new List<Container>();
    for(BluetoothService service in _services) {
      List<Widget> characteristicsWidgets = new List<Widget>();
      for(BluetoothCharacteristic characteristic in service.characteristics) {
        characteristic.value.listen((value) {
          print(value);
        });
        characteristicsWidgets.add(
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      characteristic.uuid.toString(),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    )
                  ],
                ),
                Row(
                  children: <Widget>[
                    ..._buildReadWriteNotifyButton(characteristic),
                  ],
                ),
                Row(
                  children: <Widget>[
                    Text('Value: ' +
                        widget.readValues[characteristic.uuid].toString()),
                  ],
                ),
                Divider(),
              ],
            ),
          )
        );
        containers.add(
          Container(
            child: ExpansionTile(
                title: Text(service.uuid.toString()),
                children: characteristicsWidgets),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          ...containers,
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[],
    );
  }

  List<ButtonTheme> _buildReadWriteNotifyButton(BluetoothCharacteristic characteristic) {
    List<ButtonTheme> buttons = new List<ButtonTheme>();
    if(characteristic.properties.read) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RaisedButton(
              color: Colors.blue,
              child: Text('READ', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                var sub = characteristic.value.listen((value) {
                  setState(() {
                    widget.readValues[characteristic.uuid] = value;
                  });
                });
                await characteristic.read();
                sub.cancel();
              },
            ),
          ),
        )
      );
    }
    if(characteristic.properties.write) {
      buttons.add(
          ButtonTheme(
            minWidth: 10,
            height: 20,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: RaisedButton(
                color: Colors.blue,
                child: Text('WRITE', style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text("Write"),
                          content: Row(
                            children: <Widget>[
                              Expanded(
                                child: TextField(
                                  controller: _writeController,
                                ),
                              ),
                            ],
                          ),
                          actions: <Widget>[
                            FlatButton(
                              child: Text("Send"),
                              onPressed: () {
                                characteristic.write(utf8
                                    .encode(_writeController.value.text));
                                Navigator.pop(context);
                              },
                            ),
                            FlatButton(
                              child: Text("Cancel"),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        );
                      });
                },
              ),
            ),
          )
      );
    }
    if(characteristic.properties.notify) {
      buttons.add(
          ButtonTheme(
            minWidth: 10,
            height: 20,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: RaisedButton(
                color: Colors.blue,
                child: Text('NOTIFIY', style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  characteristic.value.listen((value) {
                    widget.readValues[characteristic.uuid] = value;
                  });
                  await characteristic.setNotifyValue(true);
                },
              ),
            ),
          )
      );
    }
    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _buildView()
     );
  }
}
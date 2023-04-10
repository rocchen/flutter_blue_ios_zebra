import 'package:flutter/services.dart';

class FlutterBlueIosZebra {
  static const MethodChannel _channel = MethodChannel('com.jax.flutter_blue_ios_zebra');


  Future<String?> getPlatformVersion() async {
    final version = await _channel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  Future<bool> writeText(String printer, List<String> data) async {
    Map<String, String> map =  {};
    map.putIfAbsent("printer", () => printer);
    map.putIfAbsent("length", () => data.length.toString());
    for (int idx = 0; idx < data.length; idx++) {
      map.putIfAbsent("data$idx", () => data[idx]);
    }
    try {
      return  await _channel.invokeMethod("writeText", map);
    } on PlatformException catch (e) {
      throw UnimplementedError('writeText() has not been implemented.${e.message}');
    }
  }
  Future<void> list() async {
    await _channel.invokeMethod('list');
  }

  Future<Map<dynamic, dynamic>> getDriverList() async {
    var result = await _channel.invokeMethod("getDriverList");
    return Map<dynamic, dynamic>.from(result);
  }

  Future<void> dispose() async {
    await _channel.invokeMethod('unregis');
  }
  static FlutterBlueIosZebra? _instance;
  FlutterBlueIosZebra._internal() {
    // initialization and stuff
    _channel.invokeMethod('regis');
  }

  static FlutterBlueIosZebra get instance {
    _instance ??= FlutterBlueIosZebra._internal();
    return _instance!;
  }
}

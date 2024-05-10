import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal_windows.dart';

class PrintBluetoothThermal {
  static const MethodChannel _channel = MethodChannel('groons.web.app/print');

  // Private constructor
  PrintBluetoothThermal._privateConstructor();

  // Static private instance of the class
  static final PrintBluetoothThermal _instance =
      PrintBluetoothThermal._privateConstructor();

  // Public static getter for the instance
  static PrintBluetoothThermal get instance => _instance;

  // Flag to check if initialized
  bool _isInitialized = false;

  // Public method to initialize Bluetooth connection
  Future<void> initializeBluetooth() async {
    if (!_isInitialized) {
      try {
        final String result =
            await _channel.invokeMethod('initializeBluetooth');
        print(result); // Should print "Bluetooth central manager initialized"
        _isInitialized = true;
      } on PlatformException catch (e) {
        print("Failed to initialize Bluetooth: '${e.message}'.");
      }
    }
  }

  ///Check if it is allowed on Android 12 access to Bluetooth onwards
  Future<bool> isPermissionBluetoothGranted() async {
    // Ensure initialization before proceeding
    await _ensureInitialized();
    //bluetooth esta disponible?
    bool bluetoothState = false;
    if (Platform.isWindows) {
      return true;
    } else if (Platform.isAndroid || Platform.isIOS) {
      bluetoothState =
          await _channel.invokeMethod('ispermissionbluetoothgranted');
    }

    return bluetoothState;
  }

  // Add _ensureInitialized method to wrap calls that require Bluetooth to be initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initializeBluetooth();
    }
  }

  ///returns true if bluetooth is on
  Future<bool> bluetoothEnabled() async {
    //bluetooth esta prendido?
    bool bluetoothState = false;
    if (Platform.isWindows) {
      return true;
    } else if (Platform.isAndroid || Platform.isIOS) {
      bluetoothState = await _channel.invokeMethod('bluetoothenabled');
    }

    return bluetoothState;
  }

  ///Android: Return all paired bluetooth on the device IOS: Return nearby bluetooths
  Future<List<BluetoothInfo>> pairedBluetooths() async {
    await _ensureInitialized();
    //bluetooth vinculados
    List<BluetoothInfo> items = [];
    if (Platform.isWindows) {
      items = await PrintBluetoothThermalWindows.getPariedBluetoohts();
    } else if (Platform.isAndroid || Platform.isIOS) {
      final List result = await _channel.invokeMethod('pairedbluetooths');
      //print("llego: $result");
      for (String item in result) {
        List<String> info = item.split("#");
        String name = info[0];
        String mac = info[1];
        items.add(BluetoothInfo(name: name, macAdress: mac));
      }
    }

    return items;
  }

  //returns true if you are currently connected to the printer
  Future<bool> get connectionStatus async {
    await _ensureInitialized();
    //estado de la conexion eon el bluetooth
    if (Platform.isWindows) {
      return PrintBluetoothThermalWindows.connectionStatus;
    } else {
      final bool result = await _channel.invokeMethod('connectionstatus');
      //print("llego: $result");
      return result;
    }
  }

  ///send connection to ticket printer and wait true if it was successful, the mac address of the printer's bluetooth must be sent
  Future<bool> connect({required String macPrinterAddress}) async {
    await _ensureInitialized();
    //conectar impresora bluetooth
    bool result = false;

    String mac = macPrinterAddress; //"66:02:BD:06:18:7B";
    if (Platform.isWindows) {
      result = await PrintBluetoothThermalWindows.connect(macAddress: mac);
    } else {
      result = await _channel.invokeMethod('connect', mac);
    }
    return result;
  }

  ///send bytes to print, esc_pos_utils_plus package must be used, returns true if successful
  Future<bool> writeBytes(List<int> bytes) async {
    await _ensureInitialized();
    //enviar bytes a la impresora
    if (Platform.isWindows) {
      return await PrintBluetoothThermalWindows.writeBytes(bytes: bytes);
    } else {
      return await _channel.invokeMethod('writebytes', bytes);
    }
  }

  ///Strings are sent to be printed by the PrintTextSize class can print from size 1 (50%) to size 5 (400%)
  Future<bool> writeString({required PrintTextSize printText}) async {
    await _ensureInitialized();

    ///EN: you must send the enter \n to print the complete phrase, it is not sent automatically because you may want to add several
    /// horizontal values ​​of different size
    ///ES: se debe enviar el enter \n para que imprima la frase completa, no se envia automatico por que tal vez quiera agregar varios
    ///valores horizontales de diferente tamaño
    int size = printText.size <= 5 ? printText.size : 2;
    String text = printText.text;

    String textFinal = "$size///$text";

    if (Platform.isAndroid || Platform.isIOS) {
      return await _channel.invokeMethod('printstring', textFinal);
    } else {
      throw UnimplementedError(
          "This functionality is not yet implemented. Please use the writeBytes option.");
    }
  }

  ///gets the android version where it is running, returns String
  Future<String> get platformVersion async {
    String version = "";
    if (Platform.isAndroid || Platform.isIOS) {
      version = await _channel.invokeMethod('getPlatformVersion');
    }
    return version;
  }

  ///get the percentage of the battery returns int
  Future<int> get batteryLevel async {
    int result = 0;

    if (Platform.isWindows) {
    } else if (Platform.isAndroid || Platform.isIOS) {
      result = await _channel.invokeMethod('getBatteryLevel');
    }
    return result;
  }

  ///disconnect print
  Future<bool> get disconnect async {
    await _ensureInitialized();
    if (Platform.isWindows) {
      return await PrintBluetoothThermalWindows.disconnect();
    }
    return await _channel.invokeMethod('disconnect');
  }
}

class BluetoothInfo {
  late String name;
  late String macAdress;
  BluetoothInfo({
    required this.name,
    required this.macAdress,
  });
}

class PrintTextSize {
  ///min size 1 max 5, if the size is different to the range it will be 2
  late int size;
  late String text;

  PrintTextSize({
    required this.size,
    required this.text,
  });
}

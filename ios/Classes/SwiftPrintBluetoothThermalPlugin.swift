import Flutter
import UIKit
import CoreBluetooth

public class SwiftPrintBluetoothThermalPlugin: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate,  FlutterPlugin {
    var centralManager: CBCentralManager?  // Define una variable para guardar el gestor central de bluetooth
    var discoveredDevices: [String] = []  //lista de bluetooths encontrados
    var connectedPeripheral: CBPeripheral!  //dispositivo conectado
    var targetService: CBService? // Variable global para el servicio objetivo
    //var characteristics: [CBCharacteristic] = [] // Variable global para almacenar las características encontradas
    var targetCharacteristic: CBCharacteristic? // Variable global para almacenar la característica objetivo


    var flutterResult: FlutterResult? //para el resul de flutter
    var stringprint = ""; //variable para almacenar los string que llegan

    // Fragmentos de escritura BLE pendientes y el tipo con el que deben
    // enviarse. Un envío no puede lanzar todos los fragmentos seguidos: sin
    // esperar la confirmación (.withResponse) o el hueco de envío
    // (.withoutResponse) el buffer de entrada de la impresora se satura y el
    // recibo sale como caracteres aleatorios.
    var writeQueue: [Data] = []
    var pendingWriteType: CBCharacteristicWriteType = .withoutResponse

    // En el método init, inicializa el gestor central con un delegado
    //para solicitar el permiso del bluetooth
    override init() {
        super.init()
    }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "groons.web.app/print", binaryMessenger: registrar.messenger())
    let instance = SwiftPrintBluetoothThermalPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // En el método init, inicializa el gestor central con un delegado
    //para solicitar el permiso del bluetooth
    if (self.centralManager == nil) {
        self.centralManager = CBCentralManager(delegate: self, queue: nil, options: ["CBCentralManagerOptionShowPowerAlertKey": 0])
    }

    //para iniciar la variable result
    self.flutterResult = result
    //result("iOS " + UIDevice.current.systemVersion)
    //let argumento = call.arguments as! String //leer el argumento recibido
    if call.method == "getPlatformVersion" { // Verifica si se está llamando el método "getPlatformVersion"
      let iosVersion = UIDevice.current.systemVersion // Obtiene la versión de iOS
      result("iOS " + iosVersion) // Devuelve el resultado como una cadena de texto
    } else if call.method == "getBatteryLevel" {
      let device = UIDevice.current
      let batteryState = device.batteryState
      let batteryLevel = device.batteryLevel * 100
      result(Int(batteryLevel))
    } else if call.method == "bluetoothenabled"{
      switch centralManager?.state {
      case .poweredOn:
          result(true)
      default:
          result(false)
      }
    } else if call.method == "ispermissionbluetoothgranted"{
      //let centralManager = CBCentralManager()
      if #available(iOS 10.0, *) {
        switch centralManager?.state {
        case .poweredOn:
          print("Bluetooth is on")
          result(true)
        default:
          print("Bluetooth is off")
          result(false)
        }
      }
    } else if call.method == "pairedbluetooths" {
      //print("buscando bluetooths");
      //let discoveredDevices = scanForBluetoothDevices(duration: 5.0)
      //print("Discovered devices: \(discoveredDevices)")
      switch centralManager?.state {
        case .unknown:
            //print("El estado del bluetooth es desconocido")
            break
        case .resetting:
            //print("El bluetooth se está reiniciando")
            break
        case .unsupported:
            //print("El bluetooth no es compatible con este dispositivo")
            break
        case .unauthorized:
            //print("El bluetooth no está autorizado para esta app")
            break
        case .poweredOff:
            //print("El bluetooth está apagado")
            centralManager?.stopScan()
        case .poweredOn:
            //print("El bluetooth está encendido")
            //Escanea todos los bluetooths disponibles
            centralManager?.scanForPeripherals(withServices: nil, options: nil)
            // Escanea todos los dispositivos Bluetooth vinculados
            centralManager?.retrieveConnectedPeripherals(withServices: [])
        @unknown default:
            //print("El estado del bluetooth es desconocido (default)")
            break
      }

        // despues de 5 segundos se para la busqueda y se devuelve la lista de dispositivos disponibles
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.centralManager?.stopScan()
            print("Stopped scanning -> Discovered devices: \(self.discoveredDevices.count)")
            result(self.discoveredDevices)
        }

    } 
    else if call.method == "connect"{
        let macAddress = call.arguments as! String 
        // Busca el dispositivo con la dirección MAC dada
        let peripherals = centralManager?.retrievePeripherals(withIdentifiers: [UUID(uuidString: macAddress)!])
        guard let peripheral = peripherals?.first else {
          //print("No se encontró ningún dispositivo con la dirección MAC \(macAddress)")
          result(false)
          return
        }

        // Intenta conectar con el dispositivo
        centralManager?.connect(peripheral, options: nil)

        // Verifica si la conexión fue exitosa después de un tiempo de espera
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if peripheral.state == .connected {
                //print("Conexión exitosa con el dispositivo \(peripheral.name ?? "Desconocido")")
                self.connectedPeripheral = peripheral

                self.connectedPeripheral.delegate = self
                // Discover services of the connected peripheral
                //se ejecuta los servicios descubiertos en primer peripheral
                self.connectedPeripheral?.discoverServices(nil)
                result(true)
            } else {
                //print("La conexión con el dispositivo \(peripheral.name ?? "Desconocido") falló")
                result(false)
            }
        }
  
    }else if call.method == "connectionstatus"{
      if connectedPeripheral?.state == CBPeripheralState.connected {
          //print("El dispositivo periférico está conectado.")
          result(true)
      } else {
          //print("El dispositivo periférico no está conectado.")
          result(false)
      }
    }else if call.method == "writebytes"{
        guard let listbytes = call.arguments as? [Int] else {
          // Manejar el caso en que los argumentos no son del tipo esperado
          result(false)
          return
        }
        guard let characteristic = targetCharacteristic, let peripheral = connectedPeripheral else {
            print("No hay caracteristica para imprimir")
            result(false)
            return
        }

        //Imprimir bloques de 150 bytes en la impresora para que no se sature
        let data = Data(listbytes.map { UInt8(truncatingIfNeeded: $0) })
        let chunkSize = 150 // Tamaño de cada fragmento en bytes

        writeQueue = stride(from: 0, to: data.count, by: chunkSize).map { offset in
            data.subdata(in: offset..<min(offset + chunkSize, data.count))
        }
        // Si la característica no admite escritura sin confirmación, cada
        // fragmento debe esperar su respuesta antes de enviar el siguiente.
        pendingWriteType = characteristic.properties.contains(.writeWithoutResponse)
            ? .withoutResponse
            : .withResponse

        if writeQueue.isEmpty {
            result(true)
            return
        }

        //la respuesta va en peripheral, ver sendNextChunk/didWriteValueFor/peripheralIsReady
        sendNextChunk(peripheral: peripheral, characteristic: characteristic)

      } else if call.method == "printstring"{
        self.stringprint = call.arguments as! String
        //print("llego a printstring\(self.stringprint)")
        if let characteristic = targetCharacteristic {
            if self.stringprint.count > 0 {
                    //ver el tamaño del texto
                    var size = 0
                    var texto = ""
                    let linea = self.stringprint.components(separatedBy: "///")
                    if linea.count > 1 {
                        size = Int(linea[0]) ?? 0
                        texto = String(linea[1])
                        if size < 1 || size > 5 {
                            size = 2
                        }
                    } else {
                        size = 2
                        texto = self.stringprint
                    }
                    let sizeBytes: [[UInt8]] = [
                                [0x1d, 0x21, 0x00], // La fuente no se agranda 0
                                [0x1b, 0x4d, 0x01], // Fuente ASCII comprimida 1
                                [0x1b, 0x4d, 0x00], //Fuente estándar ASCII    2
                                [0x1d, 0x21, 0x11], // Altura doblada 3
                                [0x1d, 0x21, 0x22], // Altura doblada 4
                                [0x1d, 0x21, 0x33] // Altura doblada 5
                            ]
                    let resetBytes: [UInt8] = [0x1b, 0x40]

                    // Envío de los datos
                    let datasize = Data(sizeBytes[size])

                    var writeType = CBCharacteristicWriteType.withoutResponse;
                    if characteristic.properties.contains(.write) {
                        writeType = CBCharacteristicWriteType.withResponse;
                    }

                    connectedPeripheral?.writeValue(datasize, for: characteristic, type: writeType)

                    let data = Data(texto.utf8)
                    connectedPeripheral?.writeValue(data, for: characteristic, type: writeType)

                    // reseteo de la impresora
                    let datareset = Data(resetBytes)
                    connectedPeripheral?.writeValue(datareset, for: characteristic, type: writeType)
                    stringprint = ""

                    //la respuesta va en peripheral si es .withResponse
                    //self.flutterResult?(true)
                }
        } else {
            print("No hay caracteristica para imprimir")
            result(false)
        }
        } else if call.method == "disconnect"{
        centralManager?.cancelPeripheralConnection(connectedPeripheral)
        targetCharacteristic = nil
        writeQueue.removeAll()
        //la respuesta va en centralManager segunda funcion
        //result(true)
      } else {
        result(FlutterMethodNotImplemented) // Si se llama otro método que no está implementado, se devuelve un error
      }
  }

    // Pausa entre fragmentos, igual a kPrinterChunkPause en el lado Dart:
    // canSendWriteWithoutResponse/didWriteValueFor solo evitan que la cola
    // local de CoreBluetooth (o su cola GATT) se desborde, pero no dicen nada
    // del buffer físico de impresión de la impresora, que en modo imagen es
    // el cuello de botella real. Sin esta pausa, una ráfaga larga de
    // fragmentos (un recibo con imagen tiene decenas) puede quedar dentro de
    // la capacidad local y salir toda de golpe, desbordando la impresora a
    // mitad de un comando gráfico — la impresora sale del modo raster y
    // empieza a imprimir el resto de los bytes de la imagen como si fueran
    // texto, lo que se ve como caracteres aleatorios ("?", "=", letras
    // sueltas) en vez de una imagen corrupta.
    static let chunkPause: TimeInterval = 0.02

    // Envía el siguiente fragmento pendiente respetando el flujo de BLE:
    // con .withoutResponse solo si el peripheral tiene hueco de envío
    // (si no, se reanuda en peripheralIsReady(toSendWriteWithoutResponse:));
    // con .withResponse se envía uno y se espera didWriteValueFor antes del
    // siguiente. En ambos casos se espacía con chunkPause antes de continuar.
    func sendNextChunk(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        guard !writeQueue.isEmpty else {
            self.flutterResult?(true)
            return
        }
        if pendingWriteType == .withoutResponse && !peripheral.canSendWriteWithoutResponse {
            return
        }
        let chunk = writeQueue.removeFirst()
        peripheral.writeValue(chunk, for: characteristic, type: pendingWriteType)
        if pendingWriteType == .withoutResponse {
            // CoreBluetooth no llama a didWriteValueFor para .withoutResponse.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.chunkPause) { [weak self] in
                self?.sendNextChunk(peripheral: peripheral, characteristic: characteristic)
            }
        }
        // Para .withResponse, el siguiente fragmento se envía desde didWriteValueFor.
    }


    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        //print("Discovered \(peripheral.name ?? "Unknown") at \(RSSI) dBm")
        if let deviceName = peripheral.name {
            let deviceAddress = peripheral.identifier.uuidString
            //print("name \(deviceName) Address: \(deviceAddress)")
            let device = "\(deviceName)#\(deviceAddress)"
            if !discoveredDevices.contains(device) {
                discoveredDevices.append(device)
            }
        }
    }

    //funcion para verificar si desconecto el dispositivo
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if error != nil {
            //print("Error al desconectar del dispositivo: \(error!.localizedDescription)")
            self.flutterResult?(false)
        } else {
        //print("Se ha desconectado del dispositivo con éxito")
         self.flutterResult?(true)
        }
    }

     //detectar los servicios descubiertos y guardarlo para poder imprimir
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
           if let error = error {
               print("Error discovering services: \(error.localizedDescription)")
               return
           }

           if let services = peripheral.services {
               for service in services {
                   print("Service discovered: \(service.uuid)")
                   let allowedServices = [
                        CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB"),
                        CBUUID(string: "49535343-FE7D-4AE5-8FA9-9FAFD205E455"),
                        CBUUID(string: "A76EB9E0-F3AC-4990-84CF-3A94D2426B2B")
                   ]

                   if allowedServices.contains(service.uuid) {
                       print("Service found: \(service.uuid)") 
                       // Por ejemplo, puedes descubrir las características del servicio
                       peripheral.discoverCharacteristics(nil, for: service)

                       // También puedes almacenar el servicio en una variable para futuras referencias
                       // targetService = service
                       self.targetService = service;
                   }

                   // Aquí puedes realizar operaciones adicionales con cada servicio encontrado, como descubrir características
                   peripheral.discoverCharacteristics(nil, for: service)
               }
           }
    }

    // Implementación del método peripheral(_:didDiscoverCharacteristicsFor:error:) para buscar las caracteristicas del dispositivo bluetooth
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }

        if let discoveredCharacteristics = service.characteristics {
            for characteristic in discoveredCharacteristics {
                //print("characteristics found: \(characteristic.uuid)")
            
                let allowedCharacteristics = [
                    CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB"), 
                    CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3"), 
                    CBUUID(string: "A76EB9E2-F3AC-4990-84CF-3A94D2426B2B")
                ]

                if allowedCharacteristics.contains(characteristic.uuid) {
                    targetCharacteristic = characteristic // Guarda la característica objetivo en la variable global
                    print("Target characteristic found: \(characteristic.uuid)")
                 
                    if characteristic.properties.contains(.write) {
                        // La característica admite escritura
                        print("characteristics found: \(characteristic.uuid) La característica admite escritura")
                    } else {
                        // La característica no admite escritura
                        print("characteristics found: \(characteristic.uuid) La característica no admite escritura")
                    }
                    break
                }
            }
        }
    }

    // Implementación del método peripheral(_:didWriteValueFor:error:) para saber si la impresion fue exitosa si se pasa .withResponse
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
           print("Error al escribir en la característica: \(error.localizedDescription)")
            writeQueue.removeAll()
            self.flutterResult?(false)
           return
        }
        if pendingWriteType == .withResponse && !writeQueue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.chunkPause) { [weak self] in
                self?.sendNextChunk(peripheral: peripheral, characteristic: characteristic)
            }
            return
        }
         self.flutterResult?(true)
        print("Escritura exitosa en la característica: \(characteristic.uuid)")
        // Aquí puedes realizar operaciones adicionales con la respuesta de la escritura
    }

    // Se llama cuando vuelve a haber hueco para escrituras .withoutResponse;
    // reanuda el envío de la cola pausada en sendNextChunk.
    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        guard let characteristic = targetCharacteristic else { return }
        sendNextChunk(peripheral: peripheral, characteristic: characteristic)
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            case .poweredOn:
                // El bluetooth está encendido y listo para usar
                print("Bluetooth está encendido")
            case .poweredOff:
                // El bluetooth está apagado
                print("Bluetooth está apagado")
            case .resetting:
                // El bluetooth está reiniciándose
                print("Bluetooth está reiniciándose")
            case .unauthorized:
                // La app no tiene permiso para usar el bluetooth
                print("La app no tiene permiso para usar el bluetooth")
            case .unsupported:
                // El dispositivo no soporta el bluetooth
                print("El dispositivo no soporta el bluetooth")
            case .unknown:
                // El estado del bluetooth es desconocido
                print("El estado del bluetooth es desconocido")
            @unknown default:
                // Otro caso no esperado
                print("Otro caso no esperado")
        }
    }

}



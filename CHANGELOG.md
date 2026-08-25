## [1.1.8]
1. iOS BLE writeBytes: added a 20ms pause between chunks (like the rest of the app's transports) on top of the previous backpressure fix. canSendWriteWithoutResponse/didWriteValueFor only protect the local CoreBluetooth queue, not the printer's own print buffer, so a long burst (image-mode receipts have dozens of chunks) could still outrun the printer and desync a graphics command mid-transfer, making it fall back to printing the raw image bytes as text.

## [1.1.7]
1. Fixed iOS BLE writeBytes sending every chunk back-to-back with no backpressure, which overran the printer's input buffer and printed random characters. Chunks now wait for canSendWriteWithoutResponse/peripheralIsReady when the characteristic only supports writeWithoutResponse, or for didWriteValueFor when it supports write with response.

## [1.1.6]
1. Update Api v2 de flutter for Android
2. 2025/02/14

## [1.1.5]
1. Update desing new flutter
2. 2025/01/16

## [1.1.4]
1. Delete package web
2. update code pull request #52

## [1.1.3]

1. Update folder ios and update platform suport

## [1.1.2]

1. Updated to support the new Android versions in new Flutter projects.

## [1.1.1]

1. Update readme.md

## [1.1.0]

1. Add support for Windows print

## [1.0.9]

1. Update README.md

## [1.0.8]

1. Update README.md

## [1.0.7]

1. Added support for IOS
2. Updated the gradle version to 7.2.0
3. Kotlin version was updated to 1.8.0


## [1.0.6]

1. Fixed a bug that when validating bluetooth permission on devices with android sdk less than 31 showed false, and it should be true since those devices do not need the access permission to nearby devices

## [1.0.5]

1. Fixed an error that in versions of android with decimals, for example android 7.1.1, did not work.

## [1.0.3]

1. Added support for android 12
2. Added BLUETOOTH_CONNECT permission for android 12 onwards
3. Added isPermissionBluetoothGranted function to detect if permission is enabled, works only on android 12 and up
4. Changed Kotlin from 1.3.50 to 1.6.10

## [1.0.2]

Added a method to disconnect the printer

## [1.0.1]

Shareability with null security was added and all methods were changed to English.
if you want to migrate to this version you must read the README.md file

## [1.0.0]

Shareability with null security was added and all methods were changed to English.
if you want to migrate to this version you must read the README.md file

## [0.0.8]

Se cambio el modo de separar el tamaño en texto personalizado por (//) antes (/)

## [0.0.7]

Se agrego que ahora se detecta el estado del bluetooth getBluetoothState

## [0.0.6]

Se agrego que ahora se detecta claramente el estado de la conexion

## [0.0.5]

Se agrego la opcion de detectar la conexion de la impresora con el metodo estadoConexion

## [0.0.4]

Se agrego que la el metodo getNivelbateria retorne un int

## [0.0.3]

cambio del contexto para no causar conflictos con otros paquetes

## [0.0.2]

# print_bluetooth_thermal

Se cambio de dart a pluning


import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart';

enum BleEstado { desconectado, conectando, conectado }

/// Maneja TODA la conexión con la banda respiratoria (ESP32) por
/// Web Bluetooth. Es un singleton: la conexión se mantiene mientras
/// se navega entre pantallas y se cambia de paciente.
///
/// Protocolo del ESP32 (texto por notificaciones):
///   `F:<int>`    -> frecuencia respiratoria (rpm)  -> [frStream]
///   `V:<double>` -> punto de la señal respiratoria -> [senalStream]
class BleService extends ChangeNotifier {
  BleService._();
  static final BleService instance = BleService._();

  static const String serviceUUID = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String characteristicUUID =
      'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  /// Reintentos automáticos si el ESP32 se desconecta solo.
  static const int maxReintentos = 10;
  static const Duration esperaReintento = Duration(seconds: 3);

  BleEstado _estado = BleEstado.desconectado;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<bool>? _conexionSub;
  StreamSubscription<ByteData>? _datosSub;
  Timer? _timerReintento;
  int _reintento = 0;
  bool _desconexionManual = false;
  String? _ultimoError;

  final StreamController<int> _frController =
      StreamController<int>.broadcast();
  final StreamController<double> _senalController =
      StreamController<double>.broadcast();

  BleEstado get estado => _estado;
  bool get conectado => _estado == BleEstado.conectado;

  /// true mientras se intenta recuperar una conexión que se cayó sola.
  bool get reconectando =>
      _estado == BleEstado.conectando && _reintento > 0;
  int get reintento => _reintento;

  String? get nombreDispositivo {
    final d = _device;
    if (d == null) return null;
    final n = d.name;
    return (n == null || n.isEmpty) ? d.id : n;
  }

  String? get ultimoError => _ultimoError;

  /// Frecuencia respiratoria (rpm) recibida del ESP32.
  Stream<int> get frStream => _frController.stream;

  /// Puntos de la señal respiratoria para la gráfica.
  Stream<double> get senalStream => _senalController.stream;

  Future<bool> soportado() async {
    try {
      return await FlutterWebBluetooth.instance.isAvailable.first;
    } catch (_) {
      return false;
    }
  }

  /// Abre el selector del navegador y conecta. Si ya está conectado no
  /// hace nada. Debe llamarse desde un toque del usuario (requisito de
  /// Web Bluetooth). Devuelve true si quedó conectado.
  Future<bool> conectar() async {
    if (_estado != BleEstado.desconectado) return conectado;

    _ultimoError = null;

    if (!await soportado()) {
      _ultimoError =
          'Tu navegador no soporta Web Bluetooth (usa Chrome o Edge).';
      notifyListeners();
      return false;
    }

    _setEstado(BleEstado.conectando);

    try {
      final device = await FlutterWebBluetooth.instance.requestDevice(
        RequestOptionsBuilder([
          RequestFilterBuilder(services: [serviceUUID]),
        ]),
      );

      // Si se eligió otro dispositivo, se suelta el anterior.
      if (_device != null && _device!.id != device.id) {
        await _limpiarDispositivo(desconectar: true);
      }

      _device = device;
      _desconexionManual = false;
      _reintento = 0;
      await _conectarDispositivo();
      return true;
    } catch (e) {
      debugPrint('BLE: error al conectar: $e');
      // UserCancelledDialogError no se exporta en la API pública del
      // paquete; su toString() empieza con el nombre del error.
      _ultimoError = e.toString().startsWith('UserCancelledDialogError')
          ? 'Conexión cancelada.'
          : 'No se pudo conectar con la banda.';
      _setEstado(BleEstado.desconectado);
      return false;
    }
  }

  /// Desconexión pedida por el usuario: no se reintenta.
  Future<void> desconectar() async {
    _desconexionManual = true;
    _timerReintento?.cancel();
    _reintento = 0;
    await _limpiarDispositivo(desconectar: true);
    _device = null;
    _setEstado(BleEstado.desconectado);
  }

  // ---------------------------------------------------------------------

  Future<void> _conectarDispositivo() async {
    final device = _device!;

    await device.connect(timeout: const Duration(seconds: 10));

    final services = await device.discoverServices();
    final service = services.firstWhere((s) => s.uuid == serviceUUID);
    final characteristic = await service.getCharacteristic(characteristicUUID);

    await _datosSub?.cancel();
    _characteristic = characteristic;
    await characteristic.startNotifications();
    _datosSub = characteristic.value.listen(_procesarDatos);

    // Vigilar caídas de conexión (una sola suscripción por dispositivo).
    _conexionSub ??= device.connected.listen(_onCambioConexion);

    _reintento = 0;
    _timerReintento?.cancel();
    _setEstado(BleEstado.conectado);
  }

  void _procesarDatos(ByteData data) {
    final texto = utf8.decode(data.buffer.asUint8List()).trim();

    if (texto.startsWith('V:')) {
      final valor = double.tryParse(texto.substring(2));
      if (valor != null) _senalController.add(valor);
    } else if (texto.startsWith('F:')) {
      final fr = int.tryParse(texto.substring(2));
      if (fr != null && fr > 0) _frController.add(fr);
    }
  }

  void _onCambioConexion(bool estaConectado) {
    if (estaConectado || _desconexionManual) return;
    if (_estado != BleEstado.conectado) return;

    debugPrint('BLE: el dispositivo se desconectó solo. Reintentando...');
    _datosSub?.cancel();
    _datosSub = null;
    _characteristic = null;
    _reintento = 0;
    _programarReintento();
  }

  void _programarReintento() {
    if (_desconexionManual || _device == null) return;

    if (_reintento >= maxReintentos) {
      debugPrint('BLE: se agotaron los reintentos.');
      _ultimoError =
          'Se perdió la conexión con la banda. Vuelve a conectarla.';
      _reintento = 0;
      _setEstado(BleEstado.desconectado);
      return;
    }

    _reintento++;
    _setEstado(BleEstado.conectando);

    _timerReintento?.cancel();
    _timerReintento = Timer(esperaReintento, () async {
      if (_desconexionManual || _device == null) return;
      try {
        await _conectarDispositivo();
        debugPrint('BLE: reconectado.');
      } catch (e) {
        debugPrint('BLE: reintento $_reintento falló: $e');
        _programarReintento();
      }
    });
  }

  Future<void> _limpiarDispositivo({required bool desconectar}) async {
    await _datosSub?.cancel();
    _datosSub = null;
    await _conexionSub?.cancel();
    _conexionSub = null;

    try {
      await _characteristic?.stopNotifications();
    } catch (_) {}
    _characteristic = null;

    if (desconectar) {
      try {
        _device?.disconnect();
      } catch (_) {}
    }
  }

  void _setEstado(BleEstado nuevo) {
    _estado = nuevo;
    notifyListeners();
  }
}

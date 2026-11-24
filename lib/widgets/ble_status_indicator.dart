import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

import '../screens/bluetooth_screen.dart';
import '../services/ble_service.dart';

/// Indicador pequeño para el AppBar: punto verde = conectado,
/// ámbar = conectando/reconectando, gris = desconectado.
/// Al tocarlo abre la pantalla "Conexión Bluetooth".
class BleStatusIndicator extends StatelessWidget {
  const BleStatusIndicator({super.key});

  static Color colorDe(BleEstado estado) {
    switch (estado) {
      case BleEstado.conectado:
        return const Color(0xFF20A86B);
      case BleEstado.conectando:
        return const Color(0xFFF5A524);
      case BleEstado.desconectado:
        return Colors.grey;
    }
  }

  static String textoDe(BleService ble) {
    switch (ble.estado) {
      case BleEstado.conectado:
        return 'Banda conectada';
      case BleEstado.conectando:
        return ble.reconectando ? 'Reconectando...' : 'Conectando...';
      case BleEstado.desconectado:
        return 'Banda desconectada';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ble = BleService.instance;

    return ListenableBuilder(
      listenable: ble,
      builder: (context, _) {
        return Tooltip(
          message: '${textoDe(ble)} · Toca para ver la conexión',
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BluetoothScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ble.conectado
                        ? AppIcons.bluetoothConnected
                        : AppIcons.bluetooth,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colorDe(ble.estado),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

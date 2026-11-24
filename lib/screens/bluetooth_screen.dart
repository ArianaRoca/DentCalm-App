import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ble_status_indicator.dart';
import '../widgets/ui.dart';

class BluetoothScreen extends StatelessWidget {
  const BluetoothScreen({super.key});

  Future<void> _conectar(BuildContext context) async {
    final ble = BleService.instance;
    final ok = await ble.conectar();
    if (!ok && ble.ultimoError != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ble.ultimoError!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ble = BleService.instance;

    return AppBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Conexión Bluetooth',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: const [ThemeToggleButton(), SizedBox(width: 10)],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListenableBuilder(
                listenable: ble,
                builder: (context, _) {
                  final color = BleStatusIndicator.colorDe(ble.estado);
                  final conectando = ble.estado == BleEstado.conectando;

                  return FadeInSlide(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: color, width: 3),
                              ),
                              child: conectando
                                  ? Padding(
                                      padding: const EdgeInsets.all(30),
                                      child: CircularProgressIndicator(
                                        color: color,
                                      ),
                                    )
                                  : Icon(
                                      ble.conectado
                                          ? AppIcons.bluetoothConnected
                                          : AppIcons.bluetoothSlash,
                                      size: 52,
                                      color: color,
                                    ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              BleStatusIndicator.textoDe(ble),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            if (ble.reconectando) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Intento ${ble.reintento} de ${BleService.maxReintentos}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                            const SizedBox(height: 25),
                            _Fila(
                              icon: AppIcons.broadcast,
                              titulo: 'Dispositivo',
                              valor: ble.nombreDispositivo ?? 'Ninguno',
                            ),
                            _Fila(
                              icon: AppIcons.info,
                              titulo: 'Estado',
                              valor: switch (ble.estado) {
                                BleEstado.conectado => 'Conectado',
                                BleEstado.conectando => 'Conectando',
                                BleEstado.desconectado => 'Desconectado',
                              },
                            ),
                            if (ble.ultimoError != null &&
                                ble.estado == BleEstado.desconectado)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  ble.ultimoError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 25),
                            Text(
                              'La banda queda conectada aunque cambies de '
                              'paciente o de pantalla. Si se aleja o se apaga, '
                              'la app intenta reconectarla sola.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 25),
                            Row(
                              children: [
                                Expanded(
                                  child: PrimaryButton(
                                    onPressed:
                                        ble.estado == BleEstado.desconectado
                                        ? () => _conectar(context)
                                        : null,
                                    icon: AppIcons.bluetooth,
                                    label: 'Conectar',
                                    padding: const EdgeInsets.all(18),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        ble.estado == BleEstado.desconectado
                                        ? null
                                        : ble.desconectar,
                                    icon: const Icon(AppIcons.bluetoothSlash),
                                    label: const Text('Desconectar'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.danger,
                                      padding: const EdgeInsets.all(18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String valor;

  const _Fila({required this.icon, required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(valor, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/ble_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'ble_status_indicator.dart';

class SidebarItem {
  final IconData icon;
  final String label;

  const SidebarItem(this.icon, this.label);
}

/// Menú lateral izquierdo: logo, secciones, y abajo el estado de la banda
/// Bluetooth y el botón sol/luna. Con [compacto] solo muestra íconos.
class AppSidebar extends StatelessWidget {
  final List<SidebarItem> items;
  final int seleccionado;
  final ValueChanged<int> onSeleccionar;

  /// Abre "Conexión Bluetooth" dentro de la sección actual.
  final VoidCallback onBluetooth;
  final bool compacto;

  const AppSidebar({
    super.key,
    required this.items,
    required this.seleccionado,
    required this.onSeleccionar,
    required this.onBluetooth,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.symmetric(
        vertical: 24,
        horizontal: compacto ? 10 : 16,
      ),
      child: SizedBox(
        width: compacto ? 56 : 228,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // LOGO
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compacto ? 0 : 8),
              child: compacto
                  ? Image.asset('assets/images/A_icono.png', height: 40)
                  : const Align(
                      alignment: Alignment.centerLeft,
                      child: AppLogo(height: 46),
                    ),
            ),
            const SizedBox(height: 32),

            // SECCIONES
            for (var i = 0; i < items.length; i++)
              _ItemMenu(
                item: items[i],
                activo: i == seleccionado,
                compacto: compacto,
                onTap: () => onSeleccionar(i),
              ),

            const Spacer(),

            // ESTADO BLUETOOTH
            _EstadoBluetooth(compacto: compacto, onTap: onBluetooth),
            const SizedBox(height: 12),

            // SOL / LUNA
            _SelectorTema(compacto: compacto),
          ],
        ),
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final SidebarItem item;
  final bool activo;
  final bool compacto;
  final VoidCallback onTap;

  const _ItemMenu({
    required this.item,
    required this.activo,
    required this.compacto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = activo ? Colors.white : scheme.onSurface;
    final radio = BorderRadius.circular(14);

    final fila = Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: compacto ? 0 : 14),
      decoration: BoxDecoration(
        color: activo ? AppTheme.primary : Colors.transparent,
        borderRadius: radio,
      ),
      child: Row(
        mainAxisAlignment: compacto
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Icon(item.icon, size: 22, color: color),
          if (!compacto) ...[
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: AppText.texto(
                  size: 15,
                  weight: activo ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Tooltip(
        message: compacto ? item.label : '',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(borderRadius: radio, onTap: onTap, child: fila),
        ),
      ),
    );
  }
}

/// Tarjeta pequeña con el estado de la banda (BleService).
/// Al tocarla abre la pantalla "Conexión Bluetooth".
class _EstadoBluetooth extends StatelessWidget {
  final bool compacto;
  final VoidCallback onTap;

  const _EstadoBluetooth({required this.compacto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ble = BleService.instance;

    return ListenableBuilder(
      listenable: ble,
      builder: (context, _) {
        final color = BleStatusIndicator.colorDe(ble.estado);
        final radio = BorderRadius.circular(16);
        final icono = ble.conectado
            ? AppIcons.bluetoothConnected
            : (ble.estado == BleEstado.desconectado
                  ? AppIcons.bluetoothSlash
                  : AppIcons.bluetooth);

        final abrir = onTap;

        if (compacto) {
          return Tooltip(
            message: BleStatusIndicator.textoDe(ble),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: radio,
                onTap: abrir,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: radio,
                  ),
                  child: Icon(icono, color: color),
                ),
              ),
            ),
          );
        }

        return Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radio,
            onTap: abrir,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.softSurface(context),
                borderRadius: radio,
                border: Border.all(
                  color: Glass.borderColor(
                    Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icono, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Banda respiratoria',
                          style: AppText.texto(
                            size: 13,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                switch (ble.estado) {
                                  BleEstado.conectado =>
                                    ble.nombreDispositivo ?? 'Conectada',
                                  BleEstado.conectando =>
                                    ble.reconectando
                                        ? 'Reconectando...'
                                        : 'Conectando...',
                                  BleEstado.desconectado => 'Desconectada',
                                },
                                overflow: TextOverflow.ellipsis,
                                style: AppText.texto(
                                  size: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

/// Botón sol/luna. En el menú completo muestra las dos opciones.
class _SelectorTema extends StatelessWidget {
  final bool compacto;

  const _SelectorTema({required this.compacto});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (compacto) return const Center(child: ThemeToggleButton());

    Widget opcion(IconData icon, String texto, bool activa) {
      return Expanded(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: activa ? null : toggleThemeMode,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: activa ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: activa
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    texto,
                    style: AppText.texto(
                      size: 13,
                      weight: FontWeight.w700,
                      color: activa
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.softSurface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          opcion(AppIcons.sun, 'Claro', !dark),
          const SizedBox(width: 4),
          opcion(AppIcons.moon, 'Oscuro', dark),
        ],
      ),
    );
  }
}

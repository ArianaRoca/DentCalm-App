import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';
import 'bluetooth_screen.dart';
import 'history_screen.dart';
import 'patients_screen.dart';
import 'settings_screen.dart';

/// Estructura principal tras iniciar sesión: menú lateral fijo a la
/// izquierda y, a la derecha, el contenido de la sección elegida.
///
/// Cada sección tiene su propio Navigator: al abrir un paciente, una
/// sesión, etc., el menú sigue visible y la sección recuerda dónde estaba.
class AppShell extends StatefulWidget {
  /// Pantalla de Inicio (se pasa desde main.dart).
  final Widget inicio;

  const AppShell({super.key, required this.inicio});

  static const int inicioIdx = 0;
  static const int pacientesIdx = 1;
  static const int monitoreoIdx = 2;
  static const int historialIdx = 3;
  static const int ajustesIdx = 4;

  /// Cambia de sección desde cualquier pantalla dentro del menú.
  static void irA(BuildContext context, int indice) {
    context.findAncestorStateOfType<_AppShellState>()?._seleccionar(indice);
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _items = [
    SidebarItem(AppIcons.house, 'Inicio'),
    SidebarItem(AppIcons.usersThree, 'Pacientes'),
    SidebarItem(AppIcons.heartbeat, 'Monitoreo'),
    SidebarItem(AppIcons.clockCounterClockwise, 'Historial'),
    SidebarItem(AppIcons.gear, 'Ajustes'),
  ];

  final _navegadores = List.generate(
    _items.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  int _actual = 0;

  /// Las secciones se crean la primera vez que se visitan.
  final Set<int> _visitadas = {0};

  Widget _raiz(int i) => switch (i) {
    AppShell.inicioIdx => widget.inicio,
    AppShell.pacientesIdx => const PatientsScreen(),
    AppShell.monitoreoIdx => const PatientsScreen(modoSeleccion: true),
    AppShell.historialIdx => const HistoryScreen(),
    _ => const SettingsScreen(),
  };

  void _seleccionar(int i) {
    if (i == _actual) {
      // Tocar la sección activa la devuelve a su pantalla inicial.
      _navegadores[i].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _actual = i;
      _visitadas.add(i);
    });
  }

  void _abrirBluetooth() {
    _navegadores[_actual].currentState?.push(
      MaterialPageRoute(builder: (_) => const BluetoothScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compacto = MediaQuery.sizeOf(context).width < 1000;

    return AppBackground(
      child: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSidebar(
              items: _items,
              seleccionado: _actual,
              onSeleccionar: _seleccionar,
              onBluetooth: _abrirBluetooth,
              compacto: compacto,
            ),
            Expanded(
              child: IndexedStack(
                index: _actual,
                children: [
                  for (var i = 0; i < _items.length; i++)
                    _visitadas.contains(i)
                        ? HeroControllerScope.none(
                            child: Navigator(
                              key: _navegadores[i],
                              onGenerateRoute: (_) =>
                                  MaterialPageRoute(builder: (_) => _raiz(i)),
                            ),
                          )
                        : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

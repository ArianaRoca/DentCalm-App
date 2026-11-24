import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'bluetooth_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget fila({
      required IconData icon,
      required String titulo,
      required String subtitulo,
      Widget? trailing,
      VoidCallback? onTap,
      Color? color,
    }) {
      return ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(
          icon,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          titulo,
          style: AppText.texto(size: 16, weight: FontWeight.w700, color: color),
        ),
        subtitle: Text(
          subtitulo,
          style: AppText.texto(size: 13, color: Colors.grey),
        ),
        trailing: trailing,
      );
    }

    return AppBackground(
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 32, 32, 32),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ajustes', style: AppText.titulo(size: 30)),
                  const SizedBox(height: 24),

                  Text('Apariencia', style: AppText.titulo(size: 17)),
                  const SizedBox(height: 10),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: fila(
                      icon: dark ? AppIcons.moon : AppIcons.sun,
                      titulo: 'Modo oscuro',
                      subtitulo: 'Se recuerda la próxima vez que abras la app.',
                      trailing: Switch(
                        value: dark,
                        onChanged: (_) => toggleThemeMode(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text('Dispositivo', style: AppText.titulo(size: 17)),
                  const SizedBox(height: 10),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: fila(
                      icon: AppIcons.bluetooth,
                      titulo: 'Conexión Bluetooth',
                      subtitulo:
                          'Conectar o desconectar la banda respiratoria.',
                      trailing: const Icon(
                        AppIcons.caretRight,
                        color: Colors.grey,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BluetoothScreen(),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text('Cuenta', style: AppText.titulo(size: 17)),
                  const SizedBox(height: 10),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        fila(
                          icon: AppIcons.user,
                          titulo: (user?.displayName?.isNotEmpty ?? false)
                              ? user!.displayName!
                              : 'Odontólogo',
                          subtitulo: user?.email ?? '',
                        ),
                        const Divider(),
                        fila(
                          icon: AppIcons.signOut,
                          titulo: 'Cerrar sesión',
                          subtitulo: 'Salir de tu cuenta en este dispositivo.',
                          color: AppTheme.danger,
                          onTap: () => FirebaseAuth.instance.signOut(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

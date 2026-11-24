import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pantalla de inicio (estática): muestra el diente y el logo un momento
/// y luego pasa a [next].
class SplashScreen extends StatefulWidget {
  final Widget next;
  final Duration duracion;

  const SplashScreen({
    super.key,
    required this.next,
    this.duracion = const Duration(milliseconds: 1500),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duracion, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => widget.next,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/A_icono.png', height: 150),
              const SizedBox(height: 28),
              const AppLogo(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}

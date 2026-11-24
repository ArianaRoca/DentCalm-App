import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Área tocable con efecto de tinta estándar (sin animación de escala).
class Pressable extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(Glass.radius)),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(borderRadius: borderRadius, onTap: onTap, child: child),
    );
  }
}

/// Botón principal: azul #1E62C8, texto blanco.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final EdgeInsets padding;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: padding,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else if (icon != null)
            Icon(icon, size: 20),
          if (loading || icon != null) const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.texto(size: 15, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Antes animaba la entrada; ahora la app va sin animaciones y solo
/// devuelve [child]. Se conserva para no tocar todas las pantallas.
class FadeInSlide extends StatelessWidget {
  final Widget child;
  final int index;

  const FadeInSlide({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) => child;
}

/// Estado vacío amable con el diente de DentCalm.
class EmptyState extends StatelessWidget {
  final String titulo;
  final String mensaje;
  final Widget? accion;

  const EmptyState({
    super.key,
    required this.titulo,
    required this.mensaje,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/A_icono.png', height: 90),
            const SizedBox(height: 18),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: AppText.titulo(size: 19),
            ),
            const SizedBox(height: 8),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: AppText.texto(size: 15, color: Colors.grey),
            ),
            if (accion != null) ...[const SizedBox(height: 20), accion!],
          ],
        ),
      ),
    );
  }
}

/// Avatar circular con las iniciales sobre el color principal.
class InitialsAvatar extends StatelessWidget {
  final String nombre;
  final double size;

  const InitialsAvatar({super.key, required this.nombre, this.size = 52});

  String get _iniciales {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    final a = partes.first[0];
    final b = partes.length > 1 ? partes[1][0] : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: AppTheme.gradient,
        shape: BoxShape.circle,
      ),
      child: Text(
        _iniciales,
        style: AppText.titulo(
          size: size * 0.34,
          weight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Recuadro redondeado con el ícono en color de marca.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;

  const IconBadge({super.key, required this.icon, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.tint(context),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

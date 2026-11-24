import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_icons.dart';

const String _kModoOscuro = 'modoOscuro';

/// Modo de tema global de la app (claro / oscuro).
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.light,
);

/// Carga el modo guardado. Se llama en main() antes de runApp.
Future<void> loadThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final oscuro = prefs.getBool(_kModoOscuro) ?? false;
    themeModeNotifier.value = oscuro ? ThemeMode.dark : ThemeMode.light;
  } catch (e) {
    debugPrint('No se pudo leer el modo de tema guardado: $e');
  }
}

Future<void> toggleThemeMode() async {
  final oscuro = themeModeNotifier.value != ThemeMode.dark;
  themeModeNotifier.value = oscuro ? ThemeMode.dark : ThemeMode.light;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kModoOscuro, oscuro);
  } catch (e) {
    debugPrint('No se pudo guardar el modo de tema: $e');
  }
}

// ===========================================================================
// TIPOGRAFÍA: Poppins (títulos) + Nunito (texto)
// ===========================================================================

/// google_fonts registra cada peso como una familia distinta
/// ("Nunito_700"...). Para que las negritas sean reales y no simuladas,
/// los estilos se piden SIEMPRE con su peso a través de estas funciones.
class AppText {
  /// Títulos y números destacados (Poppins).
  static TextStyle titulo({
    double size = 22,
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) => GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

  /// Texto general (Nunito).
  static TextStyle texto({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color);
}

// ===========================================================================
// COLORES Y TEMA
// ===========================================================================

class AppTheme {
  // Paleta base.
  static const Color primary = Color(0xFF1E62C8); // botón principal
  static const Color accent = Color(0xFF0E7A67); // acento turquesa
  static const Color textLight = Color(0xFF13345B); // texto modo claro
  static const Color textDark = Color(0xFFF3F7FD); // texto modo oscuro
  static const Color danger = Color(0xFFD94B4B);

  /// Azul marino de las superficies de vidrio en modo oscuro.
  static const Color navyGlass = Color(0xFF0E2340);

  // Nombres que ya usan las pantallas.
  static const Color secondary = accent;
  static const Color navy = textLight;

  // Degradado del logo (A_icono.png), para detalles de marca.
  static const Color gradStart = Color(0xFF2983EA);
  static const Color gradEnd = Color(0xFF189C9E);
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradStart, gradEnd],
  );

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
    ).copyWith(onSurface: textLight);
    return _base(scheme, textLight, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      // En oscuro, el azul/turquesa de textos e íconos se aclara para
      // mantener el contraste; el fondo del botón principal sigue #1E62C8.
      primary: const Color(0xFF7AAEF5),
      onPrimary: const Color(0xFF0B1E38),
      secondary: const Color(0xFF3FC2A6),
    ).copyWith(onSurface: textDark);
    return _base(scheme, textDark, Brightness.dark);
  }

  static ThemeData _base(ColorScheme scheme, Color texto, Brightness b) {
    final dark = b == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
    );

    TextStyle? p(TextStyle? s) =>
        s == null ? null : GoogleFonts.poppins(textStyle: s, color: texto);
    TextStyle? n(TextStyle? s) =>
        s == null ? null : GoogleFonts.nunito(textStyle: s, color: texto);
    final t = base.textTheme;

    // Sin animación al cambiar de pantalla.
    const sinTransicion = _SinTransicion();

    return base.copyWith(
      textTheme: TextTheme(
        displayLarge: p(t.displayLarge),
        displayMedium: p(t.displayMedium),
        displaySmall: p(t.displaySmall),
        headlineLarge: p(t.headlineLarge),
        headlineMedium: p(t.headlineMedium),
        headlineSmall: p(t.headlineSmall),
        titleLarge: p(t.titleLarge),
        titleMedium: p(t.titleMedium),
        titleSmall: p(t.titleSmall),
        bodyLarge: n(t.bodyLarge),
        bodyMedium: n(t.bodyMedium),
        bodySmall: n(t.bodySmall),
        labelLarge: n(t.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        labelMedium: n(t.labelMedium),
        labelSmall: n(t.labelSmall),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: sinTransicion,
          TargetPlatform.iOS: sinTransicion,
          TargetPlatform.windows: sinTransicion,
          TargetPlatform.macOS: sinTransicion,
          TargetPlatform.linux: sinTransicion,
          TargetPlatform.fuchsia: sinTransicion,
        },
      ),
      // Flecha "atrás" con el mismo estilo de íconos (Phosphor).
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(AppIcons.arrowLeft),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: texto,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppText.titulo(size: 22, color: texto),
      ),
      cardTheme: CardThemeData(
        color: Glass.fill(dark),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Glass.radius),
          side: BorderSide(color: Glass.borderColor(dark)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.75),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Glass.borderColor(dark, fuerte: true)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppText.texto(size: 15, weight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: Glass.borderColor(dark, fuerte: true)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppText.texto(size: 15, weight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: AppText.texto(size: 15, weight: FontWeight.w700),
        ),
      ),
      dividerTheme: DividerThemeData(color: Glass.borderColor(dark)),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Superficie semitransparente para bloques internos (no tarjetas).
  static Color softSurface(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF2F6FC).withValues(alpha: 0.85);
  }

  /// Fondo suave del color de marca para íconos/avatares.
  static Color tint(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return primary.withValues(alpha: dark ? 0.28 : 0.10);
  }
}

/// Cambio de pantalla instantáneo (sin animación).
class _SinTransicion extends PageTransitionsBuilder {
  const _SinTransicion();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

// ===========================================================================
// VIDRIO (glassmorphism)
// ===========================================================================

/// Valores del efecto vidrio, compartidos por [GlassCard] y el tema.
class Glass {
  static const double radius = 24;
  static const double blur = 18;

  /// Blanco 70% (claro) / azul marino 58% (oscuro).
  static Color fill(bool dark) => dark
      ? AppTheme.navyGlass.withValues(alpha: 0.58)
      : Colors.white.withValues(alpha: 0.70);

  /// Borde sutil.
  static Color borderColor(bool dark, {bool fuerte = false}) => dark
      ? Colors.white.withValues(alpha: fuerte ? 0.18 : 0.10)
      : Colors.white.withValues(alpha: fuerte ? 0.95 : 0.85);
}

/// Tarjeta de vidrio reutilizable: fondo translúcido con desenfoque,
/// radio 24 y borde sutil. Si [onTap] no es nulo, es tocable.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.radius = Glass.radius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final borde = BorderRadius.circular(radius);

    Widget contenido = Padding(padding: padding, child: child);
    if (onTap != null) {
      contenido = InkWell(onTap: onTap, borderRadius: borde, child: contenido);
    }
    // Material transparente encima del fondo de vidrio: ListTile, InkWell y
    // botones de adentro pintan aquí sus efectos (si no, quedan tapados).
    contenido = Material(type: MaterialType.transparency, child: contenido);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borde,
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0xFF1E62C8).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borde,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: Glass.blur, sigmaY: Glass.blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Glass.fill(dark),
              borderRadius: borde,
              border: Border.all(color: Glass.borderColor(dark)),
            ),
            child: contenido,
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// FONDO, LOGO Y BOTÓN DE TEMA
// ===========================================================================

/// Fondo de pantalla: imagen según el modo + capa semitransparente.
/// Si ya hay un AppBackground más arriba (por ejemplo dentro del menú
/// lateral), no se vuelve a pintar: así el fondo no se oscurece de más.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (_FondoPintado.existe(context)) return child;

    final dark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          dark
              ? 'assets/images/fondo_oscuro.png'
              : 'assets/images/fondo_claro.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
        ColoredBox(
          color: dark
              ? Colors.black.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.20),
        ),
        _FondoPintado(child: child),
      ],
    );
  }
}

class _FondoPintado extends InheritedWidget {
  const _FondoPintado({required super.child});

  static bool existe(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_FondoPintado>() != null;

  @override
  bool updateShouldNotify(_FondoPintado oldWidget) => false;
}

/// Logo horizontal de DentCalm: texto oscuro en modo claro,
/// texto blanco en modo oscuro.
class AppLogo extends StatelessWidget {
  final double height;

  const AppLogo({super.key, this.height = 40});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Image.asset(
      dark
          ? 'assets/images/A_horizontal_fondo_oscuro.png'
          : 'assets/images/A_horizontal.png',
      height: height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      semanticLabel: 'DentCalm',
    );
  }
}

/// Botón sol/luna para cambiar entre modo claro y oscuro.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: dark ? 'Modo claro' : 'Modo oscuro',
      onPressed: toggleThemeMode,
      icon: Icon(dark ? AppIcons.sun : AppIcons.moon),
    );
  }
}

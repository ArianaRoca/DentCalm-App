import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/zona_calma.dart';

// ===========================================================================
// PIEZAS COMUNES
// ===========================================================================

Color _gris(BuildContext c) => Colors.grey.withValues(alpha: 0.22);

const Color _verdeSemaforo = Color(0xFF1F9D57);

/// Franja "zona calma" del niño: desde μ_b hasta su límite verde.
/// Sin basal todavía, no se dibuja.
RangeAnnotations _franjaCalma(double? desde, double? hasta) =>
    (desde == null || hasta == null)
    ? RangeAnnotations()
    : RangeAnnotations(
        horizontalRangeAnnotations: [
          HorizontalRangeAnnotation(
            y1: desde,
            y2: hasta,
            color: _verdeSemaforo.withValues(alpha: 0.13),
          ),
        ],
      );

/// Bordes punteados de la zona calma con su etiqueta y, si hay umbral por
/// edad, la línea del centil 99.
ExtraLinesData _lineasReferencia(
  double? desde,
  double? hasta,
  double? umbralRojo,
) {
  HorizontalLine punteada(double y, Color c, String? texto) => HorizontalLine(
    y: y,
    color: c.withValues(alpha: 0.55),
    strokeWidth: 1,
    dashArray: [4, 4],
    label: HorizontalLineLabel(
      show: texto != null,
      alignment: Alignment.topRight,
      padding: const EdgeInsets.only(right: 6, bottom: 2),
      style: AppText.texto(size: 11, weight: FontWeight.w700, color: c),
      labelResolver: (_) => texto ?? '',
    ),
  );

  return ExtraLinesData(
    horizontalLines: [
      if (desde != null && hasta != null) ...[
        punteada(hasta, _verdeSemaforo, 'Zona calma'),
        punteada(desde, _verdeSemaforo, null),
      ],
      if (umbralRojo != null)
        punteada(umbralRojo, AppTheme.danger, 'Centil 99 por edad'),
    ],
  );
}

Widget _eje(String t, TitleMeta meta) => SideTitleWidget(
  meta: meta,
  child: Text(t, style: AppText.texto(size: 11, color: Colors.grey)),
);

AxisTitles _ejeRpm() => AxisTitles(
  axisNameWidget: Text(
    'rpm',
    style: AppText.texto(size: 11, color: Colors.grey),
  ),
  axisNameSize: 18,
  sideTitles: SideTitles(
    showTitles: true,
    reservedSize: 34,
    interval: 5,
    getTitlesWidget: (v, meta) => _eje(v.toInt().toString(), meta),
  ),
);

/// Rango vertical con margen. [ys] incluye los datos y las referencias
/// que deban verse (zona calma, centil 99).
(double, double) _rangoY(Iterable<double> ys) {
  final lista = ys.toList();
  var lo = 12.0;
  var hi = 24.0;
  if (lista.isNotEmpty) {
    lo = lista.reduce(math.min);
    hi = lista.reduce(math.max);
  }
  lo = math.max(0, ((lo - 3) / 5).floor() * 5.0);
  hi = ((hi + 3) / 5).ceil() * 5.0;
  return (lo, hi);
}

String _mmss(num segundos) {
  final s = segundos.toInt();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

// ===========================================================================
// MONITOREO: FR EN VIVO
// ===========================================================================

enum VentanaFr {
  unMinuto('1 min', 60, 10),
  cincoMinutos('5 min', 300, 60),
  sesion('Sesión', null, null);

  final String etiqueta;

  /// Segundos visibles (null = toda la sesión).
  final int? segundos;

  /// Separación de las marcas del eje X en segundos (null = automática).
  final int? marca;

  const VentanaFr(this.etiqueta, this.segundos, this.marca);
}

/// FR en tiempo real. [puntos]: x = segundo de la sesión, y = rpm.
/// Marca el máximo y el mínimo visibles con su valor.
class FrEnVivoChart extends StatelessWidget {
  final List<FlSpot> puntos;
  final VentanaFr ventana;

  /// Zona calma del niño: μ_b (desde) y límite verde (hasta).
  final double? bandaDesde;
  final double? bandaHasta;

  /// Centil 99 por edad (línea roja), si hay umbral para su edad.
  final double? umbralRojo;

  const FrEnVivoChart({
    super.key,
    required this.puntos,
    required this.ventana,
    this.bandaDesde,
    this.bandaHasta,
    this.umbralRojo,
  });

  static FlSpot _max(List<FlSpot> l) => l.reduce((a, b) => b.y > a.y ? b : a);
  static FlSpot _min(List<FlSpot> l) => l.reduce((a, b) => b.y < a.y ? b : a);

  @override
  Widget build(BuildContext context) {
    if (puntos.isEmpty) {
      return Center(
        child: Text(
          'La gráfica aparecerá al recibir los primeros datos de la banda.',
          textAlign: TextAlign.center,
          style: AppText.texto(color: Colors.grey),
        ),
      );
    }

    final ultimo = puntos.last.x;
    final double minX;
    final double maxX;
    final seg = ventana.segundos;
    if (seg != null) {
      maxX = math.max(ultimo, seg.toDouble());
      minX = maxX - seg;
    } else {
      minX = 0;
      maxX = math.max(ultimo, 60);
    }
    final visibles = puntos.where((p) => p.x >= minX).toList();
    if (visibles.isEmpty) visibles.add(puntos.last);
    final (minY, maxY) = _rangoY([
      ...visibles.map((p) => p.y),
      ?bandaDesde,
      ?bandaHasta,
      ?umbralRojo,
    ]);

    // Marcas del eje X: cada 10 s (1 min), cada minuto (5 min) o
    // automáticas para toda la sesión (~6 marcas, múltiplos de 30 s).
    final marca =
        (ventana.marca ?? math.max(30, ((maxX - minX) / 6 / 30).ceil() * 30))
            .toDouble();

    final pMax = _max(visibles);
    final pMin = _min(visibles);

    final linea = LineChartBarData(
      spots: visibles,
      isCurved: true,
      preventCurveOverShooting: true,
      barWidth: 3,
      color: AppTheme.primary,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, _) => spot == pMax || spot == pMin,
        getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
          radius: 5,
          color: Colors.white,
          strokeWidth: 3,
          strokeColor: spot == pMax ? AppTheme.danger : AppTheme.accent,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: AppTheme.primary.withValues(alpha: 0.08),
      ),
    );

    final indicadores = [
      ShowingTooltipIndicators([LineBarSpot(linea, 0, pMax)]),
      if (pMin != pMax) ShowingTooltipIndicators([LineBarSpot(linea, 0, pMin)]),
    ];
    final dark = Theme.of(context).brightness == Brightness.dark;

    return LineChart(
      duration: Duration.zero, // sin animación
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        rangeAnnotations: _franjaCalma(bandaDesde, bandaHasta),
        extraLinesData: _lineasReferencia(bandaDesde, bandaHasta, umbralRojo),
        gridData: FlGridData(
          drawVerticalLine: true,
          verticalInterval: marca,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: _gris(context), strokeWidth: 1),
          getDrawingVerticalLine: (_) =>
              FlLine(color: _gris(context), strokeWidth: 1, dashArray: [3, 4]),
        ),
        borderData: FlBorderData(show: false),
        showingTooltipIndicators: indicadores,
        lineTouchData: LineTouchData(
          enabled: false,
          handleBuiltInTouches: false,
          getTouchedSpotIndicator: (bar, idx) => idx
              .map(
                (_) => const TouchedSpotIndicatorData(
                  FlLine(color: Colors.transparent),
                  FlDotData(show: false),
                ),
              )
              .toList(),
          touchTooltipData: LineTouchTooltipData(
            tooltipMargin: 10,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) =>
                dark ? const Color(0xFF16304F) : Colors.white,
            getTooltipItems: (spots) => spots.map((s) {
              final esMax = s.x == pMax.x && s.y == pMax.y;
              return LineTooltipItem(
                '${esMax ? 'Máx' : 'Mín'} ${s.y.toInt()}',
                AppText.texto(
                  size: 12,
                  weight: FontWeight.w800,
                  color: esMax ? AppTheme.danger : AppTheme.accent,
                ),
              );
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: _ejeRpm(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: marca,
              reservedSize: 26,
              getTitlesWidget: (v, meta) {
                if (v < 0) return const SizedBox.shrink();
                return _eje(_mmss(v), meta);
              },
            ),
          ),
        ),
        lineBarsData: [linea],
      ),
    );
  }
}

// ===========================================================================
// DETALLE DEL PACIENTE: FR POR SESIÓN
// ===========================================================================

class PuntoSesion {
  final DateTime? fecha;
  final double promedio;
  final double? minima;
  final double? maxima;

  /// μ_b y σ_b guardados en la sesión (null en sesiones antiguas).
  final double? basalMedia;
  final double? basalDesvio;

  const PuntoSesion({
    required this.fecha,
    required this.promedio,
    this.minima,
    this.maxima,
    this.basalMedia,
    this.basalDesvio,
  });

  double? get limiteVerde =>
      SemaforoFr.limiteVerdePara(basalMedia, basalDesvio);
}

/// Por sesión: franja verde con la zona calma de ESA sesión (μ_b → límite
/// verde), barra con el rango mín–máx y punto + línea con el promedio.
class FrPorSesionChart extends StatelessWidget {
  final List<PuntoSesion> sesiones;

  const FrPorSesionChart({super.key, required this.sesiones});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final azul = Theme.of(context).colorScheme.primary;

    // Zona calma de cada sesión: franja ancha y translúcida.
    final zonas = <LineChartBarData>[
      for (var i = 0; i < sesiones.length; i++)
        if (sesiones[i].basalMedia != null && sesiones[i].limiteVerde != null)
          LineChartBarData(
            spots: [
              FlSpot(i.toDouble(), sesiones[i].basalMedia!),
              FlSpot(i.toDouble(), sesiones[i].limiteVerde!),
            ],
            barWidth: 30,
            color: _verdeSemaforo.withValues(alpha: 0.16),
            dotData: const FlDotData(show: false),
          ),
    ];

    // Cada rango mín–máx se dibuja como una línea vertical gruesa (barra).
    final barras = <LineChartBarData>[
      for (var i = 0; i < sesiones.length; i++)
        if (sesiones[i].minima != null && sesiones[i].maxima != null)
          LineChartBarData(
            spots: [
              FlSpot(i.toDouble(), sesiones[i].minima!),
              FlSpot(i.toDouble(), sesiones[i].maxima!),
            ],
            barWidth: 10,
            isStrokeCapRound: true,
            color: azul.withValues(alpha: dark ? 0.35 : 0.22),
            dotData: const FlDotData(show: false),
          ),
    ];

    final lineaPromedio = LineChartBarData(
      spots: [
        for (var i = 0; i < sesiones.length; i++)
          FlSpot(i.toDouble(), sesiones[i].promedio),
      ],
      barWidth: 2.5,
      color: azul,
      dotData: FlDotData(
        show: true,
        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
          radius: 5,
          color: azul,
          strokeWidth: 2,
          strokeColor: Colors.white,
        ),
      ),
    );

    final ys = <double>[
      for (final s in sesiones) ...[
        s.promedio,
        if (s.minima != null) s.minima!,
        if (s.maxima != null) s.maxima!,
        if (s.basalMedia != null) s.basalMedia!,
        if (s.limiteVerde != null) s.limiteVerde!,
      ],
    ];
    final (minY, maxY) = _rangoY(ys);

    String etiqueta(int i) {
      final f = sesiones[i].fecha;
      if (f == null) return 'Nueva';
      return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}';
    }

    return LineChart(
      duration: Duration.zero, // sin animación
      LineChartData(
        minX: -0.5,
        maxX: sesiones.length - 0.5,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: _gris(context), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: _ejeRpm(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 26,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if ((v - i).abs() > 0.01 || i < 0 || i >= sesiones.length) {
                  return const SizedBox.shrink();
                }
                final paso = (sesiones.length / 10).ceil();
                if (i % paso != 0 && i != sesiones.length - 1) {
                  return const SizedBox.shrink();
                }
                return _eje(etiqueta(i), meta);
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) =>
                dark ? const Color(0xFF16304F) : Colors.white,
            getTooltipItems: (spots) => spots.map((s) {
              // Solo la línea de promedio (la última) muestra el detalle.
              if (s.barIndex != zonas.length + barras.length) return null;
              final ses = sesiones[s.x.toInt()];
              final rango = ses.minima != null && ses.maxima != null
                  ? '\nMín ${ses.minima!.toInt()} · Máx ${ses.maxima!.toInt()}'
                  : '';
              final zona = ses.basalMedia != null && ses.limiteVerde != null
                  ? '\nZona calma ${ses.basalMedia!.toStringAsFixed(1)}–'
                        '${ses.limiteVerde!.toStringAsFixed(1)}'
                  : '';
              return LineTooltipItem(
                '${etiqueta(s.x.toInt())}\n',
                AppText.texto(size: 12, color: Colors.grey),
                children: [
                  TextSpan(
                    text: 'Prom. ${s.y.toStringAsFixed(1)} rpm',
                    style: AppText.texto(
                      size: 13,
                      weight: FontWeight.w800,
                      color: azul,
                    ),
                  ),
                  TextSpan(
                    text: rango + zona,
                    style: AppText.texto(size: 12, color: Colors.grey),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        lineBarsData: [...zonas, ...barras, lineaPromedio],
      ),
    );
  }
}

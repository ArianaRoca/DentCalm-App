import 'dart:math' as math;

import 'package:flutter/material.dart';

// ===========================================================================
// SEMÁFORO DE FRECUENCIA RESPIRATORIA (FR) BASADO EN LA BASAL DE CADA NIÑO
// ===========================================================================
//
// Fleming et al., Lancet 2011; parámetros de diseño, no valores clínicos
// validados.
//
// Las constantes de abajo (k, Δ, T, ventana de basal y centiles por edad)
// son parámetros de diseño de DentCalm. Cambiarlas aquí cambia toda la app.

class ParametrosSemaforo {
  /// Fleming et al., Lancet 2011; parámetros de diseño, no valores clínicos
  /// validados.
  /// k: número de desviaciones estándar sobre la media basal.
  static const double k = 2;

  /// Fleming et al., Lancet 2011; parámetros de diseño, no valores clínicos
  /// validados.
  /// Δ: aumento relativo mínimo sobre la media basal (10 %).
  static const double delta = 0.10;

  /// Fleming et al., Lancet 2011; parámetros de diseño, no valores clínicos
  /// validados.
  /// T: segundos que la FR debe sostenerse sobre el límite para pasar a ámbar.
  static const double sostenidoSeg = 30;

  /// Fleming et al., Lancet 2011; parámetros de diseño, no valores clínicos
  /// validados.
  /// Duración de la medición basal al inicio de la sesión (segundos).
  static const double ventanaBasalSeg = 60;
}

/// Umbrales por edad.
///
/// Fleming et al., Lancet 2011; parámetros de diseño, no valores clínicos
/// validados.
class UmbralesEdad {
  /// Rango aceptable para la media basal (rpm).
  final double basalMin;
  final double basalMax;

  /// Centil 99 de FR para la edad (rpm). Por encima → rojo.
  final double centil99;

  const UmbralesEdad({
    required this.basalMin,
    required this.basalMax,
    required this.centil99,
  });

  /// Fleming et al., Lancet 2011; parámetros de diseño, no valores clínicos
  /// validados.
  static const seisASiete = UmbralesEdad(
    basalMin: 16,
    basalMax: 27,
    centil99: 27,
  );

  /// Fleming et al., Lancet 2011; parámetros de diseño, no valores clínicos
  /// validados.
  static const ocho = UmbralesEdad(basalMin: 14, basalMax: 25, centil99: 25);

  /// Umbrales para la edad del paciente (en años). Solo hay valores
  /// definidos para 6–8 años; para otras edades devuelve null y no se
  /// aplican ni el rojo por centil ni la verificación de la basal.
  static UmbralesEdad? paraEdad(int? edad) => switch (edad) {
    6 || 7 => seisASiete,
    8 => ocho,
    _ => null,
  };
}

enum EstadoSemaforo {
  midiendoBasal('Midiendo basal…', Color(0xFF8A94A3)),
  verde('Respiración estable', Color(0xFF1F9D57)),
  ambar('Activación respiratoria', Color(0xFFE08A1E)),
  rojo('FR alta: revisar llanto, habla o sensor', Color(0xFFD94B4B));

  final String texto;
  final Color color;

  const EstadoSemaforo(this.texto, this.color);
}

/// Lee la edad del paciente desde el dato de Firestore (int, num o texto).
int? edadDesde(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

/// Motor del semáforo para UNA sesión. Recibe cada muestra de FR con el
/// segundo de la sesión en que llegó.
///
/// 1. Basal: con las muestras de los primeros 60 s calcula μ_b y σ_b.
///    Mientras tanto el estado es "Midiendo basal…".
/// 2. Verde: FR < μ_b + max(k·σ_b, Δ·μ_b).
/// 3. Ámbar: FR ≥ ese límite de forma sostenida durante ≥ T segundos.
/// 4. Rojo: FR > centil 99 por edad (aunque la basal sea alta).
/// 5. Si μ_b cae fuera del rango por edad → "Basal fuera de rango".
/// 6. Las muestras en ámbar o rojo no actualizan la basal.
class SemaforoFr {
  final UmbralesEdad? umbrales;

  SemaforoFr({required int? edad}) : umbrales = UmbralesEdad.paraEdad(edad);

  final List<double> _muestrasBasal = [];
  double? _inicioBasal;
  double? _mediaBasal;
  double? _desvioBasal;
  double? _sobreLimiteDesde;
  double _ultimoT = 0;
  EstadoSemaforo _estado = EstadoSemaforo.midiendoBasal;

  EstadoSemaforo get estado => _estado;

  /// μ_b (rpm). Null mientras se mide la basal.
  double? get mediaBasal => _mediaBasal;

  /// σ_b (rpm). Null mientras se mide la basal.
  double? get desvioBasal => _desvioBasal;

  bool get basalLista => _mediaBasal != null;

  /// Límite verde: μ_b + max(k·σ_b, Δ·μ_b).
  double? get limiteVerde => limiteVerdePara(_mediaBasal, _desvioBasal);

  static double? limiteVerdePara(double? media, double? desvio) {
    if (media == null || desvio == null) return null;
    return media +
        math.max(
          ParametrosSemaforo.k * desvio,
          ParametrosSemaforo.delta * media,
        );
  }

  /// Avance de la medición basal (0 a 1).
  double get progresoBasal {
    if (basalLista) return 1;
    if (_inicioBasal == null) return 0;
    return ((_ultimoT - _inicioBasal!) / ParametrosSemaforo.ventanaBasalSeg)
        .clamp(0, 1)
        .toDouble();
  }

  /// La media basal está fuera del rango esperado para la edad.
  bool get basalFueraDeRango {
    final u = umbrales, m = _mediaBasal;
    if (u == null || m == null) return false;
    return m < u.basalMin || m > u.basalMax;
  }

  /// Segundos seguidos con la FR sobre el límite verde (0 si no lo está).
  double get segundosSobreLimite =>
      _sobreLimiteDesde == null ? 0 : _ultimoT - _sobreLimiteDesde!;

  void agregar(double t, double fr) {
    _ultimoT = t;
    final rojo = umbrales != null && fr > umbrales!.centil99;

    // ---- Medición basal ----
    if (!basalLista) {
      _inicioBasal ??= t;
      // Regla 6: una muestra en rojo no entra en la basal.
      if (!rojo) _muestrasBasal.add(fr);
      final transcurrido = t - _inicioBasal!;
      if (transcurrido >= ParametrosSemaforo.ventanaBasalSeg &&
          _muestrasBasal.length >= 2) {
        _calcularBasal();
      }
      _estado = rojo ? EstadoSemaforo.rojo : EstadoSemaforo.midiendoBasal;
      if (!basalLista) return;
    }

    // ---- Semáforo ----
    final limite = limiteVerde!;
    if (fr >= limite) {
      _sobreLimiteDesde ??= t;
    } else {
      _sobreLimiteDesde = null;
    }
    final ambar =
        _sobreLimiteDesde != null &&
        t - _sobreLimiteDesde! >= ParametrosSemaforo.sostenidoSeg;

    _estado = rojo
        ? EstadoSemaforo.rojo
        : ambar
        ? EstadoSemaforo.ambar
        : EstadoSemaforo.verde;
  }

  /// "Repetir medición": vuelve a medir la basal desde la próxima muestra.
  void reiniciarBasal() {
    _muestrasBasal.clear();
    _inicioBasal = null;
    _mediaBasal = null;
    _desvioBasal = null;
    _sobreLimiteDesde = null;
    _estado = EstadoSemaforo.midiendoBasal;
  }

  void _calcularBasal() {
    final n = _muestrasBasal.length;
    final media = _muestrasBasal.reduce((a, b) => a + b) / n;
    final varianza =
        _muestrasBasal
            .map((x) => (x - media) * (x - media))
            .reduce((a, b) => a + b) /
        (n - 1);
    _mediaBasal = media;
    _desvioBasal = math.sqrt(varianza);
  }
}

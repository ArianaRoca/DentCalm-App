import 'package:app_odontologo/theme/zona_calma.dart';
import 'package:flutter_test/flutter_test.dart';

/// Agrega una muestra por segundo con la FR indicada, de t0 a t1 (incl.).
void serie(SemaforoFr s, double t0, double t1, double fr) {
  for (var t = t0; t <= t1; t++) {
    s.agregar(t, fr);
  }
}

void main() {
  group('Basal', () {
    test('mide durante 60 s y muestra "Midiendo basal…"', () {
      final s = SemaforoFr(edad: 7);
      serie(s, 0, 59, 20);
      expect(s.estado, EstadoSemaforo.midiendoBasal);
      expect(s.basalLista, isFalse);

      s.agregar(60, 20);
      expect(s.basalLista, isTrue);
      expect(s.mediaBasal, closeTo(20, 1e-9));
      expect(s.estado, EstadoSemaforo.verde);
    });

    test('μ_b y σ_b (desviación muestral)', () {
      final s = SemaforoFr(edad: 7);
      for (var t = 0; t <= 60; t++) {
        s.agregar(t.toDouble(), t.isEven ? 18 : 22);
      }
      // 31 muestras de 18 y 30 de 22 → 1218 / 61
      expect(s.mediaBasal, closeTo(1218 / 61, 1e-9));
      expect(s.desvioBasal, closeTo(2.0, 0.05));
    });

    test('las muestras en rojo no entran en la basal (regla 6)', () {
      final s = SemaforoFr(edad: 7); // centil 99 = 27
      serie(s, 0, 30, 20);
      s.agregar(31, 35); // rojo
      expect(s.estado, EstadoSemaforo.rojo);
      serie(s, 32, 60, 20);
      expect(s.mediaBasal, closeTo(20, 1e-9));
    });

    test('basal fuera de rango por edad (regla 5)', () {
      final s = SemaforoFr(edad: 8); // rango 14–25
      serie(s, 0, 60, 12);
      expect(s.basalFueraDeRango, isTrue);
      s.reiniciarBasal();
      expect(s.estado, EstadoSemaforo.midiendoBasal);
      expect(s.basalLista, isFalse);
    });
  });

  group('Semáforo', () {
    // Basal 20 ± 0 → límite = 20 + max(0, 10 % · 20) = 22.
    SemaforoFr conBasal({int edad = 7}) {
      final s = SemaforoFr(edad: edad);
      serie(s, 0, 60, 20);
      return s;
    }

    test('límite verde = μ_b + max(k·σ_b, Δ·μ_b)', () {
      expect(conBasal().limiteVerde, closeTo(22, 1e-9));
      expect(SemaforoFr.limiteVerdePara(20, 3), closeTo(26, 1e-9));
    });

    test('verde bajo el límite', () {
      final s = conBasal();
      s.agregar(61, 21.9);
      expect(s.estado, EstadoSemaforo.verde);
    });

    test('ámbar solo si se sostiene ≥ 30 s sobre el límite', () {
      final s = conBasal();
      serie(s, 61, 90, 23); // 29 s sobre el límite
      expect(s.estado, EstadoSemaforo.verde);
      s.agregar(91, 23); // 30 s
      expect(s.estado, EstadoSemaforo.ambar);
      s.agregar(92, 21); // vuelve bajo el límite
      expect(s.estado, EstadoSemaforo.verde);
      expect(s.segundosSobreLimite, 0);
    });

    test('una bajada reinicia el conteo de 30 s', () {
      final s = conBasal();
      serie(s, 61, 80, 23);
      s.agregar(81, 20);
      serie(s, 82, 110, 23); // 28 s desde el reinicio
      expect(s.estado, EstadoSemaforo.verde);
    });

    test('rojo por centil 99 de la edad (8 años: > 25)', () {
      final s = conBasal(edad: 8);
      s.agregar(61, 25);
      expect(s.estado, isNot(EstadoSemaforo.rojo));
      s.agregar(62, 26);
      expect(s.estado, EstadoSemaforo.rojo);
    });

    test('rojo aunque la basal sea alta', () {
      final s = SemaforoFr(edad: 7);
      serie(s, 0, 60, 26); // basal alta, límite 28.6
      s.agregar(61, 28); // bajo el límite verde pero > 27
      expect(s.estado, EstadoSemaforo.rojo);
    });

    test('sin umbrales para edades fuera de 6–8', () {
      final s = SemaforoFr(edad: 10);
      expect(s.umbrales, isNull);
      serie(s, 0, 60, 40);
      expect(s.basalFueraDeRango, isFalse);
      s.agregar(61, 41);
      expect(s.estado, EstadoSemaforo.verde);
    });
  });

  test('edadDesde acepta int, num y texto', () {
    expect(edadDesde(7), 7);
    expect(edadDesde(7.0), 7);
    expect(edadDesde(' 8 '), 8);
    expect(edadDesde(null), isNull);
  });
}

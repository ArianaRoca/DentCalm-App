import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

import 'package:fl_chart/fl_chart.dart' show FlSpot;

import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/ui.dart';
import '../services/ble_service.dart';
import '../theme/zona_calma.dart';

class MonitoringScreen extends StatefulWidget {
  final DocumentSnapshot patient;

  const MonitoringScreen({super.key, required this.patient});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final BleService _ble = BleService.instance;

  Timer? timerDuracion;
  int segundos = 0;

  int frActual = 0; // 0 hasta recibir el primer dato
  final List<int> valoresFR = [];
  bool monitoreando = false;
  bool pausado = false;

  VentanaFr _ventana = VentanaFr.unMinuto;

  // Suscripción al stream de FR del BleService. Al salir o finalizar SOLO
  // se cancela esta suscripción: la banda sigue conectada.
  StreamSubscription<int>? _frSub;

  /// Puntos de la gráfica: x = segundo de la sesión, y = rpm.
  final List<FlSpot> puntosFR = [];

  /// Semáforo basado en la basal de este niño (usa su edad de Firestore).
  late final SemaforoFr _semaforo = SemaforoFr(
    edad: edadDesde((widget.patient.data() as Map<String, dynamic>)['edad']),
  );

  bool get dispositivoConectado => _ble.conectado;

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onCambioBle);

    _frSub = _ble.frStream.listen((frRecibida) {
      if (pausado) return; // en pausa no se registran datos
      setState(() {
        frActual = frRecibida;
        valoresFR.add(frActual);
        puntosFR.add(FlSpot(segundos.toDouble(), frRecibida.toDouble()));
        _semaforo.agregar(segundos.toDouble(), frRecibida.toDouble());
      });
    });

    // Si la banda ya estaba conectada, la sesión empieza de inmediato.
    if (_ble.conectado) _iniciarMonitoreo();
  }

  void _onCambioBle() {
    if (!mounted) return;
    // La sesión empieza la primera vez que hay conexión. Si luego se cae,
    // el cronómetro sigue y los datos vuelven cuando el BleService reconecta.
    if (_ble.conectado && !monitoreando) _iniciarMonitoreo();
    setState(() {});
  }

  void _iniciarMonitoreo() {
    monitoreando = true;
    _iniciarCronometro();
  }

  // Botón "Conectar dispositivo" (solo si no hay conexión).
  Future<void> conectarDispositivo() async {
    final ok = await _ble.conectar();
    if (!ok && _ble.ultimoError != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_ble.ultimoError!)));
    }
  }

  void _iniciarCronometro() {
    timerDuracion?.cancel();
    timerDuracion = Timer.periodic(const Duration(seconds: 1), (_) {
      if (monitoreando && !pausado) {
        setState(() => segundos++);
      }
    });
  }

  void _alternarPausa() => setState(() => pausado = !pausado);

  /// "Repetir medición" de la basal.
  void _repetirBasal() => setState(_semaforo.reiniciarBasal);

  double get frPromedio {
    if (valoresFR.isEmpty) return 0;
    final suma = valoresFR.reduce((a, b) => a + b);
    return suma / valoresFR.length;
  }

  int get frMinima {
    if (valoresFR.isEmpty) return 0;
    return valoresFR.reduce(min);
  }

  int get frMaxima {
    if (valoresFR.isEmpty) return 0;
    return valoresFR.reduce(max);
  }

  String get tiempoFormateado {
    final minutos = segundos ~/ 60;
    final segundosRestantes = segundos % 60;
    return '${minutos.toString().padLeft(2, '0')}:${segundosRestantes.toString().padLeft(2, '0')}';
  }

  void _cancelarSuscripciones() {
    timerDuracion?.cancel();
    _frSub?.cancel();
    _frSub = null;
    _ble.removeListener(_onCambioBle);
  }

  void finalizarSesion() {
    _cancelarSuscripciones();

    setState(() {
      monitoreando = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackScreen(
          patient: widget.patient,
          frPromedio: frPromedio,
          frMinima: frMinima,
          frMaxima: frMaxima,
          duracion: segundos,
          basalMedia: _semaforo.mediaBasal,
          basalDesvio: _semaforo.desvioBasal,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cancelarSuscripciones();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final datos = widget.patient.data() as Map<String, dynamic>;
    final nombre = (datos['nombre'] ?? 'Sin nombre').toString();
    final ancho = MediaQuery.sizeOf(context).width;
    final dosColumnas = ancho >= 1180;

    final tarjetaFr = _TarjetaFrecuencia(
      frActual: frActual,
      conectado: dispositivoConectado,
      estado: _ble.estado,
      reconectando: _ble.reconectando,
      pausado: pausado,
      puedeFinalizar: monitoreando,
      onFinalizar: finalizarSesion,
      onPausar: _alternarPausa,
      onConectar: conectarDispositivo,
      semaforo: _semaforo,
      onRepetirBasal: _repetirBasal,
    );

    final tarjetaGrafica = GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Frecuencia respiratoria',
                      style: AppText.titulo(size: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(switch (_ventana) {
                      VentanaFr.unMinuto => 'Último minuto',
                      VentanaFr.cincoMinutos => 'Últimos 5 minutos',
                      VentanaFr.sesion => 'Toda la sesión',
                    }, style: AppText.texto(size: 13, color: Colors.grey)),
                  ],
                ),
              ),
              _PestanasVentana(
                actual: _ventana,
                onCambio: (v) => setState(() => _ventana = v),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 300,
            child: FrEnVivoChart(
              puntos: puntosFR,
              ventana: _ventana,
              bandaDesde: _semaforo.mediaBasal,
              bandaHasta: _semaforo.limiteVerde,
              umbralRojo: _semaforo.umbrales?.centil99,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _Leyenda(
                color: EstadoSemaforo.verde.color.withValues(alpha: 0.35),
                texto: _semaforo.basalLista
                    ? 'Zona calma de este niño '
                          '(${_semaforo.mediaBasal!.toStringAsFixed(1)}–'
                          '${_semaforo.limiteVerde!.toStringAsFixed(1)} rpm)'
                    : 'Zona calma: se calcula tras la basal',
              ),
              if (_semaforo.umbrales != null)
                _Leyenda(
                  color: AppTheme.danger.withValues(alpha: 0.6),
                  texto:
                      'Centil 99 por edad '
                      '(${_semaforo.umbrales!.centil99.toInt()} rpm)',
                ),
              const _Leyenda(
                color: AppTheme.danger,
                texto: 'Máximo',
                punto: true,
              ),
              const _Leyenda(
                color: AppTheme.accent,
                texto: 'Mínimo',
                punto: true,
              ),
            ],
          ),
        ],
      ),
    );

    final tarjetasStats = [
      _StatCard(
        title: 'Promedio',
        value: valoresFR.isEmpty ? '--' : frPromedio.toStringAsFixed(1),
        unidad: 'rpm',
      ),
      _StatCard(
        title: 'Mínima',
        value: valoresFR.isEmpty ? '--' : '$frMinima',
        unidad: 'rpm',
      ),
      _StatCard(
        title: 'Máxima',
        value: valoresFR.isEmpty ? '--' : '$frMaxima',
        unidad: 'rpm',
      ),
      _StatCard(title: 'Duración', value: tiempoFormateado, unidad: 'min'),
    ];

    // 4 en fila; en pantallas angostas, 2 por fila.
    final estadisticas = LayoutBuilder(
      builder: (context, c) {
        final porFila = c.maxWidth >= 720 ? 4 : 2;
        const espacio = 16.0;
        final ancho = (c.maxWidth - espacio * (porFila - 1)) / porFila;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final t in tarjetasStats) SizedBox(width: ancho, child: t),
          ],
        );
      },
    );

    return AppBackground(
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          titleSpacing: 4,
          title: Text(
            nombre,
            overflow: TextOverflow.ellipsis,
            style: AppText.titulo(size: 22),
          ),
          actions: [
            _ChipEnVivo(
              estado: _ble.estado,
              reconectando: _ble.reconectando,
              pausado: pausado,
              dispositivo: _ble.nombreDispositivo,
            ),
            const SizedBox(width: 24),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (dosColumnas)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 340, child: tarjetaFr),
                      const SizedBox(width: 20),
                      Expanded(child: tarjetaGrafica),
                    ],
                  ),
                )
              else ...[
                tarjetaFr,
                const SizedBox(height: 20),
                tarjetaGrafica,
              ],
              const SizedBox(height: 20),
              estadisticas,
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// TARJETA "FRECUENCIA ACTUAL"
// =====================================================
class _TarjetaFrecuencia extends StatelessWidget {
  final int frActual;
  final bool conectado;
  final BleEstado estado;
  final bool reconectando;
  final bool pausado;
  final bool puedeFinalizar;
  final VoidCallback onFinalizar;
  final VoidCallback onPausar;
  final VoidCallback onConectar;
  final SemaforoFr semaforo;
  final VoidCallback onRepetirBasal;

  const _TarjetaFrecuencia({
    required this.frActual,
    required this.conectado,
    required this.estado,
    required this.reconectando,
    required this.pausado,
    required this.puedeFinalizar,
    required this.onFinalizar,
    required this.onPausar,
    required this.onConectar,
    required this.semaforo,
    required this.onRepetirBasal,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hayDato = frActual > 0;

    // Semáforo (basado en la basal de este niño).
    final estadoSem = semaforo.estado;
    final (String textoZona, Color colorZona, IconData iconoZona) = !hayDato
        ? ('Esperando datos', Colors.grey, AppIcons.wind)
        : (
            estadoSem.texto,
            estadoSem.color,
            switch (estadoSem) {
              EstadoSemaforo.midiendoBasal => AppIcons.timer,
              EstadoSemaforo.verde => AppIcons.smiley,
              EstadoSemaforo.ambar => AppIcons.trendUp,
              EstadoSemaforo.rojo => AppIcons.warningCircle,
            },
          );

    final colorAro = !conectado || !hayDato
        ? Colors.grey.withValues(alpha: 0.35)
        : colorZona;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Frecuencia actual', style: AppText.titulo(size: 18)),
          const SizedBox(height: 24),

          // Número grande + "RPM" dentro de un círculo
          Center(
            child: Container(
              width: 196,
              height: 196,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorAro.withValues(alpha: 0.08),
                border: Border.all(color: colorAro, width: 6),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hayDato ? '$frActual' : '--',
                    style: AppText.titulo(
                      size: 64,
                      weight: FontWeight.w700,
                      color: hayDato ? scheme.onSurface : Colors.grey,
                    ),
                  ),
                  Text(
                    'RPM',
                    style: AppText.texto(
                      size: 14,
                      weight: FontWeight.w800,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colorZona.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconoZona, size: 18, color: colorZona),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      textoZona,
                      style: AppText.texto(
                        size: 14,
                        weight: FontWeight.w700,
                        color: colorZona,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _InfoBasal(semaforo: semaforo, onRepetir: onRepetirBasal),

          const SizedBox(height: 24),

          if (!conectado) ...[
            PrimaryButton(
              label: estado == BleEstado.conectando
                  ? (reconectando
                        ? 'Reconectando la banda...'
                        : 'Conectando...')
                  : 'Conectar dispositivo',
              icon: AppIcons.bluetooth,
              loading: estado == BleEstado.conectando,
              onPressed: estado == BleEstado.desconectado ? onConectar : null,
            ),
            const SizedBox(height: 12),
          ],

          ElevatedButton.icon(
            onPressed: puedeFinalizar ? onFinalizar : null,
            icon: const Icon(AppIcons.stopCircle),
            label: const Text('Finalizar sesión'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: puedeFinalizar ? onPausar : null,
            icon: Icon(pausado ? AppIcons.play : AppIcons.pause),
            label: Text(pausado ? 'Reanudar' : 'Pausar'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// INFORMACIÓN DE LA BASAL
// =====================================================
class _InfoBasal extends StatelessWidget {
  final SemaforoFr semaforo;
  final VoidCallback onRepetir;

  const _InfoBasal({required this.semaforo, required this.onRepetir});

  @override
  Widget build(BuildContext context) {
    final gris = AppText.texto(size: 12, color: Colors.grey);

    final List<Widget> lineas;
    if (!semaforo.basalLista) {
      final seg = (semaforo.progresoBasal * ParametrosSemaforo.ventanaBasalSeg)
          .round();
      lineas = [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: semaforo.progresoBasal,
            minHeight: 5,
            color: EstadoSemaforo.midiendoBasal.color,
            backgroundColor: EstadoSemaforo.midiendoBasal.color.withValues(
              alpha: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Basal: $seg de ${ParametrosSemaforo.ventanaBasalSeg.toInt()} s',
          textAlign: TextAlign.center,
          style: gris,
        ),
      ];
    } else {
      final sobre = semaforo.segundosSobreLimite;
      lineas = [
        Text(
          'Basal ${semaforo.mediaBasal!.toStringAsFixed(1)} ± '
          '${semaforo.desvioBasal!.toStringAsFixed(1)} rpm · '
          'límite verde ${semaforo.limiteVerde!.toStringAsFixed(1)} rpm',
          textAlign: TextAlign.center,
          style: gris,
        ),
        if (semaforo.estado == EstadoSemaforo.verde && sobre > 0)
          Text(
            'Sobre el límite hace ${sobre.toInt()} s '
            '(ámbar a los ${ParametrosSemaforo.sostenidoSeg.toInt()} s)',
            textAlign: TextAlign.center,
            style: AppText.texto(
              size: 12,
              weight: FontWeight.w700,
              color: EstadoSemaforo.ambar.color,
            ),
          ),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...lineas,
        if (semaforo.umbrales == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Sin umbrales por edad para este paciente '
              '(definidos para 6–8 años).',
              textAlign: TextAlign.center,
              style: gris,
            ),
          ),
        if (semaforo.basalFueraDeRango) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Basal fuera de rango, repetir medición',
                  textAlign: TextAlign.center,
                  style: AppText.texto(
                    size: 13,
                    weight: FontWeight.w800,
                    color: AppTheme.danger,
                  ),
                ),
                Text(
                  'Rango esperado: ${semaforo.umbrales!.basalMin.toInt()}–'
                  '${semaforo.umbrales!.basalMax.toInt()} rpm',
                  style: gris,
                ),
                TextButton.icon(
                  onPressed: onRepetir,
                  icon: const Icon(AppIcons.arrowsClockwise, size: 18),
                  label: const Text('Repetir medición'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// =====================================================
// CHIP "EN VIVO · ESP32"
// =====================================================
class _ChipEnVivo extends StatelessWidget {
  final BleEstado estado;
  final bool reconectando;
  final bool pausado;
  final String? dispositivo;

  const _ChipEnVivo({
    required this.estado,
    required this.reconectando,
    required this.pausado,
    required this.dispositivo,
  });

  @override
  Widget build(BuildContext context) {
    final (String texto, Color color) = switch (estado) {
      BleEstado.conectado when pausado => ('En pausa', const Color(0xFFE08A1E)),
      BleEstado.conectado => ('En vivo · ESP32', const Color(0xFF20A86B)),
      BleEstado.conectando => (
        reconectando ? 'Reconectando...' : 'Conectando...',
        const Color(0xFFF5A524),
      ),
      BleEstado.desconectado => ('Sin conexión', Colors.grey),
    };

    return Tooltip(
      message: dispositivo == null
          ? 'Banda respiratoria'
          : 'Dispositivo: $dispositivo',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              texto,
              style: AppText.texto(
                size: 13,
                weight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// PESTAÑAS 1 min / 5 min / Sesión
// =====================================================
class _PestanasVentana extends StatelessWidget {
  final VentanaFr actual;
  final ValueChanged<VentanaFr> onCambio;

  const _PestanasVentana({required this.actual, required this.onCambio});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.softSurface(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in VentanaFr.values)
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => onCambio(v),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: v == actual ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    v.etiqueta,
                    style: AppText.texto(
                      size: 13,
                      weight: FontWeight.w700,
                      color: v == actual
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  final Color color;
  final String texto;
  final bool punto;

  const _Leyenda({
    required this.color,
    required this.texto,
    this.punto = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: punto ? 10 : 18,
          height: 10,
          decoration: BoxDecoration(
            color: punto ? Colors.white : color,
            border: punto ? Border.all(color: color, width: 2.5) : null,
            borderRadius: BorderRadius.circular(punto ? 5 : 3),
          ),
        ),
        const SizedBox(width: 6),
        Text(texto, style: AppText.texto(size: 12, color: Colors.grey)),
      ],
    );
  }
}

// =====================================================
// TARJETA DE ESTADÍSTICA
// =====================================================
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unidad;

  const _StatCard({
    required this.title,
    required this.value,
    required this.unidad,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.texto(size: 14, color: Colors.grey)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppText.titulo(
                  size: 26,
                  weight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Text(unidad, style: AppText.texto(size: 13, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================
// FINALIZAR SESIÓN (FEEDBACK)
// =====================================================

class FeedbackScreen extends StatefulWidget {
  final DocumentSnapshot patient;
  final double frPromedio;
  final int frMinima;
  final int frMaxima;
  final int duracion;

  /// μ_b y σ_b de la basal (null si no se completó la medición).
  final double? basalMedia;
  final double? basalDesvio;

  const FeedbackScreen({
    super.key,
    required this.patient,
    required this.frPromedio,
    required this.frMinima,
    required this.frMaxima,
    required this.duracion,
    this.basalMedia,
    this.basalDesvio,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  String? nivelAnsiedad;

  final feedbackController = TextEditingController();

  bool guardando = false;

  Future<void> guardarSesion() async {
    if (nivelAnsiedad == null || feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa el nivel de inquietud y el feedback.'),
        ),
      );

      return;
    }

    setState(() {
      guardando = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('sesiones').add({
        'patientId': widget.patient.id,
        'dentistId': user?.uid,
        'frPromedio': widget.frPromedio,
        'frMinima': widget.frMinima,
        'frMaxima': widget.frMaxima,
        'duracionSegundos': widget.duracion,
        'nivelAnsiedad': nivelAnsiedad,
        // Basal del semáforo (si se completó la medición).
        if (widget.basalMedia != null) 'basalMedia': widget.basalMedia,
        if (widget.basalDesvio != null) 'basalDesvio': widget.basalDesvio,
        'feedback': feedbackController.text.trim(),
        'fecha': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión guardada correctamente.')),
        );

        // Vuelve a la pantalla desde donde se inició la sesión
        // (detalle del paciente, o el Home si se usó "Nueva sesión").
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la sesión: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          guardando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,

          title: const Text(
            'Finalizar sesión',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: const [ThemeToggleButton(), SizedBox(width: 10)],
        ),

        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),

            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),

              child: Card(
                elevation: 0,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),

                child: Padding(
                  padding: const EdgeInsets.all(30),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'Resumen de la sesión',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 25),

                      Row(
                        children: [
                          Expanded(
                            child: _ResultCard(
                              title: 'FR promedio',
                              value:
                                  '${widget.frPromedio.toStringAsFixed(1)} rpm',
                            ),
                          ),

                          const SizedBox(width: 15),

                          Expanded(
                            child: _ResultCard(
                              title: 'FR mínima',
                              value: '${widget.frMinima} rpm',
                            ),
                          ),

                          const SizedBox(width: 15),

                          Expanded(
                            child: _ResultCard(
                              title: 'FR máxima',
                              value: '${widget.frMaxima} rpm',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      const Text(
                        'Nivel de inquietud observado',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 15),

                      DropdownButtonFormField<String>(
                        initialValue: nivelAnsiedad,

                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(AppIcons.smiley),
                        ),

                        items: const [
                          DropdownMenuItem(value: 'Bajo', child: Text('Bajo')),
                          DropdownMenuItem(
                            value: 'Moderado',
                            child: Text('Moderado'),
                          ),
                          DropdownMenuItem(value: 'Alto', child: Text('Alto')),
                        ],

                        onChanged: (value) {
                          setState(() {
                            nivelAnsiedad = value;
                          });
                        },
                      ),

                      const SizedBox(height: 25),

                      const Text(
                        'Feedback del odontólogo',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 15),

                      TextField(
                        controller: feedbackController,

                        maxLines: 5,

                        decoration: const InputDecoration(
                          hintText: 'Describe brevemente cómo fue la sesión y el nivel de inquietud observado...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,

                        child: PrimaryButton(
                          label: guardando ? 'Guardando...' : 'Guardar sesión',
                          icon: AppIcons.floppyDisk,
                          loading: guardando,
                          onPressed: guardarSesion,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String value;

  const _ResultCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.softSurface(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

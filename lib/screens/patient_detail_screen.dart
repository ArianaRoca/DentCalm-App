import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/pdf_report.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/zona_calma.dart';
import '../widgets/charts.dart';
import '../widgets/ui.dart';
import 'monitoring_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final DocumentSnapshot patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

DateTime? _fechaDe(Map<String, dynamic> d) {
  final f = d['fecha'];
  return f is Timestamp ? f.toDate() : null;
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  bool _exportando = false;

  Map<String, dynamic> get _datos =>
      widget.patient.data() as Map<String, dynamic>;

  void _nuevaSesion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MonitoringScreen(patient: widget.patient),
      ),
    );
  }

  Future<void> _exportar(List<Map<String, dynamic>> sesiones) async {
    setState(() => _exportando = true);
    try {
      await PdfReport.exportarPaciente(
        paciente: _datos,
        sesiones: sesiones,
        fechas: sesiones.map(_fechaDe).toList(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar el PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Paciente')),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sesiones')
              .where('patientId', isEqualTo: widget.patient.id)
              .snapshots(),
          builder: (context, snapshot) {
            final cargando =
                snapshot.connectionState == ConnectionState.waiting;

            // Orden por fecha, de la más antigua a la más reciente
            // (en la app; la consulta no cambia).
            final sesiones =
                (snapshot.data?.docs ?? [])
                    .map((d) => d.data() as Map<String, dynamic>)
                    .toList()
                  ..sort((a, b) {
                    final fa = _fechaDe(a), fb = _fechaDe(b);
                    if (fa == null && fb == null) return 0;
                    // Sin fecha = pendiente de guardar (la más nueva)
                    if (fa == null) return 1;
                    if (fb == null) return -1;
                    return fa.compareTo(fb);
                  });

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 32, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TarjetaPaciente(
                    datos: _datos,
                    numSesiones: cargando ? null : sesiones.length,
                    exportando: _exportando,
                    onNuevaSesion: _nuevaSesion,
                    onExportar: cargando ? null : () => _exportar(sesiones),
                  ),
                  const SizedBox(height: 20),

                  if (snapshot.hasError)
                    GlassCard(
                      child: Text(
                        'Error al cargar las sesiones:\n${snapshot.error}',
                        style: AppText.texto(color: AppTheme.danger),
                      ),
                    )
                  else if (cargando)
                    const GlassCard(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (sesiones.isEmpty)
                    GlassCard(
                      child: EmptyState(
                        titulo: 'Sin sesiones todavía',
                        mensaje:
                            'Cuando realices la primera sesión de monitoreo\n'
                            'con este paciente, verás aquí su evolución.',
                        accion: PrimaryButton(
                          label: 'Iniciar sesión de monitoreo',
                          icon: AppIcons.play,
                          onPressed: _nuevaSesion,
                        ),
                      ),
                    )
                  else ...[
                    _TarjetaGrafica(sesiones: sesiones),
                    const SizedBox(height: 20),
                    _TablaSesiones(sesiones: sesiones.reversed.toList()),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// =====================================================
// TARJETA DEL PACIENTE
// =====================================================

class _TarjetaPaciente extends StatelessWidget {
  final Map<String, dynamic> datos;
  final int? numSesiones;
  final bool exportando;
  final VoidCallback onNuevaSesion;
  final VoidCallback? onExportar;

  const _TarjetaPaciente({
    required this.datos,
    required this.numSesiones,
    required this.exportando,
    required this.onNuevaSesion,
    required this.onExportar,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = (datos['nombre'] ?? 'Sin nombre').toString();
    final edad = datos['edad'];
    final codigo = (datos['codigo'] ?? '').toString();
    final notas = (datos['notas'] ?? '').toString();

    Widget dato(String titulo, String valor) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valor,
          style: AppText.titulo(
            size: 22,
            weight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(titulo, style: AppText.texto(size: 13, color: Colors.grey)),
      ],
    );

    final info = Row(
      children: [
        InitialsAvatar(nombre: nombre, size: 72),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre, style: AppText.titulo(size: 26)),
              if (codigo.isNotEmpty)
                Text(
                  'Código: $codigo',
                  style: AppText.texto(size: 14, color: Colors.grey),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 32,
                runSpacing: 8,
                children: [
                  dato('Edad', edad == null ? '—' : '$edad años'),
                  dato('Sesiones', numSesiones == null ? '…' : '$numSesiones'),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final botones = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        PrimaryButton(
          label: 'Nueva sesión',
          icon: AppIcons.play,
          onPressed: onNuevaSesion,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: exportando ? null : onExportar,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          ),
          icon: exportando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.filePdf, size: 20),
          label: Text(exportando ? 'Generando...' : 'Exportar reporte PDF'),
        ),
      ],
    );

    return GlassCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) => c.maxWidth >= 720
                ? Row(
                    children: [
                      Expanded(child: info),
                      const SizedBox(width: 20),
                      SizedBox(width: 240, child: botones),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [info, const SizedBox(height: 20), botones],
                  ),
          ),
          if (notas.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.softSurface(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(AppIcons.notepad, size: 18, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(child: Text(notas, style: AppText.texto())),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================
// GRÁFICA POR SESIÓN
// =====================================================

class _TarjetaGrafica extends StatelessWidget {
  final List<Map<String, dynamic>> sesiones;

  const _TarjetaGrafica({required this.sesiones});

  @override
  Widget build(BuildContext context) {
    double? n(dynamic v) => v is num ? v.toDouble() : null;
    final puntos = [
      for (final s in sesiones)
        if (n(s['frPromedio']) case final prom?)
          PuntoSesion(
            fecha: _fechaDe(s),
            promedio: prom,
            minima: n(s['frMinima']),
            maxima: n(s['frMaxima']),
            basalMedia: n(s['basalMedia']),
            basalDesvio: n(s['basalDesvio']),
          ),
    ];
    if (puntos.isEmpty) return const SizedBox.shrink();

    final azul = Theme.of(context).colorScheme.primary;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FR por sesión', style: AppText.titulo(size: 18)),
          Text(
            'Promedio y rango mínimo–máximo de cada sesión',
            style: AppText.texto(size: 13, color: Colors.grey),
          ),
          const SizedBox(height: 18),
          SizedBox(height: 280, child: FrPorSesionChart(sesiones: puntos)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _Leyenda(color: azul, texto: 'Promedio', punto: true),
              _Leyenda(
                color: azul.withValues(alpha: 0.3),
                texto: 'Rango mín–máx',
              ),
              _Leyenda(
                color: AppTheme.accent.withValues(alpha: 0.35),
                texto: 'Zona calma de cada sesión (basal → límite verde)',
              ),
            ],
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
            color: color,
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
// TABLA DE SESIONES
// =====================================================

class _TablaSesiones extends StatelessWidget {
  /// De la más reciente a la más antigua.
  final List<Map<String, dynamic>> sesiones;

  const _TablaSesiones({required this.sesiones});

  static const _flex = [3, 2, 2, 1, 1, 2];

  void _verDetalle(BuildContext context, Map<String, dynamic> s) {
    final feedback = (s['feedback'] ?? '').toString();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Glass.radius),
        ),
        title: Text(
          'Sesión del ${_fechaTexto(_fechaDe(s))}',
          style: AppText.titulo(size: 19),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fila('Duración', _duracion(s)),
              _fila('FR promedio', _fr(s['frPromedio'], decimales: 1)),
              _fila('FR mínima', _fr(s['frMinima'])),
              _fila('FR máxima', _fr(s['frMaxima'])),
              _fila('Basal', _basalTexto(s)),
              _fila('Inquietud', (s['nivelAnsiedad'] ?? '—').toString()),
              const SizedBox(height: 8),
              Text('Feedback', style: AppText.texto(weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                feedback.isEmpty ? '—' : feedback,
                style: AppText.texto(color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  static Widget _fila(String t, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(t, style: AppText.texto(weight: FontWeight.w700)),
        ),
        Expanded(child: Text(v, style: AppText.texto())),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final gris = AppText.texto(
      size: 12,
      weight: FontWeight.w800,
      color: Colors.grey,
    );

    Widget celda(int i, Widget hijo, {bool derecha = false}) => Expanded(
      flex: _flex[i],
      child: Align(
        alignment: derecha ? Alignment.centerRight : Alignment.centerLeft,
        child: hijo,
      ),
    );

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sesiones', style: AppText.titulo(size: 18)),
          Text(
            'Toca una sesión para ver el feedback',
            style: AppText.texto(size: 13, color: Colors.grey),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                celda(0, Text('FECHA', style: gris)),
                celda(1, Text('DURACIÓN', style: gris), derecha: true),
                celda(2, Text('FR PROM.', style: gris), derecha: true),
                celda(3, Text('MÍN.', style: gris), derecha: true),
                celda(4, Text('MÁX.', style: gris), derecha: true),
                celda(
                  5,
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text('INQUIETUD', style: gris),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var i = 0; i < sesiones.length; i++) ...[
            _filaSesion(context, sesiones[i], celda),
            if (i < sesiones.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _filaSesion(
    BuildContext context,
    Map<String, dynamic> s,
    Widget Function(int, Widget, {bool derecha}) celda,
  ) {
    final prom = s['frPromedio'];
    // Verde si el promedio quedó bajo el límite verde de ESA sesión
    // (μ_b + max(k·σ_b, Δ·μ_b)). Sesiones sin basal guardada: sin punto.
    final limite = SemaforoFr.limiteVerdePara(
      (s['basalMedia'] as num?)?.toDouble(),
      (s['basalDesvio'] as num?)?.toDouble(),
    );
    final enZona = prom is num && limite != null && prom < limite;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _verDetalle(context, s),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              celda(
                0,
                Text(
                  _fechaTexto(_fechaDe(s)),
                  style: AppText.texto(weight: FontWeight.w600),
                ),
              ),
              celda(1, Text(_duracion(s)), derecha: true),
              celda(
                2,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (prom is num && limite != null)
                      Tooltip(
                        message: enZona
                            ? 'Promedio bajo el límite verde de la sesión'
                            : 'Promedio sobre el límite verde de la sesión',
                        child: Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: enZona
                                ? EstadoSemaforo.verde.color
                                : EstadoSemaforo.ambar.color,
                          ),
                        ),
                      ),
                    Text(
                      _fr(prom, decimales: 1),
                      style: AppText.texto(weight: FontWeight.w700),
                    ),
                  ],
                ),
                derecha: true,
              ),
              celda(3, Text(_fr(s['frMinima'])), derecha: true),
              celda(4, Text(_fr(s['frMaxima'])), derecha: true),
              celda(
                5,
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    (s['nivelAnsiedad'] ?? '—').toString(),
                    style: AppText.texto(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _dos(int n) => n.toString().padLeft(2, '0');

String _fechaTexto(DateTime? f) => f == null
    ? 'Guardando…'
    : '${_dos(f.day)}/${_dos(f.month)}/${f.year} ${_dos(f.hour)}:${_dos(f.minute)}';

String _duracion(Map<String, dynamic> s) {
  final d = (s['duracionSegundos'] as num?)?.toInt() ?? 0;
  return '${_dos(d ~/ 60)}:${_dos(d % 60)}';
}

String _basalTexto(Map<String, dynamic> s) {
  final m = s['basalMedia'], d = s['basalDesvio'];
  if (m is! num || d is! num) return '—';
  return '${m.toStringAsFixed(1)} ± ${d.toStringAsFixed(1)} rpm';
}

String _fr(dynamic v, {int decimales = 0}) =>
    v is num ? v.toStringAsFixed(decimales) : '—';

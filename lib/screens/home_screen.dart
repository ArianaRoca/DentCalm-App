import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'patient_detail_screen.dart';
import 'patients_screen.dart';

/// Inicio: resumen simple y útil para la doctora.
/// Lee las mismas colecciones de siempre ('pacientes' y 'sesiones'
/// filtradas por dentistId); los cálculos se hacen en la app.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _buscador = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  void _nuevaSesion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PatientsScreen(modoSeleccion: true),
      ),
    );
  }

  void _abrirPaciente(DocumentSnapshot paciente) {
    _buscador.clear();
    setState(() => _busqueda = '');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: paciente)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return AppBackground(
      child: Scaffold(
        body: uid == null
            ? const SizedBox.shrink()
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('pacientes')
                    .where('dentistId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapPacientes) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('sesiones')
                        .where('dentistId', isEqualTo: uid)
                        .snapshots(),
                    builder: (context, snapSesiones) {
                      final pacientes = snapPacientes.data?.docs ?? [];
                      final sesiones = snapSesiones.data?.docs ?? [];
                      final cargando =
                          !snapPacientes.hasData || !snapSesiones.hasData;
                      final error = snapPacientes.error ?? snapSesiones.error;

                      final resumen = _Resumen.calcular(pacientes, sesiones);

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 32, 32, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _encabezado(pacientes),
                            const SizedBox(height: 24),
                            if (error != null)
                              GlassCard(
                                child: Text(
                                  'No se pudieron cargar los datos:\n$error',
                                  style: AppText.texto(color: AppTheme.danger),
                                ),
                              )
                            else ...[
                              _Contadores(resumen: resumen, cargando: cargando),
                              const SizedBox(height: 24),
                              _TablaUltimasSesiones(
                                filas: resumen.ultimas,
                                cargando: cargando,
                                onAbrir: _abrirPaciente,
                                onNuevaSesion: _nuevaSesion,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  /// Título "Inicio" con la fecha, buscador y botón "Nueva sesión".
  Widget _encabezado(List<QueryDocumentSnapshot> pacientes) {
    final q = _busqueda.trim().toLowerCase();
    final coincidencias = q.isEmpty
        ? <QueryDocumentSnapshot>[]
        : pacientes
              .where((p) {
                final d = p.data() as Map<String, dynamic>;
                final nombre = (d['nombre'] ?? '').toString().toLowerCase();
                final codigo = (d['codigo'] ?? '').toString().toLowerCase();
                return nombre.contains(q) || codigo.contains(q);
              })
              .take(6)
              .toList();

    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Inicio', style: AppText.titulo(size: 30)),
        const SizedBox(height: 2),
        Text(
          _fechaLarga(DateTime.now()),
          style: AppText.texto(size: 15, color: Colors.grey),
        ),
      ],
    );

    final buscador = TextField(
      controller: _buscador,
      onChanged: (v) => setState(() => _busqueda = v),
      decoration: InputDecoration(
        hintText: 'Buscar paciente por nombre o código',
        prefixIcon: const Icon(AppIcons.magnifyingGlass),
        isDense: true,
        suffixIcon: _busqueda.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar',
                icon: const Icon(AppIcons.minus),
                onPressed: () {
                  _buscador.clear();
                  setState(() => _busqueda = '');
                },
              ),
      ),
    );

    final boton = PrimaryButton(
      label: 'Nueva sesión',
      icon: AppIcons.plus,
      onPressed: _nuevaSesion,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  titulo,
                  const SizedBox(height: 16),
                  buscador,
                  const SizedBox(height: 12),
                  boton,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: titulo),
                SizedBox(width: 340, child: buscador),
                const SizedBox(width: 12),
                boton,
              ],
            );
          },
        ),

        // Resultados del buscador
        if (q.isNotEmpty) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: coincidencias.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'No hay pacientes que coincidan con "$_busqueda".',
                          style: AppText.texto(color: Colors.grey),
                        ),
                      )
                    : Column(
                        children: [
                          for (final p in coincidencias)
                            Builder(
                              builder: (context) {
                                final d = p.data() as Map<String, dynamic>;
                                final nombre = (d['nombre'] ?? 'Sin nombre')
                                    .toString();
                                return ListTile(
                                  onTap: () => _abrirPaciente(p),
                                  leading: InitialsAvatar(
                                    nombre: nombre,
                                    size: 36,
                                  ),
                                  title: Text(
                                    nombre,
                                    style: AppText.texto(
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Código: ${d['codigo'] ?? p.id}',
                                    style: AppText.texto(
                                      size: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    AppIcons.caretRight,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// =====================================================
// CÁLCULOS
// =====================================================

class _FilaSesion {
  final DocumentSnapshot? paciente;
  final String nombre;
  final DateTime? fecha;
  final int duracionSeg;
  final double? frPromedio;

  /// % de cambio del FR promedio respecto a la sesión anterior del mismo
  /// paciente (null si es su primera sesión).
  final double? cambio;

  const _FilaSesion({
    required this.paciente,
    required this.nombre,
    required this.fecha,
    required this.duracionSeg,
    required this.frPromedio,
    required this.cambio,
  });
}

class _Resumen {
  final int pacientes;
  final int sesiones;
  final int hoy;
  final double? cambioPromedio;
  final List<_FilaSesion> ultimas;

  const _Resumen({
    required this.pacientes,
    required this.sesiones,
    required this.hoy,
    required this.cambioPromedio,
    required this.ultimas,
  });

  static DateTime? _fecha(Map<String, dynamic> d) {
    final f = d['fecha'];
    return f is Timestamp ? f.toDate() : null;
  }

  static _Resumen calcular(
    List<QueryDocumentSnapshot> pacientesDocs,
    List<QueryDocumentSnapshot> sesionesDocs,
  ) {
    final porId = {for (final p in pacientesDocs) p.id: p};
    final ahora = DateTime.now();
    final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);

    // Sesiones ordenadas por fecha (sin fecha = recién guardada, al final).
    final datos =
        sesionesDocs.map((d) => d.data() as Map<String, dynamic>).toList()
          ..sort((a, b) {
            final fa = _fecha(a), fb = _fecha(b);
            if (fa == null && fb == null) return 0;
            if (fa == null) return 1;
            if (fb == null) return -1;
            return fa.compareTo(fb);
          });

    final ultimoFrPorPaciente = <String, double>{};
    final cambios = <double>[];
    final filas = <_FilaSesion>[];
    var hoy = 0;

    for (final s in datos) {
      final f = _fecha(s);
      if (f != null && !f.isBefore(inicioHoy)) hoy++;

      final pid = (s['patientId'] ?? '').toString();
      final fr = s['frPromedio'] is num
          ? (s['frPromedio'] as num).toDouble()
          : null;

      double? cambio;
      final previo = ultimoFrPorPaciente[pid];
      if (fr != null && fr > 0) {
        if (previo != null && previo > 0) {
          cambio = (fr - previo) / previo * 100;
          cambios.add(cambio);
        }
        ultimoFrPorPaciente[pid] = fr;
      }

      final paciente = porId[pid];
      final datosPaciente = paciente?.data() as Map<String, dynamic>?;
      filas.add(
        _FilaSesion(
          paciente: paciente,
          nombre: (datosPaciente?['nombre'] ?? 'Paciente no encontrado')
              .toString(),
          fecha: f,
          duracionSeg: (s['duracionSegundos'] as num?)?.toInt() ?? 0,
          frPromedio: fr,
          cambio: cambio,
        ),
      );
    }

    return _Resumen(
      pacientes: pacientesDocs.length,
      sesiones: sesionesDocs.length,
      hoy: hoy,
      cambioPromedio: cambios.isEmpty
          ? null
          : cambios.reduce((a, b) => a + b) / cambios.length,
      ultimas: filas.reversed.take(10).toList(),
    );
  }
}

// =====================================================
// CONTADORES
// =====================================================

class _Contadores extends StatelessWidget {
  final _Resumen resumen;
  final bool cargando;

  const _Contadores({required this.resumen, required this.cargando});

  @override
  Widget build(BuildContext context) {
    String v(String s) => cargando ? '…' : s;
    final cambio = resumen.cambioPromedio;

    final items = [
      _Contador(
        icon: AppIcons.usersThree,
        titulo: 'Pacientes',
        valor: v('${resumen.pacientes}'),
      ),
      _Contador(
        icon: AppIcons.notepad,
        titulo: 'Sesiones totales',
        valor: v('${resumen.sesiones}'),
      ),
      _Contador(
        icon: AppIcons.calendarBlank,
        titulo: 'Sesiones hoy',
        valor: v('${resumen.hoy}'),
      ),
      _Contador(
        icon: AppIcons.wind,
        titulo: 'Cambio promedio de FR',
        valor: v(cambio == null ? '—' : _porcentaje(cambio)),
        color: cambio == null ? null : _colorCambio(context, cambio),
        ayuda:
            'Promedio del cambio del FR promedio de cada sesión '
            'respecto a la sesión anterior del mismo paciente.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final porFila = c.maxWidth >= 900 ? 4 : 2;
        const espacio = 16.0;
        final ancho = (c.maxWidth - espacio * (porFila - 1)) / porFila;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [for (final i in items) SizedBox(width: ancho, child: i)],
        );
      },
    );
  }
}

class _Contador extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String valor;
  final Color? color;
  final String? ayuda;

  const _Contador({
    required this.icon,
    required this.titulo,
    required this.valor,
    this.color,
    this.ayuda,
  });

  @override
  Widget build(BuildContext context) {
    final tarjeta = GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconBadge(icon: icon, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: AppText.titulo(
                    size: 26,
                    weight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  titulo,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.texto(size: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return ayuda == null ? tarjeta : Tooltip(message: ayuda, child: tarjeta);
  }
}

// =====================================================
// TABLA "ÚLTIMAS SESIONES"
// =====================================================

class _TablaUltimasSesiones extends StatelessWidget {
  final List<_FilaSesion> filas;
  final bool cargando;
  final ValueChanged<DocumentSnapshot> onAbrir;
  final VoidCallback onNuevaSesion;

  const _TablaUltimasSesiones({
    required this.filas,
    required this.cargando,
    required this.onAbrir,
    required this.onNuevaSesion,
  });

  static const _flex = [4, 3, 2, 2, 2];

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
          Text('Últimas sesiones', style: AppText.titulo(size: 18)),
          const SizedBox(height: 14),

          if (cargando)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filas.isEmpty)
            EmptyState(
              titulo: 'Todavía no hay sesiones',
              mensaje:
                  'Cuando termines tu primera sesión de monitoreo,\n'
                  'aparecerá aquí con su resumen.',
              accion: PrimaryButton(
                label: 'Nueva sesión',
                icon: AppIcons.plus,
                onPressed: onNuevaSesion,
              ),
            )
          else ...[
            // Encabezado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  celda(0, Text('PACIENTE', style: gris)),
                  celda(1, Text('FECHA', style: gris)),
                  celda(2, Text('DURACIÓN', style: gris), derecha: true),
                  celda(3, Text('FR PROM.', style: gris), derecha: true),
                  celda(4, Text('CAMBIO', style: gris), derecha: true),
                ],
              ),
            ),
            const Divider(height: 1),

            for (final f in filas) ...[
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: f.paciente == null ? null : () => onAbrir(f.paciente!),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        celda(
                          0,
                          Row(
                            children: [
                              InitialsAvatar(nombre: f.nombre, size: 34),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  f.nombre,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.texto(weight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        celda(
                          1,
                          Text(
                            f.fecha == null
                                ? 'Guardando…'
                                : _fechaCorta(f.fecha!),
                            style: AppText.texto(size: 14, color: Colors.grey),
                          ),
                        ),
                        celda(
                          2,
                          Text(
                            _duracion(f.duracionSeg),
                            style: AppText.texto(),
                          ),
                          derecha: true,
                        ),
                        celda(
                          3,
                          Text(
                            f.frPromedio == null
                                ? '—'
                                : '${f.frPromedio!.toStringAsFixed(1)} rpm',
                            style: AppText.texto(weight: FontWeight.w700),
                          ),
                          derecha: true,
                        ),
                        celda(
                          4,
                          f.cambio == null
                              ? Text(
                                  'Primera',
                                  style: AppText.texto(
                                    size: 13,
                                    color: Colors.grey,
                                  ),
                                )
                              : _ChipCambio(cambio: f.cambio!),
                          derecha: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (f != filas.last) const Divider(height: 1),
            ],
          ],
        ],
      ),
    );
  }
}

class _ChipCambio extends StatelessWidget {
  final double cambio;

  const _ChipCambio({required this.cambio});

  @override
  Widget build(BuildContext context) {
    final color = _colorCambio(context, cambio);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            cambio < 0 ? AppIcons.trendDown : AppIcons.trendUp,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            _porcentaje(cambio),
            style: AppText.texto(
              size: 13,
              weight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// FORMATOS
// =====================================================

/// Bajar la FR suele indicar más calma (turquesa); subirla, ámbar.
Color _colorCambio(BuildContext context, double cambio) => cambio.abs() < 0.05
    ? Colors.grey
    : cambio < 0
    ? Theme.of(context).colorScheme.secondary
    : const Color(0xFFE08A1E);

String _porcentaje(double v) => '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}%';

String _dos(int n) => n.toString().padLeft(2, '0');

String _fechaCorta(DateTime f) =>
    '${_dos(f.day)}/${_dos(f.month)}/${f.year} ${_dos(f.hour)}:${_dos(f.minute)}';

String _duracion(int s) => '${_dos(s ~/ 60)}:${_dos(s % 60)}';

const _dias = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _fechaLarga(DateTime f) {
  final dia = _dias[f.weekday - 1];
  return '${dia[0].toUpperCase()}${dia.substring(1)}, ${f.day} de '
      '${_meses[f.month - 1]} de ${f.year}';
}

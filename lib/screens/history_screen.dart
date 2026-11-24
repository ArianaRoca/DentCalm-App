import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'patient_detail_screen.dart';

/// Historial de TODAS las sesiones del odontólogo, de la más reciente
/// a la más antigua.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return AppBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Historial de sesiones',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: const [ThemeToggleButton(), SizedBox(width: 10)],
        ),
        body: uid == null
            ? const _Mensaje(
                icon: AppIcons.lockSimple,
                texto: 'Inicia sesión para ver el historial.',
              )
            // Pacientes del odontólogo (para mostrar el nombre y abrir el detalle)
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
                      if (snapPacientes.hasError || snapSesiones.hasError) {
                        return _Mensaje(
                          icon: AppIcons.warningCircle,
                          texto:
                              'Error al cargar el historial:\n${snapSesiones.error ?? snapPacientes.error}',
                        );
                      }

                      if (!snapPacientes.hasData || !snapSesiones.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final pacientes = {
                        for (final doc in snapPacientes.data!.docs) doc.id: doc,
                      };

                      // Se ordena en la app para no requerir un índice
                      // compuesto en Firestore (dentistId + fecha).
                      final sesiones = [...snapSesiones.data!.docs]
                        ..sort((a, b) {
                          final fa = _fecha(a);
                          final fb = _fecha(b);
                          // Sin fecha = recién guardada (pendiente) -> arriba
                          if (fa == null && fb == null) return 0;
                          if (fa == null) return -1;
                          if (fb == null) return 1;
                          return fb.compareTo(fa);
                        });

                      if (sesiones.isEmpty) {
                        return const EmptyState(
                          titulo: 'Todavía no hay sesiones',
                          mensaje: 'Cuando termines tu primera sesión de monitoreo,\naparecerá aquí con su resumen.',
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: sesiones.length,
                        itemBuilder: (context, index) {
                          final sesion = sesiones[index];
                          final datos = sesion.data() as Map<String, dynamic>;
                          final paciente = pacientes[datos['patientId']];
                          return FadeInSlide(
                            index: index,
                            child: _SesionCard(
                              datos: datos,
                              fecha: _fecha(sesion),
                              paciente: paciente,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  static DateTime? _fecha(QueryDocumentSnapshot doc) {
    final valor = (doc.data() as Map<String, dynamic>)['fecha'];
    return valor is Timestamp ? valor.toDate() : null;
  }
}

class _SesionCard extends StatelessWidget {
  final Map<String, dynamic> datos;
  final DateTime? fecha;
  final DocumentSnapshot? paciente;

  const _SesionCard({
    required this.datos,
    required this.fecha,
    required this.paciente,
  });

  @override
  Widget build(BuildContext context) {
    final datosPaciente = paciente?.data() as Map<String, dynamic>?;
    final nombre =
        datosPaciente?['nombre']?.toString() ?? 'Paciente no encontrado';

    final fr = datos['frPromedio'];
    final frTexto = fr is num ? '${fr.toStringAsFixed(1)} rpm' : '- rpm';

    final duracion = (datos['duracionSegundos'] as num?)?.toInt() ?? 0;
    final duracionTexto =
        '${(duracion ~/ 60).toString().padLeft(2, '0')}:${(duracion % 60).toString().padLeft(2, '0')}';

    final f = fecha;
    final fechaTexto = f == null
        ? 'Guardando...'
        : '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} '
              '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Pressable(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (paciente == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se encontró el paciente de esta sesión.'),
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatientDetailScreen(patient: paciente!),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              InitialsAvatar(nombre: nombre),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      fechaTexto,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              _Dato(valor: frTexto, titulo: 'FR promedio'),
              const SizedBox(width: 20),
              _Dato(valor: duracionTexto, titulo: 'Duración'),
              const SizedBox(width: 10),
              const Icon(AppIcons.caretRight, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String valor;
  final String titulo;

  const _Dato({required this.valor, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          valor,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class _Mensaje extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _Mensaje({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

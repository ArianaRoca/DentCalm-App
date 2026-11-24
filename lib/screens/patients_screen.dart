import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'new_patient_screen.dart';
import 'patient_detail_screen.dart';
import 'monitoring_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';

class PatientsScreen extends StatefulWidget {
  /// Si es true, la lista sirve para elegir un paciente e ir directo
  /// a la sesión de monitoreo (sin pasar por el detalle).
  final bool modoSeleccion;

  const PatientsScreen({super.key, this.modoSeleccion = false});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Text(
            widget.modoSeleccion ? 'Elegir paciente' : 'Pacientes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            const ThemeToggleButton(),
            Padding(
              padding: const EdgeInsets.only(right: 15),
              child: Center(
                child: PrimaryButton(
                  label: 'Nuevo paciente',
                  icon: AppIcons.plus,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NewPatientScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // BARRA DE BÚSQUEDA
            Container(
              color: Theme.of(context).appBarTheme.backgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o código...',
                  prefixIcon: const Icon(
                    AppIcons.magnifyingGlass,
                    color: Colors.grey,
                  ),
                  filled: true,
                  fillColor: AppTheme.softSurface(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // LISTA DE PACIENTES
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('pacientes')
                    .where(
                      'dentistId',
                      isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                    )
                    .orderBy(
                      'createdAt',
                      descending: true,
                    ) // Ordenar por los más recientes
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error al cargar pacientes:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final pacientes = snapshot.data?.docs ?? [];

                  // FILTRAR PACIENTES SEGÚN LA BÚSQUEDA
                  final pacientesFiltrados = pacientes.where((paciente) {
                    final datos = paciente.data() as Map<String, dynamic>;
                    final nombre = (datos['nombre'] ?? '')
                        .toString()
                        .toLowerCase();
                    final codigo = (datos['codigo'] ?? '')
                        .toString()
                        .toLowerCase();
                    return nombre.contains(searchQuery) ||
                        codigo.contains(searchQuery);
                  }).toList();

                  if (pacientesFiltrados.isEmpty) {
                    if (searchQuery.isNotEmpty) {
                      return const EmptyState(
                        titulo: 'Sin resultados',
                        mensaje: 'No encontramos pacientes con ese nombre o código.\nPrueba con otra búsqueda.',
                      );
                    }
                    return EmptyState(
                      titulo: 'Aún no hay pacientes',
                      mensaje: 'Registra a tu primer paciente para empezar\na monitorear sus sesiones con tranquilidad.',
                      accion: PrimaryButton(
                        label: 'Registrar paciente',
                        icon: AppIcons.userPlus,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NewPatientScreen(),
                            ),
                          );
                        },
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: pacientesFiltrados.length,
                    itemBuilder: (context, index) {
                      final paciente = pacientesFiltrados[index];
                      final datos = paciente.data() as Map<String, dynamic>;
                      final nombre = datos['nombre'] ?? 'Sin nombre';
                      final edad = datos['edad'] ?? '-';
                      final sexo = datos['sexo'] ?? '-';
                      final codigo = datos['codigo'] ?? paciente.id;

                      return FadeInSlide(
                        index: index,
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 15),
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Pressable(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              if (widget.modoSeleccion) {
                                final ruta = MaterialPageRoute(
                                  builder: (_) =>
                                      MonitoringScreen(patient: paciente),
                                );
                                // Si se llegó desde Inicio ("Nueva sesión"),
                                // la lista se reemplaza: al terminar se vuelve
                                // a Inicio. Si es la raíz de la sección
                                // Monitoreo del menú, se apila encima para
                                // volver a esta lista al terminar.
                                if (Navigator.canPop(context)) {
                                  Navigator.pushReplacement(context, ruta);
                                } else {
                                  Navigator.push(context, ruta);
                                }
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PatientDetailScreen(patient: paciente),
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  InitialsAvatar(nombre: nombre.toString()),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nombre.toString(),
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          '$edad años  •  Sexo: $sexo',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Código: $codigo',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    widget.modoSeleccion
                                        ? AppIcons.playCircle
                                        : AppIcons.caretRight,
                                    size: widget.modoSeleccion ? 28 : 22,
                                    color: widget.modoSeleccion
                                        ? Theme.of(context)
                                              .colorScheme
                                              .secondary
                                        : Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

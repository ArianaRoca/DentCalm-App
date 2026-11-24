import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../theme/zona_calma.dart';

/// Genera y descarga/comparte reportes PDF (de una sesión o del paciente).
/// Solo lee los datos que ya se tienen en pantalla (no consulta Firebase).
class PdfReport {
  static const _azul = PdfColor.fromInt(0xFF2983EA);
  static const _turquesa = PdfColor.fromInt(0xFF189C9E);
  static const _navy = PdfColor.fromInt(0xFF12355B);
  static const _gris = PdfColor.fromInt(0xFF6B7A8C);
  static const _fondo = PdfColor.fromInt(0xFFF1F6FD);

  static Future<void> exportarSesion({
    required Map<String, dynamic> paciente,
    required Map<String, dynamic> sesion,
    required DateTime? fecha,
  }) async {
    final regular = await PdfGoogleFonts.nunitoRegular();
    final bold = await PdfGoogleFonts.nunitoBold();
    final extraBold = await PdfGoogleFonts.nunitoExtraBold();
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/images/A_horizontal.png')).buffer
          .asUint8List(),
    );

    final nombre = (paciente['nombre'] ?? 'Sin nombre').toString();
    final codigo = (paciente['codigo'] ?? '-').toString();
    final edad = (paciente['edad'] ?? '-').toString();
    final sexo = switch (paciente['sexo']) {
      'F' => 'Femenino',
      'M' => 'Masculino',
      final otro => (otro ?? '-').toString(),
    };

    String num1(dynamic v) => v is num ? v.toStringAsFixed(1) : '-';
    final duracion = (sesion['duracionSegundos'] as num?)?.toInt() ?? 0;
    final duracionTexto =
        '${(duracion ~/ 60).toString().padLeft(2, '0')}:${(duracion % 60).toString().padLeft(2, '0')} min';
    final fechaTexto = fecha == null ? 'Fecha no disponible' : _fecha(fecha);
    final inquietud = (sesion['nivelAnsiedad'] ?? '-').toString();
    final feedback = (sesion['feedback'] ?? '').toString();

    final doc = pw.Document(
      title: 'Reporte de sesión - $nombre',
      author: 'DentCalm',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    pw.Widget dato(String titulo, String valor) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: _fondo,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              valor,
              style: pw.TextStyle(font: extraBold, fontSize: 18, color: _azul),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              titulo,
              style: const pw.TextStyle(fontSize: 10, color: _gris),
            ),
          ],
        ),
      ),
    );

    pw.Widget fila(String titulo, String valor) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              titulo,
              style: pw.TextStyle(font: bold, color: _navy),
            ),
          ),
          pw.Expanded(child: pw.Text(valor)),
        ],
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(logo, height: 46),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Reporte de sesión',
                      style: pw.TextStyle(
                        font: extraBold,
                        fontSize: 16,
                        color: _navy,
                      ),
                    ),
                    pw.Text(
                      fechaTexto,
                      style: const pw.TextStyle(color: _gris),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              height: 4,
              decoration: const pw.BoxDecoration(
                gradient: pw.LinearGradient(colors: [_azul, _turquesa]),
              ),
            ),
            pw.SizedBox(height: 22),
            pw.Text(
              'Paciente',
              style: pw.TextStyle(font: extraBold, fontSize: 14, color: _navy),
            ),
            pw.SizedBox(height: 8),
            fila('Nombre', nombre),
            fila('Código', codigo),
            fila('Edad', '$edad años'),
            fila('Sexo', sexo),
            pw.SizedBox(height: 18),
            pw.Text(
              'Frecuencia respiratoria',
              style: pw.TextStyle(font: extraBold, fontSize: 14, color: _navy),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                dato('FR promedio', '${num1(sesion['frPromedio'])} rpm'),
                dato('FR mínima', '${sesion['frMinima'] ?? '-'} rpm'),
                dato('FR máxima', '${sesion['frMaxima'] ?? '-'} rpm'),
                dato('Duración', duracionTexto),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Evaluación del odontólogo',
              style: pw.TextStyle(font: extraBold, fontSize: 14, color: _navy),
            ),
            pw.SizedBox(height: 8),
            fila('Nivel de inquietud', inquietud),
            fila('Feedback', feedback.isEmpty ? '-' : feedback),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.Text(
              'Generado con DentCalm · Monitorización respiratoria para la atención odontológica',
              style: const pw.TextStyle(fontSize: 9, color: _gris),
            ),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    final archivo =
        'DentCalm_${nombre.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_${fecha == null ? 'sesion' : _fechaArchivo(fecha)}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: archivo);
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');

  static String _fecha(DateTime f) =>
      '${_dos(f.day)}/${_dos(f.month)}/${f.year} ${_dos(f.hour)}:${_dos(f.minute)}';

  static String _fechaArchivo(DateTime f) =>
      '${f.year}${_dos(f.month)}${_dos(f.day)}_${_dos(f.hour)}${_dos(f.minute)}';

  // ===================================================================
  // REPORTE DEL PACIENTE (todas sus sesiones)
  // ===================================================================

  static const _primario = PdfColor.fromInt(0xFF1E62C8);
  static const _acento = PdfColor.fromInt(0xFF0E7A67);
  static const _texto = PdfColor.fromInt(0xFF13345B);

  /// [sesiones]: datos de cada sesión, de la más antigua a la más reciente.
  /// [fechas]: la fecha de cada sesión (misma posición que [sesiones]).
  static Future<void> exportarPaciente({
    required Map<String, dynamic> paciente,
    required List<Map<String, dynamic>> sesiones,
    required List<DateTime?> fechas,
  }) async {
    final regular = await PdfGoogleFonts.nunitoRegular();
    final bold = await PdfGoogleFonts.nunitoBold();
    final titulo = await PdfGoogleFonts.poppinsSemiBold();
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/images/A_horizontal.png')).buffer
          .asUint8List(),
    );

    final nombre = (paciente['nombre'] ?? 'Sin nombre').toString();
    final codigo = (paciente['codigo'] ?? '-').toString();
    final edad = (paciente['edad'] ?? '-').toString();
    final sexo = switch (paciente['sexo']) {
      'F' => 'Femenino',
      'M' => 'Masculino',
      final otro => (otro ?? '-').toString(),
    };

    double? num_(dynamic v) => v is num ? v.toDouble() : null;
    final promedios = [for (final s in sesiones) ?num_(s['frPromedio'])];
    final promedioGeneral = promedios.isEmpty
        ? null
        : promedios.reduce((a, b) => a + b) / promedios.length;
    // Sesiones con basal guardada y su promedio bajo el límite verde.
    var conBasal = 0;
    var bajoLimite = 0;
    for (final ses in sesiones) {
      final limite = SemaforoFr.limiteVerdePara(
        num_(ses['basalMedia']),
        num_(ses['basalDesvio']),
      );
      final prom = num_(ses['frPromedio']);
      if (limite == null || prom == null) continue;
      conBasal++;
      if (prom < limite) bajoLimite++;
    }
    String basal(Map<String, dynamic> ses) {
      final m = num_(ses['basalMedia']), d = num_(ses['basalDesvio']);
      return m == null || d == null
          ? '-'
          : '${m.toStringAsFixed(1)}±${d.toStringAsFixed(1)}';
    }

    String dur(int s) => '${_dos(s ~/ 60)}:${_dos(s % 60)}';

    final doc = pw.Document(
      title: 'Reporte del paciente - $nombre',
      author: 'DentCalm',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    pw.Widget h(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
      child: pw.Text(
        t,
        style: pw.TextStyle(font: titulo, fontSize: 13, color: _texto),
      ),
    );

    pw.Widget dato(String t, String v) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _fondo,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              v,
              style: pw.TextStyle(font: titulo, fontSize: 16, color: _primario),
            ),
            pw.Text(t, style: const pw.TextStyle(fontSize: 9, color: _gris)),
          ],
        ),
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(logo, height: 40),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Reporte del paciente',
                      style: pw.TextStyle(
                        font: titulo,
                        fontSize: 14,
                        color: _texto,
                      ),
                    ),
                    pw.Text(
                      'Generado el ${_fecha(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 9, color: _gris),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Container(height: 3, color: _primario),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DentCalm · Monitorización respiratoria para la atención odontológica',
              style: const pw.TextStyle(fontSize: 8, color: _gris),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _gris),
            ),
          ],
        ),
        build: (context) => [
          h('Paciente'),
          pw.Table(
            columnWidths: const {
              0: pw.FixedColumnWidth(110),
              1: pw.FlexColumnWidth(),
            },
            children: [
              for (final (t, v) in [
                ('Nombre', nombre),
                ('Código', codigo),
                ('Edad', '$edad años'),
                ('Sexo', sexo),
              ])
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        t,
                        style: pw.TextStyle(font: bold, color: _texto),
                      ),
                    ),
                    pw.Text(v),
                  ],
                ),
            ],
          ),

          h('Resumen'),
          pw.Row(
            children: [
              dato('Sesiones', '${sesiones.length}'),
              dato(
                'FR promedio general',
                promedioGeneral == null
                    ? '-'
                    : '${promedioGeneral.toStringAsFixed(1)} rpm',
              ),
              dato(
                'Promedio bajo el límite verde',
                conBasal == 0 ? '-' : '$bajoLimite de $conBasal',
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Zona calma de cada sesión: desde la basal (μ_b) hasta el límite verde '
            'μ_b + max(${ParametrosSemaforo.k.toInt()}·σ_b, '
            '${(ParametrosSemaforo.delta * 100).toInt()} %·μ_b). Solo cuenta sesiones con basal '
            'guardada. Parámetros de diseño (Fleming et al., Lancet 2011), no valores '
            'clínicos validados.',
            style: const pw.TextStyle(fontSize: 9, color: _gris),
          ),

          h('Sesiones'),
          if (sesiones.isEmpty)
            pw.Text('Este paciente todavía no tiene sesiones.')
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                font: bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: _primario),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerLeft,
                7: pw.Alignment.centerLeft,
              },
              oddRowDecoration: const pw.BoxDecoration(color: _fondo),
              headers: [
                'Fecha',
                'Duración',
                'FR prom.',
                'Mín.',
                'Máx.',
                'Basal',
                'Inquietud',
                'Feedback',
              ],
              columnWidths: const {
                0: pw.FixedColumnWidth(78),
                1: pw.FixedColumnWidth(44),
                2: pw.FixedColumnWidth(42),
                3: pw.FixedColumnWidth(30),
                4: pw.FixedColumnWidth(30),
                5: pw.FixedColumnWidth(52),
                6: pw.FixedColumnWidth(50),
                7: pw.FlexColumnWidth(),
              },
              data: [
                for (var i = sesiones.length - 1; i >= 0; i--)
                  [
                    fechas[i] == null ? '-' : _fecha(fechas[i]!),
                    dur(
                      (sesiones[i]['duracionSegundos'] as num?)?.toInt() ?? 0,
                    ),
                    num_(sesiones[i]['frPromedio'])?.toStringAsFixed(1) ?? '-',
                    '${sesiones[i]['frMinima'] ?? '-'}',
                    '${sesiones[i]['frMaxima'] ?? '-'}',
                    basal(sesiones[i]),
                    '${sesiones[i]['nivelAnsiedad'] ?? '-'}',
                    '${sesiones[i]['feedback'] ?? ''}',
                  ],
              ],
            ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Las sesiones se listan de la más reciente a la más antigua.',
            style: const pw.TextStyle(fontSize: 8, color: _acento),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final archivo =
        'DentCalm_${nombre.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_reporte_${_fechaArchivo(DateTime.now())}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: archivo);
  }
}

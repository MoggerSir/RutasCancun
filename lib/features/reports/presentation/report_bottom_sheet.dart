import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutas_cancun/features/routes/data/routes_repository.dart';

const reportTypes = [
  ('passed', 'Acaba de pasar', Icons.directions_bus),
  ('full', 'Va lleno', Icons.people),
  ('accident', 'Accidente', Icons.warning),
  ('no_show', 'No pasó', Icons.block),
];

Future<void> showReportBottomSheet(
  BuildContext context,
  WidgetRef ref,
  String routeId, {
  required double lat,
  required double lng,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (ctx) => _ReportSheet(routeId: routeId, lat: lat, lng: lng),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.routeId,
    required this.lat,
    required this.lng,
  });

  final String routeId;
  final double lat;
  final double lng;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  bool _sending = false;

  Future<void> _submit(String type) async {
    setState(() => _sending = true);
    try {
      await ref.read(routesRepositoryProvider).submitReport(
            routeId: widget.routeId,
            reportType: type,
            lat: widget.lat,
            lng: widget.lng,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte enviado. ¡Gracias!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // showModalBottomSheet no agrega el inset inferior automáticamente;
    // sin SafeArea la barra de navegación del sistema tapa "No pasó".
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reportar', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_sending) const LinearProgressIndicator(),
            ...reportTypes.map(
              (t) => ListTile(
                leading: Icon(t.$3),
                title: Text(t.$2),
                onTap: _sending ? null : () => _submit(t.$1),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

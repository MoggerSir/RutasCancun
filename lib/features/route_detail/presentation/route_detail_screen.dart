import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutas_cancun/features/routes/providers/routes_providers.dart';
import 'package:rutas_cancun/features/reports/presentation/report_bottom_sheet.dart';

class RouteDetailScreen extends ConsumerWidget {
  const RouteDetailScreen({super.key, required this.routeId});
  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(routeDetailProvider(routeId));

    return Scaffold(
      appBar: AppBar(title: Text(routeId.toUpperCase())),
      floatingActionButton: detailAsync.maybeWhen(
        data: (d) => FloatingActionButton.extended(
          onPressed: () => showReportBottomSheet(context, ref, d.id,
              lat: d.stops.first.lat, lng: d.stops.first.lng),
          icon: const Icon(Icons.report),
          label: const Text('Reportar'),
        ),
        orElse: () => null,
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (detail) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            // Deja espacio para el FAB "Reportar" y la barra de navegación
            // del sistema, que de otro modo tapan la última parada.
            88 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            Text(detail.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (detail.metadata != null) ...[
              _MetadataCard(metadata: detail.metadata!),
              const SizedBox(height: 12),
            ],
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Sin reportes recientes — ¡sé el primero en reportar!',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Paradas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...detail.stops.map(
              (s) => ListTile(
                leading: CircleAvatar(child: Text('${s.sequence}')),
                title: Text(s.name),
                dense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.metadata});
  final Map<String, dynamic> metadata;

  @override
  Widget build(BuildContext context) {
    final confidence = metadata['durationConfidence'] as String?;
    final duration = metadata['estDurationMin'] as int?;
    final distance = metadata['distanceKm'];

    String durationText = '';
    if (confidence == 'low') {
      durationText = 'Duración no mostrada (baja confianza en datos)';
    } else if (duration != null) {
      durationText = confidence == 'medium'
          ? '~$duration min (aprox., sin tráfico en vivo)'
          : '~$duration min estimados (sin tráfico en vivo)';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distancia total: $distance km'),
            if (durationText.isNotEmpty) Text(durationText),
            const SizedBox(height: 4),
            Text(
              'Tiempos estimados. No incluyen tráfico en vivo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

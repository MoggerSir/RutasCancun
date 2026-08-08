import 'package:flutter/material.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/features/map/domain/route_map_ui_helpers.dart';
import 'package:rutas_cancun/features/routes/data/routes_repository.dart';

class RouteInfoSheet extends StatelessWidget {
  const RouteInfoSheet({
    super.key,
    required this.summary,
    required this.detail,
    required this.routeColor,
  });

  final RouteSummary summary;
  final RouteDetail detail;
  final Color routeColor;

  static Future<void> show(
    BuildContext context, {
    required RouteSummary summary,
    required RouteDetail detail,
    required Color routeColor,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.42,
        minChildSize: 0.28,
        maxChildSize: 0.72,
        builder: (context, scrollController) => RouteInfoSheet(
          summary: summary,
          detail: detail,
          routeColor: routeColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = detail.resolvedPhotoUrl();
    final idaMin = detail.durationIda;
    final vueltaMin = detail.durationVuelta;
    final singleDirection = detail.hasIdaOnly && !detail.hasVuelta;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  photo,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _photoPlaceholder(),
                ),
              )
            else
              _photoPlaceholder(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.code,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: routeColor,
                    ),
                  ),
                  Text(
                    operatorLabel(summary, detail),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (idaMin != null)
                    Text(
                      'Ida: ~$idaMin min',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  if (vueltaMin != null)
                    Text(
                      'Vuelta: ~$vueltaMin min',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  if (singleDirection)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Solo ida disponible — vuelta en validación',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Por dónde pasa',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          detail.description?.trim().isNotEmpty == true
              ? detail.description!.trim()
              : routeCorridorLabel(detail),
          style: const TextStyle(fontSize: 13, height: 1.35),
        ),
        if (detail.stops.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...detail.stops.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${s.sequence}. ${shortStopLabel(s.name)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: routeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.route_rounded, color: routeColor, size: 32),
    );
  }
}

class RouteAmbiguousPicker extends StatelessWidget {
  const RouteAmbiguousPicker({
    super.key,
    required this.codes,
    required this.onPick,
    required this.onDismiss,
  });

  final List<String> codes;
  final ValueChanged<String> onPick;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿Cuál ruta?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: codes
                  .map(
                    (c) => ActionChip(
                      label: Text(c),
                      onPressed: () => onPick(c),
                    ),
                  )
                  .toList(),
            ),
            TextButton(onPressed: onDismiss, child: const Text('Cancelar')),
          ],
        ),
      ),
    );
  }
}

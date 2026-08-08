import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/core/widgets/glass_surface.dart';

/// Puntos predefinidos (fallback sin Mapbox autocomplete en MVP).
const presetPoints = <Map<String, dynamic>>[
  {'label': 'Terminal ADO', 'lat': 21.16542, 'lng': -86.85121},
  {'label': 'Plaza Las Américas', 'lat': 21.15277, 'lng': -86.82458},
  {'label': 'Mercado 28', 'lat': 21.17423, 'lng': -86.80745},
  {'label': 'Blvd. Kukulcán Km 9', 'lat': 21.13345, 'lng': -86.74782},
  {'label': 'Puerto Juárez Ferry', 'lat': 21.19456, 'lng': -86.80312},
  {'label': 'Bonfil Mercado', 'lat': 21.08567, 'lng': -86.86512},
];

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  Map<String, dynamic>? _origin;
  Map<String, dynamic>? _destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planificar viaje')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassSurface(
            padding: const EdgeInsets.all(14),
            child: Text(
              'MVP: puntos predefinidos en Cancún. Autocompletado Mapbox en fase 2.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 16),
          GlassSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _PointSelector(
                  title: 'Origen',
                  selected: _origin,
                  onSelected: (p) => setState(() => _origin = p),
                ),
                const SizedBox(height: 16),
                _PointSelector(
                  title: 'Destino',
                  selected: _destination,
                  onSelected: (p) => setState(() => _destination = p),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _origin != null && _destination != null
                ? () => context.push('/search/results', extra: {
                      'origin': _origin,
                      'destination': _destination,
                    })
                : null,
            child: const Text('Buscar rutas'),
          ),
        ],
      ),
    );
  }
}

class _PointSelector extends StatelessWidget {
  const _PointSelector({
    required this.title,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presetPoints.map((p) {
            final isSelected = selected?['label'] == p['label'];
            return FilterChip(
              selected: isSelected,
              label: Text(p['label']!),
              selectedColor: AppColors.primary.withValues(alpha: 0.22),
              checkmarkColor: AppColors.primary,
              side: BorderSide(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.5) : AppColors.glassBorder,
              ),
              onSelected: (_) => onSelected(p),
            );
          }).toList(),
        ),
      ],
    );
  }
}

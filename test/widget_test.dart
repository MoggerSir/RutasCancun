import 'package:flutter_test/flutter_test.dart';
import 'package:rutas_cancun/features/routes/data/routes_repository.dart';

void main() {
  test('RankedRoute durationText hides low confidence', () {
    final route = RankedRoute(
      routeId: '1',
      routeCode: 'R5',
      routeName: 'Test',
      rankByCoverage: 1,
      rankByDistance: 1,
      rankByIncidents: null,
      distanceKm: 9.6,
      estDurationMin: 32,
      durationConfidence: 'low',
      durationLabel: 'oculto_baja_confianza',
      recentIncidentClusters: 0,
    );
    expect(route.durationText(), isEmpty);
  });

  test('RankedRoute durationText shows approx for medium', () {
    final route = RankedRoute(
      routeId: '1',
      routeCode: 'R15',
      routeName: 'Test',
      rankByCoverage: 1,
      rankByDistance: 1,
      rankByIncidents: null,
      distanceKm: 11,
      estDurationMin: 38,
      durationConfidence: 'medium',
      durationLabel: 'estimado_sin_trafico',
      recentIncidentClusters: 0,
    );
    expect(route.durationText(), contains('aprox'));
  });
}

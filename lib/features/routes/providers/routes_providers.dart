import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutas_cancun/features/routes/data/routes_repository.dart';

final routesListProvider = FutureProvider<List<RouteSummary>>((ref) async {
  final routes = await ref.watch(routesRepositoryProvider).listRoutes();
  routes.sort((a, b) => a.code.compareTo(b.code));
  return routes;
});

final routeDetailProvider = FutureProvider.family<RouteDetail, String>((ref, id) {
  return ref.watch(routesRepositoryProvider).getRoute(id);
});

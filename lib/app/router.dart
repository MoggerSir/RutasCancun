import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rutas_cancun/features/map/presentation/map_screen.dart';
import 'package:rutas_cancun/features/search/presentation/search_screen.dart';
import 'package:rutas_cancun/features/search/presentation/search_results_screen.dart';
import 'package:rutas_cancun/features/route_detail/presentation/route_detail_screen.dart';
import 'package:rutas_cancun/features/legal/presentation/legal_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const MapScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: '/search/results',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return SearchResultsScreen(
            origin: extra['origin'] as Map<String, dynamic>,
            destination: extra['destination'] as Map<String, dynamic>,
          );
        },
      ),
      GoRoute(
        path: '/routes/:id',
        builder: (_, state) =>
            RouteDetailScreen(routeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/legal',
        builder: (_, state) {
          final section = switch (state.uri.queryParameters['section']) {
            'privacy' => LegalSection.privacy,
            'terms' => LegalSection.terms,
            _ => LegalSection.about,
          };
          return LegalScreen(initialSection: section);
        },
      ),
    ],
  );
});

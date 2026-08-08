import 'package:rutas_cancun/features/routes/data/routes_repository.dart';

String shortStopLabel(String name) {
  var clean = name.split('(').first.trim();
  clean = clean.replaceAll(RegExp(r'^(Inicio|Fin)\s+ida\s*', caseSensitive: false), '');
  if (clean.length > 22) return '${clean.substring(0, 20)}…';
  return clean.isEmpty ? name : clean;
}

String routeCorridorLabel(RouteDetail? detail) {
  if (detail == null || detail.stops.isEmpty) return 'Recorrido validado';
  if (detail.stops.length >= 2) {
    return '${shortStopLabel(detail.stops.first.name)} → ${shortStopLabel(detail.stops.last.name)}';
  }
  return shortStopLabel(detail.stops.first.name);
}

int? routeEstDurationMin(RouteDetail? detail) {
  final fromDir = detail?.durationIda;
  if (fromDir != null) return fromDir;
  final v = detail?.metadata?['estDurationMin'];
  if (v is num) return v.round();
  return null;
}

double? routeDistanceKm(RouteDetail? detail) {
  final v = detail?.metadata?['distanceKm'];
  if (v is num) return v.toDouble();
  return null;
}

String routeDurationLabel(RouteDetail? detail) {
  final min = routeEstDurationMin(detail);
  if (min == null || min <= 0) return 'Duración estimada';
  return '~$min min';
}

String routeDistanceLabel(RouteDetail? detail) {
  final km = routeDistanceKm(detail);
  if (km == null || km <= 0) return '';
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1)} km';
}

String operatorLabel(RouteSummary summary, RouteDetail? detail) {
  final op = summary.operator.trim();
  if (op.isNotEmpty) return op;
  if (detail?.name.contains('Turicún') == true) return 'Turicún';
  if (detail?.name.contains('Autocar') == true) return 'Autocar';
  return 'Transporte público';
}

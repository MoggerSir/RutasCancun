/// Horarios de servicio por ruta — catálogo cliente basado en IMOVEQROO y fuentes públicas.
///
/// Fuentes:
/// - R1/R2 Zona Hotelera: servicio 24 h (frecuencia reducida de madrugada).
/// - R27 MOBI: última salida reportada alrededor de 23:30, todavía en piloto.
/// - El resto no se marca nocturno sin evidencia pública suficiente.
///
/// Cuando la API exponga `metadata.service_hours`, [RouteServiceHours.forRoute] lo prioriza.
library;

enum RouteServiceLevel {
  /// Operación continua 24 h (p. ej. corredor Zona Hotelera R1/R2).
  allDay24h,

  /// Servicio diurno con extensión nocturna hasta altas horas (~23:00–02:30).
  extendedNight,

  /// Horario diurno estándar (~06:00–22:30).
  dayOnly,
}

class RouteServiceInfo {
  const RouteServiceInfo({
    required this.level,
    required this.summary,
    this.firstDeparture = '06:00',
    this.lastDeparture,
    this.sources = const [],
  });

  final RouteServiceLevel level;
  final String summary;
  final String firstDeparture;

  /// `null` = sin hora fija de cierre (24 h).
  final String? lastDeparture;
  final List<String> sources;

  bool get hasNightService =>
      level == RouteServiceLevel.allDay24h ||
      level == RouteServiceLevel.extendedNight;

  String get badgeLabel => switch (level) {
        RouteServiceLevel.allDay24h => '24 h',
        RouteServiceLevel.extendedNight => 'Noche',
        RouteServiceLevel.dayOnly => '',
      };
}

abstract final class RouteServiceHours {
  static const _catalog = <String, RouteServiceInfo>{
    'R1': RouteServiceInfo(
      level: RouteServiceLevel.allDay24h,
      summary: 'Corredor Zona Hotelera · servicio continuo 24 h',
      firstDeparture: '05:00',
      lastDeparture: null,
      sources: ['IMOVEQROO', 'PorEsto ZH'],
    ),
    'R2': RouteServiceInfo(
      level: RouteServiceLevel.allDay24h,
      summary: 'Centro ↔ Zona Hotelera · servicio continuo 24 h',
      firstDeparture: '05:00',
      lastDeparture: null,
      sources: ['IMOVEQROO', 'Reddit r/cancun', 'Tripadvisor Cancún'],
    ),
    'R4': RouteServiceInfo(
      level: RouteServiceLevel.dayOnly,
      summary: 'Tierra Maya → Plaza · horario diurno',
      lastDeparture: '22:30',
    ),
    'R6': RouteServiceInfo(
      level: RouteServiceLevel.dayOnly,
      summary: 'Jacinto Pat → Crucero · horario diurno',
      lastDeparture: '22:30',
    ),
    'R11': RouteServiceInfo(
      level: RouteServiceLevel.dayOnly,
      summary: 'Corales → Tecnológico · horario diurno',
      lastDeparture: '22:30',
    ),
    'R15': RouteServiceInfo(
      level: RouteServiceLevel.dayOnly,
      summary: 'ADO → Región 95 · horario diurno',
      lastDeparture: '22:30',
    ),
    'R27': RouteServiceInfo(
      level: RouteServiceLevel.extendedNight,
      summary: 'MOBI · últimas corridas estimadas hasta 23:30',
      firstDeparture: '05:30',
      lastDeparture: '23:30',
      sources: ['Gobierno de Quintana Roo (piloto MOBI)', 'fuente comunitaria'],
    ),
    'R48': RouteServiceInfo(
      level: RouteServiceLevel.dayOnly,
      summary: 'Corales → Jacinto Pat · horario diurno',
      lastDeparture: '22:30',
    ),
    'R0': RouteServiceInfo(
      level: RouteServiceLevel.dayOnly,
      summary: 'Ruta piloto · horario diurno',
      lastDeparture: '22:30',
    ),
  };

  static RouteServiceInfo? forCode(String code,
      {Map<String, dynamic>? metadata}) {
    final fromMeta = _fromMetadata(metadata);
    if (fromMeta != null) return fromMeta;
    return _catalog[code.toUpperCase()];
  }

  static RouteServiceInfo? _fromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    final hours = metadata['service_hours'];
    if (hours is! Map<String, dynamic>) return null;

    final levelStr = hours['level'] as String?;
    final level = switch (levelStr) {
      '24h' || 'all_day' => RouteServiceLevel.allDay24h,
      'extended_night' || 'night' => RouteServiceLevel.extendedNight,
      'day' || 'day_only' => RouteServiceLevel.dayOnly,
      _ => null,
    };
    if (level == null) return null;

    return RouteServiceInfo(
      level: level,
      summary: hours['summary'] as String? ?? '',
      firstDeparture: hours['first_departure'] as String? ?? '06:00',
      lastDeparture: hours['last_departure'] as String?,
    );
  }

  /// Rutas con servicio nocturno o 24 h (filtro del mapa).
  static bool hasNightService(String code, {Map<String, dynamic>? metadata}) {
    return forCode(code, metadata: metadata)?.hasNightService ?? false;
  }

  static bool matchesNightFilter(String code,
          {Map<String, dynamic>? metadata}) =>
      hasNightService(code, metadata: metadata);

  /// Indica si la ruta podría estar operando en este momento (heurística local).
  static bool isLikelyOperatingNow(String code, DateTime now,
      {Map<String, dynamic>? metadata}) {
    final info = forCode(code, metadata: metadata);
    if (info == null) return true;
    if (info.level == RouteServiceLevel.allDay24h) return true;

    final minutes = now.hour * 60 + now.minute;
    final start = _parseTime(info.firstDeparture) ?? 360;
    final end =
        info.lastDeparture != null ? _parseTime(info.lastDeparture!) : null;

    if (end == null) return minutes >= start;

    // Ventana que cruza medianoche (p. ej. 06:00 → 02:30).
    if (end < start) {
      return minutes >= start || minutes <= end;
    }
    return minutes >= start && minutes <= end;
  }

  static int? _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static String nightFilterHint({required int count, required DateTime now}) {
    if (count == 0) return 'Sin rutas nocturnas cargadas';
    final hour = now.hour;
    if (hour >= 22 || hour < 5) {
      return '$count rutas · 24 h o servicio extendido';
    }
    return '$count rutas · disponibles de noche';
  }
}

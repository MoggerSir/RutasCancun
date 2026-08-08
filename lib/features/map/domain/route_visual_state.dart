enum RouteVisualState { selected, nearby, far }

/// [hasSelection] fuerza a 0 el estado "far" cuando el usuario seleccionó una
/// ruta puntual: en ese modo la intención es aislarla (ver solo esa), no
/// mostrar de fondo las demás atenuadas como en el filtro "cerca de ti".
double opacityForRouteVisual(
  RouteVisualState state, {
  required bool showAllFar,
  bool hasSelection = false,
}) {
  return switch (state) {
    RouteVisualState.selected => 1.0,
    RouteVisualState.nearby => 0.85,
    RouteVisualState.far => hasSelection ? 0.0 : (showAllFar ? 0.25 : 0.0),
  };
}

RouteVisualState visualStateForRoute({
  required String code,
  required String? selectedCode,
  required Set<String> nearbyCodes,
  required bool nearbyFilterActive,
}) {
  if (selectedCode == code) return RouteVisualState.selected;
  // Con una ruta seleccionada, todo lo demás pasa a "far" (se esconde) —
  // antes solo miraba el filtro de cercanía y una ruta seleccionada dejaba
  // el resto casi igual de visible (0.85), sin aislar nada.
  if (selectedCode != null) return RouteVisualState.far;
  if (!nearbyFilterActive || nearbyCodes.contains(code)) {
    return RouteVisualState.nearby;
  }
  return RouteVisualState.far;
}

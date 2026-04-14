import 'dart:html' as html;

/// True when this session was started by a full browser reload (F5 / refresh).
bool isBrowserFullReload() {
  try {
    final entries = html.window.performance.getEntriesByType('navigation');
    if (entries.isEmpty) return false;
    final first = entries.first;
    if (first is html.PerformanceNavigationTiming) {
      return first.type == 'reload';
    }
    return false;
  } catch (_) {
    return false;
  }
}

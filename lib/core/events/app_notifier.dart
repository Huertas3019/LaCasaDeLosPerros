import 'package:flutter/foundation.dart';

enum AppEventType {
  stockActualizado,
  ventaRealizada,
  turnoCambiado,
  gastoRegistrado,
  categoriaModificada,
}

/// Sistema de notificaciones reactivas global de la aplicación.
/// Permite que todas las pestañas (POS, Inventario, Turnos, Gastos y Balance)
/// se enteren al instante de cualquier cambio y se sincronicen en tiempo real.
class AppNotifier extends ChangeNotifier {
  static final AppNotifier instance = AppNotifier._internal();
  AppNotifier._internal();

  AppEventType? _lastEventType;
  AppEventType? get lastEventType => _lastEventType;

  void notify(AppEventType eventType) {
    _lastEventType = eventType;
    notifyListeners();
  }

  void notifyStockActualizado() => notify(AppEventType.stockActualizado);
  void notifyVentaRealizada() => notify(AppEventType.ventaRealizada);
  void notifyTurnoCambiado() => notify(AppEventType.turnoCambiado);
  void notifyGastoRegistrado() => notify(AppEventType.gastoRegistrado);
  void notifyCategoriaModificada() => notify(AppEventType.categoriaModificada);
}

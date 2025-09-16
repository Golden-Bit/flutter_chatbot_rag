import 'package:flutter/foundation.dart';

/// Istanza immutabile dello stato "pagamenti".
class BillingSnapshot {
  final bool isLoading;              // true durante il fetch
  final bool hasFetched;             // true dopo QUALSIASI esito (ok/404/errore)
  final bool hasActiveSubscription;  // true solo se esiste un piano attivo
  final dynamic plan;                // tipo del tuo SDK (usato come dynamic per compatibilità)
  final dynamic credits;             // tipo del tuo SDK (UserCreditsResponse o simile)
  final DateTime? lastUpdated;
  final String? error;               // valorizzata solo in caso di errore "non 404"

  const BillingSnapshot({
    required this.isLoading,
    required this.hasFetched,
    required this.hasActiveSubscription,
    this.plan,
    this.credits,
    this.lastUpdated,
    this.error,
  });

  factory BillingSnapshot.initial() => const BillingSnapshot(
        isLoading: false,
        hasFetched: false,
        hasActiveSubscription: false,
        plan: null,
        credits: null,
        lastUpdated: null,
        error: null,
      );

  BillingSnapshot copyWith({
    bool? isLoading,
    bool? hasFetched,
    bool? hasActiveSubscription,
    dynamic plan,
    dynamic credits,
    DateTime? lastUpdated,
    String? error,
  }) {
    return BillingSnapshot(
      isLoading: isLoading ?? this.isLoading,
      hasFetched: hasFetched ?? this.hasFetched,
      hasActiveSubscription: hasActiveSubscription ?? this.hasActiveSubscription,
      plan: plan ?? this.plan,
      credits: credits ?? this.credits,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      error: error,
    );
  }
}

/// Singleton con ValueNotifier per aggiornamenti live (UI si rifa' da sola).
class BillingGlobals {
  BillingGlobals._();

  static final ValueNotifier<BillingSnapshot> notifier =
      ValueNotifier<BillingSnapshot>(BillingSnapshot.initial());

  // Comodità:
  static BillingSnapshot get snap => notifier.value;

  static void setLoading() {
    notifier.value = notifier.value.copyWith(
      isLoading: true,
      hasFetched: false,
      error: null,
    );
  }

  /// Esito: NESSUN piano (404): plan/credits = null ma hasFetched = true,
  /// hasActiveSubscription = false. Serve per distinguere da stato “non ancora fetchato”.
  static void setNoPlan() {
    notifier.value = notifier.value.copyWith(
      isLoading: false,
      hasFetched: true,
      hasActiveSubscription: false,
      plan: null,
      credits: null,
      lastUpdated: DateTime.now(),
      error: null,
    );
  }

  /// Esito: piano attivo + (eventuali) crediti.
  static void setData({required dynamic plan, dynamic credits}) {
    notifier.value = notifier.value.copyWith(
      isLoading: false,
      hasFetched: true,
      hasActiveSubscription: true,
      plan: plan,
      credits: credits,
      lastUpdated: DateTime.now(),
      error: null,
    );
  }

  /// Esito: errore “non 404”. Finisce il loading e sblocca lo spinner.
  static void setError(Object e) {
    notifier.value = notifier.value.copyWith(
      isLoading: false,
      hasFetched: true,
      error: e.toString(),
    );
  }

  // Getter di retro-compatibilità (se altrove leggi ancora queste proprietà):
  static dynamic get currentPlan => notifier.value.plan;
  static dynamic get userCredits => notifier.value.credits;
  static DateTime? get lastUpdated => notifier.value.lastUpdated;
}

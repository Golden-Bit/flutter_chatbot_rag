import 'package:flutter/material.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/user_manager/pages/payment_page.dart';
import 'package:boxed_ai/user_manager/state/billing_globals.dart';

// ─────────────────────────────────────────────────────────────────────
// Helpers di lettura dal CurrentPlanResponse (schema SDK)
// ─────────────────────────────────────────────────────────────────────
String? _readSubscriptionId(dynamic plan) {
  try {
    final v = plan?.subscriptionId;
    if (v is String) return v;
  } catch (_) {}
  try {
    if (plan is Map && plan['subscription_id'] is String) {
      return plan['subscription_id'] as String;
    }
  } catch (_) {}
  return null;
}

String? _readPlanType(dynamic plan) {
  try { final v = plan?.planType; if (v is String) return v; } catch (_) {}
  try { if (plan is Map && plan['plan_type'] is String) return plan['plan_type'] as String; } catch (_) {}
  return null;
}

String? _readVariant(dynamic plan) {
  try { final v = plan?.variant; if (v is String) return v; } catch (_) {}
  try { if (plan is Map && plan['variant'] is String) return plan['variant'] as String; } catch (_) {}
  return null;
}


class BillingPage extends StatefulWidget {
  final VoidCallback onClose;

  /// SDK e token sono necessari per creare checkout / deeplink / portal session
  final ContextApiSdk sdk;
  final String token;

  /// URL opzionali per redirect (se vuoi passarli al backend)
  final String? successUrl;
  final String? cancelUrl;

  const BillingPage({
    Key? key,
    required this.onClose,
    required this.sdk,
    required this.token,
    this.successUrl,
    this.cancelUrl,
  }) : super(key: key);

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  // Toggle periodo
  bool _annual = false;

  // Stato billing condiviso
  late final ValueNotifier<BillingSnapshot> _billing;
  bool _printedOnce = false;

  // ─────────────────────────────────────────────────────────────────────
  // CATALOGO PIANI (UI) + MAPPATURA VARIANT
  // ─────────────────────────────────────────────────────────────────────
  static const String _planType = 'ai_standard';

  // Prezzi “di listino” — usati per determinare upgrade/downgrade (solo UI)
  static const Map<String, double> _prices = {
    'starter_monthly': 1.99,
    'starter_annual': 19.90,
    'premium_monthly': 4.99,
    'premium_annual': 49.90,
    'enterprise_monthly': 9.99,
    'enterprise_annual': 99.90,
  };

  // Definizione card (per ogni titolo abbiamo 2 varianti)
  static const List<Map<String, dynamic>> _planCards = [
    {
      'title': 'Starter',
      'variant_monthly': 'starter_monthly',
      'variant_annual': 'starter_annual',
      'features': [
        'Accesso alle funzioni base',
        '100 richieste mensili',
        'Supporto via email',
      ],
    },
    {
      'title': 'Premium',
      'variant_monthly': 'premium_monthly',
      'variant_annual': 'premium_annual',
      'features': [
        'Tutto di Starter',
        'Richieste illimitate',
        'Accesso API',
      ],
    },
    {
      'title': 'Enterprise',
      'variant_monthly': 'enterprise_monthly',
      'variant_annual': 'enterprise_annual',
      'features': [
        'Tutto di Premium',
        'Account dedicato',
        'SLA 24/7',
      ],
    },
  ];

@override
void initState() {
  super.initState();
  _billing = BillingGlobals.notifier;
  _billing.addListener(_onBillingUpdate);
  _maybePrintOnce(_billing.value);

  // ⬇️ allinea subito il toggle alla situazione corrente (o Mensile se nessun piano)
  _syncToggleWithCurrent();
}


  @override
  void dispose() {
    _billing.removeListener(_onBillingUpdate);
    super.dispose();
  }
  
void _onBillingUpdate() {
  final snap = _billing.value;
  _maybePrintOnce(snap);
  _syncToggleWithCurrent(); // ⬅️ ricalcola Mensile/Annuale quando cambia il piano
  setState(() {});          // ridisegna la UI
}

  void _maybePrintOnce(BillingSnapshot snap) {
    if (!_printedOnce && snap.hasFetched) {
      _printedOnce = true;
      final pt = _readPlanType(snap.plan);
      final v = _readVariant(snap.plan);
      debugPrint("[billing] BillingPage ▸ planType=$pt | variant=$v");
    }
  }

bool _isAnnualVariantCode(String? v) {
  if (v == null) return false;
  final s = v.toLowerCase();
  // copriamo diversi formati: "annual", "annuale", "starter_annual", "premium-annual", ecc.
  return s.endsWith('_annual') || s.contains('annual') || s.contains('annuale');
}

/// Allinea il toggle al piano corrente:
/// - se c'è un piano ed è annuale → _annual = true
/// - se c'è un piano ed è mensile → _annual = false
/// - se NON c'è piano → _annual = false (Mensile di default)
void _syncToggleWithCurrent() {
  final hasPlan = _hasActivePlan();
  final desired = hasPlan ? _isAnnualVariantCode(_currentVariant()) : false;
  if (_annual != desired && mounted) {
    setState(() => _annual = desired);
  }
}


  @override
  Widget build(BuildContext context) {
    final snap = BillingGlobals.notifier.value;

    // Spinner finché ChatBotPage non ha finito il fetch (o durante loading)
    if (!snap.hasFetched || snap.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final String? err = snap.error;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // X di chiusura in alto a destra
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: widget.onClose,
                child: const Icon(Icons.close, color: Colors.black, size: 28),
              ),
            ),

            // Contenuto principale
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Fai l'upgrade del tuo piano",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (err != null) ...[
                          const SizedBox(height: 8),
                          _ErrorBanner(error: err),
                        ],

                        const SizedBox(height: 12),
                        Center(child: _buildPeriodSwitcher()),
                        const SizedBox(height: 8),

                        LayoutBuilder(builder: (ctx, constraints) {
                          final isNarrow = constraints.maxWidth < 1000;
                          final cardWidth = (constraints.maxWidth - 64) / 3;
                          if (isNarrow) {
                            return Column(
                              children: [
                                for (final plan in _planCards) ...[
                                  _PlanCard(
                                    data: plan,
                                    annual: _annual,
                                    width: double.infinity,
                                    planType: _planType, // PASSIAMO IL PLAN TYPE
                                    onPressed: (variantCode) =>
                                        _handleActionForVariant(
                                            context, variantCode),
                                    buttonLabel: _buttonLabelForVariant(
                                        variantFor(plan)),
                                    isCurrent: _isCurrentVariant(
                                        variantFor(plan)),
                                    price: _priceOf(variantFor(plan)),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ],
                            );
                          } else {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final plan in _planCards) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      child: _PlanCard(
                                        data: plan,
                                        annual: _annual,
                                        width: cardWidth,
                                        planType:
                                            _planType, // PASSIAMO IL PLAN TYPE
                                        onPressed: (variantCode) =>
                                            _handleActionForVariant(
                                                context, variantCode),
                                        buttonLabel: _buttonLabelForVariant(
                                            variantFor(plan)),
                                        isCurrent: _isCurrentVariant(
                                            variantFor(plan)),
                                        price: _priceOf(variantFor(plan)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Period switcher
  Widget _buildPeriodSwitcher() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      child: Container(
        width: 240,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            // highlight scorrevole
            AnimatedAlign(
              alignment:
                  _annual ? Alignment.centerRight : Alignment.centerLeft,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Container(
                width: 120,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            // testo tappabile
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(24)),
                    onTap: () => setState(() => _annual = false),
                    child: Center(
                      child: Text(
                        "Mensile",
                        style: TextStyle(
                          color:
                              _annual ? Colors.grey.shade700 : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(24)),
                    onTap: () => setState(() => _annual = true),
                    child: Center(
                      child: Text(
                        "Annuale",
                        style: TextStyle(
                          color:
                              _annual ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // LOGICA BUSINESS
  // ─────────────────────────────────────────────────────────────────────

  // determina la variant da mostrare per la card (in base al toggle)
  String variantFor(Map<String, dynamic> plan) {
    return (_annual ? plan['variant_annual'] : plan['variant_monthly'])
        as String;
    }

  // legge la variant corrente dallo snapshot (snake_case normalizzata)
  String? _currentVariant() {
    final v = _readVariant(BillingGlobals.snap.plan);
    return v?.toLowerCase().replaceAll('-', '_');
  }

  String? _currentPlanType() {
    final t = _readPlanType(BillingGlobals.snap.plan);
    return t?.toLowerCase();
  }

  bool _hasActivePlan() => BillingGlobals.snap.hasActiveSubscription;

  bool _isCurrentVariant(String variantCode) {
    final curVar = _currentVariant();
    final curType = _currentPlanType();
    return curType == _planType && curVar == variantCode;
  }

  double? _priceOf(String variantCode) => _prices[variantCode];

  String _buttonLabelForVariant(String targetVariant) {
    // nessun piano → “Acquista”
    if (!_hasActivePlan()) return 'Acquista';

    // stessa card del piano corrente → “Gestisci”
    if (_isCurrentVariant(targetVariant)) return 'Gestisci';

    // altro piano → Upgrade/Downgrade in base al prezzo
    final curVar = _currentVariant();
    final curPrice = (curVar != null) ? _priceOf(curVar) : null;
    final tgtPrice = _priceOf(targetVariant);

    if (curPrice == null || tgtPrice == null) return 'Seleziona';

    if (tgtPrice > curPrice) return 'Upgrade';
    if (tgtPrice < curPrice) return 'Downgrade';
    return 'Seleziona';
  }

  // ─────────────────────────────────────────────────────────────────────
  // Overlay di attesa mentre si genera l’URL di redirect (Stripe)
  // ─────────────────────────────────────────────────────────────────────
  Future<T?> _awaitWithRedirectOverlay<T>(Future<T> future) async {
    // Mostra dialogo
    _showRedirectDialog();
    try {
      final result = await future;
      return result;
    } finally {
      // Chiudi dialogo a prescindere da ok/errore
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  void _showRedirectDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4), // angoli a 4
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Attendere…',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Stiamo aprendo la pagina del portale di pagamento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  SizedBox(height: 16),
                  // progress bar indeterminata
                  LinearProgressIndicator(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleActionForVariant(
      BuildContext ctx, String variantCode) async {
    try {
      final hasPlan = _hasActivePlan();

      // Se è la card corrente → apri Billing Portal
      if (hasPlan && _isCurrentVariant(variantCode)) {
final curPlan = BillingGlobals.snap.plan;
final subId   = _readSubscriptionId(curPlan);
final curType = _readPlanType(curPlan);

final portal = await _awaitWithRedirectOverlay(
  widget.sdk.createPortalSession(
    token: widget.token,
    // [HINT] se disponibili, li passiamo in snake_case lato L2
    currentSubscriptionId: subId,
    currentPlanType: curType,
    returnUrl: widget.successUrl, // opzionale se vuoi
  ),
);
        if (portal != null) _openWeb(portal.url);
        return;
      }

      if (!hasPlan) {
        // Nessun piano → Checkout (nuova sottoscrizione)
        final res = await _awaitWithRedirectOverlay(
          widget.sdk.createCheckoutSessionVariant(
            token: widget.token,
            planType: _planType,
            variant: variantCode,
            successUrl: widget.successUrl,
            cancelUrl: widget.cancelUrl,
          ),
        );

        // Unified open
        final url = (res is CheckoutSuccessResponse)
            ? res.url
            : (res is PortalRedirectResponse)
                ? res.portalUrl
                : null;

        if (url != null) {
          _openWeb(url);
        } else {
          _snack(ctx, 'Impossibile avviare il checkout.');
        }
        return;
      }

      // Cambio piano → deeplink upgrade/downgrade
final curPlan = BillingGlobals.snap.plan;
final subId   = _readSubscriptionId(curPlan);
final curType = _readPlanType(curPlan);
final curVar  = _readVariant(curPlan);

final deeplink = await _awaitWithRedirectOverlay(
  widget.sdk.createUpgradeDeeplink(
    token: widget.token,
    targetPlanType: _planType,
    targetVariant: variantCode,
    returnUrl: widget.successUrl,

    // [HINT] ⇒ L2 evita list/resources
    currentSubscriptionId: subId,
    currentPlanType: curType,
    currentVariant: curVar,
  ),
);

      _openWeb(deeplink!.url);
    } catch (e) {
      _snack(ctx, 'Operazione non riuscita: $e');
    }
  }

  void _openWeb(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PaymentPage(url: url)),
    );
  }

  void _snack(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────────────────────────────────────────────────
  // Helpers di lettura dal CurrentPlanResponse (schema SDK)
  // ─────────────────────────────────────────────────────────────────────
  String? _readPlanType(dynamic plan) {
    try {
      final v = plan?.planType;
      if (v is String) return v;
    } catch (_) {}
    try {
      if (plan is Map && plan['plan_type'] is String) {
        return plan['plan_type'] as String;
      }
    } catch (_) {}
    return null;
  }

  String? _readVariant(dynamic plan) {
    try {
      final v = plan?.variant;
      if (v is String) return v;
    } catch (_) {}
    try {
      if (plan is Map && plan['variant'] is String) {
        return plan['variant'] as String;
      }
    } catch (_) {}
    return null;
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool annual;
  final double width;

  /// azione bottone → passa la variant da attivare
  final void Function(String variantCode) onPressed;

  /// etichetta del pulsante (Acquista/Upgrade/Downgrade/Gestisci)
  final String buttonLabel;

  /// se questa card rappresenta il piano corrente
  final bool isCurrent;

  /// prezzo mostrato (per contesto utente)
  final double? price;

  /// plan type mostrato accanto alla variant (es. "ai_standard • starter_monthly")
  final String planType;

  const _PlanCard({
    required this.data,
    required this.annual,
    required this.width,
    required this.onPressed,
    required this.buttonLabel,
    required this.isCurrent,
    required this.price,
    required this.planType,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String;
    final variantCode =
        (annual ? data['variant_annual'] : data['variant_monthly']) as String;
    final features = (data['features'] as List).cast<String>();

    final periodText = annual ? ' USD/anno' : ' USD/mese';
    final priceStr = (price != null) ? price!.toStringAsFixed(2) : '—';

    // Bordi: nero spesso per piano attuale, grigio sottile per gli altri
    final borderColor =
        isCurrent ? Colors.black : Colors.grey.shade400;
    final borderWidth = isCurrent ? 2.0 : 1.0;

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      elevation: isCurrent ? 3 : 2,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 520,
          minWidth: 300,
          maxWidth: 500,
        ),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titolo + badge "Piano attuale" allineato a destra (in alto)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: const Text(
                        'Piano attuale',
                        style:
                            TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 4),
              Text(
                '$planType • $variantCode',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Prezzo
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$$priceStr',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    periodText,
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Feature
              ...features.map(
                (f) => Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check,
                          size: 16, color: Colors.black),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Pulsante azione
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () => onPressed(variantCode),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(buttonLabel),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String error;
  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Alcune informazioni di fatturazione non sono disponibili. Riprova più tardi.',
              style: TextStyle(color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/user_manager/pages/billing_page.dart';
import 'package:boxed_ai/user_manager/pages/payment_page.dart';
import 'package:boxed_ai/user_manager/state/billing_globals.dart';

/// Mostra lo stato dell’abbonamento:
/// - Spinner finché il fetch in ChatBotPage non è concluso
/// - Vista "Plus" (titolo) determinata da planType
/// - Vista "Free" se il fetch è concluso ma non c’è alcun piano (404)
/// Usa planType + variant come identificatori del piano (NO .name).
class SubscriptionSettingsContent extends StatefulWidget {
  const SubscriptionSettingsContent({
    super.key,
    required this.accessToken, // ⬅️ ora riceviamo solo il token
  });

  final String accessToken;

  @override
  State<SubscriptionSettingsContent> createState() =>
      _SubscriptionSettingsContentState();
}

class _SubscriptionSettingsContentState
    extends State<SubscriptionSettingsContent> {
  late final ValueNotifier<BillingSnapshot> _billing;

  // ── SDK gestito internamente ────────────────────────────────────────────
  late final ContextApiSdk _sdk;
  bool _sdkReady = false;
  Object? _sdkError;

  bool _printedOnce = false;

  @override
  void initState() {
    super.initState();

    // init stato billing
    _billing = BillingGlobals.notifier;
    _billing.addListener(_onBillingUpdate);
    _maybePrintOnce(_billing.value);

    // init SDK interno
    _sdk = ContextApiSdk();
    _initSdk();
  }

  Future<void> _initSdk() async {
    try {
      await _sdk.loadConfig(); // carica baseUrl ecc.
      if (mounted) setState(() => _sdkReady = true);
    } catch (e) {
      _sdkError = e;
      if (mounted) setState(() => _sdkReady = false);
    }
  }

  @override
  void dispose() {
    _billing.removeListener(_onBillingUpdate);
    super.dispose();
  }

  void _onBillingUpdate() {
    final snap = _billing.value;
    _maybePrintOnce(snap);
    setState(() {}); // ricostruisci per togliere/mostrare spinner e contenuti
  }

  void _maybePrintOnce(BillingSnapshot snap) {
    if (!_printedOnce && snap.hasFetched) {
      _printedOnce = true;
      final pt = _readPlanType(snap.plan);
      final v = _readVariant(snap.plan);
      debugPrint(
        "[billing] SubscriptionSettingsContent ▸ planType=$pt | variant=$v | credits=${_creditsSummary(snap.credits)}",
      );
    }
  }

  bool get _canManageBilling =>
      _sdkReady && (widget.accessToken.isNotEmpty == true);

  void _openBillingOrWarn(BuildContext context) {
    if (!_canManageBilling) {
      final msg = (_sdkError != null)
          ? 'Gestione abbonamento non disponibile (${_sdkError}).'
          : 'Gestione abbonamento non disponibile.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
   Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BillingPage(
        onClose: () => Navigator.of(context).pop(),
        sdk: _sdk,
        token: widget.accessToken,
        // successUrl: 'https://…',
        // cancelUrl : 'https://…',
      ),
    ),
  );
  }

Future<T?> _awaitWithRedirectOverlay<T>(Future<T> future) async {
  _showRedirectDialog();
  try {
    final result = await future;
    return result;
  } finally {
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
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.black12),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      );
    },
  );
}

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


Future<void> _openPortalDirect(BuildContext ctx) async {
  try {
    // HINT dal piano corrente (così L2 evita le GET list/resources)
    final curPlan = BillingGlobals.snap.plan;
    final subId   = _readSubscriptionId(curPlan);
    final curType = _readPlanType(curPlan);

    final portal = await _awaitWithRedirectOverlay(
      _sdk.createPortalSession(
        token: widget.accessToken,
        currentSubscriptionId: subId,  // <-- HINT
        currentPlanType: curType,      // <-- HINT
        // returnUrl: 'https://…'      // opzionale se vuoi passarla
      ),
    );

    if (portal != null) {
      // Apri direttamente la webview col Billing Portal (stesso comportamento di BillingPage)
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PaymentPage(url: portal.url)),
      );
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Impossibile avviare il Billing Portal.')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text('Operazione non riuscita: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final snap = _billing.value;

    // 1) Spinner durante o prima del fetch
    if (!snap.hasFetched || snap.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2) Errori non-404 (se presenti): mostra un fallback non-bloccante
    if (snap.error != null) {
      return _buildErrorFallback(context, snap.error!);
    }

    // 3) Dati dal singleton
    final bool hasPlan = snap.hasActiveSubscription;
    final dynamic plan = snap.plan; // CurrentPlanResponse oppure Map
    final dynamic credits = snap.credits; // UserCreditsResponse oppure Map

    final String planType = _readPlanType(plan) ?? '';
    final String variant = _readVariant(plan) ?? '';
    final String planLabel = hasPlan ? _labelFromPlanType(planType) : 'Free';
    final String? renewText = hasPlan ? _renewTextFromPeriodEnd(plan) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(
              context, planLabel, variant, renewText, hasPlan),
          const SizedBox(height: 24),
          _buildInfoBox(hasPlan),
          const SizedBox(height: 24),
          _buildPaymentSection(context),
        ],
      ),
    );
  }

  // HEADER -------------------------------------------------------------------
  Widget _buildHeaderSection(
    BuildContext context,
    String planLabel,
    String variant,
    String? renewDateText,
    bool hasPlan,
  ) {
    final String fatturazione = variant.isEmpty
        ? ''
        : (variant.toLowerCase() == 'annual' ||
                variant.toLowerCase() == 'annuale')
            ? ' • Fatturazione: Annuale'
            : (variant.toLowerCase() == 'monthly' ||
                    variant.toLowerCase() == 'mensile')
                ? ' • Fatturazione: Mensile'
                : ' • Variante: ${_titleCase(variant)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BoxedAI $planLabel',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                hasPlan
                    ? (renewDateText != null
                        ? 'Piano attivo$fatturazione • Rinnovo: $renewDateText'
                        : 'Piano attivo$fatturazione')
                    : 'Nessun piano attivo',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
// Pulsante principale: sempre "Gestisci" → BillingPage
OutlinedButton(
  style: OutlinedButton.styleFrom(
    foregroundColor: Colors.black,
    side: const BorderSide(color: Colors.black),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  ),
  onPressed: _canManageBilling ? () => _openBillingOrWarn(context) : null,
  child: const Text('Gestisci'),
),
const SizedBox(width: 8),
// Secondario: "Apri Portale" → solo se c'è un piano attivo
          ],
        ),
        if (!_canManageBilling) ...[
          const SizedBox(height: 6),
          Text(
            _sdkError != null
                ? 'Funzione non disponibile: errore SDK.'
                : 'Funzione non disponibile in questa installazione.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }

  // INFO BOX -----------------------------------------------------------------
  Widget _buildInfoBox(bool hasPlan) {
    final List<Widget> items = hasPlan
        ? const [
            _CheckItem('Tutte le funzioni del piano Free'),
            _CheckItem(
                'Limitazioni più ampie per chat, analisi dati e generazione immagini'),
            _CheckItem('Modalità vocale standard e avanzata'),
            _CheckItem(
                'Accesso a ricerche approfondite e modelli di ragionamento'),
            _CheckItem('Crea e usa attività, progetti e GPT personalizzati'),
            _CheckItem('Opportunità per provare nuove funzioni'),
          ]
        : const [
            _CheckItem('Funzionalità base'),
            _CheckItem('Prova BoxedAI Plus per sbloccare funzioni avanzate'),
          ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasPlan
                ? 'Grazie per l’abbonamento a BoxedAI Plus. Il tuo piano include:'
                : 'Stai usando BoxedAI Free. Con Plus ottieni:',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }

  // PAGAMENTO (etichetta + pulsante) -----------------------------------------
  Widget _buildPaymentSection(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Text(
            'Pagamento',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
        ),
        /*OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            side: const BorderSide(color: Colors.black),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
          ),
          onPressed:
              _canManageBilling ? () => _openBillingOrWarn(context) : null,
          child: const Text('Gestisci'),
        ),*/
          OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.black,
      side: const BorderSide(color: Colors.black12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    icon: const Icon(Icons.launch, size: 18),
    label: const Text('Apri Portale'),
    onPressed: _canManageBilling ? () => _openPortalDirect(context) : null,
  ),
      ],
    );
  }


  Widget _buildErrorFallback(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
          const SizedBox(height: 8),
          const Text(
            'Impossibile recuperare i dati di abbonamento.',
            style: TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(error,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {},
            child: const Text('Riprova più tardi'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers: lettura sicura dei campi del tuo SDK (dynamic o Map)
  // ─────────────────────────────────────────────────────────────
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

  int? _readPeriodEnd(dynamic plan) {
    try {
      final v = plan?.periodEnd;
      if (v is int) return v;
    } catch (_) {}
    try {
      if (plan is Map && plan['period_end'] is int) {
        return plan['period_end'] as int;
      }
    } catch (_) {}
    return null;
  }

  String? _renewTextFromPeriodEnd(dynamic plan) {
    final sec = _readPeriodEnd(plan);
    if (sec == null) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true)
        .toLocal();
    return _fmtDateIt(dt);
  }

  num? _readNum(dynamic obj, String camel, String snake) {
    try {
      final v = obj?.toJson()?[camel];
      if (v is num) return v;
    } catch (_) {}
    try {
      final v = obj?[camel];
      if (v is num) return v;
    } catch (_) {}
    try {
      if (obj is Map && obj[camel] is num) return obj[camel] as num;
    } catch (_) {}
    try {
      if (obj is Map && obj[snake] is num) return obj[snake] as num;
    } catch (_) {}
    return null;
  }

  String _labelFromPlanType(String? planType) {
    if (planType == null || planType.trim().isEmpty) return 'Plus';
    // Mappa veloce, con fallback Title Case
    switch (planType.toLowerCase()) {
      case 'starter':
        return 'Starter';
      case 'premium':
        return 'Premium';
      case 'business':
        return 'Business';
      default:
        return _titleCase(planType);
    }
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  String _fmtDateIt(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yy = dt.year.toString();
    return '$dd/$mm/$yy';
  }

  String _creditsSummary(dynamic credits) {
    final r = _readNum(credits, 'remainingTotal', 'remaining_total');
    final u = _readNum(credits, 'usedTotal', 'used_total');
    final p = _readNum(credits, 'providedTotal', 'provided_total');
    return '{remaining:$r, used:$u, provided:$p}';
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  const _CheckItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check, size: 18, color: Colors.black),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

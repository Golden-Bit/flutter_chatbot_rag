import 'package:flutter/material.dart';
import 'package:flutter_app/user_manager/pages/payment_page.dart';

class BillingPage extends StatefulWidget {
  final VoidCallback onClose;
  const BillingPage({Key? key, required this.onClose}) : super(key: key);

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  bool _annual = false;

  // map: titolo → { mensile: url, annuale: url }
  static const Map<String, Map<String, String>> _stripeLinks = {
    'Starter': {
      'mensile': 'https://buy.stripe.com/5kQ8wRboD6hKe3Vdg83cc00',
      'annuale': 'https://buy.stripe.com/eVq9AV9gv21u4tl5NG3cc02',
    },
    'Premium': { // qui Premium corrisponde al tuo Pro
      'mensile': 'https://buy.stripe.com/aFafZj78nbC40d5gsk3cc01',
      'annuale': 'https://buy.stripe.com/fZufZj1O3dKc5xp7VO3cc03',
    },
    'Business': {
      'mensile': 'https://buy.stripe.com/5kQeVf2S7fSkf7Z6RK3cc04',
      'annuale': 'https://buy.stripe.com/eVq4gBgIX7lO9NF3Fy3cc05',
    },
  };

  // Dati dei piani
  static const _plans = [
    {
      'title': 'Starter',
      'monthly': '1.99',
      'annual': '19.90',
      'features': [
        'Accesso alle funzioni base',
        '100 richieste mensili',
        'Supporto via email',
      ],
      'button': 'Seleziona',
    },
    {
      'title': 'Premium',
      'monthly': '4.99',
      'annual': '49.90',
      'features': [
        'Tutto di Starter',
        'Richieste illimitate',
        'Accesso API',
      ],
      'button': 'Seleziona',
    },
    {
      'title': 'Business',
      'monthly': '9.99',
      'annual': '99.90',
      'features': [
        'Tutto di Premium',
        'Account dedicato',
        'SLA 24/7',
      ],
      'button': 'Richiedi',
    },
  ];

 Widget _buildPeriodSwitcher() {
    return GestureDetector(
      // permette di toccare fuori dal tappabile per deselect, se ti serve…
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
            // highlight “scorrevole”
            AnimatedAlign(
              alignment: _annual ? Alignment.centerRight : Alignment.centerLeft,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Container(
                width: 120, // metà del parent
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),

            // il testo tappabile
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                    onTap: () => setState(() => _annual = false),
                    child: Center(
                      child: Text(
                        "Mensile",
                        style: TextStyle(
                          color: _annual ? Colors.grey.shade700 : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
                    onTap: () => setState(() => _annual = true),
                    child: Center(
                      child: Text(
                        "Annuale",
                        style: TextStyle(
                          color: _annual ? Colors.white : Colors.grey.shade700,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // X di chiusura sempre in alto a dx con margine
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: widget.onClose,
                child: const Icon(Icons.close, color: Colors.black, size: 28),
              ),
            ),

            // Contenuto principale centrato
            Center(
              child: SingleChildScrollView(
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Titolo
                      const Text(
                        "Fai l'upgrade del tuo piano",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Toggle Mensile/Annuale
                      Center(
                        child: _buildPeriodSwitcher(),
                      ),

                      // distanza ridotta tra toggle e schede
                      const SizedBox(height: 8),

                      // Griglia piani responsive
                      LayoutBuilder(builder: (ctx, constraints) {
                        final isNarrow = constraints.maxWidth < 600;
                        final cardWidth = (constraints.maxWidth - 64) / 3;
                        if (isNarrow) {
                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                for (var plan in _plans) ...[
                                  _PlanCard(
                                    data: plan,
                                    annual: _annual,
                                    width: double.infinity,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ],
                            ),
                          );
                        } else {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var plan in _plans) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: _PlanCard(
                                      data: plan,
                                      annual: _annual,
                                      width: cardWidth,
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          );
                        }
                      }),
                    ],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool annual;
  final double width;

  const _PlanCard({
    required this.data,
    required this.annual,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String;
    final price =
        annual ? data['annual'] as String : data['monthly'] as String;
    final features = data['features'] as List<String>;
    final buttonText = data['button'] as String;

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.black, width: 1.5)),
      elevation: 2,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 500),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titolo
              Text(title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              const SizedBox(height: 8),

              // Prezzo
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$$price',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                  const SizedBox(width: 4),
                  Text(
                    annual ? ' USD/anno' : ' USD/mese',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Feature
              ...features.map(
                (f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 16, color: Colors.black),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(f,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[800])),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Pulsante di selezione
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
onPressed: () {
  final period = annual ? 'annuale' : 'mensile';
  final link = _BillingPageState._stripeLinks[title]?[period];
  if (link != null) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentPage(url: link),
      ),
    );
  } else {
    // fallback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link di pagamento non trovato')),
    );
  }
},
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('Seleziona'),
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


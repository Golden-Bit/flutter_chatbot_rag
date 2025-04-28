import 'package:flutter/material.dart';

class SubscriptionSettingsContent extends StatelessWidget {
  const SubscriptionSettingsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 24),
          _buildInfoBox(),
          const SizedBox(height: 24),
          _buildPaymentSection(), // ← nuovo: etichetta e pulsante allineati orizzontalmente
        ],
      ),
    );
  }

  // HEADER -------------------------------------------------------------------
  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BoxedAI Plus',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Text(
                'Il tuo piano si rinnova automaticamente in data 16 mag 2025',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
            OutlinedButton(
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
              onPressed: () {
                // TODO: Azione per gestione abbonamento
              },
              child: const Text('Gestisci'),
            ),
          ],
        ),
      ],
    );
  }

  // INFO BOX -----------------------------------------------------------------
  Widget _buildInfoBox() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Grazie per aver sottoscritto un abbonamento a BoxedAI Plus. Il tuo piano Plus include:',
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          SizedBox(height: 16),
          _CheckItem('Tutte le funzioni del piano Free'),
          _CheckItem(
              'Limitazioni più ampie per chat, analisi dati avanzata e generazione di immagini'),
          _CheckItem('Modalità vocale standard e avanzata'),
          _CheckItem(
              'Accesso a ricerche approfondite, modelli di ragionamento multipli (o4-mini, o4-mini-high e o3) e un’anteprima di ricerca di GPT‑4.5'),
          _CheckItem('Crea e usa attività, progetti e GPT personalizzati'),
          _CheckItem('Accesso limitato alla generazione di video di Sora'),
          _CheckItem('Opportunità per provare nuove funzioni'),
        ],
      ),
    );
  }

  // PAGAMENTO (etichetta + pulsante) -----------------------------------------
  Widget _buildPaymentSection() {
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
        OutlinedButton(
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
          onPressed: () {
            // TODO: Gestione pagamento
          },
          child: const Text('Gestisci'),
        ),
      ],
    );
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class UsageDialog extends StatefulWidget {
  const UsageDialog({super.key});

  @override
  State<UsageDialog> createState() => _UsageDialogState();
}

class _UsageDialogState extends State<UsageDialog> {
  DateTime? _startDate;
  DateTime? _endDate;

  final double _chatTotal = 0.063;
  final double _docTotal = 0.000;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('it_IT', null);
  }

  Future<void> _pickDate({
    required bool isStart,
    required BuildContext context,
  }) async {
    final initial = isStart ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now();
    final firstDate = DateTime(2023, 1, 1);
    final lastDate = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('it', 'IT'),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && _endDate!.isBefore(_startDate!)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900), // <- larghezza aumentata
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(context),
              const SizedBox(height: 20),
              _buildDateRangeForm(context),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildChatUsageSection()),
                  const SizedBox(width: 24),
                  Expanded(child: _buildDocumentUsageSection()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.bar_chart_rounded, size: 24, color: Colors.black87),
        const SizedBox(width: 8),
        Text(
          'Analisi utilizzo',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Chiudi',
          icon: const Icon(Icons.close, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _buildDateRangeForm(BuildContext context) {
    String _format(DateTime? d) =>
        d == null ? 'Seleziona' : DateFormat('dd MMM y', 'it_IT').format(d);

    return Row(
      children: [
        Expanded(
          child: _DateField(
            label: 'Dal',
            text: _format(_startDate),
            onTap: () => _pickDate(isStart: true, context: context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DateField(
            label: 'Al',
            text: _format(_endDate),
            onTap: () => _pickDate(isStart: false, context: context),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String label) => Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      );

  Widget _buildKeyValue(String key, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(key,
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ),
            Text(value,
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ],
        ),
      );

  Widget _buildChatUsageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Messaggi generati con chatbot'),
        const SizedBox(height: 12),
        Container(
          height: 360,
          decoration: BoxDecoration(
            color: Colors.grey[100], // <- sfondo contenitore
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _UsageCard(
                icon: Icons.message_rounded,
                title: 'Domanda su sintassi Python',
                subtitle: '18 apr 2025 · GPT‑4o‑mini',
                children: [
                  _buildKeyValue('Token input', '152'),
                  _buildKeyValue('Token output', '298'),
                  _buildKeyValue('Costo stimato', '0,010'),
                ],
              ),
              const SizedBox(height: 12),
              _UsageCard(
                icon: Icons.message_outlined,
                title: 'Genera post LinkedIn marketing',
                subtitle: '17 apr 2025 · GPT‑3.5‑turbo',
                children: [
                  _buildKeyValue('Token input', '78'),
                  _buildKeyValue('Token output', '143'),
                  _buildKeyValue('Costo stimato', '0,001'),
                ],
              ),
              const SizedBox(height: 12),
              _UsageCard(
                icon: Icons.message_outlined,
                title: 'Traduci documento tecnico in giapponese',
                subtitle: '15 apr 2025 · GPT‑4o‑mini‑high',
                children: [
                  _buildKeyValue('Token input', '1 024'),
                  _buildKeyValue('Token output', '1 725'),
                  _buildKeyValue('Costo stimato', '0,052'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Totale stimato: ${_chatTotal.toStringAsFixed(3)}',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentUsageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Documenti e media processati'),
        const SizedBox(height: 12),
        Container(
          height: 360,
          decoration: BoxDecoration(
            color: Colors.grey[100], // <- sfondo contenitore
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _UsageCard(
                icon: Icons.picture_as_pdf_rounded,
                title: 'Capitolo‑3‑Manuale‑AI.pdf',
                subtitle: '19 pagine · 1,8 MB',
                children: [
                  _buildKeyValue('Tipo', 'PDF'),
                  _buildKeyValue('Token estratti', '4 539'),
                  _buildKeyValue('Tempo elaborazione', '6 s'),
                ],
              ),
              const SizedBox(height: 12),
              _UsageCard(
                icon: Icons.description_rounded,
                title: 'Budget‑Q2‑2025.docx',
                subtitle: '12 pagine · 426 KB',
                children: [
                  _buildKeyValue('Tipo', 'DOCX'),
                  _buildKeyValue('Token estratti', '2 097'),
                  _buildKeyValue('Tempo elaborazione', '3 s'),
                ],
              ),
              const SizedBox(height: 12),
              _UsageCard(
                icon: Icons.movie_rounded,
                title: 'Spot‑prodotto‑30s.mp4',
                subtitle: '0:30 · 1080p · 12 MB',
                children: [
                  _buildKeyValue('Tipo', 'Video MP4'),
                  _buildKeyValue('Frame analizzati', '450'),
                  _buildKeyValue('Tempo elaborazione', '19 s'),
                ],
              ),
              const SizedBox(height: 12),
              _UsageCard(
                icon: Icons.image_rounded,
                title: 'Schema‑architettura.png',
                subtitle: '2048×1024 · 1,2 MB',
                children: [
                  _buildKeyValue('Tipo', 'PNG'),
                  _buildKeyValue('Descrizione generata', 'Diagramma di rete'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Totale stimato: ${_docTotal.toStringAsFixed(3)}',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}

//=============================================================================
//  WIDGET CARD USO
//=============================================================================
class _UsageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _UsageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white, // <- sfondo card bianco
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.black87),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

//=============================================================================
//  WIDGET CAMPO DATA
//=============================================================================
class _DateField extends StatelessWidget {
  final String label;
  final String text;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
          isDense: true,
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}

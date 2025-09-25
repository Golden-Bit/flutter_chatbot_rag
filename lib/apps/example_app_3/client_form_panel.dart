import 'dart:convert';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';

/// Callbacks che l’host espone al ChatBot
class ClientFormCallbacks extends ChatBotHostCallbacks {
  const ClientFormCallbacks({
    required this.setField,
    required this.fillAll,
    required this.focusField,
  });

  final void Function(String field, dynamic value) setField;
  final void Function(Map<String, dynamic> payload) fillAll;
  final void Function(String field) focusField;
}

/*───────────────────────────────────────────────────────────────────────────*/
/*  TOOL WIDGETS                                                             */
/*───────────────────────────────────────────────────────────────────────────*/

class SetClientFieldWidget extends StatefulWidget {
  const SetClientFieldWidget({
    super.key,
    required this.jsonData,
    required this.onReply,
    required this.pageCbs,
    required this.hostCbs,
  });

  final Map<String, dynamic> jsonData;
  final void Function(String) onReply;
  final ChatBotPageCallbacks pageCbs;
  final ClientFormCallbacks hostCbs;

  @override
  State<SetClientFieldWidget> createState() => _SetClientFieldWidgetState();
}

class _SetClientFieldWidgetState extends State<SetClientFieldWidget> {
  @override
  void initState() {
    super.initState();
    final firstTime = widget.jsonData['is_first_time'] as bool? ?? true;
    final String field = (widget.jsonData['field'] ?? '').toString();
    final dynamic value = widget.jsonData['value'];

    if (firstTime && field.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.hostCbs.setField(field, value);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final field = (widget.jsonData['field'] ?? '').toString();
    final value = widget.jsonData['value'];
    return Card(
      color: Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Impostato "$field" → $value'),
      ),
    );
  }
}

class FillClientFormWidget extends StatefulWidget {
  const FillClientFormWidget({
    super.key,
    required this.jsonData,
    required this.onReply,
    required this.pageCbs,
    required this.hostCbs,
  });

  final Map<String, dynamic> jsonData;
  final void Function(String) onReply;
  final ChatBotPageCallbacks pageCbs;
  final ClientFormCallbacks hostCbs;

  @override
  State<FillClientFormWidget> createState() => _FillClientFormWidgetState();
}

class _FillClientFormWidgetState extends State<FillClientFormWidget> {
  @override
  void initState() {
    super.initState();
    final firstTime = widget.jsonData['is_first_time'] as bool? ?? true;

    // Per massima compatibilità usiamo una stringa JSON nel param "json"
    final raw = (widget.jsonData['json'] ?? '{}').toString();
    Map<String, dynamic> payload = {};
    try { payload = jsonDecode(raw) as Map<String, dynamic>; } catch (_) {}

    if (firstTime && payload.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.hostCbs.fillAll(payload);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Modulo cliente compilato'),
      ),
    );
  }
}

class FocusClientFieldWidget extends StatefulWidget {
  const FocusClientFieldWidget({
    super.key,
    required this.jsonData,
    required this.onReply,
    required this.pageCbs,
    required this.hostCbs,
  });

  final Map<String, dynamic> jsonData;
  final void Function(String) onReply;
  final ChatBotPageCallbacks pageCbs;
  final ClientFormCallbacks hostCbs;

  @override
  State<FocusClientFieldWidget> createState() => _FocusClientFieldWidgetState();
}

class _FocusClientFieldWidgetState extends State<FocusClientFieldWidget> {
  @override
  void initState() {
    super.initState();
    final firstTime = widget.jsonData['is_first_time'] as bool? ?? true;
    final field = (widget.jsonData['field'] ?? '').toString();
    if (firstTime && field.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.hostCbs.focusField(field);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final field = (widget.jsonData['field'] ?? '').toString();
    return Card(
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Focus su "$field"'),
      ),
    );
  }
}

/*───────────────────────────────────────────────────────────────────────────*/
/*  TOOL SPECS (visibili all’LLM)                                            */
/*───────────────────────────────────────────────────────────────────────────*/

const List<String> kClientFields = [
  'full_name','email','phone','company','vat','address','city',
  'zip','country','notes','newsletter','tier','birthday'
];

const ToolSpec kSetClientFieldTool = ToolSpec(
  toolName: 'SetClientFieldWidget',
  description: 'Imposta un singolo campo del form cliente',
  params: [
    ToolParamSpec(
      name: 'field',
      paramType: ParamType.string,
      description: 'Nome campo',
      allowedValues: kClientFields,
      example: 'email',
    ),
    ToolParamSpec(
      name: 'value',
      paramType: ParamType.string,
      description: 'Valore (true/false per newsletter, YYYY-MM-DD per birthday)',
      example: 'jane@acme.com',
    ),
  ],
);

const ToolSpec kFillClientFormTool = ToolSpec(
  toolName: 'FillClientFormWidget',
  description: 'Compila l’intero form cliente con un JSON',
  params: [
    ToolParamSpec(
      name: 'json',
      paramType: ParamType.string,
      description:
          'JSON string con i campi (es. {"full_name":"Mario", "email":"m@x.com"})',
      example:
          '{"full_name":"Mario Rossi","email":"mario@example.com","company":"ACME","newsletter":true}',
    ),
  ],
);

const ToolSpec kFocusClientFieldTool = ToolSpec(
  toolName: 'FocusClientFieldWidget',
  description: 'Porta il focus su un campo del form cliente',
  params: [
    ToolParamSpec(
      name: 'field',
      paramType: ParamType.string,
      description: 'Nome campo',
      allowedValues: kClientFields,
      example: 'full_name',
    ),
  ],
);

/*───────────────────────────────────────────────────────────────────────────*/
/*  PANNELLO SINISTRO: FORM CLIENTE                                          */
/*───────────────────────────────────────────────────────────────────────────*/

class ClientFormPanel extends StatefulWidget with ChatBotExtensions {
  ClientFormPanel({super.key});

  // Stato condiviso (value-notifiers + controller)
  final Map<String, TextEditingController> _c = {
    'full_name': TextEditingController(),
    'email'    : TextEditingController(),
    'phone'    : TextEditingController(),
    'company'  : TextEditingController(),
    'vat'      : TextEditingController(),
    'address'  : TextEditingController(),
    'city'     : TextEditingController(),
    'zip'      : TextEditingController(),
    'country'  : TextEditingController(),
    'notes'    : TextEditingController(),
    'birthday' : TextEditingController(), // YYYY-MM-DD
  };

  final newsletter = ValueNotifier<bool>(false);
  final tier = ValueNotifier<String>('standard');

  // focus map
  final Map<String, FocusNode> _f = {
    for (final k in kClientFields) k: FocusNode()
  };

  /*──────── ChatBotExtensions: host callbacks ───────*/
  @override
  ChatBotHostCallbacks get hostCallbacks => ClientFormCallbacks(
        setField: (field, value) => _applyField(field, value),
        fillAll : (payload) => _applyAll(payload),
        focusField: (field) => _focus(field),
      );

  @override
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders => {
        'SetClientFieldWidget': (data, onR, pCbs, hCbs) => SetClientFieldWidget(
              jsonData: data,
              onReply: onR,
              pageCbs: pCbs,
              hostCbs: hCbs as ClientFormCallbacks,
            ),
        'FillClientFormWidget': (data, onR, pCbs, hCbs) => FillClientFormWidget(
              jsonData: data,
              onReply: onR,
              pageCbs: pCbs,
              hostCbs: hCbs as ClientFormCallbacks,
            ),
        'FocusClientFieldWidget': (data, onR, pCbs, hCbs) => FocusClientFieldWidget(
              jsonData: data,
              onReply: onR,
              pageCbs: pCbs,
              hostCbs: hCbs as ClientFormCallbacks,
            ),
      };

  @override
  List<ToolSpec> get toolSpecs => const [
        kSetClientFieldTool,
        kFillClientFormTool,
        kFocusClientFieldTool,
      ];

  // Helpers invocati dalle callbacks
  void _applyField(String field, dynamic value) {
    switch (field) {
      case 'newsletter':
        final v = (value is bool) ? value : (value.toString().toLowerCase() == 'true');
        newsletter.value = v;
        break;
      case 'tier':
        final v = value.toString();
        if (v.isNotEmpty) tier.value = v; // es: standard | premium | enterprise
        break;
      case 'birthday':
        final raw = value?.toString() ?? '';
        // validazione minimale YYYY-MM-DD
        final ok = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw);
        _c['birthday']!.text = ok ? raw : '';
        break;
      default:
        if (_c.containsKey(field)) {
          _c[field]!.text = value?.toString() ?? '';
        }
        break;
    }
  }

  void _applyAll(Map<String, dynamic> m) {
    m.forEach((k, v) => _applyField(k, v));
  }

  void _focus(String field) {
    if (_f.containsKey(field)) {
      FocusScope.of(_f[field]!.context!).requestFocus(_f[field]);
    }
  }

  // Esporta il modello corrente (per debug / submit)
  Map<String, dynamic> get model => {
        'full_name': _c['full_name']!.text.trim(),
        'email'    : _c['email']!.text.trim(),
        'phone'    : _c['phone']!.text.trim(),
        'company'  : _c['company']!.text.trim(),
        'vat'      : _c['vat']!.text.trim(),
        'address'  : _c['address']!.text.trim(),
        'city'     : _c['city']!.text.trim(),
        'zip'      : _c['zip']!.text.trim(),
        'country'  : _c['country']!.text.trim(),
        'notes'    : _c['notes']!.text.trim(),
        'newsletter': newsletter.value,
        'tier'      : tier.value,
        'birthday'  : _c['birthday']!.text.trim(),
      };

  @override
  State<ClientFormPanel> createState() => _ClientFormPanelState();
}

class _ClientFormPanelState extends State<ClientFormPanel> {
  @override
  void initState() {
    super.initState();
    widget.newsletter.addListener(_refresh);
    widget.tier.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.newsletter.removeListener(_refresh);
    widget.tier.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  Widget _t(String key, String label, {String? hint}) => TextField(
        controller: widget._c[key],
        focusNode: widget._f[key],
        decoration: _dec(label, hint: hint),
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Titolo
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Dati cliente', style: Theme.of(context).textTheme.titleLarge),
            ),

            // Grid responsive minima
            LayoutBuilder(builder: (_, c) {
              final twoCols = c.maxWidth > 640;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: twoCols ? (c.maxWidth - 12)/2 : c.maxWidth, child: _t('full_name', 'Nome completo', hint: 'Mario Rossi')),
                  SizedBox(width: twoCols ? (c.maxWidth - 12)/2 : c.maxWidth, child: _t('email', 'Email', hint: 'mario@example.com')),
                  SizedBox(width: twoCols ? (c.maxWidth - 12)/2 : c.maxWidth, child: _t('phone', 'Telefono', hint: '+39 333 1234567')),
                  SizedBox(width: twoCols ? (c.maxWidth - 12)/2 : c.maxWidth, child: _t('company', 'Azienda', hint: 'ACME S.p.A.')),
                  SizedBox(width: twoCols ? (c.maxWidth - 12)/2 : c.maxWidth, child: _t('vat', 'P. IVA', hint: 'IT01234567890')),
                  SizedBox(width: twoCols ? (c.maxWidth - 12)/2 : c.maxWidth, child: _t('birthday', 'Data di nascita (YYYY-MM-DD)', hint: '1985-06-09')),
                  SizedBox(width: c.maxWidth, child: _t('address', 'Indirizzo', hint: 'Via Roma 1')),
                  SizedBox(width: twoCols ? (c.maxWidth - 12)/2 : c.maxWidth, child: _t('city', 'Città')),
                  SizedBox(width: twoCols ? (c.maxWidth - 12)/2 : c.maxWidth, child: _t('zip', 'CAP')),
                  SizedBox(width: twoCols ? (c.maxWidth - 12)/2 : c.maxWidth, child: _t('country', 'Paese', hint: 'Italia')),
                ],
              );
            }),

            const SizedBox(height: 12),

            // Row: newsletter + tier
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Switch(
                          value: widget.newsletter.value,
                          onChanged: (v) => setState(() => widget.newsletter.value = v),
                        ),
                        const SizedBox(width: 8),
                        const Text('Newsletter'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: widget.tier.value,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(12),
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'standard', child: Text('Standard')),
                        DropdownMenuItem(value: 'premium',  child: Text('Premium')),
                        DropdownMenuItem(value: 'enterprise', child: Text('Enterprise')),
                      ],
                      onChanged: (v) => setState(() => widget.tier.value = v ?? 'standard'),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            _t('notes', 'Note', hint: 'Annotazioni aggiuntive'),

            const SizedBox(height: 16),

            // Footer azioni
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Invia'),
                  onPressed: () {
                    final data = const JsonEncoder.withIndent('  ').convert(widget.model);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dati inviati (demo)')),
                    );
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Payload inviato'),
                        content: SingleChildScrollView(child: Text(data)),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ok'))],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('Pulisci'),
                  onPressed: () {
                    for (final c in widget._c.values) c.clear();
                    widget.newsletter.value = false;
                    widget.tier.value = 'standard';
                    setState(() {});
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

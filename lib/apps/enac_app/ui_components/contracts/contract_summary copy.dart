// lib/apps/enac_app/ui_components/contract_detail_page.dart
// ═══════════════════════════════════════════════════════════════
// ContractDetailPage (FULL) con Documenti (upload/list/CRUD)
// ═══════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html; // upload/download Web
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../logic_components/backend_sdk.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

/// ─────────── Utilità formattazione ───────────
final _dateFmt = DateFormat('dd/MM/yyyy');
final _currencyFmt = NumberFormat.currency(locale: 'it_IT', symbol: '€');

String _fmtDate(DateTime? dt) => (dt == null) ? '—' : _dateFmt.format(dt);

double? _parseMoney(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s0 = v.toString().trim();
  if (s0.isEmpty) return null;
  if (s0.contains(',') && s0.contains('.')) {
    final lastDot = s0.lastIndexOf('.');
    final lastComma = s0.lastIndexOf(',');
    if (lastDot > lastComma) {
      final norm = s0.replaceAll(',', '');
      return double.tryParse(norm);
    } else {
      final norm = s0.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(norm);
    }
  }
  if (s0.contains(',') && !s0.contains('.')) {
    return double.tryParse(s0.replaceAll(',', '.'));
  }
  return double.tryParse(s0);
}

String _fmtMoney(dynamic v) {
  final parsed = _parseMoney(v);
  if (parsed == null) return '—';
  return _currencyFmt.format(parsed);
}

String _yesNo(bool? b) => b == null ? '—' : (b ? 'Sì' : 'No');

/// ─────────── Widgets base (KV + griglia) ───────────
class _KV extends StatelessWidget {
  const _KV(this.k, this.v, {super.key});
  final String k, v;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 11, color: Colors.blueGrey, height: 1.3)),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(v.isEmpty ? '—' : v, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({required this.rows, super.key});
  final List<_KV> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final colW = math.max(180.0, (c.maxWidth - 24) / 2); // 2 colonne responsive
      return Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [for (final kv in rows) SizedBox(width: colW, child: kv)],
      );
    });
  }
}

/// ─────────── Azioni header (icone a destra) ───────────
class _HeaderActionIconsContract extends StatelessWidget {
  const _HeaderActionIconsContract();

  @override
  Widget build(BuildContext context) {
    Color active = Colors.grey.shade700;
    Color disabled = Colors.grey.shade400;
    Widget ico(IconData i, {bool enabled = true, String? tip}) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Tooltip(
            message: tip ?? '',
            child: Icon(i, size: 18, color: enabled ? active : disabled),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ico(Icons.edit, tip: 'Modifica'),
        ico(Icons.file_copy, tip: 'Duplica'),
        ico(Icons.mail, tip: 'Email'),
        ico(Icons.phone, tip: 'Chiama'),
        ico(Icons.cloud_upload, enabled: false, tip: 'Carica'),
      ],
    );
  }
}

/// ─────────── Modello documento UI ───────────
class _DocItem {
  final String id;
  final Map<String, dynamic> meta;
  _DocItem(this.id, this.meta);

  String get name => meta['nome_originale']?.toString() ?? id;
  String get mime => meta['mime']?.toString() ?? 'application/octet-stream';
  int get size => (meta['size'] is num) ? (meta['size'] as num).toInt() : 0;
  String get categoria => meta['categoria']?.toString() ?? 'ALTRO';
}

/// ═══════════════════════════════════════════════════════════════
/// ContractDetailPage — con Documenti (upload/list/CRUD)
/// ═══════════════════════════════════════════════════════════════
class ContractDetailPage extends StatefulWidget {
  const ContractDetailPage({
    super.key,
    required this.contratto,
    required this.sdk,
    required this.user,
    required this.userId,
    required this.entityId,
    required this.contractId,
    this.initialTab = 0,  
  });

  final ContrattoOmnia8 contratto;
final int initialTab;     
  // Necessari per le API Documenti contratto
  final Omnia8Sdk sdk;
  final User user;
  final String userId;
  final String entityId;
  final String contractId;

  @override
  State<ContractDetailPage> createState() => _ContractDetailPageState();
}

class _ContractDetailPageState extends State<ContractDetailPage> {
  /* ----------------- Documenti: stato ----------------- */
  bool _docsLoading = true;
  List<_DocItem> _docs = [];
  String _uploadCategoria = 'CND'; // default per contratto (CND/APP/ALTRO)
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _refreshDocs();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtSize(int b) {
    if (b < 1024) return '$b B';
    final kb = b / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024.0;
    return '${mb.toStringAsFixed(1)} MB';
  }

  IconData _iconForMime(String mime) {
    if (mime.startsWith('image/')) return Icons.image;
    if (mime == 'application/pdf') return Icons.picture_as_pdf;
    if (mime.contains('word') || mime.contains('msword')) return Icons.description;
    if (mime.contains('excel') || mime.contains('spreadsheet')) return Icons.grid_on;
    if (mime.contains('zip') || mime.contains('compressed')) return Icons.archive;
    return Icons.insert_drive_file;
  }

  /* ====================== DOCUMENTI — API WRAPPERS ====================== */

  Future<void> _refreshDocs() async {
    setState(() => _docsLoading = true);
    try {
      final ids = await widget.sdk.listContractDocs(
        widget.userId,
        widget.entityId,
        widget.contractId,
      );
      final metas = await Future.wait(ids.map((id) async {
        try {
          final meta = await widget.sdk.getContractDocMeta(
            widget.userId,
            widget.entityId,
            widget.contractId,
            id,
          );
          return _DocItem(id, meta);
        } catch (_) {
          return _DocItem(id, {'nome_originale': id, 'size': 0, 'mime': ''});
        }
      }).toList());

      setState(() {
        _docs = metas;
      });
    } catch (e) {
      _snack('Impossibile caricare i documenti: $e');
    } finally {
      if (mounted) setState(() => _docsLoading = false);
    }
  }

  Future<void> _downloadDoc(_DocItem d) async {
    try {
      final bytes = await widget.sdk.downloadContractDoc(
        widget.userId,
        widget.entityId,
        widget.contractId,
        d.id,
      );
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final a = html.AnchorElement(href: url)
        ..download = d.name
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      _snack('Download fallito: $e');
    }
  }

  Future<html.File?> _pickFile() async {
    final input = html.FileUploadInputElement()..accept = '*/*';
    input.click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return null;
    return input.files!.first;
  }

  Future<void> _uploadNew() async {
    setState(() => _uploading = true);
    try {
      final file = await _pickFile();
      if (file == null) return;
      final reader = html.FileReader();
      final completer = Completer<void>();
      reader.onLoadEnd.listen((_) => completer.complete());
      reader.readAsArrayBuffer(file);
      await completer.future;

      final bytes = (reader.result as List<int>);
      final base64 = base64Encode(bytes);

      final meta = DocumentoMeta(
        scope: 'CONTRATTO',
        categoria: _uploadCategoria, // CND/APP/ALTRO
        mime: file.type.isEmpty ? 'application/octet-stream' : file.type,
        nomeOriginale: file.name,
        size: file.size,
        metadati: const {},
      );
      final payload = CreateDocumentRequest(meta: meta, contentBase64: base64);

      await widget.sdk.createContractDoc(
        widget.userId,
        widget.entityId,
        widget.contractId,
        payload,
      );

      _snack('Documento caricato.');
      await _refreshDocs();
    } catch (e) {
      _snack('Upload fallito: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _updateDoc(_DocItem d) async {
    try {
      final file = await _pickFile();
      if (file == null) return;
      final reader = html.FileReader();
      final completer = Completer<void>();
      reader.onLoadEnd.listen((_) => completer.complete());
      reader.readAsArrayBuffer(file);
      await completer.future;

      final bytes = (reader.result as List<int>);
      final base64 = base64Encode(bytes);

      final meta = DocumentoMeta(
        scope: d.meta['scope']?.toString() ?? 'CONTRATTO',
        categoria: d.categoria,
        mime: file.type.isEmpty ? 'application/octet-stream' : file.type,
        nomeOriginale: file.name,
        size: file.size,
        metadati: Map<String, dynamic>.from(d.meta['metadati'] ?? const {}),
      );

      final payload = CreateDocumentRequest(meta: meta, contentBase64: base64);

      await widget.sdk.updateContractDoc(
        widget.userId,
        widget.entityId,
        widget.contractId,
        d.id,
        payload,
      );

      _snack('Documento aggiornato.');
      await _refreshDocs();
    } catch (e) {
      _snack('Aggiornamento fallito: $e');
    }
  }

  Future<void> _deleteDoc(_DocItem d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina documento'),
        content: Text('Vuoi eliminare "${d.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.sdk.deleteContractDoc(
        widget.userId,
        widget.entityId,
        widget.contractId,
        d.id,
        deleteBlob: true,
      );
      _snack('Documento eliminato.');
      await _refreshDocs();
    } catch (e) {
      _snack('Eliminazione fallita: $e');
    }
  }

  /// Griglia documenti + sezione upload (stile coerente a ClaimSummary)
  Widget _documentsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Riquadro elenco
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            color: Colors.grey.shade50,
          ),
          child: _docsLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : (_docs.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Nessun documento disponibile.',
                          style: TextStyle(color: Colors.black54)),
                    )
                  : LayoutBuilder(builder: (_, c) {
                      final width = c.maxWidth;
                      int cross = 4;
                      if (width < 480) cross = 1;
                      else if (width < 820) cross = 2;
                      else if (width < 1100) cross = 3;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 3.2,
                        ),
                        itemCount: _docs.length,
                        itemBuilder: (_, i) {
                          final d = _docs[i];
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(_iconForMime(d.mime),
                                    size: 28, color: Colors.grey.shade700),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 14,
                                        runSpacing: 4,
                                        children: [
                                          Text('MIME: ${d.mime}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                          Text('Dim: ${_fmtSize(d.size)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                          Text('Cat: ${d.categoria}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tooltip(
                                      message: 'Scarica',
                                      child: IconButton(
                                        icon: const Icon(Icons.download),
                                        onPressed: () => _downloadDoc(d),
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'Aggiorna file',
                                      child: IconButton(
                                        icon: const Icon(Icons.upload_file),
                                        onPressed: () => _updateDoc(d),
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'Elimina',
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _deleteDoc(d),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      );
                    })),
        ),

        const SizedBox(height: 16),

        // Riquadro upload
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            color: Colors.white,
          ),
          child: Row(
            children: [
              const Text('Carica nuovo documento:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _uploadCategoria,
                items: const [
                  DropdownMenuItem(value: 'CND',  child: Text('Categoria: CND')),
                  DropdownMenuItem(value: 'APP',  child: Text('Categoria: APP')),
                  DropdownMenuItem(value: 'ALTRO', child: Text('Categoria: ALTRO')),
                ],
                onChanged: (v) => setState(() => _uploadCategoria = v!),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
                onPressed: _uploading ? null : _uploadNew,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_uploading ? 'Caricamento…' : 'Seleziona file e carica'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Header sintetico con badge, titolo, info e azioni
  Widget _header(BuildContext ctx) {
    final id = widget.contratto.identificativi;

    RichText pair(String l, String v) => RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 11, color: Colors.black87),
            children: [
              TextSpan(text: '$l ', style: const TextStyle(color: Colors.blueGrey)),
              TextSpan(text: v.isEmpty ? '—' : v),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7E6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // logo/placeholder
          Container(
            width: 56,
            height: 56,
            color: Colors.white,
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported, size: 30, color: Colors.grey),
          ),
          const SizedBox(width: 12),

          // testo a sinistra
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A651),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text('CONTRATTO',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  Text('${id.compagnia} – ${id.numeroPolizza}',
                      style: const TextStyle(
                        fontSize: 22,
                        color: Color(0xFF0082C8),
                        fontWeight: FontWeight.w600,
                      )),
                ]),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 18,
                  runSpacing: 2,
                  children: [
                    pair('RAMO', id.ramo),
                    pair('RISCHIO', id.tipo),
                    pair('PRODOTTO', widget.contratto.ramiEl?.descrizione ?? '—'),
                    pair('INTERMEDIARIO', widget.contratto.unitaVendita?.intermediario ?? '—'),
                  ],
                ),
              ],
            ),
          ),

          // premio + azioni
Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    const _HeaderActionIconsContract(), // ⬅️ ora in ALTO a destra
    const SizedBox(height: 8),
    const Text('PREMIO ANNUO',
        style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
    Text(
      _fmtMoney(widget.contratto.premi?.premio),
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ],
),
        ],
      ),
    );
  }

  /// Contenuto del tab RIEPILOGO (quello “attuale” esistente)
  Widget _buildRiepilogo() {
    final id   = widget.contratto.identificativi;
    final uv   = widget.contratto.unitaVendita;          // opzionale
    final amm  = widget.contratto.amministrativi;        // opzionale
    final prem = widget.contratto.premi;                 // opzionale
    final rinn = widget.contratto.rinnovo;               // opzionale
    final op   = widget.contratto.operativita;           // opzionale
    final pr   = op?.parametriRegolazione;               // opzionale
    final ram  = widget.contratto.ramiEl;                // opzionale

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('Identificativi', [
            _KV('Tipo', id.tipo),
            _KV('TpCar', id.tpCar ?? ''),
            _KV('Ramo', id.ramo),
            _KV('Compagnia', id.compagnia),
            _KV('Numero Polizza', id.numeroPolizza),
          ]),
          _section('Rischio / Prodotto', [
            _KV('Descrizione', ram?.descrizione ?? ''),
          ]),
          _section('Unità Vendita', [
            _KV('Punto Vendita', uv?.puntoVendita ?? ''),
            _KV('Punto Vendita 2', uv?.puntoVendita2 ?? ''),
            _KV('Account', uv?.account ?? ''),
            _KV('Intermediario', uv?.intermediario ?? ''),
          ]),
          _section('Amministrativi', [
            _KV('Effetto', _fmtDate(amm?.effetto)),
            _KV('Scadenza', _fmtDate(amm?.scadenza)),
            _KV('Data Emissione', _fmtDate(amm?.dataEmissione)),
            _KV('Ultima Rata Pagata', _fmtDate(amm?.ultimaRataPagata)),
            _KV('Scadenza Originaria', _fmtDate(amm?.scadenzaOriginaria)),
            _KV('Scadenza Mora', _fmtDate(amm?.scadenzaMora)),
            _KV('Scadenza Vincolo', _fmtDate(amm?.scadenzaVincolo)),
            _KV('Scadenza Copertura', _fmtDate(amm?.scadenzaCopertura)),
            _KV('Fine Copertura Proroga', _fmtDate(amm?.fineCoperturaProroga)),
            _KV('Numero Proposta', amm?.numeroProposta ?? ''),
            _KV('Codice Convenzione', amm?.codConvenzione ?? ''),
            _KV('Frazionamento', amm?.frazionamento ?? ''),
            _KV('Modalità Incasso', amm?.modalitaIncasso ?? ''),
            _KV('Compreso Firma', _yesNo(amm?.compresoFirma)),
          ]),
          _section('Premi', [
            _KV('Premio', _fmtMoney(prem?.premio)),
            _KV('Netto', _fmtMoney(prem?.netto)),
            _KV('Accessori', _fmtMoney(prem?.accessori)),
            _KV('Diritti', _fmtMoney(prem?.diritti)),
            _KV('Imposte', _fmtMoney(prem?.imposte)),
            _KV('Spese', _fmtMoney(prem?.spese)),
            _KV('Fondo', _fmtMoney(prem?.fondo)),
            _KV('Sconto', prem?.sconto == null ? '—' : _fmtMoney(prem?.sconto)),
          ]),
          _section('Rinnovo', [
            _KV('Rinnovo', rinn?.rinnovo ?? ''),
            _KV('Disdetta', rinn?.disdetta ?? ''),
            _KV('Giorni Mora', rinn?.giorniMora ?? ''),
            _KV('Proroga', rinn?.proroga ?? ''),
          ]),
          _section('Operatività', [
            _KV('Regolazione', _yesNo(op?.regolazione)),
            _KV('Inizio', _fmtDate(pr?.inizio)),
            _KV('Fine', _fmtDate(pr?.fine)),
            _KV('Ultima Reg. Emessa', _fmtDate(pr?.ultimaRegEmessa)),
            _KV('Giorni Invio Dati', pr?.giorniInvioDati?.toString() ?? ''),
            _KV('Giorni Pagamento Reg.', pr?.giorniPagReg?.toString() ?? ''),
            _KV('Giorni Mora Regolazione', pr?.giorniMoraRegolazione?.toString() ?? ''),
            _KV('Cadenza Regolazione', pr?.cadenzaRegolazione ?? ''),
          ]),
        ],
      ),
    );
  }

  Widget _section(String t, List<_KV> rows) => Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _SectionGrid(rows: rows),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: const TabBar(
                labelPadding: EdgeInsets.symmetric(horizontal: 16),
                isScrollable: true,
                indicatorColor: Color(0xFF0082C8),
                labelColor: Color(0xFF0A2B4E),
                unselectedLabelColor: Colors.black54,
                tabs: [
                  Tab(text: 'Riepilogo'),
                  Tab(text: 'Documenti'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildRiepilogo(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                    child: _documentsTab(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

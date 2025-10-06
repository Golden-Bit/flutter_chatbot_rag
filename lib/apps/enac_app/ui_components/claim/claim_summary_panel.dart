// lib/apps/enac_app/ui_components/claim_summary_panel.dart
// ─────────────────────────────────────────────────────────────────────────────
// ClaimSummaryPanel (FULL) con Documenti (upload/list/CRUD) + Diario (CRUD)
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html; // upload/download Web
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// SDK e modelli (Sinistro, DocumentoMeta, CreateDocumentRequest,
// DiarioEntryItem, DiarioEntry, ApiException, Omnia8Sdk, ecc.)
import '../../logic_components/backend_sdk.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');
String _fmtDate(DateTime? dt) => (dt == null) ? '—' : _dateFmt.format(dt);

Text _linkText(String s) => Text(
      s,
      style: const TextStyle(
        color: Color(0xFF0082C8),
        fontSize: 13,
        decoration: TextDecoration.underline,
        decorationColor: Color(0xFF0082C8),
      ),
      overflow: TextOverflow.ellipsis,
    );

Widget _pairRight(String l, String v) => RichText(
      textAlign: TextAlign.right,
      text: TextSpan(
        style:
            const TextStyle(fontSize: 12, color: Colors.black87, height: 1.2),
        children: [
          TextSpan(text: '$l ', style: const TextStyle(color: Colors.blueGrey)),
          TextSpan(text: v.isEmpty ? '—' : v),
        ],
      ),
    );

class _KV extends StatelessWidget {
  const _KV(this.k, this.v, {super.key});
  final String k, v;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k,
            style:
                const TextStyle(fontSize: 11, color: Colors.blueGrey, height: 1.3)),
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
      final colW = math.max(220.0, (c.maxWidth - 24) / 2); // 2 colonne comode
      return Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [for (final kv in rows) SizedBox(width: colW, child: kv)],
      );
    });
  }
}

/// Oggetto documento mostrato in UI
class _DocItem {
  final String id;
  final Map<String, dynamic> meta;
  _DocItem(this.id, this.meta);

  String get name => meta['nome_originale']?.toString() ?? id;
  String get mime => meta['mime']?.toString() ?? 'application/octet-stream';
  int get size => (meta['size'] is num) ? (meta['size'] as num).toInt() : 0;
  String get categoria => meta['categoria']?.toString() ?? 'ALTRO';
}

/// ───────────────────────────────────────────────────────────────
/// SUMMARY SINISTRO — con Documenti & Diario funzionanti
/// ───────────────────────────────────────────────────────────────
class ClaimSummaryPanel extends StatefulWidget {
  const ClaimSummaryPanel({
    super.key,
    required this.sinistro,
    required this.viewRow,
    required this.sdk,
    required this.user,
    required this.userId,
    required this.entityId,
    required this.contractId,
    required this.claimId,
  });

  final Sinistro sinistro;
  final Map<String, dynamic> viewRow;

  // Nuovi parametri necessari per chiamare le API
  final Omnia8Sdk sdk;
  final User user;
  final String userId;
  final String entityId;
  final String contractId;
  final String claimId;

  /// Build da viewRow (fallback quando non abbiamo l’oggetto pieno)
  static Sinistro claimFromViewRow(Map<String, dynamic> v) {
    DateTime d(String k) {
      final raw = v[k]?.toString();
      if (raw == null || raw.isEmpty) return DateTime.now();
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return DateTime.now();
      }
    }

    String? s(String k) => v[k]?.toString();

    return Sinistro(
      esercizio: int.tryParse((s('esercizio') ?? s('Esercizio') ?? '0')) ?? 0,
      numeroSinistro:
          (s('numero_sinistro') ?? s('NumeroSinistro') ?? s('num_sinistro') ?? ''),
      numeroSinistroCompagnia:
          s('numero_sinistro_compagnia') ?? s('NumeroSinistroCompagnia'),
      numeroPolizza: s('numero_polizza') ?? s('NumeroPolizza'),
      compagnia: s('compagnia') ?? s('Compagnia'),
      rischio: s('rischio') ?? s('Rischio'),
      intermediario: s('intermediario') ?? s('Intermediario'),
      descrizioneAssicurato:
          s('descrizione_assicurato') ?? s('DescrizioneAssicurato'),
      dataAvvenimento: d('data_avvenimento'),
      citta: s('città') ?? s('citta') ?? s('Citta'),
      indirizzo: s('indirizzo') ?? s('Indirizzo'),
      cap: s('cap') ?? s('CAP'),
      provincia: s('provincia') ?? s('Provincia'),
      codiceStato: s('codice_stato') ?? s('CodiceStato'),
      targa: s('targa') ?? s('Targa'),
      dinamica: s('dinamica') ?? s('Dinamica'),
      statoCompagnia: s('stato_compagnia') ?? s('StatoCompagnia'),
      dataApertura: d('data_apertura'),
      dataChiusura:
          (s('data_chiusura')?.isNotEmpty ?? false) ? d('data_chiusura') : null,
    );
  }

  @override
  State<ClaimSummaryPanel> createState() => _ClaimSummaryPanelState();
}

class _ClaimSummaryPanelState extends State<ClaimSummaryPanel> {
  /* ----------------- Stato Documenti ----------------- */
  bool _docsLoading = true;
  List<_DocItem> _docs = [];
  String _uploadCategoria = 'CLAIM'; // default
  bool _uploading = false;

  /* ----------------- Stato Diario -------------------- */
  bool _diaryLoading = true;
  final TextEditingController _noteCtrl = TextEditingController();
  List<DiaryEntryItem> _diary = [];

  @override
  void initState() {
    super.initState();
    _refreshDocs();
    _refreshDiary();
  }

  /* ====================== Helpers comuni ====================== */
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

  /* ====================== DOCUMENTI ====================== */

  Future<void> _refreshDocs() async {
    setState(() => _docsLoading = true);
    try {
      final ids = await widget.sdk.listClaimDocs(
        widget.userId,
        widget.entityId,
        widget.contractId,
        widget.claimId,
      );
      final metas = await Future.wait(ids.map((id) async {
        try {
          final meta = await widget.sdk.getClaimDocMeta(
            widget.userId,
            widget.entityId,
            widget.contractId,
            widget.claimId,
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
      final bytes = await widget.sdk.downloadClaimDoc(
        widget.userId,
        widget.entityId,
        widget.contractId,
        widget.claimId,
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
        scope: 'SINISTRO',
        categoria: _uploadCategoria,
        mime: file.type.isEmpty ? 'application/octet-stream' : file.type,
        nomeOriginale: file.name,
        size: file.size,
        metadati: const {},
      );
      final payload = CreateDocumentRequest(meta: meta, contentBase64: base64);

      await widget.sdk.createClaimDoc(
        widget.userId,
        widget.entityId,
        widget.contractId,
        widget.claimId,
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

      // Manteniamo categoria/scope, aggiorniamo nome/mime/size
      final meta = DocumentoMeta(
        scope: d.meta['scope']?.toString() ?? 'SINISTRO',
        categoria: d.categoria,
        mime: file.type.isEmpty ? 'application/octet-stream' : file.type,
        nomeOriginale: file.name,
        size: file.size,
        metadati: Map<String, dynamic>.from(d.meta['metadati'] ?? const {}),
      );

      final payload =
          CreateDocumentRequest(meta: meta, contentBase64: base64);

      await widget.sdk.updateClaimDoc(
        widget.userId,
        widget.entityId,
        widget.contractId,
        widget.claimId,
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
      await widget.sdk.deleteClaimDoc(
        widget.userId,
        widget.entityId,
        widget.contractId,
        widget.claimId,
        d.id,
        deleteBlob: true,
      );
      _snack('Documento eliminato.');
      await _refreshDocs();
    } catch (e) {
      _snack('Eliminazione fallita: $e');
    }
  }

  Widget _documentsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Riquadro elenco documenti
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            color: Colors.grey.shade50,
          ),
          child: _docsLoading
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ))
              : (_docs.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Nessun documento disponibile.',
                          style: TextStyle(color: Colors.black54)),
                    )
                  : LayoutBuilder(builder: (_, c) {
                      // griglia responsiva senza scroll proprio
                      final width = c.maxWidth;
                      int cross = 4;
                      if (width < 480) cross = 1;
                      else if (width < 820) cross = 2;
                      else if (width < 1100) cross = 3;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
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
                              border:
                                  Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(_iconForMime(d.mime),
                                    size: 28, color: Colors.grey.shade700),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(d.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 14,
                                        runSpacing: 4,
                                        children: [
                                          Text('MIME: ${d.mime}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54)),
                                          Text('Dim: ${_fmtSize(d.size)}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54)),
                                          Text('Cat: ${d.categoria}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Azioni
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

        // Sezione upload
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
                  DropdownMenuItem(value: 'CLAIM', child: Text('Categoria: CLAIM')),
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

  /* ====================== DIARIO ====================== */

  Future<void> _refreshDiary() async {
    setState(() => _diaryLoading = true);
    try {
      final list = await widget.sdk.listDiaryEntries(
        widget.userId,
        widget.entityId,
        widget.contractId,
        widget.claimId,
      );
      setState(() => _diary = list);
    } catch (e) {
      _snack('Impossibile caricare il diario: $e');
    } finally {
      if (mounted) setState(() => _diaryLoading = false);
    }
  }

  Future<void> _addNote() async {
    final txt = _noteCtrl.text.trim();
    if (txt.isEmpty) {
      _snack('Inserisci il testo della nota.');
      return;
    }
    try {
      final entry = DiarioEntry(
        autore: widget.user.username,
        testo: txt,
        timestamp: DateTime.now(),
      );
      await widget.sdk.addDiaryEntry(
        widget.userId,
        widget.entityId,
        widget.contractId,
        widget.claimId,
        entry,
      );
      _noteCtrl.clear();
      await _refreshDiary();
    } catch (e) {
      _snack('Creazione nota fallita: $e');
    }
  }

  Future<void> _editNote(DiaryEntryItem item) async {
    final ctrl = TextEditingController(text: item.entry.testo);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifica nota'),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Testo della nota',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salva')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final updated = DiarioEntry(
        autore: item.entry.autore,
        testo: ctrl.text.trim(),
        timestamp: DateTime.now(),
      );
      await widget.sdk.updateDiaryEntry(
        widget.userId,
        widget.entityId,
        widget.contractId,
        widget.claimId,
        item.entryId,
        updated,
      );
      await _refreshDiary();
    } catch (e) {
      _snack('Aggiornamento nota fallito: $e');
    }
  }

  Future<void> _deleteNote(DiaryEntryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina nota'),
        content: const Text('Confermi l’eliminazione della nota?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.sdk.deleteDiaryEntry(
        widget.userId,
        widget.entityId,
        widget.contractId,
        widget.claimId,
        item.entryId,
      );
      await _refreshDiary();
    } catch (e) {
      _snack('Eliminazione nota fallita: $e');
    }
  }

  Widget _diaryTab() {
    return Column(
      children: [
        // Editor nuova nota
// Editor nuova nota
Container(
  padding: const EdgeInsets.all(12),
  width: double.infinity,
  decoration: BoxDecoration(
    border: Border.all(color: Colors.grey.shade300),
    color: Colors.white,
  ),
  child: IntrinsicHeight( // ⬅️ Fa sì che il Row prenda l’altezza massima dei figli
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch, // ⬅️ allunga in verticale
      children: [
        Expanded(
          child: TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Scrivi una nota di diario…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // ⬇️ Il pulsante si estende in altezza come il TextField (grazie a stretch+IntrinsicHeight)
        SizedBox(
          width: 160, // scegli larghezza a piacere
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.black87,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
            onPressed: _addNote,
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi'),
          ),
        ),
      ],
    ),
  ),
),

        const SizedBox(height: 12),

        // Lista note
        Expanded(
          child: _diaryLoading
              ? const Center(child: CircularProgressIndicator())
              : (_diary.isEmpty
                  ? Center(
                      child: Text('Nessuna nota presente.',
                          style: TextStyle(color: Colors.grey.shade600)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                      itemCount: _diary.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final it = _diary[i];
                        final ts = it.entry.timestamp != null
                            ? DateFormat('dd/MM/yyyy HH:mm')
                                .format(it.entry.timestamp!)
                            : '';
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.note_alt, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 16,
                                      children: [
                                        Text(it.entry.autore,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        if (ts.isNotEmpty)
                                          Text(ts,
                                              style: const TextStyle(
                                                  color: Colors.black54)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(it.entry.testo),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message: 'Modifica',
                                    child: IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _editNote(it),
                                    ),
                                  ),
                                  Tooltip(
                                    message: 'Elimina',
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _deleteNote(it),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    )),
        ),
      ],
    );
  }

  /* ====================== HEADER + BUILD ====================== */

  static Widget _kvInline(String k, String v) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          children: [
            TextSpan(text: '$k  ', style: const TextStyle(color: Colors.blueGrey)),
            TextSpan(text: v.isEmpty ? '—' : v),
          ],
        ),
      );

  String _fmtScadenza(dynamic v) {
    if (v == null) return '—';
    if (v is DateTime) return _fmtDate(v);
    final s = v.toString();
    if (s.isEmpty) return '—';
    try {
      return _fmtDate(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }

  Widget _header(BuildContext context) {
    String _s(String a, [String? b]) =>
        (widget.viewRow[a] ?? (b != null ? widget.viewRow[b] : null) ?? '')
            .toString();

    final esercizio = _s('esercizio', 'Esercizio').isEmpty
        ? widget.sinistro.esercizio.toString()
        : _s('esercizio', 'Esercizio');
    final nSinistro = _s('numero_sinistro', 'NumeroSinistro').isEmpty
        ? widget.sinistro.numeroSinistro
        : _s('numero_sinistro', 'NumeroSinistro');
    final compagnia = _s('compagnia', 'Compagnia').isEmpty
        ? (widget.sinistro.compagnia ?? '')
        : _s('compagnia', 'Compagnia');
    final numeroPolizza =
        _s('numero_polizza', 'NumeroPolizza').isEmpty
            ? (widget.sinistro.numeroPolizza ?? '')
            : _s('numero_polizza', 'NumeroPolizza');
    final clientName = _s('entity_name', 'cliente').isEmpty
        ? (_s('Cliente', 'CLIENTE'))
        : _s('entity_name', 'cliente');
    final rischio = _s('rischio', 'Rischio').isEmpty
        ? (widget.sinistro.rischio ?? '')
        : _s('rischio', 'Rischio');
    final intermediario = _s('intermediario', 'Intermediario').isEmpty
        ? (widget.sinistro.intermediario ?? '')
        : _s('intermediario', 'Intermediario');

    final dataAvvRaw = widget.viewRow['data_avvenimento'] ??
        widget.viewRow['DataAvvenimento'] ??
        widget.sinistro.dataAvvenimento;
    final dataChiusRaw = widget.viewRow['data_chiusura'] ??
        widget.viewRow['DataChiusura'] ??
        widget.sinistro.dataChiusura;
    final dataAvv = _fmtScadenza(dataAvvRaw);
    final dataChius = _fmtScadenza(dataChiusRaw);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            color: Colors.white,
            alignment: Alignment.center,
            child: const Icon(Icons.local_fire_department,
                size: 28, color: Colors.grey),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text('SINISTRO',
                          style:
                              TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${esercizio.isEmpty ? '-' : esercizio} - ${nSinistro.isEmpty ? '-' : nSinistro}',
                      style: const TextStyle(
                        fontSize: 22,
                        color: Color(0xFF0082C8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 18,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('CONTRATTO  ',
                            style: TextStyle(
                                fontSize: 11, color: Colors.blueGrey)),
                        const Icon(Icons.open_in_new,
                            size: 14, color: Color(0xFF0082C8)),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 360),
                          child: _linkText(
                              '${compagnia.isEmpty ? '—' : compagnia} - ${numeroPolizza.isEmpty ? '—' : numeroPolizza}'),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("ENTITA'  ",
                            style: TextStyle(
                                fontSize: 11, color: Colors.blueGrey)),
                        const Icon(Icons.open_in_new,
                            size: 14, color: Color(0xFF0082C8)),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 360),
                          child:
                              _linkText(clientName.isEmpty ? '—' : clientName),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 24,
                  runSpacing: 2,
                  children: [
                    _kvInline('RISCHIO', rischio),
                    _kvInline('INTERMEDIARIO', intermediario),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const _HeaderActionIcons(),
              const SizedBox(height: 6),
              _pairRight('DATA AVVENIMENTO', dataAvv),
              const SizedBox(height: 4),
              _pairRight('DATA CHIUSURA', dataChius),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String _s(String a, [String? b]) =>
        (widget.viewRow[a] ?? (b != null ? widget.viewRow[b] : null) ?? '')
            .toString();

    final compagnia = _s('compagnia', 'Compagnia').isEmpty
        ? (widget.sinistro.compagnia ?? '')
        : _s('compagnia', 'Compagnia');
    final numeroPolizza = _s('numero_polizza', 'NumeroPolizza').isEmpty
        ? (widget.sinistro.numeroPolizza ?? '')
        : _s('numero_polizza', 'NumeroPolizza');
    final rischio = _s('rischio', 'Rischio').isEmpty
        ? (widget.sinistro.rischio ?? '')
        : _s('rischio', 'Rischio');
    final descAssic =
        _s('descrizione_assicurato', 'DescrizioneAssicurato');

    final esercizio = _s('esercizio', 'Esercizio').isEmpty
        ? widget.sinistro.esercizio.toString()
        : _s('esercizio', 'Esercizio');
    final numSinistro = _s('numero_sinistro', 'NumeroSinistro').isEmpty
        ? widget.sinistro.numeroSinistro
        : _s('numero_sinistro', 'NumeroSinistro');
    final numSinComp =
        _s('numero_sinistro_compagnia', 'NumeroSinistroCompagnia');
    final statoComp = _s('stato_compagnia', 'StatoCompagnia');

    final dataAvvRaw = widget.viewRow['data_avvenimento'] ??
        widget.viewRow['DataAvvenimento'] ??
        widget.sinistro.dataAvvenimento;
    final citta = _s('città', 'citta').isEmpty
        ? (widget.sinistro.citta ?? '')
        : _s('città', 'citta');
    final indirizzo = _s('indirizzo', 'Indirizzo').isEmpty
        ? (widget.sinistro.indirizzo ?? '')
        : _s('indirizzo', 'Indirizzo');
    final cap = _s('cap', 'CAP').isEmpty
        ? (widget.sinistro.cap ?? '')
        : _s('cap', 'CAP');
    final provincia = _s('provincia', 'Provincia').isEmpty
        ? (widget.sinistro.provincia ?? '')
        : _s('provincia', 'Provincia');
    final codiceStato = _s('codice_stato', 'CodiceStato').isEmpty
        ? (widget.sinistro.codiceStato ?? '')
        : _s('codice_stato', 'CodiceStato');
    final targa = _s('targa', 'Targa').isEmpty
        ? (widget.sinistro.targa ?? '')
        : _s('targa', 'Targa');
    final dinamica = _s('dinamica', 'Dinamica').isEmpty
        ? (widget.sinistro.dinamica ?? '')
        : _s('dinamica', 'Dinamica');

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context),

          // Barra tab
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
                Tab(text: 'Diario di Andamento'),
              ],
            ),
          ),

          // Contenuto
          Expanded(
            child: TabBarView(
              children: [
                // ───────── RIEPILOGO ─────────
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Polizza',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _SectionGrid(rows: [
                        _KV('Compagnia', compagnia),
                        _KV('Numero Contratto', numeroPolizza),
                        _KV('Rischio', rischio),
                        _KV('Descrizione Assicurato', descAssic),
                        _KV('Targa', targa),
                      ]),
                      const SizedBox(height: 28),
                      const Text('Numerazione',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _SectionGrid(rows: [
                        _KV('Esercizio', esercizio),
                        _KV('Numero Sinistro', numSinistro),
                        _KV('Num. Sin. Compagnia', numSinComp ?? ''),
                        _KV('Stato Sin. Compagnia', statoComp ?? ''),
                      ]),
                      const SizedBox(height: 28),
                      const Text('Avvenimento',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _SectionGrid(rows: [
                        _KV('Data Avvenimento', _fmtScadenza(dataAvvRaw)),
                        _KV('Città Avvenimento', citta),
                        _KV('Indirizzo Avvenimento', indirizzo),
                        _KV('CAP Avvenimento', cap),
                        _KV('Provincia', provincia),
                        _KV('Codice Stato', codiceStato),
                        _KV('Dinamica del Sinistro', dinamica),
                      ]),
                    ],
                  ),
                ),

                // ───────── DOCUMENTI ─────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
                  child: _documentsTab(),
                ),

                // ───────── DIARIO ─────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: _diaryTab(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActionIcons extends StatelessWidget {
  const _HeaderActionIcons();

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
        ico(Icons.sell, tip: 'Tag'),
        ico(Icons.mail, tip: 'Email'),
        ico(Icons.phone, tip: 'Chiama'),
        ico(Icons.chat_bubble, enabled: false, tip: 'Chat'),
        ico(Icons.chat_bubble_outline, enabled: false, tip: 'Note'),
        ico(Icons.print, enabled: false, tip: 'Stampa'),
      ],
    );
  }
}

// chat_input_widget.dart
// Widget esterno che contiene pari‑pari il vecchio blocco di input,
// AGGIORNATO per visualizzare le immagini pending in miniatura
// sopra il campo testuale, usando il base64 via SDK.
//
// ignore_for_file: camel_case_types, non_constant_identifier_names

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// <-- aggiorna l'import col path reale dove hai lo SDK
import 'package:flutter_app/context_api_sdk.dart';
import 'package:flutter_app/ui_components/dialogs/showMediaUploadDialog.dart';

/// ======================================================================
/// 1) CACHE BASE64 (per non rifare la stessa chiamata /image/base64)
/// ======================================================================
class _B64ImageCache {
  static final _futures = <String, Future<ImageBase64ResponseDto>>{};

  static Future<ImageBase64ResponseDto> get(
    ContextApiSdk sdk,
    String url, {
    bool includeDimensions = true,
    int maxBytes = 10 * 1024 * 1024,
  }) {
    return _futures.putIfAbsent(url, () {
      return sdk.fetchImageAsBase64(
        url,
        includeDimensions: includeDimensions,
        maxBytes: maxBytes,
      );
    });
  }
}

/// ======================================================================
/// 2) MINI-WIDGET per UNA thumb con bottone "X" (rimozione)
/// ======================================================================
class PendingThumbB64 extends StatelessWidget {
  final ContextApiSdk apiSdk;
  final String url;
  final double size;
  final VoidCallback onRemove;

  const PendingThumbB64({
    Key? key,
    required this.apiSdk,
    required this.url,
    required this.onRemove,
    this.size = 64,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageBase64ResponseDto>(
      future: _B64ImageCache.get(apiSdk, url),
      builder: (context, snap) {
        Widget img;
        if (snap.connectionState == ConnectionState.waiting) {
          img = Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        } else if (snap.hasError || !snap.hasData) {
          img = Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.broken_image),
          );
        } else {
          final bytes = base64Decode(snap.data!.base64Raw);
          img = ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        }

        return Stack(
          children: [
          img,
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

/// ======================================================================
/// 3) STRIP ORIZZONTALE con tutte le immagini pending
/// ======================================================================
class PendingImagesStrip extends StatelessWidget {
  final ContextApiSdk apiSdk;
  final List<Map<String, dynamic>> pendingImages;
  final void Function(int index) onRemoveImage;

  const PendingImagesStrip({
    Key? key,
    required this.apiSdk,
    required this.pendingImages,
    required this.onRemoveImage,
  }) : super(key: key);

  String? _readUrl(Map<String, dynamic> img) {
    if (img['type'] == 'image_url') {
      return img['image_url']?['url'] as String?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (pendingImages.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: pendingImages.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final url = _readUrl(pendingImages[i]);

            if (url == null) {
              // placeholder se manca l'URL
              return Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.broken_image),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => onRemoveImage(i),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }

            return PendingThumbB64(
              apiSdk: apiSdk,
              url: url,
              size: 64,
              onRemove: () => onRemoveImage(i),
            );
          },
        ),
      ),
    );
  }
}

/// ======================================================================
/// 4) CHAT INPUT WIDGET (riscritto e aggiornato completamente)
/// ======================================================================
class ChatInputWidget extends StatelessWidget {
  // === proprietà che il vecchio codice usava direttamente ===============
  final ScrollController _inputScroll;
  final TextEditingController _controller;
  final FocusNode _inputFocus;
  final bool _isListening;
  final bool _isStreaming;
  final bool _isCostLoading;
  final double _liveCost;
  final void Function() _listen;
  final void Function() _stopStreaming;
  final void Function(String) _handleUserInput;
  final void Function(String) _updateLiveCost;
  final void Function() _showContextDialog;
  final Future<void> Function({required bool isMedia}) _uploadFileForChatAsync;
  final dynamic localizations; // tipizzato dynamic per non alterare nulla

  /// NEW: immagini attaccate dall’utente in attesa di essere mandate
  final List<Map<String, dynamic>> pendingInputImages;
  final void Function(Map<String, dynamic>) onAddImage;
  final void Function(int) onRemoveImage;

  /// NEW: serve per fetchare base64 dal backend
  final ContextApiSdk apiSdk;

  final bool isSending;

  const ChatInputWidget({
    super.key,
    required ScrollController inputScroll,
    required TextEditingController controller,
    required FocusNode inputFocus,
    required bool isListening,
    required bool isStreaming,
    required bool isCostLoading,
    required double liveCost,
    required void Function() listen,
    required void Function() stopStreaming,
    required void Function(String) handleUserInput,
    required void Function(String) updateLiveCost,
    required void Function() showContextDialog,
    required Future<void> Function({required bool isMedia}) uploadFileForChatAsync,
    required this.localizations,
    // NEW
    required this.pendingInputImages,
    required this.onAddImage,
    required this.onRemoveImage,
    required this.apiSdk, // NEW
    required this.isSending,
  })  : _inputScroll = inputScroll,
        _controller = controller,
        _inputFocus = inputFocus,
        _isListening = isListening,
        _isStreaming = isStreaming,
        _isCostLoading = isCostLoading,
        _liveCost = liveCost,
        _listen = listen,
        _stopStreaming = stopStreaming,
        _handleUserInput = handleUserInput,
        _updateLiveCost = updateLiveCost,
        _showContextDialog = showContextDialog,
        _uploadFileForChatAsync = uploadFileForChatAsync;

  /// Dialog semplificato per aggiungere un’immagine da URL.
  void _showAddImageDialog(BuildContext context) {
    final urlCtrl = TextEditingController();
    String detailVal = 'auto';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Allega immagine da URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL immagine',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'detail'),
              value: detailVal,
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('auto')),
                DropdownMenuItem(value: 'low', child: Text('low')),
                DropdownMenuItem(value: 'high', child: Text('high')),
              ],
              onChanged: (v) => detailVal = v ?? 'auto',
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Annulla'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Aggiungi'),
            onPressed: () {
              final url = urlCtrl.text.trim();
              if (url.isEmpty) return;
              onAddImage({
                'type': 'image_url',
                'image_url': {'url': url, 'detail': detailVal},
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  /// Dialog media “completo” (file o url). Se è file vero → delega all’upload
  /// (non potendo usare fetch base64 su un file locale).
  Future<void> _openMediaDialog(BuildContext context) async {
    final res = await showMediaUploadDialog(context);
    if (res == null) return;

    if (res.source == MediaSource.file) {
      // Selezione file locale:
      // non possiamo chiamare /image/base64 con bytes locali (l’endpoint accetta URL),
      // quindi deleghiamo all’upload verso il backend (che poi potrà generare un URL).
      await _uploadFileForChatAsync(isMedia: true);
    } else {
      // URL → aggiungo a pending (anteprima sopra il box)
      final url = (res.url ?? '').trim();
      if (url.isEmpty) return;
      onAddImage({
        'type': 'image_url',
        'image_url': {'url': url, 'detail': 'auto'},
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Container di input unificato (testo + icone + mic/invia)
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double availableWidth = constraints.maxWidth;
          final double containerWidth =
              (availableWidth > 800) ? 800 : availableWidth;

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: containerWidth,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4.0,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─────────────────────────────────────────────
                  // STRIP MINIATURE IMMAGINI (SE PRESENTI)
                  // ─────────────────────────────────────────────
                  if (pendingInputImages.isNotEmpty) ...[
                    PendingImagesStrip(
                      apiSdk: apiSdk,
                      pendingImages: pendingInputImages,
                      onRemoveImage: onRemoveImage,
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE0E0E0),
                    ),
                  ],

                  // RIGA 1: Campo di input testuale
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 150,
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        controller: _inputScroll,
                        child: TextField(
                          enabled: !isSending,
                          controller: _controller,
                          focusNode: _inputFocus,
                          minLines: 1,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.send,
                          decoration: const InputDecoration(
                            hintText: 'Scrivi qui…',
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                          onChanged: _updateLiveCost,
                          onSubmitted: (value) => _handleUserInput(value),
                        ),
                      ),
                    ),
                  ),

                  // Divider sottile per separare input text e icone
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE0E0E0),
                  ),

                  // RIGA 2: Icone in basso (contesti, doc, media) + mic/freccia
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 0.0),
                    child: Row(
                      children: [
                        // Icona contesti
                        IconButton(
                          icon: SvgPicture.network(
                            'https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element2.svg',
                            width: 24,
                            height: 24,
                            color: Colors.grey,
                          ),
                          tooltip: localizations.knowledgeBoxes,
                          onPressed: _showContextDialog,
                        ),
                        // Icona doc
                        IconButton(
                          icon: SvgPicture.network(
                            'https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element7.svg',
                            width: 24,
                            height: 24,
                            color: Colors.grey,
                          ),
                          tooltip: localizations.upload_document,
                          onPressed: () =>
                              _uploadFileForChatAsync(isMedia: false),
                        ),
                        // Icona media (URL/file)
                        IconButton(
                          icon: SvgPicture.network(
                            'https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element8.svg',
                            width: 24,
                            height: 24,
                            color: Colors.grey,
                          ),
                          tooltip: localizations.upload_media,
                          onPressed: () => _openMediaDialog(context),
                        ),

                        const Spacer(),

                        // Cost estimation (o spinner)
                        _isCostLoading
                            ? const SizedBox(
                                width: 40,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                "\$${_liveCost.toStringAsFixed(4)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                        const SizedBox(width: 8),

                        // Pulsante finale
                        isSending
                            ? const Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 8.0),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _isStreaming
                                // streaming in corso → STOP ▢
                                ? IconButton(
                                    icon: const Icon(Icons.stop, size: 24),
                                    tooltip: 'Interrompi risposta',
                                    onPressed: _stopStreaming,
                                  )
                                // nessuno stream → mic / send
                                : (_controller.text.isEmpty
                                    ? IconButton(
                                        icon: Icon(_isListening
                                            ? Icons.mic_off
                                            : Icons.mic),
                                        tooltip:
                                            localizations.enable_mic,
                                        onPressed: _listen,
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.send),
                                        tooltip:
                                            localizations.send_message,
                                        onPressed: () => _handleUserInput(
                                            _controller.text),
                                      )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

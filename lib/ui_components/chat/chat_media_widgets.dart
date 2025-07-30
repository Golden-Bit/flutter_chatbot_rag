import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/context_api_sdk.dart';

/// Cache *semplice* in memoria.
/// - key = URL immagine
/// - value = Future della risposta per evitare doppie richieste durante i rebuild
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


class B64Image extends StatelessWidget {
  final ContextApiSdk apiSdk;
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const B64Image({
    Key? key,
    required this.apiSdk,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageBase64ResponseDto>(
      future: _B64ImageCache.get(apiSdk, url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ??
              SizedBox(
                width: width,
                height: height,
                child: const Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return errorWidget ??
              Container(
                color: Colors.grey.shade200,
                width: width,
                height: height,
                child: const Icon(Icons.broken_image),
              );
        }

        final dto = snapshot.data!;
        final bytes = base64Decode(dto.base64Raw);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
        );
      },
    );
  }
}


class ImagesGallery extends StatelessWidget {
  final List<Map<String, dynamic>> images;
  final void Function(int index) onTapImage;
  final ContextApiSdk apiSdk; // NEW

  const ImagesGallery({
    Key? key,
    required this.images,
    required this.onTapImage,
    required this.apiSdk,     // NEW
  }) : super(key: key);

  String? _readUrl(Map<String, dynamic> img) {
    if (img['type'] == 'image_url') {
      return img['image_url']?['url'] as String?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final url = _readUrl(images[i]);
          return GestureDetector(
            onTap: () => onTapImage(i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: url == null
                  ? Container(
                      width: 90,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image),
                    )
                  : B64Image(
                      apiSdk: apiSdk,
                      url: url,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
            ),
          );
        },
      ),
    );
  }
}

void openFullScreenGallery(
  BuildContext context,
  List<Map<String, dynamic>> images,
  int initialIndex,
  ContextApiSdk apiSdk, // NEW
) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withOpacity(0.9),
      pageBuilder: (_, __, ___) {
        return FullScreenGallery(
          images: images,
          initialIndex: initialIndex,
          apiSdk: apiSdk,   // NEW
        );
      },
    ),
  );
}

class FullScreenGallery extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;
  final ContextApiSdk apiSdk; // NEW

  const FullScreenGallery({
    Key? key,
    required this.images,
    required this.initialIndex,
    required this.apiSdk,
  }) : super(key: key);

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  String? _readUrl(Map<String, dynamic> img) {
    if (img['type'] == 'image_url') {
      return img['image_url']?['url'] as String?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.9),
        body: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                controller: _ctrl,
                itemCount: widget.images.length,
                itemBuilder: (_, i) {
                  final url = _readUrl(widget.images[i]);
                  if (url == null) {
                    return const Center(
                      child: Icon(Icons.broken_image, color: Colors.white),
                    );
                  }
                  return InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: B64Image(
                        apiSdk: widget.apiSdk,
                        url: url,
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

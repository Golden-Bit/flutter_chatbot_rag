import 'dart:html' as html;
import 'dart:ui'  as ui;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class JSRunnerWidgetTool extends StatefulWidget {
  /// jsonData es.: { "code": "...", "height": 300 }
  final Map<String, dynamic> jsonData;
  const JSRunnerWidgetTool({super.key, required this.jsonData});

  @override
  State<JSRunnerWidgetTool> createState() => _JSRunnerWidgetToolState();
}

class _JSRunnerWidgetToolState extends State<JSRunnerWidgetTool> {
  late final String    _viewType;
  static final _uuid   = Uuid();
  late html.IFrameElement _iframe;
  bool _isInteractive = false;                     // 🔸 di default OFF

  @override
  void initState() {
    super.initState();
    _viewType = 'js-runner-${_uuid.v4()}';

    ui.platformViewRegistry.registerViewFactory(_viewType, (_) {
      _iframe = html.IFrameElement()
        ..style.width  = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..style.overflow = 'hidden'
        ..style.pointerEvents = 'none'              // 🔸 blocca al primo render
        ..setAttribute('sandbox', 'allow-scripts allow-same-origin')
        ..srcdoc = _buildHtml(widget.jsonData['code'] ?? "// write JS here");

      // inoltra la rotella del mouse alla pagina Flutter
      _iframe.onLoad.listen((_) {
        _iframe.contentWindow?.addEventListener('wheel', (event) {
          final e = event as html.WheelEvent;
          html.window.postMessage({'deltaY': e.deltaY}, '*');
        });
      });
      return _iframe;
    });

    // sblocca lo scroll della chat padre
    html.window.onMessage.listen((event) {
      if (!mounted) return;
      final data = event.data;
      if (data is Map && data['deltaY'] is num) {
        Scrollable.ensureVisible(
          context,
          alignment: 0,
          duration: const Duration(milliseconds: 1),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  // switch interattività
  void _toggleInteractivity() {
    setState(() => _isInteractive = !_isInteractive);
    _iframe.style.pointerEvents = _isInteractive ? 'auto' : 'none';
  }

  // HTML centrato con Flexbox
  String _buildHtml(String js) => '''
<!DOCTYPE html><html><head><meta charset="utf-8">
<link rel="preconnect" href="https://cdn.jsdelivr.net">
<script src="https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js"></script>
<style>
  html,body{margin:0;height:100%;display:flex;justify-content:center;align-items:center;font-family:monospace;}
  #wrapper{display:flex;flex-direction:column;align-items:center;gap:12px;}
  pre{margin:0;white-space:pre-wrap;text-align:center;}
  #chart{width:600px;height:400px;}
</style></head><body>
<div id="wrapper"><pre id="out"></pre><div id="chart"></div></div>
<script>
  try{
    const out=(...a)=>document.getElementById('out').textContent+=a.join(' ')+'\\n';
    console.log=out;console.error=out;
    ${js}
  }catch(e){console.error(e);}
</script></body></html>
''';

  @override
  Widget build(BuildContext context) {
    final double h = (widget.jsonData['height'] ?? 300).toDouble();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,   // pulsante a dx
        children: [
          // barra dei comandi
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 4),
            child: Tooltip(
              message: _isInteractive ? 'Blocca interazione' : 'Sblocca interazione',
              child: InkWell(
                onTap: _toggleInteractivity,
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isInteractive ? Icons.lock_open : Icons.lock,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // iframe vero e proprio
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: h,
              width : double.infinity,
              child : HtmlElementView(viewType: _viewType),
            ),
          ),
        ],
      ),
    );
  }
}

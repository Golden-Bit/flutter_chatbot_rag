import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

/// Widget Flutter per integrare il TradingView "Advanced Real-Time Chart Widget"
class TradingViewAdvancedChart extends StatelessWidget {
  final bool autosize;
  final String symbol;
  final String timezone;
  final String theme;
  final String style;
  final String locale;
  final bool withDateRanges;
  final String range;
  final bool hideSideToolbar;
  final bool allowSymbolChange;
  final List<String> watchlist;
  final bool details;
  final bool hotlist;
  final bool calendar;
  final List<String> studies;
  final bool showPopupButton;
  final String popupWidth;
  final String popupHeight;
  final String supportHost;

  /// Larghezza e altezza del widget visualizzato nella UI Flutter (in pixel)
  final double width;
  final double height;

  TradingViewAdvancedChart({
    Key? key,
    this.autosize = true,
    required this.symbol,
    this.timezone = "Etc/UTC",
    this.theme = "dark",
    this.style = "1",
    this.locale = "en",
    this.withDateRanges = true,
    this.range = "YTD",
    this.hideSideToolbar = false,
    this.allowSymbolChange = true,
    this.watchlist = const ["OANDA:XAUUSD"],
    this.details = true,
    this.hotlist = true,
    this.calendar = false,
    this.studies = const ["STD;Accumulation_Distribution"],
    this.showPopupButton = true,
    this.popupWidth = "1000",
    this.popupHeight = "650",
    this.supportHost = "https://www.tradingview.com",
    this.width = 800,
    this.height = 600,
  }) : super(key: key) {
    // Genera un ID univoco per il widget
    final String viewId =
        'tradingview-advanced-chart-${symbol.hashCode}-${DateTime.now().millisecondsSinceEpoch}';

    // Crea il contenuto HTML dinamico sostituendo i parametri
    final String htmlContent = """
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
<style>
  html, body { 
    margin: 0; 
    padding: 0; 
    height: 100%; 
    width: 100%; 
  }
</style>
  </head>
  <body>
    <!-- TradingView Widget BEGIN -->
    <div class="tradingview-widget-container" style="height:100%;width:100%">
      <div class="tradingview-widget-container__widget" style="height:calc(100% - 32px);width:100%"></div>
      <div class="tradingview-widget-copyright">
        <a href="https://www.tradingview.com/" rel="noopener nofollow" target="_blank">
          <span class="blue-text">Track all markets on TradingView</span>
        </a>
      </div>
      <script type="text/javascript" src="https://s3.tradingview.com/external-embedding/embed-widget-advanced-chart.js" async>
      {
        "autosize": $autosize,
        "symbol": "$symbol",
        "timezone": "$timezone",
        "theme": "$theme",
        "style": "$style",
        "locale": "$locale",
        "withdateranges": $withDateRanges,
        "range": "$range",
        "hide_side_toolbar": $hideSideToolbar,
        "allow_symbol_change": $allowSymbolChange,
        "watchlist": ${_listToJson(watchlist)},
        "details": $details,
        "hotlist": $hotlist,
        "calendar": $calendar,
        "studies": ${_listToJson(studies)},
        "show_popup_button": $showPopupButton,
        "popup_width": "$popupWidth",
        "popup_height": "$popupHeight",
        "support_host": "$supportHost"
      }
      </script>
    </div>
    <!-- TradingView Widget END -->
  </body>
</html>
""";

    // Crea un blob HTML e genera un URL oggetto
    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Crea un elemento IFrame per visualizzare il contenuto HTML
    final html.IFrameElement iFrameElement = html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..width = '100%'
      ..height = '100%';

    // Registra il view factory con l'ID univoco
    ui.platformViewRegistry.registerViewFactory(viewId, (int viewId) => iFrameElement);
    _viewId = viewId;
  }

  late final String _viewId;

  // Funzione helper per convertire una lista in una stringa JSON
  static String _listToJson(List<String> list) {
    final escaped = list.map((e) => '"${e.replaceAll('"', '\\"')}"').join(', ');
    return '[$escaped]';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

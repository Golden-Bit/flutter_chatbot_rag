import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/widgets.dart';

/// Widget Flutter per integrare il TradingView "Market Overview Widget"
class TradingViewMarketOverview extends StatelessWidget {
  final String colorTheme;
  final String dateRange;
  final bool showChart;
  final String locale;
  final String width; // es. "100%" o "800"
  final int height;   // Altezza in pixel (es. 700)
  final String largeChartUrl;
  final bool isTransparent;
  final bool showSymbolLogo;
  final bool showFloatingTooltip;
  final String plotLineColorGrowing;
  final String plotLineColorFalling;
  final String gridLineColor;
  final String scaleFontColor;
  final String belowLineFillColorGrowing;
  final String belowLineFillColorFalling;
  final String belowLineFillColorGrowingBottom;
  final String belowLineFillColorFallingBottom;
  final String symbolActiveColor;
  final String tabs; // JSON string con la configurazione delle tabs

  TradingViewMarketOverview({
    Key? key,
    this.colorTheme = "dark",
    this.dateRange = "12M",
    this.showChart = true,
    this.locale = "en",
    this.width = "100%",
    this.height = 700,
    this.largeChartUrl = "",
    this.isTransparent = false,
    this.showSymbolLogo = true,
    this.showFloatingTooltip = true,
    this.plotLineColorGrowing = "rgba(41, 98, 255, 1)",
    this.plotLineColorFalling = "rgba(41, 98, 255, 1)",
    this.gridLineColor = "rgba(42, 46, 57, 0)",
    this.scaleFontColor = "rgba(219, 219, 219, 1)",
    this.belowLineFillColorGrowing = "rgba(41, 98, 255, 0.12)",
    this.belowLineFillColorFalling = "rgba(41, 98, 255, 0.12)",
    this.belowLineFillColorGrowingBottom = "rgba(41, 98, 255, 0)",
    this.belowLineFillColorFallingBottom = "rgba(41, 98, 255, 0)",
    this.symbolActiveColor = "rgba(41, 98, 255, 0.12)",
    this.tabs = '''[
      {
        "title": "Indices",
        "symbols": [
          {"s": "FOREXCOM:SPXUSD", "d": "S&P 500 Index"},
          {"s": "FOREXCOM:NSXUSD", "d": "US 100 Cash CFD"},
          {"s": "FOREXCOM:DJI", "d": "Dow Jones Industrial Average Index"},
          {"s": "INDEX:NKY", "d": "Japan 225"},
          {"s": "INDEX:DEU40", "d": "DAX Index"},
          {"s": "FOREXCOM:UKXGBP", "d": "FTSE 100 Index"}
        ],
        "originalTitle": "Indices"
      },
      {
        "title": "Futures",
        "symbols": [
          {"s": "CME_MINI:ES1!", "d": "S&P 500"},
          {"s": "CME:6E1!", "d": "Euro"},
          {"s": "COMEX:GC1!", "d": "Gold"},
          {"s": "NYMEX:CL1!", "d": "WTI Crude Oil"},
          {"s": "NYMEX:NG1!", "d": "Gas"},
          {"s": "CBOT:ZC1!", "d": "Corn"}
        ],
        "originalTitle": "Futures"
      },
      {
        "title": "Bonds",
        "symbols": [
          {"s": "CBOT:ZB1!", "d": "T-Bond"},
          {"s": "CBOT:UB1!", "d": "Ultra T-Bond"},
          {"s": "EUREX:FGBL1!", "d": "Euro Bund"},
          {"s": "EUREX:FBTP1!", "d": "Euro BTP"},
          {"s": "EUREX:FGBM1!", "d": "Euro BOBL"}
        ],
        "originalTitle": "Bonds"
      },
      {
        "title": "Forex",
        "symbols": [
          {"s": "FX:EURUSD", "d": "EUR to USD"},
          {"s": "FX:GBPUSD", "d": "GBP to USD"},
          {"s": "FX:USDJPY", "d": "USD to JPY"},
          {"s": "FX:USDCHF", "d": "USD to CHF"},
          {"s": "FX:AUDUSD", "d": "AUD to USD"},
          {"s": "FX:USDCAD", "d": "USD to CAD"}
        ],
        "originalTitle": "Forex"
      }
    ]''',
  }) : super(key: key) {
    // Genera un ID univoco per la view factory
    final String viewId =
        'tradingview-market-overview-${DateTime.now().millisecondsSinceEpoch}';

    // Crea il contenuto HTML sostituendo i parametri
    final String htmlContent = """
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <style>
      html, body { margin: 0; padding: 0; height: 100%; }
.tradingview-widget-container {
  margin: 0 auto;
  max-width: 600px;     /* limite massimo di 600 px */
  width: 100%;          /* si adatta se meno di 600 px */
  display: block;
}
    </style>
  </head>
  <body>
    <!-- TradingView Widget BEGIN -->
    <div class="tradingview-widget-container">
      <div class="tradingview-widget-container__widget"></div>
      <div class="tradingview-widget-copyright">
        <a href="https://www.tradingview.com/" rel="noopener nofollow" target="_blank">
          <span class="blue-text">Track all markets on TradingView</span>
        </a>
      </div>
      <script type="text/javascript" src="https://s3.tradingview.com/external-embedding/embed-widget-market-overview.js" async>
      {
        "colorTheme": "$colorTheme",
        "dateRange": "$dateRange",
        "showChart": ${showChart.toString()},
        "locale": "$locale",
        "width": "$width",
        "height": "$height",
        "largeChartUrl": "$largeChartUrl",
        "isTransparent": ${isTransparent.toString()},
        "showSymbolLogo": ${showSymbolLogo.toString()},
        "showFloatingTooltip": ${showFloatingTooltip.toString()},
        "plotLineColorGrowing": "$plotLineColorGrowing",
        "plotLineColorFalling": "$plotLineColorFalling",
        "gridLineColor": "$gridLineColor",
        "scaleFontColor": "$scaleFontColor",
        "belowLineFillColorGrowing": "$belowLineFillColorGrowing",
        "belowLineFillColorFalling": "$belowLineFillColorFalling",
        "belowLineFillColorGrowingBottom": "$belowLineFillColorGrowingBottom",
        "belowLineFillColorFallingBottom": "$belowLineFillColorFallingBottom",
        "symbolActiveColor": "$symbolActiveColor",
        "tabs": $tabs
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

    // Crea l'elemento IFrame con le dimensioni desiderate
    final html.IFrameElement iFrameElement = html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..width = '100%'
      ..height = '$height';

    // Registra la view factory con l'id univoco
    ui.platformViewRegistry.registerViewFactory(viewId, (int viewId) => iFrameElement);
    _viewId = viewId;
  }

  late final String _viewId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity , //.tryParse(width) ?? double.infinity,
      height: height.toDouble(),
      child: HtmlElementView(viewType: _viewId),
    );
  }
}


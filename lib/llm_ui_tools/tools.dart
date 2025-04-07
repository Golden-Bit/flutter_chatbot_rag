import 'package:flutter/material.dart';
import 'package:flutter_app/llm_ui_tools/utilities/advanced_chart.dart';
import 'package:flutter_app/llm_ui_tools/utilities/custom_chart.dart';
import 'package:flutter_app/llm_ui_tools/utilities/market_overview.dart';
import 'package:flutter_app/llm_ui_tools/utilities/radar_chart.dart';
// Assicurati di importare il file in cui è definito RadarChartWidget e RadarIndicatorData.


class RadarChartWidgetTool extends StatelessWidget {
  final Map<String, dynamic> jsonData;
  final void Function(String) onReply; // Callback per eventuali interazioni, per compatibilità con widgetMap.

  const RadarChartWidgetTool({
    Key? key,
    required this.jsonData,
    required this.onReply,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Estrai i parametri dal JSON con dei valori di default
    final String title = jsonData['title'] ?? 'Radar Chart';
    final double width = (jsonData['width'] is num)
        ? (jsonData['width'] as num).toDouble()
        : 400.0;
    final double height = (jsonData['height'] is num)
        ? (jsonData['height'] as num).toDouble()
        : 400.0;

    // Estrai e trasforma la lista degli indicatori
    final List<dynamic> indicatorsJson = jsonData['indicators'] ?? [];
    final List<RadarIndicatorData> indicators = indicatorsJson.map((e) {
      return RadarIndicatorData(
        name: e['name'] ?? '',
        max: (e['max'] is num) ? (e['max'] as num).toDouble() : 10.0,
        value: (e['value'] is num) ? (e['value'] as num).toDouble() : 0.0,
      );
    }).toList();

    // Costruisci il RadarChartWidget con i parametri estratti
    return RadarChartWidget(
      title: title,
      width: width,
      height: height,
      indicators: indicators,
    );
  }
}


class TradingViewAdvancedChartWidget extends StatelessWidget {
  final Map<String, dynamic> jsonData;
  final void Function(String) onReply;

  const TradingViewAdvancedChartWidget({
    Key? key,
    required this.jsonData,
    required this.onReply,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TradingViewAdvancedChart(
      autosize: jsonData["autosize"] ?? true,
      symbol: jsonData["symbol"] ?? "AAPL",
      timezone: jsonData["timezone"] ?? "Etc/UTC",
      theme: jsonData["theme"] ?? "dark",
      style: jsonData["style"] ?? "1",
      locale: jsonData["locale"] ?? "en",
      withDateRanges: jsonData["withDateRanges"] ?? true,
      range: jsonData["range"] ?? "YTD",
      hideSideToolbar: jsonData["hideSideToolbar"] ?? false,
      allowSymbolChange: jsonData["allowSymbolChange"] ?? true,
      watchlist: jsonData["watchlist"] != null ? List<String>.from(jsonData["watchlist"]) : const ["OANDA:XAUUSD"],
      details: jsonData["details"] ?? true,
      hotlist: jsonData["hotlist"] ?? true,
      calendar: jsonData["calendar"] ?? false,
      studies: jsonData["studies"] != null ? List<String>.from(jsonData["studies"]) : const ["STD;Accumulation_Distribution"],
      showPopupButton: jsonData["showPopupButton"] ?? true,
      popupWidth: jsonData["popupWidth"] ?? "1000",
      popupHeight: jsonData["popupHeight"] ?? "650",
      supportHost: jsonData["supportHost"] ?? "https://www.tradingview.com",
      width: (jsonData["width"] is num) ? (jsonData["width"] as num).toDouble() : 800,
      height: (jsonData["height"] is num) ? (jsonData["height"] as num).toDouble() : 600,
    );
  }
}


class TradingViewMarketOverviewWidget extends StatelessWidget {
  final Map<String, dynamic> jsonData;
  final void Function(String) onReply;

  const TradingViewMarketOverviewWidget({
    Key? key,
    required this.jsonData,
    required this.onReply,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Estrai i vari parametri dal JSON, fornendo valori predefiniti se assenti
    return TradingViewMarketOverview(
      colorTheme: jsonData["colorTheme"] ?? "dark",
      dateRange: jsonData["dateRange"] ?? "12M",
      showChart: jsonData["showChart"] ?? true,
      locale: jsonData["locale"] ?? "en",
      width: "100%", //jsonData["width"]?.toString() ?? "100%",
      height: (jsonData["height"] is num) ? (jsonData["height"] as num).toInt() : 700,
      largeChartUrl: jsonData["largeChartUrl"] ?? "",
      isTransparent: jsonData["isTransparent"] ?? false,
      showSymbolLogo: jsonData["showSymbolLogo"] ?? true,
      showFloatingTooltip: jsonData["showFloatingTooltip"] ?? true,
      plotLineColorGrowing: jsonData["plotLineColorGrowing"] ?? "rgba(41, 98, 255, 1)",
      plotLineColorFalling: jsonData["plotLineColorFalling"] ?? "rgba(41, 98, 255, 1)",
      gridLineColor: jsonData["gridLineColor"] ?? "rgba(42, 46, 57, 0)",
      scaleFontColor: jsonData["scaleFontColor"] ?? "rgba(219, 219, 219, 1)",
      belowLineFillColorGrowing: jsonData["belowLineFillColorGrowing"] ?? "rgba(41, 98, 255, 0.12)",
      belowLineFillColorFalling: jsonData["belowLineFillColorFalling"] ?? "rgba(41, 98, 255, 0.12)",
      belowLineFillColorGrowingBottom: jsonData["belowLineFillColorGrowingBottom"] ?? "rgba(41, 98, 255, 0)",
      belowLineFillColorFallingBottom: jsonData["belowLineFillColorFallingBottom"] ?? "rgba(41, 98, 255, 0)",
      symbolActiveColor: jsonData["symbolActiveColor"] ?? "rgba(41, 98, 255, 0.12)",
      tabs: jsonData["tabs"] ??
          '''[
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
            }
          ]''',
    );
  }
}

class CustomChartWidgetTool extends StatelessWidget {
  final Map<String, dynamic> jsonData;
  final void Function(String) onReply; // Callback, se servisse rispondere al chatbot

  const CustomChartWidgetTool({
    Key? key,
    required this.jsonData,
    required this.onReply,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1) Estraiamo i parametri principali dal JSON
    final String title = jsonData['title'] ?? 'My MultiSeries Chart';
    final double width = (jsonData['width'] is num)
        ? (jsonData['width'] as num).toDouble()
        : 1200.0;
    final double height = (jsonData['height'] is num)
        ? (jsonData['height'] as num).toDouble()
        : 700.0;
    final bool simulateIfNoData = jsonData['simulateIfNoData'] ?? false;

    // 2) Leggiamo la parte "seriesList", che è un array di oggetti:
    //    each -> { "label", "colorHex", "visible", "seriesType", "data", "customOptions": {...} }
    final List<dynamic> rawSeries = jsonData['seriesList'] ?? [];
    final List<SeriesData> seriesList = rawSeries.map((item) {
      // item è un Map<String, dynamic> => costruiamo SeriesData
      final String label = item['label'] ?? 'Unnamed';
      final String colorHex = item['colorHex'] ?? '#ff0000';
      final bool visible = item['visible'] ?? true;

      // "seriesType" è string -> convertiamola a SeriesType
      final String stypeString = (item['seriesType'] ?? 'area').toString().toLowerCase();
      SeriesType stype;
      switch (stypeString) {
        case 'line':
          stype = SeriesType.line;
          break;
        case 'bar':
          stype = SeriesType.bar;
          break;
        case 'candlestick':
          stype = SeriesType.candlestick;
          break;
        case 'histogram':
          stype = SeriesType.histogram;
          break;
        default:
          stype = SeriesType.area;
          break;
      }

      // "customOptions" eventuali
      final Map<String,dynamic> customOpts = 
        (item['customOptions'] is Map<String,dynamic>) 
          ? Map<String,dynamic>.from(item['customOptions']) 
          : {};

      // Convertiamo l'array "data" in una lista di ChartDataPoint
      final List<dynamic> rawData = item['data'] ?? [];
      final List<ChartDataPoint> points = rawData.map((dp) {
        // dp è un Map con campi "time", e a seconda del tipo: value o open/high/low/close
        final String time = dp['time'] ?? '2020-01-01';
        final double? value = (dp['value'] is num) ? (dp['value'] as num).toDouble() : null;
        final double? open  = (dp['open']  is num) ? (dp['open']  as num).toDouble() : null;
        final double? high  = (dp['high']  is num) ? (dp['high']  as num).toDouble() : null;
        final double? low   = (dp['low']   is num) ? (dp['low']   as num).toDouble() : null;
        final double? close = (dp['close'] is num) ? (dp['close'] as num).toDouble() : null;

        return ChartDataPoint(
          time: time,
          value: value,
          open: open, high: high, low: low, close: close,
        );
      }).toList();

      return SeriesData(
        label: label,
        colorHex: colorHex,
        visible: visible,
        seriesType: stype,
        customOptions: customOpts,
        data: points,
      );
    }).toList();

    // 3) Leggiamo la parte "verticalDividers", array di oggetti
    //    each -> { "time", "colorHex", "leftLabel", "rightLabel" }
    final List<dynamic> rawDivs = jsonData['verticalDividers'] ?? [];
    final List<VerticalDividerData> verticalDividers = rawDivs.map((item) {
      final String time = item['time'] ?? '2020-01-01';
      final String colorHex = item['colorHex'] ?? '#ff0000';
      final String leftLabel  = item['leftLabel']  ?? '';
      final String rightLabel = item['rightLabel'] ?? '';
      return VerticalDividerData(
        time: time,
        colorHex: colorHex,
        leftLabel: leftLabel,
        rightLabel: rightLabel,
      );
    }).toList();

    // 4) Creiamo e ritorniamo il MultiSeriesLightweightChartWidget
    return CustomChartWidget(
      title: title,
      seriesList: seriesList,
      simulateIfNoData: simulateIfNoData,
      width: width,
      height: height,
      verticalDividers: verticalDividers,
    );
  }
}



class ChangeChatNameWidgetTool extends StatefulWidget {
  final Map<String, dynamic> jsonData;
  final Future<void> Function(String chatId, String newName) onRenameChat;
  final Future<String> Function() getCurrentChatId; // Callback per ottenere l'ID della chat attuale

  const ChangeChatNameWidgetTool({
    Key? key,
    required this.jsonData,
    required this.onRenameChat,
    required this.getCurrentChatId,
  }) : super(key: key);

  @override
  _ChangeChatNameWidgetToolState createState() => _ChangeChatNameWidgetToolState();
}

class _ChangeChatNameWidgetToolState extends State<ChangeChatNameWidgetTool> {
  bool _operationCompleted = false;
  String _effectiveChatId = "";
  bool _isFirstTime = true; // Per memorizzare se è la prima volta

  @override
  void initState() {
    super.initState();

    // Leggiamo is_first_time dal jsonData (se non c'è, di default è true)
    _isFirstTime = widget.jsonData['is_first_time'] ?? true;

    // Ricaviamo chatId (se vuoto, useremo getCurrentChatId)
    final String providedChatId = widget.jsonData['chatId'] ?? '';
    if (providedChatId.isEmpty) {
      // Se non viene fornito un chatId, usa quello della chat attuale
      widget.getCurrentChatId().then((id) {
        setState(() {
          _effectiveChatId = id;
          // Se è la prima volta, facciamo subito la rinomina
          if (_isFirstTime && !_operationCompleted) {
            _autoRename();
          }
        });
      });
    } else {
      // Abbiamo un chatId esplicito
      _effectiveChatId = providedChatId;
      // Se è la prima volta, facciamo subito la rinomina
      if (_isFirstTime && !_operationCompleted) {
        _autoRename();
      }
    }
  }

  /// Funzione che esegue la rinomina automatica
  Future<void> _autoRename() async {
    final String newName = widget.jsonData['newName'] ?? '';
    await widget.onRenameChat(_effectiveChatId, newName);
    setState(() {
      _operationCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String providedChatId = widget.jsonData['chatId'] ?? '';
    final String newName = widget.jsonData['newName'] ?? '';

    // Se is_first_time è false, mostriamo solo una card con un messaggio sintetico
    if (!_isFirstTime) {
      return Card(
        margin: const EdgeInsets.all(8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey, Colors.black54],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Rinomina chat già eseguita (is_first_time: false).',
              style: TextStyle(fontSize: 16, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Messaggio finale dopo la rinomina
    final String messageText = providedChatId.isEmpty 
      ? 'La chat attuale (ID: $_effectiveChatId) è stata rinominata in "$newName".'
      : 'La chat con ID "$_effectiveChatId" è stata rinominata in "$newName".';

    // Se _isFirstTime è true, ci troviamo in due possibili stati:
    //  - _operationCompleted = false => la rinomina è in corso (ma la facciamo in initState)
    //  - _operationCompleted = true  => la rinomina è terminata

    return Card(
      margin: const EdgeInsets.all(8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: Container(
        decoration: BoxDecoration(
          // Sfondo verde sfumato per il messaggio d’esito
          gradient: LinearGradient(
            colors: [Colors.greenAccent, Colors.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _operationCompleted 
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'OPERAZIONE EFFETTUATA',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      messageText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    // Qui potresti mettere un messaggio di "Rinomino in corso..."
                    // o uno spinner, se vuoi
                    Text(
                      'Rinominazione in corso...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8.0),
                    CircularProgressIndicator(color: Colors.white),
                  ],
                ),
        ),
      ),
    );
  }
}

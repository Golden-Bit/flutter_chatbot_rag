import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Tipi di serie supportati in Lightweight Charts v4.
enum SeriesType {
  line,
  area,
  bar,
  candlestick,
  histogram,
  // potresti aggiungere 'baseline', ecc.
}

/// Rappresenta un singolo punto dati per la serie.
/// time: stringa "yyyy-MM-dd".
/// Se la serie è line/area/histogram => `value`.
/// Se bar/candlestick => `open, high, low, close`.
class ChartDataPoint {
  final String time;
  final double? value; // per line/area/histogram
  final double? open;  // bar/candle
  final double? high;  // bar/candle
  final double? low;   // bar/candle
  final double? close; // bar/candle

  ChartDataPoint({
    required this.time,
    this.value,
    this.open,
    this.high,
    this.low,
    this.close,
  });
}

/// Descrive una singola serie (label, colore, dati, etc.).
///
/// - [seriesType] uno tra line, area, bar, candlestick, histogram.
/// - [customOptions] opzioni addizionali passate alla libreria:
///   ad es. 'lineWidth', 'lineStyle', 'priceFormat', 'upColor', ecc.
class SeriesData {
  final String label;
  final String colorHex;
  final List<ChartDataPoint>? data;
  final bool visible;
  final SeriesType seriesType;

  /// Mappa di opzioni extra (passate così com’è ad addLineSeries, addAreaSeries, etc.)
  final Map<String, dynamic> customOptions;

  SeriesData({
    required this.label,
    required this.colorHex,
    this.data,
    this.visible = true,
    this.seriesType = SeriesType.area,
    this.customOptions = const {},
  });
}

/// Divisore verticale sul grafico. time in "yyyy-MM-dd",
/// [leftLabel]/[rightLabel] testi mostrati in alto (sinistra/destra).
/// [colorHex] colore base della linea. Per spessore/stile vedi `_buildHtmlContent`.
class VerticalDividerData {
  final String time;
  final String colorHex;
  final String leftLabel;
  final String rightLabel;

  VerticalDividerData({
    required this.time,
    required this.colorHex,
    required this.leftLabel,
    required this.rightLabel,
  });
}

/// Il widget Flutter che crea un IFrame con:
/// - Più serie di vario tipo (line, area, bar, candlestick, histogram)
/// - Toggles di visibilità, range buttons, navigator
/// - Crosshair tooltip, tabella dati, download CSV
/// - Divisori verticali personalizzabili (colore, label, spessore, tratteggio)
/// - Parametri di personalizzazione come asse dei prezzi a dx, label trasparenti, unità di misura.
class CustomChartWidget extends StatelessWidget {
  final String title;
  final List<SeriesData> seriesList;
  final bool simulateIfNoData;
  final double width;
  final double height;

  /// Divisori verticali da disegnare.
  final List<VerticalDividerData> verticalDividers;

  /// Costruttore
  ///
  /// - [simulateIfNoData] se `true`, se una serie non ha data, generiamo dati fittizi.
  /// - [verticalDividers] per linee verticali personalizzate (time, colore, label).
  CustomChartWidget({
    Key? key,
    required this.title,
    required this.seriesList,
    this.simulateIfNoData = false,
    this.width = 1200,
    this.height = 700,
    this.verticalDividers = const [],
  }) : super(key: key) {
    // 1) Creiamo l'id univoco per l'iFrame
    final String viewId = 'multi-series-charts-${DateTime.now().millisecondsSinceEpoch}';
    _viewId = viewId;

    // 2) Convertiamo le serie e i divisori in stringa JS/JSON
    final String seriesJsArray = _buildSeriesJsArray(seriesList, simulateIfNoData);
    final String verticalDividersJsArray = _buildVerticalDividersJsArray(verticalDividers);

    // 3) Costruiamo l'HTML
    final String htmlContent = _buildHtmlContent(
      title,
      seriesJsArray,
      verticalDividersJsArray,
    );

    // 4) Creiamo un Blob + URL
    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);

    // 5) Creiamo l'IFrame
    final html.IFrameElement iFrameElement = html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..width = '100%'
      ..height = '100%';

    // 6) Registriamo la view
    ui.platformViewRegistry.registerViewFactory(viewId, (int viewId) => iFrameElement);
  }

  late final String _viewId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: HtmlElementView(viewType: _viewId),
    );
  }

  /// Costruisce l'HTML + CSS + script con tutte le feature.
  /// - Permette di spostare l'asse dei prezzi a dx o sx
  /// - Divisori verticali personalizzati (spessore, stile, trasparenza label, ecc.)
  /// - Unità di misura custom (vedi customOptions e priceFormat)
  String _buildHtmlContent(
    String title,
    String seriesJsArray,
    String verticalDividersJsArray,
  ) {
    // Ecco come si presenta. È un HTML che definisce:
    //  - Alcuni stili CSS
    //  - Un <script> che crea la chart con Lightweight Charts v4
    //  - Codice per toggles, range, crosshair, data table, divisori verticali

    // Se vuoi spostare l'asse dei prezzi a destra, vedi i commenti "MARK_A" e "MARK_B" qui sotto.
    // Se vuoi label trasparenti, puoi cambiare in .vertical-divider-label-left, background: rgba(0,0,0,0.0).
    // Se vuoi linea divisore 3px tratteggiata, cambia style: lineEl.style.width= '0px'; lineEl.style.borderLeft= '3px dashed <color>';

    return '''
<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8" />
  <title>\${_escapeHtml(title)}</title>
  <style>
    body {
      margin: 0;
      padding: 0;
      background: #1e242c;
      font-family: sans-serif;
      color: #fff;
    }
    /* Contenitore principale */
    #app-container {
      width: 90%;
      max-width: 1200px;
      margin: 0 auto;
      padding: 20px 0;
      position: relative;
    }
    h1 {
      width: 100%;
      margin: 20px 0 10px 0;
      text-align: left;
    }
    /* Pulsanti range */
    #range-buttons {
      display: grid;
      grid-template-columns: repeat(6, 1fr);
      gap: 10px;
      margin-bottom: 20px;
    }
    #range-buttons button {
      background: #2b333d;
      color: #fff;
      border: 1px solid #444;
      padding: 8px;
      cursor: pointer;
      border-radius: 4px;
      font-size: 14px;
      text-align: center;
    }
    #range-buttons button:hover {
      background: #3e464f;
    }
    #range-buttons button.selected {
      background: #404854;
    }
    /* Chart principale */
    #main-chart {
      width: 100%;
      height: 400px;
      position: relative;
    }
    /* Contenitore per le linee verticali e label */
    #vertical-dividers-container {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      overflow: visible;
      z-index: 9999;
    }

    /* Esempio di divisore 3px e tratteggiato: (vedi script se vuoi personalizzare a runtime) 
       di default qui mettiamo spessore 2 e colore backgroundColor...
    */
    .vertical-divider-line {
      position: absolute;
      top: 0;
      width: 2px; /* se vuoi un approach a border-left, fallo nello script */
      height: 100%;
      background-color: #ff0000;
    }

    /* Esempio: label con sfondo semitrasparente, se la vuoi trasparente -> rgba(0,0,0,0.0) */
    .vertical-divider-label-left,
    .vertical-divider-label-right {
      position: absolute;
      top: 0;
      color: #fff;
      background: rgba(0,0,0,0.7);
      padding: 2px 6px;
      border-radius: 4px;
      white-space: nowrap;
      font-size: 12px;
    }
    .vertical-divider-label-left {
      transform: translate(-130%, 0px);
    }
    .vertical-divider-label-right {
      transform: translate(30%, 0px);
    }
    /* Navigator */
    #navigator-chart {
      width: 100%;
      height: 80px;
      margin-top: 10px;
      position: relative;
      overflow: hidden;
    }
    #navigator-rectangle {
      position: absolute;
      top: 0;
      height: 100%;
      background: rgba(140,198,255,0.3);
      pointer-events: none;
      z-index: 2;
    }
    /* Legenda toggles */
    #series-toggles {
      display: flex;
      gap: 20px;
      margin-top: 15px;
      align-items: center;
      flex-wrap: wrap;
      justify-content: flex-start;
    }
    .toggle-item {
      display: flex;
      align-items: center;
      gap: 6px;
      cursor: pointer;
      transition: opacity 0.3s;
    }
    .toggle-item.disabled {
      opacity: 0.5;
    }
    .toggle-color-box {
      width: 12px;
      height: 12px;
      border-radius: 2px;
      display: inline-block;
    }
    /* Crosshair tooltip */
    #multi-tooltip {
      position: absolute;
      display: none;
      pointer-events: none;
      background: rgba(0,0,0,0.8);
      color: #fff;
      padding: 8px 10px;
      font-size: 14px;
      border-radius: 4px;
      z-index: 999;
      max-width: 300px;
    }
    /* Pulsante "DATA" */
    #data-button-container {
      width: 100%;
      margin-top: 20px;
      text-align: right;
    }
    #btn-show-data {
      background: #2b333d;
      color: #fff;
      border: 1px solid #444;
      padding: 8px 12px;
      cursor: pointer;
      border-radius: 4px;
      font-size: 14px;
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }
    #btn-show-data:hover {
      background: #3e464f;
    }
    /* Tabella dati */
    #data-table-container {
      display: none;
      margin-top: 20px;
      background: #1e242c;
      border: 1px solid #444;
      border-radius: 4px;
      position: relative;
    }
    #data-table-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 8px 12px;
      border-bottom: 1px solid #444;
    }
    #data-table-header .title {
      font-size: 16px;
      font-weight: bold;
    }
    #btn-close-table {
      background: transparent;
      color: #fff;
      border: none;
      font-size: 18px;
      cursor: pointer;
    }
    #download-button-container {
      width: 100%;
      margin-top: 10px;
      text-align: left;
      padding: 0 12px 12px 12px;
    }
    #btn-download-csv {
      background: #2b333d;
      color: #fff;
      border: 1px solid #444;
      padding: 8px 12px;
      cursor: pointer;
      border-radius: 4px;
      font-size: 14px;
    }
    #btn-download-csv:hover {
      background: #3e464f;
    }
    #data-table-scroll {
      max-height: 300px;
      overflow-y: auto;
    }
    table.data-table {
      width: 100%;
      border-collapse: collapse;
    }
    table.data-table thead {
      background: #2b333d;
      position: sticky;
      top: 0;
      z-index: 1;
    }
    table.data-table th,
    table.data-table td {
      padding: 8px 12px;
      border-bottom: 1px solid #444;
      text-align: left;
    }
    table.data-table tbody tr:hover {
      background: #2b333d;
    }
    table.data-table tbody tr:nth-child(even) {
      background: #242a31;
    }
  </style>
</head>
<body>
  <div id="app-container">
    <h1>$title</h1>
    <!-- Range Buttons -->
    <div id="range-buttons">
      <button data-range="1m">1M</button>
      <button data-range="3m">3M</button>
      <button data-range="1y">1Y</button>
      <button data-range="3y">3Y</button>
      <button data-range="5y">5Y</button>
      <button data-range="all">Max</button>
    </div>
    <!-- Main Chart -->
    <div id="main-chart">
      <!-- container per linee verticali -->
      <div id="vertical-dividers-container"></div>
    </div>
    <!-- Navigator -->
    <div id="navigator-chart">
      <div id="navigator-rectangle"></div>
    </div>
    <!-- Toggles series -->
    <div id="series-toggles"></div>
    <!-- Data button -->
    <div id="data-button-container">
      <button id="btn-show-data">
        <span>📊</span>
        DATA
      </button>
    </div>
    <!-- Crosshair tooltip -->
    <div id="multi-tooltip"></div>
    <!-- Data Table -->
    <div id="data-table-container">
      <div id="data-table-header">
        <span class="title">Data Table</span>
        <button id="btn-close-table">X</button>
      </div>
      <div id="data-table-scroll">
        <table class="data-table" id="data-table">
          <thead>
            <tr id="table-header-row">
              <!-- colonna "Date" + 1 colonna per ogni serie -->
            </tr>
          </thead>
          <tbody id="data-table-body"></tbody>
        </table>
      </div>
      <div id="download-button-container">
        <button id="btn-download-csv">Download CSV</button>
      </div>
    </div>
  </div>
  <script src="https://unpkg.com/lightweight-charts@4/dist/lightweight-charts.standalone.production.js"></script>
  <script>
    (function(){
      const seriesList = $seriesJsArray; 
      const verticalDividers = $verticalDividersJsArray;

      function parseYMD(str) {
        const [y,m,d] = str.split('-');
        return new Date(+y, +m-1, +d);
      }
      function clampRange(range, min, max) {
        return {
          from: Math.max(range.from, min),
          to: Math.min(range.to, max),
        };
      }

      // uniamo i time di tutte le serie per la tabella
      let allTimesSet = new Set();
      seriesList.forEach(s => {
        s.data.forEach(dp => {
          allTimesSet.add(dp.time);
        });
      });
      let allTimes = Array.from(allTimesSet).sort();

      let mainChartEl, navChartEl, mainChart, navChart;
      window.addEventListener('DOMContentLoaded', () => {
        mainChartEl = document.getElementById('main-chart');
        navChartEl  = document.getElementById('navigator-chart');

        // MARK_A: Se vuoi l'asse a dx, basta impostare: rightPriceScale.visible=true, leftPriceScale.visible=false
        // E potresti definire un priceFormat con unita' di misura personalizzate
        // ad es. priceFormat: { type: 'custom', formatter: (price) => price.toFixed(2) + ' EUR' }
        mainChart = LightweightCharts.createChart(mainChartEl, {
          width: mainChartEl.clientWidth,
          height: mainChartEl.clientHeight,
          layout: {
            background: { type: 'Solid', color: '#1e242c' },
            textColor: '#fff',
          },
          timeScale: {
            timeVisible: true,
            secondsVisible: false,
          },
          // Esempio: disabilitiamo left e abilitiamo right
          // Se vuoi lasciarlo a sinistra, inverti
          rightPriceScale: {
            visible: true,
            borderVisible: false,
          },
          leftPriceScale: { visible: false },
          grid: {
            vertLines: { color: '#2B2B43', style: 0 },
            horzLines: { color: '#2B2B43', style: 0 },
          },
          crosshair: {
            vertLine: { labelVisible: true },
            horzLine: { labelVisible: true },
          },
        });

        // chart del navigator
        navChart = LightweightCharts.createChart(navChartEl, {
          width: navChartEl.clientWidth,
          height: navChartEl.clientHeight,
          layout: {
            background: { type: 'Solid', color: '#1e242c' },
            textColor: '#aaa',
          },
          kineticScroll: { mouse: false, touch: false },
          handleScroll: false,
          handleScale: false,
          timeScale: {
            timeVisible: true,
            secondsVisible: false,
          },
          // se l'asse del navigator lo vuoi a dx e non a sx, configuralo qui
          rightPriceScale: { visible: false },
          leftPriceScale: { visible: false },
          grid: {
            vertLines: { visible: false },
            horzLines: { visible: false },
          },
          crosshair: {
            mode: 0,
            vertLine: { visible: false },
            horzLine: { visible: false },
          },
        });

        function createSeriesOnChart(chart, s) {
          let series;
          let baseOptions = {
            visible: s.visible,
          };

          for (let k in s.customOptions) {
            baseOptions[k] = s.customOptions[k];
          }

          switch (s.seriesType) {
            case 'line':
              series = chart.addLineSeries({
                lineColor: s.color,
                lineWidth: 2,
                lastValueVisible: false,
                priceLineVisible: false,
                ...baseOptions,
              });
              break;
            case 'bar':
              series = chart.addBarSeries({
                ...baseOptions,
              });
              break;
            case 'candlestick':
              series = chart.addCandlestickSeries({
                lastValueVisible: false,
                priceLineVisible: false,
                ...baseOptions,
              });
              break;
            case 'histogram':
              series = chart.addHistogramSeries({
                color: s.color,
                lastValueVisible: false,
                priceLineVisible: false,
                ...baseOptions,
              });
              break;
            case 'area':
            default:
              series = chart.addAreaSeries({
                topColor: s.color + '33',
                bottomColor: s.color + '00',
                lineColor: s.color,
                lineWidth: 2,
                lastValueVisible: false,
                priceLineVisible: false,
                ...baseOptions,
              });
              break;
          }

          const dataForChart = s.data.map(dp => {
            if (s.seriesType === 'bar' || s.seriesType === 'candlestick') {
              return {
                time: dp.time,
                open: dp.open,
                high: dp.high,
                low: dp.low,
                close: dp.close
              };
            } else {
              return {
                time: dp.time,
                value: dp.value
              };
            }
          });
          series.setData(dataForChart);
          return series;
        }

        const mainSeriesObjs = [];
        seriesList.forEach(s => {
          const created = createSeriesOnChart(mainChart, s);
          mainSeriesObjs.push({
            label: s.label,
            series: created,
            color: s.color,
            data: s.data
          });
        });

        mainChart.timeScale().fitContent();

        // navigator: per semplicità, disegniamo TUTTE come area
        seriesList.forEach(s => {
          const navSeries = navChart.addAreaSeries({
            topColor: s.color + '33',
            bottomColor: s.color + '00',
            lineColor: s.color,
            lineWidth: 1,
            lastValueVisible: false,
            priceLineVisible: false,
          });
          const navData = s.data.map(dp => ({
            time: dp.time,
            value: dp.value ?? dp.close ?? 0,
          }));
          navSeries.setData(navData);
        });
        navChart.timeScale().fitContent();

        // gestiamo il rettangolo del navigator
        const navRect = document.getElementById('navigator-rectangle');
        function updateNavRectangle() {
          const range = mainChart.timeScale().getVisibleLogicalRange();
          if (!range) {
            navRect.style.display = 'none';
            return;
          }
          let leftIndex = Math.floor(range.from);
          let rightIndex= Math.ceil(range.to);
          leftIndex = Math.max(0, leftIndex);
          rightIndex= Math.min(allTimes.length-1, rightIndex);
          const fromTime = allTimes[leftIndex];
          const toTime = allTimes[rightIndex];
          const fromX = navChart.timeScale().timeToCoordinate(fromTime);
          const toX   = navChart.timeScale().timeToCoordinate(toTime);
          if (fromX===null || toX===null) {
            navRect.style.display='none';
            return;
          }
          let left = Math.min(fromX, toX);
          let width= Math.abs(toX - fromX);
          const containerW= navChartEl.clientWidth;
          if (left<0) {
            width+= left;
            left=0;
          }
          if (left+width>containerW) {
            width= containerW-left;
          }
          if (width<=0) {
            navRect.style.display='none';
            return;
          }
          navRect.style.display='block';
          navRect.style.left= left+'px';
          navRect.style.width= width+'px';
          navRect.style.top='0px';
          navRect.style.height= navChartEl.clientHeight+'px';
        }
        mainChart.timeScale().subscribeVisibleLogicalRangeChange(updateNavRectangle);
        updateNavRectangle();

        // Range Buttons
        const rangeButtons = document.querySelectorAll('#range-buttons button');
        rangeButtons.forEach(btn => {
          btn.addEventListener('click', () => {
            rangeButtons.forEach(b => b.classList.remove('selected'));
            btn.classList.add('selected');
            setCustomRange(btn.dataset.range);
          });
        });
        function setCustomRange(rid) {
          if (rid==='all') {
            mainChart.timeScale().fitContent();
            return;
          }
          const last = allTimes[allTimes.length-1];
          const lastDate= parseYMD(last);
          let fromDate= new Date(lastDate);
          if(rid==='1m'){ fromDate.setMonth(fromDate.getMonth()-1); }
          else if(rid==='3m'){ fromDate.setMonth(fromDate.getMonth()-3); }
          else if(rid==='1y'){ fromDate.setFullYear(fromDate.getFullYear()-1); }
          else if(rid==='3y'){ fromDate.setFullYear(fromDate.getFullYear()-3); }
          else if(rid==='5y'){ fromDate.setFullYear(fromDate.getFullYear()-5); }
          else {
            mainChart.timeScale().fitContent();
            return;
          }
          function toYMD(d){
            const y=d.getFullYear();
            const m=('0'+(d.getMonth()+1)).slice(-2);
            const dd=('0'+d.getDate()).slice(-2);
            return y+'-'+m+'-'+dd;
          }
          const fromStr= toYMD(fromDate);
          if(fromStr<allTimes[0]){
            mainChart.timeScale().fitContent();
            return;
          }
          let fromIndex= allTimes.findIndex(t=>t>=fromStr);
          if(fromIndex<0) fromIndex=0;
          const toIndex= allTimes.length-1;
          mainChart.timeScale().setVisibleLogicalRange({from: fromIndex, to: toIndex});
        }
        document.querySelector('button[data-range="all"]').classList.add('selected');

        // Toggles
        const seriesTogglesDiv = document.getElementById('series-toggles');
        mainSeriesObjs.forEach((obj,i)=>{
          const s= seriesList[i];
          const item= document.createElement('div');
          item.className= 'toggle-item' + (s.visible ? '' : ' disabled');
          item.dataset.seriesIndex= i;
          item.innerHTML= '<div class="toggle-color-box" style="background:'+obj.color+';"></div><span>'+_escapeHtml(s.label)+'</span>';
          item.addEventListener('click', ()=>{
            const isVisible= obj.series.options().visible;
            obj.series.applyOptions({ visible: !isVisible });
            item.classList.toggle('disabled', isVisible);
          });
          seriesTogglesDiv.appendChild(item);
        });

        // Crosshair tooltip
        const multiTooltip= document.getElementById('multi-tooltip');
        mainChart.subscribeCrosshairMove(param=>{
          if(!param.point || !param.time){
            multiTooltip.style.display='none';
            return;
          }
          const dateStr= param.time;
          let lines=['<strong>'+dateStr+'</strong>'];
          mainSeriesObjs.forEach(({label,series,data,color})=>{
            if(series.options().visible){
              const idx= data.findIndex(d=>d.time===dateStr);
              if(idx>=0){
                const dp = data[idx];
                let strVal = '';
                if (dp.open!==undefined && dp.high!==undefined && dp.low!==undefined && dp.close!==undefined) {
                  strVal = 'O:'+dp.open.toFixed(2)+' H:'+dp.high.toFixed(2)+' L:'+dp.low.toFixed(2)+' C:'+dp.close.toFixed(2);
                } else if (dp.value!==undefined) {
                  strVal = dp.value.toFixed(2);
                } else {
                  strVal = '???';
                }
                lines.push('<span style="color:'+color+'">'+label+': '+ strVal +'</span>');
              }
            }
          });
          if(lines.length<=1){
            multiTooltip.style.display='none';
            return;
          }
          multiTooltip.innerHTML= lines.join('<br/>');
          multiTooltip.style.display='block';
          const rect= mainChartEl.getBoundingClientRect();
          const x= param.point.x;
          const y= param.point.y;
          multiTooltip.style.left= x+'px';
          multiTooltip.style.top = y+'px';
        });

        // scroll clamp
        let currentValidRange= mainChart.timeScale().getVisibleLogicalRange() || {from:0,to:allTimes.length-1};
        mainChart.timeScale().subscribeVisibleLogicalRangeChange((newRange)=>{
          if(!newRange) return;
          const clamped= clampRange(newRange,0,allTimes.length-1);
          if(clamped.from!==newRange.from||clamped.to!==newRange.to){
            mainChart.timeScale().setVisibleLogicalRange(currentValidRange);
          } else {
            currentValidRange= newRange;
          }
        });

        // resize
        window.addEventListener('resize', ()=>{
          const cw= mainChartEl.clientWidth;
          const ch= mainChartEl.clientHeight;
          mainChart.applyOptions({width:cw,height:ch});
          const nw= navChartEl.clientWidth;
          const nh= navChartEl.clientHeight;
          navChart.applyOptions({width:nw,height:nh});
          updateNavRectangle();
          updateVerticalDividers();
        });

        // vertical dividers
        const verticalDividersContainer = document.getElementById('vertical-dividers-container');
        const dividerElems = [];
        verticalDividers.forEach((vd, idx)=>{
          const lineEl = document.createElement('div');
          lineEl.className = 'vertical-divider-line';
          // se vuoi un line spessore 3px e dashed puoi fare:
          // lineEl.style.width= '0px';
          // lineEl.style.borderLeft= '3px dashed ' + vd.colorHex;
          // oppure un approach differente
          // per default lasciamo un background color su width=2px
          lineEl.style.backgroundColor = vd.colorHex;

          verticalDividersContainer.appendChild(lineEl);

          const labelLeftEl = document.createElement('div');
          labelLeftEl.className = 'vertical-divider-label-left';
          // se la vuoi trasparente:
          // labelLeftEl.style.background= 'rgba(0,0,0,0.0)';
          labelLeftEl.style.backgroundColor = 'rgba(0,0,0,0.7)';
          labelLeftEl.style.display = (vd.leftLabel.trim().length>0 ? 'block' : 'none');
          labelLeftEl.innerText = vd.leftLabel;
          verticalDividersContainer.appendChild(labelLeftEl);

          const labelRightEl = document.createElement('div');
          labelRightEl.className = 'vertical-divider-label-right';
          labelRightEl.style.backgroundColor = 'rgba(0,0,0,0.7)';
          labelRightEl.style.display = (vd.rightLabel.trim().length>0 ? 'block' : 'none');
          labelRightEl.innerText = vd.rightLabel;
          verticalDividersContainer.appendChild(labelRightEl);

          dividerElems.push({
            time: vd.time,
            lineEl,
            labelLeftEl,
            labelRightEl,
          });
        });

        function updateVerticalDividers(){
          dividerElems.forEach(de => {
            const xCoord = mainChart.timeScale().timeToCoordinate(de.time);
            if(xCoord===null) {
              de.lineEl.style.display='none';
              de.labelLeftEl.style.display='none';
              de.labelRightEl.style.display='none';
              return;
            }
            de.lineEl.style.display='block';
            de.lineEl.style.left = xCoord+'px';

            if(de.labelLeftEl.innerText.trim().length>0){
              de.labelLeftEl.style.display='block';
              de.labelLeftEl.style.left = xCoord+'px';
            }
            if(de.labelRightEl.innerText.trim().length>0){
              de.labelRightEl.style.display='block';
              de.labelRightEl.style.left = xCoord+'px';
            }
          });
        }
        mainChart.timeScale().subscribeVisibleTimeRangeChange(updateVerticalDividers);
        updateVerticalDividers();

        // data table
        buildDataTable();
        function buildDataTable(){
          const thr= document.getElementById('table-header-row');
          thr.innerHTML= '<th>Date</th>';
          seriesList.forEach(s=>{
            thr.innerHTML+= '<th>'+_escapeHtml(s.label)+'</th>';
          });
          const tbody= document.getElementById('data-table-body');
          tbody.innerHTML= '';
          // costruiamo mappa time-> value (o close) per visualizzare
          const dataMaps= seriesList.map(s=>{
            const map={};
            s.data.forEach(dp=>{
              let val = 0;
              if(s.seriesType==='bar' || s.seriesType==='candlestick'){
                val = dp.close ?? 0;
              } else {
                val = dp.value ?? 0;
              }
              map[dp.time]= val;
            });
            return map;
          });
          allTimes.forEach(time=>{
            const tr= document.createElement('tr');
            let row= '<td>'+ time + '</td>';
            dataMaps.forEach((map,i)=>{
              const v= map[time];
              row+= '<td>'+(v!==undefined ? v.toFixed(2) : '-')+'</td>';
            });
            tr.innerHTML= row;
            tbody.appendChild(tr);
          });
        }

        // Pulsanti "DATA" e "Download CSV"
        const dataTableContainer= document.getElementById('data-table-container');
        const btnShowData= document.getElementById('btn-show-data');
        const btnCloseTable= document.getElementById('btn-close-table');
        const btnDownloadCsv= document.getElementById('btn-download-csv');

        btnShowData.addEventListener('click', ()=>{
          document.getElementById('main-chart').style.display='none';
          document.getElementById('navigator-chart').style.display='none';
          document.getElementById('range-buttons').style.display='none';
          document.getElementById('series-toggles').style.display='none';
          document.getElementById('multi-tooltip').style.display='none';
          document.getElementById('data-button-container').style.display='none';
          dataTableContainer.style.display='block';
        });
        btnCloseTable.addEventListener('click',()=>{
          dataTableContainer.style.display='none';
          document.getElementById('main-chart').style.display='block';
          document.getElementById('navigator-chart').style.display='block';
          document.getElementById('range-buttons').style.display='grid';
          document.getElementById('series-toggles').style.display='flex';
          document.getElementById('data-button-container').style.display='block';
        });
        btnDownloadCsv.addEventListener('click',()=>{
          let csvContent= 'Date';
          seriesList.forEach(s=>{
            csvContent+= ','+s.label;
          });
          csvContent+='\\n';
          const dataMaps= seriesList.map(s=>{
            const map={};
            s.data.forEach(dp=>{
              let val=0;
              if(s.seriesType==='bar' || s.seriesType==='candlestick'){
                val = dp.close ?? 0;
              } else {
                val = dp.value ?? 0;
              }
              map[dp.time]= val;
            });
            return map;
          });
          allTimes.forEach(time=>{
            csvContent+= time;
            dataMaps.forEach((map,i)=>{
              const v= map[time];
              csvContent+= ','+(v!==undefined ? v.toFixed(2) : '');
            });
            csvContent+='\\n';
          });
          const blob= new Blob([csvContent],{type:'text/csv;charset=utf-8;'});
          const url= URL.createObjectURL(blob);
          const tempLink= document.createElement('a');
          tempLink.href= url;
          tempLink.setAttribute('download','multi_series_data.csv');
          tempLink.style.display='none';
          document.body.appendChild(tempLink);
          tempLink.click();
          document.body.removeChild(tempLink);
          URL.revokeObjectURL(url);
        });
      });

      function _escapeHtml(s){
        return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
      }
    })();
  </script>
</body>
</html>
''';
  }

  /// Se la serie non ha data e [simulateIfNoData]==true, generiamo dati fittizi
  String _buildSeriesJsArray(List<SeriesData> series, bool simulate) {
    final buffer = StringBuffer();
    buffer.write('[');
    for (int i = 0; i < series.length; i++) {
      final s = series[i];
      final dataList = (s.data == null || s.data!.isEmpty)
          ? (simulate ? _simulateDataForSeriesType(s.seriesType) : <ChartDataPoint>[])
          : s.data!;

      final dataJs = _pointsToJs(dataList, s.seriesType);
      final visibleStr = s.visible ? 'true' : 'false';
      final stype = s.seriesType.toString().split('.').last;
      final customOptionsJs = _mapToJsObject(s.customOptions);

      buffer.write('{ ');
      buffer.write('"label":"${_escapeJs(s.label)}", ');
      buffer.write('"color":"${_escapeJs(s.colorHex)}", ');
      buffer.write('"visible":$visibleStr, ');
      buffer.write('"seriesType":"$stype", ');
      buffer.write('"customOptions":$customOptionsJs, ');
      buffer.write('"data":$dataJs ');
      buffer.write('}');
      if (i < series.length - 1) {
        buffer.write(', ');
      }
    }
    buffer.write(']');
    return buffer.toString();
  }

  /// Converte una mappa Dart in un oggetto JS, per customOptions
  String _mapToJsObject(Map<String, dynamic> map) {
    if (map.isEmpty) {
      return '{}';
    }
    final sb = StringBuffer();
    sb.write('{');
    int idx = 0;
    map.forEach((key, value) {
      sb.write('"${_escapeJs(key)}":');
      if (value is num || value is bool) {
        sb.write('$value');
      } else {
        sb.write('"${_escapeJs(value.toString())}"');
      }
      if (idx < map.length - 1) {
        sb.write(',');
      }
      idx++;
    });
    sb.write('}');
    return sb.toString();
  }

  /// Converte i ChartDataPoint in array JS (time, open,high,low,close) o (time,value)
  String _pointsToJs(List<ChartDataPoint> points, SeriesType stype) {
    final sb = StringBuffer();
    sb.write('[');
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      if (stype == SeriesType.bar || stype == SeriesType.candlestick) {
        sb.write('{ time:"${_escapeJs(p.time)}", ');
        sb.write('open:${p.open ?? 0}, ');
        sb.write('high:${p.high ?? 0}, ');
        sb.write('low:${p.low ?? 0}, ');
        sb.write('close:${p.close ?? 0} }');
      } else {
        sb.write('{ time:"${_escapeJs(p.time)}", value:${p.value ?? 0} }');
      }
      if (i < points.length - 1) sb.write(', ');
    }
    sb.write(']');
    return sb.toString();
  }

  /// Generiamo dati fittizi se manca
  List<ChartDataPoint> _simulateDataForSeriesType(SeriesType stype) {
    switch (stype) {
      case SeriesType.bar:
      case SeriesType.candlestick:
        return _simulateOhlcData();
      case SeriesType.histogram:
      case SeriesType.line:
      case SeriesType.area:
      default:
        return _simulateValueData();
    }
  }

  /// Dati mensili single-value ~50
  List<ChartDataPoint> _simulateValueData() {
    final List<ChartDataPoint> result = [];
    DateTime current = DateTime(2016, 1, 1);
    final end = DateTime(2025, 12, 31);
    double val = 50.0;
    while (!current.isAfter(end)) {
      final timeStr = '${current.year}-${_twoDigits(current.month)}-01';
      result.add(ChartDataPoint(time: timeStr, value: val.clamp(0.0, double.infinity)));
      final rnd = (DateTime.now().microsecondsSinceEpoch % 1000) / 1000.0 - 0.5;
      val += (rnd * 10);
      current = DateTime(current.year, current.month + 1, 1);
    }
    return result;
  }

  /// Dati mensili OHLC ~50
  List<ChartDataPoint> _simulateOhlcData() {
    final List<ChartDataPoint> result = [];
    DateTime current = DateTime(2016, 1, 1);
    final end = DateTime(2025, 12, 31);
    double baseVal = 50.0;
    while (!current.isAfter(end)) {
      final timeStr = '${current.year}-${_twoDigits(current.month)}-01';
      final rnd1 = (DateTime.now().microsecondsSinceEpoch % 1000) / 1000.0;
      final open = baseVal + (rnd1 - 0.5) * 4;
      final rnd2 = ((current.microsecondsSinceEpoch) % 1000) / 1000.0;
      final close = open + (rnd2 - 0.5) * 6;
      final high = (open > close ? open : close) + 3;
      final low = (open < close ? open : close) - 3;

      result.add(ChartDataPoint(
        time: timeStr,
        open: open,
        high: high,
        low: low,
        close: close,
      ));
      baseVal = close;
      current = DateTime(current.year, current.month + 1, 1);
    }
    return result;
  }

  String _twoDigits(int v) => v < 10 ? '0$v' : '$v';

  /// Converte la lista di divisori verticali in JSON
  String _buildVerticalDividersJsArray(List<VerticalDividerData> dividers) {
    final buffer = StringBuffer();
    buffer.write('[');
    for (int i = 0; i < dividers.length; i++) {
      final d = dividers[i];
      buffer.write('{ ');
      buffer.write('"time":"${_escapeJs(d.time)}", ');
      buffer.write('"colorHex":"${_escapeJs(d.colorHex)}", ');
      buffer.write('"leftLabel":"${_escapeJs(d.leftLabel)}", ');
      buffer.write('"rightLabel":"${_escapeJs(d.rightLabel)}" ');
      buffer.write('}');
      if (i < dividers.length - 1) buffer.write(', ');
    }
    buffer.write(']');
    return buffer.toString();
  }

  String _escapeJs(String s) {
    return s.replaceAll('\\', '\\\\').replaceAll('\'', '\\\'');
  }
}

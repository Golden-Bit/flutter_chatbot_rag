import 'dart:html' as html;
import 'dart:math';
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';

/// Modello dati per ogni indicatore (vertice) del radar chart.
class RadarIndicatorData {
  /// Etichetta dell'indicatore (es. "Dividend", "Value", ecc.)
  final String name;
  /// Valore massimo (range da 0 a max)
  final double max;
  /// Valore corrente
  double value;

  RadarIndicatorData({
    required this.name,
    required this.max,
    required this.value,
  });
}

/// Widget RadarChartWidget che incapsula il codice HTML/JS (con D3.js)
/// per disegnare un radar chart con vertici draggabili, grid, marker bianchi e tooltip.
/// Il widget accetta una lista di [indicators] per definire il numero di vertici, le etichette e il range.
class RadarChartWidget extends StatelessWidget {
  final String title;
  final double width; // larghezza SVG (in pixel)
  final double height; // altezza SVG (in pixel)
  final List<RadarIndicatorData> indicators;

  late final String _viewId;

  RadarChartWidget({
    Key? key,
    required this.title,
    required this.width,
    required this.height,
    required this.indicators,
  }) : super(key: key) {
    // Genera un ID univoco per l'iframe
    final String viewId = 'radar-chart-${DateTime.now().millisecondsSinceEpoch}';
    _viewId = viewId;

    // Calcola il raggio: ad esempio, 1/3 del min(width, height)
    final int radarRadius = (min(width, height) / 3).floor();

    // Crea la stringa JS per gli indicatori
    final String indicatorsJs = _buildIndicatorsJs(indicators);

    // Costruisce il contenuto HTML completo, iniettando i parametri dinamici.
    final String htmlContent = '''
<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8">
  <title>${_escapeHtml(title)}</title>
  <script src="https://d3js.org/d3.v7.min.js"></script>
  <style>
    body {
      font-family: Arial, sans-serif;
      background-color: #222;
      color: white;
      margin: 20px;
    }
    h1 {
      text-align: center;
      color: white;
    }
    svg {
      background-color: #333;
      border: 1px solid #444;
      box-shadow: 0 0 8px rgba(0,0,0,0.5);
      display: block;
      margin: 0 auto;
    }
    .axis {
      stroke: #555;
      stroke-width: 1;
    }
    .polygon {
      stroke-width: 2;
    }
    .vertex {
      fill: white;
      cursor: pointer;
      stroke-width: 2;
    }
    .label {
      font-size: 12px;
      text-anchor: middle;
      fill: white;
    }
    .grid {
      fill: none;
      stroke: white;
      stroke-opacity: 0.8;
      stroke-width: 1.5;
    }
    #tooltip {
      position: absolute;
      background: rgba(0,0,0,0.85);
      color: #fff;
      padding: 6px 8px;
      border-radius: 4px;
      font-size: 12px;
      pointer-events: none;
      opacity: 0;
      transition: opacity 0.2s ease-in-out;
    }
  </style>
</head>
<body>
  <h1>${_escapeHtml(title)}</h1>
  <div id="chart"></div>
  <div id="tooltip"></div>
  <script>
    // Dimensioni e costanti
    const width = ${width.toInt()}, height = ${height.toInt()};
    const radius = ${radarRadius};
    const centerX = width / 2, centerY = height / 2;
    
    // Dati degli indicatori (generati dinamicamente)
    const indicators = ${indicatorsJs};
    const n = indicators.length;
    
    // Crea l'elemento SVG
    const svg = d3.select("#chart")
      .append("svg")
      .attr("width", width)
      .attr("height", height);
    
    // Disegna gli assi radiali
    for (let i = 0; i < n; i++) {
      const angle = (2 * Math.PI / n) * i - Math.PI / 2;
      const x = centerX + radius * Math.cos(angle);
      const y = centerY + radius * Math.sin(angle);
      svg.append("line")
         .attr("class", "axis")
         .attr("x1", centerX)
         .attr("y1", centerY)
         .attr("x2", x)
         .attr("y2", y);
    }
    
    // Funzione che calcola la posizione [x,y] per un indicatore in base al suo valore
    function pointForIndicator(ind, i) {
      const angle = (2 * Math.PI / n) * i - Math.PI / 2;
      const r = (ind.value / ind.max) * radius;
      return [centerX + r * Math.cos(angle), centerY + r * Math.sin(angle)];
    }
    
    // Disegna la griglia (cerchi concentrici)
    const gridLevels = 5;
    for (let i = 1; i <= gridLevels; i++) {
      svg.append("circle")
         .attr("class", "grid")
         .attr("cx", centerX)
         .attr("cy", centerY)
         .attr("r", radius * i / gridLevels);
    }
    
    // Disegna le etichette degli indicatori
    indicators.forEach((d, i) => {
      const angle = (2 * Math.PI / n) * i - Math.PI / 2;
      const labelRadius = radius + 20;
      const x = centerX + labelRadius * Math.cos(angle);
      const y = centerY + labelRadius * Math.sin(angle);
      svg.append("text")
         .attr("class", "label")
         .attr("x", x)
         .attr("y", y)
         .text(d.name);
    });
    
    // Disegna il poligono radar
    let radarPolygon = svg.append("polygon")
      .attr("class", "polygon")
      .attr("points", indicators.map((d, i) => pointForIndicator(d, i).join(",")).join(" "));
    
    // Scala lineare per il colore (dominio: [0, max] – qui si usa max=10 come esempio generico)
    const colorScale = d3.scaleLinear()
      .domain([0, 5, 6, 10])
      .range([
        "rgba(255,0,0,0.95)",
        "rgba(255,165,0,0.95)",
        "rgba(255,255,0,0.95)",
        "rgba(144,238,144,0.95)"
      ]);
    
    // Aggiorna il poligono in base alla media degli indicatori
    function updatePolygon() {
      const points = indicators.map((d, i) => pointForIndicator(d, i).join(",")).join(" ");
      radarPolygon.attr("points", points);
      const avg = d3.mean(indicators, d => d.value);
      const fillColor = colorScale(avg);
      radarPolygon.attr("fill", fillColor);
      const borderColor = d3.rgb(fillColor).darker(0.7).toString();
      radarPolygon.attr("stroke", borderColor);
      svg.selectAll(".vertex").attr("stroke", borderColor);
    }
    
    // Gestione tooltip
    const tooltip = d3.select("#tooltip");
    radarPolygon
      .on("mousemove", (event) => {
        const tooltipText = indicators.map(d => d.name + ': ' + d.value.toFixed(2)).join("<br/>");
        tooltip.html(tooltipText)
               .style("left", (event.pageX + 10) + "px")
               .style("top", (event.pageY + 10) + "px")
               .style("opacity", 1);
      })
      .on("mouseout", () => { tooltip.style("opacity", 0); });
    
    // Disegna marker draggabili
    let vertices = svg.selectAll(".vertex")
      .data(indicators)
      .enter()
      .append("circle")
      .attr("class", "vertex")
      .attr("r", 8)
      .attr("cx", (d, i) => pointForIndicator(d, i)[0])
      .attr("cy", (d, i) => pointForIndicator(d, i)[1])
      .attr("stroke", d3.rgb(colorScale(d3.mean(indicators, d => d.value))).darker(0.7).toString())
      .call(d3.drag()
        .on("drag", function(event, d) {
          const index = indicators.indexOf(d);
          const dx = event.x - centerX;
          const dy = event.y - centerY;
          let newDistance = Math.sqrt(dx * dx + dy * dy);
          if (newDistance > radius) newDistance = radius;
          d.value = (newDistance / radius) * d.max;
          const newX = centerX + newDistance * Math.cos((2 * Math.PI / n) * index - Math.PI/2);
          const newY = centerY + newDistance * Math.sin((2 * Math.PI / n) * index - Math.PI/2);
          d3.select(this).attr("cx", newX).attr("cy", newY);
          updatePolygon();
        })
      );
    
    updatePolygon();
  </script>
</body>
</html>
''';

    // Crea il Blob e il URL per l'iframe
    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Crea l'iframe e lo registra
    final html.IFrameElement iFrameElement = html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..width = '100%'
      ..height = '100%';

    ui.platformViewRegistry.registerViewFactory(_viewId, (int viewId) => iFrameElement);
  }

  // Funzione per costruire la stringa JS degli indicatori
  String _buildIndicatorsJs(List<RadarIndicatorData> indicators) {
    final sb = StringBuffer();
    sb.write('[');
    for (int i = 0; i < indicators.length; i++) {
      final ind = indicators[i];
      sb.write('{ name: "${_escapeJs(ind.name)}", max: ${ind.max}, value: ${ind.value} }');
      if (i < indicators.length - 1) sb.write(', ');
    }
    sb.write(']');
    return sb.toString();
  }

  static String _escapeJs(String s) {
    const placeholder = '[[NEWLINE]]';
    s = s.replaceAll('\n', placeholder);
    s = s
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll("'", "\\'");
    return s.replaceAll(placeholder, '\\u000A');
  }

  static String _escapeHtml(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  @override
  Widget build(BuildContext context) {
    // Restituisce un SizedBox che contiene l'iframe con il radar chart
    return SizedBox(
      width: double.infinity,
      height: 600,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}



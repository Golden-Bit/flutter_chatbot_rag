import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/*void main() {
  runApp(StockChartApp());
}

class StockChartApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grafico Quotazioni Azionarie',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: StockChartScreen(),
    );
  }
}*/

class StockChartScreen extends StatefulWidget {
  final Map<String, dynamic> stockData;

  // Aggiunto un costruttore per accettare i dati JSON direttamente
  StockChartScreen({required this.stockData});

  @override
  _StockChartScreenState createState() => _StockChartScreenState();
}

class _StockChartScreenState extends State<StockChartScreen> {
  Map<String, dynamic>? stockData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStockData();
  }

  // Modificata per caricare i dati direttamente dal parametro
  Future<void> _loadStockData() async {
    setState(() {
      stockData = widget.stockData;
      isLoading = false;
    });
  }

  // Converte i dati di prezzo in punti FlSpot
  List<FlSpot> _getStockPrices() {
    if (stockData == null || !stockData!.containsKey("Close")) return [];
    final closeData = stockData!["Close"];
    
    List<FlSpot> spots = [];
    int index = 0; // Utilizzo l'indice per il grafico dell'asse X

    closeData.forEach((timeString, price) {
      spots.add(FlSpot(index.toDouble(), price.toDouble()));
      index++;
    });

    return spots;
  }

  // Genera etichette di date dall'epoca e crea una mappa in formato anno-mese-giorno
  Map<double, String> _generateDateLabels() {
    if (stockData == null || !stockData!.containsKey("Close")) return {};

    final closeData = stockData!["Close"];
    Map<double, String> dateLabels = {};
    int index = 0; // Usato per etichette sull'asse X
    String lastMonth = '';

    closeData.forEach((timeString, price) {
      final timeInMs = double.parse(timeString);
      final date = DateTime.fromMillisecondsSinceEpoch(timeInMs.toInt());

      // Formattiamo la data come 'yyyy-MM-dd'
      String formattedDate = DateFormat('yyyy-MM-dd').format(date);
      String monthLabel = DateFormat('yyyy-MM').format(date);

      // Aggiungi un'etichetta per il primo giorno di ogni mese
      if (monthLabel != lastMonth) {
        dateLabels[index.toDouble()] = formattedDate;
        lastMonth = monthLabel;
      }

      index++;
    });

    return dateLabels;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Storico Quotazioni'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildLineChart(),
            ),
    );
  }

  Widget _buildLineChart() {
    List<FlSpot> spots = _getStockPrices();
    Map<double, String> dateLabels = _generateDateLabels();

    if (spots.isEmpty) {
      return Center(child: Text('Nessun dato disponibile'));
    }

    double minY = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            belowBarData: BarAreaData(show: false),
          ),
        ],
        minY: minY - (maxY - minY) * 0.1,
        maxY: maxY + (maxY - minY) * 0.1,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false), // Nascondi l'asse Y a sinistra
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, _) {
                return Text(value.toStringAsFixed(0), style: TextStyle(fontSize: 12));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60, // Spazio per le etichette delle date
              getTitlesWidget: (value, _) {
                if (dateLabels.containsKey(value)) {
                  return Text(dateLabels[value]!, style: TextStyle(fontSize: 10));
                }
                return Text('');
              },
              interval: 1, // Ogni mese visualizza un'etichetta
            ),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false), // Disabilita l'asse superiore
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true, // Disegna le linee verticali
          verticalInterval: 1, // Intervallo delle linee verticali
          getDrawingVerticalLine: (value) {
            if (dateLabels.containsKey(value)) {
              return FlLine(color: Colors.grey, strokeWidth: 1); // Linea verticale in corrispondenza delle etichette
            }
            return FlLine(color: Colors.transparent); // Nascondi le linee non corrispondenti alle etichette
          },
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.black, width: 1)),
      ),
    );
  }
}

void main() {
  final Map<String, dynamic> sampleData = {
    "Close": {
      "1640995200000": 100.0,
      "1641081600000": 101.5,
      "1641168000000": 102.0,
      "1641254400000": 103.2,
      "1701340800000": 104.0,
    }
  };

  runApp(MaterialApp(
    home: StockChartScreen(stockData: sampleData),
  ));
}
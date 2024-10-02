import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eurostat ESG Data',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DataScreen(),
    );
  }
}

class DataScreen extends StatefulWidget {
  @override
  _DataScreenState createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  Map<String, dynamic>? data;
  bool isLoadingData = false;
  bool hasError = false;
  bool isExpanded = false;
  bool parametersLoaded = false;
  Map<String, dynamic>? parameters;
  String? selectedGeo;
  String? selectedUnit;
  List<String> selectedTimeRange = [];
  Map<int, int> viewModes = {}; // Mappa per gestire lo stato di visualizzazione di ogni grafico
  Map<int, bool> cardExpansionStates = {}; // Mappa per tracciare lo stato di espansione delle schede

  @override
  void initState() {
    super.initState();
    fetchParameters();
  }

  Future<void> fetchParameters() async {
    setState(() {
      hasError = false;
    });

    final String apiUrl =
        'http://34.140.110.56:8096/dataset/parameters/?dataset_id=nama_10_gdp';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          parameters = json.decode(response.body);
          selectedTimeRange = parameters!['time_options'].keys.toList();
          parametersLoaded = true;
        });
      } else {
        setState(() {
          hasError = true;
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
      });
    }
  }

  Future<void> fetchData() async {
    if (!parametersLoaded) {
      return;
    }

    setState(() {
      isLoadingData = true;
      hasError = false;
    });

    final String apiUrl = 'http://34.140.110.56:8096/generate_data/';
    final Map<String, dynamic> requestBody = {
      "dataset_id": 'nama_10_gdp',
      "geo": selectedGeo,
      "unit": selectedUnit,
      "time_range": selectedTimeRange,
      "indicators": []
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        setState(() {
          data = json.decode(response.body);
          isLoadingData = false;
          isExpanded = false; // Collassa automaticamente il riquadro di caricamento
        });
      } else {
        setState(() {
          hasError = true;
          isLoadingData = false;
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
        isLoadingData = false;
      });
    }
  }

  void _showDownloadDialog(BuildContext context, List<dynamic> records) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Seleziona formato di download'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('CSV'),
                leading: Icon(Icons.file_download),
                onTap: () {
                  _downloadCsv(records);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('JSON'),
                leading: Icon(Icons.file_download),
                onTap: () {
                  _downloadJson(records);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _downloadCsv(List<dynamic> records) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Tempo,Valore,Geo,Unità');
    for (var record in records) {
      buffer.writeln(
          '${record["time"]},${record["value"]},${record["geo"]},${record["unit"]}');
    }
    _saveFile(buffer.toString(), 'data.csv', 'text/csv');
  }

  void _downloadJson(List<dynamic> records) {
    final jsonData = jsonEncode(records);
    _saveFile(jsonData, 'data.json', 'application/json');
  }

  void _saveFile(String content, String fileName, String mimeType) {
    final blob = html.Blob([content], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dati ESG Eurostat'),
      ),
      body: parameters == null
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Riquadro generale
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    height: isExpanded ? 400 : 60,
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            isExpanded
                                ? SizedBox()
                                : Text(
                                    'Espandi per configurare il caricamento',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                            IconButton(
                              icon: Icon(isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more),
                              onPressed: () {
                                setState(() {
                                  isExpanded = !isExpanded;
                                });
                              },
                            ),
                          ],
                        ),
                        if (isExpanded) ...[
                          // Mostra il contenuto aggiuntivo solo se espanso
                          SizedBox(height: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: selectedGeo,
                                            hint: Text('Seleziona Paese'),
                                            onChanged: (String? newValue) {
                                              setState(() {
                                                selectedGeo = newValue;
                                              });
                                            },
                                            items: parameters!['geo_options']
                                                .entries
                                                .map<DropdownMenuItem<String>>(
                                                    (entry) {
                                              return DropdownMenuItem<String>(
                                                value: entry.key,
                                                child: Text(entry.value),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: selectedUnit,
                                            hint: Text('Seleziona Unità'),
                                            onChanged: (String? newValue) {
                                              setState(() {
                                                selectedUnit = newValue;
                                              });
                                            },
                                            items: parameters!['unit_options']
                                                .entries
                                                .map<DropdownMenuItem<String>>(
                                                    (entry) {
                                              return DropdownMenuItem<String>(
                                                value: entry.key,
                                                child: Text(entry.value),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text('Seleziona Anni:'),
                                            SizedBox(width: 8),
                                            Tooltip(
                                              message:
                                                  'Seleziona uno o più anni per filtrare i dati ESG.',
                                              child: Icon(Icons.info_outline),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8.0,
                                          runSpacing: 8.0,
                                          children: parameters!['time_options']
                                              .entries
                                              .map<Widget>((entry) {
                                            return FilterChip(
                                              label: Text(entry.value,
                                                  style:
                                                      TextStyle(fontSize: 12)),
                                              labelPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 8),
                                              selected: selectedTimeRange
                                                  .contains(entry.key),
                                              onSelected: (bool selected) {
                                                setState(() {
                                                  if (selected) {
                                                    selectedTimeRange
                                                        .add(entry.key);
                                                  } else {
                                                    selectedTimeRange
                                                        .remove(entry.key);
                                                  }
                                                });
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: parametersLoaded ? fetchData : null,
                                child: Text('Carica'),
                              ),
                            ],
                          )
                        ]
                      ],
                    ),
                  ),

                  SizedBox(height: 20), // Spaziatura

                  // Visualizzazione dei dati caricati
                  Expanded(
                    child: isLoadingData
                        ? Center(child: CircularProgressIndicator())
                        : data == null
                            ? Text('Nessun dato caricato.')
                            : ListView.builder(
                                itemCount: data!["processed_data"].length,
                                itemBuilder: (context, index) {
                                  String indicator = data!["processed_data"]
                                      .keys
                                      .elementAt(index);
                                  List<dynamic> records =
                                      data!["processed_data"][indicator];

                                  String description =
                                      _getDescriptionForIndicator(indicator);

                                  // Inizializza lo stato di visualizzazione e di espansione per ogni scheda
                                  if (!viewModes.containsKey(index)) {
                                    viewModes[index] = 0;
                                  }
                                  if (!cardExpansionStates.containsKey(index)) {
                                    cardExpansionStates[index] = false; // Default to collapsed
                                  }

                                  return Card(
                                    margin: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Stack(
                                      children: [
                                        Column(
                                          children: [
                                            ListTile(
                                              title: Text(
                                                indicator,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              subtitle: Text(description),
                                              trailing: IconButton(
                                                icon: Icon(
                                                  cardExpansionStates[index]!
                                                      ? Icons.expand_less
                                                      : Icons.expand_more,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    cardExpansionStates[index] =
                                                        !cardExpansionStates[
                                                            index]!;
                                                  });
                                                },
                                              ),
                                            ),
                                            if (cardExpansionStates[index] ==
                                                true) ...[
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8.0),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                            color: Colors.grey),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(5),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8.0),
                                                      child: Row(
                                                        children: [
                                                          IconButton(
                                                            icon: Icon(Icons
                                                                .show_chart),
                                                            onPressed: () {
                                                              setState(() {
                                                                viewModes[
                                                                    index] = 0;
                                                              });
                                                            },
                                                          ),
                                                          IconButton(
                                                            icon: Icon(Icons
                                                                .table_chart),
                                                            onPressed: () {
                                                              setState(() {
                                                                viewModes[
                                                                    index] = 1;
                                                              });
                                                            },
                                                          ),
                                                          IconButton(
                                                            icon: Icon(Icons
                                                                .bar_chart),
                                                            onPressed: () {
                                                              setState(() {
                                                                viewModes[
                                                                    index] = 2;
                                                              });
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(
                                                          Icons.download),
                                                      onPressed: () {
                                                        _showDownloadDialog(
                                                            context, records);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                        bottom: 20.0),
                                                child: viewModes[index] == 0
                                                    ? _buildLineChart(records)
                                                    : viewModes[index] == 1
                                                        ? _buildDataTable(
                                                            records)
                                                        : _buildBarChart(
                                                            records),
                                              ),
                                            ]
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
    );
  }

  // Funzioni per generare descrizioni, costruire i grafici e le tabelle
  String _getDescriptionForIndicator(String indicator) {
    switch (indicator) {
      case 'gdp':
        return 'Prodotto interno lordo (PIL) misura il valore totale dei beni e servizi prodotti in un paese.';
      case 'unemployment_rate':
        return 'Tasso di disoccupazione rappresenta la percentuale della forza lavoro senza impiego.';
      case 'inflation_rate':
        return 'Tasso di inflazione riflette la variazione percentuale del livello generale dei prezzi nel tempo.';
      default:
        return 'Indicatore macroeconomico chiave che rappresenta una misura delle performance economiche.';
    }
  }

  Widget _buildLineChart(List<dynamic> records) {
    double minY = records
        .map((record) => double.parse(record["value"].toString()))
        .reduce((a, b) => a < b ? a : b);
    double maxY = records
        .map((record) => double.parse(record["value"].toString()))
        .reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        height: 300,
        child: LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: records
                    .map((record) => FlSpot(
                        double.parse(record["time"].toString()),
                        double.parse(record["value"].toString())))
                    .toList(),
                isCurved: true,
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.lightBlueAccent],
                ),
                barWidth: 3,
                belowBarData: BarAreaData(show: false),
              ),
            ],
            minY: minY - (maxY - minY) * 0.1,
            maxY: maxY + (maxY - minY) * 0.1,
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, _) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        value.toStringAsFixed(0),
                        style: TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        value.toInt().toString(),
                        style: TextStyle(fontSize: 10),
                      ),
                    );
                  },
                  interval: 1,
                ),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(show: true),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.black, width: 1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(List<dynamic> records) {
    double minY = records
        .map((record) => double.parse(record["value"].toString()))
        .reduce((a, b) => a < b ? a : b);
    double maxY = records
        .map((record) => double.parse(record["value"].toString()))
        .reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        height: 300,
        child: BarChart(
          BarChartData(
            barGroups: records
                .map((record) => BarChartGroupData(
                      x: int.parse(record["time"].toString()),
                      barRods: [
                        BarChartRodData(
                          toY: double.parse(record["value"].toString()),
                          color: Colors.blue,
                        ),
                      ],
                    ))
                .toList(),
            minY: minY - (maxY - minY) * 0.1,
            maxY: maxY + (maxY - minY) * 0.1,
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, _) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        value.toStringAsFixed(0),
                        style: TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        value.toInt().toString(),
                        style: TextStyle(fontSize: 10),
                      ),
                    );
                  },
                  interval: 1,
                ),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(show: true),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.black, width: 1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable(List<dynamic> records) {
    return Container(
      width: double.infinity,
      height: 300,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(5),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columns: [
            DataColumn(label: Text('Tempo')),
            DataColumn(label: Text('Valore')),
            DataColumn(label: Text('Geo')),
            DataColumn(label: Text('Unità')),
          ],
          rows: records
              .map((record) => DataRow(cells: [
                    DataCell(Text(record["time"].toString())),
                    DataCell(Text(record["value"].toString())),
                    DataCell(Text(record["geo"].toString())),
                    DataCell(Text(record["unit"].toString())),
                  ]))
              .toList(),
        ),
      ),
    );
  }
}

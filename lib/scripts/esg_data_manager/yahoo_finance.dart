import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // Aggiungi questa libreria per formattare le date
import 'esg_charts.dart'; // Importa la pagina di analisi ESG aziendale

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ricerca Aziende ESG',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ESGDataScreen(),
    );
  }
}

class ESGDataScreen extends StatefulWidget {
  @override
  _ESGDataScreenState createState() => _ESGDataScreenState();
}

class _ESGDataScreenState extends State<ESGDataScreen> {
  TextEditingController _searchController = TextEditingController();
  List<dynamic> _tickers = [];
  List<dynamic> _filteredTickers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTickers();
  }

  Future<void> _fetchTickers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse('http://34.140.110.56:8097/tickers'));

      if (response.statusCode == 200) {
        List<dynamic> tickers = json.decode(response.body);
        setState(() {
          _tickers = tickers;
          _filteredTickers = tickers;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        throw Exception('Errore nel caricamento dei tickers.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print(e);
    }
  }

  void _filterTickers(String query) {
    setState(() {
      _filteredTickers = _tickers.where((ticker) {
        final companyName = ticker['company_name']?.toLowerCase() ?? '';
        final tickerSymbol = ticker['ticker']?.toLowerCase() ?? '';
        return companyName.contains(query.toLowerCase()) || tickerSymbol.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _fetchCompanyData(String ticker) async {
    setState(() {
      _isLoading = true;
    });

    List<String> dataIds = ["esg_data", "company_data", "financials_data", "dividends_history", "stock_history"];
    Map<String, dynamic> combinedCompanyData = {};

    try {
      for (String dataId in dataIds) {
        try {
          final response = await http.post(
            Uri.parse('http://34.140.110.56:8097/tickers/$ticker/data'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "ticker": ticker,
              "data_id": dataId,
              "data_params": {}
            }),
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            combinedCompanyData[dataId] = data;
          } else {
            combinedCompanyData[dataId] = "Dati non disponibili.";
          }
        } catch (e) {
          combinedCompanyData[dataId] = "Errore nel caricamento dei dati.";
        }
      }

      setState(() {
        _isLoading = false;
      });

      if (combinedCompanyData.isNotEmpty) {
        _showCompanyDataDialog(ticker, combinedCompanyData);
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Errore generale: $e');
    }
  }

  void _showCompanyDataDialog(String ticker, Map<String, dynamic> companyData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: DefaultTabController(
            length: companyData.keys.length,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TabBar(
                  tabs: companyData.keys.map((section) {
                    return Tab(text: _getFormattedSectionName(section));
                  }).toList(),
                  labelColor: Colors.blue,
                  indicatorColor: Colors.blueAccent,
                  unselectedLabelColor: Colors.grey,
                ),
                Expanded(
                  child: TabBarView(
                    children: companyData.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildSection(entry.key, entry.value),
                      );
                    }).toList(),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Chiudi'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(String sectionTitle, dynamic data) {
    print(sectionTitle);
    print(data);
    if (data == null || data == "Errore nel caricamento dei dati" || data == "Dati non disponibili.") {
      return Center(child: Text('Dati non disponibili per $sectionTitle.'));
    }

        if (sectionTitle == "stock_history" && data is Map<String, dynamic>) {
      return StockChartScreen(stockData: data);
    }

    if (data is Map<String, dynamic>) {
      return ListView(
        shrinkWrap: true,
        children: data.entries.map((entry) {
          if (entry.value is List) {
            return _buildListData(entry.key, entry.value);
          } else if (entry.value is Map) {
            return _buildNestedObject(entry.key, entry.value);
          } else {
            return _buildFormattedDataRow(entry.key, entry.value);
          }
        }).toList(),
      );
    }

    return Text('Formato dati non riconosciuto.');
  }

  Widget _buildFormattedDataRow(String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _formatKey(key),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _formatValue(value),
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListData(String key, List<dynamic> value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatKey(key),
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),
          SizedBox(height: 8),
          Container(
            height: 100, // Make the container scrollable if the list is long
            child: ListView.builder(
              scrollDirection: Axis.vertical,
              itemCount: value.length,
              itemBuilder: (context, index) {
                return Text('- ${_formatValue(value[index])}');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNestedObject(String key, Map<String, dynamic> value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatKey(key),
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: value.entries.map((entry) {
                return _buildFormattedDataRow(entry.key, entry.value);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatKey(String key) {
    return key.replaceAll('_', ' ').toUpperCase();
  }

  String _formatValue(dynamic value) {
    if (value == null || value == "null") {
      return "N/A";
    } else if (value is double || value is int) {
      return value.toStringAsFixed(2);
    } else {
      return value.toString();
    }
  }

  String _getFormattedSectionName(String section) {
    switch (section) {
      case "esg_data":
        return "Dati ESG";
      case "company_data":
        return "Dati Aziendali";
      case "financials_data":
        return "Bilancio";
      case "dividends_history":
        return "Dividendi";
      case "stock_history":
        return "Storico Azioni";
      default:
        return section;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ricerca Aziende ESG'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Barra di ricerca per filtrare i tickers
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cerca Azienda o Ticker',
                suffixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                _filterTickers(value);
              },
            ),
            SizedBox(height: 20),

            // Lista dei tickers filtrati
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _filteredTickers.length,
                      itemBuilder: (context, index) {
                        final ticker = _filteredTickers[index];
                        return ListTile(
                          title: Text(ticker['company_name'] ?? 'N/A'),
                          subtitle: Text('Ticker: ${ticker['ticker'] ?? 'N/A'}'),
                          onTap: () {
                            _fetchCompanyData(ticker['ticker']);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

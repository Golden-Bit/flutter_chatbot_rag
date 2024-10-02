import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'ticker_data_processor.dart'; // Importa la pagina per il processor
import 'ticker_data_page.dart'; // Importa la pagina di visualizzazione dati del ticker

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
  bool _isFocused = false;

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

    try {
      final response = await http.post(
        Uri.parse('http://34.140.110.56:8097/tickers/$ticker/data'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "ticker": ticker,
          "data_id": "stock_history",
          "data_params": {}
        }),
      );

      if (response.statusCode == 200) {
        // Parsing del JSON in formato mappa
        final Map<String, dynamic> stockData = json.decode(response.body);

        // Estrazione dei dati da ogni metrica (Open, Close, etc.)
        Map<String, double> openData = Map<String, double>.from(stockData['Open']);
        Map<String, double> closeData = Map<String, double>.from(stockData['Close']);
        Map<String, double> highData = Map<String, double>.from(stockData['High']);
        Map<String, double> lowData = Map<String, double>.from(stockData['Low']);
        Map<String, double> volumeData = Map<String, double>.from(stockData['Volume']);
        Map<String, double> dividendData = Map<String, double>.from(stockData['Dividends']);

        // Creazione della lista di TickerData
        List<TickerData> tickerData = [];
        for (String timestamp in openData.keys) {
          tickerData.add(TickerData(
            timestamp: int.parse(timestamp),
            open: openData[timestamp] ?? 0.0,
            close: closeData[timestamp] ?? 0.0,
            high: highData[timestamp] ?? 0.0,
            low: lowData[timestamp] ?? 0.0,
            volume: volumeData[timestamp]?.toInt() ?? 0,
            dividend: dividendData[timestamp] ?? 0.0,
          ));
        }

        // Naviga alla nuova pagina con i dati del ticker
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TickerDataPage(ticker: ticker, processor: TickerDataProcessor(data: tickerData)),
          ),
        );

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        throw Exception('Errore nel caricamento dei dati del ticker.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Errore generale: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ricerca Aziende ESG'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildFullWidthPlaceholder('Sezione 1'),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Column(
                  children: [
                    FocusScope(
                      onFocusChange: (hasFocus) {
                        setState(() {
                          _isFocused = hasFocus;
                        });
                      },
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Cerca Azienda o Ticker',
                          suffixIcon: Icon(Icons.search),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          _filterTickers(value);
                        },
                      ),
                    ),
                    if (_isFocused && _searchController.text.isNotEmpty)
                      SizedBox(height: 10),
                    if (_isFocused && _searchController.text.isNotEmpty)
                      _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : _filteredTickers.isEmpty
                              ? Center(child: Text('Nessun risultato trovato.'))
                              : Container(
                                  height: _filteredTickers.length > 10 ? 300 : null,
                                  child: ListView.builder(
                                    shrinkWrap: true,
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
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildSectionPlaceholder('Aziende Bullish')),
                  SizedBox(width: 16),
                  Expanded(child: _buildSectionPlaceholder('Aziende Bearish')),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildSectionPlaceholder('Ritracciamento Bullish')),
                  SizedBox(width: 16),
                  Expanded(child: _buildSectionPlaceholder('Ritracciamento Bearish')),
                ],
              ),
              SizedBox(height: 20),
              _buildTwoColumnPlaceholders(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthPlaceholder(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.yellow[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Sezione in lavorazione',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionPlaceholder(String title) {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18),
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.yellow[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Sezione in lavorazione',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoColumnPlaceholders() {
    return Container(
      width: double.infinity,
      height: 300,
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sezione 3',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.yellow[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sezione in lavorazione (Colonna 1)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.yellow[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sezione in lavorazione (Colonna 2)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

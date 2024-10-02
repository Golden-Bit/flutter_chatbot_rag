import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ticker_data_processor.dart';

class TickerDataPage extends StatelessWidget {
  final String ticker;
  final TickerDataProcessor processor;

  TickerDataPage({required this.ticker, required this.processor});

  @override
  Widget build(BuildContext context) {
    final companyData = {
      "companyName": ticker,
      "ticker": ticker,
      "exchange": "NASDAQ",
      "sector": "Technology - Consumer Electronics",
      "price": 12.0, // processor.getLatestClose(TimeFrame.daily),
      "priceChange": 0.00,
      "priceChangePercentage": 0.0,
      "currentPrice": 12.0, // processor.getLatestClose(TimeFrame.daily),
      "priceChangeToday": 0.12,
      "dayMin": 12.0, // processor.getMinPrice(TimeFrame.daily),
      "dayMax": 12.0, // processor.getMaxPrice(TimeFrame.daily),
      "yearMin": 164.08,
      "yearMax": 237.23,
      "marketCap": "3.46T",
      "volume": "55.8M",
      "eps": 6.56,
      "peRatio": 34.72,
      "earningsDate": "31/10/2024, 01:00:00"
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('Dati per $ticker'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              companyData["companyName"].toString(),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colonna 1: Prezzo, variazione e info generali
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${companyData["price"]} USD',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${companyData["priceChange"]}% USD',
                        style: TextStyle(
                          fontSize: 18,
                          color: (companyData["priceChange"] as double) >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      Text(
                        '${companyData["exchange"]} - ${companyData["ticker"]}',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      Text(
                        companyData["sector"].toString(),
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // Colonna 2: Dati centrali (prezzi, volume, capitalizzazione)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: 'Prezzo attuale: ',
                          children: [
                            TextSpan(
                              text: '${companyData["currentPrice"]} USD',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            TextSpan(
                              text: ' (${companyData["priceChangeToday"]}%)',
                              style: TextStyle(
                                  color: Colors.green, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Min/Max giornata: ${companyData["dayMin"]} - ${companyData["dayMax"]} USD',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Min/Max Anno: ${companyData["yearMin"]} - ${companyData["yearMax"]} USD',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Cap. di mercato: ${companyData["marketCap"]}',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Media Vol: ${companyData["volume"]}',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // Colonna 3: EPS, PE, Annuncio Earnings
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'EPS: ${companyData["eps"]}',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        'PE: ${companyData["peRatio"]}',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Annuncio Earnings: ${companyData["earningsDate"]}',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Bottoni per copiare i dati
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: Icon(Icons.copy),
                  label: Text('Copia'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: jsonEncode(companyData)));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Dati copiati negli appunti')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

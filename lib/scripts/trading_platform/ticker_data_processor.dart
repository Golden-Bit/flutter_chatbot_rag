import 'dart:convert';
import 'dart:math';

// Struttura per rappresentare i dati di un ticker (prezzo, dividendi, volumi)
class TickerData {
  int timestamp; // Millisecondi dall'epoca
  double open;
  double close;
  double high;
  double low;
  num volume;
  double dividend;

  TickerData({
    required this.timestamp,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.volume,
    required this.dividend,
  });

  // Metodo per ottenere un JSON contenente la data formattata con timezone Europa Centrale in formato ISO
  Map<String, dynamic> getFormattedDateJson() {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    DateTime cetDateTime = _applyCentralEuropeanTimeZone(dateTime); // Applica il fuso orario CET/CEST
    String timezoneOffset = _getIsoTimeZoneOffset(cetDateTime);

    return {
      'year': cetDateTime.year,
      'month': cetDateTime.month,
      'week': ((cetDateTime.day - 1) / 7).ceil(),
      'day_of_week': cetDateTime.weekday,  // Aggiunta del giorno della settimana (1=Lunedì, 7=Domenica)
      'hour': cetDateTime.hour,
      'minute': cetDateTime.minute,
      'second': cetDateTime.second,
      'timezone': 'CET$timezoneOffset',  // Fuso orario in formato ISO
    };
  }

  // Metodo per convertire in JSON
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'open': open,
      'close': close,
      'high': high,
      'low': low,
      'volume': volume,
      'dividend': dividend,
      'formatted_date': getFormattedDateJson(),
    };
  }

  // Metodo per applicare il fuso orario Europa Centrale (CET o CEST)
  DateTime _applyCentralEuropeanTimeZone(DateTime dateTime) {
    // CET = UTC+1, CEST = UTC+2 (ora legale)
    bool isDaylightSaving = dateTime.timeZoneOffset.isNegative;
    return isDaylightSaving
        ? dateTime.add(Duration(hours: 2))  // CEST (UTC+2)
        : dateTime.add(Duration(hours: 1)); // CET (UTC+1)
  }

  // Metodo per ottenere il fuso orario nel formato ISO
  String _getIsoTimeZoneOffset(DateTime dateTime) {
    final duration = dateTime.timeZoneOffset;
    final hours = duration.inHours.abs().toString().padLeft(2, '0');
    final minutes = (duration.inMinutes.remainder(60)).abs().toString().padLeft(2, '0');
    final sign = duration.isNegative ? '-' : '+';
    return '$sign$hours:$minutes';
  }
}

// Classe per manipolare i dati del ticker
class TickerDataProcessor {
  List<TickerData> data;

  TickerDataProcessor({required this.data});

  // Metodo per raggruppare i dati in un certo timeframe (orario, giornaliero, settimanale, ecc.)
  List<TickerData> aggregateData(TimeFrame timeframe) {
    // Raggruppamento per il timeframe scelto
    Map<int, List<TickerData>> groupedData = {};

    for (var entry in data) {
      int adjustedTime = _adjustTimestamp(entry.timestamp, timeframe);

      if (!groupedData.containsKey(adjustedTime)) {
        groupedData[adjustedTime] = [];
      }

      groupedData[adjustedTime]?.add(entry);
    }

    // Accorpa i dati raggruppati
    List<TickerData> aggregatedData = [];
    groupedData.forEach((key, value) {
      aggregatedData.add(_mergeData(key, value));
    });

    return aggregatedData;
  }

  // Metodo per visualizzare la struttura dati in JSON
  String toJson(TimeFrame timeframe) {
    List<TickerData> aggregatedData = aggregateData(timeframe);
    return jsonEncode(aggregatedData.map((e) => e.toJson()).toList());
  }

  // Metodo per raggruppare in base al timestamp in millisecondi
  int _adjustTimestamp(int timestamp, TimeFrame timeframe) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    switch (timeframe) {
      case TimeFrame.hourly:
        return DateTime(dateTime.year, dateTime.month, dateTime.day, dateTime.hour).millisecondsSinceEpoch;
      case TimeFrame.daily:
        return DateTime(dateTime.year, dateTime.month, dateTime.day).millisecondsSinceEpoch;
      case TimeFrame.weekly:
        int dayOfWeek = dateTime.weekday;
        DateTime startOfWeek = dateTime.subtract(Duration(days: dayOfWeek - 1));
        return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day).millisecondsSinceEpoch;
      case TimeFrame.monthly:
        return DateTime(dateTime.year, dateTime.month).millisecondsSinceEpoch;
      case TimeFrame.yearly:
        return DateTime(dateTime.year).millisecondsSinceEpoch;
      default:
        throw ArgumentError('Invalid timeframe');
    }
  }

  // Metodo per accorpare dati per lo stesso timestamp (stesso giorno, settimana, mese, etc.)
  TickerData _mergeData(int timestamp, List<TickerData> entries) {
    double open = entries.first.open;
    double close = entries.last.close;
    double high = entries.map((e) => e.high).reduce(max);
    double low = entries.map((e) => e.low).reduce(min);
    num volume = entries.map((e) => e.volume).reduce((a, b) => a + b);
    double dividend = entries.map((e) => e.dividend).reduce((a, b) => a + b);

    return TickerData(
      timestamp: timestamp,
      open: open,
      close: close,
      high: high,
      low: low,
      volume: volume,
      dividend: dividend,
    );
  }
}

// Enum per definire i timeframe, ora include anche "orario"
enum TimeFrame {
  hourly,    // Timeframe orario
  daily,
  weekly,
  monthly,
  yearly,
}

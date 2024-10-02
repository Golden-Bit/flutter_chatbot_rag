import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        body: CalendarComponent(),
      ),
    );
  }
}

class CalendarComponent extends StatefulWidget {
  @override
  _CalendarComponentState createState() => _CalendarComponentState();
}

class _CalendarComponentState extends State<CalendarComponent> {
  DateTime _currentDate = DateTime.now();
  Map<DateTime, List<Appointment>> _appointments = {};
  String _viewMode = 'Mese';

  void _previousMonth() {
    setState(() {
      if (_viewMode == 'Mese') {
        _currentDate = DateTime(_currentDate.year, _currentDate.month - 1);
      } else {
        _currentDate = DateTime(_currentDate.year - 1, _currentDate.month);
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_viewMode == 'Mese') {
        _currentDate = DateTime(_currentDate.year, _currentDate.month + 1);
      } else {
        _currentDate = DateTime(_currentDate.year + 1, _currentDate.month);
      }
    });
  }

  void _addAppointment(
      DateTime date,
      String title,
      DateTime startTime,
      Color color,
      String recurrence,
      int recurrenceCount,
      Duration duration,
      String location,
      String description,
      String privacy,
      String organizer,
      String videocallUrl) {
    setState(() {
      for (int i = 0; i < recurrenceCount; i++) {
        DateTime appointmentDate = date;
        if (recurrence == 'Giornaliera') {
          appointmentDate = date.add(Duration(days: i));
        } else if (recurrence == 'Settimanale') {
          appointmentDate = date.add(Duration(days: 7 * i));
        } else if (recurrence == 'Mensile') {
          appointmentDate = DateTime(date.year, date.month + i, date.day);
        } else if (recurrence == 'Annuale') {
          appointmentDate = DateTime(date.year + i, date.month, date.day);
        }

        if (_appointments[appointmentDate] == null) {
          _appointments[appointmentDate] = [];
        }
        _appointments[appointmentDate]!.add(Appointment(
          title,
          startTime,
          color,
          duration,
          location: location,
          description: description,
          privacy: privacy,
          organizer: organizer,
          recurrence: recurrence,
          recurrenceCount: recurrenceCount,
          currentRecurrence: i + 1,
          videocallUrl: videocallUrl,
        ));
        _appointments[appointmentDate]!
            .sort((a, b) => a.startTime.compareTo(b.startTime));
      }
    });
  }

  void _showAppointmentsDialog(DateTime date) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title:
              Text('Appuntamenti del ${DateFormat('dd/MM/yyyy').format(date)}'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _appointments[date]?.length ?? 0,
              itemBuilder: (BuildContext context, int index) {
                final appointment = _appointments[date]![index];
                final endTime = appointment.startTime.add(appointment.duration);
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: appointment.color, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                text: 'Inizio: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                                children: <TextSpan>[
                                  TextSpan(
                                      text:
                                          '${DateFormat.Hm().format(appointment.startTime)}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.normal)),
                                ],
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                text: 'Fine: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                                children: <TextSpan>[
                                  TextSpan(
                                      text:
                                          '${DateFormat.Hm().format(endTime)}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.normal)),
                                ],
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                text: 'Durata: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                                children: <TextSpan>[
                                  TextSpan(
                                      text:
                                          '${appointment.duration.inHours} ore ${appointment.duration.inMinutes.remainder(60)} minuti',
                                      style: TextStyle(
                                          fontWeight: FontWeight.normal)),
                                ],
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                text: 'Ricorrenza: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                                children: <TextSpan>[
                                  TextSpan(
                                      text: '${appointment.recurrence}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.normal)),
                                ],
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                text: 'Ricorrenza attuale: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                                children: <TextSpan>[
                                  TextSpan(
                                      text:
                                          '${appointment.currentRecurrence}/${appointment.recurrenceCount}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.normal)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      VerticalDivider(
                        color: Colors.grey,
                        thickness: 1,
                        width: 32,
                        indent: 8,
                        endIndent: 8,
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                text: 'Oggetto: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                                children: <TextSpan>[
                                  TextSpan(
                                      text: '${appointment.title}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.normal)),
                                ],
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                text: 'Descrizione: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                                children: <TextSpan>[
                                  TextSpan(
                                      text: '${appointment.description}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.normal)),
                                ],
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                text: 'Privacy: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                                children: <TextSpan>[
                                  TextSpan(
                                      text: '${appointment.privacy}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.normal)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      VerticalDivider(
                        color: Colors.grey,
                        thickness: 1,
                        width: 32,
                        indent: 8,
                        endIndent: 8,
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                text: 'Luogo: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                                children: <TextSpan>[
                                  TextSpan(
                                      text: '${appointment.location}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.normal)),
                                ],
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                text: 'Videocall: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                                children: <TextSpan>[
                                  TextSpan(
                                      text: '${appointment.videocallUrl}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.normal)),
                                ],
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                text: 'Organizzatore: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                                children: <TextSpan>[
                                  TextSpan(
                                      text: '${appointment.organizer}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.normal)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text('Chiudi'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int daysInMonth =
        DateTime(_currentDate.year, _currentDate.month + 1, 0).day;
    String monthYear = DateFormat.yMMMM().format(_currentDate);

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8.0),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewAppointmentPage(
                        initialDate: _currentDate,
                      ),
                    ),
                  );
                  if (result != null && result is Map<String, dynamic>) {
                    _addAppointment(
                        result['date'],
                        result['title'],
                        result['startTime'],
                        result['color'],
                        result['recurrence'],
                        result['recurrenceCount'],
                        result['duration'],
                        result['location'],
                        result['description'],
                        result['privacy'],
                        result['organizer'],
                        result['videocallUrl']);
                  }
                },
                child: Text('Nuovo'),
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.arrow_left),
                onPressed: _previousMonth,
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _viewMode = 'Mese';
                  });
                },
                style: ElevatedButton.styleFrom(
                  side: BorderSide(
                      color: _viewMode == 'Mese'
                          ? Colors.blue
                          : Colors.transparent,
                      width: 2),
                  elevation: _viewMode == 'Mese' ? 10 : 2,
                ),
                child: Text('Mese'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _viewMode = 'Anno';
                  });
                },
                style: ElevatedButton.styleFrom(
                  side: BorderSide(
                      color: _viewMode == 'Anno'
                          ? Colors.blue
                          : Colors.transparent,
                      width: 2),
                  elevation: _viewMode == 'Anno' ? 10 : 2,
                ),
                child: Text('Anno'),
              ),
              IconButton(
                icon: Icon(Icons.arrow_right),
                onPressed: _nextMonth,
              ),
              Spacer(),
              Text(monthYear, style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = constraints.maxWidth ~/ 100;
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 1.0,
                  mainAxisSpacing: 4.0,
                  crossAxisSpacing: 4.0,
                ),
                itemCount: daysInMonth,
                itemBuilder: (BuildContext context, int index) {
                  DateTime date = DateTime(
                      _currentDate.year, _currentDate.month, index + 1);
                  return GestureDetector(
                    onTap: () {
                      _showAppointmentsDialog(date);
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      child: Card(
                        child: Stack(
                          children: [
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            if (_appointments[date] != null)
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: _appointments[date]!
                                          .map((appointment) {
                                        return Container(
                                          margin: EdgeInsets.only(top: 4),
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 2, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: appointment.color,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              DateFormat.Hm()
                                                  .format(appointment.startTime),
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class NewAppointmentPage extends StatefulWidget {
  final DateTime initialDate;

  NewAppointmentPage({required this.initialDate});

  @override
  _NewAppointmentPageState createState() => _NewAppointmentPageState();
}

class _NewAppointmentPageState extends State<NewAppointmentPage> {
  late TextEditingController _titleController;
  late DateTime _selectedDate;
  late DateTime _startTime;
  late TextEditingController _durationController;
  late TextEditingController _locationController;
  late TextEditingController _videocallController;
  String _recurrence = 'Nessuna';
  late TextEditingController _recurrenceCountController;
  String _privacy = "default";
  String _organizer = "simonesansalone777@gmail.com";
  String _description = "";
  Color _selectedColor = Colors.green;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _locationController = TextEditingController();
    _videocallController = TextEditingController();
    _durationController = TextEditingController(text: '01:00');
    _recurrenceCountController = TextEditingController(text: '1');
    _selectedDate = widget.initialDate;
    _startTime = widget.initialDate;
  }

  List<Color> _colorOptions = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.yellow,
    Colors.cyan,
    Colors.teal,
    Colors.amber,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nuovo Appuntamento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Oggetto appuntamento',
                hintText: 'es. Pranzo di lavoro',
              ),
            ),
            SizedBox(height: 16),
            Text('Avvio', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              readOnly: true,
              controller: TextEditingController(
                text: DateFormat('dd/MM/yyyy HH:mm').format(_startTime),
              ),
              decoration: InputDecoration(
                hintText: 'Data di inizio',
              ),
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2101),
                );
                if (pickedDate != null) {
                  TimeOfDay? pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_startTime),
                  );
                  if (pickedTime != null) {
                    setState(() {
                      _startTime = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                    });
                  }
                }
              },
            ),
            SizedBox(height: 16),
            TextField(
              controller: _durationController,
              decoration: InputDecoration(
                labelText: 'Durata',
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Text('Ricorrenza:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _recurrence = 'Nessuna';
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    side: BorderSide(
                        color: _recurrence == 'Nessuna'
                            ? Colors.blue
                            : Colors.transparent,
                        width: 2),
                    elevation: _recurrence == 'Nessuna' ? 10 : 2,
                  ),
                  child: Text('Nessuna'),
                ),
                SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _recurrence = 'Giornaliera';
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    side: BorderSide(
                        color: _recurrence == 'Giornaliera'
                            ? Colors.blue
                            : Colors.transparent,
                        width: 2),
                    elevation: _recurrence == 'Giornaliera' ? 10 : 2,
                  ),
                  child: Text('Giornaliera'),
                ),
                SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _recurrence = 'Settimanale';
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    side: BorderSide(
                        color: _recurrence == 'Settimanale'
                            ? Colors.blue
                            : Colors.transparent,
                        width: 2),
                    elevation: _recurrence == 'Settimanale' ? 10 : 2,
                  ),
                  child: Text('Settimanale'),
                ),
                SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _recurrence = 'Mensile';
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    side: BorderSide(
                        color: _recurrence == 'Mensile'
                            ? Colors.blue
                            : Colors.transparent,
                        width: 2),
                    elevation: _recurrence == 'Mensile' ? 10 : 2,
                  ),
                  child: Text('Mensile'),
                ),
                SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _recurrence = 'Annuale';
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    side: BorderSide(
                        color: _recurrence == 'Annuale'
                            ? Colors.blue
                            : Colors.transparent,
                        width: 2),
                    elevation: _recurrence == 'Annuale' ? 10 : 2,
                  ),
                  child: Text('Annuale'),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextField(
              controller: _recurrenceCountController,
              decoration: InputDecoration(
                labelText: 'Numero di ricorrenze',
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Ubicazione',
                hintText: 'Riunione online',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _videocallController,
              decoration: InputDecoration(
                labelText: 'Videocall URL',
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Text('Privacy', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                DropdownButton<String>(
                  value: _privacy,
                  items: [
                    DropdownMenuItem(
                      value: "default",
                      child: Text("Predefinito"),
                    ),
                    DropdownMenuItem(
                      value: "public",
                      child: Text("Pubblica"),
                    ),
                    DropdownMenuItem(
                      value: "private",
                      child: Text("Privato"),
                    ),
                    DropdownMenuItem(
                      value: "confidential",
                      child: Text("Solo utenti interni"),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _privacy = value!;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            Text('Organizzatore',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(
                      'https://gold-solar-srl2.odoo.com/web/image/res.partner/3/avatar_128'),
                ),
                SizedBox(width: 8),
                Text(_organizer),
              ],
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Descrizione',
                hintText: 'Aggiungi descrizione',
              ),
              maxLines: 3,
              onChanged: (value) {
                setState(() {
                  _description = value;
                });
              },
            ),
            SizedBox(height: 16),
            Text('Colore del marcatore',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              children: _colorOptions.map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.all(4),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(
                        color: _selectedColor == color
                            ? Colors.black
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Duration duration = Duration(
                    hours: int.parse(_durationController.text.split(':')[0]),
                    minutes: int.parse(_durationController.text.split(':')[1]));
                Navigator.pop(context, {
                  'date': DateTime(
                      _startTime.year, _startTime.month, _startTime.day),
                  'title': _titleController.text,
                  'startTime': _startTime,
                  'color': _selectedColor,
                  'recurrence': _recurrence,
                  'recurrenceCount': int.parse(_recurrenceCountController.text),
                  'duration': duration,
                  'location': _locationController.text,
                  'description': _description,
                  'privacy': _privacy,
                  'organizer': _organizer,
                  'videocallUrl': _videocallController.text,
                });
              },
              child: Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }
}

class Appointment {
  final String title;
  final DateTime startTime;
  final Color color;
  final Duration duration;
  final String location;
  final String description;
  final String privacy;
  final String organizer;
  final String recurrence;
  final int recurrenceCount;
  final int currentRecurrence;
  final String videocallUrl;

  Appointment(this.title, this.startTime, this.color, this.duration,
      {this.location = '',
      this.description = '',
      this.privacy = 'default',
      this.organizer = '',
      this.recurrence = 'Nessuna',
      this.recurrenceCount = 1,
      this.currentRecurrence = 1,
      this.videocallUrl = ''});
}


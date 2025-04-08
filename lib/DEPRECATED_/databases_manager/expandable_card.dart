// expandable_card.dart
import 'package:flutter/material.dart';
import 'json_viewer.dart';

class ExpandableCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String dbName;
  final String collectionName;
  final Function onEdit;
  final Function onDelete;

  ExpandableCard({
    required this.item,
    required this.dbName,
    required this.collectionName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  _ExpandableCardState createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> {
  bool isExpanded = false;
  bool isSelected = false; // Stato della checkbox

  @override
  Widget build(BuildContext context) {
    return Card(
                                            color: Colors.white, // Imposta lo sfondo bianco
                                                          elevation: 6, // Intensità dell'ombra (0 = nessuna ombra)
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(4), // Angoli arrotondati
    //side: BorderSide(
    //  color: Colors.grey, // Colore dei bordi
    //  width: 0, // Spessore dei bordi
    //),
  ),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Aggiungi la checkbox a sinistra dell'ID
                    Checkbox(
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          isSelected = value ?? false;
                        });
                      },
                    ),
                    // Mostra sempre il campo _id
                    Text(
                      '_id: ${widget.item["_id"]}',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // Se espanso, mostra tutti i campi, altrimenti solo _id
                if (isExpanded)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...widget.item.entries
                          .where((entry) => entry.key != '_id')
                          .map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: JsonViewer(
                            json: {entry.key: entry.value},
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                // Aggiungi l'icona per espandere/collassare al centro in basso
                Center(
                  child: IconButton(
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onPressed: () {
                      setState(() {
                        isExpanded = !isExpanded;
                      });
                    },
                  ),
                ),
              ],
            ),
            // Icone di modifica ed eliminazione ancorate in alto a destra
            Positioned(
              right: 0,
              top: 0,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      widget.onEdit(widget.item);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      widget.onDelete(widget.item['_id']);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
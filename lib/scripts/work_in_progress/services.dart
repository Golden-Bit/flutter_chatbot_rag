import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

void main() {
  runApp(ServiceManagerApp());
}

class ServiceManagerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ServiceManagerPage(),
    );
  }
}

class ServiceManagerPage extends StatefulWidget {
  @override
  _ServiceManagerPageState createState() => _ServiceManagerPageState();
}

class _ServiceManagerPageState extends State<ServiceManagerPage> {
  List<Service> services = [];
  List<Tax> taxes = [];
  List<Label> categories = [];
  List<Label> labels = [];
  String searchQuery = '';
  String searchCategory = '';
  String searchSku = '';

  void _addOrUpdateService(Service service, {Service? existingService}) {
    setState(() {
      if (existingService != null) {
        int index = services.indexOf(existingService);
        if (index != -1) {
          services[index] = service;
        }
      } else {
        services.add(service);
      }
    });
  }

  void _removeService(Service service) {
    setState(() {
      services.remove(service);
    });
  }

  void _duplicateService(Service service) {
  final duplicatedService = Service(
    name: '${service.name} (Copia)',
    description: service.description,
    additionalDescriptions: List.from(service.additionalDescriptions),
    categories: List.from(service.categories),
    salePrice: service.salePrice,
    purchasePrice: service.purchasePrice,
    billingPolicy: service.billingPolicy,
    taxes: List.from(service.taxes),
    servicecode: service.servicecode,
    //sku: service.sku,
    attachments: List.from(service.attachments),
    //weight: service.weight,
    //dimensions: service.dimensions,
    //volume: service.volume,
    labels: List.from(service.labels),
    currency: service.currency,
    images: List.from(service.images),
    unitOfMeasure: service.unitOfMeasure,
    minQuantity: service.minQuantity,
    minIncrement: service.minIncrement,
    parts: service.parts.map((part) => ServicePart(part.service, part.quantity)).toList(),
  );
  _addOrUpdateService(duplicatedService);
}

  void _navigateToAddServicePage(BuildContext context, {Service? service}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddServicePage(
          onAddOrUpdateService: (newService) =>
              _addOrUpdateService(newService, existingService: service),
          existingService: service,
          services: services,
          categories: categories,
          labels: labels,
          taxes: taxes,
          onAddTax: _addTax,
          onAddCategory: _addCategory,
          onAddLabel: _addLabel,
        ),
      ),
    );
  }

  void _addTax(Tax tax) {
    setState(() {
      taxes.add(tax);
    });
  }

  void _addCategory(Label category) {
    setState(() {
      categories.add(category);
    });
  }

  void _addLabel(Label label) {
    setState(() {
      labels.add(label);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredServices = services
        .where((service) {
          final nameMatches = service.name.toLowerCase().contains(searchQuery.toLowerCase());
          final categoryMatches = searchCategory.isEmpty ||
              service.categories.any((category) =>
                  category.name.toLowerCase().contains(searchCategory.toLowerCase()));

          return nameMatches && categoryMatches;
        })
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestione Servizi'),
        actions: [
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('Crea Nuovo Servizio'),
            onPressed: () => _navigateToAddServicePage(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Cerca',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                  SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Cerca per categoria',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchCategory = value;
                      });
                    },
                  ),
                  SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Cerca per Codice',
                      prefixIcon: Icon(Icons.info_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchSku = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ...filteredServices.map(
                    (service) => ServiceCard(
                      service: service,
                      onRemove: () => _removeService(service),
                      onDuplicate: () => _duplicateService(service),
                      onEdit: () => _navigateToAddServicePage(context, service: service),
                    ),
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

class Service {
  final String name;
  final String? description;
  final List<AdditionalDescription> additionalDescriptions;
  final List<Label> categories;
  final double salePrice;
  final double purchasePrice;
  final String billingPolicy;
  final List<Tax> taxes;
  final String? servicecode;
  final List<String> attachments;
  final List<Label> labels;
  final List<String> images;
  String currency;
  String unitOfMeasure;
  final double minQuantity;
  final double minIncrement;
  List<ServicePart> parts;
  final String serviceType;

  Service({
    required this.name,
    this.description = 'Non compilato',
    this.additionalDescriptions = const [],
    this.categories = const [],
    this.salePrice = 0.0,
    this.purchasePrice = 0.0,
    this.billingPolicy = 'Quantità ordinate',
    this.taxes = const [],
    this.servicecode = 'Non compilato',
    this.attachments = const [],
    this.labels = const [],
    this.images = const [],
    this.currency = '€',
    this.unitOfMeasure = 'Non compilato',
    this.minQuantity = 1.0,
    this.minIncrement = 1.0,
    this.parts = const [],
    this.serviceType = 'Fisico',
  });
}



class ServicePart {
  final Service service;
  final int quantity;

  ServicePart(this.service, this.quantity);
}

class AdditionalDescription {
  String title;
  String content;

  AdditionalDescription({required this.title, required this.content});
}

class Label {
  String name;
  Color color;

  Label({required this.name, required this.color});
}

class Tax {
  String name;
  double rate;

  Tax({required this.name, required this.rate});
}

class ServiceCard extends StatefulWidget {
  final Service service;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback onEdit;

  const ServiceCard({
    required this.service,
    required this.onRemove,
    required this.onDuplicate,
    required this.onEdit,
  });

  @override
  _ServiceCardState createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard> with SingleTickerProviderStateMixin {
  bool isExpanded = false;
  List<bool> additionalDescriptionsExpanded = [];

  @override
  void initState() {
    super.initState();
    additionalDescriptionsExpanded =
        //List.filled(widget.service.additionalDescriptions.length, false);
        List.filled(100, false);
  }

void _showViewServiceDialog() {
  List<bool> additionalDescriptionsExpanded =
      //List.filled(widget.service.additionalDescriptions.length, false);
      List.filled(100, false);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: EdgeInsets.all(10),
        child: Container(
          padding: EdgeInsets.all(20),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Intestazione fissa con il nome del servizio e l'icona di chiusura
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.service.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  // Contenuto scrollabile
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailsSection(
                            'Descrizione',
                            widget.service.description != null &&
                                    widget.service.description!.isNotEmpty
                                ? HtmlWidget(widget.service.description!)
                                : Text(
                                    'Non compilato',
                                    style: TextStyle(fontWeight: FontWeight.normal),
                                  ),
                            fullWidth: true,
                          ),
                          if (widget.service.additionalDescriptions.isNotEmpty)
                            _buildMainAdditionalDescriptionsSection(
                              widget.service.additionalDescriptions,
                              additionalDescriptionsExpanded,
                              setState,
                            ),
                          _buildDetailsSection(
                            'Prezzi',
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Prezzo di acquisto',
                                        '${widget.service.purchasePrice} ${widget.service.currency}',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Prezzo di vendita',
                                        '${widget.service.salePrice} ${widget.service.currency}',
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8.0),
                                Text(
                                  'Imposte',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Wrap(
                                  alignment: WrapAlignment.start,
                                  spacing: 16.0,
                                  children: widget.service.taxes.isNotEmpty
                                      ? widget.service.taxes.map((tax) {
                                          return RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: '${tax.name}: ',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.normal,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: '${tax.rate}%',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.normal,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList()
                                      : [Text('Non compilato')],
                                ),
                              ],
                            ),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Dettagli Servizi',
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Codice Servizio',
                                        widget.service.servicecode ?? 'Non compilato',
                                      ),
                                    ),
                                    //Expanded(
                                    //  child: _buildDetailsText('SKU', widget.service.sku),
                                    //),
                                  ],
                                ),
                                Row(
                                  children: [
                                    //Expanded(
                                    //  child: _buildDetailsText('Peso', '${widget.service.weight} kg'),
                                    //),
                                    //Expanded(
                                    //  child: _buildDetailsText(
                                    //    'Dimensioni',
                                    //    widget.service.dimensions.isNotEmpty
                                    //        ? widget.service.dimensions
                                    //        : 'Non compilato',
                                    //  ),
                                    //),
                                  ],
                                ),
                                Row(
                                  children: [
                                    //Expanded(
                                    //  child: _buildDetailsText('Volume', '${widget.service.volume} m³'),
                                    //),
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Tipologia di Servizio',
                                        widget.service.serviceType,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Quantità Minima',
                                        '${widget.service.minQuantity}',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Incremento Minimo',
                                        '${widget.service.minIncrement}',
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Unità di Misura',
                                        widget.service.unitOfMeasure.isNotEmpty
                                            ? widget.service.unitOfMeasure
                                            : 'Non compilato',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Parti del Servizio',
                            widget.service.parts.isNotEmpty
                                ? _buildPartsField(widget.service.parts)
                                : Text('Non compilato'),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Categorie',
                            widget.service.categories.isNotEmpty
                                ? Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children: widget.service.categories.map((category) {
                                      return Chip(
                                        label: Text(category.name),
                                        backgroundColor: category.color,
                                      );
                                    }).toList(),
                                  )
                                : Text('Non compilato'),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Immagini del Servizio',
                            _buildImagesField(widget.service.images),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Etichette',
                            widget.service.labels.isNotEmpty
                                ? _buildLabelsField(widget.service.labels)
                                : Text('Non compilato'),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Allegati',
                            widget.service.attachments.isNotEmpty
                                ? _buildAttachmentsField(widget.service.attachments)
                                : Text('Non compilato'),
                            fullWidth: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.0),
      child: AnimatedSize(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: SizedBox(
          height: isExpanded ? null : 175,
          child: Card(
            margin: EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: widget.service.images.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _showFullScreenImage(widget.service.images.first);
                                  },
                                  child: Image.network(
                                    widget.service.images.first,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.image,
                                    size: 50,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(width: 16.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.service.name,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (!isExpanded) ...[
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Categorie: ',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(
                                      text: widget.service.categories.isNotEmpty
                                          ? widget.service.categories
                                              .map((cat) => cat.name)
                                              .join(', ')
                                          : '',
                                    ),
                                  ],
                                ),
                              ),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    //TextSpan(
                                    //  text: 'SKU: ',
                                    //  style: TextStyle(fontWeight: FontWeight.bold),
                                    //),
                                    //TextSpan(
                                    //  text: widget.service.sku,
                                    //),
                                    TextSpan(
                                      text: 'Prezzo: ',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(
                                      text: '${widget.service.salePrice} ${widget.service.currency}',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
PopupMenuButton<String>(
  onSelected: (value) {
    if (value == 'elimina') {
      widget.onRemove();
    } else if (value == 'duplica') {
      widget.onDuplicate();
    } else if (value == 'modifica') {
      widget.onEdit();
    } else if (value == 'visualizza') {  // Nuova opzione "Visualizza"
      _showViewServiceDialog();
    }
  },
  itemBuilder: (BuildContext context) {
    return [
      PopupMenuItem<String>(
        value: 'visualizza',  // Nuova opzione "Visualizza"
        child: Text('Visualizza'),
      ),
      PopupMenuItem<String>(
        value: 'elimina',
        child: Text('Elimina'),
      ),
      PopupMenuItem<String>(
        value: 'duplica',
        child: Text('Duplica'),
      ),
      PopupMenuItem<String>(
        value: 'modifica',
        child: Text('Modifica'),
      ),
    ];
  },
)
                    ],
                  ),
                  if (isExpanded)
                    Column(
                      children: [
                        _buildDetailsSection(
                          'Descrizione',
                          Container(
                            width: double.infinity,
                            child: widget.service.description != null
                                ? HtmlWidget(widget.service.description!)
                                : Text(
                                    'Non compilato',
                                    style: TextStyle(fontWeight: FontWeight.normal),
                                  ),
                          ),
                          fullWidth: true,
                        ),
if (widget.service.additionalDescriptions.isNotEmpty)
  _buildMainAdditionalDescriptionsSection(
    widget.service.additionalDescriptions,  // Lista delle descrizioni addizionali
    additionalDescriptionsExpanded,         // Stato di espansione delle descrizioni nel dialogo
    setState,                               // Funzione per aggiornare lo stato nel dialogo
  ),
                        _buildDetailsSection(
                          'Prezzi',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailsText(
                                        'Prezzo di acquisto',
                                        '${widget.service.purchasePrice} ${widget.service.currency}'),
                                  ),
                                  Expanded(
                                    child: _buildDetailsText(
                                        'Prezzo di vendita',
                                        '${widget.service.salePrice} ${widget.service.currency}'),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8.0),
                              Text(
                                'Imposte',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Wrap(
                                alignment: WrapAlignment.start,
                                spacing: 16.0,
                                children: widget.service.taxes.isNotEmpty
                                    ? widget.service.taxes.map((tax) {
                                        return RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: '${tax.name}: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.normal,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              TextSpan(
                                                text: '${tax.rate}%',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.normal,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList()
                                    : [Text('Non compilato')],
                              ),
                            ],
                          ),
                        ),
                        _buildDetailsSection(
                          'Dettagli Servizi',
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailsText(
                                        'Codice Servizio',
                                        widget.service.servicecode ?? 'Non compilato'),
                                  ),
                                  //Expanded(
                                  //  child: _buildDetailsText('SKU', widget.service.sku),
                                  //),
                                ],
                              ),
                              Row(
                                children: [
                                  //Expanded(
                                  //  child: _buildDetailsText(
                                  //      'Peso', '${widget.service.weight} kg'),
                                  //),
                                  //Expanded(
                                  //  child: _buildDetailsText(
                                  //      'Dimensioni',
                                  //      widget.service.dimensions ?? 'Non compilato'),
                                  //),
                                ],
                              ),
                              Row(
                                children: [
                                  //Expanded(
                                  //  child: _buildDetailsText(
                                  //      'Volume', '${widget.service.volume} m³'),
                                  //),
                                  /*Expanded(
                                    child: _buildDetailsText(
                                        'Traccia Magazzino',
                                        widget.service.trackInventory ? 'Sì' : 'No'),
                                  ),*/
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailsText(
                                        'Tipologia di Servizio', widget.service.serviceType),
                                  ),
                                  Expanded(
                                    child: _buildDetailsText(
                                        'Quantità Minima', '${widget.service.minQuantity}'),
                                  ),
                                  Expanded(
                                    child: _buildDetailsText('Incremento Minimo',
                                        '${widget.service.minIncrement}'),
                                  ),
                                  Expanded(
                                    child: _buildDetailsText(
                                        'Unità di Misura', widget.service.unitOfMeasure),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildDetailsSection(
                          'Parti del Servizio',
                          _buildPartsField(widget.service.parts),
                          fullWidth: true,
                        ),
                                                _buildDetailsSection(
                          'Categorie',
                          widget.service.categories.isNotEmpty
                              ? Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  children: widget.service.categories.map((category) {
                                    return Chip(
                                      label: Text(category.name),
                                      backgroundColor: category.color,
                                    );
                                  }).toList(),
                                )
                              : SizedBox.shrink(),
                          fullWidth: true,
                        ),
                        _buildDetailsSection(
                          'Immagini del Servizio',
                          _buildImagesField(widget.service.images),
                          fullWidth: true,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 0.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLabeledSection(
                                'Etichette',
                                widget.service.labels.isNotEmpty
                                    ? _buildLabelsField(widget.service.labels)
                                    : SizedBox.shrink(),
                              ),
                              SizedBox(height: 8.0),
                              _buildLabeledSection(
                                'Allegati',
                                _buildAttachmentsField(widget.service.attachments),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  Align(
                    alignment: Alignment.center,
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
            ),
          ),
        ),
      ),
    );
  }

Widget _buildMainAdditionalDescriptionsSection(
    List<AdditionalDescription> descriptions,
    List<bool> additionalDescriptionsExpanded,
    Function(void Function()) setState) {
  return _buildDetailsSection(
    'Descrizioni Addizionali',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: descriptions.asMap().entries.map((entry) {
        int index = entry.key;
        AdditionalDescription desc = entry.value;
        return _buildDetailsSection(
          desc.title,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (additionalDescriptionsExpanded[index])
                HtmlWidget(desc.content),
              Align(
                alignment: Alignment.bottomRight,
                child: IconButton(
                  icon: Icon(additionalDescriptionsExpanded[index]
                      ? Icons.expand_less
                      : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      additionalDescriptionsExpanded[index] =
                          !additionalDescriptionsExpanded[index];
                    });
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
    fullWidth: true,
  );
}

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImagePage(imageUrl: imageUrl),
      ),
    );
  }

  Widget _buildDetailsSection(String title, Widget content, {bool fullWidth = false}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      width: fullWidth ? double.infinity : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          content,
        ],
      ),
    );
  }

  Widget _buildLabeledSection(String title, Widget content) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          content,
        ],
      ),
    );
  }

  Widget _buildDetailsText(String title, String? content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(content?.isNotEmpty == true ? content! : 'Non compilato'),
        ],
      ),
    );
  }

  Widget _buildAttachmentsField(List<String> attachments) {
    if (attachments.isEmpty) return Text('Non compilato');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: attachments.map((fileName) {
          return Chip(
            label: Text(fileName),
            onDeleted: null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLabelsField(List<Label> labels) {
    if (labels.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: labels.map((label) {
          return Chip(
            label: Text(label.name),
            backgroundColor: label.color,
            onDeleted: null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImagesField(List<String> images) {
    if (images.isEmpty)
      return Container(
        color: Colors.grey.shade200,
        height: 256,
        child: Center(
          child: Icon(
            Icons.image,
            size: 50,
            color: Colors.grey.shade500,
          ),
        ),
      );
    return Container(
      height: 256,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              _showFullScreenImage(images[index]);
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  images[index],
                  width: 256,
                  height: 256,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

Widget _buildPartsField(List<ServicePart> parts) {
  return Wrap(
    spacing: 8.0,
    runSpacing: 8.0,
    children: parts.map((part) {
      return GestureDetector(
        onTap: () {
          _showServiceDialog(part.service); // Apre il dialog del servizio
        },
        child: Chip(
          label: Text('${part.quantity}x ${part.service.servicecode}'),
          onDeleted: null,
          /*onDeleted: () {
            setState(() {
              parts.remove(part);
            });
          },*/
        ),
      );
    }).toList(),
  );
}

void _showServiceDialog(Service service) {

  List<bool> additionalDescriptionsExpanded = 
      List.filled(service.additionalDescriptions.length, false);

  // Copia della logica di _showViewServiceDialog adattata per un servizio specifico
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: EdgeInsets.all(10),
        child: Container(
          padding: EdgeInsets.all(20),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Intestazione fissa con il nome del servizio e l'icona di chiusura
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        service.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  // Contenuto scrollabile
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailsSection(
                            'Descrizione',
                            service.description != null &&
                                    service.description!.isNotEmpty
                                ? HtmlWidget(service.description!)
                                : Text(
                                    'Non compilato',
                                    style: TextStyle(fontWeight: FontWeight.normal),
                                  ),
                            fullWidth: true,
                          ),
                          if (service.additionalDescriptions.isNotEmpty)
                            _buildMainAdditionalDescriptionsSection(
                              service.additionalDescriptions,
                              additionalDescriptionsExpanded,
                              setState,
                            ),
                          _buildDetailsSection(
                            'Prezzi',
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Prezzo di acquisto',
                                        '${service.purchasePrice} ${service.currency}',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Prezzo di vendita',
                                        '${service.salePrice} ${service.currency}',
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8.0),
                                Text(
                                  'Imposte',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Wrap(
                                  alignment: WrapAlignment.start,
                                  spacing: 16.0,
                                  children: service.taxes.isNotEmpty
                                      ? service.taxes.map((tax) {
                                          return RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: '${tax.name}: ',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.normal,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: '${tax.rate}%',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.normal,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList()
                                      : [Text('Non compilato')],
                                ),
                              ],
                            ),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Dettagli Servizi',
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Codice Servizio',
                                        service.servicecode ?? 'Non compilato',
                                      ),
                                    ),
                                    //Expanded(
                                    //  child: _buildDetailsText('SKU', service.sku),
                                    //),
                                  ],
                                ),
                                Row(
                                  children: [
                                    //Expanded(
                                    //  child: _buildDetailsText('Peso', '${service.weight} kg'),
                                    //),
                                    //Expanded(
                                    //  child: _buildDetailsText(
                                    //    'Dimensioni',
                                    //    service.dimensions.isNotEmpty
                                    //        ? service.dimensions
                                    //        : 'Non compilato',
                                    //  ),
                                    //),
                                  ],
                                ),
                                Row(
                                  children: [
                                    //Expanded(
                                    //  child: _buildDetailsText('Volume', '${service.volume} m³'),
                                    //),
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Tipologia di Servizio',
                                        service.serviceType,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Quantità Minima',
                                        '${service.minQuantity}',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Incremento Minimo',
                                        '${service.minIncrement}',
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Unità di Misura',
                                        service.unitOfMeasure.isNotEmpty
                                            ? service.unitOfMeasure
                                            : 'Non compilato',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Parti del Servizio',
                            service.parts.isNotEmpty
                                ? _buildPartsField(service.parts)
                                : Text('Non compilato'),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Categorie',
                            service.categories.isNotEmpty
                                ? Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children: service.categories.map((category) {
                                      return Chip(
                                        label: Text(category.name),
                                        backgroundColor: category.color,
                                      );
                                    }).toList(),
                                  )
                                : Text('Non compilato'),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Immagini del Servizio',
                            _buildImagesField(service.images),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Etichette',
                            service.labels.isNotEmpty
                                ? _buildLabelsField(service.labels)
                                : Text('Non compilato'),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Allegati',
                            service.attachments.isNotEmpty
                                ? _buildAttachmentsField(service.attachments)
                                : Text('Non compilato'),
                            fullWidth: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

  void _openPartsDialog() async {
    final selectedParts = await showDialog<List<ServicePart>>(
      context: context,
      builder: (context) {
        return PartsSelectionDialog(
          allServices: widget.service.parts.map((p) => p.service).toList(),
          selectedParts: widget.service.parts,
        );
      },
    );

    if (selectedParts != null) {
      setState(() {
        widget.service.parts = selectedParts;
      });
    }
  }
}

class PartsSelectionDialog extends StatefulWidget {
  final List<Service> allServices;
  final List<ServicePart> selectedParts;

  PartsSelectionDialog({
    required this.allServices,
    required this.selectedParts,
  });

  @override
  _PartsSelectionDialogState createState() => _PartsSelectionDialogState();
}

class _PartsSelectionDialogState extends State<PartsSelectionDialog> {
  late List<Service> filteredServices;
  late List<ServicePart> selectedParts;
  String searchQuery = '';
  String searchCategory = '';
  String searchSku = '';

  @override
  void initState() {
    super.initState();
    filteredServices = widget.allServices;
    selectedParts = List.from(widget.selectedParts);
  }

  void _filterServices() {
    setState(() {
      filteredServices = widget.allServices
          .where((service) =>
              service.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              service.servicecode!.toLowerCase().contains(searchSku.toLowerCase()))
          .toList();
    });
  }

  void _updatePartQuantity(Service service, int newQuantity) {
    final partIndex = selectedParts.indexWhere((part) => part.service == service);
    if (partIndex >= 0) {
      setState(() {
        selectedParts[partIndex] = ServicePart(service, newQuantity);
      });
    } else {
      setState(() {
        selectedParts.add(ServicePart(service, newQuantity));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Seleziona Parti del Servizio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: 'Cerca Servizio',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value;
                _filterServices();
              });
            },
          ),
          SizedBox(height: 8.0),
          Expanded(
            child: ListView.builder(
              itemCount: filteredServices.length,
              itemBuilder: (context, index) {
                final service = filteredServices[index];
                final part = selectedParts.firstWhere(
                  (part) => part.service == service,
                  orElse: () => ServicePart(service, 0),
                );

                return ListTile(
                  title: Text(service.name),
                  subtitle: Text('Codice: ${service.servicecode}'),
                  trailing: Container(
                    width: 100,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(
                              text: part.quantity > 0 ? part.quantity.toString() : '',
                            ),
                            decoration: InputDecoration(labelText: 'Quantità'),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              final newQuantity = int.tryParse(value) ?? 0;
                              _updatePartQuantity(service, newQuantity);
                            },
                          ),
                        ),
                        Checkbox(
                          value: part.quantity > 0,
                          onChanged: (value) {
                            if (value == true) {
                              _updatePartQuantity(service, 1);
                            } else {
                              _updatePartQuantity(service, 0);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(selectedParts);
          },
          child: Text('Salva'),
        ),
      ],
    );
  }
}

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  FullScreenImagePage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 3.0,
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}

class AddServicePage extends StatefulWidget {
  final Function(Service) onAddOrUpdateService;
  final Service? existingService;
  final List<Label> categories;
  final List<Label> labels;
  final List<Tax> taxes;
  final Function(Tax) onAddTax;
  final Function(Label) onAddCategory;
  final Function(Label) onAddLabel;
  final List<Service> services;

  AddServicePage({
    required this.onAddOrUpdateService,
    this.existingService,
    required this.categories,
    required this.labels,
    required this.taxes,
    required this.onAddTax,
    required this.onAddCategory,
    required this.onAddLabel,
    required this.services,
  });

  @override
  _AddServicePageState createState() => _AddServicePageState();
}

class _AddServicePageState extends State<AddServicePage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController salePriceController = TextEditingController();
  TextEditingController purchasePriceController = TextEditingController();
  TextEditingController servicecodeController = TextEditingController();
  TextEditingController skuController = TextEditingController();
  TextEditingController weightController = TextEditingController();
  TextEditingController dimensionsController = TextEditingController();
  TextEditingController volumeController = TextEditingController();
  TextEditingController minQuantityController = TextEditingController();
  TextEditingController minIncrementController = TextEditingController();

  List<String> attachments = [];
  List<Label> selectedCategories = [];
  List<Label> selectedLabels = [];
  List<Tax> addedTaxes = [];
  List<TextEditingController> taxNameControllers = [];
  List<TextEditingController> taxRateControllers = [];
  List<AdditionalDescription> additionalDescriptions = [];
  List<String> images = [];
  String? billingPolicy = 'Quantità ordinate';
  bool trackInventory = false;
  String currency = '€';
  String selectedUnitOfMeasure = 'Unità';
  List<ServicePart> selectedParts = [];
  List<bool> additionalDescriptionsExpanded = List.filled(100, false);
  //[];
  String selectedServiceType = 'Fisico';

  // Aggiungi una lista di controller per le descrizioni addizionali
  List<TextEditingController> additionalDescriptionTitleControllers = [];
  List<TextEditingController> additionalDescriptionControllers = [];

void initState() {
  super.initState();
  if (widget.existingService != null) {
    final service = widget.existingService!;

    // Inizializza i controller per le tasse esistenti
    addedTaxes = service.taxes.map((tax) => Tax(name: tax.name, rate: tax.rate)).toList(); // Deep copy
    taxNameControllers = List.generate(addedTaxes.length, (index) => TextEditingController(text: addedTaxes[index].name));
    taxRateControllers = List.generate(addedTaxes.length, (index) => TextEditingController(text: addedTaxes[index].rate.toString()));
    

    nameController.text = service.name;
    descriptionController.text = service.description ?? 'Non compilato';
    salePriceController.text = service.salePrice.toString();
    purchasePriceController.text = service.purchasePrice.toString();
    servicecodeController.text = service.servicecode ?? 'Non compilato';
    attachments = service.attachments.map((attachment) => attachment).toList(); // Deep copy
    selectedCategories = service.categories.map((category) => Label(name: category.name, color: category.color)).toList(); // Deep copy
    selectedLabels = service.labels.map((label) => Label(name: label.name, color: label.color)).toList(); // Deep copy
    addedTaxes = service.taxes.map((tax) => Tax(name: tax.name, rate: tax.rate)).toList(); // Deep copy
    billingPolicy = service.billingPolicy;
    currency = service.currency;
    selectedUnitOfMeasure = service.unitOfMeasure;
    additionalDescriptions = service.additionalDescriptions.map((desc) => AdditionalDescription(title: desc.title, content: desc.content)).toList(); // Deep copy
    images = service.images.map((image) => image).toList(); // Deep copy
    minQuantityController.text = service.minQuantity.toString();
    minIncrementController.text = service.minIncrement.toString();
    selectedParts = service.parts.map((part) => ServicePart(part.service, part.quantity)).toList(); // Deep copy
    selectedServiceType = service.serviceType;

    // Inizializza i controller per i titoli e i contenuti delle descrizioni addizionali
    additionalDescriptionTitleControllers = List.generate(additionalDescriptions.length, (index) {
        return TextEditingController(text: additionalDescriptions[index].title);
      });
    additionalDescriptionControllers = List.generate(additionalDescriptions.length, (index) {
      return TextEditingController(text: additionalDescriptions[index].content);
    });

    // Inizializza additionalDescriptionsExpanded
    additionalDescriptionsExpanded = List.filled(additionalDescriptions.length, false);
  }
}

  Future<void> _selectAttachments() async {
    html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '*/*';
    uploadInput.multiple = true;
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        for (var file in files) {
          final reader = html.FileReader();
          reader.readAsDataUrl(file);
          reader.onLoadEnd.listen((e) {
            setState(() {
              attachments.add(file.name);
            });
          });
        }
      }
    });
  }

  Future<void> _selectImages() async {
    html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.multiple = true;
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        for (var file in files) {
          final reader = html.FileReader();
          reader.readAsDataUrl(file);
          reader.onLoadEnd.listen((e) {
            setState(() {
              images.add(reader.result as String);
            });
          });
        }
      }
    });
  }

   void _saveService() {
    final service = Service(
      name: nameController.text.isNotEmpty ? nameController.text : 'Nome servizio non compilato',
      description: descriptionController.text.isNotEmpty
          ? descriptionController.text
          : 'Non compilato',
      additionalDescriptions: additionalDescriptions,
      categories: selectedCategories,
      labels: selectedLabels,
      salePrice: double.tryParse(salePriceController.text) ?? 0.0,
      purchasePrice: double.tryParse(purchasePriceController.text) ?? 0.0,
      billingPolicy: billingPolicy ?? 'Quantità ordinate',
      taxes: addedTaxes.isNotEmpty
          ? addedTaxes
          : [Tax(name: 'Non compilato', rate: 0.0)],
      servicecode: servicecodeController.text.isNotEmpty ? servicecodeController.text : 'Non compilato',
      attachments: attachments,
      images: images,
      currency: currency,
      unitOfMeasure: selectedUnitOfMeasure.isNotEmpty
          ? selectedUnitOfMeasure
          : 'Non compilato',
      minQuantity: double.tryParse(minQuantityController.text) ?? 1.0,
      minIncrement: double.tryParse(minIncrementController.text) ?? 1.0,
      parts: selectedParts,
      serviceType: selectedServiceType,
    );

    widget.onAddOrUpdateService(service);
    Navigator.of(context).pop();
  }


  void _addNewTaxField() {
    setState(() {
      addedTaxes.add(Tax(name: '', rate: 0.0));
      taxNameControllers.add(TextEditingController());
      taxRateControllers.add(TextEditingController());
    });
  }

  void _removeTaxField(int index) {
    setState(() {
      addedTaxes.removeAt(index);
      taxNameControllers.removeAt(index);
      taxRateControllers.removeAt(index);
    });
  }

  void _addNewCategory() {
    final TextEditingController categoryController = TextEditingController();
    Color categoryColor = Colors.transparent;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Aggiungi Nuova Categoria'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: categoryController,
                    decoration: InputDecoration(labelText: 'Nome Categoria'),
                  ),
                  Row(
                    children: [
                      Text('Seleziona Colore:'),
                      SizedBox(width: 10),
                      ...Colors.primaries.map((color) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              categoryColor = color;
                            });
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 5.0),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: categoryColor == color
                                  ? Border.all(width: 2.0, color: Colors.black)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    final label = Label(
                      name: categoryController.text,
                      color: categoryColor,
                    );
                    widget.onAddCategory(label);
                    Navigator.of(context).pop();
                  },
                  child: Text('Aggiungi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addNewLabel() {
    final TextEditingController labelController = TextEditingController();
    Color labelColor = Colors.transparent;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Aggiungi Nuova Etichetta'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelController,
                    decoration: InputDecoration(labelText: 'Nome Etichetta'),
                  ),
                  Row(
                    children: [
                      Text('Seleziona Colore:'),
                      SizedBox(width: 10),
                      ...Colors.primaries.map((color) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              labelColor = color;
                            });
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 5.0),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: labelColor == color
                                  ? Border.all(width: 2.0, color: Colors.black)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    final label = Label(
                      name: labelController.text,
                      color: labelColor,
                    );
                    widget.onAddLabel(label);
                    Navigator.of(context).pop();
                  },
                  child: Text('Aggiungi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

void _addNewAdditionalDescription() {
  setState(() {
    additionalDescriptions = List.of(additionalDescriptions.map((desc) => AdditionalDescription(title: desc.title, content: desc.content)).toList()); // Assicura la mutabilità con deep copy
    additionalDescriptions.add(AdditionalDescription(title: '', content: ''));
    additionalDescriptionTitleControllers.add(TextEditingController());
    additionalDescriptionControllers.add(TextEditingController());
    additionalDescriptionsExpanded = List.of(additionalDescriptionsExpanded); // Assicura la mutabilità
    additionalDescriptionsExpanded.add(false);
  });
}


void _removeAdditionalDescription(int index) {
  setState(() {
    additionalDescriptions = List.of(additionalDescriptions.map((desc) => AdditionalDescription(title: desc.title, content: desc.content)).toList()); // Assicura la mutabilità con deep copy
    additionalDescriptions.removeAt(index);
    additionalDescriptionsExpanded = List.of(additionalDescriptionsExpanded); // Assicura la mutabilità
    additionalDescriptionsExpanded.removeAt(index);
  });
}

  void _showLabelMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(Offset.zero, ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      items: widget.labels.map((Label label) {
        return PopupMenuItem<Label>(
          value: label,
          child: ListTile(
            title: Text(label.name),
            leading: CircleAvatar(
              backgroundColor: label.color,
            ),
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        setState(() {
          selectedLabels.add(value);
        });
      }
    });
  }

  void _showCategoryMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(Offset.zero, ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      items: widget.categories.map((Label category) {
        return PopupMenuItem<Label>(
          value: category,
          child: ListTile(
            title: Text(category.name),
            leading: CircleAvatar(
              backgroundColor: category.color,
            ),
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        setState(() {
          selectedCategories.add(value);
        });
      }
    });
  }

  Widget _buildInputField({required String title, required Widget content}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      padding: EdgeInsets.all(12.0),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildAdditionalDescriptions() {
    return Column(
      children: additionalDescriptions.asMap().entries.map((entry) {
        final index = entry.key;
        final desc = entry.value;
        final titleController = additionalDescriptionTitleControllers[index];
        final contentController = additionalDescriptionControllers[index];
        
        return Stack(
          key: ValueKey(desc),
          children: [
            _buildInputField(
              title: 'Descrizione Addizionale ${index + 1}',
              content: Column(
                children: [
                  TextField(
                    controller: titleController,
                    onChanged: (value) {
                      setState(() {
                        desc.title = value;
                      });
                    },
                    decoration: InputDecoration(labelText: 'Titolo'),
                  ),
                  SizedBox(height: 8.0),
                  TextField(
                    controller: contentController,
                    onChanged: (value) {
                      setState(() {
                        desc.content = value;
                      });
                    },
                    decoration: InputDecoration(labelText: 'Contenuto'),
                    maxLines: 6,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    additionalDescriptions.removeAt(index);
                    additionalDescriptionTitleControllers.removeAt(index);
                    additionalDescriptionControllers.removeAt(index);
                  });
                },
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTaxFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...addedTaxes.asMap().entries.map((entry) {
          final index = entry.key;
          final tax = entry.value;

          // Imposta il testo dei controller se non è già stato impostato
          if (taxNameControllers[index].text.isEmpty) {
            taxNameControllers[index].text = tax.name;
          }
          if (taxRateControllers[index].text.isEmpty) {
            taxRateControllers[index].text = tax.rate.toString();
          }

          return Row(
            children: [
              Expanded(
                child: TextField(
                  controller: taxNameControllers[index],
                  onChanged: (value) {
                    setState(() {
                      tax.name = value;
                    });
                  },
                  decoration: InputDecoration(labelText: 'Nome Imposta'),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: taxRateControllers[index],
                  onChanged: (value) {
                    setState(() {
                      tax.rate = double.tryParse(value) ?? 0.0;
                    });
                  },
                  decoration: InputDecoration(labelText: 'Tasso (%)'),
                  keyboardType: TextInputType.number,
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeTaxField(index),
              ),
            ],
          );
        }).toList(),
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _addNewTaxField,
              child: Text('+ Aggiungi Imposta'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitOfMeasureField() {
    return DropdownButtonFormField<String>(
      value: selectedUnitOfMeasure,
      onChanged: (String? newValue) {
        setState(() {
          selectedUnitOfMeasure = newValue!;
        });
      },
      items: <String>['Unità', 'kg', 'litri', 'pezzi', 'metri']
          .map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      decoration: InputDecoration(
        labelText: 'Unità di Misura',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingService != null
            ? 'Modifica Servizio'
            : 'Aggiungi Servizio'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Nome Servizio'),
              ),
              SizedBox(height: 16.0),
              _buildInputField(
                title: 'Descrizione e Descrizioni Addizionali',
                content: Column(
                  children: [
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(labelText: 'Descrizione'),
                      maxLines: 6,
                    ),
                    SizedBox(height: 8.0),
                    _buildAdditionalDescriptions(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _addNewAdditionalDescription,
                        child: Text('+ Aggiungi Descrizione Addizionale'),
                      ),
                    ),
                  ],
                ),
              ),
              _buildInputField(
                title: 'Categorie',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedCategories.isEmpty)
                      Text('Non compilato')
                    else
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: selectedCategories.map((category) {
                          return Chip(
                            label: Text(category.name),
                            backgroundColor: category.color,
                            onDeleted: () {
                              setState(() {
                                selectedCategories.remove(category);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.add, color: Colors.black),
                          onPressed: _addNewCategory,
                        ),
                        Builder(
                          builder: (context) => IconButton(
                            icon: Icon(Icons.category, color: Colors.black),
                            onPressed: () => _showCategoryMenu(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildInputField(
                title: 'Prezzi',
                content: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: salePriceController,
                            decoration: InputDecoration(labelText: 'Prezzo di Vendita'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: purchasePriceController,
                            decoration: InputDecoration(labelText: 'Prezzo di Acquisto'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        DropdownButton<String>(
                          value: currency,
                          onChanged: (String? newValue) {
                            setState(() {
                              currency = newValue!;
                            });
                          },
                          items: <String>['€', '\$']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          underline: Container(),
                        ),
                      ],
                    ),
                    _buildTaxFields(),
                  ],
                ),
              ),
              _buildInputField(
                title: 'Dettagli Servizi',
                content: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: servicecodeController,
                            decoration: InputDecoration(labelText: 'Codice Servizio'),
                          ),
                        ),
                        SizedBox(width: 16),
                        //Expanded(
                        //  child: TextField(
                        //    controller: skuController,
                        //    decoration: InputDecoration(labelText: 'SKU'),
                        //  ),
                        //),
                      ],
                    ),
                    /*Row(
                      children: [
                        Checkbox(
                          value: trackInventory,
                          onChanged: (value) {
                            setState(() {
                              trackInventory = value!;
                            });
                          },
                        ),
                        Text('Traccia Magazzino'),
                        SizedBox(width: 16),
                        DropdownButton<String>(
                          value: billingPolicy,
                          onChanged: (String? newValue) {
                            setState(() {
                              billingPolicy = newValue!;
                            });
                          },
                          items: <String>[
                            'Quantità ordinate',
                            'Quantità consegnate'
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ],
                    ),*/
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedServiceType,
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedServiceType = newValue!;
                              });
                            },
                            items: <String>['Fisico', 'Digitale']
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            decoration: InputDecoration(
                              labelText: 'Tipologia di Servizio',
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: minQuantityController,
                            decoration: InputDecoration(labelText: 'Quantità Minima'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: minIncrementController,
                            decoration: InputDecoration(labelText: 'Incremento Minimo'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildUnitOfMeasureField(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildInputField(
                title: 'Parti del Servizio',
                content: _buildPartsField(selectedParts),
              ),
              /*_buildInputField(
                title: 'Informazioni di Spedizione',
                content: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: weightController,
                            decoration: InputDecoration(labelText: 'Peso (kg)'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: dimensionsController,
                            decoration: InputDecoration(labelText: 'Dimensioni (LxPxH)'),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: volumeController,
                      decoration: InputDecoration(labelText: 'Volume (m³)'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),*/
              _buildInputField(
                title: 'Allegati',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: attachments.map((fileName) {
                        return Chip(
                          label: Text(fileName),
                          onDeleted: () {
                            setState(() {
                              attachments.remove(fileName);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: Icon(Icons.attach_file),
                        onPressed: _selectAttachments,
                      ),
                    ),
                  ],
                ),
              ),
              _buildInputField(
                title: "Etichette",
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedLabels.isEmpty)
                      Text('Non compilato')
                    else
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        alignment: WrapAlignment.start,
                        children: selectedLabels.map((label) {
                          return Chip(
                            label: Text(
                              label.name,
                              style: TextStyle(color: Colors.black87),
                            ),
                            backgroundColor: label.color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            onDeleted: () {
                              setState(() {
                                selectedLabels.remove(label);
                              });
                            },
                            deleteIconColor: Colors.black,
                          );
                        }).toList(),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.add, color: Colors.black),
                          onPressed: _addNewLabel,
                        ),
                        Builder(
                          builder: (context) => IconButton(
                            icon: Icon(Icons.label, color: Colors.black),
                            onPressed: () => _showLabelMenu(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildInputField(
                title: "Immagini del Servizio",
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (images.isEmpty)
                      Container(
                        color: Colors.grey.shade200,
                        height: 256,
                        child: Center(
                          child: Icon(
                            Icons.image,
                            size: 50,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 256,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.network(
                                      images[index],
                                      width: 256,
                                      height: 256,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        images.removeAt(index);
                                      });
                                    },
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.red,
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: Icon(Icons.add_photo_alternate),
                        onPressed: _selectImages,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: _saveService,
                    child: Text(widget.existingService != null
                        ? 'Salva Modifiche'
                        : 'Salva Servizio'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartsField(List<ServicePart> parts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parts.isEmpty)
          Text('Non compilato')
        else
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: parts.map((part) {
              return Chip(
                label: Text('${part.quantity}x ${part.service.servicecode}'),
                onDeleted: () {
                  setState(() {
                    parts.remove(part);
                  });
                },
              );
            }).toList(),
          ),
        Align(
          alignment: Alignment.bottomRight,
          child: IconButton(
            icon: Icon(Icons.add),
            onPressed: _openPartsDialog,
          ),
        ),
      ],
    );
  }

  void _openPartsDialog() async {
    final selectedParts = await showDialog<List<ServicePart>>(
      context: context,
      builder: (context) {
        return ServicePartsSelectionDialog(
          allServices: widget.services,
          selectedParts: this.selectedParts,
        );
      },
    );

    if (selectedParts != null) {
      setState(() {
        this.selectedParts = selectedParts;
      });
    }
  }
}

class ServicePartsSelectionDialog extends StatefulWidget {
  final List<Service> allServices;
  final List<ServicePart> selectedParts;

  ServicePartsSelectionDialog({
    required this.allServices,
    required this.selectedParts,
  });

  @override
  _ServicePartsSelectionDialogState createState() =>
      _ServicePartsSelectionDialogState();
}

class _ServicePartsSelectionDialogState
    extends State<ServicePartsSelectionDialog> {
  late List<Service> filteredServices;
  late List<ServicePart> selectedParts;
  String searchQuery = '';
  String searchCategory = '';
  String searchSku = '';

  @override
  void initState() {
    super.initState();
    filteredServices = widget.allServices;
    selectedParts = List.from(widget.selectedParts);
  }

  void _filterServices() {
    setState(() {
      filteredServices = widget.allServices
          .where((service) {
            final nameMatches =
                service.name.toLowerCase().contains(searchQuery.toLowerCase());
            final categoryMatches = searchCategory.isEmpty ||
                service.categories.any((category) =>
                    category.name.toLowerCase().contains(searchCategory.toLowerCase()));
            final skuMatches =
                service.servicecode!.toLowerCase().contains(searchSku.toLowerCase());

            return nameMatches && categoryMatches && skuMatches;
          })
          .toList();
    });
  }

  void _updatePartQuantity(Service service, int newQuantity) {
    final partIndex =
        selectedParts.indexWhere((part) => part.service == service);
    if (partIndex >= 0) {
      setState(() {
        selectedParts[partIndex] = ServicePart(service, newQuantity);
      });
    } else {
      setState(() {
        selectedParts.add(ServicePart(service, newQuantity));
      });
    }
  }

  void _showServiceDialog(Service service) {

    List<bool> additionalDescriptionsExpanded = 
        List.filled(service.additionalDescriptions.length, false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.all(10),
          child: Container(
            padding: EdgeInsets.all(20),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          service.name,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailsSection(
                              'Descrizione',
                              service.description != null &&
                                      service.description!.isNotEmpty
                                  ? HtmlWidget(service.description!)
                                  : Text(
                                      'Non compilato',
                                      style:
                                          TextStyle(fontWeight: FontWeight.normal),
                                    ),
                              fullWidth: true,
                            ),
                            if (service.additionalDescriptions.isNotEmpty)
                              _buildMainAdditionalDescriptionsSection(
                                service.additionalDescriptions,
                                additionalDescriptionsExpanded,
                                setState,
                              ),
                            _buildDetailsSection(
                              'Prezzi',
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDetailsText(
                                          'Prezzo di acquisto',
                                          '${service.purchasePrice} ${service.currency}',
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildDetailsText(
                                          'Prezzo di vendita',
                                          '${service.salePrice} ${service.currency}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.0),
                                  Text(
                                    'Imposte',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Wrap(
                                    alignment: WrapAlignment.start,
                                    spacing: 16.0,
                                    children: service.taxes.isNotEmpty
                                        ? service.taxes.map((tax) {
                                            return RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: '${tax.name}: ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: '${tax.rate}%',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList()
                                        : [Text('Non compilato')],
                                  ),
                                ],
                              ),
                              fullWidth: true,
                            ),
                            _buildDetailsSection(
                              'Dettagli Servizi',
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDetailsText(
                                          'Codice Servizio',
                                          service.servicecode ?? 'Non compilato',
                                        ),
                                      ),
                                      //Expanded(
                                      //  child: _buildDetailsText('SKU', service.sku),
                                      //),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      //Expanded(
                                      //  child: _buildDetailsText(
                                      //      'Peso', '${service.weight} kg'),
                                      //),
                                      //Expanded(
                                      //  child: _buildDetailsText(
                                      //    'Dimensioni',
                                      //    service.dimensions.isNotEmpty
                                      //        ? service.dimensions
                                      //        : 'Non compilato',
                                      //  ),
                                      //),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      //Expanded(
                                      //  child: _buildDetailsText(
                                      //      'Volume', '${service.volume} m³'),
                                      //),
                                      Expanded(
                                        child: _buildDetailsText(
                                          'Tipologia di Servizio',
                                          service.serviceType,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDetailsText(
                                          'Quantità Minima',
                                          '${service.minQuantity}',
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildDetailsText(
                                          'Incremento Minimo',
                                          '${service.minIncrement}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDetailsText(
                                          'Unità di Misura',
                                          service.unitOfMeasure.isNotEmpty
                                              ? service.unitOfMeasure
                                              : 'Non compilato',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              fullWidth: true,
                            ),
                            _buildDetailsSection(
                              'Parti del Servizio',
                              service.parts.isNotEmpty
                                  ? _buildPartsField(service.parts)
                                  : Text('Non compilato'),
                              fullWidth: true,
                            ),
                            _buildDetailsSection(
                              'Categorie',
                              service.categories.isNotEmpty
                                  ? Wrap(
                                      spacing: 8.0,
                                      runSpacing: 8.0,
                                      children: service.categories.map((category) {
                                        return Chip(
                                          label: Text(category.name),
                                          backgroundColor: category.color,
                                        );
                                      }).toList(),
                                    )
                                  : Text('Non compilato'),
                              fullWidth: true,
                            ),
                            _buildDetailsSection(
                              'Immagini del Servizio',
                              _buildImagesField(service.images),
                              fullWidth: true,
                            ),
                            _buildDetailsSection(
                              'Etichette',
                              service.labels.isNotEmpty
                                  ? _buildLabelsField(service.labels)
                                  : Text('Non compilato'),
                              fullWidth: true,
                            ),
                            _buildDetailsSection(
                              'Allegati',
                              service.attachments.isNotEmpty
                                  ? _buildAttachmentsField(service.attachments)
                                  : Text('Non compilato'),
                              fullWidth: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Le funzioni seguenti sono aggiunte per supportare il dialogo servizio.

  Widget _buildDetailsSection(String title, Widget content,
      {bool fullWidth = false}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      width: fullWidth ? double.infinity : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          content,
        ],
      ),
    );
  }

  Widget _buildDetailsText(String title, String? content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(content?.isNotEmpty == true ? content! : 'Non compilato'),
        ],
      ),
    );
  }

  Widget _buildMainAdditionalDescriptionsSection(
      List<AdditionalDescription> descriptions,
      List<bool> additionalDescriptionsExpanded,
      Function(void Function()) setState) {
    return _buildDetailsSection(
      'Descrizioni Addizionali',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: descriptions.asMap().entries.map((entry) {
          int index = entry.key;
          AdditionalDescription desc = entry.value;
          return _buildDetailsSection(
            desc.title,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (additionalDescriptionsExpanded[index])
                  HtmlWidget(desc.content),
                Align(
                  alignment: Alignment.bottomRight,
                  child: IconButton(
                    icon: Icon(additionalDescriptionsExpanded[index]
                        ? Icons.expand_less
                        : Icons.expand_more),
                    onPressed: () {
                      setState(() {
                        additionalDescriptionsExpanded[index] =
                            !additionalDescriptionsExpanded[index];
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
      fullWidth: true,
    );
  }

  Widget _buildPartsField(List<ServicePart> parts) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: parts.map((part) {
        return GestureDetector(
          onTap: () {
            _showServiceDialog(part.service); // Apre il dialog del servizio
          },
          child: Chip(
            label: Text('${part.quantity}x ${part.service.servicecode}'),
            onDeleted: null,
            /*onDeleted: () {
              setState(() {
                parts.remove(part);
              });
            },*/
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImagesField(List<String> images) {
    if (images.isEmpty)
      return Container(
        color: Colors.grey.shade200,
        height: 256,
        child: Center(
          child: Icon(
            Icons.image,
            size: 50,
            color: Colors.grey.shade500,
          ),
        ),
      );
    return Container(
      height: 256,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              _showServiceDialog(filteredServices[index]);
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  images[index],
                  width: 256,
                  height: 256,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabelsField(List<Label> labels) {
    if (labels.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: labels.map((label) {
          return Chip(
            label: Text(label.name),
            backgroundColor: label.color,
            onDeleted: null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAttachmentsField(List<String> attachments) {
    if (attachments.isEmpty) return Text('Non compilato');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: attachments.map((fileName) {
          return Chip(
            label: Text(fileName),
            onDeleted: null,
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: EdgeInsets.only(top: 8.0, left: 16.0, right: 8.0),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Seleziona Parti del Servizio'),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Cerca per Nome',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                        _filterServices();
                      });
                    },
                  ),
                ),
                SizedBox(width: 8.0),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Cerca per Categoria',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchCategory = value;
                        _filterServices();
                      });
                    },
                  ),
                ),
                SizedBox(width: 8.0),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Cerca per Codice',
                      prefixIcon: Icon(Icons.info_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchSku = value;
                        _filterServices();
                      });
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.0),
            Expanded(
              child: ListView.builder(
                itemCount: filteredServices.length,
                itemBuilder: (context, index) {
                  final service = filteredServices[index];
                  final part = selectedParts.firstWhere(
                    (part) => part.service == service,
                    orElse: () => ServicePart(service, 0),
                  );

                  return ListTile(
                    title: Row(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          margin: EdgeInsets.only(right: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: service.images.isNotEmpty
                                ? Image.network(
                                    service.images.first,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: Colors.grey.shade200,
                                    child: Icon(
                                      Icons.image,
                                      size: 50,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(service.name),
                              Text('Codice: ${service.servicecode}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      _showServiceDialog(service);
                    },
                    trailing: Container(
                      width: 100,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(
                                text: part.quantity > 0
                                    ? part.quantity.toString()
                                    : '',
                              ),
                              decoration: InputDecoration(labelText: 'Quantità'),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                final newQuantity =
                                    int.tryParse(value) ?? 0;
                                _updatePartQuantity(service, newQuantity);
                              },
                            ),
                          ),
                          Checkbox(
                            value: part.quantity > 0,
                            onChanged: (value) {
                              if (value == true) {
                                _updatePartQuantity(service, 1);
                              } else {
                                _updatePartQuantity(service, 0);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(selectedParts);
          },
          child: Text('Salva'),
        ),
      ],
    );
  }
}


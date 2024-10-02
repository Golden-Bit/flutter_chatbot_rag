import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

void main() {
  runApp(ProductManagerApp());
}

class ProductManagerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ProductManagerPage(),
    );
  }
}

class ProductManagerPage extends StatefulWidget {
  @override
  _ProductManagerPageState createState() => _ProductManagerPageState();
}

class _ProductManagerPageState extends State<ProductManagerPage> {
  List<Product> products = [];
  List<Tax> taxes = [];
  List<Label> categories = [];
  List<Label> labels = [];
  String searchQuery = '';
  String searchCategory = '';
  String searchSku = '';

  void _addOrUpdateProduct(Product product, {Product? existingProduct}) {
    setState(() {
      if (existingProduct != null) {
        int index = products.indexOf(existingProduct);
        if (index != -1) {
          products[index] = product;
        }
      } else {
        products.add(product);
      }
    });
  }

  void _removeProduct(Product product) {
    setState(() {
      products.remove(product);
    });
  }

  void _duplicateProduct(Product product) {
  final duplicatedProduct = Product(
    name: '${product.name} (Copia)',
    description: product.description,
    additionalDescriptions: List.from(product.additionalDescriptions),
    categories: List.from(product.categories),
    salePrice: product.salePrice,
    purchasePrice: product.purchasePrice,
    billingPolicy: product.billingPolicy,
    taxes: List.from(product.taxes),
    barcode: product.barcode,
    sku: product.sku,
    attachments: List.from(product.attachments),
    weight: product.weight,
    dimensions: product.dimensions,
    volume: product.volume,
    labels: List.from(product.labels),
    currency: product.currency,
    images: List.from(product.images),
    unitOfMeasure: product.unitOfMeasure,
    minQuantity: product.minQuantity,
    minIncrement: product.minIncrement,
    parts: product.parts.map((part) => ProductPart(part.product, part.quantity)).toList(),
  );
  _addOrUpdateProduct(duplicatedProduct);
}

  void _navigateToAddProductPage(BuildContext context, {Product? product}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductPage(
          onAddOrUpdateProduct: (newProduct) =>
              _addOrUpdateProduct(newProduct, existingProduct: product),
          existingProduct: product,
          products: products,
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
    final filteredProducts = products
        .where((product) {
          final nameMatches = product.name.toLowerCase().contains(searchQuery.toLowerCase());
          final categoryMatches = searchCategory.isEmpty ||
              product.categories.any((category) =>
                  category.name.toLowerCase().contains(searchCategory.toLowerCase()));

          return nameMatches && categoryMatches;
        })
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestione Prodotti'),
        actions: [
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('Crea Nuovo Prodotto'),
            onPressed: () => _navigateToAddProductPage(context),
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
                      labelText: 'Cerca per SKU',
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
                  ...filteredProducts.map(
                    (product) => ProductCard(
                      product: product,
                      onRemove: () => _removeProduct(product),
                      onDuplicate: () => _duplicateProduct(product),
                      onEdit: () => _navigateToAddProductPage(context, product: product),
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

class Product {
  final String name;
  final String? description;
  final List<AdditionalDescription> additionalDescriptions;
  final List<Label> categories;
  final double salePrice;
  final double purchasePrice;
  final String billingPolicy;
  final List<Tax> taxes;
  final String? barcode;
  final String sku;
  final List<String> attachments;
  final double weight;
  final String dimensions;
  final double volume;
  final List<Label> labels;
  final List<String> images;
  String currency;
  String unitOfMeasure;
  final double minQuantity;
  final double minIncrement;
  List<ProductPart> parts;
  final String productType;

  Product({
    required this.name,
    this.description = 'Non compilato',
    this.additionalDescriptions = const [],
    this.categories = const [],
    this.salePrice = 0.0,
    this.purchasePrice = 0.0,
    this.billingPolicy = 'Quantità ordinate',
    this.taxes = const [],
    this.barcode = 'Non compilato',
    required this.sku,
    this.attachments = const [],
    this.weight = 0.0,
    this.dimensions = 'Non compilato',
    this.volume = 0.0,
    this.labels = const [],
    this.images = const [],
    this.currency = '€',
    this.unitOfMeasure = 'Non compilato',
    this.minQuantity = 1.0,
    this.minIncrement = 1.0,
    this.parts = const [],
    this.productType = 'Fisico',
  });
}


class ProductPart {
  final Product product;
  final int quantity;

  ProductPart(this.product, this.quantity);
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

class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback onEdit;

  const ProductCard({
    required this.product,
    required this.onRemove,
    required this.onDuplicate,
    required this.onEdit,
  });

  @override
  _ProductCardState createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> with SingleTickerProviderStateMixin {
  bool isExpanded = false;
  List<bool> additionalDescriptionsExpanded = [];

  @override
  void initState() {
    super.initState();
    additionalDescriptionsExpanded =
        //List.filled(widget.product.additionalDescriptions.length, false);
        List.filled(100, false);
  }

void _showViewProductDialog() {
  List<bool> additionalDescriptionsExpanded =
      //List.filled(widget.product.additionalDescriptions.length, false);
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
                  // Intestazione fissa con il nome del prodotto e l'icona di chiusura
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.product.name,
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
                            widget.product.description != null &&
                                    widget.product.description!.isNotEmpty
                                ? HtmlWidget(widget.product.description!)
                                : Text(
                                    'Non compilato',
                                    style: TextStyle(fontWeight: FontWeight.normal),
                                  ),
                            fullWidth: true,
                          ),
                          if (widget.product.additionalDescriptions.isNotEmpty)
                            _buildMainAdditionalDescriptionsSection(
                              widget.product.additionalDescriptions,
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
                                        '${widget.product.purchasePrice} ${widget.product.currency}',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Prezzo di vendita',
                                        '${widget.product.salePrice} ${widget.product.currency}',
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
                                  children: widget.product.taxes.isNotEmpty
                                      ? widget.product.taxes.map((tax) {
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
                            'Dettagli Prodotti',
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Codice Prodotto',
                                        widget.product.barcode ?? 'Non compilato',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildDetailsText('SKU', widget.product.sku),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText('Peso', '${widget.product.weight} kg'),
                                    ),
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Dimensioni',
                                        widget.product.dimensions.isNotEmpty
                                            ? widget.product.dimensions
                                            : 'Non compilato',
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText('Volume', '${widget.product.volume} m³'),
                                    ),
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Tipologia di Prodotto',
                                        widget.product.productType,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Quantità Minima',
                                        '${widget.product.minQuantity}',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Incremento Minimo',
                                        '${widget.product.minIncrement}',
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Unità di Misura',
                                        widget.product.unitOfMeasure.isNotEmpty
                                            ? widget.product.unitOfMeasure
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
                            'Parti del Prodotto',
                            widget.product.parts.isNotEmpty
                                ? _buildPartsField(widget.product.parts)
                                : Text('Non compilato'),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Categorie',
                            widget.product.categories.isNotEmpty
                                ? Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children: widget.product.categories.map((category) {
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
                            'Immagini del Prodotto',
                            _buildImagesField(widget.product.images),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Etichette',
                            widget.product.labels.isNotEmpty
                                ? _buildLabelsField(widget.product.labels)
                                : Text('Non compilato'),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Allegati',
                            widget.product.attachments.isNotEmpty
                                ? _buildAttachmentsField(widget.product.attachments)
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
                          child: widget.product.images.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _showFullScreenImage(widget.product.images.first);
                                  },
                                  child: Image.network(
                                    widget.product.images.first,
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
                              widget.product.name,
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
                                      text: widget.product.categories.isNotEmpty
                                          ? widget.product.categories
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
                                    TextSpan(
                                      text: 'SKU: ',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(
                                      text: widget.product.sku,
                                    ),
                                    TextSpan(
                                      text: 'Prezzo: ',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(
                                      text: '${widget.product.salePrice} ${widget.product.currency}',
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
      _showViewProductDialog();
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
                            child: widget.product.description != null
                                ? HtmlWidget(widget.product.description!)
                                : Text(
                                    'Non compilato',
                                    style: TextStyle(fontWeight: FontWeight.normal),
                                  ),
                          ),
                          fullWidth: true,
                        ),
if (widget.product.additionalDescriptions.isNotEmpty)
  _buildMainAdditionalDescriptionsSection(
    widget.product.additionalDescriptions,  // Lista delle descrizioni addizionali
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
                                        '${widget.product.purchasePrice} ${widget.product.currency}'),
                                  ),
                                  Expanded(
                                    child: _buildDetailsText(
                                        'Prezzo di vendita',
                                        '${widget.product.salePrice} ${widget.product.currency}'),
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
                                children: widget.product.taxes.isNotEmpty
                                    ? widget.product.taxes.map((tax) {
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
                          'Dettagli Prodotti',
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailsText(
                                        'Codice Prodotto',
                                        widget.product.barcode ?? 'Non compilato'),
                                  ),
                                  Expanded(
                                    child: _buildDetailsText('SKU', widget.product.sku),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailsText(
                                        'Peso', '${widget.product.weight} kg'),
                                  ),
                                  Expanded(
                                    child: _buildDetailsText(
                                        'Dimensioni',
                                        widget.product.dimensions ?? 'Non compilato'),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailsText(
                                        'Volume', '${widget.product.volume} m³'),
                                  ),
                                  /*Expanded(
                                    child: _buildDetailsText(
                                        'Traccia Magazzino',
                                        widget.product.trackInventory ? 'Sì' : 'No'),
                                  ),*/
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailsText(
                                        'Tipologia di Prodotto', widget.product.productType),
                                  ),
                                  Expanded(
                                    child: _buildDetailsText(
                                        'Quantità Minima', '${widget.product.minQuantity}'),
                                  ),
                                  Expanded(
                                    child: _buildDetailsText('Incremento Minimo',
                                        '${widget.product.minIncrement}'),
                                  ),
                                  Expanded(
                                    child: _buildDetailsText(
                                        'Unità di Misura', widget.product.unitOfMeasure),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildDetailsSection(
                          'Parti del Prodotto',
                          _buildPartsField(widget.product.parts),
                          fullWidth: true,
                        ),
                                                _buildDetailsSection(
                          'Categorie',
                          widget.product.categories.isNotEmpty
                              ? Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  children: widget.product.categories.map((category) {
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
                          'Immagini del Prodotto',
                          _buildImagesField(widget.product.images),
                          fullWidth: true,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 0.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLabeledSection(
                                'Etichette',
                                widget.product.labels.isNotEmpty
                                    ? _buildLabelsField(widget.product.labels)
                                    : SizedBox.shrink(),
                              ),
                              SizedBox(height: 8.0),
                              _buildLabeledSection(
                                'Allegati',
                                _buildAttachmentsField(widget.product.attachments),
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

Widget _buildPartsField(List<ProductPart> parts) {
  return Wrap(
    spacing: 8.0,
    runSpacing: 8.0,
    children: parts.map((part) {
      return GestureDetector(
        onTap: () {
          _showProductDialog(part.product); // Apre il dialog del prodotto
        },
        child: Chip(
          label: Text('${part.quantity}x ${part.product.sku}'),
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

void _showProductDialog(Product product) {

  List<bool> additionalDescriptionsExpanded = 
      List.filled(product.additionalDescriptions.length, false);

  // Copia della logica di _showViewProductDialog adattata per un prodotto specifico
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
                  // Intestazione fissa con il nome del prodotto e l'icona di chiusura
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.name,
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
                            product.description != null &&
                                    product.description!.isNotEmpty
                                ? HtmlWidget(product.description!)
                                : Text(
                                    'Non compilato',
                                    style: TextStyle(fontWeight: FontWeight.normal),
                                  ),
                            fullWidth: true,
                          ),
                          if (product.additionalDescriptions.isNotEmpty)
                            _buildMainAdditionalDescriptionsSection(
                              product.additionalDescriptions,
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
                                        '${product.purchasePrice} ${product.currency}',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Prezzo di vendita',
                                        '${product.salePrice} ${product.currency}',
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
                                  children: product.taxes.isNotEmpty
                                      ? product.taxes.map((tax) {
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
                            'Dettagli Prodotti',
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Codice Prodotto',
                                        product.barcode ?? 'Non compilato',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildDetailsText('SKU', product.sku),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText('Peso', '${product.weight} kg'),
                                    ),
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Dimensioni',
                                        product.dimensions.isNotEmpty
                                            ? product.dimensions
                                            : 'Non compilato',
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText('Volume', '${product.volume} m³'),
                                    ),
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Tipologia di Prodotto',
                                        product.productType,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Quantità Minima',
                                        '${product.minQuantity}',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Incremento Minimo',
                                        '${product.minIncrement}',
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailsText(
                                        'Unità di Misura',
                                        product.unitOfMeasure.isNotEmpty
                                            ? product.unitOfMeasure
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
                            'Parti del Prodotto',
                            product.parts.isNotEmpty
                                ? _buildPartsField(product.parts)
                                : Text('Non compilato'),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Categorie',
                            product.categories.isNotEmpty
                                ? Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children: product.categories.map((category) {
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
                            'Immagini del Prodotto',
                            _buildImagesField(product.images),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Etichette',
                            product.labels.isNotEmpty
                                ? _buildLabelsField(product.labels)
                                : Text('Non compilato'),
                            fullWidth: true,
                          ),
                          _buildDetailsSection(
                            'Allegati',
                            product.attachments.isNotEmpty
                                ? _buildAttachmentsField(product.attachments)
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
    final selectedParts = await showDialog<List<ProductPart>>(
      context: context,
      builder: (context) {
        return PartsSelectionDialog(
          allProducts: widget.product.parts.map((p) => p.product).toList(),
          selectedParts: widget.product.parts,
        );
      },
    );

    if (selectedParts != null) {
      setState(() {
        widget.product.parts = selectedParts;
      });
    }
  }
}

class PartsSelectionDialog extends StatefulWidget {
  final List<Product> allProducts;
  final List<ProductPart> selectedParts;

  PartsSelectionDialog({
    required this.allProducts,
    required this.selectedParts,
  });

  @override
  _PartsSelectionDialogState createState() => _PartsSelectionDialogState();
}

class _PartsSelectionDialogState extends State<PartsSelectionDialog> {
  late List<Product> filteredProducts;
  late List<ProductPart> selectedParts;
  String searchQuery = '';
  String searchCategory = '';
  String searchSku = '';

  @override
  void initState() {
    super.initState();
    filteredProducts = widget.allProducts;
    selectedParts = List.from(widget.selectedParts);
  }

  void _filterProducts() {
    setState(() {
      filteredProducts = widget.allProducts
          .where((product) =>
              product.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              product.sku.toLowerCase().contains(searchSku.toLowerCase()))
          .toList();
    });
  }

  void _updatePartQuantity(Product product, int newQuantity) {
    final partIndex = selectedParts.indexWhere((part) => part.product == product);
    if (partIndex >= 0) {
      setState(() {
        selectedParts[partIndex] = ProductPart(product, newQuantity);
      });
    } else {
      setState(() {
        selectedParts.add(ProductPart(product, newQuantity));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Seleziona Parti del Prodotto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: 'Cerca Prodotto',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value;
                _filterProducts();
              });
            },
          ),
          SizedBox(height: 8.0),
          Expanded(
            child: ListView.builder(
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                final part = selectedParts.firstWhere(
                  (part) => part.product == product,
                  orElse: () => ProductPart(product, 0),
                );

                return ListTile(
                  title: Text(product.name),
                  subtitle: Text('SKU: ${product.sku}'),
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
                              _updatePartQuantity(product, newQuantity);
                            },
                          ),
                        ),
                        Checkbox(
                          value: part.quantity > 0,
                          onChanged: (value) {
                            if (value == true) {
                              _updatePartQuantity(product, 1);
                            } else {
                              _updatePartQuantity(product, 0);
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

class AddProductPage extends StatefulWidget {
  final Function(Product) onAddOrUpdateProduct;
  final Product? existingProduct;
  final List<Label> categories;
  final List<Label> labels;
  final List<Tax> taxes;
  final Function(Tax) onAddTax;
  final Function(Label) onAddCategory;
  final Function(Label) onAddLabel;
  final List<Product> products;

  AddProductPage({
    required this.onAddOrUpdateProduct,
    this.existingProduct,
    required this.categories,
    required this.labels,
    required this.taxes,
    required this.onAddTax,
    required this.onAddCategory,
    required this.onAddLabel,
    required this.products,
  });

  @override
  _AddProductPageState createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController salePriceController = TextEditingController();
  TextEditingController purchasePriceController = TextEditingController();
  TextEditingController barcodeController = TextEditingController();
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
  List<ProductPart> selectedParts = [];
  List<bool> additionalDescriptionsExpanded = List.filled(100, false);
  //[];
  String selectedProductType = 'Fisico';

  // Aggiungi una lista di controller per le descrizioni addizionali
  List<TextEditingController> additionalDescriptionTitleControllers = [];
  List<TextEditingController> additionalDescriptionControllers = [];

void initState() {
  super.initState();
  if (widget.existingProduct != null) {
    final product = widget.existingProduct!;

    // Inizializza i controller per le tasse esistenti
    addedTaxes = product.taxes.map((tax) => Tax(name: tax.name, rate: tax.rate)).toList(); // Deep copy
    taxNameControllers = List.generate(addedTaxes.length, (index) => TextEditingController(text: addedTaxes[index].name));
    taxRateControllers = List.generate(addedTaxes.length, (index) => TextEditingController(text: addedTaxes[index].rate.toString()));
    

    nameController.text = product.name;
    descriptionController.text = product.description ?? 'Non compilato';
    salePriceController.text = product.salePrice.toString();
    purchasePriceController.text = product.purchasePrice.toString();
    barcodeController.text = product.barcode ?? 'Non compilato';
    skuController.text = product.sku;
    weightController.text = product.weight.toString();
    dimensionsController.text = product.dimensions;
    volumeController.text = product.volume.toString();
    attachments = product.attachments.map((attachment) => attachment).toList(); // Deep copy
    selectedCategories = product.categories.map((category) => Label(name: category.name, color: category.color)).toList(); // Deep copy
    selectedLabels = product.labels.map((label) => Label(name: label.name, color: label.color)).toList(); // Deep copy
    addedTaxes = product.taxes.map((tax) => Tax(name: tax.name, rate: tax.rate)).toList(); // Deep copy
    billingPolicy = product.billingPolicy;
    currency = product.currency;
    selectedUnitOfMeasure = product.unitOfMeasure;
    additionalDescriptions = product.additionalDescriptions.map((desc) => AdditionalDescription(title: desc.title, content: desc.content)).toList(); // Deep copy
    images = product.images.map((image) => image).toList(); // Deep copy
    minQuantityController.text = product.minQuantity.toString();
    minIncrementController.text = product.minIncrement.toString();
    selectedParts = product.parts.map((part) => ProductPart(part.product, part.quantity)).toList(); // Deep copy
    selectedProductType = product.productType;

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

  void _saveProduct() {
    final product = Product(
      name: nameController.text.isNotEmpty ? nameController.text : 'Nome prodotto non compilato',
      description: descriptionController.text.isNotEmpty
          ? descriptionController.text
          : 'Non compilato',
      additionalDescriptions: additionalDescriptions,
      categories: selectedCategories,
      labels: selectedLabels,
      salePrice: double.tryParse(salePriceController.text) ?? 0.0,
      purchasePrice: double.tryParse(purchasePriceController.text) ?? 0.0,
      //trackInventory: trackInventory,
      billingPolicy: billingPolicy ?? 'Quantità ordinate',
      taxes: addedTaxes.isNotEmpty
          ? addedTaxes
          : [Tax(name: 'Non compilato', rate: 0.0)],
      barcode: barcodeController.text.isNotEmpty ? barcodeController.text : 'Non compilato',
      sku: skuController.text.isNotEmpty ? skuController.text : 'Non compilato',
      attachments: attachments,
      weight: double.tryParse(weightController.text) ?? 0.0,
      dimensions: dimensionsController.text.isNotEmpty ? dimensionsController.text : 'Non compilato',
      volume: double.tryParse(volumeController.text) ?? 0.0,
      images: images,
      currency: currency,
      unitOfMeasure: selectedUnitOfMeasure.isNotEmpty
          ? selectedUnitOfMeasure
          : 'Non compilato',
      minQuantity: double.tryParse(minQuantityController.text) ?? 1.0,
      minIncrement: double.tryParse(minIncrementController.text) ?? 1.0,
      parts: selectedParts,
      productType: selectedProductType,
    );

    widget.onAddOrUpdateProduct(product);
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
        title: Text(widget.existingProduct != null
            ? 'Modifica Prodotto'
            : 'Aggiungi Prodotto'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Nome Prodotto'),
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
                title: 'Dettagli Prodotti',
                content: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: barcodeController,
                            decoration: InputDecoration(labelText: 'Codice Prodotto'),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: skuController,
                            decoration: InputDecoration(labelText: 'SKU'),
                          ),
                        ),
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
                            value: selectedProductType,
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedProductType = newValue!;
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
                              labelText: 'Tipologia di Prodotto',
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
                title: 'Parti del Prodotto',
                content: _buildPartsField(selectedParts),
              ),
              _buildInputField(
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
              ),
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
                title: "Immagini del Prodotto",
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
                    onPressed: _saveProduct,
                    child: Text(widget.existingProduct != null
                        ? 'Salva Modifiche'
                        : 'Salva Prodotto'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartsField(List<ProductPart> parts) {
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
                label: Text('${part.quantity}x ${part.product.sku}'),
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
    final selectedParts = await showDialog<List<ProductPart>>(
      context: context,
      builder: (context) {
        return ProductPartsSelectionDialog(
          allProducts: widget.products,
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

class ProductPartsSelectionDialog extends StatefulWidget {
  final List<Product> allProducts;
  final List<ProductPart> selectedParts;

  ProductPartsSelectionDialog({
    required this.allProducts,
    required this.selectedParts,
  });

  @override
  _ProductPartsSelectionDialogState createState() =>
      _ProductPartsSelectionDialogState();
}

class _ProductPartsSelectionDialogState
    extends State<ProductPartsSelectionDialog> {
  late List<Product> filteredProducts;
  late List<ProductPart> selectedParts;
  String searchQuery = '';
  String searchCategory = '';
  String searchSku = '';

  @override
  void initState() {
    super.initState();
    filteredProducts = widget.allProducts;
    selectedParts = List.from(widget.selectedParts);
  }

  void _filterProducts() {
    setState(() {
      filteredProducts = widget.allProducts
          .where((product) {
            final nameMatches =
                product.name.toLowerCase().contains(searchQuery.toLowerCase());
            final categoryMatches = searchCategory.isEmpty ||
                product.categories.any((category) =>
                    category.name.toLowerCase().contains(searchCategory.toLowerCase()));
            final skuMatches =
                product.sku.toLowerCase().contains(searchSku.toLowerCase());

            return nameMatches && categoryMatches && skuMatches;
          })
          .toList();
    });
  }

  void _updatePartQuantity(Product product, int newQuantity) {
    final partIndex =
        selectedParts.indexWhere((part) => part.product == product);
    if (partIndex >= 0) {
      setState(() {
        selectedParts[partIndex] = ProductPart(product, newQuantity);
      });
    } else {
      setState(() {
        selectedParts.add(ProductPart(product, newQuantity));
      });
    }
  }

  void _showProductDialog(Product product) {

    List<bool> additionalDescriptionsExpanded = 
      List.filled(product.additionalDescriptions.length, false);

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
                          product.name,
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
                              product.description != null &&
                                      product.description!.isNotEmpty
                                  ? HtmlWidget(product.description!)
                                  : Text(
                                      'Non compilato',
                                      style:
                                          TextStyle(fontWeight: FontWeight.normal),
                                    ),
                              fullWidth: true,
                            ),
                            if (product.additionalDescriptions.isNotEmpty)
                              _buildMainAdditionalDescriptionsSection(
                                product.additionalDescriptions,
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
                                          '${product.purchasePrice} ${product.currency}',
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildDetailsText(
                                          'Prezzo di vendita',
                                          '${product.salePrice} ${product.currency}',
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
                                    children: product.taxes.isNotEmpty
                                        ? product.taxes.map((tax) {
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
                              'Dettagli Prodotti',
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDetailsText(
                                          'Codice Prodotto',
                                          product.barcode ?? 'Non compilato',
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildDetailsText('SKU', product.sku),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDetailsText(
                                            'Peso', '${product.weight} kg'),
                                      ),
                                      Expanded(
                                        child: _buildDetailsText(
                                          'Dimensioni',
                                          product.dimensions.isNotEmpty
                                              ? product.dimensions
                                              : 'Non compilato',
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDetailsText(
                                            'Volume', '${product.volume} m³'),
                                      ),
                                      Expanded(
                                        child: _buildDetailsText(
                                          'Tipologia di Prodotto',
                                          product.productType,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDetailsText(
                                          'Quantità Minima',
                                          '${product.minQuantity}',
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildDetailsText(
                                          'Incremento Minimo',
                                          '${product.minIncrement}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDetailsText(
                                          'Unità di Misura',
                                          product.unitOfMeasure.isNotEmpty
                                              ? product.unitOfMeasure
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
                              'Parti del Prodotto',
                              product.parts.isNotEmpty
                                  ? _buildPartsField(product.parts)
                                  : Text('Non compilato'),
                              fullWidth: true,
                            ),
                            _buildDetailsSection(
                              'Categorie',
                              product.categories.isNotEmpty
                                  ? Wrap(
                                      spacing: 8.0,
                                      runSpacing: 8.0,
                                      children: product.categories.map((category) {
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
                              'Immagini del Prodotto',
                              _buildImagesField(product.images),
                              fullWidth: true,
                            ),
                            _buildDetailsSection(
                              'Etichette',
                              product.labels.isNotEmpty
                                  ? _buildLabelsField(product.labels)
                                  : Text('Non compilato'),
                              fullWidth: true,
                            ),
                            _buildDetailsSection(
                              'Allegati',
                              product.attachments.isNotEmpty
                                  ? _buildAttachmentsField(product.attachments)
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

  // Le funzioni seguenti sono aggiunte per supportare il dialogo prodotto.

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

  Widget _buildPartsField(List<ProductPart> parts) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: parts.map((part) {
        return GestureDetector(
          onTap: () {
            _showProductDialog(part.product); // Apre il dialog del prodotto
          },
          child: Chip(
            label: Text('${part.quantity}x ${part.product.sku}'),
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
              _showProductDialog(filteredProducts[index]);
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
          Text('Seleziona Parti del Prodotto'),
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
                        _filterProducts();
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
                        _filterProducts();
                      });
                    },
                  ),
                ),
                SizedBox(width: 8.0),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Cerca per SKU',
                      prefixIcon: Icon(Icons.info_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchSku = value;
                        _filterProducts();
                      });
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.0),
            Expanded(
              child: ListView.builder(
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  final part = selectedParts.firstWhere(
                    (part) => part.product == product,
                    orElse: () => ProductPart(product, 0),
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
                            child: product.images.isNotEmpty
                                ? Image.network(
                                    product.images.first,
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
                              Text(product.name),
                              Text('SKU: ${product.sku}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      _showProductDialog(product);
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
                                _updatePartQuantity(product, newQuantity);
                              },
                            ),
                          ),
                          Checkbox(
                            value: part.quantity > 0,
                            onChanged: (value) {
                              if (value == true) {
                                _updatePartQuantity(product, 1);
                              } else {
                                _updatePartQuantity(product, 0);
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


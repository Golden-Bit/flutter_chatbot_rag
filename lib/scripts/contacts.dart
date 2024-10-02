import 'package:flutter/material.dart';
import 'databases_manager/database_service.dart';
import 'user_manager/auth_service.dart';
import 'dart:html' as html;

/*void main() {
  runApp(ContactManagerApp());
}

class ContactManagerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ContactManagerPage(),
    );
  }
}*/

class ContactManagerPage extends StatefulWidget {
  final String token;

  ContactManagerPage({required this.token});  // Accetta il token come parametro

  @override
  _ContactManagerPageState createState() => _ContactManagerPageState();
}

class _ContactManagerPageState extends State<ContactManagerPage> {
  bool showPersonContacts = true;
  bool showCompanyContacts = true;
  List<Contact> personContacts = [];
  List<Contact> companyContacts = [];
  List<Label> labels = [];
  String searchQuery = '';
  String searchJobTitle = '';
  String searchCompanyName = '';
  List<String> personJobTitles = ['Manager', 'Developer', 'Designer'];
  List<String> companyJobTitles = ['Fornitore di Elettronica', 'Installatore di Impianti', 'Distributore'];
  List<String> relations = ['Cliente', 'Collaboratore'];

@override
void initState() {
  super.initState();
  _loadContactsFromDatabase(); // Carica i contatti dal database all'inizializzazione
}

Future<void> _loadContactsFromDatabase() async {
  try {
    final authService = AuthService();
    final databaseService = DatabaseService();
    
    // Ottenere l'utente corrente utilizzando il token
    final user = await authService.fetchCurrentUser(widget.token);
    final dbName = '${user.username}-database_0';
    final collectionName = 'contacts';

    final contactsData = await databaseService.fetchCollectionData(
      dbName,
      collectionName,
      widget.token,
    );

    setState(() {
      personContacts.clear();
      companyContacts.clear();
      for (var contactJson in contactsData) {
        final contact = Contact.fromJson(contactJson);
        if (contact.isPerson) {
          personContacts.add(contact);
        } else {
          companyContacts.add(contact);
        }
      }
    });

    print("Contatti caricati dal database");
  } catch (e) {
    print("Errore durante il caricamento dei contatti: $e");
  }
}

Future<void> _saveContactToDatabase(Contact contact) async {
  try {
    final databaseService = DatabaseService();
    final authService = AuthService();
    
    // Ottenere l'utente corrente utilizzando il token
    final user = await authService.fetchCurrentUser(widget.token);
    final dbName = '${user.username}-database_0';
    final collectionName = 'contacts';

    if (contact.id.isEmpty) {

      // Nuovo contatto
      final response = await databaseService.addDataToCollection(
        dbName,
        collectionName,
        contact.toJson(),
        widget.token,
      );

      // Estrai l'ID generato dal database e aggiornalo nel contatto
      final newId = response['id'];  // Supponendo che la risposta contenga un campo 'id'
      final updatedContact = contact.copyWith(id: newId);

      // Inserisci il contatto aggiornato nella lista appropriata
      /*setState(() {
        if (updatedContact.isPerson) {
          personContacts.add(updatedContact);
        } else {
          companyContacts.add(updatedContact);
        }
      });*/
    } else {

      // Aggiornamento contatto esistente
      await databaseService.updateCollectionData(
        dbName,
        collectionName,
        contact.id,
        contact.toJson(),
        widget.token,
      );
    }

    print("Contatto salvato nel database");
  } catch (e) {
    print("Errore durante il salvataggio del contatto: $e");
  }
}


Future<void> _deleteContactFromDatabase(Contact contact) async {
  try {
    final databaseService = DatabaseService();
    final authService = AuthService();

    // Ottenere l'utente corrente utilizzando il token
    final user = await authService.fetchCurrentUser(widget.token);
    final dbName = '${user.username}-database_0';
    final collectionName = 'contacts';

    await databaseService.deleteCollectionData(
      dbName,
      collectionName,
      contact.id,
      widget.token,
    );

    print("Contatto eliminato dal database");
  } catch (e) {
    print("Errore durante l'eliminazione del contatto: $e");
  }
}
Future<void> _updateContactInDatabase(Contact contact) async {
  try {
    final databaseService = DatabaseService();
    final authService = AuthService();

    // Ottenere l'utente corrente utilizzando il token
    final user = await authService.fetchCurrentUser(widget.token);
    final dbName = '${user.username}-database_0';
    final collectionName = 'contacts';

    // Aggiornamento del contatto esistente nel database
    await databaseService.updateCollectionData(
      dbName,
      collectionName,
      contact.id,  // Assumiamo che l'ID sia già presente nel contatto
      contact.toJson(),
      widget.token,
    );

    print("Contatto aggiornato nel database");
  } catch (e) {
    print("Errore durante l'aggiornamento del contatto: $e");
  }
}
void _addOrUpdateContact(Contact contact, {Contact? existingContact}) async {
  if (existingContact != null) {
    // Aggiorna il contatto esistente nel database
    contact.id = existingContact.id;
    await _updateContactInDatabase(contact);
    
    setState(() {
      if (existingContact.isPerson) {
        int index = personContacts.indexOf(existingContact);
        if (index != -1) {
          // Aggiorna la lista locale con il nuovo contatto
          personContacts[index] = contact;
        }
      } else {
        int index = companyContacts.indexOf(existingContact);
        if (index != -1) {
          // Aggiorna la lista locale con il nuovo contatto
          companyContacts[index] = contact;
        }
      }
    });
  } else {
    // Aggiungi nuovo contatto al database
    await _saveContactToDatabase(contact);
    
    setState(() {
      if (contact.isPerson) {
        personContacts.add(contact);
      } else {
        companyContacts.add(contact);
      }
    });
  }
}


 void _removeContact(Contact contact) async {
  await _deleteContactFromDatabase(contact);
  setState(() {
    if (contact.isPerson) {
      personContacts.remove(contact);
    } else {
      companyContacts.remove(contact);
    }
  });
}

  void _duplicateContact(Contact contact) {
    final duplicatedContact = Contact(
      id: contact.id,
      isPerson: contact.isPerson,
      name: '${contact.name} (Copia)',
      biography: contact.biography,
      jobTitle: contact.jobTitle,
      relation: contact.relation,
      address: contact.address,
      vatNumber: contact.vatNumber,
      phone: contact.phone,
      mobile: contact.mobile,
      email: contact.email,
      website: contact.website,
      labels: contact.labels.map((label) => Label(name: label.name, color: label.color)).toList(),
      profileImage: contact.profileImage,
      attachments: List.from(contact.attachments),
      logoColor: contact.logoColor,
    );
    _addOrUpdateContact(duplicatedContact);
  }

  void _navigateToAddContactPage(BuildContext context, {Contact? contact}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddContactPage(
          onAddOrUpdateContact: (newContact) => _addOrUpdateContact(newContact, existingContact: contact),
          existingContact: contact,
          personJobTitles: personJobTitles,
          companyJobTitles: companyJobTitles,
          relations: relations,
          labels: labels,
          onAddRelation: _addRelation,
          onAddJobTitle: _addJobTitle,
          onAddLabel: _addLabel,
        ),
      ),
    );
  }

  void _addRelation(String relation) {
    setState(() {
      relations.add(relation);
    });
  }

  void _addJobTitle(String jobTitle, bool isPerson) {
    setState(() {
      if (isPerson) {
        personJobTitles.add(jobTitle);
      } else {
        companyJobTitles.add(jobTitle);
      }
    });
  }

  void _addLabel(Label label) {
    setState(() {
      labels.add(label);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredPersonContacts = personContacts
        .where((contact) =>
            contact.name.toLowerCase().contains(searchQuery.toLowerCase()) &&
            (contact.jobTitle?.toLowerCase().contains(searchJobTitle.toLowerCase()) ?? true))
        .toList();

    final filteredCompanyContacts = companyContacts
        .where((contact) =>
            contact.name.toLowerCase().contains(searchQuery.toLowerCase()) &&
            (contact.companyName?.toLowerCase().contains(searchCompanyName.toLowerCase()) ?? true))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestione Contatti'),
        actions: [
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('Crea Nuovo Contatto'),
            onPressed: () => _navigateToAddContactPage(context),
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
                  Row(
                    children: [
                      Checkbox(
                        value: showPersonContacts,
                        onChanged: (bool? value) {
                          setState(() {
                            showPersonContacts = value ?? true;
                          });
                        },
                      ),
                      Text('Persone'),
                      SizedBox(width: 16),
                      Checkbox(
                        value: showCompanyContacts,
                        onChanged: (bool? value) {
                          setState(() {
                            showCompanyContacts = value ?? true;
                          });
                        },
                      ),
                      Text('Aziende'),
                    ],
                  ),
                  SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Cerca contatti',
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
                  if (showPersonContacts)
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Cerca per posizione lavorativa',
                        prefixIcon: Icon(Icons.work),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchJobTitle = value;
                        });
                      },
                    ),
                  SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Cerca per nome azienda',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchCompanyName = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (showPersonContacts)
                    ...filteredPersonContacts.map(
                      (contact) => ContactCard(
                        contact: contact,
                        onRemove: () => _removeContact(contact),
                        onDuplicate: () => _duplicateContact(contact),
                        onEdit: () => _navigateToAddContactPage(context, contact: contact),
                      ),
                    ),
                  if (showCompanyContacts)
                    ...filteredCompanyContacts.map(
                      (contact) => ContactCard(
                        contact: contact,
                        onRemove: () => _removeContact(contact),
                        onDuplicate: () => _duplicateContact(contact),
                        onEdit: () => _navigateToAddContactPage(context, contact: contact),
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
class Contact {
  String id; // Aggiungiamo un ID per identificare il contatto nel database
  final bool isPerson;
  final String name;
  final String? biography;
  final String? companyName;
  final String? jobTitle;
  final String relation;
  final String? address;
  final String? vatNumber;
  final String? phone;
  final String? mobile;
  final String? email;
  final String? website;
  final String? title;
  final List<Label> labels;
  final String? profileImage;
  final List<String> attachments;
  final Color logoColor;

  Contact({
    this.id = "",
    required this.isPerson,
    required this.name,
    this.biography,
    this.companyName,
    this.jobTitle,
    required this.relation,
    this.address,
    this.vatNumber,
    this.phone,
    this.mobile,
    this.email,
    this.website,
    this.title,
    this.labels = const [],
    this.profileImage,
    this.attachments = const [],
    required this.logoColor,
  });

  // Conversione a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isPerson': isPerson,
      'name': name,
      'biography': biography,
      'companyName': companyName,
      'jobTitle': jobTitle,
      'relation': relation,
      'address': address,
      'vatNumber': vatNumber,
      'phone': phone,
      'mobile': mobile,
      'email': email,
      'website': website,
      'labels': labels.map((label) => label.toJson()).toList(),
      'profileImage': profileImage,
      'attachments': attachments,
      'logoColor': logoColor.value,
    };
  }

  // Creazione da JSON
  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['_id'],
      isPerson: json['isPerson'],
      name: json['name'],
      biography: json['biography'],
      companyName: json['companyName'],
      jobTitle: json['jobTitle'],
      relation: json['relation'],
      address: json['address'],
      vatNumber: json['vatNumber'],
      phone: json['phone'],
      mobile: json['mobile'],
      email: json['email'],
      website: json['website'],
      labels: (json['labels'] as List)
          .map((labelJson) => Label.fromJson(labelJson))
          .toList(),
      profileImage: json['profileImage'],
      attachments: List<String>.from(json['attachments']),
      logoColor: Color(json['logoColor']),
    );
  }

  // Aggiungere il metodo copyWith per aggiornare l'ID
  Contact copyWith({String? id}) {
    return Contact(
      id: id ?? this.id,
      isPerson: this.isPerson,
      name: this.name,
      biography: this.biography,
      companyName: this.companyName,
      jobTitle: this.jobTitle,
      relation: this.relation,
      address: this.address,
      vatNumber: this.vatNumber,
      phone: this.phone,
      mobile: this.mobile,
      email: this.email,
      website: this.website,
      labels: this.labels,
      profileImage: this.profileImage,
      attachments: this.attachments,
      logoColor: this.logoColor,
    );
  }
}

class Label {
  String name;
  Color color;

  Label({required this.name, required this.color});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'color': color.value,
    };
  }

  factory Label.fromJson(Map<String, dynamic> json) {
    return Label(
      name: json['name'],
      color: Color(json['color']),
    );
  }
}
class ContactCard extends StatefulWidget {
  final Contact contact;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback onEdit;

  const ContactCard({
    required this.contact,
    required this.onRemove,
    required this.onDuplicate,
    required this.onEdit,
  });

  @override
  _ContactCardState createState() => _ContactCardState();
}

class _ContactCardState extends State<ContactCard> with SingleTickerProviderStateMixin {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.0),
      child: AnimatedSize(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Card(
          margin: EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      widget.contact.isPerson ? Icons.person : Icons.business,
                      color: Colors.white,
                    ),
                    backgroundColor: widget.contact.logoColor,
                  ),
                  title: isExpanded
                      ? Text(
                          widget.contact.name,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        )
                      : Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: widget.contact.name,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: ' (Ruolo: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: widget.contact.jobTitle ?? 'Non compilato',
                              ),
                              TextSpan(
                                text: ' Relazione: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: widget.contact.relation,
                              ),
                              TextSpan(text: ')'),
                            ],
                          ),
                        ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'elimina') {
                        widget.onRemove();
                      } else if (value == 'duplica') {
                        widget.onDuplicate();
                      } else if (value == 'modifica') {
                        widget.onEdit();
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
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
                  ),
                ),
                if (isExpanded)
                  Column(
                    children: [
                      _buildDetailsSection(
                        'Biografia, Ruolo e Relazione',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.contact.biography != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(widget.contact.biography!),
                              ),
                            Row(
                              children: [
                                Expanded(child: _buildDetailsText('Ruolo', widget.contact.jobTitle)),
                                Expanded(child: _buildDetailsText('Relazione', widget.contact.relation)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _buildDetailsSection(
                        'Dettagli Contatto',
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildDetailsText('Indirizzo', widget.contact.address)),
                                Expanded(child: _buildDetailsText('Partita IVA', widget.contact.vatNumber)),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(child: _buildDetailsText('Telefono', widget.contact.phone)),
                                Expanded(child: _buildDetailsText('Mobile', widget.contact.mobile)),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(child: _buildDetailsText('Email', widget.contact.email)),
                                Expanded(child: _buildDetailsText('Sito Web', widget.contact.website)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(child: _buildLabeledSection('Etichette', _buildLabelsField(widget.contact.labels))),
                            SizedBox(width: 8.0),
                            Expanded(child: _buildLabeledSection('Allegati', _buildAttachmentsField(widget.contact.attachments))),
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
    );
  }

  Widget _buildDetailsSection(String title, Widget content) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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

  Widget _buildLabeledSection(String title, Widget content) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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

  Widget _buildLabelsField(List<Label> labels) {
    if (labels.isEmpty) return Text('Non compilato');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: labels.map((label) {
          return Chip(
            label: Text(label.name, style: TextStyle(color: Colors.black87)),
            backgroundColor: label.color,
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
            onDeleted: null, // Disable delete in view mode
          );
        }).toList(),
      ),
    );
  }
}

class AddContactPage extends StatefulWidget {
  final Function(Contact) onAddOrUpdateContact;
  final Contact? existingContact;
  final List<String> relations;
  final List<String> personJobTitles;
  final List<String> companyJobTitles;
  final List<Label> labels;
  final Function(String) onAddRelation;
  final Function(String, bool) onAddJobTitle;
  final Function(Label) onAddLabel;

  AddContactPage({
    required this.onAddOrUpdateContact,
    this.existingContact,
    required this.relations,
    required this.personJobTitles,
    required this.companyJobTitles,
    required this.labels,
    required this.onAddRelation,
    required this.onAddJobTitle,
    required this.onAddLabel,
  });

  @override
  _AddContactPageState createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  bool isPerson = true;
  TextEditingController nameController = TextEditingController();
  TextEditingController biographyController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController vatNumberController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController mobileController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController websiteController = TextEditingController();
  List<String> attachments = [];
  String? profileImage;
  String? selectedRelation;
  String? selectedJobTitle;
  List<Label> selectedLabels = [];
  Color selectedColor = Colors.blue; // Default color for logo

  @override
  void initState() {
    super.initState();
    if (widget.existingContact != null) {
      final contact = widget.existingContact!;
      isPerson = contact.isPerson;
      nameController.text = contact.name;
      biographyController.text = contact.biography ?? '';
      addressController.text = contact.address ?? '';
      vatNumberController.text = contact.vatNumber ?? '';
      phoneController.text = contact.phone ?? '';
      mobileController.text = contact.mobile ?? '';
      emailController.text = contact.email ?? '';
      websiteController.text = contact.website ?? '';
      attachments = List.from(contact.attachments);
      profileImage = contact.profileImage;
      selectedRelation = contact.relation;
      selectedColor = contact.logoColor;

      // Assicura che il jobTitle selezionato sia tra le opzioni disponibili
      if (isPerson && widget.personJobTitles.contains(contact.jobTitle)) {
        selectedJobTitle = contact.jobTitle;
      } else if (!isPerson && widget.companyJobTitles.contains(contact.jobTitle)) {
        selectedJobTitle = contact.jobTitle;
      } else {
        selectedJobTitle = null;
      }

      selectedLabels = contact.labels;
    }
  }

  Future<void> _selectProfileImage() async {
    html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final reader = html.FileReader();
        reader.readAsDataUrl(files[0]);
        reader.onLoadEnd.listen((e) {
          setState(() {
            profileImage = reader.result as String?;
          });
        });
      }
    });
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

  void _saveContact() {
    final contact = Contact(
      isPerson: isPerson,
      name: nameController.text,
      biography: biographyController.text,
      jobTitle: selectedJobTitle ?? (isPerson ? widget.personJobTitles.first : widget.companyJobTitles.first),
      relation: selectedRelation ?? widget.relations.first,
      address: addressController.text,
      vatNumber: vatNumberController.text,
      phone: phoneController.text,
      mobile: mobileController.text,
      email: emailController.text,
      website: websiteController.text,
      labels: selectedLabels,
      profileImage: profileImage,
      attachments: attachments,
      logoColor: selectedColor,
    );
    widget.onAddOrUpdateContact(contact);
    Navigator.of(context).pop();
  }

  void _addNewRelation() {
    final TextEditingController newRelationController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Aggiungi Nuova Relazione'),
          content: TextField(
            controller: newRelationController,
            decoration: InputDecoration(hintText: 'Nome Relazione'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final newRelation = newRelationController.text;
                if (newRelation.isNotEmpty) {
                  widget.onAddRelation(newRelation);
                  setState(() {
                    selectedRelation = newRelation;
                  });
                  Navigator.of(context).pop();
                }
              },
              child: Text('Aggiungi'),
            ),
          ],
        );
      },
    );
  }

  void _addNewJobTitle(bool isPerson) {
    final TextEditingController newJobTitleController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Aggiungi Nuova Posizione Lavorativa'),
          content: TextField(
            controller: newJobTitleController,
            decoration: InputDecoration(hintText: 'Nome Posizione Lavorativa'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final newJobTitle = newJobTitleController.text;
                if (newJobTitle.isNotEmpty) {
                  widget.onAddJobTitle(newJobTitle, isPerson);
                  setState(() {
                    selectedJobTitle = newJobTitle;
                  });
                  Navigator.of(context).pop();
                }
              },
              child: Text('Aggiungi'),
            ),
          ],
        );
      },
    );
  }

  void _addNewLabel() {
    final TextEditingController labelNameController = TextEditingController();
    Color labelColor = Colors.transparent;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Crea Nuova Etichetta'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelNameController,
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
                      name: labelNameController.text,
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

  Widget _buildColorPicker() {
    return Row(
      children: [
        Text('Seleziona Colore Logo:'),
        SizedBox(width: 10),
        ...Colors.primaries.map((color) {
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedColor = color;
              });
            },
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 5.0),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: selectedColor == color
                    ? Border.all(width: 2.0, color: Colors.black)
                    : null,
              ),
            ),
          );
        }).toList(),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingContact != null ? 'Modifica Contatto' : 'Aggiungi Contatto'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: isPerson,
                    onChanged: (value) {
                      setState(() {
                        isPerson = value!;
                        selectedJobTitle = null; // Resetta il jobTitle quando cambia il tipo
                      });
                    },
                  ),
                  Text('Persona'),
                  Radio<bool>(
                    value: false,
                    groupValue: isPerson,
                    onChanged: (value) {
                      setState(() {
                        isPerson = value!;
                        selectedJobTitle = null; // Resetta il jobTitle quando cambia il tipo
                      });
                    },
                  ),
                  Text('Azienda'),
                ],
              ),
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: isPerson ? 'Nome' : 'Nome Azienda'),
              ),
              TextField(
                controller: biographyController,
                decoration: InputDecoration(labelText: 'Biografia'),
                maxLines: 3,
              ),
              _buildInputField(
                title: isPerson ? 'Ruolo e Relazione' : 'Ruolo e Relazione',
                content: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(labelText: 'Ruolo'),
                            value: selectedJobTitle,
                            items: (isPerson ? widget.personJobTitles : widget.companyJobTitles).map((jobTitle) {
                              return DropdownMenuItem<String>(
                                value: jobTitle,
                                child: Text(jobTitle),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedJobTitle = value;
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () => _addNewJobTitle(isPerson),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(labelText: 'Relazione'),
                            value: selectedRelation,
                            items: widget.relations.map((relation) {
                              return DropdownMenuItem<String>(
                                value: relation,
                                child: Text(relation),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedRelation = value;
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: _addNewRelation,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildInputField(
                title: 'Dettagli Contatto',
                content: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: addressController,
                            decoration: InputDecoration(labelText: 'Indirizzo'),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: vatNumberController,
                            decoration: InputDecoration(labelText: 'Partita IVA'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: phoneController,
                            decoration: InputDecoration(labelText: 'Telefono'),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: mobileController,
                            decoration: InputDecoration(labelText: 'Mobile'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: emailController,
                            decoration: InputDecoration(labelText: 'E-mail'),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: websiteController,
                            decoration: InputDecoration(labelText: 'Sito Web'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildInputField(
                title: "Etichette",
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
              SizedBox(height: 16.0),
              _buildColorPicker(),
              SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.camera_alt),
                    label: Text('Seleziona Immagine Profilo'),
                    onPressed: _selectProfileImage,
                  ),
                  ElevatedButton(
                    onPressed: _saveContact,
                    child: Text(widget.existingContact != null ? 'Salva Modifiche' : 'Salva Contatto'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

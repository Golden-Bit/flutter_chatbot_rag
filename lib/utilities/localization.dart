import 'package:flutter/material.dart';

enum Language { english, italian, spanish }

class AppLocalizations {
  final Language language;

  AppLocalizations(this.language);

  // Titoli e label generali
  String get searchTitle {
    switch (language) {
      case Language.italian:
        return 'Cerca nei messaggi';
      case Language.spanish:
        return 'Buscar en los mensajes';
      case Language.english:
      default:
        return 'Search Messages';
    }
  }

  String get searchButton {
    switch (language) {
      case Language.italian:
        return 'Cerca';
      case Language.spanish:
        return 'Buscar';
      case Language.english:
      default:
        return 'Search';
    }
  }

  String get conversation {
    switch (language) {
      case Language.italian:
        return 'Conversazione';
      case Language.spanish:
        return 'Conversación';
      case Language.english:
      default:
        return 'Conversation';
    }
  }

  String get knowledgeBoxes {
    switch (language) {
      case Language.italian:
        return 'Knowledge Boxes'; //'Basi di conoscenza';
      case Language.spanish:
        return 'Knowledge Boxes'; //'Cajas de Conocimiento';
      case Language.english:
      default:
        return 'Knowledge Boxes';
    }
  }

  String get newChat {
    switch (language) {
      case Language.italian:
        return 'Nuova Chat';
      case Language.spanish:
        return 'Nueva Chat';
      case Language.english:
      default:
        return 'New Chat';
    }
  }

  // Menu a tendina (dropdown) e top bar
  String get profile {
    switch (language) {
      case Language.italian:
        return 'Profilo';
      case Language.spanish:
        return 'Perfil';
      case Language.english:
      default:
        return 'Profile';
    }
  }

  String get usage {
    switch (language) {
      case Language.italian:
        return 'Utilizzo';
      case Language.spanish:
        return 'Uso';
      case Language.english:
      default:
        return 'Usage';
    }
  }

  String get settings {
    switch (language) {
      case Language.italian:
        return 'Impostazioni';
      case Language.spanish:
        return 'Configuración';
      case Language.english:
      default:
        return 'Settings';
    }
  }

  String get logout {
    switch (language) {
      case Language.italian:
        return 'Logout';
      case Language.spanish:
        return 'Logout'; //'Cerrar sesión';
      case Language.english:
      default:
        return 'Logout';
    }
  }

  // Sezione TTS e personalizzazione grafica
  String get ttsSettings {
    switch (language) {
      case Language.italian:
        return 'Impostazioni Text-to-Speech';
      case Language.spanish:
        return 'Configuración de Texto a Voz';
      case Language.english:
      default:
        return 'Text-to-Speech Settings';
    }
  }

  String get selectLanguage {
    switch (language) {
      case Language.italian:
        return 'Seleziona lingua';
      case Language.spanish:
        return 'Selecciona idioma';
      case Language.english:
      default:
        return 'Select Language';
    }
  }

  String get englishUS {
    // Di solito rimane invariato
    return 'English (US)';
  }

  String get italian {
    switch (language) {
      case Language.italian:
        return 'Italiano';
      case Language.spanish:
        return 'Italiano';
      case Language.english:
      default:
        return 'Italian';
    }
  }

  // Parametri di lettura
  String get readingSpeed {
    switch (language) {
      case Language.italian:
        return 'Velocità lettura';
      case Language.spanish:
        return 'Velocidad de lectura';
      case Language.english:
      default:
        return 'Reading Speed';
    }
  }

  String get pitch {
    switch (language) {
      case Language.italian:
        return 'Intonazione (Pitch)';
      case Language.spanish:
        return 'Tono (Pitch)';
      case Language.english:
      default:
        return 'Pitch';
    }
  }

  String get volume {
    switch (language) {
      case Language.italian:
        return 'Volume';
      case Language.spanish:
        return 'Volumen';
      case Language.english:
      default:
        return 'Volume';
    }
  }

  String get pauseBetweenSentences {
    switch (language) {
      case Language.italian:
        return 'Pausa tra frasi';
      case Language.spanish:
        return 'Pausa entre frases';
      case Language.english:
      default:
        return 'Pause Between Sentences';
    }
  }

  // Personalizzazione grafica
  String get graphicCustomization {
    switch (language) {
      case Language.italian:
        return 'Personalizzazione grafica';
      case Language.spanish:
        return 'Personalización gráfica';
      case Language.english:
      default:
        return 'Graphic Customization';
    }
  }

  String get userMessageColor {
    switch (language) {
      case Language.italian:
        return 'Colore messaggio utente';
      case Language.spanish:
        return 'Color del mensaje de usuario';
      case Language.english:
      default:
        return 'User Message Color';
    }
  }

  String get assistantMessageColor {
    switch (language) {
      case Language.italian:
        return 'Colore messaggio assistente';
      case Language.spanish:
        return 'Color del mensaje del asistente';
      case Language.english:
      default:
        return 'Assistant Message Color';
    }
  }

  String get chatBackgroundColor {
    switch (language) {
      case Language.italian:
        return 'Colore sfondo chat';
      case Language.spanish:
        return 'Color de fondo del chat';
      case Language.english:
      default:
        return 'Chat Background Color';
    }
  }

  String get avatarColor {
    switch (language) {
      case Language.italian:
        return 'Colore avatar';
      case Language.spanish:
        return 'Color del avatar';
      case Language.english:
      default:
        return 'Avatar Color';
    }
  }

  String get avatarIconColor {
    switch (language) {
      case Language.italian:
        return 'Colore icona avatar';
      case Language.spanish:
        return 'Color del ícono del avatar';
      case Language.english:
      default:
        return 'Avatar Icon Color';
    }
  }

  // Messaggio Info Dialog
  String get messageInfoTitle {
    switch (language) {
      case Language.italian:
        return 'Dettagli del messaggio';
      case Language.spanish:
        return 'Detalles del mensaje';
      case Language.english:
      default:
        return 'Message Details';
    }
  }

  String get roleLabel {
    switch (language) {
      case Language.italian:
        return 'Ruolo:';
      case Language.spanish:
        return 'Rol:';
      case Language.english:
      default:
        return 'Role:';
    }
  }

  String get userRole {
    switch (language) {
      case Language.italian:
        return 'Utente';
      case Language.spanish:
        return 'Usuario';
      case Language.english:
      default:
        return 'User';
    }
  }

  String get assistantRole {
    switch (language) {
      case Language.italian:
        return 'Assistente';
      case Language.spanish:
        return 'Asistente';
      case Language.english:
      default:
        return 'Assistant';
    }
  }

  String get dateLabel {
    switch (language) {
      case Language.italian:
        return 'Data:';
      case Language.spanish:
        return 'Fecha:';
      case Language.english:
      default:
        return 'Date:';
    }
  }

  String get charLength {
    switch (language) {
      case Language.italian:
        return 'Lunghezza in caratteri:';
      case Language.spanish:
        return 'Longitud en caracteres:';
      case Language.english:
      default:
        return 'Character Length:';
    }
  }

  String get tokenLength {
    switch (language) {
      case Language.italian:
        return 'Lunghezza in token:';
      case Language.spanish:
        return 'Longitud en tokens:';
      case Language.english:
      default:
        return 'Token Length:';
    }
  }

  String get agentConfigDetails {
    switch (language) {
      case Language.italian:
        return "Dettagli della configurazione dell'agente:";
      case Language.spanish:
        return "Detalles de la configuración del agente:";
      case Language.english:
      default:
        return "Agent Configuration Details:";
    }
  }

  String get modelLabel {
    switch (language) {
      case Language.italian:
        return 'Modello:';
      case Language.spanish:
        return 'Modelo:';
      case Language.english:
      default:
        return 'Model:';
    }
  }

  String get selectedContextsLabel {
    switch (language) {
      case Language.italian:
        return 'Contesti selezionati:';
      case Language.spanish:
        return 'Contextos seleccionados:';
      case Language.english:
      default:
        return 'Selected Contexts:';
    }
  }

  String get chainIdLabel {
    switch (language) {
      case Language.italian:
        return 'Chain ID:';
      case Language.spanish:
        return 'ID de cadena:';
      case Language.english:
      default:
        return 'Chain ID:';
    }
  }

  String get additionalMetrics {
    switch (language) {
      case Language.italian:
        return 'Metriche aggiuntive:';
      case Language.spanish:
        return 'Métricas adicionales:';
      case Language.english:
      default:
        return 'Additional Metrics:';
    }
  }

  String get tokensReceived {
    switch (language) {
      case Language.italian:
        return 'Token ricevuti:';
      case Language.spanish:
        return 'Tokens recibidos:';
      case Language.english:
      default:
        return 'Tokens Received:';
    }
  }

  String get tokensGenerated {
    switch (language) {
      case Language.italian:
        return 'Token generati:';
      case Language.spanish:
        return 'Tokens generados:';
      case Language.english:
      default:
        return 'Tokens Generated:';
    }
  }

  String get responseCost {
    switch (language) {
      case Language.italian:
        return 'Costo risposta:';
      case Language.spanish:
        return 'Costo de respuesta:';
      case Language.english:
      default:
        return 'Response Cost:';
    }
  }

  // Raggruppamento chat
  String get today {
    switch (language) {
      case Language.italian:
        return 'Oggi';
      case Language.spanish:
        return 'Hoy';
      case Language.english:
      default:
        return 'Today';
    }
  }

  String get yesterday {
    switch (language) {
      case Language.italian:
        return 'Ieri';
      case Language.spanish:
        return 'Ayer';
      case Language.english:
      default:
        return 'Yesterday';
    }
  }

  String get last7Days {
    switch (language) {
      case Language.italian:
        return 'Ultimi 7 giorni';
      case Language.spanish:
        return 'Últimos 7 días';
      case Language.english:
      default:
        return 'Last 7 Days';
    }
  }

  String get last30Days {
    switch (language) {
      case Language.italian:
        return 'Ultimi 30 giorni';
      case Language.spanish:
        return 'Últimos 30 días';
      case Language.english:
      default:
        return 'Last 30 Days';
    }
  }

  String get pastChats {
    switch (language) {
      case Language.italian:
        return 'Chat passate';
      case Language.spanish:
        return 'Chats pasadas';
      case Language.english:
      default:
        return 'Past Chats';
    }
  }

  String get noChatAvailable {
    switch (language) {
      case Language.italian:
        return 'Nessuna chat disponibile.';
      case Language.spanish:
        return 'No hay chats disponibles.';
      case Language.english:
      default:
        return 'No chats available.';
    }
  }

  String get copyMessage {
    switch (language) {
      case Language.italian:
        return 'Messaggio copiato negli appunti';
      case Language.spanish:
        return 'Mensaje copiado al portapapeles';
      case Language.english:
      default:
        return 'Message copied to clipboard';
    }
  }

  String get copy {
  switch (language) {
    case Language.italian:
      return 'Copia';
    case Language.spanish:
      return 'Copiar';
    case Language.english:
    default:
      return 'Copy';
  }
}

String get positive_feedback {
  switch (language) {
    case Language.italian:
      return 'Feedback positivo';
    case Language.spanish:
      return 'Retroalimentación positiva';
    case Language.english:
    default:
      return 'Positive Feedback';
  }
}

String get negative_feedback {
  switch (language) {
    case Language.italian:
      return 'Feedback negativo';
    case Language.spanish:
      return 'Retroalimentación negativa';
    case Language.english:
    default:
      return 'Negative Feedback';
  }
}

String get close {
  switch (language) {
    case Language.italian:
      return 'Chiudi';
    case Language.spanish:
      return 'Cerrar';
    case Language.english:
    default:
      return 'Close';
  }
}
String get message_details {
  switch (language) {
    case Language.italian:
      return 'Dettagli del messaggio';
    case Language.spanish:
      return 'Detalles del mensaje';
    case Language.english:
    default:
      return 'Message Details';
  }
}

String get edit {
  switch (language) {
    case Language.italian:
      return 'Modifica';
    case Language.spanish:
      return 'Editar';
    case Language.english:
    default:
      return 'Edit';
  }
}

String get delete {
  switch (language) {
    case Language.italian:
      return 'Elimina';
    case Language.spanish:
      return 'Eliminar';
    case Language.english:
    default:
      return 'Delete';
  }
}

String get write_here_your_message {
  switch (language) {
    case Language.italian:
      return 'Scrivi qui il tuo messaggio...';
    case Language.spanish:
      return 'Escribe aquí tu mensaje...';
    case Language.english:
    default:
      return 'Write your message here...';
  }
}

String get upload_document {
  switch (language) {
    case Language.italian:
      return 'Carica documento';
    case Language.spanish:
      return 'Subir documento';
    case Language.english:
    default:
      return 'Upload document';
  }
}

String get upload_media {
  switch (language) {
    case Language.italian:
      return 'Carica media';
    case Language.spanish:
      return 'Subir medio';
    case Language.english:
    default:
      return 'Upload media';
  }
}

String get enable_mic {
  switch (language) {
    case Language.italian:
      return 'Abilita microfono';
    case Language.spanish:
      return 'Habilitar micrófono';
    case Language.english:
    default:
      return 'Enable mic';
  }
}

String get send_message {
  switch (language) {
    case Language.italian:
      return 'Invia messaggio';
    case Language.spanish:
      return 'Enviar mensaje';
    case Language.english:
    default:
      return 'Send message';
  }
}

String get edit_chat_name {
  switch (language) {
    case Language.italian:
      return 'Modifica nome chat';
    case Language.spanish:
      return 'Editar nombre de chat';
    case Language.english:
    default:
      return 'Edit chat name';
  }
}

String get chat_name {
  switch (language) {
    case Language.italian:
      return 'Nome chat';
    case Language.spanish:
      return 'Nombre de chat';
    case Language.english:
    default:
      return 'Chat name';
  }
}

String get cancel {
  switch (language) {
    case Language.italian:
      return 'Annulla';
    case Language.spanish:
      return 'Cancelar';
    case Language.english:
    default:
      return 'Cancel';
  }
}

String get save {
  switch (language) {
    case Language.italian:
      return 'Salva';
    case Language.spanish:
      return 'Guardar';
    case Language.english:
    default:
      return 'Save';
  }
}

// Getter per il titolo del dialog di selezione contesti e modello
String get select_contexts_and_model {
  switch (language) {
    case Language.italian:
      return 'Seleziona knowledge box e modello';
    case Language.spanish:
      return 'Selecciona contextos y modelo';
    case Language.english:
    default:
      return 'Select knowledge box and Model';
  }
}


String get search_contexts {
  switch (language) {
    case Language.italian:
      return 'Cerca knowledge boxe...';
    case Language.spanish:
      return 'Buscar contextos...';
    case Language.english:
    default:
      return 'Search knowledge boxes...';
  }
}

String get confirm {
  switch (language) {
    case Language.italian:
      return 'Conferma';
    case Language.spanish:
      return 'Confirmar';
    case Language.english:
    default:
      return 'Confirm';
  }
}

// Getter per la sezione TTS e personalizzazione:
String get tts_settings {
  switch (language) {
    case Language.italian:
      return 'Impostazioni Text-to-Speech';
    case Language.spanish:
      return 'Configuración de Texto a Voz';
    case Language.english:
    default:
      return 'Text-to-Speech Settings';
  }
}

String get select_language {
  switch (language) {
    case Language.italian:
      return 'Seleziona lingua';
    case Language.spanish:
      return 'Selecciona idioma';
    case Language.english:
    default:
      return 'Select Language';
  }
}

String get english_us {
  switch (language) {
    case Language.italian:
      return 'Inglese (US)';
    case Language.spanish:
      return 'Inglés (EE.UU.)';
    case Language.english:
    default:
      return 'English (US)';
  }
}

String get reading_speed {
  switch (language) {
    case Language.italian:
      return 'Velocità lettura';
    case Language.spanish:
      return 'Velocidad de lectura';
    case Language.english:
    default:
      return 'Reading Speed';
  }
}

String get pause_between_sentences {
  switch (language) {
    case Language.italian:
      return 'Pausa tra frasi';
    case Language.spanish:
      return 'Pausa entre frases';
    case Language.english:
    default:
      return 'Pause Between Sentences';
  }
}

String get graphic_customization {
  switch (language) {
    case Language.italian:
      return 'Personalizzazione grafica';
    case Language.spanish:
      return 'Personalización gráfica';
    case Language.english:
    default:
      return 'Graphic Customization';
  }
}

String get user_message_color {
  switch (language) {
    case Language.italian:
      return 'Colore messaggio utente';
    case Language.spanish:
      return 'Color del mensaje de usuario';
    case Language.english:
    default:
      return 'User Message Color';
  }
}

String get assistant_message_color {
  switch (language) {
    case Language.italian:
      return 'Colore messaggio assistente';
    case Language.spanish:
      return 'Color del mensaje del asistente';
    case Language.english:
    default:
      return 'Assistant Message Color';
  }
}

String get chat_background_color {
  switch (language) {
    case Language.italian:
      return 'Colore sfondo chat';
    case Language.spanish:
      return 'Color de fondo del chat';
    case Language.english:
    default:
      return 'Chat Background Color';
  }
}

String get avatar_color {
  switch (language) {
    case Language.italian:
      return 'Colore avatar';
    case Language.spanish:
      return 'Color del avatar';
    case Language.english:
    default:
      return 'Avatar Color';
  }
}

String get avatar_icon_color {
  switch (language) {
    case Language.italian:
      return 'Colore icona avatar';
    case Language.spanish:
      return 'Color del ícono del avatar';
    case Language.english:
    default:
      return 'Avatar Icon Color';
  }
}

// Getter per il dialog "Dettagli del messaggio":
String get role_label {
  switch (language) {
    case Language.italian:
      return 'Ruolo:';
    case Language.spanish:
      return 'Rol:';
    case Language.english:
    default:
      return 'Role:';
  }
}

String get user_role {
  switch (language) {
    case Language.italian:
      return 'Utente';
    case Language.spanish:
      return 'Usuario';
    case Language.english:
    default:
      return 'User';
  }
}

String get assistant_role {
  switch (language) {
    case Language.italian:
      return 'Assistente';
    case Language.spanish:
      return 'Asistente';
    case Language.english:
    default:
      return 'Assistant';
  }
}

String get date_label {
  switch (language) {
    case Language.italian:
      return 'Data:';
    case Language.spanish:
      return 'Fecha:';
    case Language.english:
    default:
      return 'Date:';
  }
}

String get char_length {
  switch (language) {
    case Language.italian:
      return 'Lunghezza in caratteri:';
    case Language.spanish:
      return 'Longitud en caracteres:';
    case Language.english:
    default:
      return 'Character Length:';
  }
}

String get token_length {
  switch (language) {
    case Language.italian:
      return 'Lunghezza in token:';
    case Language.spanish:
      return 'Longitud en tokens:';
    case Language.english:
    default:
      return 'Token Length:';
  }
}

String get agent_config_details {
  switch (language) {
    case Language.italian:
      return "Dettagli della configurazione dell'agente:";
    case Language.spanish:
      return "Detalles de la configuración del agente:";
    case Language.english:
    default:
      return "Agent Configuration Details:";
  }
}

String get model_label {
  switch (language) {
    case Language.italian:
      return 'Modello:';
    case Language.spanish:
      return 'Modelo:';
    case Language.english:
    default:
      return 'Model:';
  }
}

String get selected_contexts_label {
  switch (language) {
    case Language.italian:
      return 'Contesti selezionati:';
    case Language.spanish:
      return 'Contextos seleccionados:';
    case Language.english:
    default:
      return 'Selected Contexts:';
  }
}

String get chain_id_label {
  switch (language) {
    case Language.italian:
      return 'Chain ID:';
    case Language.spanish:
      return 'ID de cadena:';
    case Language.english:
    default:
      return 'Chain ID:';
  }
}

String get additional_metrics {
  switch (language) {
    case Language.italian:
      return 'Metriche aggiuntive:';
    case Language.spanish:
      return 'Métricas adicionales:';
    case Language.english:
    default:
      return 'Additional Metrics:';
  }
}

String get tokens_received {
  switch (language) {
    case Language.italian:
      return 'Token ricevuti:';
    case Language.spanish:
      return 'Tokens recibidos:';
    case Language.english:
    default:
      return 'Tokens Received:';
  }
}

String get tokens_generated {
  switch (language) {
    case Language.italian:
      return 'Token generati:';
    case Language.spanish:
      return 'Tokens generados:';
    case Language.english:
    default:
      return 'Tokens Generated:';
  }
}

String get response_cost {
  switch (language) {
    case Language.italian:
      return 'Costo risposta:';
    case Language.spanish:
      return 'Costo de respuesta:';
    case Language.english:
    default:
      return 'Response Cost:';
  }
}


String get last7_days {
  switch (language) {
    case Language.italian:
      return 'Ultimi 7 giorni';
    case Language.spanish:
      return 'Últimos 7 días';
    case Language.english:
    default:
      return 'Last 7 Days';
  }
}

String get last30_days {
  switch (language) {
    case Language.italian:
      return 'Ultimi 30 giorni';
    case Language.spanish:
      return 'Últimos 30 días';
    case Language.english:
    default:
      return 'Last 30 Days';
  }
}

String get past_chats {
  switch (language) {
    case Language.italian:
      return 'Chat passate';
    case Language.spanish:
      return 'Chats pasadas';
    case Language.english:
    default:
      return 'Past Chats';
  }
}

String get no_chat_available {
  switch (language) {
    case Language.italian:
      return 'Nessuna chat disponibile.';
    case Language.spanish:
      return 'No hay chats disponibles.';
    case Language.english:
    default:
      return 'No chats available.';
  }
}

// Getter per pulsanti e dialog in varie parti dell'app:
String get new_chat {
  switch (language) {
    case Language.italian:
      return 'Nuova Chat';
    case Language.spanish:
      return 'Nueva Chat';
    case Language.english:
    default:
      return 'New Chat';
  }
}

String get select_color {
  switch (language) {
    case Language.italian:
      return 'Seleziona il colore';
    case Language.spanish:
      return 'Selecciona el color';
    case Language.english:
    default:
      return 'Select Color';
  }
}

// Getter per il titolo del dialog di upload file in Knowledge Boxes
String get upload_file_in_multiple_knowledge_boxes {
  switch (language) {
    case Language.italian:
      return 'Carica File in Knowledge Boxes';
    case Language.spanish:
      return 'Subir Archivo en Knowledge Boxes';
    case Language.english:
    default:
      return 'Upload File to Knowledge Boxes';
  }
}

// Getter per il testo del bottone per selezionare un file
String get select_file {
  switch (language) {
    case Language.italian:
      return 'Seleziona File';
    case Language.spanish:
      return 'Seleccionar Archivo';
    case Language.english:
    default:
      return 'Select File';
  }
}

// Getter per l'hint della barra di ricerca nei file
String get search_file {
  switch (language) {
    case Language.italian:
      return 'Cerca file...';
    case Language.spanish:
      return 'Buscar archivo...';
    case Language.english:
    default:
      return 'Search file...';
  }
}

// Getter per l'etichetta "Tipo" dei file
String get file_type {
  switch (language) {
    case Language.italian:
      return 'Tipo';
    case Language.spanish:
      return 'Tipo';
    case Language.english:
    default:
      return 'Type';
  }
}

// Getter per l'etichetta "Dimensione" dei file
String get file_size {
  switch (language) {
    case Language.italian:
      return 'Dimensione';
    case Language.spanish:
      return 'Tamaño';
    case Language.english:
    default:
      return 'Size';
  }
}

// Getter per l'etichetta "Data di caricamento" dei file
String get upload_date {
  switch (language) {
    case Language.italian:
      return 'Data di caricamento';
    case Language.spanish:
      return 'Fecha de subida';
    case Language.english:
    default:
      return 'Upload Date';
  }
}

// Getter per il testo del pulsante di upload file nel dialog dei Knowledge Boxes
String get upload_file {
  switch (language) {
    case Language.italian:
      return 'Carica File';
    case Language.spanish:
      return 'Subir Archivo';
    case Language.english:
    default:
      return 'Upload File';
  }
}

// Getter per il titolo del dialog di creazione di una nuova Knowledge Box
String get create_new_knowledge_box {
  switch (language) {
    case Language.italian:
      return 'Crea Nuova Knowledge Box';
    case Language.spanish:
      return 'Crear Nueva Knowledge Box';
    case Language.english:
    default:
      return 'Create New Knowledge Box';
  }
}

// Getter per il label del campo "Nome della Knowledge Box"
String get knowledge_box_name {
  switch (language) {
    case Language.italian:
      return 'Nome della Knowledge Box';
    case Language.spanish:
      return 'Nombre de la Knowledge Box';
    case Language.english:
    default:
      return 'Knowledge Box Name';
  }
}

// Getter per il label del campo "Descrizione della Knowledge Box"
String get knowledge_box_description {
  switch (language) {
    case Language.italian:
      return 'Descrizione della Knowledge Box';
    case Language.spanish:
      return 'Descripción de la Knowledge Box';
    case Language.english:
    default:
      return 'Knowledge Box Description';
  }
}

// Getter per il testo della scheda per creare una Knowledge Box (nella griglia)
String get create_knowledge_box {
  switch (language) {
    case Language.italian:
      return 'Crea Knowledge Box';
    case Language.spanish:
      return 'Crear Knowledge Box';
    case Language.english:
    default:
      return 'Create Knowledge Box';
  }
}

// Getter per il testo della scheda per creare una Knowledge Box (nella griglia)
String get selected_file {
  switch (language) {
    case Language.italian:
      return 'File selezionato';
    case Language.spanish:
      return 'Archivo seleccionado';
    case Language.english:
    default:
      return 'Selected file';
  }
}

String get search_by_name_or_description {
  switch (language) {
    case Language.italian:
      return 'Cerca per nome o descrizione...';
    case Language.spanish:
      return 'Buscar por nombre o descripción...';
    case Language.english:
    default:
      return 'Search by name or description...';
  }
}

  // Hint per il campo di ricerca
  String get searchHint {
    switch (language) {
      case Language.italian:
        return 'Inserisci testo da cercare...';
      case Language.spanish:
        return 'Ingrese texto a buscar...';
      case Language.english:
      default:
        return 'Enter text to search...';
    }
  }

  // Messaggio da mostrare se non ci sono risultati
  String get noResults {
    switch (language) {
      case Language.italian:
        return 'Nessun risultato.';
      case Language.spanish:
        return 'No se encontraron resultados.';
      case Language.english:
      default:
        return 'No results found.';
    }
  }

  // Testo da usare quando il nome della chat non è disponibile
  String get unknownChat {
    switch (language) {
      case Language.italian:
        return 'Chat Sconosciuta';
      case Language.spanish:
        return 'Chat desconocida';
      case Language.english:
      default:
        return 'Unknown Chat';
    }
  }

  // --- Pagina di Registrazione ---
  String get registrationTitle {
    switch (language) {
      case Language.italian:
        return 'Registrazione';
      case Language.spanish:
        return 'Registro';
      case Language.english:
      default:
        return 'Registration';
    }
  }

  String get registerButton {
    switch (language) {
      case Language.italian:
        return 'Register';
      case Language.spanish:
        return 'Registrar';
      case Language.english:
      default:
        return 'Register';
    }
  }

  String get enterUsername {
    switch (language) {
      case Language.italian:
        return 'Inserisci il tuo username';
      case Language.spanish:
        return 'Introduce tu nombre de usuario';
      case Language.english:
      default:
        return 'Enter your username';
    }
  }

  String get enterEmail {
    switch (language) {
      case Language.italian:
        return 'Inserisci la tua email';
      case Language.spanish:
        return 'Introduce tu correo electrónico';
      case Language.english:
      default:
        return 'Enter your email';
    }
  }

  String get enterFullName {
    switch (language) {
      case Language.italian:
        return 'Inserisci il tuo nome completo';
      case Language.spanish:
        return 'Introduce tu nombre completo';
      case Language.english:
      default:
        return 'Enter your full name';
    }
  }

  String get enterPassword {
    switch (language) {
      case Language.italian:
        return 'Inserisci la tua password';
      case Language.spanish:
        return 'Introduce tu contraseña';
      case Language.english:
      default:
        return 'Enter your password';
    }
  }

  String get confirmPassword {
    switch (language) {
      case Language.italian:
        return 'Conferma la tua password';
      case Language.spanish:
        return 'Confirma tu contraseña';
      case Language.english:
      default:
        return 'Confirm your password';
    }
  }

  String get passwordsDoNotMatch {
    switch (language) {
      case Language.italian:
        return 'Le password non coincidono';
      case Language.spanish:
        return 'Las contraseñas no coinciden';
      case Language.english:
      default:
        return 'Passwords do not match';
    }
  }

  // --- Pagina di Login ---
  String get loginTitle {
    switch (language) {
      case Language.italian:
        return 'Login';
      case Language.spanish:
        return 'Inicio de sesión';
      case Language.english:
      default:
        return 'Login';
    }
  }

  String get enterUsernameLogin {
    switch (language) {
      case Language.italian:
        return 'Inserisci il tuo username';
      case Language.spanish:
        return 'Introduce tu nombre de usuario';
      case Language.english:
      default:
        return 'Enter your username';
    }
  }

  String get enterPasswordLogin {
    switch (language) {
      case Language.italian:
        return 'Inserisci la tua password';
      case Language.spanish:
        return 'Introduce tu contraseña';
      case Language.english:
      default:
        return 'Enter your password';
    }
  }

  String get noAccountRegisterPrompt {
    switch (language) {
      case Language.italian:
        return 'Non hai un account? Registrati';
      case Language.spanish:
        return '¿No tienes una cuenta? Regístrate';
      case Language.english:
      default:
        return "Don't have an account? Register";
    }
  }

  String get loginButton {
    switch (language) {
      case Language.italian:
        return 'Login';
      case Language.spanish:
        return 'Iniciar sesión';
      case Language.english:
      default:
        return 'Login';
    }
  }

  String get loginError {
    switch (language) {
      case Language.italian:
        return 'Errore durante il login: ';
      case Language.spanish:
        return 'Error durante el inicio de sesión: ';
      case Language.english:
      default:
        return 'Error during login: ';
    }
  }

  // --- Pagina Impostazioni Utente ---
  String get accountSettingsTitle {
    switch (language) {
      case Language.italian:
        return 'Impostazioni Account';
      case Language.spanish:
        return 'Configuración de la Cuenta';
      case Language.english:
      default:
        return 'Account Settings';
    }
  }

  String get editProfile {
    switch (language) {
      case Language.italian:
        return 'Modifica profilo';
      case Language.spanish:
        return 'Editar perfil';
      case Language.english:
      default:
        return 'Edit Profile';
    }
  }

  String get updateProfile {
    switch (language) {
      case Language.italian:
        return 'Aggiorna profilo';
      case Language.spanish:
        return 'Actualizar perfil';
      case Language.english:
      default:
        return 'Update Profile';
    }
  }

  String get changePassword {
    switch (language) {
      case Language.italian:
        return 'Cambia password';
      case Language.spanish:
        return 'Cambiar contraseña';
      case Language.english:
      default:
        return 'Change Password';
    }
  }

  String get oldPassword {
    switch (language) {
      case Language.italian:
        return 'Vecchia password';
      case Language.spanish:
        return 'Contraseña antigua';
      case Language.english:
      default:
        return 'Old Password';
    }
  }

  String get newPassword {
    switch (language) {
      case Language.italian:
        return 'Nuova password';
      case Language.spanish:
        return 'Nueva contraseña';
      case Language.english:
      default:
        return 'New Password';
    }
  }

  String get confirmNewPassword {
    switch (language) {
      case Language.italian:
        return 'Conferma nuova password';
      case Language.spanish:
        return 'Confirma nueva contraseña';
      case Language.english:
      default:
        return 'Confirm New Password';
    }
  }

  String get profileUpdated {
    switch (language) {
      case Language.italian:
        return 'Profilo aggiornato con successo!';
      case Language.spanish:
        return '¡Perfil actualizado con éxito!';
      case Language.english:
      default:
        return 'Profile updated successfully!';
    }
  }

  String get passwordChanged {
    switch (language) {
      case Language.italian:
        return 'Password cambiata con successo!';
      case Language.spanish:
        return '¡Contraseña cambiada con éxito!';
      case Language.english:
      default:
        return 'Password changed successfully!';
    }
  }

  String get deleteAccount {
    switch (language) {
      case Language.italian:
        return 'Elimina Account';
      case Language.spanish:
        return 'Eliminar cuenta';
      case Language.english:
      default:
        return 'Delete Account';
    }
  }

  String get confirmAccountDeletion {
    switch (language) {
      case Language.italian:
        return 'Conferma Eliminazione Account';
      case Language.spanish:
        return 'Confirmar eliminación de la cuenta';
      case Language.english:
      default:
        return 'Confirm Account Deletion';
    }
  }

  String get username {
    switch (language) {
      case Language.italian:
        return 'Username';
      case Language.spanish:
        return 'Nombre de usuario';
      case Language.english:
      default:
        return 'Username';
    }
  }

  String get password {
    switch (language) {
      case Language.italian:
        return 'Password';
      case Language.spanish:
        return 'Contraseña';
      case Language.english:
      default:
        return 'Password';
    }
  }

  /// Etichetta nel popup‑menu (fra “Modifica” e “Elimina”)
  String get archive {
    switch (language) {
      case Language.italian:
        return 'Archivia';
      case Language.spanish:
        return 'Archivar';
      case Language.english:
      default:
        return 'Archive';
    }
  }

  /// Snack‑bar di conferma quando la chat è stata archiviata
  String get chat_archived {
    switch (language) {
      case Language.italian:
        return 'Chat archiviata';
      case Language.spanish:
        return 'Chat archivada';
      case Language.english:
      default:
        return 'Chat archived';
    }
  }

  /// Messaggio di fallback per errori generici
  String get genericError {
    switch (language) {
      case Language.italian:
        return 'Si è verificato un errore';
      case Language.spanish:
        return 'Se produjo un error';
      case Language.english:
      default:
        return 'An error occurred';
    }
  }

  String get all_chats_deleted {
  switch (language) {
    case Language.italian:  return 'Tutte le chat eliminate';
    case Language.spanish:  return 'Todas las conversaciones eliminadas';
    default:                return 'All chats deleted';
  }
}

String get all_chats_archived {
  switch (language) {
    case Language.italian:  return 'Tutte le chat archiviate';
    case Language.spanish:  return 'Todas las conversaciones archivadas';
    default:                return 'All chats archived';
  }
}

String get edit_knowledge_box {
  switch (language) {
    case Language.italian:  return 'Modifica Knowledge Box';
    case Language.spanish:  return 'Editar Knowledge Box';
    default:                return 'Edit Knowledge Box';
  }
}
 String get write_here {
    switch (language) {
      case Language.italian:
        return 'Scrivi qui…';
      case Language.spanish:
        return 'Escribe aquí…';
      case Language.english:
      default:
        return 'Write here…';
    }
  }

  /// Tooltip per disattivare il microfono
  String get disable_mic {
    switch (language) {
      case Language.italian:
        return 'Disabilita microfono';
      case Language.spanish:
        return 'Desactivar micrófono';
      case Language.english:
      default:
        return 'Disable mic';
    }
  }

  /// Tooltip per stoppare lo streaming della risposta
  String get stop_streaming {
    switch (language) {
      case Language.italian:
        return 'Interrompi risposta';
      case Language.spanish:
        return 'Detener respuesta';
      case Language.english:
      default:
        return 'Stop response';
    }
  }
    /// Tooltip per stoppare lo streaming della risposta
  String get stop_tts {
    switch (language) {
      case Language.italian:
        return 'Arresta lettura';
      case Language.spanish:
        return 'Detener lectura';
      case Language.english:
      default:
        return 'Stop reading';
    }
  }
}



class LocalizationProvider extends InheritedWidget {
  final AppLocalizations localizations;

  const LocalizationProvider({
    Key? key,
    required this.localizations,
    required Widget child,
  }) : super(key: key, child: child);

  static AppLocalizations of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<LocalizationProvider>();
    assert(provider != null, 'No LocalizationProvider found in context');
    return provider!.localizations;
  }

  @override
  bool updateShouldNotify(LocalizationProvider oldWidget) {
    // Se la lingua cambia, notificare i figli
    return localizations.language != oldWidget.localizations.language;
  }

  
}
class LocalizationProviderWrapper extends StatefulWidget {
  final Widget child;

  const LocalizationProviderWrapper({Key? key, required this.child})
      : super(key: key);

  /// Metodo statico per accedere allo stato del wrapper ovunque nel widget tree
  static _LocalizationProviderWrapperState of(BuildContext context) {
    final state = context.findAncestorStateOfType<_LocalizationProviderWrapperState>();
    assert(state != null, 'LocalizationProviderWrapper not found in context');
    return state!;
  }

  @override
  _LocalizationProviderWrapperState createState() =>
      _LocalizationProviderWrapperState();
}

class _LocalizationProviderWrapperState extends State<LocalizationProviderWrapper> {
  /// Lingua corrente
  Language _currentLanguage = Language.english;

  /// Getter per ottenere la lingua corrente
  Language get currentLanguage => _currentLanguage;

  /// Metodo per aggiornare la lingua
  void setLanguage(Language newLanguage) {
    if (_currentLanguage != newLanguage) {
      setState(() {
        _currentLanguage = newLanguage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LocalizationProvider(
      localizations: AppLocalizations(_currentLanguage),
      child: widget.child,
    );
  }
}

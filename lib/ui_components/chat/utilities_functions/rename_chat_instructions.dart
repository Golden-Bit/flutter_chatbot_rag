// append_instruction.dart
String appendChatInstruction(
  String input, {
  required String currentChatName,
  required int messageCount,
}) {
  // Se il nome della chat è "New Chat" oppure se siamo nei primi 4 messaggi
  /*if (currentChatName.trim().toLowerCase() == "new chat" || messageCount < 8) {
    return input +
        "\n\n[ISTRUZIONE AGGIUNTIVA: SVILUPPA UN NOME PER LA CONVERSAIZONE E CAMBIALO USANDO APPOSITO STRUMENTO FORNITO ChangeChatNameWidget. TALE NOME DELLA CHAT SIA SINTETICO E COERENTE, PRENDENDO IN CONSIDERAZIONE IL COTENUTO DELLA CONVERSAIOZNE. USA IL WIDGET APPOSITO ChangeChatNameWidget PER CAMBIARE IL NOME DELLA CHAT, SENZA CHIEDERE IL PERMESSO ALL'UTENTE. NON TI DIMENTICARE DI FARLO]";
  }*/
  return input;
}

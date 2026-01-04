class QuickMessage {
  final String id;
  final String text;
  final String type; // emoji | text

  QuickMessage({
    required this.id,
    required this.text,
    this.type = "text",
  });
}

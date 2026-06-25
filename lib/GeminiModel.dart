class ModelMessage {
  final bool isprompt;
  final String message;
  final DateTime time;

  ModelMessage({
    required this.isprompt,
    required this.message,
    required this.time,
  });
}

class ChatMessage {
  String text;
  bool isUserMessage;
  bool isLoading;

  ChatMessage(
      {required this.text, this.isUserMessage = true, this.isLoading = false});

      //toJson 
      Map<String, dynamic> toJson() => {
        'text': text,
        'isUserMessage': isUserMessage,
        'isLoading': isLoading
      };
      //fromJson
      factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'],
        isUserMessage: json['isUserMessage'],
        isLoading: json['isLoading'],
      );
}

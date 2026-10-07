class ReceiverInfo {
  String? senderId;
  String? senderName;
  String? senderFullName;
  String? message;
  bool? readChat;


  ReceiverInfo({
    this.senderId,
    this.senderName,
    this.senderFullName,
    this.message,
    this.readChat
  });

  factory ReceiverInfo.fromJson(Map<String, dynamic> json) {
    return ReceiverInfo(
      senderId: json['senderId'],
      senderName: json['senderName'],
      senderFullName: json['senderFullName'],
      message: json['message'],
      readChat: json['readChat']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderFullName': senderFullName,
      'message': message,
      'readChat': readChat
    };
  }
}
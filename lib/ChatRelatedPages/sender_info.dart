class SenderInfo {
  String? receiverName;
  String? receiverFullName;
  String? receiverId;
  String? message;
  bool? readChat;

  SenderInfo({
    this.receiverName,
    this.receiverFullName,
    this.receiverId,
    this.message,
    this.readChat
  });

  factory SenderInfo.fromJson(Map<String, dynamic> json) {
    return SenderInfo(
      receiverName: json['receiverName'],
      receiverFullName: json['receiverFullName'],
      receiverId: json['receiverId'],
      message: json['message'],
      readChat: json['readChat']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'receiverName': receiverName,
      'receiverName': receiverFullName,
      'receiverId': receiverId,
      'message': message,
      'readChat': readChat
    };
  }
}
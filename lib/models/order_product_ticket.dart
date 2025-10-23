class OrderProductTicket {

  OrderProductTicket({
    required this.id,
    required this.ticketCode,
    required this.status,
  });

  final int id;
  final String ticketCode;
  final int status;

  factory OrderProductTicket.fromJson(Map<String, dynamic> map) {
    return OrderProductTicket(
      id: map['id'] as int,
      ticketCode: map['ticket_code'] as String,
      status: map['status'] as int,
    );
  }

}
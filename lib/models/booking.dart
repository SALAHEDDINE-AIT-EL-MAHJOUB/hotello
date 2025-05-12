class Booking {
  final String id;
  final String hotelId;
  final String userId;
  final DateTime checkIn;
  final DateTime checkOut;
  final double totalPrice;
  final String status; // 'pending', 'confirmed', 'cancelled'

  Booking({
    required this.id,
    required this.hotelId,
    required this.userId,
    required this.checkIn,
    required this.checkOut,
    required this.totalPrice,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hotelId': hotelId,
      'userId': userId,
      'checkIn': checkIn.millisecondsSinceEpoch,
      'checkOut': checkOut.millisecondsSinceEpoch,
      'totalPrice': totalPrice,
      'status': status,
    };
  }
}
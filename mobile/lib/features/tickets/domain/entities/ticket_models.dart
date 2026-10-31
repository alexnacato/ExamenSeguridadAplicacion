enum SeatState { free, mine, locked, sold }

SeatState seatStateFrom(String value) {
  switch (value) {
    case 'mine':
      return SeatState.mine;
    case 'locked':
      return SeatState.locked;
    case 'sold':
      return SeatState.sold;
    default:
      return SeatState.free;
  }
}

class SeatMap {
  const SeatMap({required this.price, required this.seats});

  final double price;
  final Map<String, SeatState> seats;

  int count(SeatState state) =>
      seats.values.where((value) => value == state).length;
}

class Ticket {
  const Ticket({
    required this.id,
    required this.seat,
    required this.used,
    required this.last4,
  });

  final String id;
  final String seat;
  final bool used;
  final String last4;

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
        id: json['id']?.toString() ?? '',
        seat: json['seat']?.toString() ?? '',
        used: json['used'] == true,
        last4: json['last4']?.toString() ?? '',
      );
}

class PurchaseResult {
  const PurchaseResult({required this.ids, required this.total});

  final List<String> ids;
  final double total;
}

class DynamicQr {
  const DynamicQr({required this.value, required this.rotateSeconds});

  final String value;
  final int rotateSeconds;
}

class Order {
  final String id;
  final String? userId;
  final String? customerName; // New field
  final String? customerPhoneNumber; // New field
  final double totalAmount;
  final String deliveryOption;
  final String? deliveryAddress;
  final String? deliveryTimeSlot;
  final String paymentMethod;
  final String orderStatus;
  final DateTime createdAt;
  final String? deliveryPartnerName;
  final String? deliveryPartnerPhone;
  final List<OrderDetail> items;

  Order({
    required this.id,
    this.userId,
    this.customerName, // New field
    this.customerPhoneNumber, // New field
    required this.totalAmount,
    required this.deliveryOption,
    this.deliveryAddress,
    this.deliveryTimeSlot,
    required this.paymentMethod,
    required this.orderStatus,
    required this.createdAt,
    this.deliveryPartnerName,
    this.deliveryPartnerPhone,
    required this.items,
  });
}

class OrderDetail {
  final int productId;
  final String productName;
  final String? productImageUrl;
  final int quantity;
  final String unit;
  final int? discount;
  final double price;

  OrderDetail({
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.quantity,
    required this.unit,
    this.discount,
    required this.price,
  });

  // Since API returns total price in 'price' field, itemTotal just subtracts discount
  double get itemTotal => price - (discount ?? 0);

  // Calculate unit price from total price and quantity
  double get unitPrice => price / quantity;
}

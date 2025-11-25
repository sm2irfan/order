class Order {
  final String id;
  final String? userId;
  final String? customerName; // New field
  final String? customerPhoneNumber; // New field
  final String? link; // Customer profile link
  final String? geographicCoordinates; // Customer geographic coordinates
  final int? profileNumber; // Customer profile number
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
    this.link, // Customer profile link
    this.geographicCoordinates, // Customer geographic coordinates
    this.profileNumber, // Customer profile number
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

  // Create Order from Map (from database or API)
  factory Order.fromMap(Map<String, dynamic> map, List<OrderDetail> items) {
    return Order(
      id: map['id'],
      userId: map['user_id'],
      customerName: map['customer_name'],
      customerPhoneNumber: map['customer_phone_number'],
      link: map['link'],
      geographicCoordinates: map['geographic_coordinates'],
      profileNumber: map['profile_number'],
      totalAmount: (map['total_amount'] as num).toDouble(),
      deliveryOption: map['delivery_option'],
      deliveryAddress: map['delivery_address'],
      deliveryTimeSlot: map['delivery_time_slot'],
      paymentMethod: map['payment_method'],
      orderStatus: map['order_status'],
      createdAt: DateTime.parse(map['created_at']),
      deliveryPartnerName: map['delivery_partner_name'],
      deliveryPartnerPhone: map['delivery_partner_phone'],
      items: items,
    );
  }

  // Convert Order to Map (for database storage)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'customer_name': customerName,
      'customer_phone_number': customerPhoneNumber,
      'link': link,
      'geographic_coordinates': geographicCoordinates,
      'profile_number': profileNumber,
      'total_amount': totalAmount,
      'delivery_option': deliveryOption,
      'delivery_address': deliveryAddress,
      'delivery_time_slot': deliveryTimeSlot,
      'payment_method': paymentMethod,
      'order_status': orderStatus,
      'created_at': createdAt.toIso8601String(),
      'delivery_partner_name': deliveryPartnerName,
      'delivery_partner_phone': deliveryPartnerPhone,
    };
  }
}

class OrderDetail {
  final int productId;
  final String productName;
  final String? productImageUrl;
  final int quantity;
  final String unit;
  final int? discount;
  final double price;
  final String? stockQuantity; // New field for stock quantity
  final double? profit; // New field for profit

  OrderDetail({
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.quantity,
    required this.unit,
    this.discount,
    required this.price,
    this.stockQuantity, // New field for stock quantity
    this.profit, // New field for profit
  });

  // Create OrderDetail from Map (from database or API)
  factory OrderDetail.fromMap(Map<String, dynamic> map) {
    return OrderDetail(
      productId: map['product_id'],
      productName: map['product_name'] ?? 'Product ${map['product_id']}',
      productImageUrl: map['product_image_url'],
      quantity: map['quantity'],
      unit: map['unit'],
      discount: map['discount'],
      price: (map['price'] as num).toDouble(),
      stockQuantity: map['stock_quantity']?.toString(), // Parse stock quantity
      profit: map['profit'] != null ? (map['profit'] as num).toDouble() : null, // Parse profit
    );
  }

  // Convert OrderDetail to Map (for database storage)
  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'product_image_url': productImageUrl,
      'quantity': quantity,
      'unit': unit,
      'discount': discount,
      'price': price,
      'stock_quantity': stockQuantity, // Include stock quantity in map
      'profit': profit, // Include profit in map
    };
  }

  // Since API returns total price in 'price' field, itemTotal just subtracts discount
  double get itemTotal => price - (discount ?? 0);

  // Calculate unit price from total price and quantity
  double get unitPrice => price / quantity;
}

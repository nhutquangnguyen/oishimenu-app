
enum OrderStatus {
  pending('PENDING'),
  confirmed('CONFIRMED'),
  preparing('PREPARING'),
  ready('READY'),
  outForDelivery('OUT_FOR_DELIVERY'),
  delivered('DELIVERED'),
  cancelled('CANCELLED'),
  failed('FAILED');

  const OrderStatus(this.value);
  final String value;

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => OrderStatus.pending,
    );
  }
}

enum OrderType {
  dineIn('DINE_IN'),
  takeaway('TAKEAWAY'),
  delivery('DELIVERY');

  const OrderType(this.value);
  final String value;

  static OrderType fromString(String value) {
    return OrderType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => OrderType.dineIn,
    );
  }
}

enum PaymentMethod {
  cash('cash'),
  card('card'),
  digitalWallet('digital_wallet'),
  bankTransfer('bank_transfer');

  const PaymentMethod(this.value);
  final String value;

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (method) => method.value == value,
      orElse: () => PaymentMethod.cash,
    );
  }
}

enum PaymentStatus {
  pending('PENDING'),
  paid('PAID'),
  failed('FAILED'),
  refunded('REFUNDED');

  const PaymentStatus(this.value);
  final String value;

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => PaymentStatus.pending,
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final Customer customer;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double tax;
  final double serviceCharge;
  final double total;
  final OrderType orderType;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final DeliveryInfo? deliveryInfo;
  final String? tableNumber;
  final String platform;
  final String? assignedStaff;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.orderNumber,
    required this.customer,
    required this.items,
    required this.subtotal,
    this.deliveryFee = 0.0,
    this.discount = 0.0,
    this.tax = 0.0,
    this.serviceCharge = 0.0,
    required this.total,
    required this.orderType,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    this.deliveryInfo,
    this.tableNumber,
    this.platform = 'direct',
    this.assignedStaff,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id']?.toString() ?? '',
      orderNumber: map['order_number'] ?? '',
      customer: Customer.fromMap({
        'id': map['customer_id']?.toString() ?? '',
        'name': map['customer_name'] ?? '',
        'phone': map['customer_phone'],
        'email': map['customer_email'],
        'address': map['customer_address'],
      }),
      items: [], // Items will be loaded separately from order_items table
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      deliveryFee: (map['delivery_fee'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      tax: (map['tax'] ?? 0).toDouble(),
      serviceCharge: (map['service_charge'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      orderType: OrderType.fromString(map['order_type'] ?? 'DINE_IN'),
      status: OrderStatus.fromString(map['status'] ?? 'PENDING'),
      paymentMethod: PaymentMethod.fromString(map['payment_method'] ?? 'cash'),
      paymentStatus: PaymentStatus.fromString(map['payment_status'] ?? 'PENDING'),
      deliveryInfo: null, // Will be handled separately if needed
      tableNumber: map['table_number'],
      platform: map['platform'] ?? 'direct',
      assignedStaff: map['assigned_staff_id']?.toString(),
      notes: map['notes'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id.isEmpty ? null : int.tryParse(id),
      'order_number': orderNumber,
      'customer_id': customer.id.isEmpty ? null : int.tryParse(customer.id),
      'subtotal': subtotal,
      'delivery_fee': deliveryFee,
      'discount': discount,
      'tax': tax,
      'service_charge': serviceCharge,
      'total': total,
      'order_type': orderType.value,
      'status': status.value,
      'payment_method': paymentMethod.value,
      'payment_status': paymentStatus.value,
      'table_number': tableNumber,
      'platform': platform,
      'assigned_staff_id': assignedStaff?.isEmpty == true ? null : int.tryParse(assignedStaff ?? ''),
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  Order copyWith({
    String? id,
    String? orderNumber,
    Customer? customer,
    List<OrderItem>? items,
    double? subtotal,
    double? deliveryFee,
    double? discount,
    double? tax,
    double? serviceCharge,
    double? total,
    OrderType? orderType,
    OrderStatus? status,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    DeliveryInfo? deliveryInfo,
    String? tableNumber,
    String? platform,
    String? assignedStaff,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customer: customer ?? this.customer,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      total: total ?? this.total,
      orderType: orderType ?? this.orderType,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      deliveryInfo: deliveryInfo ?? this.deliveryInfo,
      tableNumber: tableNumber ?? this.tableNumber,
      platform: platform ?? this.platform,
      assignedStaff: assignedStaff ?? this.assignedStaff,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class OrderItem {
  final String id;
  final String menuItemId;
  final String menuItemName;
  final double basePrice;
  final int quantity;
  final List<SelectedOption> selectedOptions;
  final String? selectedSize;
  final double subtotal;
  final String? notes;

  OrderItem({
    required this.id,
    required this.menuItemId,
    required this.menuItemName,
    required this.basePrice,
    required this.quantity,
    this.selectedOptions = const [],
    this.selectedSize,
    required this.subtotal,
    this.notes,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id']?.toString() ?? '',
      menuItemId: map['menu_item_id']?.toString() ?? '',
      menuItemName: map['menu_item_name'] ?? '',
      basePrice: (map['base_price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
      selectedOptions: [], // Options will be handled separately if needed
      selectedSize: map['selected_size'],
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id.isEmpty ? null : int.tryParse(id),
      'menu_item_id': int.tryParse(menuItemId),
      'menu_item_name': menuItemName,
      'base_price': basePrice,
      'quantity': quantity,
      'selected_size': selectedSize,
      'subtotal': subtotal,
      'notes': notes,
    };
  }
}

class SelectedOption {
  final String optionGroupId;
  final String optionGroupName;
  final String optionId;
  final String optionName;
  final double price;

  SelectedOption({
    required this.optionGroupId,
    required this.optionGroupName,
    required this.optionId,
    required this.optionName,
    required this.price,
  });

  factory SelectedOption.fromMap(Map<String, dynamic> map) {
    return SelectedOption(
      optionGroupId: map['optionGroupId'] ?? '',
      optionGroupName: map['optionGroupName'] ?? '',
      optionId: map['optionId'] ?? '',
      optionName: map['optionName'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'optionGroupId': optionGroupId,
      'optionGroupName': optionGroupName,
      'optionId': optionId,
      'optionName': optionName,
      'price': price,
    };
  }
}

class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
    };
  }
}

class DeliveryInfo {
  final String address;
  final String? city;
  final String? district;
  final String? ward;
  final String? postalCode;
  final String? notes;
  final double? latitude;
  final double? longitude;

  DeliveryInfo({
    required this.address,
    this.city,
    this.district,
    this.ward,
    this.postalCode,
    this.notes,
    this.latitude,
    this.longitude,
  });

  factory DeliveryInfo.fromMap(Map<String, dynamic> map) {
    return DeliveryInfo(
      address: map['address'] ?? '',
      city: map['city'],
      district: map['district'],
      ward: map['ward'],
      postalCode: map['postalCode'],
      notes: map['notes'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'city': city,
      'district': district,
      'ward': ward,
      'postalCode': postalCode,
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
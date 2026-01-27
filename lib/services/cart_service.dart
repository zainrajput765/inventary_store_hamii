import 'package:flutter/foundation.dart';
import '../models/schema.dart';

class CartItem {
  final Product product;
  int quantity;
  double price; // Allows override if needed
  bool isGift;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.isGift = false
  }) : price = product.sellPrice;
}

class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];
  double _discount = 0.0;
  double _tradeInAmount = 0.0;

  List<CartItem> get items => _items;
  double get discount => _discount;
  double get tradeInAmount => _tradeInAmount;

  double get subtotal => _items.fold(0, (sum, item) => sum + (item.price * item.quantity));

  // Logic: Total = (Items Total) - (Discount) - (TradeIn Value)
  // If result is negative, it means we owe the customer money (Refund/Exchange)
  double get total => subtotal - _discount - _tradeInAmount;

  // Alias for compatibility if POS screen uses .totalAmount
  double get totalAmount => total;

  bool addToCart(Product product) {
    // Check if item exists in cart
    final index = _items.indexWhere((item) => item.product.id == product.id);

    // Check stock limit (Prevent selling more than available)
    int currentQtyInCart = index != -1 ? _items[index].quantity : 0;
    if (product.quantity <= currentQtyInCart && product.isMobile) {
      // For mobiles, usually strict 1-to-1 stock check
      return false;
    }

    if (index != -1) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(product: product));
    }
    notifyListeners();
    return true;
  }

  void removeFromCart(CartItem item) { // Accepts CartItem directly for safety
    _items.remove(item);
    notifyListeners();
  }

  // Helper to remove by Product object if needed
  void removeFromCartByProduct(Product product) {
    final index = _items.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void toggleGift(CartItem item) {
    item.isGift = !item.isGift;
    if (item.isGift) {
      item.price = 0; // Gift = Free
    } else {
      item.price = item.product.sellPrice; // Reset to original price
    }
    notifyListeners();
  }

  void setDiscount(double amount) {
    _discount = amount;
    notifyListeners();
  }

  void setTradeIn(double amount) {
    _tradeInAmount = amount;
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _discount = 0.0;
    _tradeInAmount = 0.0;
    notifyListeners();
  }
}
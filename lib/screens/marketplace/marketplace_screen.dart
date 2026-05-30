part of '../../main.dart';

class MarketplaceHomeScreen extends StatefulWidget {
  const MarketplaceHomeScreen({
    super.key,
    required this.userPhone,
    required this.deliveryLabel,
    required this.deliveryPoint,
    this.onSwitchAccount,
  });

  final String userPhone;
  final String deliveryLabel;
  final DemoMapPoint deliveryPoint;
  final VoidCallback? onSwitchAccount;

  @override
  State<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends State<MarketplaceHomeScreen> {
  final MarketplaceService _service = MarketplaceService();
  final TextEditingController _searchCtrl = TextEditingController();
  final List<backend.MarketplaceCartItem> _cart = [];
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _cartCount => _cart.fold(0, (sum, item) => sum + item.quantity);

  void _addToCart(backend.MarketplaceProduct product) {
    if (!product.canCustomerOrder) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} is not available today.')),
      );
      return;
    }
    setState(() {
      final index = _cart.indexWhere((item) => item.productId == product.id);
      if (index == -1) {
        _cart.add(
          backend.MarketplaceCartItem(
            productId: product.id,
            storeId: product.storeId,
            productName: product.name,
            quantity: 1,
            unitPrice: product.price,
            productImageUrl: product.imageUrl,
          ),
        );
      } else {
        _cart[index] = _cart[index].copyWith(
          quantity: _cart[index].quantity + 1,
        );
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${product.name} added to cart')));
  }

  Future<void> _openStore(backend.MarketplaceStore store) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketplaceStoreScreen(
          store: store,
          cart: _cart,
          onCartChanged: (items) => setState(() {
            _cart
              ..clear()
              ..addAll(items);
          }),
          onAddToCart: _addToCart,
          userPhone: widget.userPhone,
          deliveryLabel: widget.deliveryLabel,
          deliveryPoint: widget.deliveryPoint,
          onSwitchAccount: widget.onSwitchAccount,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openCart(List<backend.MarketplaceStore> stores) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketplaceCartScreen(
          cart: _cart,
          stores: stores,
          userPhone: widget.userPhone,
          deliveryLabel: widget.deliveryLabel,
          deliveryPoint: widget.deliveryPoint,
          onSwitchAccount: widget.onSwitchAccount,
          onCartChanged: (items) => setState(() {
            _cart
              ..clear()
              ..addAll(items);
          }),
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<backend.MarketplaceStore>>(
      stream: _service.watchStores(),
      builder: (context, snapshot) {
        final stores = snapshot.data ?? const <backend.MarketplaceStore>[];
        final filteredStores = stores
            .where(
              (store) =>
                  _query.isEmpty ||
                  store.name.toLowerCase().contains(_query.toLowerCase()) ||
                  store.category.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('OMW Marketplace'),
            actions: [
              _CartIconButton(
                count: _cartCount,
                onPressed: () => _openCart(stores),
              ),
              if (widget.onSwitchAccount != null)
                TextButton.icon(
                  onPressed: () =>
                      switchAccountFrom(context, widget.onSwitchAccount!),
                  icon: const Icon(Icons.logout),
                  label: const Text('Switch'),
                ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: kBrandBlack,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'On My Way Marketplace',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Shop essentials, food, gifts, and more with OMW delivery.',
                        style: TextStyle(
                          color: kMutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search stores or products',
                    prefixIcon: Icon(Icons.search, color: kDeepGold),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
                const SizedBox(height: 16),
                _MarketplaceDebugPanel(
                  title: 'Debug marketplace data',
                  lines: [
                    'Stores loaded: ${stores.length}',
                    if (snapshot.hasError) 'Store error: ${snapshot.error}',
                    ...stores.map(
                      (store) =>
                          '${store.name} | ${store.id} | ${store.status} | open=${store.isOpen}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const SectionLabel('Categories'),
                const _MarketplaceCategoryWrap(),
                const SizedBox(height: 20),
                const SectionLabel('Featured stores'),
                const SizedBox(height: 8),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator()
                else if (snapshot.hasError)
                  _MarketplaceEmptyState(
                    icon: Icons.cloud_off_outlined,
                    text:
                        'Could not load marketplace stores: ${snapshot.error}',
                  )
                else if (filteredStores.isEmpty)
                  const _MarketplaceEmptyState(
                    icon: Icons.storefront_outlined,
                    text: 'No marketplace stores are available right now.',
                  )
                else
                  ...filteredStores.map(
                    (store) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MarketplaceStoreCard(
                        store: store,
                        onTap: () => _openStore(store),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const SectionLabel('Popular products'),
                const SizedBox(height: 8),
                _PopularProductsStrip(onAddToCart: _addToCart),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MarketplaceStoreScreen extends StatelessWidget {
  const MarketplaceStoreScreen({
    super.key,
    required this.store,
    required this.cart,
    required this.onCartChanged,
    required this.onAddToCart,
    required this.userPhone,
    required this.deliveryLabel,
    required this.deliveryPoint,
    this.onSwitchAccount,
  });

  final backend.MarketplaceStore store;
  final List<backend.MarketplaceCartItem> cart;
  final ValueChanged<List<backend.MarketplaceCartItem>> onCartChanged;
  final ValueChanged<backend.MarketplaceProduct> onAddToCart;
  final String userPhone;
  final String deliveryLabel;
  final DemoMapPoint deliveryPoint;
  final VoidCallback? onSwitchAccount;

  @override
  Widget build(BuildContext context) {
    final service = MarketplaceService();
    final cartCount = cart.fold(0, (sum, item) => sum + item.quantity);
    return Scaffold(
      appBar: AppBar(
        title: Text(store.name),
        actions: [
          _CartIconButton(
            count: cartCount,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MarketplaceCartScreen(
                  cart: cart,
                  stores: [store],
                  userPhone: userPhone,
                  deliveryLabel: deliveryLabel,
                  deliveryPoint: deliveryPoint,
                  onSwitchAccount: onSwitchAccount,
                  onCartChanged: onCartChanged,
                ),
              ),
            ),
          ),
          if (onSwitchAccount != null)
            TextButton.icon(
              onPressed: () => switchAccountFrom(context, onSwitchAccount!),
              icon: const Icon(Icons.logout),
              label: const Text('Switch'),
            ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<backend.MarketplaceProduct>>(
          stream: service.watchProductsByStore(store.id),
          builder: (context, snapshot) {
            final products =
                snapshot.data ?? const <backend.MarketplaceProduct>[];
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _StoreHero(store: store),
                const SizedBox(height: 18),
                _MarketplaceDebugPanel(
                  title: 'Debug selected store',
                  lines: [
                    'Selected store: ${store.name}',
                    'Selected store id: ${store.id}',
                    'Products loaded: ${products.length}',
                    if (snapshot.hasError) 'Product error: ${snapshot.error}',
                  ],
                ),
                const SizedBox(height: 18),
                const SectionLabel('Products'),
                const SizedBox(height: 8),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator()
                else if (products.isEmpty)
                  const _MarketplaceEmptyState(
                    icon: Icons.inventory_2_outlined,
                    text: 'No products available from this store yet.',
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.6,
                        ),
                    itemBuilder: (context, index) {
                      return _ProductCard(
                        product: products[index],
                        onAdd: () => onAddToCart(products[index]),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MarketplaceDebugPanel extends StatelessWidget {
  const _MarketplaceDebugPanel({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(
            lines.isEmpty ? 'No debug data.' : lines.join('\n'),
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class MarketplaceCartScreen extends StatefulWidget {
  const MarketplaceCartScreen({
    super.key,
    required this.cart,
    required this.stores,
    required this.userPhone,
    required this.deliveryLabel,
    required this.deliveryPoint,
    this.onSwitchAccount,
    required this.onCartChanged,
  });

  final List<backend.MarketplaceCartItem> cart;
  final List<backend.MarketplaceStore> stores;
  final String userPhone;
  final String deliveryLabel;
  final DemoMapPoint deliveryPoint;
  final VoidCallback? onSwitchAccount;
  final ValueChanged<List<backend.MarketplaceCartItem>> onCartChanged;

  @override
  State<MarketplaceCartScreen> createState() => _MarketplaceCartScreenState();
}

class _MarketplaceCartScreenState extends State<MarketplaceCartScreen> {
  final MarketplaceService _service = MarketplaceService();
  final AuthService _authService = AuthService();
  final TextEditingController _notesCtrl = TextEditingController();
  late List<backend.MarketplaceCartItem> _items;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.cart);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.total);
  double get _deliveryFee => _items.isEmpty ? 0 : 3.0;
  double get _total => _subtotal + _deliveryFee;

  void _sync() => widget.onCartChanged(List.of(_items));

  void _changeQuantity(backend.MarketplaceCartItem item, int delta) {
    setState(() {
      final index = _items.indexWhere(
        (entry) => entry.productId == item.productId,
      );
      if (index == -1) return;
      final nextQuantity = _items[index].quantity + delta;
      if (nextQuantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(quantity: nextQuantity);
      }
    });
    _sync();
  }

  Future<void> _placeOrder() async {
    if (_items.isEmpty || _placing) return;
    if (_paymentMethod == PaymentMethod.card) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card payments coming soon.')),
      );
      return;
    }
    setState(() => _placing = true);
    final store = widget.stores.firstWhere(
      (candidate) => candidate.id == _items.first.storeId,
      orElse: () => MarketplaceService.sampleStores.first,
    );
    final user = _authService.currentUser;
    if (FirebaseService.instance.isReady && user == null) {
      setState(() => _placing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again to place order.')),
      );
      return;
    }
    final customerId = user?.uid ?? 'local-customer';
    try {
      final order = backend.MarketplaceOrder(
        id: '',
        customerId: customerId,
        customerPhone: user?.phoneNumber ?? widget.userPhone,
        storeId: store.id,
        storeName: store.name,
        storeAddress: store.address,
        storeLat: store.lat,
        storeLng: store.lng,
        items: _items,
        subtotal: _subtotal,
        deliveryFee: _deliveryFee,
        total: _total,
        paymentMethod: backendPaymentMethodFor(_paymentMethod),
        deliveryLabel: widget.deliveryLabel,
        deliveryLat: widget.deliveryPoint.latitude,
        deliveryLng: widget.deliveryPoint.longitude,
        status: backend.MarketplaceOrderStatus.pending,
        createdAt: DateTime.now(),
      );
      final orderId = await _service.createMarketplaceOrder(order);
      if (!mounted) return;
      setState(() {
        _items.clear();
        _placing = false;
      });
      _sync();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your OMW Marketplace order was placed')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MarketplaceTrackingScreen(
            order: order.copyWith(id: orderId ?? order.id),
            onSwitchAccount: widget.onSwitchAccount,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _placing = false);
      final message = error is StateError
          ? error.message
          : 'Could not place this marketplace order.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OMW Cart'),
        actions: [
          if (widget.onSwitchAccount != null)
            TextButton.icon(
              onPressed: () =>
                  switchAccountFrom(context, widget.onSwitchAccount!),
              icon: const Icon(Icons.logout),
              label: const Text('Switch'),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_items.isEmpty)
              const _StateMessage(
                icon: Icons.shopping_bag_outlined,
                text: 'Your OMW Marketplace cart is empty.',
              )
            else
              ..._items.map(
                (item) => _CartItemTile(
                  item: item,
                  onDecrease: () => _changeQuantity(item, -1),
                  onIncrease: () => _changeQuantity(item, 1),
                  onRemove: () => _changeQuantity(item, -item.quantity),
                ),
              ),
            const SizedBox(height: 16),
            const SectionLabel('Delivery'),
            TextFormField(
              key: ValueKey(widget.deliveryLabel),
              initialValue: widget.deliveryLabel,
              readOnly: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_on_outlined, color: kDeepGold),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Add delivery notes',
                prefixIcon: Icon(Icons.notes_outlined, color: kDeepGold),
              ),
            ),
            const SizedBox(height: 16),
            const SectionLabel('Payment'),
            _PaymentSelector(
              selected: _paymentMethod,
              onChanged: (method) => setState(() => _paymentMethod = method),
            ),
            const SizedBox(height: 16),
            _CartTotals(
              subtotal: _subtotal,
              deliveryFee: _deliveryFee,
              total: _total,
            ),
            const SizedBox(height: 18),
            PrimaryCtaButton(
              label: _placing ? 'Placing order...' : 'Place marketplace order',
              onPressed: _placing || _items.isEmpty ? null : _placeOrder,
            ),
          ],
        ),
      ),
    );
  }
}

class MarketplaceTrackingScreen extends StatelessWidget {
  const MarketplaceTrackingScreen({
    super.key,
    required this.order,
    this.onSwitchAccount,
  });

  final backend.MarketplaceOrder order;
  final VoidCallback? onSwitchAccount;

  int _stepFor(backend.MarketplaceOrderStatus status) {
    return switch (status) {
      backend.MarketplaceOrderStatus.pending => 0,
      backend.MarketplaceOrderStatus.accepted => 1,
      backend.MarketplaceOrderStatus.shopping => 2,
      backend.MarketplaceOrderStatus.pickedUp => 3,
      backend.MarketplaceOrderStatus.onTheWay => 4,
      backend.MarketplaceOrderStatus.delivered => 5,
      backend.MarketplaceOrderStatus.cancelled => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final steps = const [
      'Order received',
      'Courier accepted',
      'Shopping/preparing',
      'Picked up',
      'On the way',
      'Delivered',
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace tracking'),
        actions: [
          if (onSwitchAccount != null)
            TextButton.icon(
              onPressed: () => switchAccountFrom(context, onSwitchAccount!),
              icon: const Icon(Icons.logout),
              label: const Text('Switch'),
            ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<backend.MarketplaceOrder?>(
          stream: MarketplaceService().watchMarketplaceOrder(order.id),
          builder: (context, snapshot) {
            final current = snapshot.data ?? order;
            final activeStep = _stepFor(current.status);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: kBrandBlack,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OMW Marketplace order',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        current.storeName,
                        style: const TextStyle(
                          color: kAccentYellow,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${current.itemCount} items - \$${current.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: kMutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ...steps.indexed.map(
                  (entry) => _MarketplaceTimelineStep(
                    label: entry.$2,
                    active: entry.$1 == activeStep,
                    complete: entry.$1 < activeStep,
                  ),
                ),
                const SizedBox(height: 16),
                _StateMessage(
                  icon: Icons.delivery_dining,
                  text: current.assignedWorkerName == null
                      ? 'Waiting for an approved OMW courier to accept.'
                      : '${current.assignedWorkerName} accepted this marketplace delivery.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CartIconButton extends StatelessWidget {
  const _CartIconButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: const Icon(Icons.shopping_cart_outlined),
          tooltip: 'Cart',
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: CircleAvatar(
              radius: 9,
              backgroundColor: kAccentYellow,
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: kBrandBlack,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MarketplaceCategoryWrap extends StatelessWidget {
  const _MarketplaceCategoryWrap();

  static const categories = [
    ('Grocery', Icons.local_grocery_store_outlined),
    ('Pharmacy', Icons.local_pharmacy_outlined),
    ('Restaurants', Icons.restaurant_outlined),
    ('Electronics', Icons.devices_other),
    ('Gifts', Icons.card_giftcard),
    ('Convenience', Icons.storefront_outlined),
    ('Beauty', Icons.spa_outlined),
    ('Pet supplies', Icons.pets_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories
          .map(
            (category) => Chip(
              avatar: Icon(category.$2, size: 18, color: kBrandBlack),
              label: Text(category.$1),
              backgroundColor: kAccentYellow.withValues(alpha: 0.28),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              side: BorderSide(color: kDeepGold.withValues(alpha: 0.25)),
            ),
          )
          .toList(),
    );
  }
}

class _MarketplaceStoreCard extends StatelessWidget {
  const _MarketplaceStoreCard({required this.store, required this.onTap});

  final backend.MarketplaceStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _MarketplaceImagePlaceholder(icon: Icons.storefront_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${store.category} - ${store.deliveryEstimateMinutes} min',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${store.rating.toStringAsFixed(1)} rating - ${store.isCustomerOrderable ? 'Open' : 'Store closed'}',
                  style: TextStyle(
                    color: store.isCustomerOrderable
                        ? Colors.green.shade700
                        : Colors.grey,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: store.isCustomerOrderable ? onTap : null,
            child: const Text('Shop now'),
          ),
        ],
      ),
    );
  }
}

class _PopularProductsStrip extends StatelessWidget {
  const _PopularProductsStrip({required this.onAddToCart});

  final ValueChanged<backend.MarketplaceProduct> onAddToCart;

  @override
  Widget build(BuildContext context) {
    final products = MarketplaceService.sampleProductsForStore(
      'omw-grocery',
    ).take(4).toList();
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final product = products[index];
          return SizedBox(
            width: 142,
            child: _ProductCard(
              product: product,
              onAdd: () => onAddToCart(product),
            ),
          );
        },
      ),
    );
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero({required this.store});

  final backend.MarketplaceStore store;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBrandBlack,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const _MarketplaceImagePlaceholder(icon: Icons.storefront_outlined),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${store.category} - ${store.address}',
                  style: const TextStyle(
                    color: kMutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${store.deliveryEstimateMinutes} min delivery - ${store.rating.toStringAsFixed(1)} rating',
                  style: const TextStyle(
                    color: kAccentYellow,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onAdd});

  final backend.MarketplaceProduct product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final stockLabel = switch (product.stockStatus) {
      'out_of_stock' => 'Out of stock',
      'low_stock' => 'Low stock',
      _ => 'In stock',
    };
    final stockColor = switch (product.stockStatus) {
      'out_of_stock' => Colors.red.shade700,
      'low_stock' => kDeepGold,
      _ => Colors.green.shade700,
    };
    final available = product.canCustomerOrder;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(
            child: _MarketplaceImagePlaceholder(
              icon: Icons.shopping_bag_outlined,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            product.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            !product.isVisibleToCustomers || !product.isAvailable
                ? 'Unavailable today'
                : stockLabel,
            style: TextStyle(
              color: available ? stockColor : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: kDeepGold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.filled(
                onPressed: available ? onAdd : null,
                icon: const Icon(Icons.add),
                tooltip: 'Add to cart',
                style: IconButton.styleFrom(
                  backgroundColor: kAccentYellow,
                  foregroundColor: kBrandBlack,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarketplaceImagePlaceholder extends StatelessWidget {
  const _MarketplaceImagePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: kAccentYellow.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: kDeepGold),
    );
  }
}

class _MarketplaceEmptyState extends StatelessWidget {
  const _MarketplaceEmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: kDeepGold, size: 34),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final backend.MarketplaceCartItem item;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          item.productName,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}',
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(onPressed: onDecrease, icon: const Icon(Icons.remove)),
            Text(
              item.quantity.toString(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            IconButton(onPressed: onIncrease, icon: const Icon(Icons.add)),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartTotals extends StatelessWidget {
  const _CartTotals({
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
  });

  final double subtotal;
  final double deliveryFee;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBrandBlack,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _KeyValueRow(
            label: 'Subtotal',
            value: '\$${subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          _KeyValueRow(
            label: 'Delivery fee',
            value: '\$${deliveryFee.toStringAsFixed(2)}',
          ),
          const Divider(color: kMutedText),
          _KeyValueRow(label: 'Total', value: '\$${total.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}

class _MarketplaceTimelineStep extends StatelessWidget {
  const _MarketplaceTimelineStep({
    required this.label,
    required this.active,
    required this.complete,
  });

  final String label;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: active || complete
            ? kAccentYellow
            : Colors.grey.shade300,
        child: Icon(
          complete ? Icons.check : Icons.circle,
          size: 14,
          color: kBrandBlack,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: active ? FontWeight.w900 : FontWeight.w700,
          color: active ? kBrandBlack : Colors.grey.shade700,
        ),
      ),
    );
  }
}

class _PlacesSuggestionList extends StatelessWidget {
  const _PlacesSuggestionList({
    required this.suggestions,
    required this.onSelected,
  });

  final List<PlaceSuggestion> suggestions;
  final ValueChanged<PlaceSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: suggestions.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, indent: 54, color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              dense: true,
              minLeadingWidth: 28,
              leading: const Icon(Icons.place_outlined, color: kAccentBlue),
              title: Text(
                suggestion.mainText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: suggestion.secondaryText.isEmpty
                  ? null
                  : Text(
                      suggestion.secondaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => onSelected(suggestion),
            );
          },
        ),
      ),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard({required this.estimate, required this.loading});

  final RouteEstimate? estimate;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAccentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            const Icon(Icons.route, color: kAccentBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loading
                  ? 'Calculating estimate...'
                  : '${estimate!.isFallback ? 'Approx. estimate\n' : ''}'
                        'Estimated distance: ${estimate!.distanceText}\n'
                        'Estimated time: ${estimate!.durationText}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (estimate?.isFallback == true)
            Tooltip(
              message: 'Fallback estimate',
              child: Icon(Icons.info_outline, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$$amount',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RecommendedOfferCard extends StatelessWidget {
  const _RecommendedOfferCard({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAccentYellow.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccentYellow),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF8A6D00)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Recommended offer',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '\$$amount',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _OfferSlider extends StatelessWidget {
  const _OfferSlider({
    required this.amount,
    required this.band,
    required this.onChanged,
  });

  final int amount;
  final PriceBand band;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your offer',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '\$$amount',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            min: band.minimum.toDouble(),
            max: band.maximum.toDouble(),
            divisions: math.max(1, band.maximum - band.minimum),
            value: amount.toDouble(),
            activeColor: kAccentYellow,
            inactiveColor: Colors.grey.shade300,
            label: '\$$amount',
            onChanged: (value) => onChanged(value.round()),
          ),
          Row(
            children: [
              Text(
                '\$${band.minimum}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '\$${band.maximum}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text('$label - \$$value'),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: kAccentYellow.withValues(alpha: 0.5),
      checkmarkColor: Colors.black87,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.black87 : Colors.grey.shade800,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    );
  }
}

class _OnlineDriverPreview extends StatelessWidget {
  const _OnlineDriverPreview({required this.service});

  final ServiceType service;

  @override
  Widget build(BuildContext context) {
    final drivers = onlineDriversFor(service);
    if (drivers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'No OMW drivers online right now. A test driver can go online from OMW Driver.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }
    final driver = drivers.first;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAccentYellow.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.radio_button_checked, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${driver.name} is online with OMW - ${driver.etaMin} min away',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSelector extends StatelessWidget {
  const _PaymentSelector({required this.selected, required this.onChanged});

  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PaymentOption(
            method: PaymentMethod.cash,
            selected: selected == PaymentMethod.cash,
            onTap: () => onChanged(PaymentMethod.cash),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PaymentOption(
            method: PaymentMethod.card,
            selected: selected == PaymentMethod.card,
            onTap: () => onChanged(PaymentMethod.card),
          ),
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = method == PaymentMethod.cash
        ? Icons.payments_outlined
        : Icons.credit_card;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? kAccentYellow.withValues(alpha: 0.32)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kDeepGold : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? kBrandBlack : Colors.grey.shade700),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                paymentLabel(method),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? kBrandBlack : Colors.black87,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

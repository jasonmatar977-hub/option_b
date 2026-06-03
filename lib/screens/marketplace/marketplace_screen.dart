part of '../../main.dart';

class MarketplaceHomeScreen extends StatefulWidget {
  const MarketplaceHomeScreen({
    super.key,
    required this.userPhone,
    required this.deliveryLabel,
    required this.deliveryPoint,
    this.onSwitchAccount,
    this.showAsRootTab = false,
  });

  final String userPhone;
  final String deliveryLabel;
  final DemoMapPoint deliveryPoint;
  final VoidCallback? onSwitchAccount;
  // When true: suppress the back button and Switch action (root of bottom-nav shell).
  final bool showAsRootTab;

  @override
  State<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends State<MarketplaceHomeScreen> {
  final MarketplaceService _service = MarketplaceService();
  final TextEditingController _searchCtrl = TextEditingController();
  final List<backend.MarketplaceCartItem> _cart = [];
  final GooglePlacesService _placesService = const GooglePlacesService();
  String _query = '';
  String? _selectedCategory;
  // null = curated home mode; set = show filtered collection list
  _MarketplaceCollectionFilter? _activeCollectionFilter;

  bool get _isHomeMode =>
      _query.isEmpty &&
      _selectedCategory == null &&
      _activeCollectionFilter == null;
  late String _deliveryLabel;
  late DemoMapPoint _deliveryPoint;

  @override
  void initState() {
    super.initState();
    _deliveryLabel = widget.deliveryLabel;
    _deliveryPoint = widget.deliveryPoint;
  }

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
          deliveryLabel: _deliveryLabel,
          deliveryPoint: _deliveryPoint,
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
          deliveryLabel: _deliveryLabel,
          deliveryPoint: _deliveryPoint,
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

  Future<void> _openLocationPicker() async {
    final result = await showModalBottomSheet<_MarketplaceLocationResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _MarketplaceLocationSheet(
        initialLabel: _deliveryLabel,
        initialPoint: _deliveryPoint,
        placesService: _placesService,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _deliveryLabel = result.label;
      _deliveryPoint = result.point;
    });
  }

  void _selectCollection(_MarketplaceCollectionFilter filter) {
    setState(() {
      // Tap same card = deselect and return to curated home
      if (_activeCollectionFilter == filter) {
        _activeCollectionFilter = null;
        _selectedCategory = null;
        return;
      }
      _activeCollectionFilter = filter;
      _selectedCategory = null;
      _searchCtrl.clear();
      _query = '';
    });
  }

  bool _matchesSearch(backend.MarketplaceStore store, String storeCategory) {
    final normalizedQuery = _query.toLowerCase();
    return _query.isEmpty ||
        store.name.toLowerCase().contains(normalizedQuery) ||
        backend
            .marketplaceCategoryLabel(storeCategory)
            .toLowerCase()
            .contains(normalizedQuery) ||
        store.description.toLowerCase().contains(normalizedQuery);
  }

  bool _matchesCollection(backend.MarketplaceStore store) {
    final filter = _activeCollectionFilter;
    if (filter == null) return true;
    final category = backend.normalizeMarketplaceCategory(store.category);
    return switch (filter) {
      _MarketplaceCollectionFilter.freeDelivery => store.freeDeliveryEnabled,
      _MarketplaceCollectionFilter.firstOrderDeals =>
        store.firstOrderDealEnabled || store.discountEnabled,
      _MarketplaceCollectionFilter.openNow => store.isCustomerOrderable,
      _MarketplaceCollectionFilter.popularNearYou => store.isCustomerVisible,
      _MarketplaceCollectionFilter.newOnOmw => store.isCustomerVisible,
      _MarketplaceCollectionFilter.essentials =>
        category == 'grocery' || category == 'convenience_store',
      _MarketplaceCollectionFilter.sweetCravings =>
        category == 'bakery' || category == 'coffee_shop',
      _MarketplaceCollectionFilter.quickLunch =>
        category == 'restaurant' || category == 'coffee_shop',
      _MarketplaceCollectionFilter.familyMeals => category == 'restaurant',
      _MarketplaceCollectionFilter.bestRated =>
        store.rating > 0 && store.isCustomerVisible,
      _MarketplaceCollectionFilter.coffeeBreakfast =>
        category == 'coffee_shop' || category == 'bakery',
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<backend.MarketplaceStore>>(
      stream: _service.watchStores(),
      builder: (context, snapshot) {
        final stores = snapshot.data ?? const <backend.MarketplaceStore>[];
        final storeById = {for (final store in stores) store.id: store};

        // Filtered list — used when search / category / collection is active
        final filteredStores = stores.where((store) {
          final storeCategory = backend.normalizeMarketplaceCategory(
            store.category,
          );
          final matchesCategory =
              _selectedCategory == null || storeCategory == _selectedCategory;
          return matchesCategory &&
              _matchesSearch(store, storeCategory) &&
              _matchesCollection(store);
        }).toList();
        if (_activeCollectionFilter == _MarketplaceCollectionFilter.newOnOmw) {
          filteredStores.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
        } else if (_activeCollectionFilter ==
            _MarketplaceCollectionFilter.bestRated) {
          filteredStores.sort((a, b) => b.rating.compareTo(a.rating));
        }

        // Curated home sections (pre-computed when no filter active)
        final featuredStores = stores
            .where((s) => s.featuredEnabled && s.isCustomerVisible)
            .toList();
        final openNowStores = stores
            .where((s) => s.isCustomerOrderable)
            .toList();
        final sweetCravingStores = stores
            .where(
              (s) =>
                  (backend.normalizeMarketplaceCategory(s.category) ==
                          'bakery' ||
                      backend.normalizeMarketplaceCategory(s.category) ==
                          'coffee_shop') &&
                  s.isCustomerVisible,
            )
            .toList();
        final freshGroceryStores = stores
            .where(
              (s) =>
                  (backend.normalizeMarketplaceCategory(s.category) ==
                          'grocery' ||
                      backend.normalizeMarketplaceCategory(s.category) ==
                          'convenience_store' ||
                      backend.normalizeMarketplaceCategory(s.category) ==
                          'pharmacy') &&
                  s.isCustomerVisible,
            )
            .toList();
        final newStores = stores.where((s) => s.isCustomerVisible).toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
          );

        final activeFilterLabel = _activeCollectionFilter != null
            ? _marketplaceCollectionLabel(_activeCollectionFilter!)
            : _selectedCategory != null
            ? backend.marketplaceCategoryLabel(_selectedCategory!)
            : _query.isNotEmpty
            ? 'Search results'
            : 'All stores';

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            automaticallyImplyLeading: !widget.showAsRootTab,
            leading: widget.showAsRootTab
                ? null
                : OmwBackButton(
                    fallback: widget.onSwitchAccount == null
                        ? null
                        : () => switchAccountFrom(
                            context,
                            widget.onSwitchAccount!,
                          ),
                  ),
            title: const Text('OMW Marketplace'),
            actions: [
              _CartIconButton(
                count: _cartCount,
                onPressed: () => _openCart(stores),
              ),
              if (!widget.showAsRootTab && widget.onSwitchAccount != null)
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
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // ── Location header ───────────────────────────────────────
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _MarketplaceTopHeader(
                    deliveryLabel: _deliveryLabel,
                    onLocationTap: _openLocationPicker,
                  ),
                ),
                const SizedBox(height: 14),

                // ── ONE search bar ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _MarketplaceSearchBar(
                    controller: _searchCtrl,
                    onChanged: (value) => setState(() {
                      _query = value.trim();
                      if (_query.isNotEmpty) {
                        _activeCollectionFilter = null;
                        _selectedCategory = null;
                      }
                    }),
                  ),
                ),
                const SizedBox(height: 12),

                // ── ONE horizontal category row ───────────────────────────
                _MarketplaceCategoryScroller(
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (cat) => setState(() {
                    _selectedCategory = _selectedCategory == cat ? null : cat;
                    _activeCollectionFilter = null;
                    _searchCtrl.clear();
                    _query = '';
                  }),
                ),
                const SizedBox(height: 14),

                // ── Animated promo carousel ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _MarketplacePromoCarousel(
                    selectedFilter: _activeCollectionFilter,
                    onSelected: _selectCollection,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Body: curated home feed OR filtered list ──────────────
                if (_isHomeMode) ...[
                  // CURATED HOME FEED ─────────────────────────────────────

                  // Featured stores
                  _MarketplaceCuratedSection(
                    title: 'Featured stores',
                    stores: featuredStores,
                    onTap: _openStore,
                    emptyText: null, // hide section when empty
                  ),

                  // Open now
                  _MarketplaceCuratedSection(
                    title: 'Open now',
                    stores: openNowStores,
                    onTap: _openStore,
                    emptyText: 'No stores open right now. Check back later.',
                  ),

                  // Popular products rail
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _MarketplaceSectionHeader(title: 'Popular products'),
                  ),
                  _MarketplaceProductsRail(
                    service: _service,
                    stores: stores,
                    storeById: storeById,
                    selectedCategory: null,
                    collectionFilter:
                        _MarketplaceCollectionFilter.popularNearYou,
                    query: '',
                    onAddToCart: _addToCart,
                  ),
                  const SizedBox(height: 20),

                  // Sweet cravings
                  _MarketplaceCuratedSection(
                    title: 'Sweet cravings',
                    stores: sweetCravingStores,
                    onTap: _openStore,
                    emptyText: null,
                  ),

                  // Fresh groceries
                  _MarketplaceCuratedSection(
                    title: 'Fresh groceries',
                    stores: freshGroceryStores,
                    onTap: _openStore,
                    emptyText: null,
                  ),

                  // New on OMW
                  _MarketplaceCuratedSection(
                    title: 'New on OMW',
                    stores: newStores.take(8).toList(),
                    onTap: _openStore,
                    emptyText: null,
                  ),

                  // All stores fallback when no curated section has data
                  if (featuredStores.isEmpty &&
                      openNowStores.isEmpty &&
                      sweetCravingStores.isEmpty &&
                      freshGroceryStores.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _MarketplaceSectionHeader(title: 'All stores'),
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: LinearProgressIndicator(),
                      )
                    else if (stores.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: _MarketplaceEmptyState(
                          icon: Icons.storefront_outlined,
                          text:
                              'No approved stores yet. Stores appear here after admin approval.',
                        ),
                      )
                    else
                      ...stores.map(
                        (store) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _MarketplaceStoreCard(
                            store: store,
                            onTap: () => _openStore(store),
                          ),
                        ),
                      ),
                  ],
                ] else ...[
                  // FILTERED LIST ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _MarketplaceSectionHeader(
                      title: activeFilterLabel,
                      actionLabel: 'Clear',
                      onAction: () => setState(() {
                        _activeCollectionFilter = null;
                        _selectedCategory = null;
                        _searchCtrl.clear();
                        _query = '';
                      }),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: LinearProgressIndicator(),
                    )
                  else if (snapshot.hasError)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _MarketplaceEmptyState(
                        icon: Icons.storefront_outlined,
                        text: 'Could not load stores. Check your connection.',
                      ),
                    )
                  else if (filteredStores.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _MarketplaceEmptyState(
                        icon: Icons.storefront_outlined,
                        text: 'No matches. Try a different filter or search.',
                      ),
                    )
                  else
                    ...filteredStores.map(
                      (store) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _MarketplaceStoreCard(
                          store: store,
                          onTap: () => _openStore(store),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _MarketplaceSectionHeader(
                      title: 'Trending products',
                    ),
                  ),
                  _MarketplaceProductsRail(
                    service: _service,
                    stores: stores,
                    storeById: storeById,
                    selectedCategory: _selectedCategory,
                    collectionFilter:
                        _activeCollectionFilter ??
                        _MarketplaceCollectionFilter.popularNearYou,
                    query: _query,
                    onAddToCart: _addToCart,
                  ),
                  const SizedBox(height: 16),
                ],
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
        leading: OmwBackButton(
          fallback: onSwitchAccount == null
              ? null
              : () => switchAccountFrom(context, onSwitchAccount!),
        ),
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
  late final TextEditingController _deliveryCtrl;
  final GooglePlacesService _placesService = const GooglePlacesService();
  late List<backend.MarketplaceCartItem> _items;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  DemoMapPoint? _deliveryPoint;
  String _deliveryPlaceId = '';
  List<PlaceSuggestion> _deliverySuggestions = const [];
  bool _locating = false;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.cart);
    _deliveryCtrl = TextEditingController(text: widget.deliveryLabel);
    _deliveryPoint = widget.deliveryLabel.trim().isEmpty
        ? null
        : widget.deliveryPoint;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _deliveryCtrl.dispose();
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

  void _updateDeliverySuggestions(String value) {
    setState(() {
      _deliverySuggestions = _placesService.localSuggestions(value);
    });
  }

  void _selectDeliverySuggestion(PlaceSuggestion suggestion) {
    setState(() {
      _deliveryCtrl.text = suggestion.description;
      _deliveryPlaceId = suggestion.placeId;
      _deliveryPoint = suggestion.localPoint ?? _deliveryPoint;
      _deliverySuggestions = const [];
    });
  }

  void _setDeliveryPoint(DemoMapPoint point) {
    setState(() {
      _deliveryPoint = point;
      if (_deliveryCtrl.text.trim().isEmpty) {
        _deliveryCtrl.text =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final result = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (result.point != null) {
      _setDeliveryPoint(result.point!);
      if (_deliveryCtrl.text.trim().isEmpty) {
        _deliveryCtrl.text = 'Current location';
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Could not get current location.'),
        ),
      );
    }
  }

  Future<void> _placeOrder() async {
    if (_items.isEmpty || _placing) return;
    final deliveryLabel = _deliveryCtrl.text.trim();
    final deliveryPoint = _deliveryPoint;
    if (deliveryLabel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a delivery location first.')),
      );
      return;
    }
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
        customerName: user?.displayName ?? '',
        customerPhone: user?.phoneNumber ?? widget.userPhone,
        customerEmail: user?.email ?? '',
        storeId: store.id,
        storeOwnerId: store.ownerId,
        storeName: store.name,
        storeAddress: store.addressLabel.isEmpty
            ? store.address
            : store.addressLabel,
        storeLat: store.lat,
        storeLng: store.lng,
        storePlaceId: store.placeId,
        items: _items,
        subtotal: _subtotal,
        deliveryFee: _deliveryFee,
        total: _total,
        paymentMethod: backendPaymentMethodFor(_paymentMethod),
        deliveryLabel: deliveryLabel,
        deliveryLat: deliveryPoint?.latitude ?? 0,
        deliveryLng: deliveryPoint?.longitude ?? 0,
        deliveryPlaceId: _deliveryPlaceId,
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
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _placing = false);
      debugPrint(
        '[Marketplace] Place order FirebaseException: ${error.code} ${error.message}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place order: ${error.code}')),
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
        leading: OmwBackButton(
          fallback: widget.onSwitchAccount == null
              ? null
              : () => switchAccountFrom(context, widget.onSwitchAccount!),
        ),
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
            TextField(
              controller: _deliveryCtrl,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Delivery address',
                hintText: 'Enter delivery address or pick on map',
                prefixIcon: Icon(Icons.location_on_outlined, color: kDeepGold),
              ),
              onChanged: _updateDeliverySuggestions,
            ),
            if (_deliverySuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PlacesSuggestionList(
                suggestions: _deliverySuggestions,
                onSelected: _selectDeliverySuggestion,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _locating ? null : _useCurrentLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_outlined),
                    label: Text(
                      _locating ? 'Locating...' : 'Use current location',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppMap(
              pickup: _deliveryPoint ?? widget.deliveryPoint,
              destination: _deliveryPoint,
              height: 180,
              gesturesEnabled: false,
              onMapTap: _setDeliveryPoint,
              offerMarkers: [
                if (_deliveryPoint != null)
                  DemoMapMarker(
                    id: 'delivery',
                    point: _deliveryPoint!,
                    label: 'Delivery',
                    icon: Icons.location_on,
                  ),
              ],
            ),
            if (!kUseGoogleMaps) ...[
              const SizedBox(height: 8),
              const Text(
                'Maps are not configured. Manual address will be saved for this order.',
                style: TextStyle(
                  color: kMutedText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
            if (_deliveryPoint == null) ...[
              const SizedBox(height: 8),
              const Text(
                'No map pin selected. The order will still save the address, but distance filtering will need coordinates later.',
                style: TextStyle(
                  color: kMutedText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
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

  // Maps order status to the store-side progress step index (0-5).
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

  String _shortId(String id) =>
      id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  String _deliveryStatusLabel(String deliveryStatus) {
    return switch (deliveryStatus) {
      backend.MarketplaceDeliveryStatus.none || '' => 'No courier assigned yet',
      backend.MarketplaceDeliveryStatus.awaitingWorker =>
        'Awaiting courier dispatch',
      backend.MarketplaceDeliveryStatus.assigned => 'Courier heading to store',
      backend.MarketplaceDeliveryStatus.pickedUp =>
        'Courier picked up — heading to you',
      backend.MarketplaceDeliveryStatus.onTheWay => 'Courier on the way to you',
      backend.MarketplaceDeliveryStatus.delivered => 'Delivered',
      backend.MarketplaceDeliveryStatus.cancelled => 'Delivery cancelled',
      backend.MarketplaceDeliveryStatus.failed => 'Delivery failed',
      _ => deliveryStatus,
    };
  }

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Order placed',
      'Store accepted',
      'Store preparing',
      'Ready for pickup',
      'Courier on the way',
      'Delivered',
    ];
    return Scaffold(
      appBar: AppBar(
        leading: OmwBackButton(
          fallback: onSwitchAccount == null
              ? null
              : () => switchAccountFrom(context, onSwitchAccount!),
        ),
        title: const Text('Order tracking'),
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
            final isCancelled =
                current.status == backend.MarketplaceOrderStatus.cancelled;
            final activeStep = _stepFor(current.status);
            final shortId = _shortId(current.id);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Order summary header ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: kBrandBlack,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'OMW Marketplace order',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (isCancelled)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'CANCELLED',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        current.storeName,
                        style: const TextStyle(
                          color: kAccentYellow,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order #$shortId',
                        style: const TextStyle(
                          color: kMutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${current.itemCount} item${current.itemCount == 1 ? '' : 's'}  •  \$${current.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: kMutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Order progress timeline ───────────────────────────────
                if (!isCancelled) ...[
                  const Text(
                    'Order progress',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  ...steps.indexed.map(
                    (entry) => _MarketplaceTimelineStep(
                      label: entry.$2,
                      active: entry.$1 == activeStep,
                      complete: entry.$1 < activeStep,
                    ),
                  ),
                  const SizedBox(height: 18),
                ] else ...[
                  _StateMessage(
                    icon: Icons.cancel_outlined,
                    text: 'This order was cancelled.',
                  ),
                  const SizedBox(height: 18),
                ],

                // ── Delivery status ───────────────────────────────────────
                if (!isCancelled) ...[
                  const Text(
                    'Delivery',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  _StateMessage(
                    icon:
                        current.deliveryStatus ==
                            backend.MarketplaceDeliveryStatus.delivered
                        ? Icons.check_circle_outline
                        : Icons.delivery_dining,
                    text: _deliveryStatusLabel(current.deliveryStatus),
                  ),
                  if (current.assignedWorkerName?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your courier',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 16,
                                backgroundColor: kBrandBlack,
                                child: Icon(
                                  Icons.delivery_dining,
                                  color: kAccentYellow,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      current.assignedWorkerName ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (current
                                            .assignedWorkerPhone
                                            ?.isNotEmpty ==
                                        true)
                                      Text(
                                        current.assignedWorkerPhone!,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                ],

                // ── Delivery address ──────────────────────────────────────
                if (current.deliveryLabel.isNotEmpty) ...[
                  const Text(
                    'Delivery address',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place_outlined, color: kDeepGold),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            current.deliveryLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // ── Items ─────────────────────────────────────────────────
                const Text(
                  'Items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      ...current.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: kAccentYellow.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${item.quantity}×',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '\$${item.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 16),
                      _TrackingTotalRow(
                        label: 'Subtotal',
                        value: '\$${current.subtotal.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 4),
                      _TrackingTotalRow(
                        label: 'Delivery fee',
                        value: '\$${current.deliveryFee.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 6),
                      _TrackingTotalRow(
                        label: 'Total',
                        value: '\$${current.total.toStringAsFixed(2)}',
                        bold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TrackingTotalRow extends StatelessWidget {
  const _TrackingTotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
      fontSize: bold ? 15 : null,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
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

enum _MarketplaceCollectionFilter {
  freeDelivery,
  firstOrderDeals,
  openNow,
  popularNearYou,
  newOnOmw,
  essentials,
  sweetCravings,
  quickLunch,
  familyMeals,
  bestRated,
  coffeeBreakfast,
}

String _marketplaceCollectionLabel(_MarketplaceCollectionFilter filter) =>
    switch (filter) {
      _MarketplaceCollectionFilter.freeDelivery => 'Free Delivery',
      _MarketplaceCollectionFilter.firstOrderDeals => 'First Order Deals',
      _MarketplaceCollectionFilter.openNow => 'Open Now',
      _MarketplaceCollectionFilter.popularNearYou => 'Popular stores',
      _MarketplaceCollectionFilter.newOnOmw => 'New on OMW',
      _MarketplaceCollectionFilter.essentials => 'Essentials',
      _MarketplaceCollectionFilter.sweetCravings => 'Sweet Cravings',
      _MarketplaceCollectionFilter.quickLunch => 'Quick Lunch',
      _MarketplaceCollectionFilter.familyMeals => 'Family Meals',
      _MarketplaceCollectionFilter.bestRated => 'Best Rated',
      _MarketplaceCollectionFilter.coffeeBreakfast => 'Coffee & Breakfast',
    };

class _MarketplacePromoCarousel extends StatefulWidget {
  const _MarketplacePromoCarousel({
    required this.selectedFilter,
    required this.onSelected,
  });

  // null = no card selected (curated home mode)
  final _MarketplaceCollectionFilter? selectedFilter;
  final ValueChanged<_MarketplaceCollectionFilter> onSelected;

  @override
  State<_MarketplacePromoCarousel> createState() =>
      _MarketplacePromoCarouselState();
}

class _MarketplacePromoCarouselState extends State<_MarketplacePromoCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.88);
  Timer? _timer;
  int _page = 0;

  static const _cards = [
    _MarketplaceCarouselCardData(
      filter: _MarketplaceCollectionFilter.freeDelivery,
      title: 'Free Delivery',
      subtitle: 'Stores that enabled free delivery',
      icon: Icons.delivery_dining_outlined,
      start: kAccentYellow,
      end: Color(0xFFFFE08A),
    ),
    _MarketplaceCarouselCardData(
      filter: _MarketplaceCollectionFilter.firstOrderDeals,
      title: 'First Order Deals',
      subtitle: 'Stores with deal fields enabled',
      icon: Icons.local_offer_outlined,
      start: Color(0xFF111111),
      end: Color(0xFF3A3A3A),
      dark: true,
    ),
    _MarketplaceCarouselCardData(
      filter: _MarketplaceCollectionFilter.openNow,
      title: 'Open Now',
      subtitle: 'Approved stores accepting orders',
      icon: Icons.storefront_outlined,
      start: Color(0xFFEFF7F0),
      end: Color(0xFFFFFFFF),
    ),
    _MarketplaceCarouselCardData(
      filter: _MarketplaceCollectionFilter.popularNearYou,
      title: 'Popular Near You',
      subtitle: 'Popular approved stores',
      icon: Icons.trending_up,
      start: Color(0xFFFFF7D6),
      end: Color(0xFFFFFFFF),
    ),
    _MarketplaceCarouselCardData(
      filter: _MarketplaceCollectionFilter.newOnOmw,
      title: 'New on OMW',
      subtitle: 'Recently added stores',
      icon: Icons.auto_awesome_outlined,
      start: Color(0xFFF0F5FF),
      end: Color(0xFFFFFFFF),
    ),
    _MarketplaceCarouselCardData(
      filter: _MarketplaceCollectionFilter.essentials,
      title: 'Essentials',
      subtitle: 'Grocery and convenience picks',
      icon: Icons.shopping_basket_outlined,
      start: Color(0xFFFFFFFF),
      end: Color(0xFFFFF2BF),
    ),
    _MarketplaceCarouselCardData(
      filter: _MarketplaceCollectionFilter.sweetCravings,
      title: 'Sweet Cravings',
      subtitle: 'Bakery and coffee shop treats',
      icon: Icons.cake_outlined,
      start: Color(0xFFFFF1F6),
      end: Color(0xFFFFFFFF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (_cards.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || !_controller.hasClients) return;
        final next = (_page + 1) % _cards.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _controller,
            itemCount: _cards.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final data = _cards[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _MarketplaceCarouselCard(
                  data: data,
                  selected: widget.selectedFilter == data.filter,
                  onTap: () => widget.onSelected(data.filter),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _cards.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: _page == index ? 18 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: _page == index
                    ? kBrandBlack
                    : Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MarketplaceCarouselCardData {
  const _MarketplaceCarouselCardData({
    required this.filter,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.start,
    required this.end,
    this.dark = false,
  });

  final _MarketplaceCollectionFilter filter;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color start;
  final Color end;
  final bool dark;
}

class _MarketplaceCarouselCard extends StatelessWidget {
  const _MarketplaceCarouselCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _MarketplaceCarouselCardData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = data.dark ? Colors.white : kBrandBlack;
    final muted = data.dark ? kMutedText : Colors.black54;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [data.start, data.end]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? kDeepGold : Colors.black.withValues(alpha: 0.04),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: data.dark ? 0.16 : 0.78),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                data.icon,
                color: data.dark ? kAccentYellow : kDeepGold,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceTopHeader extends StatelessWidget {
  const _MarketplaceTopHeader({
    required this.deliveryLabel,
    required this.onLocationTap,
  });

  final String deliveryLabel;
  final VoidCallback onLocationTap;

  @override
  Widget build(BuildContext context) {
    final hasLocation = deliveryLabel.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBrandBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location row — tap to change delivery address
          InkWell(
            onTap: onLocationTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: kAccentYellow),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Deliver to',
                          style: TextStyle(
                            color: kMutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          hasLocation
                              ? deliveryLabel
                              : 'Select delivery location',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'On My Way Marketplace',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Shop approved local stores with OMW delivery.',
            style: TextStyle(color: kMutedText, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceSearchBar extends StatelessWidget {
  const _MarketplaceSearchBar({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Search store or item',
        prefixIcon: const Icon(Icons.search, color: kDeepGold),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class _MarketplaceSectionHeader extends StatelessWidget {
  const _MarketplaceSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: kBrandBlack,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _MarketplaceCategoryScroller extends StatelessWidget {
  const _MarketplaceCategoryScroller({
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final categories = backend.marketplaceCategoryOptions
        .where((option) => option.value != 'other')
        .toList();
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = selectedCategory == category.value;
          return InkWell(
            onTap: () => onCategorySelected(category.value),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 92,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? kBrandBlack : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? kBrandBlack : Colors.grey.shade200,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _marketplaceCategoryIcon(category.value),
                    color: selected ? kAccentYellow : kDeepGold,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : kBrandBlack,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

IconData _marketplaceCategoryIcon(String value) => switch (value) {
  'grocery' => Icons.local_grocery_store_outlined,
  'restaurant' => Icons.restaurant_outlined,
  'pharmacy' => Icons.local_pharmacy_outlined,
  'electronics' => Icons.devices_other,
  'clothing' => Icons.checkroom_outlined,
  'bakery' => Icons.bakery_dining_outlined,
  'coffee_shop' => Icons.local_cafe_outlined,
  'convenience_store' => Icons.storefront_outlined,
  'flowers' => Icons.local_florist_outlined,
  'beauty_personal_care' => Icons.spa_outlined,
  _ => Icons.category_outlined,
};

class _MarketplaceStoreCard extends StatelessWidget {
  const _MarketplaceStoreCard({required this.store, required this.onTap});

  final backend.MarketplaceStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final categoryLabel = backend.marketplaceCategoryLabel(store.category);
    final open = store.isCustomerOrderable;
    return InkWell(
      onTap: open ? onTap : null,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                OmwNetworkImage(
                  url: store.coverUrl,
                  width: double.infinity,
                  height: 132,
                  borderRadius: 0,
                  placeholder: Container(
                    height: 132,
                    decoration: BoxDecoration(
                      color: kBrandBlack,
                      gradient: LinearGradient(
                        colors: [
                          kBrandBlack,
                          kAccentYellow.withValues(alpha: 0.28),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.storefront_outlined,
                        color: kAccentYellow,
                        size: 38,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: _MarketplaceStatusBadge(open: open),
                ),
                Positioned(
                  left: 14,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: OmwNetworkImage(
                      url: store.imageUrl,
                      width: 52,
                      height: 52,
                      borderRadius: 14,
                      placeholder: const _MarketplaceImagePlaceholder(
                        icon: Icons.storefront_outlined,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    store.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: kBrandBlack,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    categoryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_outlined,
                        size: 16,
                        color: kDeepGold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${store.deliveryEstimateMinutes} min',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (store.rating > 0) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.star, size: 16, color: kDeepGold),
                        const SizedBox(width: 4),
                        Text(
                          store.rating.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceStatusBadge extends StatelessWidget {
  const _MarketplaceStatusBadge({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: open ? Colors.green.shade700 : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        open ? 'Open' : 'Closed',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MarketplaceProductsRail extends StatelessWidget {
  const _MarketplaceProductsRail({
    required this.service,
    required this.stores,
    required this.storeById,
    required this.selectedCategory,
    required this.collectionFilter,
    required this.query,
    required this.onAddToCart,
  });

  final MarketplaceService service;
  final List<backend.MarketplaceStore> stores;
  final Map<String, backend.MarketplaceStore> storeById;
  final String? selectedCategory;
  final _MarketplaceCollectionFilter collectionFilter;
  final String query;
  final ValueChanged<backend.MarketplaceProduct> onAddToCart;

  @override
  Widget build(BuildContext context) {
    final approvedStoreIds = stores.map((store) => store.id).toList();
    return StreamBuilder<List<backend.MarketplaceProduct>>(
      stream: service.watchVisibleProductsForStores(approvedStoreIds),
      builder: (context, snapshot) {
        final normalizedQuery = query.toLowerCase();
        final products = (snapshot.data ?? const <backend.MarketplaceProduct>[])
            .where((product) {
              final store = storeById[product.storeId];
              if (store == null || !store.isCustomerVisible) return false;
              final matchesCategory =
                  selectedCategory == null ||
                  backend.normalizeMarketplaceCategory(product.category) ==
                      selectedCategory;
              final matchesQuery =
                  normalizedQuery.isEmpty ||
                  product.name.toLowerCase().contains(normalizedQuery) ||
                  product.description.toLowerCase().contains(normalizedQuery) ||
                  store.name.toLowerCase().contains(normalizedQuery);
              return matchesCategory &&
                  matchesQuery &&
                  _productMatchesCollection(product, store);
            })
            .toList();
        if (collectionFilter == _MarketplaceCollectionFilter.newOnOmw) {
          products.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
        }
        final visibleProducts = products.take(12).toList();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (visibleProducts.isEmpty) {
          return const _MarketplaceEmptyState(
            icon: Icons.shopping_bag_outlined,
            text: 'No matches yet.',
          );
        }
        return SizedBox(
          height: 252,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visibleProducts.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = visibleProducts[index];
              return SizedBox(
                width: 160,
                child: _ProductCard(
                  product: product,
                  storeName: storeById[product.storeId]?.name ?? '',
                  onAdd: () => onAddToCart(product),
                ),
              );
            },
          ),
        );
      },
    );
  }

  bool _productMatchesCollection(
    backend.MarketplaceProduct product,
    backend.MarketplaceStore store,
  ) {
    final storeCategory = backend.normalizeMarketplaceCategory(store.category);
    final subcategory = product.subcategory;
    return switch (collectionFilter) {
      _MarketplaceCollectionFilter.freeDelivery => store.freeDeliveryEnabled,
      _MarketplaceCollectionFilter.firstOrderDeals =>
        store.firstOrderDealEnabled ||
            store.discountEnabled ||
            product.discountEnabled,
      _MarketplaceCollectionFilter.openNow => store.isCustomerOrderable,
      _MarketplaceCollectionFilter.popularNearYou => store.isCustomerVisible,
      _MarketplaceCollectionFilter.newOnOmw => product.createdAt != null,
      _MarketplaceCollectionFilter.essentials =>
        storeCategory == 'grocery' || storeCategory == 'convenience_store',
      _MarketplaceCollectionFilter.sweetCravings =>
        storeCategory == 'bakery' ||
            storeCategory == 'coffee_shop' ||
            subcategory.contains('dessert') ||
            subcategory.contains('cake') ||
            subcategory.contains('pastr'),
      _MarketplaceCollectionFilter.quickLunch =>
        storeCategory == 'restaurant' || storeCategory == 'coffee_shop',
      _MarketplaceCollectionFilter.familyMeals => storeCategory == 'restaurant',
      _MarketplaceCollectionFilter.bestRated =>
        store.rating > 0 && store.isCustomerVisible,
      _MarketplaceCollectionFilter.coffeeBreakfast =>
        storeCategory == 'coffee_shop' || subcategory.contains('breakfast'),
    };
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero({required this.store});

  final backend.MarketplaceStore store;

  @override
  Widget build(BuildContext context) {
    final categoryLabel = backend.marketplaceCategoryLabel(store.category);
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kBrandBlack,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OmwNetworkImage(
              url: store.coverUrl,
              width: constraints.maxWidth,
              height: 132,
              borderRadius: 14,
              placeholder: Container(
                height: 132,
                decoration: BoxDecoration(
                  color: kAccentYellow.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(
                    Icons.storefront_outlined,
                    color: kAccentYellow,
                    size: 34,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OmwNetworkImage(
                  url: store.imageUrl,
                  width: 58,
                  height: 58,
                  placeholder: const _MarketplaceImagePlaceholder(
                    icon: Icons.storefront_outlined,
                  ),
                ),
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
                        '$categoryLabel - ${store.address}',
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
            if (store.openingHoursLabel.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                store.openingHoursLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onAdd,
    this.storeName = '',
  });

  final backend.MarketplaceProduct product;
  final VoidCallback onAdd;
  final String storeName;

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
    final categoryLabel = backend.marketplaceSubcategoryLabel(
      product.category,
      product.subcategory,
    );
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
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => OmwNetworkImage(
                url: product.imageUrl,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                borderRadius: 10,
                placeholder: Container(
                  color: kAccentYellow.withValues(alpha: 0.22),
                  child: const Center(
                    child: Icon(Icons.shopping_bag_outlined, color: kDeepGold),
                  ),
                ),
              ),
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
            storeName.isNotEmpty
                ? storeName
                : product.description.isEmpty
                ? categoryLabel
                : product.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (storeName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              categoryLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
        leading: OmwNetworkImage(
          url: item.productImageUrl ?? '',
          width: 44,
          height: 44,
          borderRadius: 10,
          placeholder: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kAccentYellow.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: kDeepGold),
          ),
        ),
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
          _TotalsRow(
            label: 'Subtotal',
            value: '\$${subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          _TotalsRow(
            label: 'Delivery fee',
            value: '\$${deliveryFee.toStringAsFixed(2)}',
          ),
          const Divider(color: kMutedText, height: 20),
          _TotalsRow(
            label: 'Total',
            value: '\$${total.toStringAsFixed(2)}',
            highlight: true,
          ),
        ],
      ),
    );
  }
}

/// Row widget for use on dark (kBrandBlack) backgrounds — always uses light text.
class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: kMutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? kAccentYellow : Colors.white,
            fontWeight: highlight ? FontWeight.w900 : FontWeight.w800,
            fontSize: highlight ? 17 : null,
          ),
        ),
      ],
    );
  }
}

// ── Curated horizontal store section ────────────────────────────────────────

class _MarketplaceCuratedSection extends StatelessWidget {
  const _MarketplaceCuratedSection({
    required this.title,
    required this.stores,
    required this.onTap,
    this.emptyText,
  });

  final String title;
  final List<backend.MarketplaceStore> stores;
  final ValueChanged<backend.MarketplaceStore> onTap;

  // When null the entire section is hidden if stores is empty.
  // When set, the section shows with this placeholder text.
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty && emptyText == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _MarketplaceSectionHeader(title: title),
        ),
        if (stores.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: _MarketplaceEmptyState(
              icon: Icons.storefront_outlined,
              text: emptyText!,
            ),
          )
        else ...[
          SizedBox(
            height: 216,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: stores.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _MarketplaceSmallStoreCard(
                    store: stores[index],
                    onTap: () => onTap(stores[index]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

// Compact card used in horizontal curated sections.
// Shows cover image with logo overlay, name, category, status badge.
class _MarketplaceSmallStoreCard extends StatelessWidget {
  const _MarketplaceSmallStoreCard({required this.store, required this.onTap});

  final backend.MarketplaceStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final open = store.isCustomerOrderable;
    final categoryLabel = backend.marketplaceCategoryLabel(store.category);
    return InkWell(
      onTap: open ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 168,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cover with status badge and logo overlay
            Stack(
              clipBehavior: Clip.none,
              children: [
                OmwNetworkImage(
                  url: store.coverUrl,
                  width: 168,
                  height: 108,
                  borderRadius: 0,
                  placeholder: Container(
                    height: 108,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          kBrandBlack,
                          kAccentYellow.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.storefront_outlined,
                        color: kAccentYellow,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                // Open/Closed badge
                Positioned(
                  right: 8,
                  top: 8,
                  child: _MarketplaceStatusBadge(open: open),
                ),
                // Logo overlapping cover/info boundary
                Positioned(
                  left: 10,
                  bottom: -18,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: OmwNetworkImage(
                      url: store.imageUrl,
                      width: 36,
                      height: 36,
                      borderRadius: 10,
                      placeholder: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: kAccentYellow.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.storefront_outlined,
                          color: kDeepGold,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Info section — top padding accounts for logo overlap
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 24, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    categoryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.schedule_outlined, size: 12, color: kDeepGold),
                      const SizedBox(width: 3),
                      Text(
                        '${store.deliveryEstimateMinutes} min',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      if (store.rating > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star, size: 12, color: kDeepGold),
                        const SizedBox(width: 3),
                        Text(
                          store.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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

class _MarketplaceLocationResult {
  const _MarketplaceLocationResult({required this.label, required this.point});

  final String label;
  final DemoMapPoint point;
}

class _MarketplaceLocationSheet extends StatefulWidget {
  const _MarketplaceLocationSheet({
    required this.initialLabel,
    required this.initialPoint,
    required this.placesService,
  });

  final String initialLabel;
  final DemoMapPoint initialPoint;
  final GooglePlacesService placesService;

  @override
  State<_MarketplaceLocationSheet> createState() =>
      _MarketplaceLocationSheetState();
}

class _MarketplaceLocationSheetState extends State<_MarketplaceLocationSheet> {
  late final TextEditingController _addressCtrl;
  late DemoMapPoint _point;
  List<PlaceSuggestion> _suggestions = const [];
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController(text: widget.initialLabel);
    _point = widget.initialPoint;
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  void _updateSuggestions(String value) {
    setState(() {
      _suggestions = widget.placesService.localSuggestions(value);
    });
  }

  void _selectSuggestion(PlaceSuggestion suggestion) {
    setState(() {
      _addressCtrl.text = suggestion.description;
      _point = suggestion.localPoint ?? _point;
      _suggestions = const [];
    });
  }

  void _setPoint(DemoMapPoint point) {
    setState(() {
      _point = point;
      if (_addressCtrl.text.trim().isEmpty) {
        _addressCtrl.text =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final result = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (result.point != null) {
      _setPoint(result.point!);
      if (_addressCtrl.text.trim().isEmpty) {
        _addressCtrl.text = 'Current location';
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Could not get current location.'),
        ),
      );
    }
  }

  void _save() {
    final label = _addressCtrl.text.trim();
    Navigator.of(context).pop(
      _MarketplaceLocationResult(
        label: label.isEmpty ? 'Select delivery location' : label,
        point: _point,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Delivery location',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Enter delivery address',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              onChanged: _updateSuggestions,
            ),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PlacesSuggestionList(
                suggestions: _suggestions,
                onSelected: _selectSuggestion,
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _locating ? null : _useCurrentLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_outlined),
              label: Text(_locating ? 'Locating...' : 'Use current location'),
            ),
            const SizedBox(height: 10),
            AppMap(
              pickup: _point,
              destination: _point,
              height: 180,
              gesturesEnabled: false,
              onMapTap: _setPoint,
            ),
            if (!kUseGoogleMaps) ...[
              const SizedBox(height: 8),
              const Text(
                'Maps are not configured. Manual address is available.',
                style: TextStyle(
                  color: kMutedText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 14),
            PrimaryCtaButton(label: 'Use this location', onPressed: _save),
          ],
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

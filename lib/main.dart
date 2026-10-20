import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/product.dart';
import 'services/market_api.dart';

void main() {
  runApp(const MemoryMarketApp());
}

class MemoryMarketApp extends StatelessWidget {
  const MemoryMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    const forest = Color(0xFF183D32);
    const canvas = Color(0xFFF3F2E9);

    return MaterialApp(
      title: 'Memory Market',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: forest,
          primary: forest,
          surface: canvas,
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: forest,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            height: 1.05,
          ),
          titleLarge: TextStyle(
            color: forest,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
          bodyMedium: TextStyle(color: Color(0xFF58665E), height: 1.45),
        ),
      ),
      home: const MarketHomePage(),
    );
  }
}

class MarketHomePage extends StatefulWidget {
  const MarketHomePage({super.key});

  @override
  State<MarketHomePage> createState() => _MarketHomePageState();
}

class _MarketHomePageState extends State<MarketHomePage> {
  final _api = MarketApi();
  final _searchController = TextEditingController();
  final _stores = const ['All stores', 'Daraz', 'Czone', 'ZAH Computers'];

  int _tab = 0;
  String _selectedStore = 'All stores';
  List<Product> _featured = [];
  List<Product> _results = [];
  List<String> _featuredErrors = [];
  String? _featuredError;
  String? _searchError;
  bool _loadingFeatured = true;
  bool _searching = false;
  bool _hasSearched = false;

  List<Product> get _visibleProducts {
    final products = _tab == 0 ? _featured : _results;
    if (_selectedStore == 'All stores') return products;
    return products.where((product) => product.store == _selectedStore).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadFeatured();
  }

  @override
  void dispose() {
    _api.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeatured() async {
    setState(() {
      _loadingFeatured = true;
      _featuredError = null;
    });
    try {
      final response = await _api.getFeatured();
      if (!mounted) return;
      setState(() {
        _featured = response.products;
        _featuredErrors = response.errors;
        _featuredError = response.products.isEmpty && response.errors.isNotEmpty
            ? 'Featured finds could not load. Check that the show service is running.'
            : null;
      });
    } on MarketApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _featuredError = error.message;
        _featuredErrors = [];
      });
    } finally {
      if (mounted) setState(() => _loadingFeatured = false);
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (_searching) return;
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a product to search for.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _tab = 1;
      _selectedStore = 'All stores';
      _searching = true;
      _hasSearched = true;
      _searchError = null;
      _results = [];
    });
    try {
      final response = await _api.search(query);
      if (!mounted) return;
      setState(() {
        _results = response;
      });
    } on MarketApiException catch (error) {
      if (!mounted) return;
      setState(() => _searchError = error.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openProduct(Product product) async {
    final uri = product.link;
    if (uri == null) return;
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this store listing.')),
      );
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this store listing.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _visibleProducts;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            _buildDiscover(products),
            _buildSearchPage(products),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        backgroundColor: const Color(0xFFFBFAF5),
        indicatorColor: const Color(0xFFDCE9BF),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.nature_outlined),
            selectedIcon: Icon(Icons.nature),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.manage_search_rounded),
            label: 'Search',
          ),
        ],
      ),
    );
  }

  Widget _buildDiscover(List<Product> products) {
    return RefreshIndicator(
      color: const Color(0xFF183D32),
      onRefresh: _loadFeatured,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: _buildTopBar(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
              child: _buildHero(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 25, 22, 0),
              child: _buildSectionHeading(
                eyebrow: 'A BETTER WAY TO BUILD',
                title: 'Find your next upgrade',
                subtitle: 'Computer parts, gathered from stores you know.',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildStoreFilters(horizontalPadding: 22),
          ),
          if (_featuredErrors.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
                child: Text(
                  'Some stores could not be reached: ${_featuredErrors.join(', ')}',
                  style: const TextStyle(color: Color(0xFF8D5E3A), fontSize: 12),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
            sliver: _buildProductList(
              products,
              loading: _loadingFeatured,
              error: _featuredError,
              emptyTitle: 'The shelves are quiet',
              emptyMessage: 'Pull down to check for featured products again.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPage(List<Product> products) {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: _buildTopBar(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 31, 22, 0),
            child: _buildSectionHeading(
              eyebrow: 'THE WHOLE MARKET',
              title: 'Search across stores',
              subtitle: 'One search. Daraz, Czone and ZAH.',
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
            child: _buildSearchBox(),
          ),
        ),
        SliverToBoxAdapter(
          child: _buildStoreFilters(horizontalPadding: 22),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          sliver: _buildProductList(
            products,
            loading: _searching,
            error: _searchError,
            emptyTitle: _hasSearched ? 'No finds this time' : 'Start with a search',
            emptyMessage: _hasSearched
                ? 'Try another phrase, or check back in a moment.'
                : 'Search a part, brand, or upgrade to explore the market.',
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF183D32),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.spa_rounded, color: Color(0xFFD4ED8F), size: 23),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MEMORY',
              style: TextStyle(
                color: Color(0xFF183D32),
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.7,
                height: 1.1,
              ),
            ),
            Text(
              'MARKET',
              style: TextStyle(
                color: Color(0xFF7A867A),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EBDD),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            children: [
              Icon(Icons.public_rounded, size: 14, color: Color(0xFF41634E)),
              SizedBox(width: 6),
              Text(
                'PAKISTAN',
                style: TextStyle(
                  color: Color(0xFF41634E),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 236,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF285443), Color(0xFF15382E)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -54,
              top: -83,
              child: _heroOrb(220, const Color(0xFF6B8B53).withValues(alpha: .20)),
            ),
            Positioned(
              right: 55,
              bottom: -117,
              child: _heroOrb(190, const Color(0xFFC9E57E).withValues(alpha: .10)),
            ),
            Positioned(
              right: 24,
              top: 49,
              child: Transform.rotate(
                angle: -.32,
                child: const Icon(
                  Icons.eco_rounded,
                  size: 116,
                  color: Color(0xFFD4ED8F),
                ),
              ),
            ),
            Positioned(
              left: 23,
              top: 23,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4ED8F),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'YOUR PC-BUILDING COMPANION',
                    style: TextStyle(
                      color: Color(0xFFC6D7BC),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 23,
              top: 66,
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    color: Color(0xFFF5F2E8),
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.3,
                    height: 1.03,
                  ),
                  children: [
                    TextSpan(text: 'Good parts.\n'),
                    TextSpan(
                      text: 'Grounded ',
                      style: TextStyle(color: Color(0xFFD4ED8F)),
                    ),
                    TextSpan(text: 'prices.'),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 23,
              bottom: 19,
              child: Row(
                children: [
                  _heroStore('DARAZ'),
                  const SizedBox(width: 7),
                  _heroStore('CZONE'),
                  const SizedBox(width: 7),
                  _heroStore('ZAH'),
                ],
              ),
            ),
            Positioned(
              right: 19,
              bottom: 18,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4ED8F),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.arrow_downward_rounded,
                  color: Color(0xFF183D32),
                  size: 19,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1),
      ),
    );
  }

  Widget _heroStore(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .17)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE5EBDC),
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: .8,
        ),
      ),
    );
  }

  Widget _buildSectionHeading({
    required String eyebrow,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: Color(0xFF72866C),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 7),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFA),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE4E5D9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF183D32).withValues(alpha: .045),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Icon(Icons.search_rounded, color: Color(0xFF778277)),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                hintText: 'Try “RTX 4060” or “DDR4 RAM”',
                hintStyle: TextStyle(color: Color(0xFF9AA197), fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 17),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: IconButton.filled(
              onPressed: _searching ? null : _search,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF183D32),
                foregroundColor: const Color(0xFFD4ED8F),
                disabledBackgroundColor: const Color(0xFF728278),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: _searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFD4ED8F),
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreFilters({required double horizontalPadding}) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 14, horizontalPadding, 8),
        scrollDirection: Axis.horizontal,
        itemCount: _stores.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final store = _stores[index];
          final selected = _selectedStore == store;
          return ChoiceChip(
            label: Text(store),
            selected: selected,
            onSelected: (_) => setState(() => _selectedStore = store),
            backgroundColor: const Color(0xFFFBFAF5),
            selectedColor: const Color(0xFF183D32),
            side: BorderSide(
              color: selected ? const Color(0xFF183D32) : const Color(0xFFE0E2D7),
            ),
            labelStyle: TextStyle(
              color: selected ? const Color(0xFFE6F2D1) : const Color(0xFF657167),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 3),
          );
        },
      ),
    );
  }

  Widget _buildProductList(
    List<Product> products, {
    required bool loading,
    required String? error,
    required String emptyTitle,
    required String emptyMessage,
  }) {
    if (loading && products.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF315942)),
              const SizedBox(height: 13),
              Text(
                _tab == 1
                    ? 'Looking across the stores…'
                    : 'Gathering featured finds…',
                style: const TextStyle(
                  color: Color(0xFF728078),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Market out of reach',
          message: error,
          action: TextButton.icon(
            onPressed: _tab == 0 ? _loadFeatured : _search,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ),
      );
    }
    if (products.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(
          icon: _hasSearched && _tab == 1
              ? Icons.search_off_rounded
              : Icons.eco_outlined,
          title: emptyTitle,
          message: emptyMessage,
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: EdgeInsets.only(
            bottom: index == products.length - 1 ? 0 : 12,
          ),
          child: _buildProductCard(products[index]),
        ),
        childCount: products.length,
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 39, color: const Color(0xFF87937F)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF183D32),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 6),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Material(
      color: const Color(0xFFFFFEFA),
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: product.link == null ? null : () => _openProduct(product),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFE8E8DE)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: 93,
                  height: 106,
                  color: const Color(0xFFEEF0E6),
                  child: product.image == null
                      ? const Icon(
                          Icons.memory_rounded,
                          size: 34,
                          color: Color(0xFF84917F),
                        )
                      : Image.network(
                          product.image!.toString(),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.memory_rounded,
                            size: 34,
                            color: Color(0xFF84917F),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EDDE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.store.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF516B4D),
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF263D32),
                        fontSize: 13,
                        height: 1.28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.price,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF244D38),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.3,
                            ),
                          ),
                        ),
                        if (product.link != null)
                          const Icon(
                            Icons.north_east_rounded,
                            size: 16,
                            color: Color(0xFF69815E),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

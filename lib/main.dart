import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const Application());

class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CatalogViewModel()..init()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: const ApplicationWithTheme(),
    );
  }
}

class ApplicationWithTheme extends StatefulWidget {
  const ApplicationWithTheme({super.key});

  @override
  State<ApplicationWithTheme> createState() => _ApplicationWithThemeState();
}

class _ApplicationWithThemeState extends State<ApplicationWithTheme> {
  ThemeMode _mode = ThemeMode.light;
  Color _seed = const Color(0xFF6750A4);

  @override
  Widget build(BuildContext context) {
    final fontFamily = context.watch<AppSettings>().fontFamily;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UI Components Demo',
      themeMode: _mode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _seed,
        brightness: Brightness.light,
        fontFamily: fontFamily,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _seed,
        brightness: Brightness.dark,
        fontFamily: fontFamily,
      ),
      home: HomeShell(
        onToggleTheme: () => setState(() {
          _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        }),
        onChangeSeed: (color) => setState(() => _seed = color),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.onToggleTheme, required this.onChangeSeed});
  final VoidCallback onToggleTheme;
  final ValueChanged<Color> onChangeSeed;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const CatalogScreen(),
      const DialogsScreen(),
      const ProgressScreen(),
      const GridScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('UI Components & Indicators'),
        actions: [
          IconButton(
            tooltip: 'Toggle Light/Dark',
            onPressed: widget.onToggleTheme,
            icon: const Icon(Icons.brightness_6_rounded),
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Dialogs'),
          NavigationDestination(icon: Icon(Icons.downloading_outlined), selectedIcon: Icon(Icons.downloading), label: 'Progress'),
          NavigationDestination(icon: Icon(Icons.grid_on_outlined), selectedIcon: Icon(Icons.grid_on), label: 'Grid'),
          NavigationDestination(icon: Icon(Icons.tune), selectedIcon: Icon(Icons.tune), label: 'Settings'),
        ],
      ),
      floatingActionButton: _index == 4
          ? FloatingActionButton.extended(
              onPressed: () async {
                final Color? picked = await showDialog(
                  context: context,
                  builder: (ctx) => const SeedPickerDialog(),
                );
                if (picked != null) widget.onChangeSeed(picked);
              },
              label: const Text('Seed Color'),
              icon: const Icon(Icons.palette_rounded),
            )
          : null,
    );
  }
}

// --------------------------- CATALOG: Skeletons + Lazy Loader ---------------------------
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final vm = context.read<CatalogViewModel>();
    if (_controller.position.pixels >= _controller.position.maxScrollExtent - 200 &&
        !vm.loadingMore &&
        vm.hasMore) {
      vm.loadMore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CatalogViewModel>(
      builder: (_, vm, __) {
        if (vm.initialLoading) {
          // Skeleton list while first page loads
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, __) => const ProductSkeletonCard(),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: 6,
          );
        }

        return RefreshIndicator(
          onRefresh: () async => vm.refresh(),
          child: ListView.separated(
            controller: _controller,
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, i) {
                if (i == vm.items.length) {
                  if (vm.loadingMore) {
                    return Column(
                      children: [
                        const ProductSkeletonCard(),
                        const SizedBox(height: 12),
                        const ProductSkeletonCard(),
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                }

                final p = vm.items[i];
                return ProductCard(product: p);
              },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: vm.items.length + 1,
          ),
        );
      },
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                placeholder: (c, _) => const SizedBox(
                  width: 72,
                  height: 72,
                  child: ColoredBox(color: Colors.black12),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    product.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

class ProductSkeletonCard extends StatelessWidget {
  const ProductSkeletonCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: Container(
                      height: 22,
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Shimmer.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    ),
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

// --------------------------- DIALOGS ---------------------------
class DialogsScreen extends StatelessWidget {
  const DialogsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Dialogs', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Network Error'),
              content: const Text('Please check your internet connection.'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
            ),
          ),
          child: const Text('Alert Dialog'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete item?'),
              content: const Text('This action cannot be undone.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Delete')),
              ],
            ),
          ),
          child: const Text('Confirm Dialog'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx, setState) {
                bool subscribing = false;
                return AlertDialog(
                  title: const Text('Newsletter'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Get product updates and tips.'),
                      const SizedBox(height: 12),
                      if (subscribing) const LinearProgressIndicator(),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
                    FilledButton(
                      onPressed: () async {
                        setState(() => subscribing = true);
                        await Future.delayed(const Duration(milliseconds: 900));
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Subscribe'),
                    ),
                  ],
                );
              },
            ),
          ),
          child: const Text('Custom Dialog'),
        ),
      ],
    );
  }
}

// --------------------------- PROGRESS ---------------------------

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  File? _imageFile;
  double _progress = 0;
  Timer? _timer;
  bool _isProcessing = false;
  bool _uploadComplete = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _progress = 0;
        _isProcessing = false;
        _uploadComplete = false;
      });
      _startFakeUpload();
    }
  }

  void _startFakeUpload() {
    _timer?.cancel();
    _progress = 0;

    _timer = Timer.periodic(const Duration(milliseconds: 60), (t) {
      setState(() {
        _progress = (_progress + 0.02).clamp(0, 1);
      });

      if (_progress >= 1) {
        t.cancel();
        _startProcessing();
      }
    });
  }

  void _startProcessing() {
    setState(() {
      _uploadComplete = true;
      _isProcessing = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isProcessing = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 200,
        width: double.infinity,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Image Upload Simulation")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_imageFile != null) ...[
              Container(
                height: 200,
                width: double.infinity,
                alignment: Alignment.center,
                color: Colors.grey.shade200,
                child: Stack(
                  children: [
                    // Uploading placeholder
                    if (!_uploadComplete)
                      Container(color: Colors.grey.shade200),

                    // Skeleton loader while processing
                    if (_uploadComplete && _isProcessing)
                      _buildSkeletonLoader(),

                    // Final image
                    if (_uploadComplete && !_isProcessing)
                      Center(
                        child: Image.file(
                          _imageFile!,
                          fit: BoxFit.contain,
                          height: 200,
                        ),
                      ),

    
                    if (!_uploadComplete || _isProcessing)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            value: !_uploadComplete ? _progress : null, 
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Status text
              if (!_uploadComplete)
                Text("${(_progress * 100).toStringAsFixed(0)}%")
              else if (_isProcessing)
                const Text("Processing...")
              else
                const Text("✅ Upload Complete"),
            ] else
              const Text("No image selected"),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text("Pick Image & Upload"),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------- STAGGERED GRID + ORIENTATION ---------------------------
class GridScreen extends StatelessWidget {
  const GridScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final cross = isLandscape ? 4 : 2;

    final items = List.generate(20, (i) => DemoImage(index: i));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Staggered Grid', style: Theme.of(context).textTheme.titleLarge),
        ),
        Expanded(
          child: MasonryGridView.count(
            crossAxisCount: cross,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            padding: const EdgeInsets.all(12),
            itemBuilder: (ctx, i) {
              final it = items[i];
              final height = (i % 2 == 0) ? 160.0 : 240.0;
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CachedNetworkImage(
                      imageUrl: it.url,
                      fit: BoxFit.cover,
                      height: height,
                      width: double.infinity,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Item #${it.index}', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          const Text('Masonry layout demo with adaptive columns.'),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            itemCount: items.length,
          ),
        ),
      ],
    );
  }
}

// --------------------------- SETTINGS (seed color picker via dialog) ---------------------------
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<String> fonts = [
    'Roboto',
    'OpenSans',
    'Lobster',
    'Montserrat',
    'KlavikaMedium',
    'Rajdhani',
    'BebasNeue',
  ];

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettings>();
    final selectedFont = appSettings.fontFamily;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Themes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('This app uses Material 3 with a seed color. Use the FAB to pick a new seed color.'),
        const SizedBox(height: 24),
        Text('Select Font', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: selectedFont,
          items: fonts.map((font) {
            return DropdownMenuItem(
              value: font,
              child: Text(font, style: TextStyle(fontFamily: font)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              appSettings.setFontFamily(value);
            }
          },
        ),
      ],
    );
  }
}

class SeedPickerDialog extends StatelessWidget {
  const SeedPickerDialog({super.key});
  @override
  Widget build(BuildContext context) {
    final seeds = [
      const Color(0xFF6750A4), // purple
      const Color(0xFF006E1C), // green
      const Color(0xFF0B57D0), // blue
      const Color(0xFFAA2E25), // red
      const Color(0xFF775652), // brown
    ];
    return AlertDialog(
      title: const Text('Pick seed color'),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final c in seeds)
            InkWell(
              onTap: () => Navigator.pop(context, c),
              child: Container(width: 44, height: 44, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            ),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}

// --------------------------- DATA & VIEWMODEL ---------------------------
class Product {
  Product(this.id, this.title, this.subtitle, this.imageUrl);
  final int id;
  final String title;
  final String subtitle;
  final String imageUrl;
}

class CatalogViewModel extends ChangeNotifier {
  final List<Product> _items = [];
  final _pageSize = 8;
  int _page = 0;
  bool initialLoading = true;
  bool loadingMore = false;
  bool hasMore = true;

  List<Product> get items => List.unmodifiable(_items);

  void init() async {
    await Future.delayed(const Duration(milliseconds: 700));
    await _loadPage();
    initialLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    _items.clear();
    _page = 0;
    hasMore = true;
    notifyListeners();
    await _loadPage();
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    notifyListeners();
    await _loadPage();
    loadingMore = false;
    notifyListeners();
  }

  Future<void> _loadPage() async {
    await Future.delayed(const Duration(milliseconds: 1000)); // simulate network
    final next = _fakeProducts(page: _page, size: _pageSize);
    if (next.isEmpty) {
      hasMore = false;
      return;
    }
    _items.addAll(next);
    _page++;
  }
}

List<Product> _fakeProducts({required int page, required int size}) {
  // Cap total items at 60
  const total = 60;
  final start = page * size;
  if (start >= total) return [];
  final count = math.min(size, total - start);
  return List.generate(count, (i) {
    final id = start + i;
    return Product(
      id,
      'Product #$id',
      'This is a demo product with a slightly longer description to show wrapping.',
      'https://picsum.photos/seed/${id + 1}/600/400',
    );
  });
}

class DemoImage {
  final int index;
  DemoImage({required this.index});
  String get url => 'https://picsum.photos/seed/${index + 100}/600/400';
}


class AppSettings extends ChangeNotifier {
  String _fontFamily = 'Roboto';
  String get fontFamily => _fontFamily;

  void setFontFamily(String font) {
    if (_fontFamily != font) {
      _fontFamily = font;
      notifyListeners();
    }
  }
}
import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';

/// Effects browser with a horizontal category strip and vertical thumbnails.
class EffectsPanel extends StatefulWidget {
  const EffectsPanel({super.key});

  static const double height = 320;
  static const double searchHeight = 380;

  @override
  State<EffectsPanel> createState() => _EffectsPanelState();
}

class _EffectsPanelState extends State<EffectsPanel> {
  static const List<_EffectCategory> _categories = [
    _EffectCategory(icon: Icons.search, label: ''),
    _EffectCategory(icon: Icons.bookmark, label: ''),
    _EffectCategory(icon: Icons.access_time, label: ''),
    _EffectCategory(icon: null, label: 'منشور'),
    _EffectCategory(icon: null, label: 'الرياضة'),
    _EffectCategory(icon: null, label: 'جديد'),
    _EffectCategory(icon: null, label: 'الشائع'),
    _EffectCategory(icon: null, label: 'الشائع'),
    _EffectCategory(icon: null, label: 'الشائع'),
    _EffectCategory(icon: null, label: 'الشائع'),
    _EffectCategory(icon: null, label: 'الشائع'),
    _EffectCategory(icon: null, label: 'الشائع'),
    _EffectCategory(icon: null, label: 'الشائع'),
    _EffectCategory(icon: null, label: 'الشائع'),
  ];

  static const List<List<Color>> _thumbnailPalettes = [
    [Color(0xFF1E3550), Color(0xFFF2A46A)],
    [Color(0xFF243E25), Color(0xFFB4D7E4)],
    [Color(0xFF151A48), Color(0xFF5DB7DE)],
    [Color(0xFF733524), Color(0xFFE2B58A)],
    [Color(0xFF27313A), Color(0xFFEEDCC3)],
    [Color(0xFF58442B), Color(0xFFEAAE6C)],
    [Color(0xFF204E66), Color(0xFF62D6C7)],
    [Color(0xFF20202D), Color(0xFFB66D9B)],
  ];

  static const List<IconData> _thumbnailIcons = [
    Icons.face_retouching_natural,
    Icons.landscape_outlined,
    Icons.auto_awesome,
    Icons.face,
    Icons.pets_outlined,
    Icons.wb_sunny_outlined,
    Icons.local_florist_outlined,
    Icons.nightlight_outlined,
    Icons.palette_outlined,
    Icons.movie_filter_outlined,
  ];

  // The effects panel opens on the "منشور" category.
  int _selectedCategory = 3;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: _isSearching ? EffectsPanel.searchHeight : EffectsPanel.height,
        color: const Color(0xF20B0B0D),
        child: Column(
          children: [
            if (_isSearching) ...[
              _EffectSearchHeader(
                controller: _searchController,
                onCancel: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                  });
                },
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.smd,
                  AppSpacing.xxs,
                  AppSpacing.smd,
                  AppSpacing.xxs,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'مؤثرات رائجة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ] else
              _EffectCategories(
                categories: _categories,
                selectedIndex: _selectedCategory,
                onSelected: (index) =>
                    setState(() => _selectedCategory = index),
                onSearch: () => setState(() => _isSearching = true),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.smd,
                  AppSpacing.sm,
                  AppSpacing.smd,
                  AppSpacing.smd,
                ),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: AppSpacing.effectsThumbGap,
                  mainAxisSpacing: AppSpacing.smd,
                  childAspectRatio: 1,
                ),
                itemCount: 32,
                itemBuilder: (context, index) {
                  return _EffectThumbnail(
                    index: index,
                    categoryIndex: _selectedCategory,
                    palette:
                        _thumbnailPalettes[(index + _selectedCategory) %
                            _thumbnailPalettes.length],
                    icon:
                        _thumbnailIcons[(index + _selectedCategory) %
                            _thumbnailIcons.length],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EffectCategories extends StatelessWidget {
  const _EffectCategories({
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
    required this.onSearch,
  });

  final List<_EffectCategory> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          const SizedBox(
            width: 40,
            child: Center(
              child: Icon(Icons.block, color: Colors.white, size: 25),
            ),
          ),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.effectsTrayHorizontal,
                ),
                itemCount: categories.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.lg),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = selectedIndex == index;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: category.icon == Icons.search
                        ? onSearch
                        : () => onSelected(index),
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (category.icon != null)
                              Icon(
                                category.icon,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.6),
                                size: 25,
                              )
                            else
                              Text(
                                category.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.62),
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            const SizedBox(height: AppSpacing.xxs),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: isSelected ? 24 : 0,
                              height: 2,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EffectSearchHeader extends StatelessWidget {
  const _EffectSearchHeader({required this.controller, required this.onCancel});

  final TextEditingController controller;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 55,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.effectsTrayHorizontal,
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFF343A40),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: TextField(
                  controller: controller,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'البحث عن مؤثرات',
                    hintStyle: TextStyle(
                      color: Color(0xFFD5D5D5),
                      fontSize: 15,
                    ),
                    suffixIcon: Icon(
                      Icons.search,
                      color: Color(0xFFD5D5D5),
                      size: 25,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(45, 35),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('إلغاء', style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EffectThumbnail extends StatelessWidget {
  const _EffectThumbnail({
    required this.index,
    required this.categoryIndex,
    required this.palette,
    required this.icon,
  });

  final int index;
  final int categoryIndex;
  final List<Color> palette;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final showBadge = (index + categoryIndex) % 4 == 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.88),
                size: 34,
              ),
            ),
            if (showBadge)
              Positioned(
                left: 5,
                bottom: 5,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF34343A),
                    size: 9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EffectCategory {
  const _EffectCategory({required this.icon, required this.label});

  final IconData? icon;
  final String label;
}

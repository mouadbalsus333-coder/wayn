import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/wayn_colors.dart';

class HomeSearchBar extends StatefulWidget {
  final VoidCallback? onCategoryPressed;
  final ValueChanged<String>? onSearchChanged;
  final String selectedCategory;

  const HomeSearchBar({
    super.key,
    this.onCategoryPressed,
    this.onSearchChanged,
    this.selectedCategory = 'كل الأماكن',
  });

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  final TextEditingController _controller =
      TextEditingController();

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(
      const Duration(milliseconds: 450),
      () {
        widget.onSearchChanged?.call(value);
      },
    );

    setState(() {});
  }

  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();

    widget.onSearchChanged?.call('');

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText =
        _controller.text.trim().isNotEmpty;
    final colors = context.waynColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        14,
        20,
        12,
      ),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),

            Icon(
              Icons.search_rounded,
              size: 25,
              color: colors.textMuted,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: TextField(
                controller: _controller,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                textInputAction: TextInputAction.search,
                onChanged: _onTextChanged,
                decoration: InputDecoration(
                  hintText: 'شن ادور؟',
                  hintStyle: TextStyle(
                    color: colors.textMuted,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),

            if (hasText)
              GestureDetector(
                onTap: _clearSearch,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: colors.textMuted,
                  ),
                ),
              ),

            Container(
              height: 38,
              width: 1,
              color: colors.divider,
            ),

            InkWell(
              onTap: widget.onCategoryPressed,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 90,
                      ),
                      child: Text(
                        widget.selectedCategory,
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
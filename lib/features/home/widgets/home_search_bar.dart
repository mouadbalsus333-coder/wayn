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

  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    // أثناء الكتابة لا ننفذ البحث.
    // البحث يتم فقط عند الضغط على زر البحث في لوحة المفاتيح.
    setState(() {});
  }

  void _submitSearch() {
    widget.onSearchChanged?.call(
      _controller.text.trim(),
    );
  }

  void _clearSearch() {
    _controller.clear();

    widget.onSearchChanged?.call('');

    _focusNode.requestFocus();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final searchBackground = isDark
        ? const Color(0xFF151A22)
        : Colors.white;

    final searchBorder = isDark
        ? const Color(0xFF2B3340)
        : const Color(0xFFE7EBF0);

    final searchText = isDark
        ? Colors.white
        : const Color(0xFF172033);

    final searchHint = isDark
        ? const Color(0xFF8F99A8)
        : const Color(0xFF9AA3B1);

    final filterBackground = isDark
        ? const Color(0xFF17332F)
        : const Color(0xFFE8F8F6);

    final hasText =
        _controller.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        14,
        12,
        12,
      ),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: searchBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: searchBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? 0.25 : 0.12,
              ),
              blurRadius: 24,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 15),

            const Icon(
              Icons.search_rounded,
              size: 24,
              color: Color(0xFF18A99A),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                textAlignVertical:
                    TextAlignVertical.center,
                textInputAction:
                    TextInputAction.search,
                onChanged: _onTextChanged,
                onSubmitted: (_) {
                  _submitSearch();
                },
                cursorColor:
                    const Color(0xFF18A99A),
                style: TextStyle(
                  color: searchText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'شن ادور؟',
                  hintStyle: TextStyle(
                    color: searchHint,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),

                  // مهم:
                  // إزالة أي إطار داخلي حول TextField.
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,

                  filled: false,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            if (hasText)
              GestureDetector(
                onTap: _clearSearch,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: Color(0xFF8993A3),
                    size: 21,
                  ),
                ),
              ),

            const SizedBox(width: 4),

            Container(
              width: 43,
              height: 43,
              margin: const EdgeInsets.only(
                right: 7,
              ),
              decoration: BoxDecoration(
                color: filterBackground,
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onCategoryPressed,
                  borderRadius:
                      BorderRadius.circular(14),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          color: colors.brand,
                          size: 21,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 7),
          ],
        ),
      ),
    );
  }
}
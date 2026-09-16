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

class _HomeSearchBarState extends State<HomeSearchBar>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _controller =
      TextEditingController();

  final FocusNode _focusNode = FocusNode();

  static const List<String> _hints = [
    'ابحث عن كل ما تريد',
    'أماكن قريبة منك',
    'خدمات تحتاجها',
    'مطاعم ومقاهي',
    'متاجر وأماكن تسوق',
    'أنشطة وأماكن ترفيه',
    'اكتشف شيئًا جديدًا',
  ];

  Timer? _hintTimer;
  Timer? _keyboardCheckTimer;

  int _hintIndex = 0;

  bool _isFocused = false;
  bool _isFilterPressed = false;
  bool _isSearchPressed = false;

  bool _keyboardWasVisible = false;

  late final AnimationController _breathingController;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _focusNode.addListener(_handleFocusChanged);

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);

    _hintTimer = Timer.periodic(
      const Duration(milliseconds: 3400),
      (_) {
        if (!mounted) return;

        if (_isFocused ||
            _controller.text.trim().isNotEmpty) {
          return;
        }

        setState(() {
          _hintIndex =
              (_hintIndex + 1) % _hints.length;
        });
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _hintTimer?.cancel();
    _keyboardCheckTimer?.cancel();

    _focusNode.removeListener(
      _handleFocusChanged,
    );

    _breathingController.dispose();
    _controller.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final view =
        WidgetsBinding.instance.platformDispatcher.views.first;

    final keyboardVisible =
        view.viewInsets.bottom > 0;

    if (keyboardVisible) {
      _keyboardWasVisible = true;
      _keyboardCheckTimer?.cancel();
      return;
    }

    if (!_keyboardWasVisible || !_focusNode.hasFocus) {
      return;
    }

    _keyboardCheckTimer?.cancel();

    _keyboardCheckTimer = Timer(
      const Duration(milliseconds: 350),
      () {
        if (!mounted) return;

        final currentView =
            WidgetsBinding.instance.platformDispatcher.views.first;

        final stillHidden =
            currentView.viewInsets.bottom <= 0;

        if (stillHidden &&
            _keyboardWasVisible &&
            _focusNode.hasFocus) {
          _keyboardWasVisible = false;
          _focusNode.unfocus();
        }
      },
    );
  }

  void _handleFocusChanged() {
    if (!mounted) return;

    if (_focusNode.hasFocus) {
      _keyboardWasVisible = false;
    }

    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _onTextChanged(String value) {
    if (!mounted) return;

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

  void _handleFilterTap() {
    widget.onCategoryPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final hasText =
        _controller.text.trim().isNotEmpty;

    final searchBackground = isDark
        ? const Color(0xFF181E27)
        : Colors.white;

    final searchText = isDark
        ? const Color(0xFFF3F6F8)
        : const Color(0xFF172033);

    final searchHint = isDark
        ? const Color(0xFF8793A3)
        : const Color(0xFF9AA4B2);

    final borderColor = isDark
        ? const Color(0xFF252D38)
        : const Color(0xFFE8EDF2);

    final filterBackground = isDark
        ? const Color(0xFF19332F)
        : const Color(0xFFEAF8F6);

    final filterBorder = isDark
        ? const Color(0xFF27524D)
        : const Color(0xFFD8F1ED);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        14,
        12,
        12,
      ),
      child: AnimatedBuilder(
        animation: _breathingController,
        builder: (context, child) {
          final breathing =
              _breathingController.value;

          final focusGlow =
              _isFocused ? breathing : 0.0;

          return AnimatedContainer(
            duration:
                const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            height: 60,
            decoration: BoxDecoration(
              color: searchBackground,
              borderRadius:
                  BorderRadius.circular(21),
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(
                          alpha: 0.18,
                        )
                      : Colors.black.withValues(
                          alpha: 0.055,
                        ),
                  blurRadius:
                      _isFocused ? 18 : 14,
                  offset: const Offset(0, 5),
                  spreadRadius: 0,
                ),
                if (_isFocused)
                  BoxShadow(
                    color: colors.brand.withValues(
                      alpha:
                          0.035 + (focusGlow * 0.025),
                    ),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: child,
          );
        },
        child: Row(
          children: [
            const SizedBox(width: 15),

            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) {
                if (!mounted) return;

                setState(() {
                  _isSearchPressed = true;
                });
              },
              onTapCancel: () {
                if (!mounted) return;

                setState(() {
                  _isSearchPressed = false;
                });
              },
              onTapUp: (_) {
                if (!mounted) return;

                setState(() {
                  _isSearchPressed = false;
                });

                _focusNode.requestFocus();
              },
              child: AnimatedScale(
                scale:
                    _isSearchPressed ? 0.86 : 1.0,
                duration:
                    const Duration(milliseconds: 150),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _isFocused
                        ? colors.brand.withValues(
                            alpha: 0.09,
                          )
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: AnimatedRotation(
                      turns: _isFocused
                          ? 0.02
                          : 0.0,
                      duration:
                          const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        Icons.search_rounded,
                        size: 23,
                        color: colors.brand,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 7),

            Expanded(
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textDirection:
                        TextDirection.rtl,
                    textAlign: TextAlign.right,
                    textAlignVertical:
                        TextAlignVertical.center,
                    textInputAction:
                        TextInputAction.search,
                    onChanged: _onTextChanged,
                    onSubmitted: (_) {
                      _submitSearch();
                    },
                    cursorColor: colors.brand,
                    style: TextStyle(
                      color: searchText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.05,
                    ),
                    decoration:
                        const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder:
                          InputBorder.none,
                      focusedBorder:
                          InputBorder.none,
                      disabledBorder:
                          InputBorder.none,
                      errorBorder:
                          InputBorder.none,
                      focusedErrorBorder:
                          InputBorder.none,
                      filled: false,
                      isCollapsed: true,
                      contentPadding:
                          EdgeInsets.zero,
                    ),
                  ),

                  if (!hasText)
                    IgnorePointer(
                      child: SizedBox(
                        height: 28,
                        child: ClipRect(
                          child: AnimatedSwitcher(
                            duration:
                                const Duration(
                              milliseconds: 520,
                            ),
                            switchInCurve:
                                Curves.easeOutCubic,
                            switchOutCurve:
                                Curves.easeInCubic,
                            transitionBuilder:
                                (child, animation) {
                              final slide =
                                  Tween<Offset>(
                                begin:
                                    const Offset(
                                  0.0,
                                  0.65,
                                ),
                                end: Offset.zero,
                              ).animate(
                                animation,
                              );

                              return FadeTransition(
                                opacity: animation,
                                child:
                                    SlideTransition(
                                  position: slide,
                                  child: child,
                                ),
                              );
                            },
                            child: Align(
                              key: ValueKey(
                                _hints[_hintIndex],
                              ),
                              alignment:
                                  Alignment.centerRight,
                              child: Text(
                                _hints[_hintIndex],
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                textDirection:
                                    TextDirection.rtl,
                                style: TextStyle(
                                  color: searchHint,
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            AnimatedSwitcher(
              duration:
                  const Duration(milliseconds: 180),
              switchInCurve:
                  Curves.easeOutBack,
              switchOutCurve:
                  Curves.easeInCubic,
              transitionBuilder:
                  (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: hasText
                  ? GestureDetector(
                      key: const ValueKey(
                        'clear_button',
                      ),
                      behavior:
                          HitTestBehavior.opaque,
                      onTap: _clearSearch,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 5,
                        ),
                        child: AnimatedContainer(
                          duration:
                              const Duration(
                            milliseconds: 180,
                          ),
                          width: 28,
                          height: 28,
                          decoration:
                              BoxDecoration(
                            color: isDark
                                ? const Color(
                                    0xFF252D38,
                                  )
                                : const Color(
                                    0xFFF0F3F6,
                                  ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: isDark
                                ? const Color(
                                    0xFFA7B0BC,
                                  )
                                : const Color(
                                    0xFF7E8998,
                                  ),
                            size: 17,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey(
                        'no_clear_button',
                      ),
                      width: 0,
                      height: 0,
                    ),
            ),

            const SizedBox(width: 3),

            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) {
                if (!mounted) return;

                setState(() {
                  _isFilterPressed = true;
                });
              },
              onTapCancel: () {
                if (!mounted) return;

                setState(() {
                  _isFilterPressed = false;
                });
              },
              onTapUp: (_) {
                if (!mounted) return;

                setState(() {
                  _isFilterPressed = false;
                });

                _handleFilterTap();
              },
              child: AnimatedScale(
                scale:
                    _isFilterPressed ? 0.91 : 1.0,
                duration:
                    const Duration(milliseconds: 130),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 230),
                  curve: Curves.easeOutCubic,
                  width: 44,
                  height: 44,
                  margin:
                      const EdgeInsets.only(right: 7),
                  decoration: BoxDecoration(
                    color: _isFilterPressed
                        ? colors.brand.withValues(
                            alpha: isDark
                                ? 0.18
                                : 0.13,
                          )
                        : filterBackground,
                    borderRadius:
                        BorderRadius.circular(15),
                    border: Border.all(
                      color: _isFilterPressed
                          ? colors.brand.withValues(
                              alpha: 0.18,
                            )
                          : filterBorder,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: AnimatedRotation(
                      turns: _isFilterPressed
                          ? 0.035
                          : 0.0,
                      duration:
                          const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      child: AnimatedScale(
                        scale:
                            _isFilterPressed ? 0.94 : 1.0,
                        duration:
                            const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          Icons.tune_rounded,
                          color: colors.brand,
                          size: 21,
                        ),
                      ),
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
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/wayn_colors.dart';
import '../../features/home/models/place.dart';
import '../map/place_picker_page.dart';
import 'services/community_service.dart';

class CreatePostPage extends StatefulWidget {
  final CommunityService communityService;

  const CreatePostPage({
    super.key,
    required this.communityService,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  static const Color _waynTeal = Color(0xFF18A99A);
  static const Color _ratingColor = Color(0xFFF5A623);

  late final TextEditingController _textController;

  Place? _selectedPlace;
  XFile? _selectedImage;
  double? _selectedRating;

  bool _isPublishing = false;

  int _currentStep = 0;
  int _previousStep = 0;

  static const int _stepCount = 5;

  @override
  void initState() {
    super.initState();

    _textController = TextEditingController();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // ===========================================================================
  // STEP
  // ===========================================================================

  String get _stepTitle {
    switch (_currentStep) {
      case 0:
        return 'اختر المكان';
      case 1:
        return 'قيّم المكان';
      case 2:
        return 'اكتب تجربتك';
      case 3:
        return 'أضف صورة';
      case 4:
        return 'راجع منشورك';
      default:
        return 'منشور جديد';
    }
  }

  String get _stepDescription {
    switch (_currentStep) {
      case 0:
        return 'حدد المكان الذي تريد مشاركة تجربتك عنه';
      case 1:
        return 'ما تقييمك لهذا المكان؟';
      case 2:
        return 'شارك تجربتك ليستفيد منها الآخرون';
      case 3:
        return 'الصورة اختيارية ويمكنك المتابعة بدونها';
      case 4:
        return 'تأكد من التفاصيل قبل نشر منشورك';
      default:
        return '';
    }
  }

  IconData get _stepIcon {
    switch (_currentStep) {
      case 0:
        return Iconsax.location;
      case 1:
        return Iconsax.star;
      case 2:
        return Iconsax.edit_2;
      case 3:
        return Iconsax.gallery;
      case 4:
        return Iconsax.document_text;
      default:
        return Iconsax.edit;
    }
  }

  bool get _canContinue {
    switch (_currentStep) {
      case 0:
        return _selectedPlace != null;
      case 1:
        return _selectedRating != null;
      case 2:
        return _textController.text.trim().isNotEmpty;
      case 3:
        return true;
      default:
        return false;
    }
  }

  void _goBack() {
    if (_isPublishing) {
      return;
    }

    if (_currentStep == 0) {
      Navigator.of(context).pop(false);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();

    setState(() {
      _previousStep = _currentStep;
      _currentStep--;
    });
  }

  void _close() {
    if (_isPublishing) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.lightImpact();

    Navigator.of(context).pop(false);
  }

  void _goNext() {
    if (_isPublishing || !_canContinue) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();

    if (_currentStep >= _stepCount - 1) {
      return;
    }

    setState(() {
      _previousStep = _currentStep;
      _currentStep++;
    });
  }

  // ===========================================================================
  // IMAGE
  // ===========================================================================

  Future<void> _pickImage() async {
    if (_isPublishing) {
      return;
    }

    final picker = ImagePicker();

    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (image == null || !mounted) {
        return;
      }

      HapticFeedback.mediumImpact();

      setState(() {
        _selectedImage = image;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('تعذر اختيار الصورة');
    }
  }

  void _removeImage() {
    if (_isPublishing) {
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _selectedImage = null;
    });
  }

  // ===========================================================================
  // PLACE
  // ===========================================================================

  Future<void> _pickPlace() async {
    if (_isPublishing) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    HapticFeedback.lightImpact();

    final place = await Navigator.of(context).push<Place>(
      PageRouteBuilder<Place>(
        transitionDuration: const Duration(
          milliseconds: 300,
        ),
        reverseTransitionDuration: const Duration(
          milliseconds: 240,
        ),
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) {
          return PlacePickerPage(
            initialPlace: _selectedPlace,
          );
        },
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          final slideAnimation = Tween<Offset>(
            begin: const Offset(
              0.045,
              0,
            ),
            end: Offset.zero,
          ).animate(curvedAnimation);

          return SlideTransition(
            position: slideAnimation,
            child: child,
          );
        },
      ),
    );

    if (!mounted || place == null) {
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _selectedPlace = place;
    });
  }

  // ===========================================================================
  // RATING
  // ===========================================================================

  void _selectRating(double rating) {
    if (_isPublishing) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _selectedRating = rating;
    });
  }

  // ===========================================================================
  // PUBLISH
  // ===========================================================================

  Future<void> _publish() async {
    if (_isPublishing) {
      return;
    }

    final text = _textController.text.trim();

    if (text.isEmpty) {
      _showMessage('اكتب تجربتك قبل النشر');
      return;
    }

    if (_selectedPlace == null) {
      _showMessage('اختر المكان الذي تتحدث عنه');
      return;
    }

    if (_selectedRating == null) {
      _showMessage('اختر تقييم المكان');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isPublishing = true;
    });

    try {
      String? uploadedImageUrl;

      if (_selectedImage != null) {
        final fileBytes = await _selectedImage!.readAsBytes();

        uploadedImageUrl = await widget.communityService.uploadImage(
          fileBytes: fileBytes,
          fileName: _selectedImage!.name,
        );
      }

      await widget.communityService.createPost(
        placeId: _selectedPlace!.id,
        text: text,
        imageUrl: uploadedImageUrl,
        rating: _selectedRating,
      );

      if (!mounted) {
        return;
      }

      HapticFeedback.heavyImpact();

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPublishing = false;
      });

      _showMessage(
        e is ApiClientException ? e.message : 'تعذر إنشاء المنشور',
      );
    }
  }

  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    final colors = context.waynColors;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: colors.textPrimary,
          margin: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          content: Row(
            textDirection: TextDirection.rtl,
            children: [
              const Icon(
                Iconsax.info_circle,
                color: Colors.white,
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildProgress(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(
                    milliseconds: 400,
                  ),
                  reverseDuration: const Duration(
                    milliseconds: 300,
                  ),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (
                    Widget? currentChild,
                    List<Widget> previousChildren,
                  ) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (
                    Widget child,
                    Animation<double> animation,
                  ) {
                    final isForward = _currentStep >= _previousStep;

                    final begin = isForward
                        ? const Offset(0.055, 0)
                        : const Offset(-0.055, 0);

                    final offsetAnimation = Tween<Offset>(
                      begin: begin,
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );

                    final scaleAnimation = Tween<double>(
                      begin: 0.985,
                      end: 1,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );

                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: offsetAnimation,
                        child: ScaleTransition(
                          scale: scaleAnimation,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_currentStep),
                    child: _buildStep(),
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader() {
    final colors = context.waynColors;

    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: _HeaderButton(
                icon: Icons.arrow_forward_ios_rounded,
                enabled: !_isPublishing,
                onTap: _goBack,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(
                      milliseconds: 220,
                    ),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: Text(
                      _stepTitle,
                      key: ValueKey(_stepTitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedSwitcher(
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    child: Text(
                      '${_currentStep + 1} من $_stepCount',
                      key: ValueKey(_currentStep),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 44,
              height: 44,
              child: _HeaderButton(
                icon: Icons.close_rounded,
                enabled: !_isPublishing,
                onTap: _close,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PROGRESS
  // ===========================================================================

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        3,
        24,
        7,
      ),
      child: SizedBox(
        height: 30,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double currentCircleSize = 20;
            const double normalCircleSize = 14;

            final width = constraints.maxWidth;
            final usableWidth = width - currentCircleSize;
            final spacing = usableWidth / (_stepCount - 1);
            final centerOffset = currentCircleSize / 2;

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: centerOffset,
                  right: centerOffset,
                  top: 13.5,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: context.waynColors.divider.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Positioned(
                  right: centerOffset,
                  top: 13.5,
                  child: AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 420,
                    ),
                    curve: Curves.easeOutCubic,
                    width: spacing * _currentStep,
                    height: 3,
                    decoration: BoxDecoration(
                      color: _waynTeal,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                ...List.generate(
                  _stepCount,
                  (index) {
                    final completed = index <= _currentStep;
                    final current = index == _currentStep;

                    final size = current
                        ? currentCircleSize
                        : normalCircleSize;

                    final rightPosition =
                        centerOffset +
                        spacing * index -
                        (size / 2);

                    final topPosition = (30 - size) / 2;

                    return Positioned(
                      right: rightPosition,
                      top: topPosition,
                      child: AnimatedContainer(
                        duration: const Duration(
                          milliseconds: 280,
                        ),
                        curve: Curves.easeOutCubic,
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: completed
                              ? _waynTeal
                              : context.waynColors.background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: completed
                                ? _waynTeal
                                : context.waynColors.divider,
                            width: current ? 2.2 : 1.5,
                          ),
                          boxShadow: current
                              ? [
                                  BoxShadow(
                                    color: _waynTeal.withValues(
                                      alpha: 0.20,
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: completed
                            ? Center(
                                child: current
                                    ? Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.check_rounded,
                                        size: 8,
                                        color: Colors.white,
                                      ),
                              )
                            : null,
                      ),
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

  // ===========================================================================
  // STEP CONTENT
  // ===========================================================================

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _PlaceStep(
          key: const ValueKey('place_step'),
          place: _selectedPlace,
          title: _stepTitle,
          description: _stepDescription,
          icon: _stepIcon,
          onPickPlace: _pickPlace,
        );

      case 1:
        return _RatingStep(
          key: const ValueKey('rating_step'),
          selectedRating: _selectedRating,
          title: _stepTitle,
          description: _stepDescription,
          icon: _stepIcon,
          onRatingSelected: _selectRating,
        );

      case 2:
        return _TextStep(
          key: const ValueKey('text_step'),
          controller: _textController,
          title: _stepTitle,
          description: _stepDescription,
          icon: _stepIcon,
        );

      case 3:
        return _ImageStep(
          key: const ValueKey('image_step'),
          image: _selectedImage,
          title: _stepTitle,
          description: _stepDescription,
          icon: _stepIcon,
          onPickImage: _pickImage,
          onRemoveImage: _removeImage,
        );

      case 4:
        return _PreviewStep(
          key: const ValueKey('preview_step'),
          place: _selectedPlace,
          rating: _selectedRating,
          text: _textController.text.trim(),
          image: _selectedImage,
          title: _stepTitle,
          description: _stepDescription,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ===========================================================================
  // BOTTOM BAR
  // ===========================================================================

  Widget _buildBottomBar() {
    if (_currentStep == 4) {
      return _PublishBar(
        isPublishing: _isPublishing,
        onPublish: _publish,
      );
    }

    return _ContinueBar(
      enabled: _canContinue,
      text: 'متابعة',
      onTap: _goNext,
    );
  }
}

// ============================================================================
// PLACE STEP
// ============================================================================

class _PlaceStep extends StatefulWidget {
  final Place? place;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onPickPlace;

  const _PlaceStep({
    super.key,
    required this.place,
    required this.title,
    required this.description,
    required this.icon,
    required this.onPickPlace,
  });

  @override
  State<_PlaceStep> createState() => _PlaceStepState();
}

class _PlaceStepState extends State<_PlaceStep> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _pressed = true;
    });
  }

  void _handleTapCancel() {
    if (!mounted) {
      return;
    }

    setState(() {
      _pressed = false;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    if (!mounted) {
      return;
    }

    setState(() {
      _pressed = false;
    });

    widget.onPickPlace();
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24,
      ),
      child: Column(
        children: [
          _StepIntro(
            title: widget.title,
            description: widget.description,
            icon: widget.icon,
          ),
          const SizedBox(height: 30),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _handleTapDown,
            onTapCancel: _handleTapCancel,
            onTapUp: _handleTapUp,
            child: AnimatedScale(
              scale: _pressed ? 0.985 : 1,
              duration: const Duration(
                milliseconds: 130,
              ),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(
                  milliseconds: 260,
                ),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: 245,
                ),
                decoration: BoxDecoration(
                  color: context.waynColors.surface,
                  borderRadius: BorderRadius.circular(27),
                  border: Border.all(
                    color: place == null
                        ? _CreatePostPageState._waynTeal.withValues(
                            alpha: 0.10,
                          )
                        : _CreatePostPageState._waynTeal.withValues(
                            alpha: 0.30,
                          ),
                    width: place == null ? 1 : 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: _pressed ? 0.025 : 0.035,
                      ),
                      blurRadius: _pressed ? 18 : 24,
                      offset: Offset(
                        0,
                        _pressed ? 6 : 10,
                      ),
                    ),
                  ],
                ),
                child: place == null
                    ? const _EmptyPlaceSelector()
                    : _SelectedPlaceSelector(
                        place: place,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          const _InfoHint(
            icon: Iconsax.map_1,
            text: 'يمكنك البحث عن المكان أو تحديده مباشرة من الخريطة.',
          ),
        ],
      ),
    );
  }
}

class _EmptyPlaceSelector extends StatelessWidget {
  const _EmptyPlaceSelector();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: _CreatePostPageState._waynTeal.withValues(
              alpha: 0.08,
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Iconsax.location,
            size: 36,
            color: Color(0xFF18A99A),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'حدد المكان',
          style: TextStyle(
            color: context.waynColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'اضغط لفتح الخريطة',
          style: TextStyle(
            color: context.waynColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: _CreatePostPageState._waynTeal,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.location,
                color: Colors.white,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'تحديد',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedPlaceSelector extends StatelessWidget {
  final Place place;

  const _SelectedPlaceSelector({
    required this.place,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _CreatePostPageState._waynTeal.withValues(
                alpha: 0.09,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.location_tick,
              color: Color(0xFF18A99A),
              size: 31,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            place.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (place.city.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.location,
                  size: 14,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  place.city,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: _CreatePostPageState._waynTeal.withValues(
                alpha: 0.07,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.refresh,
                  size: 15,
                  color: Color(0xFF18A99A),
                ),
                SizedBox(width: 6),
                Text(
                  'اضغط لتغيير المكان',
                  style: TextStyle(
                    color: Color(0xFF18A99A),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
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

// ============================================================================
// RATING STEP
// ============================================================================

class _RatingStep extends StatelessWidget {
  final double? selectedRating;
  final String title;
  final String description;
  final IconData icon;
  final ValueChanged<double> onRatingSelected;

  const _RatingStep({
    super.key,
    required this.selectedRating,
    required this.title,
    required this.description,
    required this.icon,
    required this.onRatingSelected,
  });

  String get _ratingLabel {
    switch (selectedRating?.toInt()) {
      case 1:
        return 'سيئ جدًا';
      case 2:
        return 'يحتاج إلى تحسين';
      case 3:
        return 'جيد';
      case 4:
        return 'جيد جدًا';
      case 5:
        return 'ممتاز';
      default:
        return 'اختر تقييمك';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24,
      ),
      child: Column(
        children: [
          _StepIntro(
            title: title,
            description: description,
            icon: icon,
          ),
          const SizedBox(height: 44),
          _RatingStars(
            selectedRating: selectedRating,
            onSelected: onRatingSelected,
          ),
          const SizedBox(height: 26),
          AnimatedSwitcher(
            duration: const Duration(
              milliseconds: 220,
            ),
            transitionBuilder: (
              child,
              animation,
            ) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.92,
                    end: 1,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            child: Text(
              _ratingLabel,
              key: ValueKey(_ratingLabel),
              style: TextStyle(
                color: selectedRating == null
                    ? context.waynColors.textSecondary
                    : context.waynColors.textPrimary,
                fontSize: selectedRating == null ? 14 : 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (selectedRating != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: _CreatePostPageState._ratingColor.withValues(
                  alpha: 0.08,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star,
                    color: _CreatePostPageState._ratingColor,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${selectedRating!.toInt()} / 5',
                    style: TextStyle(
                      color: context.waynColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  final double? selectedRating;
  final ValueChanged<double> onSelected;

  const _RatingStars({
    required this.selectedRating,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        5,
        (index) {
          final value = index + 1;
          final selected =
              selectedRating != null && value <= selectedRating!;

          return _RatingStar(
            value: value,
            selected: selected,
            onTap: () => onSelected(
              value.toDouble(),
            ),
          );
        },
      ),
    );
  }
}

class _RatingStar extends StatefulWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const _RatingStar({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_RatingStar> createState() => _RatingStarState();
}

class _RatingStarState extends State<_RatingStar> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapCancel: () {
        if (!mounted) {
          return;
        }

        setState(() {
          _pressed = false;
        });
      },
      onTapUp: (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _pressed = false;
        });

        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed
            ? 0.82
            : widget.selected
                ? 1.08
                : 1,
        duration: const Duration(
          milliseconds: 130,
        ),
        curve: Curves.easeOutBack,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 3,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(
              milliseconds: 170,
            ),
            transitionBuilder: (
              child,
              animation,
            ) {
              return ScaleTransition(
                scale: animation,
                child: child,
              );
            },
            child: Icon(
              widget.selected
                  ? Icons.star
                  : Icons.star_border,
              key: ValueKey(widget.selected),
              size: 51,
              color: _CreatePostPageState._ratingColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TEXT STEP
// ============================================================================

class _TextStep extends StatefulWidget {
  final TextEditingController controller;
  final String title;
  final String description;
  final IconData icon;

  const _TextStep({
    super.key,
    required this.controller,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  State<_TextStep> createState() => _TextStepState();
}

class _TextStepState extends State<_TextStep> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      FocusScope.of(context).requestFocus(
        _focusNode,
      );
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;
    final text = widget.controller.text;
    final hasText = text.trim().isNotEmpty;
    final remaining = 1000 - text.length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24,
      ),
      child: Column(
        children: [
          _StepIntro(
            title: widget.title,
            description: widget.description,
            icon: widget.icon,
          ),
          const SizedBox(height: 27),
          AnimatedContainer(
            duration: const Duration(
              milliseconds: 220,
            ),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: hasText
                    ? _CreatePostPageState._waynTeal.withValues(
                        alpha: 0.28,
                      )
                    : colors.divider,
                width: hasText ? 1.3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.035,
                  ),
                  blurRadius: 22,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  minLines: 8,
                  maxLines: 13,
                  maxLength: 1000,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  cursorColor: _CreatePostPageState._waynTeal,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    height: 1.7,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'اكتب تجربتك مع المكان...\n\nما الذي أعجبك؟ وما الذي يمكن تحسينه؟',
                    hintTextDirection: TextDirection.rtl,
                    hintStyle: TextStyle(
                      color: colors.textMuted,
                      fontSize: 14,
                      height: 1.7,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      10,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _CreatePostPageState._waynTeal.withValues(
                            alpha: 0.07,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Iconsax.edit_2,
                          size: 14,
                          color: _CreatePostPageState._waynTeal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasText
                              ? 'تجربتك جاهزة تقريبًا'
                              : 'اكتب تجربتك بوضوح وبأسلوبك',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(
                          milliseconds: 180,
                        ),
                        child: Text(
                          '$remaining',
                          key: ValueKey(remaining),
                          style: TextStyle(
                            color: remaining < 100
                                ? _CreatePostPageState._waynTeal
                                : colors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _InfoHint(
            icon: Iconsax.message_text,
            text: 'حاول أن تكون تجربتك واضحة ومفيدة للآخرين.',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// IMAGE STEP
// ============================================================================

class _ImageStep extends StatelessWidget {
  final XFile? image;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;

  const _ImageStep({
    super.key,
    required this.image,
    required this.title,
    required this.description,
    required this.icon,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24,
      ),
      child: Column(
        children: [
          _StepIntro(
            title: title,
            description: description,
            icon: icon,
          ),
          const SizedBox(height: 30),
          AnimatedSwitcher(
            duration: const Duration(
              milliseconds: 300,
            ),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (
              child,
              animation,
            ) {
              final scaleAnimation = Tween<double>(
                begin: 0.94,
                end: 1,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              );

              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: scaleAnimation,
                  child: child,
                ),
              );
            },
            child: image == null
                ? _EmptyImageSelector(
                    key: const ValueKey(
                      'empty_image',
                    ),
                    onTap: onPickImage,
                  )
                : _SelectedImageSelector(
                    key: const ValueKey(
                      'selected_image',
                    ),
                    image: image!,
                    onRemove: onRemoveImage,
                  ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: context.waynColors.textSecondary.withValues(
                alpha: 0.07,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.info_circle,
                  size: 15,
                  color: context.waynColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'الصورة اختيارية',
                  style: TextStyle(
                    color: context.waynColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
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

class _EmptyImageSelector extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyImageSelector({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 285,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _CreatePostPageState._waynTeal.withValues(
              alpha: 0.10,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.03,
              ),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _CreatePostPageState._waynTeal.withValues(
                  alpha: 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.gallery_add,
                size: 36,
                color: Color(0xFF18A99A),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'أضف صورة',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'من معرض الصور',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 19,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _CreatePostPageState._waynTeal,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Iconsax.gallery_add,
                    color: Colors.white,
                    size: 17,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'اختيار صورة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
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

class _SelectedImageSelector extends StatelessWidget {
  final XFile image;
  final VoidCallback onRemove;

  const _SelectedImageSelector({
    super.key,
    required this.image,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Image.file(
            File(image.path),
            width: double.infinity,
            height: 320,
            fit: BoxFit.cover,
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
            ) {
              return Container(
                width: double.infinity,
                height: 320,
                color: colors.surfaceAlt,
                child: Icon(
                  Iconsax.gallery_slash,
                  size: 38,
                  color: colors.textMuted,
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: Material(
            color: Colors.black.withValues(
              alpha: 0.62,
            ),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(9),
                child: Icon(
                  Iconsax.trash,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(
                alpha: 0.58,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.gallery,
                  color: Colors.white,
                  size: 15,
                ),
                SizedBox(width: 6),
                Text(
                  'الصورة جاهزة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PREVIEW STEP
// ============================================================================

class _PreviewStep extends StatelessWidget {
  final Place? place;
  final double? rating;
  final String text;
  final XFile? image;
  final String title;
  final String description;

  const _PreviewStep({
    super.key,
    required this.place,
    required this.rating,
    required this.text,
    required this.image,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        24,
      ),
      child: Column(
        children: [
          _StepIntro(
            title: title,
            description: description,
            icon: Iconsax.document_text,
          ),
          const SizedBox(height: 22),
          _PreviewPostCard(
            place: place,
            rating: rating,
            text: text,
            image: image,
          ),
          const SizedBox(height: 12),
          Text(
            'هذه هي الطريقة التي سيظهر بها منشورك في المجتمع.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.waynColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PREVIEW POST CARD
// ============================================================================

class _PreviewPostCard extends StatelessWidget {
  final Place? place;
  final double? rating;
  final String text;
  final XFile? image;

  static const Color _amber = Color(0xFFF5A524);
  static const Color _likeColor = Color(0xFF18A99A);
  static const Color _saveColor = Color(0xFFF59E0B);
  static const Color _commentColor = Color(0xFF64748B);

  const _PreviewPostCard({
    required this.place,
    required this.rating,
    required this.text,
    required this.image,
  });

  String _ratingText() {
    if (rating == null) {
      return '';
    }

    return rating!.truncateToDouble() == rating
        ? rating!.toInt().toString()
        : rating!.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 31,
              child: Row(
                children: [
                  if (rating != null)
                    Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _amber.withValues(
                          alpha: 0.10,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            size: 17,
                            color: _amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _ratingText(),
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (rating != null)
                    const SizedBox(width: 7),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _likeColor.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Iconsax.location,
                              size: 14,
                              color: _likeColor,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                place?.name ?? 'المكان',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      color: colors.textSecondary,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            Divider(
              height: 1,
              color: colors.divider.withValues(
                alpha: 0.60,
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _likeColor.withValues(
                      alpha: 0.10,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'أ',
                      style: TextStyle(
                        color: _likeColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أنت',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'الآن',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (place != null &&
                              place!.city.trim().isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Text(
                              '•',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                place!.city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Iconsax.medal_star,
                        size: 14,
                        color: colors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '0',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  height: 31,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _likeColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: _likeColor.withValues(
                          alpha: 0.16,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'متابعة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              text,
              textAlign: TextAlign.right,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14.5,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (image != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(
                  File(image!.path),
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) {
                    return Container(
                      height: 180,
                      color: colors.surfaceAlt,
                      child: Icon(
                        Iconsax.gallery_slash,
                        size: 32,
                        color: colors.textMuted,
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: colors.divider.withValues(
                alpha: 0.60,
              ),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: _PreviewAction(
                    icon: Icons.thumb_up_outlined,
                    label: 'إعجاب',
                    color: _likeColor,
                  ),
                ),
                Expanded(
                  child: _PreviewAction(
                    icon: Iconsax.message_text_1,
                    label: 'تعليق',
                    color: _commentColor,
                  ),
                ),
                Expanded(
                  child: _PreviewAction(
                    icon: Icons.bookmark_border_rounded,
                    label: 'حفظ',
                    color: _saveColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PreviewAction({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: colors.surfaceAlt,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// STEP INTRO
// ============================================================================

class _StepIntro extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;

  const _StepIntro({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  State<_StepIntro> createState() => _StepIntroState();
}

class _StepIntroState extends State<_StepIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1800,
      ),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Column(
      children: [
        const SizedBox(height: 22),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final value = Curves.easeInOut.transform(
              _controller.value,
            );

            return Transform.translate(
              offset: Offset(
                0,
                -3 * value,
              ),
              child: child,
            );
          },
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: _CreatePostPageState._waynTeal.withValues(
                alpha: 0.08,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _CreatePostPageState._waynTeal,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _CreatePostPageState._waynTeal.withValues(
                        alpha: 0.18,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 25,
            height: 1.2,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 30,
          ),
          child: Text(
            widget.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13.5,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// INFO HINT
// ============================================================================

class _InfoHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoHint({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: _CreatePostPageState._waynTeal.withValues(
          alpha: 0.045,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _CreatePostPageState._waynTeal.withValues(
                alpha: 0.08,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 15,
              color: _CreatePostPageState._waynTeal,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HEADER BUTTON
// ============================================================================

class _HeaderButton extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled
          ? (_) {
              setState(() {
                _pressed = true;
              });
            }
          : null,
      onTapCancel: () {
        if (!mounted) {
          return;
        }

        setState(() {
          _pressed = false;
        });
      },
      onTapUp: (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _pressed = false;
        });

        if (widget.enabled) {
          widget.onTap();
        }
      },
      child: AnimatedScale(
        scale: _pressed ? 0.91 : 1,
        duration: const Duration(
          milliseconds: 120,
        ),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.divider,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Icon(
              widget.icon,
              size: 17,
              color: widget.enabled
                  ? colors.textPrimary
                  : colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CONTINUE BAR
// ============================================================================

class _ContinueBar extends StatelessWidget {
  final bool enabled;
  final String text;
  final VoidCallback onTap;

  const _ContinueBar({
    required this.enabled,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _BottomButton(
          text: text,
          enabled: enabled,
          icon: Icons.arrow_forward_rounded,
          onTap: onTap,
        ),
      ),
    );
  }
}

// ============================================================================
// PUBLISH BAR
// ============================================================================

class _PublishBar extends StatelessWidget {
  final bool isPublishing;
  final VoidCallback onPublish;

  const _PublishBar({
    required this.isPublishing,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.04,
            ),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _BottomButton(
          text: 'نشر المنشور',
          enabled: !isPublishing,
          loading: isPublishing,
          icon: Iconsax.send_2,
          onTap: onPublish,
        ),
      ),
    );
  }
}

// ============================================================================
// BOTTOM BUTTON
// ============================================================================

class _BottomButton extends StatefulWidget {
  final String text;
  final bool enabled;
  final bool loading;
  final IconData icon;
  final VoidCallback onTap;

  const _BottomButton({
    required this.text,
    required this.enabled,
    required this.onTap,
    required this.icon,
    this.loading = false,
  });

  @override
  State<_BottomButton> createState() => _BottomButtonState();
}

class _BottomButtonState extends State<_BottomButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;
    final active = widget.enabled && !widget.loading;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active
          ? (_) {
              setState(() {
                _pressed = true;
              });
            }
          : null,
      onTapCancel: () {
        if (!mounted) {
          return;
        }

        setState(() {
          _pressed = false;
        });
      },
      onTapUp: (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _pressed = false;
        });

        if (active) {
          widget.onTap();
        }
      },
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(
          milliseconds: 120,
        ),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 220,
          ),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: active
                ? _CreatePostPageState._waynTeal
                : colors.textSecondary.withValues(
                    alpha: 0.10,
                  ),
            borderRadius: BorderRadius.circular(17),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _CreatePostPageState._waynTeal.withValues(
                        alpha: 0.18,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(
                milliseconds: 180,
              ),
              child: widget.loading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      key: ValueKey(widget.text),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Icon(
                            widget.icon,
                            size: 18,
                            color: active
                                ? Colors.white
                                : colors.textSecondary.withValues(
                                    alpha: 0.45,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          widget.text,
                          style: TextStyle(
                            color: active
                                ? Colors.white
                                : colors.textSecondary.withValues(
                                    alpha: 0.55,
                                  ),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
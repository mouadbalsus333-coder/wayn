import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
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
  static const Color _waynText = Color(0xFF172033);
  static const Color _waynBackground = Color(0xFFF7F9FC);

  late final TextEditingController _textController;

  Place? _selectedPlace;
  XFile? _selectedImage;
  double? _selectedRating;

  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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

  // ===========================================================================
  // PLACE
  // ===========================================================================

  Future<void> _pickPlace() async {
    if (_isPublishing) {
      return;
    }

    final place = await Navigator.of(context).push<Place>(
      MaterialPageRoute(
        builder: (_) => PlacePickerPage(
          initialPlace: _selectedPlace,
        ),
      ),
    );

    if (!mounted || place == null) {
      return;
    }

    setState(() {
      _selectedPlace = place;
    });
  }

  // ===========================================================================
  // RATING
  // ===========================================================================

  Future<void> _pickRating() async {
    if (_isPublishing) {
      return;
    }

    final rating = await _showRatingPicker(
      context,
      _selectedRating,
    );

    if (!mounted || rating == null) {
      return;
    }

    setState(() {
      _selectedRating = rating;
    });
  }

  Future<double?> _showRatingPicker(
    BuildContext context,
    double? currentRating,
  ) async {
    double selectedRating = currentRating ?? 0;

    return showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: false,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  24,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D5DD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'قيّم المكان',
                      style: TextStyle(
                        color: _waynText,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedRating == 0
                          ? 'اختر تقييمك من نجمة إلى خمس نجوم'
                          : 'تقييمك ${selectedRating.toInt()} من 5',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (index) {
                          final value = index + 1;

                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedRating = value.toDouble();
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Icon(
                                value <= selectedRating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 44,
                                color: const Color(0xFFF5A623),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: selectedRating == 0
                            ? null
                            : () {
                                Navigator.pop(
                                  context,
                                  selectedRating,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _waynTeal,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFFE5E7EB),
                          disabledForegroundColor:
                              const Color(0xFF98A2B3),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'تأكيد التقييم',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
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
      _showMessage('اكتب شيئًا قبل النشر');
      return;
    }

    if (_selectedPlace == null) {
      _showMessage('اختر المكان الذي تتحدث عنه');
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

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPublishing = false;
      });

      _showMessage(
        e is ApiClientException
            ? e.message
            : 'تعذر إنشاء المنشور',
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

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _waynBackground,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            tooltip: 'إغلاق',
            onPressed: _isPublishing
                ? null
                : () => Navigator.of(context).pop(false),
            icon: const Icon(
              Icons.close_rounded,
              color: _waynText,
            ),
          ),
          title: const Text(
            'منشور جديد',
            style: TextStyle(
              color: _waynText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: 12,
              ),
              child: Center(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _isPublishing ? null : _publish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _waynTeal,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFFE5E7EB),
                      disabledForegroundColor:
                          const Color(0xFF98A2B3),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 17,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: _isPublishing
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'نشر',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // =================================================================
                // TEXT
                // =================================================================

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE9EDF2),
                    ),
                  ),
                  child: TextField(
                    controller: _textController,
                    enabled: !_isPublishing,
                    autofocus: true,
                    maxLines: null,
                    minLines: 8,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'شارك تجربتك مع مجتمع وين...',
                      hintTextDirection: TextDirection.rtl,
                      hintStyle: TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(17),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // =================================================================
                // TOOLBAR
                //
                // الأدوات أصبحت مباشرة تحت مربع الكتابة.
                // لم تعد مثبتة في أسفل الشاشة، لذلك لا تتحرك مع الكيبورد.
                // =================================================================

                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE9EDF2),
                    ),
                  ),
                  child: Row(
                    children: [
                      _ComposerToolButton(
                        icon: Icons.photo_library_outlined,
                        color: _waynTeal,
                        tooltip: 'إضافة صورة',
                        enabled: !_isPublishing,
                        onTap: _pickImage,
                      ),
                      const SizedBox(width: 5),
                      _ComposerToolButton(
                        icon: Icons.star_outline_rounded,
                        color: const Color(0xFFF5A623),
                        tooltip: 'إضافة تقييم',
                        enabled: !_isPublishing,
                        onTap: _pickRating,
                      ),
                      const SizedBox(width: 5),
                      _ComposerToolButton(
                        icon: Icons.location_on_outlined,
                        color: _waynTeal,
                        tooltip: 'اختيار المكان',
                        enabled: !_isPublishing,
                        onTap: _pickPlace,
                      ),
                      const Spacer(),
                      if (_selectedPlace != null)
                        Flexible(
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _waynTeal.withValues(
                                alpha: 0.07,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _waynTeal.withValues(
                                  alpha: 0.14,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 17,
                                  color: _waynTeal,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _selectedPlace!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _waynText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // =================================================================
                // IMAGE
                // =================================================================

                if (_selectedImage != null) ...[
                  const SizedBox(height: 14),
                  _SelectedImagePreview(
                    imagePath: _selectedImage!.path,
                    onRemove: _isPublishing
                        ? null
                        : () {
                            setState(() {
                              _selectedImage = null;
                            });
                          },
                  ),
                ],

                // =================================================================
                // PLACE
                // =================================================================

                if (_selectedPlace != null) ...[
                  const SizedBox(height: 14),
                  _SelectedPlaceCard(
                    place: _selectedPlace!,
                    onRemove: _isPublishing
                        ? null
                        : () {
                            setState(() {
                              _selectedPlace = null;
                            });
                          },
                  ),
                ],

                // =================================================================
                // RATING
                // =================================================================

                if (_selectedRating != null) ...[
                  const SizedBox(height: 14),
                  _SelectedRatingCard(
                    rating: _selectedRating!,
                    onRemove: _isPublishing
                        ? null
                        : () {
                            setState(() {
                              _selectedRating = null;
                            });
                          },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPOSER TOOL BUTTON
// ============================================================================

class _ComposerToolButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  const _ComposerToolButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled
        ? color
        : const Color(0xFFB8BEC8);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: effectiveColor.withValues(
                alpha: 0.09,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 21,
              color: effectiveColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SELECTED IMAGE
// ============================================================================

class _SelectedImagePreview extends StatelessWidget {
  final String imagePath;
  final VoidCallback? onRemove;

  const _SelectedImagePreview({
    required this.imagePath,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.file(
            File(imagePath),
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return Container(
                width: double.infinity,
                height: 220,
                color: const Color(0xFFF1F3F6),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  color: Color(0xFF8B94A3),
                  size: 40,
                ),
              );
            },
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 8,
            left: 8,
            child: _RemoveButton(
              onTap: onRemove!,
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// SELECTED PLACE
// ============================================================================

class _SelectedPlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback? onRemove;

  const _SelectedPlaceCard({
    required this.place,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF18A99A).withValues(
          alpha: 0.07,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF18A99A).withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF18A99A).withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Color(0xFF18A99A),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'المكان المختار',
                  style: TextStyle(
                    color: Color(0xFF8B94A3),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (place.city.trim().isNotEmpty)
                  Text(
                    place.city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: 'إزالة المكان',
              icon: const Icon(
                Icons.close_rounded,
                size: 19,
                color: Color(0xFF667085),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// SELECTED RATING
// ============================================================================

class _SelectedRatingCard extends StatelessWidget {
  final double rating;
  final VoidCallback? onRemove;

  const _SelectedRatingCard({
    required this.rating,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFF5A623).withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.star_rounded,
            color: Color(0xFFF5A623),
            size: 22,
          ),
          const SizedBox(width: 7),
          Text(
            '${rating.toInt()} / 5',
            style: const TextStyle(
              color: Color(0xFF172033),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              5,
              (index) => Icon(
                index < rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 17,
                color: const Color(0xFFF5A623),
              ),
            ),
          ),
          const Spacer(),
          if (onRemove != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              tooltip: 'إزالة التقييم',
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFF667085),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// REMOVE BUTTON
// ============================================================================

class _RemoveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RemoveButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(
        alpha: 0.65,
      ),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(7),
          child: Icon(
            Icons.close_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

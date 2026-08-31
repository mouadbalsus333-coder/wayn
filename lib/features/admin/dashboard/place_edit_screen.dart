import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/wayn_api.dart';
import '../../../models/category.dart';
import '../../map/location_picker_page.dart';

/// Real WAYN place management form (create / edit).
///
/// Uses `waynAdminApi` so the operation carries the admin session JWT and the
/// existing backend permission checks are respected. It never bypasses auth
/// and never invents new endpoints — it reuses the backend's own
/// `PlaceCreate` / `PlaceUpdate` contract verbatim.
class AdminPlaceEditScreen extends StatefulWidget {
  final Map<String, dynamic>? place;

  const AdminPlaceEditScreen({super.key, this.place});

  @override
  State<AdminPlaceEditScreen> createState() => _AdminPlaceEditScreenState();
}

class _AdminPlaceEditScreenState extends State<AdminPlaceEditScreen> {
  bool get _isEditing => widget.place != null;

  // Categories loaded from GET /api/v1/categories
  bool _loadingCategories = true;
  String? _categoriesError;
  List<Category> _categories = [];
  String? _selectedCategoryId;

  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _categoryNameCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _latitudeCtrl = TextEditingController();
  final _longitudeCtrl = TextEditingController();
  final _openingCtrl = TextEditingController();
  final _closingCtrl = TextEditingController();
  final _workingHoursCtrl = TextEditingController();
  final _serviceInputCtrl = TextEditingController();
  final _imageInputCtrl = TextEditingController();

  List<String> _services = [];
  List<String> _images = [];

  bool _isOpen = false;
  bool _isActive = true;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefill();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _categoryNameCtrl.dispose();
    _imageUrlCtrl.dispose();
    _descriptionCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    _openingCtrl.dispose();
    _closingCtrl.dispose();
    _workingHoursCtrl.dispose();
    _serviceInputCtrl.dispose();
    _imageInputCtrl.dispose();
    super.dispose();
  }

  /// Opens the existing WAYN map stack in "pick location" mode and fills the
  /// latitude/longitude fields from the confirmed pin position.
  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.of(context).push<Map<String, double>>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLatitude: double.tryParse(_latitudeCtrl.text.trim()),
          initialLongitude: double.tryParse(_longitudeCtrl.text.trim()),
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final latitude = result['latitude'];
    final longitude = result['longitude'];

    if (latitude == null || longitude == null) {
      return;
    }

    setState(() {
      _latitudeCtrl.text = latitude.toStringAsFixed(6);
      _longitudeCtrl.text = longitude.toStringAsFixed(6);
    });
  }

  bool get _hasCoordinatesSelected =>
      double.tryParse(_latitudeCtrl.text.trim()) != null &&
      double.tryParse(_longitudeCtrl.text.trim()) != null;

  Widget _buildLocationPickerCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _pickLocationOnMap,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF18A99A),
              side: const BorderSide(color: Color(0xFF18A99A)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.map_rounded),
            label: const Text(
              'تحديد الموقع على الخريطة',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _hasCoordinatesSelected
                ? 'تم تحديد الموقع ✓'
                : 'لم يتم تحديد الموقع بعد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _hasCoordinatesSelected
                  ? const Color(0xFF18A99A)
                  : const Color(0xFF7A8494),
            ),
          ),
        ],
      ),
    );
  }

  void _prefill() {
    final p = widget.place;
    if (p == null) {
      return;
    }

    _nameCtrl.text = p['name']?.toString() ?? '';
    _cityCtrl.text = p['city']?.toString() ?? '';
    _categoryNameCtrl.text = p['category_name']?.toString() ?? '';
    _imageUrlCtrl.text = p['image_url']?.toString() ?? '';
    _descriptionCtrl.text = p['description']?.toString() ?? '';
    _addressCtrl.text = p['address']?.toString() ?? '';
    _phoneCtrl.text = p['phone']?.toString() ?? '';
    _websiteCtrl.text = p['website']?.toString() ?? '';

    final lat = p['latitude'];
    if (lat != null) {
      _latitudeCtrl.text = '$lat';
    }
    final lng = p['longitude'];
    if (lng != null) {
      _longitudeCtrl.text = '$lng';
    }

    _openingCtrl.text = p['opening_time']?.toString() ?? '';
    _closingCtrl.text = p['closing_time']?.toString() ?? '';

    final wh = p['working_hours_json'];
    if (wh is Map) {
      _workingHoursCtrl.text = jsonEncode(wh);
    }

    _selectedCategoryId = p['category_id']?.toString();
    _isOpen = p['is_open'] == true;
    _isActive = p['is_active'] == true;

    final services = p['services'];
    if (services is List) {
      _services = services.map((e) => e.toString()).toList();
    }
    final images = p['images'];
    if (images is List) {
      _images = images.map((e) => e.toString()).toList();
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoriesError = null;
    });

    try {
      final response = await waynAdminApi.get('/api/v1/categories');

      if (!mounted) return;

      final list = response is List ? response : <dynamic>[];
      final categories = <Category>[];
      for (final item in list) {
        if (item is! Map) continue;
        try {
          categories.add(Category.fromMap(Map<String, dynamic>.from(item)));
        } catch (_) {
          // Ignore malformed rows so a single bad category never
          // breaks the whole selector.
        }
      }

      setState(() {
        _categories = categories;
        _loadingCategories = false;

        // A place being edited may reference a category that is no longer
        // returned by /categories (inactive/deleted). Keeping such an id as
        // the dropdown value would crash DropdownButtonFormField because the
        // value must exist among its items.
        final id = _selectedCategoryId;
        if (id != null && !categories.any((c) => c.id == id)) {
          _selectedCategoryId = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      final msg = error is ApiClientException
          ? 'HTTP ${error.statusCode ?? '؟'} — ${error.message}'
          : '$error';
      setState(() {
        _loadingCategories = false;
        _categoriesError = 'تعذر تحميل التصنيفات ($msg)';
      });
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked == null || !mounted) return;
    String two(int v) => v.toString().padLeft(2, '0');
    controller.text = '${two(picked.hour)}:${two(picked.minute)}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFD95757),
        content: Text(message),
      ),
    );
  }

  String _friendlyError(ApiClientException e) {
    switch (e.statusCode) {
      case 400:
        return e.message;
      case 401:
        return 'جلسة الإدارة غير صالحة. سجّل الدخول مجددًا.';
      case 403:
        return 'لا تملك صلاحية تنفيذ هذه العملية في لوحة الإدارة.';
      case 404:
        return 'المكان غير موجود.';
      case 422:
        return 'البيانات المرسلة غير صالحة: ${e.message}';
      default:
        return 'HTTP ${e.statusCode ?? '؟'} — ${e.message}';
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final categoryName = _categoryNameCtrl.text.trim();
    final imageUrl = _imageUrlCtrl.text.trim();

    if (name.isEmpty ||
        city.isEmpty ||
        categoryName.isEmpty ||
        imageUrl.isEmpty) {
      _showError(
        'يرجى تعبئة الحقول المطلوبة: الاسم، المدينة، التصنيف، ورابط الصورة.',
      );
      return;
    }

    double? latitude;
    if (_latitudeCtrl.text.trim().isNotEmpty) {
      final parsed = double.tryParse(_latitudeCtrl.text.trim());
      if (parsed == null) {
        _showError('قيمة خط العرض (Latitude) غير صالحة.');
        return;
      }
      if (parsed < -90 || parsed > 90) {
        _showError('خط العرض يجب أن يكون بين -90 و 90.');
        return;
      }
      latitude = parsed;
    }

    double? longitude;
    if (_longitudeCtrl.text.trim().isNotEmpty) {
      final parsed = double.tryParse(_longitudeCtrl.text.trim());
      if (parsed == null) {
        _showError('قيمة خط الطول (Longitude) غير صالحة.');
        return;
      }
      if (parsed < -180 || parsed > 180) {
        _showError('خط الطول يجب أن يكون بين -180 و 180.');
        return;
      }
      longitude = parsed;
    }

    Map<String, dynamic>? workingHours;
    if (_workingHoursCtrl.text.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(_workingHoursCtrl.text.trim());
        if (decoded is! Map) {
          throw const FormatException('not an object');
        }
        workingHours = Map<String, dynamic>.from(decoded);
      } catch (_) {
        _showError('حقل أوقات العمل (JSON) غير صالح.');
        return;
      }
    }

    final body = <String, dynamic>{
      'name': name,
      'city': city,
      'category_name': categoryName,
      'image_url': imageUrl,
      'is_open': _isOpen,
      'is_active': _isActive,
      'images': _images,
      'services': _services,
    };

    if (_selectedCategoryId != null) {
      body['category_id'] = _selectedCategoryId;
    }

    if (_descriptionCtrl.text.trim().isNotEmpty) {
      body['description'] = _descriptionCtrl.text.trim();
    }
    if (_addressCtrl.text.trim().isNotEmpty) {
      body['address'] = _addressCtrl.text.trim();
    }
    if (_phoneCtrl.text.trim().isNotEmpty) {
      body['phone'] = _phoneCtrl.text.trim();
    }
    if (_websiteCtrl.text.trim().isNotEmpty) {
      body['website'] = _websiteCtrl.text.trim();
    }
    if (latitude != null) {
      body['latitude'] = latitude;
    }
    if (longitude != null) {
      body['longitude'] = longitude;
    }
    if (_openingCtrl.text.trim().isNotEmpty) {
      body['opening_time'] = _openingCtrl.text.trim();
    }
    if (_closingCtrl.text.trim().isNotEmpty) {
      body['closing_time'] = _closingCtrl.text.trim();
    }
    if (workingHours != null) {
      body['working_hours_json'] = workingHours;
    }

    setState(() => _saving = true);

    try {
      if (_isEditing) {
        final id = widget.place!['id']?.toString();
        if (id == null || id.isEmpty) {
          throw ApiClientException(
            'لا يمكن تحديد المكان المطلوب تعديله.',
            statusCode: 400,
          );
        }
        await waynAdminApi.put(
          '/api/v1/admin/places/$id',
          body: body,
        );
      } else {
        await waynAdminApi.post(
          '/api/v1/admin/places',
          body: body,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(_friendlyError(e));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('تعذر حفظ المكان ($error)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _isEditing ? 'تعديل المكان' : 'إضافة مكان',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _sectionTitle('المعلومات الأساسية'),
            const SizedBox(height: 10),
            _buildRequired(label: 'الاسم', controller: _nameCtrl, hint: 'اسم المكان'),
            const SizedBox(height: 12),
            _buildRequired(label: 'المدينة', controller: _cityCtrl, hint: 'المدينة أو البلدة'),
            const SizedBox(height: 12),
            _categorySelector(),
            const SizedBox(height: 12),
            _buildRequired(
              label: 'رابط الصورة الرئيسية',
              controller: _imageUrlCtrl,
              hint: 'https://...',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('مفتوح الآن', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _isOpen,
                    activeTrackColor: const Color(0xFF18A99A),
                    onChanged: (v) => setState(() => _isOpen = v),
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('مفعّل', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _isActive,
                    activeTrackColor: const Color(0xFF18A99A),
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildField(label: 'الوصف', controller: _descriptionCtrl, hint: 'وصف مختصر للمكان', maxLines: 3),
            const SizedBox(height: 12),
            _buildField(label: 'العنوان', controller: _addressCtrl),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildField(label: 'الهاتف', controller: _phoneCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildField(label: 'الموقع الإلكتروني', controller: _websiteCtrl)),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle('الموقع الجغرافي'),
            const SizedBox(height: 10),
            _buildLocationPickerCard(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildField(label: 'Latitude', controller: _latitudeCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildField(label: 'Longitude', controller: _longitudeCtrl)),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle('أوقات العمل'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _timeField(_openingCtrl, 'وقت الفتح')),
                const SizedBox(width: 12),
                Expanded(child: _timeField(_closingCtrl, 'وقت الإغلاق')),
              ],
            ),
            const SizedBox(height: 12),
            _buildField(
              label: 'أوقات العمل التفصيلية (JSON، اختياري)',
              controller: _workingHoursCtrl,
              hint: '{"السبت":"09:00-18:00"}',
              maxLines: 2,
            ),
            _buildExtra(),
          ],
        ),
      ),
    );
  }
// The remaining sections (services, images, actions) kept in a separate
  // method so the main build stays readable.
  Widget _buildExtra() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        _sectionTitle('الخدمات'),
        const SizedBox(height: 10),
        _tagAdder(
          values: _services,
          controller: _serviceInputCtrl,
          hint: 'مثال: توصيل، واي فاي، مواقف',
          onAdd: () {
            final v = _serviceInputCtrl.text.trim();
            if (v.isEmpty) return;
            setState(() {
              _services.add(v);
              _serviceInputCtrl.clear();
            });
          },
          onRemove: (v) => setState(() => _services.remove(v)),
        ),
        const SizedBox(height: 18),
        _sectionTitle('الصور الإضافية (روابط فقط)'),
        const SizedBox(height: 10),
        _tagAdder(
          values: _images,
          controller: _imageInputCtrl,
          hint: 'https://example.com/img.jpg',
          onAdd: () {
            final v = _imageInputCtrl.text.trim();
            if (v.isEmpty) return;
            setState(() {
              _images.add(v);
              _imageInputCtrl.clear();
            });
          },
          onRemove: (v) => setState(() => _images.remove(v)),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF18A99A),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('حفظ'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }

  Widget _categorySelector() {
    if (_loadingCategories) {
      return _card(
        child: Row(
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('جارٍ تحميل التصنيفات...'),
          ],
        ),
      );
    }

    if (_categories.isNotEmpty) {
      return _card(
        child: DropdownButtonFormField<String>(
          initialValue: _selectedCategoryId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'التصنيف',
            hintText: 'اختر تصنيفًا',
            border: InputBorder.none,
          ),
          items: _categories
              .map(
                (c) => DropdownMenuItem<String>(
                  value: c.id,
                  child: Text(
                    c.nameAr.isNotEmpty ? c.nameAr : (c.nameEn ?? c.id),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategoryId = value;
              final selected =
                  _categories.where((c) => c.id == value).firstOrNull;
              if (selected != null && selected.nameAr.isNotEmpty) {
                _categoryNameCtrl.text = selected.nameAr;
              } else if (selected != null && selected.nameEn != null) {
                _categoryNameCtrl.text = selected.nameEn!;
              }
            });
          },
        ),
      );
    }

    final errorMsg = _categoriesError ?? 'لا توجد تصنيفات متاحة حاليًا.';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: Color(0xFFB07C00)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorMsg,
                  style: const TextStyle(color: Color(0xFF7A8494), fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _categoryNameCtrl,
            decoration: const InputDecoration(
              labelText: 'اسم التصنيف *',
              hintText: 'مثال: مطاعم',
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequired({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return _buildField(label: '$label *', controller: controller, hint: hint);
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3E8EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3E8EF)),
        ),
      ),
    );
  }
Widget _timeField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickTime(controller),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'HH:MM',
        suffixIcon: const Icon(Icons.access_time, color: Color(0xFF18A99A)),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E8EF)),
        ),
      ),
    );
  }

  Widget _tagAdder({
    required List<String> values,
    required TextEditingController controller,
    required String hint,
    required VoidCallback onAdd,
    required void Function(String) onRemove,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hint,
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'إضافة',
                visualDensity: VisualDensity.compact,
                onPressed: onAdd,
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF18A99A),
                ),
              ),
            ],
          ),
          if (values.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in values)
                  InputChip(
                    label: Text(v),
                    backgroundColor: const Color(0xFFE8F8F6),
                    labelStyle: const TextStyle(color: Color(0xFF172033)),
                    onDeleted: () => onRemove(v),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
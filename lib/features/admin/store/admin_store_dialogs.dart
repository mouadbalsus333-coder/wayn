import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'admin_store_models.dart';

const _brandColor = Color(0xFF18A99A);

Future<bool?> showAdminStoreCategoryEditor(
  BuildContext context, {
  AdminStoreCategory? category,
  required Future<void> Function(Map<String, dynamic> body) onSave,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _CategoryEditorDialog(category: category, onSave: onSave),
  );
}

Future<bool?> showAdminStoreItemEditor(
  BuildContext context, {
  AdminStoreItem? item,
  required List<AdminStoreCategory> categories,
  required Future<void> Function(Map<String, dynamic> body) onSave,
  required Future<String> Function({
    required List<int> fileBytes,
    required String fileName,
  })
  onUploadImage,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _ItemEditorDialog(
      item: item,
      categories: categories,
      onSave: onSave,
      onUploadImage: onUploadImage,
    ),
  );
}

class _CategoryEditorDialog extends StatefulWidget {
  final AdminStoreCategory? category;
  final Future<void> Function(Map<String, dynamic> body) onSave;

  const _CategoryEditorDialog({required this.category, required this.onSave});

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final _nameAr = TextEditingController(text: widget.category?.nameAr);
  late final _nameEn = TextEditingController(text: widget.category?.nameEn);
  late final _descriptionAr = TextEditingController(
    text: widget.category?.descriptionAr,
  );
  late final _descriptionEn = TextEditingController(
    text: widget.category?.descriptionEn,
  );
  late final _iconUrl = TextEditingController(text: widget.category?.iconUrl);
  late final _imageUrl = TextEditingController(text: widget.category?.imageUrl);
  late final _sortOrder = TextEditingController(
    text: '${widget.category?.sortOrder ?? 0}',
  );
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isActive = widget.category?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _descriptionAr.dispose();
    _descriptionEn.dispose();
    _iconUrl.dispose();
    _imageUrl.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameAr.text.trim().isEmpty || _nameEn.text.trim().isEmpty) {
      setState(() => _error = 'اكتب الاسم العربي والإنجليزي.');
      return;
    }

    final sortOrder = int.tryParse(_sortOrder.text.trim());
    if (sortOrder == null) {
      setState(() => _error = 'الترتيب يجب أن يكون رقمًا صحيحًا.');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      await widget.onSave({
        'name_ar': _nameAr.text.trim(),
        'name_en': _nameEn.text.trim(),
        'description_ar': _nullable(_descriptionAr.text),
        'description_en': _nullable(_descriptionEn.text),
        'icon_url': _nullable(_iconUrl.text),
        'image_url': _nullable(_imageUrl.text),
        'sort_order': sortOrder,
        'is_active': _isActive,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _apiError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(widget.category == null ? 'إضافة تصنيف' : 'تعديل التصنيف'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _textField(_nameAr, 'الاسم العربي', required: true),
                _textField(_nameEn, 'الاسم الإنجليزي', required: true),
                _textField(_descriptionAr, 'الوصف العربي', maxLines: 2),
                _textField(_descriptionEn, 'الوصف الإنجليزي', maxLines: 2),
                _textField(_iconUrl, 'رابط الأيقونة'),
                _textField(_imageUrl, 'رابط الصورة'),
                _textField(
                  _sortOrder,
                  'ترتيب الظهور',
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('التصنيف فعال'),
                  value: _isActive,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _isActive = value),
                ),
                if (_error != null) _errorText(_error!),
              ],
            ),
          ),
        ),
        actions: _actions(context, _submit, _saving),
      ),
    );
  }
}

class _ItemEditorDialog extends StatefulWidget {
  final AdminStoreItem? item;
  final List<AdminStoreCategory> categories;
  final Future<void> Function(Map<String, dynamic> body) onSave;
  final Future<String> Function({
    required List<int> fileBytes,
    required String fileName,
  })
  onUploadImage;

  const _ItemEditorDialog({
    required this.item,
    required this.categories,
    required this.onSave,
    required this.onUploadImage,
  });

  @override
  State<_ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<_ItemEditorDialog> {
  late final _nameAr = TextEditingController(text: widget.item?.nameAr);
  late final _nameEn = TextEditingController(text: widget.item?.nameEn);
  late final _descriptionAr = TextEditingController(
    text: widget.item?.descriptionAr,
  );
  late final _descriptionEn = TextEditingController(
    text: widget.item?.descriptionEn,
  );
  late final _imageUrl = TextEditingController(text: widget.item?.imageUrl);
  late final _assetId = TextEditingController(text: widget.item?.assetId);
  late final _price = TextEditingController(
    text: widget.item == null ? '' : '${widget.item!.price}',
  );
  late final _ownershipDuration = TextEditingController(
    text: widget.item?.ownershipDurationDays?.toString() ?? '',
  );
  late final _stock = TextEditingController(
    text: widget.item?.stock?.toString() ?? '',
  );
  late final _sortOrder = TextEditingController(
    text: '${widget.item?.sortOrder ?? 0}',
  );

  late String? _categoryId =
      widget.item?.categoryId ??
      (widget.categories.isEmpty ? null : widget.categories.first.id);
  late String _itemType = widget.item?.itemType ?? 'OTHER';
  late String _currency = widget.item?.currency ?? 'COINS';
  late DateTime? _availableFrom = widget.item?.availableFromDate;
  late DateTime? _availableUntil = widget.item?.availableUntilDate;
  bool _isActive = true;
  bool _unlimitedStock = true;
  bool _saving = false;
  String? _error;
  String? _status;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _pickingImage = false;

  static const _maxImageBytes = 10 * 1024 * 1024;
  static const _allowedImageExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  @override
  void initState() {
    super.initState();
    _isActive = widget.item?.isActive ?? true;
    _unlimitedStock = widget.item?.stock == null;
  }

  @override
  void dispose() {
    for (final controller in [
      _nameAr,
      _nameEn,
      _descriptionAr,
      _descriptionEn,
      _imageUrl,
      _assetId,
      _price,
      _ownershipDuration,
      _stock,
      _sortOrder,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool from}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (from ? _availableFrom : _availableUntil) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (from) {
        _availableFrom = selected;
      } else {
        _availableUntil = selected;
      }
    });
  }

  Future<void> _pickImage() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
      if (mounted) {
        setState(() {
          _pickingImage = false;
          _error = 'تعذر اختيار الصورة من الجهاز.';
        });
      }
      return;
    }
    if (!mounted) return;
    if (picked == null) {
      setState(() => _pickingImage = false);
      return;
    }
    final selected = picked;

    final extension = selected.name.contains('.')
        ? selected.name.split('.').last.toLowerCase()
        : '';
    if (!_allowedImageExtensions.contains(extension)) {
      setState(() {
        _pickingImage = false;
        _error = 'اختر صورة بصيغة JPG أو PNG أو WEBP.';
      });
      return;
    }

    Uint8List bytes;
    try {
      bytes = await selected.readAsBytes();
    } catch (_) {
      if (mounted) {
        setState(() {
          _pickingImage = false;
          _error = 'تعذر قراءة ملف الصورة.';
        });
      }
      return;
    }
    if (!mounted) return;
    if (bytes.length > _maxImageBytes) {
      setState(() {
        _pickingImage = false;
        _error = 'حجم الصورة يجب ألا يتجاوز 10 ميجابايت.';
      });
      return;
    }
    if (bytes.isEmpty) {
      setState(() {
        _pickingImage = false;
        _error = 'ملف الصورة فارغ.';
      });
      return;
    }

    setState(() {
      _error = null;
      _pickingImage = false;
      _selectedImageBytes = bytes;
      _selectedImageName = selected.name;
    });
  }

  Future<void> _submit() async {
    if (_categoryId == null) {
      setState(() => _error = 'اختر تصنيفًا للمنتج.');
      return;
    }
    if (_nameAr.text.trim().isEmpty || _nameEn.text.trim().isEmpty) {
      setState(() => _error = 'اكتب الاسم العربي والإنجليزي.');
      return;
    }

    final price = _currency == 'FREE' ? 0 : int.tryParse(_price.text.trim());
    final ownershipDuration = _optionalPositive(_ownershipDuration.text);
    final stock = _unlimitedStock ? null : int.tryParse(_stock.text.trim());
    final sortOrder = int.tryParse(_sortOrder.text.trim());

    if (_currency != 'FREE' && (price == null || price <= 0)) {
      setState(() => _error = 'أدخل سعرًا صحيحًا أكبر من صفر.');
      return;
    }
    if (_ownershipDuration.text.trim().isNotEmpty &&
        ownershipDuration == null) {
      setState(() => _error = 'مدة الملكية يجب أن تكون أكبر من صفر.');
      return;
    }
    if (!_unlimitedStock && (stock == null || stock < 0)) {
      setState(() => _error = 'المخزون يجب أن يكون صفرًا أو أكثر.');
      return;
    }
    if (sortOrder == null) {
      setState(() => _error = 'الترتيب يجب أن يكون رقمًا صحيحًا.');
      return;
    }
    if (_availableFrom != null &&
        _availableUntil != null &&
        _availableUntil!.isBefore(_availableFrom!)) {
      setState(() => _error = 'نهاية التوفر يجب أن تكون بعد البداية.');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      var imageUrl = _nullable(_imageUrl.text);
      if (_selectedImageBytes != null && _selectedImageName != null) {
        setState(() => _status = 'جاري رفع الصورة...');
        try {
          imageUrl = await widget.onUploadImage(
            fileBytes: _selectedImageBytes!,
            fileName: _selectedImageName!,
          );
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _saving = false;
            _status = null;
            _error = 'تعذر رفع صورة المنتج. تحقق من الاتصال وحاول مرة أخرى.';
          });
          return;
        }
      }

      setState(() => _status = 'جاري حفظ العنصر...');
      await widget.onSave({
        'category_id': _categoryId,
        'name_ar': _nameAr.text.trim(),
        'name_en': _nameEn.text.trim(),
        'description_ar': _nullable(_descriptionAr.text),
        'description_en': _nullable(_descriptionEn.text),
        'item_type': _itemType,
        'currency': _currency,
        'price': price,
        'image_url': imageUrl,
        'asset_id': _nullable(_assetId.text),
        'available_from': _availableFrom?.toUtc().toIso8601String(),
        'available_until': _availableUntil?.toUtc().toIso8601String(),
        'ownership_duration_days': ownershipDuration,
        'stock': stock,
        'sort_order': sortOrder,
        'is_active': _isActive,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = null;
        _error = _apiError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(widget.item == null ? 'إضافة عنصر' : 'تعديل العنصر'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _textField(_nameAr, 'اسم المنتج بالعربي', required: true),
                _textField(_nameEn, 'اسم المنتج بالإنجليزي', required: true),
                _textField(_descriptionAr, 'الوصف العربي', maxLines: 2),
                _textField(_descriptionEn, 'الوصف الإنجليزي', maxLines: 2),
                _dropdown(
                  label: 'التصنيف',
                  value: _categoryId,
                  items: widget.categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.nameAr),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _categoryId = value),
                ),
                _dropdown(
                  label: 'نوع المنتج',
                  value: _itemType,
                  items:
                      const [
                            'AVATAR',
                            'FRAME',
                            'GIFT',
                            'SUBSCRIPTION',
                            'PROFILE_BACKGROUND',
                            'BADGE',
                            'OTHER',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _itemType = value!),
                ),
                _dropdown(
                  label: 'العملة',
                  value: _currency,
                  items: const ['COINS', 'POINTS', 'FREE']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_currencyLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _currency = value!),
                ),
                if (_currency != 'FREE')
                  _textField(
                    _price,
                    'السعر',
                    keyboardType: TextInputType.number,
                    required: true,
                  ),
                _imagePickerField(),
                _textField(_imageUrl, 'رابط الصورة (اختياري)'),
                _textField(_assetId, 'معرف الأصل'),
                _dateField(
                  label: 'بداية التوفر',
                  value: _availableFrom,
                  onTap: () => _pickDate(from: true),
                  onClear: () => setState(() => _availableFrom = null),
                ),
                _dateField(
                  label: 'نهاية التوفر',
                  value: _availableUntil,
                  onTap: () => _pickDate(from: false),
                  onClear: () => setState(() => _availableUntil = null),
                ),
                _textField(
                  _ownershipDuration,
                  'مدة الملكية بالأيام (اختياري)',
                  keyboardType: TextInputType.number,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('مخزون غير محدود'),
                  value: _unlimitedStock,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _unlimitedStock = value!),
                ),
                if (!_unlimitedStock)
                  _textField(
                    _stock,
                    'المخزون',
                    keyboardType: TextInputType.number,
                  ),
                _textField(
                  _sortOrder,
                  'ترتيب الظهور',
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('العنصر فعال'),
                  value: _isActive,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _isActive = value),
                ),
                if (_error != null) _errorText(_error!),
              ],
            ),
          ),
        ),
        actions: _actions(context, _submit, _saving),
      ),
    );
  }

  Widget _imagePickerField() {
    final image = _selectedImageBytes != null
        ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
        : (_nullable(_imageUrl.text) == null
              ? null
              : Image.network(_imageUrl.text, fit: BoxFit.cover));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCDD4DD)),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: image ?? const Text('لا توجد صورة للمنتج'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickImage,
            icon: const Icon(Icons.image_outlined),
            label: Text(
              _selectedImageBytes == null ? 'اختيار صورة' : 'تغيير الصورة',
            ),
          ),
          if (_status != null)
            Text(
              _status!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _brandColor),
            ),
        ],
      ),
    );
  }
}

Widget _textField(
  TextEditingController controller,
  String label, {
  bool required = false,
  int maxLines = 1,
  TextInputType? keyboardType,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

Widget _dropdown({
  required String label,
  required String? value,
  required List<DropdownMenuItem<String>> items,
  required ValueChanged<String?>? onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

Widget _dateField({
  required String label,
  required DateTime? value,
  required VoidCallback onTap,
  required VoidCallback onClear,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: Color(0xFFCDD4DD)),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      title: Text(label),
      subtitle: Text(value == null ? 'بدون تحديد' : _dateText(value)),
      leading: const Icon(Icons.calendar_today_outlined, color: _brandColor),
      trailing: value == null
          ? null
          : IconButton(
              tooltip: 'مسح التاريخ',
              onPressed: onClear,
              icon: const Icon(Icons.clear_rounded),
            ),
      onTap: onTap,
    ),
  );
}

List<Widget> _actions(
  BuildContext context,
  VoidCallback onSubmit,
  bool saving,
) {
  return [
    TextButton(
      onPressed: saving ? null : () => Navigator.of(context).pop(false),
      child: const Text('إلغاء'),
    ),
    TextButton(
      onPressed: saving ? null : onSubmit,
      child: saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('حفظ'),
    ),
  ];
}

Widget _errorText(String message) {
  return Align(
    alignment: Alignment.centerRight,
    child: Text(message, style: const TextStyle(color: Color(0xFFD95757))),
  );
}

String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

int? _optionalPositive(String value) {
  if (value.trim().isEmpty) return null;
  final parsed = int.tryParse(value.trim());
  return parsed != null && parsed > 0 ? parsed : null;
}

String _dateText(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _currencyLabel(String value) => switch (value) {
  'COINS' => 'Coins',
  'POINTS' => 'Points',
  'FREE' => 'Free',
  _ => value,
};

String _apiError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');

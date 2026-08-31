import 'package:flutter/material.dart';

import '../models/saved_location.dart';
import '../saved_locations_store.dart';

/// نتيجة اختارها المستخدم من ورقة المواقع.
sealed class LocationSheetResult {
  const LocationSheetResult();
}

class UseGpsResult extends LocationSheetResult {
  const UseGpsResult();
}

class UseSavedLocationResult extends LocationSheetResult {
  final SavedLocation location;

  const UseSavedLocationResult(this.location);
}

class AddLocationResult extends LocationSheetResult {
  const AddLocationResult();
}

/// ورقة أسفلية تعرض المواقع المحفوظة وتسمح باختيار الموقع الحالي
/// (GPS أو موقع محفوظ) أو الانتقال إلى إضافة موقع.
Future<LocationSheetResult?> showLocationSelectorSheet(
  BuildContext context,
) {
  return showModalBottomSheet<LocationSheetResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _LocationSelectorSheet(),
  );
}

class _LocationSelectorSheet extends StatefulWidget {
  const _LocationSelectorSheet();

  @override
  State<_LocationSelectorSheet> createState() => _LocationSelectorSheetState();
}

class _LocationSelectorSheetState extends State<_LocationSelectorSheet> {
  @override
  void initState() {
    super.initState();
    // تأكد من تحميل المواقع قبل العرض.
    SavedLocationsStore.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final store = SavedLocationsStore.instance;

    return SafeArea(
      top: false,
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final locations = store.locations;
          final selected = store.selectedLocation;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E9EF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF18A99A),
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'مواقعي',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF172033),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      _buildGpsTile(store, selected),
                      ...locations.map(
                        (location) =>
                            _buildLocationTile(store, location, selected),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildAddButton(),
                const SizedBox(height: 14),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGpsTile(
    SavedLocationsStore store,
    SavedLocation? selected,
  ) {
    final active = selected == null;

    return _tileContainer(
      active: active,
      onTap: () => Navigator.of(context).pop(const UseGpsResult()),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8F6),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.my_location_rounded,
              color: Color(0xFF18A99A),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الموقع الحالي (GPS)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'موقع الجهاز الفعلي',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8993A3),
                  ),
                ),
              ],
            ),
          ),
          if (active)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF18A99A),
              size: 21,
            ),
        ],
      ),
    );
  }

  Widget _buildLocationTile(
    SavedLocationsStore store,
    SavedLocation location,
    SavedLocation? selected,
  ) {
    final active = selected?.id == location.id;

    return _tileContainer(
      active: active,
      onTap: () => Navigator.of(context).pop(UseSavedLocationResult(location)),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFFE8F8F6)
                  : const Color(0xFFF3F5F8),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: active ? const Color(0xFF18A99A) : const Color(0xFF697386),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: active ? const Color(0xFF172033) : const Color(0xFF263247),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${location.latitude.toStringAsFixed(4)} , '
                  '${location.longitude.toStringAsFixed(4)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8993A3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (active)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF18A99A),
              size: 21,
            )
          else
            GestureDetector(
              onTap: () => store.remove(location.id),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFD95353),
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tileContainer({
    required bool active,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF0FBFA) : const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? const Color(0xFF18A99A) : const Color(0xFFE8ECF1),
            width: active ? 1.5 : 1,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.of(context).pop(const AddLocationResult()),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF18A99A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.add_location_alt_rounded, size: 20),
        label: const Text(
          'إضافة موقع',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
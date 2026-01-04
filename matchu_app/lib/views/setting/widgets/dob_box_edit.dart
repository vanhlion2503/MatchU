import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:matchu_app/controllers/user/account_settings_controller.dart';

/// ================= DOB BOX (EDIT PROFILE) =================

Widget dobBoxEdit(
  BuildContext context, {
  required String label,
  required VoidCallback onTap,
  bool active = false,
  int flex = 1,
}) {
  final theme = Theme.of(context);

  return Expanded(
    flex: flex,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? theme.colorScheme.primary
                : Colors.grey.shade300,
            width: active ? 2 : 1,
          ),
          color: active
              ? theme.colorScheme.primary.withOpacity(0.05)
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: label.contains('D') ||
                    label.contains('M') ||
                    label.contains('Y')
                ? Colors.grey
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    ),
  );
}

/// ================= PICKERS =================

void openEditDayPicker(
  BuildContext context,
  AccountSettingsController c,
) {
  c.selectedDobField.value = DobField.day;

  _openEditPicker(
    context,
    title: "Chọn ngày",
    items: List.generate(31, (i) => (i + 1).toString()),
    onSelected: (v) {
      c.selectedDay.value = int.parse(v);
      c.updateBirthdayIfReady();
    },
  );
}

void openEditMonthPicker(
  BuildContext context,
  AccountSettingsController c,
) {
  c.selectedDobField.value = DobField.month;

  _openEditPicker(
    context,
    title: "Chọn tháng",
    items: List.generate(12, (i) => (i + 1).toString()),
    onSelected: (v) {
      c.selectedMonth.value = int.parse(v);
      c.updateBirthdayIfReady();
    },
  );
}

void openEditYearPicker(
  BuildContext context,
  AccountSettingsController c,
) {
  c.selectedDobField.value = DobField.year;

  final years = List.generate(
    DateTime.now().year - 1950 + 1,
    (i) => (DateTime.now().year - i).toString(),
  );

  _openEditPicker(
    context,
    title: "Chọn năm",
    items: years,
    onSelected: (v) {
      c.selectedYear.value = int.parse(v);
      c.updateBirthdayIfReady();
    },
  );
}

/// ================= INTERNAL PICKER =================

void _openEditPicker(
  BuildContext context, {
  required String title,
  required List<String> items,
  required Function(String) onSelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                onSelectedItemChanged: (i) {
                  onSelected(items[i]);
                },
                children: items
                    .map(
                      (e) => Center(
                        child: Text(
                          e,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      );
    },
  );
}

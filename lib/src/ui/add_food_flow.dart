import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
import '../models/product.dart';
import '../state/diary_controller.dart';
import 'custom_entry_sheet.dart';
import 'format.dart';
import 'product_detail_screen.dart';
import 'scan_screen.dart';
import 'search_screen.dart';

/// Opens the "how do you want to add food?" sheet.
///
/// All four entry points converge on [openProductDetail], so a portion is
/// chosen the same way regardless of how the product was found.
Future<void> showAddFoodFlow(
  BuildContext context, {
  required DiaryController controller,
  required EntryStatus status,
  MealType? meal,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.qr_code_scanner_rounded),
            title: const Text('Skann strekkode'),
            subtitle: const Text('Rett fra varen i butikken eller skapet'),
            onTap: () {
              Navigator.pop(sheetContext);
              _startScan(context, controller, status, meal);
            },
          ),
          ListTile(
            leading: const Icon(Icons.search_rounded),
            title: const Text('Søk etter produkt'),
            subtitle: const Text('Finn varen på navn'),
            onTap: () {
              Navigator.pop(sheetContext);
              _startSearch(context, controller, status, meal);
            },
          ),
          if (controller.recentProducts.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Nylig brukt'),
              subtitle: Text('${controller.recentProducts.length} produkter'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showRecent(context, controller, status, meal);
              },
            ),
          ListTile(
            leading: const Icon(Icons.edit_note_rounded),
            title: const Text('Legg inn manuelt'),
            subtitle: const Text('Hjemmelaget mat eller ukjent vare'),
            onTap: () {
              Navigator.pop(sheetContext);
              showCustomEntrySheet(
                context,
                controller: controller,
                status: status,
                meal: meal,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> _startScan(
  BuildContext context,
  DiaryController controller,
  EntryStatus status,
  MealType? meal,
) async {
  final product = await Navigator.of(
    context,
  ).push<Product>(MaterialPageRoute(builder: (_) => const ScanScreen()));
  if (product != null && context.mounted) {
    await openProductDetail(
      context,
      product,
      controller: controller,
      status: status,
      meal: meal,
    );
  }
}

Future<void> _startSearch(
  BuildContext context,
  DiaryController controller,
  EntryStatus status,
  MealType? meal,
) async {
  final product = await Navigator.of(
    context,
  ).push<Product>(MaterialPageRoute(builder: (_) => const SearchScreen()));
  if (product != null && context.mounted) {
    await openProductDetail(
      context,
      product,
      controller: controller,
      status: status,
      meal: meal,
    );
  }
}

Future<void> _showRecent(
  BuildContext context,
  DiaryController controller,
  EntryStatus status,
  MealType? meal,
) async {
  final product = await showModalBottomSheet<Product>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, scrollController) => ListView.builder(
        controller: scrollController,
        itemCount: controller.recentProducts.length,
        itemBuilder: (_, i) {
          final product = controller.recentProducts[i];
          return ListTile(
            title: Text(product.name),
            subtitle: Text(product.subtitle),
            trailing: Text(
              '${formatKcal(product.nutritionPer100.kcal)} kcal/100 ${product.basis.unitLabel}',
            ),
            onTap: () => Navigator.pop(sheetContext, product),
          );
        },
      ),
    ),
  );

  if (product != null && context.mounted) {
    await openProductDetail(
      context,
      product,
      controller: controller,
      status: status,
      meal: meal,
    );
  }
}

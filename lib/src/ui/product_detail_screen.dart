import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/diary_entry.dart';
import '../models/product.dart';
import '../state/diary_controller.dart';
import 'format.dart';
import 'widgets/macro_bars.dart';

/// Opens the portion picker for [product] and logs the result.
Future<void> openProductDetail(
  BuildContext context,
  Product product, {
  required DiaryController controller,
  required EntryStatus status,
  MealType? meal,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await Navigator.of(context).push<_LogRequest>(
    MaterialPageRoute(
      builder: (_) => ProductDetailScreen(
        product: product,
        status: status,
        initialMeal: meal ?? _mealForNow(),
      ),
    ),
  );
  if (result == null) return;

  await controller.logProduct(
    product,
    meal: result.meal,
    amount: result.amount,
    status: status,
  );

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        status == EntryStatus.planned
            ? '${product.name} lagt i planen'
            : '${product.name} registrert',
      ),
    ),
  );
}

/// Guesses the meal from the clock so the common case needs no tapping.
MealType _mealForNow() {
  final hour = DateTime.now().hour;
  if (hour < 10) return MealType.breakfast;
  if (hour < 14) return MealType.lunch;
  if (hour < 20) return MealType.dinner;
  return MealType.snack;
}

class _LogRequest {
  const _LogRequest({required this.meal, required this.amount});
  final MealType meal;
  final double amount;
}

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.status,
    required this.initialMeal,
  });

  final Product product;
  final EntryStatus status;
  final MealType initialMeal;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final TextEditingController _amountController;
  late MealType _meal;
  double _amount = 100;

  @override
  void initState() {
    super.initState();
    _meal = widget.initialMeal;
    // Default to the whole package when it is a single-serving size, since
    // that is what someone scanning a yoghurt or a soft drink actually ate.
    final package = widget.product.packageSize;
    if (package != null && package <= 500) _amount = package;
    _amountController = TextEditingController(text: _amount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setAmount(double value) {
    setState(() => _amount = value);
    _amountController.text = value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 1,
    );
    _amountController.selection = TextSelection.collapsed(
      offset: _amountController.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final theme = Theme.of(context);
    final unit = product.basis.unitLabel;
    final portion = product.nutrientsFor(_amount);
    final canLog = product.hasNutrition && _amount > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Velg mengde')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _Header(product: product),
          const SizedBox(height: 20),

          if (!product.hasNutrition)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kassalapp har ingen næringsdeklarasjon for dette '
                        'produktet. Legg det inn manuelt hvis du vil spore det.',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (product.hasNutrition) ...[
            Text('Måltid', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<MealType>(
              segments: [
                for (final meal in MealType.values)
                  ButtonSegment(value: meal, label: Text(meal.label)),
              ],
              selected: {_meal},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _meal = s.first),
            ),
            const SizedBox(height: 20),

            Text('Mengde', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(suffixText: unit),
              onChanged: (value) {
                final parsed = double.tryParse(value.replaceAll(',', '.'));
                if (parsed != null) setState(() => _amount = parsed);
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final preset in _presets(product))
                  ActionChip(
                    label: Text(preset.label),
                    onPressed: () => _setAmount(preset.amount),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: NutritionTable(
                  nutrients: portion,
                  header: 'Per ${formatAmount(_amount, unit)}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: NutritionTable(
                  nutrients: product.nutritionPer100,
                  header: 'Per 100 $unit',
                ),
              ),
            ),
          ],

          if (product.allergens.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Allergens(allergens: product.allergens),
          ],

          if (product.ingredients != null) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Ingredienser'),
              tilePadding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    product.ingredients!,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: canLog
                ? () => Navigator.of(
                    context,
                  ).pop(_LogRequest(meal: _meal, amount: _amount))
                : null,
            child: Text(
              widget.status == EntryStatus.planned
                  ? 'Legg i planen · ${formatKcal(portion.kcal)} kcal'
                  : 'Registrer · ${formatKcal(portion.kcal)} kcal',
            ),
          ),
        ),
      ),
    );
  }

  /// Quick-pick amounts: a standard 100, the package itself, and simple
  /// fractions of it when the package is big enough to share.
  List<({String label, double amount})> _presets(Product product) {
    final unit = product.basis.unitLabel;
    final presets = <({String label, double amount})>[
      (label: '100 $unit', amount: 100),
    ];

    final package = product.packageSize;
    if (package != null) {
      presets.add((
        label: 'Hele pakken (${formatAmount(package, unit)})',
        amount: package,
      ));
      if (package >= 200) {
        presets.add((label: 'Halv pakke', amount: package / 2));
      }
      if (package >= 400) {
        presets.add((label: 'Kvart pakke', amount: package / 4));
      }
    }
    return presets;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product.imageUrl != null)
          SizedBox(
            width: 72,
            height: 72,
            child: Image.network(
              product.imageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.shopping_basket_outlined, size: 40),
            ),
          )
        else
          const Icon(Icons.shopping_basket_outlined, size: 56),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name, style: theme.textTheme.titleLarge),
              if (product.subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    product.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (product.currentPrice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    [
                      formatPrice(product.currentPrice),
                      if (product.storeName != null) product.storeName!,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Allergens extends StatelessWidget {
  const _Allergens({required this.allergens});

  final List<Allergen> allergens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only the positive declarations are worth surfacing; listing the dozen
    // allergens a product does *not* contain is noise.
    final relevant = allergens
        .where(
          (a) =>
              a.presence == AllergenPresence.yes ||
              a.presence == AllergenPresence.traces,
        )
        .toList();
    if (relevant.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Allergener', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final allergen in relevant)
              Chip(
                label: Text(
                  allergen.presence == AllergenPresence.traces
                      ? '${allergen.displayName} (spor)'
                      : allergen.displayName,
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Allergeninformasjon er veiledende og kommer fra Kassalapp. '
          'Sjekk alltid emballasjen.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

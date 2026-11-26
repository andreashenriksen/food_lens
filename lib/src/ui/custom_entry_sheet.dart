import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/diary_entry.dart';
import '../models/nutrients.dart';
import '../state/diary_controller.dart';

/// Manual entry, for home cooking and anything Kassalapp does not carry.
///
/// Values are entered for the whole portion rather than per 100 g — when you
/// are typing in last night's stew, you know what you put on the plate, not a
/// reference weight.
Future<void> showCustomEntrySheet(
  BuildContext context, {
  required DiaryController controller,
  required EntryStatus status,
  MealType? meal,
}) async {
  final entry = await showModalBottomSheet<DiaryEntry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _CustomEntryForm(status: status, meal: meal),
    ),
  );

  if (entry != null) await controller.logCustom(entry);
}

class _CustomEntryForm extends StatefulWidget {
  const _CustomEntryForm({required this.status, this.meal});

  final EntryStatus status;
  final MealType? meal;

  @override
  State<_CustomEntryForm> createState() => _CustomEntryFormState();
}

class _CustomEntryFormState extends State<_CustomEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController(text: '1');
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  late MealType _meal = widget.meal ?? MealType.snack;
  String _unit = 'porsjon';

  @override
  void dispose() {
    for (final c in [_name, _amount, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      DiaryEntry(
        date: DateTime.now(),
        meal: _meal,
        status: widget.status,
        name: _name.text.trim(),
        amount: _parse(_amount) ?? 1,
        unit: _unit,
        nutrients: Nutrients(
          kcal: _parse(_kcal),
          protein: _parse(_protein),
          carbs: _parse(_carbs),
          fat: _parse(_fat),
        ),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.status == EntryStatus.planned
                  ? 'Planlegg egen rett'
                  : 'Registrer egen rett',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Navn'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Gi retten et navn' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(labelText: 'Mengde'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Enhet'),
                    items: const [
                      DropdownMenuItem(
                        value: 'porsjon',
                        child: Text('porsjon'),
                      ),
                      DropdownMenuItem(value: 'g', child: Text('g')),
                      DropdownMenuItem(value: 'ml', child: Text('ml')),
                      DropdownMenuItem(value: 'stk', child: Text('stk')),
                    ],
                    onChanged: (v) => setState(() => _unit = v ?? 'porsjon'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Næringsinnhold for hele mengden',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _kcal,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Kalorier',
                suffixText: 'kcal',
              ),
              validator: (v) {
                final parsed = double.tryParse(
                  (v ?? '').trim().replaceAll(',', '.'),
                );
                return parsed == null ? 'Fyll inn antall kalorier' : null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _macroField(_protein, 'Protein')),
                const SizedBox(width: 8),
                Expanded(child: _macroField(_carbs, 'Karbo')),
                const SizedBox(width: 8),
                Expanded(child: _macroField(_fat, 'Fett')),
              ],
            ),
            const SizedBox(height: 20),
            Text('Måltid', style: Theme.of(context).textTheme.titleSmall),
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
            FilledButton(onPressed: _submit, child: const Text('Lagre')),
          ],
        ),
      ),
    );
  }

  Widget _macroField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: 'g'),
      );
}

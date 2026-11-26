import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/settings_repository.dart';
import '../models/daily_goal.dart';
import '../state/diary_controller.dart';
import 'format.dart';

/// Calorie goal, macro split, and the Kassalapp API key.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _kcalController = TextEditingController();
  final _tokenController = TextEditingController();

  bool _hasToken = false;
  bool _macrosEnabled = false;
  double _proteinPct = 30;
  double _carbsPct = 40;
  double _fatPct = 30;

  @override
  void initState() {
    super.initState();
    final goal = context.read<DiaryController>().goal;
    _kcalController.text = goal.kcal.round().toString();
    _macrosEnabled = goal.hasMacroTargets;
    if (_macrosEnabled) {
      // Recover the split from the stored gram targets so the sliders open
      // where the user left them.
      final protein = (goal.proteinG ?? 0) * 4;
      final carbs = (goal.carbsG ?? 0) * 4;
      final fat = (goal.fatG ?? 0) * 9;
      final total = protein + carbs + fat;
      if (total > 0) {
        _proteinPct = (protein / total * 100).roundToDouble();
        _carbsPct = (carbs / total * 100).roundToDouble();
        _fatPct = (100 - _proteinPct - _carbsPct).clamp(0, 100);
      }
    }
    _loadToken();
  }

  Future<void> _loadToken() async {
    final token = await context.read<SettingsRepository>().readToken();
    if (mounted) setState(() => _hasToken = token != null && token.isNotEmpty);
  }

  @override
  void dispose() {
    _kcalController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  double get _kcal =>
      double.tryParse(_kcalController.text.replaceAll(',', '.')) ??
      DailyGoal.fallback.kcal;

  Future<void> _saveGoal() async {
    final controller = context.read<DiaryController>();
    final messenger = ScaffoldMessenger.of(context);

    final goal = _macrosEnabled
        ? DailyGoal.fromSplit(
            kcal: _kcal,
            proteinPercent: _proteinPct,
            carbsPercent: _carbsPct,
            fatPercent: _fatPct,
          )
        : DailyGoal(kcal: _kcal);

    await controller.setGoal(goal);
    messenger.showSnackBar(const SnackBar(content: Text('Mål lagret')));
  }

  Future<void> _saveToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    await context.read<SettingsRepository>().saveToken(token);
    _tokenController.clear();
    if (mounted) setState(() => _hasToken = true);
    messenger.showSnackBar(const SnackBar(content: Text('API-nøkkel lagret')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The macro percentages must add to 100 for the gram targets to be
    // meaningful, so saving is blocked until they do.
    final splitTotal = _proteinPct + _carbsPct + _fatPct;
    final splitValid = !_macrosEnabled || (splitTotal - 100).abs() < 0.5;

    return Scaffold(
      appBar: AppBar(title: const Text('Innstillinger')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Daglig kaloribudsjett', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _kcalController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Kalorigrense',
              suffixText: 'kcal',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Regn ut forslag'),
            onPressed: _openCalculator,
          ),

          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Følg makromål'),
            subtitle: const Text('Fordel kaloriene på protein, karbo og fett'),
            value: _macrosEnabled,
            onChanged: (v) => setState(() => _macrosEnabled = v),
          ),
          if (_macrosEnabled) ...[
            _SplitSlider(
              label: 'Protein',
              percent: _proteinPct,
              grams: _kcal * _proteinPct / 100 / 4,
              onChanged: (v) => setState(() => _proteinPct = v),
            ),
            _SplitSlider(
              label: 'Karbohydrater',
              percent: _carbsPct,
              grams: _kcal * _carbsPct / 100 / 4,
              onChanged: (v) => setState(() => _carbsPct = v),
            ),
            _SplitSlider(
              label: 'Fett',
              percent: _fatPct,
              grams: _kcal * _fatPct / 100 / 9,
              onChanged: (v) => setState(() => _fatPct = v),
            ),
            if (!splitValid)
              Text(
                'Fordelingen må summere til 100 % (nå ${splitTotal.round()} %).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],

          const SizedBox(height: 16),
          FilledButton(
            onPressed: splitValid ? _saveGoal : null,
            child: const Text('Lagre mål'),
          ),

          const Divider(height: 48),

          Text('Kassalapp API', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Produktdata hentes fra Kassalapp, som dekker norske dagligvarer. '
            'Lag en gratis konto på kassal.app, generer en API-nøkkel under '
            'profilen din, og lim den inn her. Nøkkelen lagres kryptert på '
            'enheten og sendes bare til kassal.app.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                _hasToken ? Icons.check_circle_outline : Icons.error_outline,
                size: 20,
                color: _hasToken
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(_hasToken ? 'Nøkkel er lagret' : 'Ingen nøkkel lagret'),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'API-nøkkel',
              hintText: 'Lim inn nøkkelen',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _saveToken,
                  child: const Text('Lagre nøkkel'),
                ),
              ),
              if (_hasToken) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await context.read<SettingsRepository>().clearToken();
                      if (mounted) setState(() => _hasToken = false);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Nøkkel fjernet')),
                      );
                    },
                    child: const Text('Fjern'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openCalculator() async {
    final suggestion = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CalorieCalculator(),
    );
    if (suggestion != null && mounted) {
      setState(() => _kcalController.text = suggestion.round().toString());
    }
  }
}

class _SplitSlider extends StatelessWidget {
  const _SplitSlider({
    required this.label,
    required this.percent,
    required this.grams,
    required this.onChanged,
  });

  final String label;
  final double percent;
  final double grams;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('${percent.round()} % · ${formatGrams(grams)}'),
          ],
        ),
        Slider(
          value: percent,
          max: 100,
          divisions: 20,
          label: '${percent.round()} %',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Mifflin-St Jeor calculator offering a starting point for the limit.
class _CalorieCalculator extends StatefulWidget {
  const _CalorieCalculator();

  @override
  State<_CalorieCalculator> createState() => _CalorieCalculatorState();
}

class _CalorieCalculatorState extends State<_CalorieCalculator> {
  BodySex _sex = BodySex.male;
  ActivityLevel _activity = ActivityLevel.light;
  WeightGoal _goal = WeightGoal.maintain;
  double _age = 30;
  double _weight = 75;
  double _height = 175;

  double get _estimate => estimateDailyCalories(
    sex: _sex,
    ageYears: _age.round(),
    weightKg: _weight,
    heightCm: _height,
    activity: _activity,
    goal: _goal,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Forslag til kaloribudsjett', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          SegmentedButton<BodySex>(
            segments: const [
              ButtonSegment(value: BodySex.female, label: Text('Kvinne')),
              ButtonSegment(value: BodySex.male, label: Text('Mann')),
            ],
            selected: {_sex},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _sex = s.first),
          ),
          _NumberSlider(
            label: 'Alder',
            value: _age,
            min: 15,
            max: 90,
            suffix: 'år',
            onChanged: (v) => setState(() => _age = v),
          ),
          _NumberSlider(
            label: 'Vekt',
            value: _weight,
            min: 40,
            max: 160,
            suffix: 'kg',
            onChanged: (v) => setState(() => _weight = v),
          ),
          _NumberSlider(
            label: 'Høyde',
            value: _height,
            min: 140,
            max: 210,
            suffix: 'cm',
            onChanged: (v) => setState(() => _height = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ActivityLevel>(
            initialValue: _activity,
            decoration: const InputDecoration(labelText: 'Aktivitetsnivå'),
            items: [
              for (final level in ActivityLevel.values)
                DropdownMenuItem(value: level, child: Text(level.label)),
            ],
            onChanged: (v) => setState(() => _activity = v ?? _activity),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<WeightGoal>(
            initialValue: _goal,
            decoration: const InputDecoration(labelText: 'Mål'),
            items: [
              for (final goal in WeightGoal.values)
                DropdownMenuItem(value: goal, child: Text(goal.label)),
            ],
            onChanged: (v) => setState(() => _goal = v ?? _goal),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${formatKcal(_estimate)} kcal',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Et estimat basert på Mifflin-St Jeor-formelen. '
                    'Dette er ikke medisinsk rådgivning — juster tallet selv, '
                    'og snakk med lege eller ernæringsfysiolog hvis du er usikker.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_estimate),
            child: const Text('Bruk dette tallet'),
          ),
        ],
      ),
    );
  }
}

class _NumberSlider extends StatelessWidget {
  const _NumberSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('${value.round()} $suffix'),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

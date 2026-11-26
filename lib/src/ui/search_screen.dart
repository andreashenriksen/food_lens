import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/kassal_api.dart';
import '../models/product.dart';
import 'format.dart';
import 'settings_screen.dart';

/// Product search by name. Pops the chosen [Product] back to the caller.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  /// Guards against an earlier, slower response overwriting a later one.
  int _requestId = 0;

  List<Product> _results = const [];
  bool _loading = false;
  String? _error;
  bool _authError = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
        _searched = false;
      });
      return;
    }
    // Kassalapp's hobby tier allows 60 requests a minute; debouncing keeps a
    // fast typist from burning through that in a few seconds.
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String query) async {
    final api = context.read<KassalApi>();
    final requestId = ++_requestId;

    setState(() {
      _loading = true;
      _error = null;
      _authError = false;
    });

    try {
      final results = await api.searchProducts(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
        _searched = true;
      });
    } on KassalException catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = e.message;
        _authError = e.isAuthFailure;
        _loading = false;
        _searched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Søk etter produkt…',
            prefixIcon: Icon(Icons.search_rounded),
            isDense: true,
          ),
          onChanged: _onChanged,
          onSubmitted: (value) {
            _debounce?.cancel();
            if (value.trim().length >= 2) _search(value);
          },
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              if (_authError) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  child: const Text('Åpne innstillinger'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _searched
                ? 'Ingen treff. Prøv et annet søkeord, eller skann strekkoden.'
                : 'Skriv minst to bokstaver for å søke i norske dagligvarer.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final product = _results[i];
        return ListTile(
          leading: _Thumbnail(url: product.imageUrl),
          title: Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              if (product.subtitle.isNotEmpty) product.subtitle,
              if (!product.hasNutrition) 'Uten næringsinnhold',
            ].join(' · '),
          ),
          trailing: product.hasNutrition
              ? Text(
                  '${formatKcal(product.nutritionPer100.kcal)}\nkcal/100 ${product.basis.unitLabel}',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall,
                )
              : null,
          onTap: () => Navigator.of(context).pop(product),
        );
      },
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      Icons.shopping_basket_outlined,
      color: Theme.of(context).colorScheme.outline,
    );

    if (url == null) return SizedBox(width: 44, height: 44, child: placeholder);

    return SizedBox(
      width: 44,
      height: 44,
      child: Image.network(
        url!,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

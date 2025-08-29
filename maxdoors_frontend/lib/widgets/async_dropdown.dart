import 'package:flutter/material.dart';

class AsyncDropdown extends StatefulWidget {
  final String label;
  final Future<List<Map<String, String>>> Function() fetchOptions;
  final String? value;
  final void Function(String?) onChanged;
  final bool enabled;

  const AsyncDropdown({
    super.key,
    required this.label,
    required this.fetchOptions,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<AsyncDropdown> createState() => _AsyncDropdownState();
}

class _AsyncDropdownState extends State<AsyncDropdown> {
  bool _loading = false;
  String? _error;
  List<Map<String, String>> _options = [];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.fetchOptions();
      setState(() => _options = items);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AsyncDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fetchOptions != widget.fetchOptions) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return InputDecorator(
        decoration: InputDecoration(labelText: widget.label),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return InputDecorator(
        decoration: InputDecoration(labelText: widget.label),
        child: Row(
          children: [
            Expanded(
                child: Text('Xato: $_error',
                    style: const TextStyle(color: Colors.red))),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
      );
    }
    return DropdownButtonFormField<String>(
      value: widget.value,
      onChanged: widget.enabled ? widget.onChanged : null,
      items: _options
          .map((o) => DropdownMenuItem(
                value: o['id'],
                child: Text(o['label'] ?? o['id']!),
              ))
          .toList(),
      decoration: InputDecoration(labelText: widget.label),
    );
  }
}

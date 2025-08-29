import 'package:flutter/material.dart';

class Loading extends StatelessWidget {
  final String? text;
  const Loading({super.key, this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (text != null) ...[
            const SizedBox(height: 12),
            Text(text!, style: const TextStyle(fontSize: 14)),
          ],
        ],
      ),
    );
  }
}

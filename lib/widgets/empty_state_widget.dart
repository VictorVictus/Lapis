import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final String message;
  const EmptyStateWidget({super.key, this.message = "All caught up!\nTime to relax."});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.checkmark_seal_fill,
              size: 100,
              color: isDark ? Colors.white70 : Colors.white70,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.white30,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Relax, everything is under control.",
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white30 : Colors.white30,
            ),
          ),
        ],
      ),
    );
  }
}

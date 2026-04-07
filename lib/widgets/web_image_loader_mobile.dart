import 'package:flutter/material.dart';

class WebImageLoader extends StatelessWidget {
  final String url;
  final double size;
  final bool showShadow;

  const WebImageLoader({
    super.key,
    required this.url,
    required this.size,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: NetworkImage(url),
          fit: BoxFit.cover,
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.white.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }
}

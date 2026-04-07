import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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
    final String viewId = 'img-${url.hashCode}';
    
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) {
        final img = html.ImageElement()
          ..src = url
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..style.borderRadius = '50%';
        
        if (showShadow) {
          img.style.boxShadow = '0 0 8px 2px rgba(255, 255, 255, 0.4)';
        }
        return img;
      },
    );

    return SizedBox(
      width: size,
      height: size,
      child: HtmlElementView(viewType: viewId),
    );
  }
}

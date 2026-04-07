// Conditionally export the correct implementation of the WebImageLoader
// This prevents compilation errors on mobile (iOS/Android) where
// web-only libraries like dart:html are not available.

export 'web_image_loader_mobile.dart'
  if (dart.library.html) 'web_image_loader_web.dart'
  if (dart.library.js_util) 'web_image_loader_web.dart';

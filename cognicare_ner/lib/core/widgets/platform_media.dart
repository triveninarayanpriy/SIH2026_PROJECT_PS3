import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Web-safe media resolution shared by every screen that shows caregiver media.
///
/// Media sources arrive in four shapes:
///  - `http(s)://…`  — Firestore-synced clips/photos.
///  - `blob:…`       — what `image_picker`/`file_picker` return on **web** for a
///                     freshly picked file (a live object URL in the browser).
///  - `assets/…`     — bundled demo assets.
///  - a device path  — what the pickers return on **Android/desktop**.
///
/// The trap this file removes: `File(path)` from `dart:io` compiles on web but
/// throws at runtime. We only ever construct a `File` when NOT on web, and route
/// browser-loadable sources (`http`/`blob`) through the network path instead.

/// Returns an [ImageProvider] for [src], or `null` when it cannot be shown on
/// the current platform (callers should render a placeholder for `null`).
ImageProvider? mediaImageProvider(String? src) {
  if (src == null || src.trim().isEmpty) return null;
  if (src.startsWith('http') || src.startsWith('blob:') || src.startsWith('data:')) {
    return NetworkImage(src);
  }
  if (src.startsWith('assets/')) return AssetImage(src);
  // A bare filesystem path: readable on mobile/desktop, not on web.
  if (kIsWeb) return null;
  return FileImage(File(src));
}

/// A drop-in image widget that shows [src] and falls back to [placeholder]
/// (or a neutral box) whenever the source is missing or unloadable.
class MediaImage extends StatelessWidget {
  const MediaImage({
    super.key,
    required this.src,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
  });

  final String? src;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? provider = mediaImageProvider(src);
    final Widget fallback = placeholder ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFFE7ECF3),
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_rounded,
              color: Color(0xFF9AA6B2), size: 40),
        );
    if (provider == null) return fallback;
    return Image(
      image: provider,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

/// Builds a [VideoPlayerController] for the given media, or `null` when the
/// source cannot play on the current platform. Prefers [url] (http/blob) and
/// falls back to a local file path on mobile/desktop only.
VideoPlayerController? mediaVideoController({String? url, String? path}) {
  final String u = url ?? '';
  if (u.startsWith('http') || u.startsWith('blob:')) {
    return VideoPlayerController.networkUrl(Uri.parse(u));
  }
  final String p = path ?? '';
  if (p.isEmpty) return null;
  if (p.startsWith('http') || p.startsWith('blob:')) {
    return VideoPlayerController.networkUrl(Uri.parse(p));
  }
  if (kIsWeb) return null;
  return VideoPlayerController.file(File(p));
}

/// True when [path] points at a real device file we can read directly
/// (i.e. not a web build and not a network/blob URL). Handy for guarding
/// `just_audio`'s `setFilePath` vs `setUrl`.
bool isLocalFilePath(String? path) {
  if (path == null || path.isEmpty) return false;
  if (path.startsWith('http') || path.startsWith('blob:') || path.startsWith('data:')) {
    return false;
  }
  if (path.startsWith('assets/')) return false;
  return !kIsWeb;
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../translations.i18n.dart';

ImagesDatabase imagesDatabase = ImagesDatabase();

class ImagesDatabase {
  /*
  !!! Using the wrappers so i don't have to rewrite most of the code, because of migration to cached network image
  */
  Future<ImageProvider> _getProvider(String url) async {
    if (url.startsWith('http')) {
      try {
        final uri = Uri.parse(url);
        if (uri.host.contains('dzcdn.net') && uri.pathSegments.length > 3) {
          final imageHash = uri.pathSegments[3];
          final directory = await getExternalStorageDirectory();
          if (directory != null) {
            final offlinePath = p.join(directory.path, 'offline', 'images');
            final imageFile = File(p.join(offlinePath, '$imageHash.jpg'));
            if (await imageFile.exists()) {
              return FileImage(imageFile);
            }
          }
        }
      } catch (e) {/* ignore */}
      return CachedNetworkImageProvider(url);
    } else if (url.isNotEmpty) {
      return AssetImage(url);
    }
    // Fallback for empty url
    return AssetImage('assets/cover.jpg');
  }

  void saveImage(String url) {
    CachedNetworkImageProvider(url);
  }

  Future<ColorScheme> getPaletteGenerator(String url) async {
    final provider = await _getProvider(url);
    return ColorScheme.fromImageProvider(provider: provider);
  }

  Future<Color> getPrimaryColor(String url) async {
    ColorScheme paletteGenerator = await getPaletteGenerator(url);
    return paletteGenerator.primary;
  }

  Future<bool> isDark(String url) async {
    ColorScheme paletteGenerator = await getPaletteGenerator(url);
    return paletteGenerator.primary.computeLuminance() > 0.5 ? false : true;
  }
}

class CachedImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final bool circular;
  final bool fullThumb;
  final bool rounded;

  const CachedImage(
      {super.key,
      required this.url,
      this.height,
      this.width,
      this.circular = false,
      this.fullThumb = false,
      this.rounded = false});

  @override
  _CachedImageState createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  String? _localUrl;
  bool _checkedLocal = false;

  @override
  void initState() {
    super.initState();
    _checkLocal();
  }

  @override
  void didUpdateWidget(CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _localUrl = null;
      _checkedLocal = false;
      _checkLocal();
    }
  }

  Future<void> _checkLocal() async {
    if (widget.url.startsWith('http')) {
      try {
        final uri = Uri.parse(widget.url);
        if (uri.host.contains('dzcdn.net') && uri.pathSegments.length > 3) {
          final imageHash = uri.pathSegments[3];
          final directory = await getExternalStorageDirectory();
          if (directory != null) {
            final offlinePath = p.join(directory.path, 'offline', 'images');
            final imageFile = File(p.join(offlinePath, '$imageHash.jpg'));
            if (await imageFile.exists()) {
              if (mounted) {
                setState(() {
                  _localUrl = imageFile.path;
                });
              }
            }
          }
        }
      } catch (e) {
        // Not a valid URL, or some other parsing error. Ignore.
      }
    }
    if (mounted) {
      setState(() {
        _checkedLocal = true;
      });
    }
  }

  Widget _buildPlaceholder(BuildContext context, {bool isError = false}) {
    String assetPath;
    if (isError) {
      assetPath = 'assets/cover.jpg';
    } else {
      assetPath =
          widget.fullThumb ? 'assets/cover.jpg' : 'assets/cover_thumb.jpg';
    }
    return Image.asset(
      assetPath,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (!_checkedLocal) {
      imageWidget = _buildPlaceholder(context);
    } else if (_localUrl != null) {
      imageWidget = Image.file(
        File(_localUrl!),
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
      );
    } else if (!widget.url.startsWith('http')) {
      imageWidget = Image.asset(
        widget.url.isNotEmpty ? widget.url : 'assets/cover.jpg',
        width: widget.width,
        height: widget.height,
      );
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: widget.url,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(context),
        errorWidget: (context, url, error) =>
            _buildPlaceholder(context, isError: true),
      );
    }

    if (widget.rounded) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: imageWidget,
      );
    }

    if (widget.circular) {
      return ClipOval(child: imageWidget);
    }

    return imageWidget;
  }
}

class ZoomableImage extends StatefulWidget {
  final String url;
  final bool rounded;
  final double? width;

  const ZoomableImage(
      {super.key, required this.url, this.rounded = false, this.width});

  @override
  _ZoomableImageState createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage> {
  BuildContext? ctx;
  PhotoViewController? controller;
  ImageProvider? _imageProvider;
  bool photoViewOpened = false;

  @override
  void initState() {
    super.initState();
    controller = PhotoViewController()..outputStateStream.listen(listener);
    _resolveImageProvider();
  }

  @override
  void didUpdateWidget(ZoomableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resolveImageProvider();
    }
  }

  // Listener of PhotoView scale changes. Used for closing PhotoView by pinch-in
  void listener(PhotoViewControllerValue value) {
    if (value.scale! < 0.16 && photoViewOpened) {
      Navigator.pop(ctx!);
      photoViewOpened =
          false; // to avoid multiple pop() when picture are being scaled out too slowly
    }
  }

  Future<void> _resolveImageProvider() async {
    final provider = await imagesDatabase._getProvider(widget.url);
    if (mounted) {
      setState(() {
        _imageProvider = provider;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ctx = context;
    return TextButton(
        child: Semantics(
          label: 'Album art'.i18n,
          child: CachedImage(
            url: widget.url,
            rounded: widget.rounded,
            width: widget.width,
            fullThumb: true,
          ),
        ),
        onPressed: () {
          if (_imageProvider == null) return;
          Navigator.of(context).push(PageRouteBuilder(
              opaque: false, // transparent background
              pageBuilder: (context, a, b) {
                photoViewOpened = true;
                return PhotoView(
                    imageProvider: _imageProvider!,
                    maxScale: 8.0,
                    minScale: 0.2,
                    controller: controller,
                    backgroundDecoration: const BoxDecoration(
                        color: Color.fromARGB(0x90, 0, 0, 0)));
              }));
        });
  }
}

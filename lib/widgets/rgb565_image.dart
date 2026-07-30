import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class Rgb565Image extends StatefulWidget {
  const Rgb565Image({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<Rgb565Image> createState() => _Rgb565ImageState();
}

class _Rgb565ImageState extends State<Rgb565Image> {
  ui.Image? _image;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant Rgb565Image oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) _decode();
  }

  Future<void> _decode() async {
    final generation = ++_generation;
    final rgba = Uint8List(320 * 240 * 4);
    for (var pixel = 0; pixel < 320 * 240; pixel++) {
      final source = pixel * 2;
      final value = widget.bytes[source] | (widget.bytes[source + 1] << 8);
      final destination = pixel * 4;
      rgba[destination] = ((value >> 11) & 0x1f) * 255 ~/ 31;
      rgba[destination + 1] = ((value >> 5) & 0x3f) * 255 ~/ 63;
      rgba[destination + 2] = (value & 0x1f) * 255 ~/ 31;
      rgba[destination + 3] = 255;
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: 320,
      height: 240,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    buffer.dispose();
    descriptor.dispose();
    codec.dispose();
    if (!mounted || generation != _generation) {
      frame.image.dispose();
      return;
    }
    final previous = _image;
    setState(() => _image = frame.image);
    previous?.dispose();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const Center(child: CircularProgressIndicator());
    return RawImage(
      image: image,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.none,
    );
  }
}

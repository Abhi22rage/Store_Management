import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';

class ImageCropperDialog extends StatefulWidget {
  final XFile imageFile;

  const ImageCropperDialog({super.key, required this.imageFile});

  static Future<XFile?> cropImage(BuildContext context, XFile imageFile) async {
    return await Navigator.of(context).push<XFile>(
      MaterialPageRoute(
        builder: (context) => ImageCropperDialog(imageFile: imageFile),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<ImageCropperDialog> createState() => _ImageCropperDialogState();
}

class _ImageCropperDialogState extends State<ImageCropperDialog> {
  Uint8List? _imageBytes;
  ui.Image? _decodedImage;
  bool _isLoading = true;

  double _zoom = 1.0;
  int _rotationDegree = 0; // 0, 90, 180, 270

  // Aspect ratio presets (Freeform default)
  bool _isFreeform = true;
  double _aspectRatio = 1.0;

  // Interactive crop box coordinates (normalized 0.0 to 1.0)
  Rect _cropRect = const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8);

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _decodedImage = frame.image;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load image: $e')),
      );
    }
  }

  void _rotateLeft() {
    setState(() {
      _rotationDegree = (_rotationDegree - 90) % 360;
    });
  }

  void _rotateRight() {
    setState(() {
      _rotationDegree = (_rotationDegree + 90) % 360;
    });
  }

  void _reset() {
    setState(() {
      _zoom = 1.0;
      _rotationDegree = 0;
      _isFreeform = true;
      _aspectRatio = 1.0;
      _cropRect = const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8);
    });
  }

  Future<void> _saveCrop() async {
    if (_decodedImage == null || _imageBytes == null) return;

    setState(() => _isLoading = true);

    try {
      final croppedXFile = await _renderCroppedImage();
      if (!mounted) return;
      Navigator.of(context).pop(croppedXFile ?? widget.imageFile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving cropped image: $e')),
      );
    }
  }

  Future<XFile?> _renderCroppedImage() async {
    final img = _decodedImage!;
    final int imgWidth = img.width;
    final int imgHeight = img.height;

    // High quality target dimensions
    final double targetWidth = 800.0;
    final double targetHeight = _isFreeform
        ? (800.0 * (_cropRect.height / _cropRect.width))
        : (800.0 / _aspectRatio);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, targetWidth, targetHeight));

    // Fill white background
    canvas.drawRect(Rect.fromLTWH(0, 0, targetWidth, targetHeight), Paint()..color = Colors.white);

    // Compute exact pixel crop source rect from _cropRect (normalized 0.0..1.0)
    final double srcLeft = (_cropRect.left * imgWidth).clamp(0.0, imgWidth.toDouble());
    final double srcTop = (_cropRect.top * imgHeight).clamp(0.0, imgHeight.toDouble());
    final double srcWidth = (_cropRect.width * imgWidth).clamp(10.0, imgWidth.toDouble());
    final double srcHeight = (_cropRect.height * imgHeight).clamp(10.0, imgHeight.toDouble());

    final srcRect = Rect.fromLTWH(srcLeft, srcTop, srcWidth, srcHeight);
    final dstRect = Rect.fromLTWH(0, 0, targetWidth, targetHeight);

    canvas.save();
    if (_rotationDegree != 0) {
      canvas.translate(targetWidth / 2, targetHeight / 2);
      canvas.rotate((_rotationDegree * 3.1415926535) / 180);
      canvas.translate(-targetWidth / 2, -targetHeight / 2);
    }

    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(img, srcRect, dstRect, paint);
    canvas.restore();

    final picture = recorder.endRecording();
    final renderedImage = await picture.toImage(targetWidth.toInt(), targetHeight.round());
    final byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) return null;
    final croppedBytes = byteData.buffer.asUint8List();

    final name = 'cropped_${DateTime.now().millisecondsSinceEpoch}.png';
    return XFile.fromData(
      croppedBytes,
      name: name,
      mimeType: 'image/png',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Crop Product Image',
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_left_rounded, color: Colors.white),
            tooltip: 'Rotate Left',
            onPressed: _rotateLeft,
          ),
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
            tooltip: 'Rotate Right',
            onPressed: _rotateRight,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, color: Colors.white),
            tooltip: 'Reset',
            onPressed: _reset,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveCrop,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(
                'Save',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.secondary))
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final boxW = constraints.maxWidth;
                      final boxH = constraints.maxHeight;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Base Image Display
                          Transform.rotate(
                            angle: (_rotationDegree * 3.1415926535) / 180,
                            child: Transform.scale(
                              scale: _zoom,
                              child: _imageBytes != null
                                  ? Image.memory(
                                      _imageBytes!,
                                      width: boxW,
                                      height: boxH,
                                      fit: BoxFit.contain,
                                    )
                                  : const SizedBox(),
                            ),
                          ),

                          // Interactive Draggable Crop Overlay
                          _buildInteractiveCropOverlay(boxW, boxH),
                        ],
                      );
                    },
                  ),
                ),
                _buildControlPanel(),
              ],
            ),
    );
  }

  Widget _buildInteractiveCropOverlay(double containerW, double containerH) {
    final rectLeft = _cropRect.left * containerW;
    final rectTop = _cropRect.top * containerH;
    final rectW = _cropRect.width * containerW;
    final rectH = _cropRect.height * containerH;

    const handleSize = 24.0;

    return Stack(
      children: [
        // Dark overlay cut-out
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.6),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(color: Colors.black),
              Positioned(
                left: rectLeft,
                top: rectTop,
                width: rectW,
                height: rectH,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.red, // Cutout mask
                  ),
                ),
              ),
            ],
          ),
        ),

        // Crop Box Frame + Drag Center
        Positioned(
          left: rectLeft,
          top: rectTop,
          width: rectW,
          height: rectH,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final dx = details.delta.dx / containerW;
                final dy = details.delta.dy / containerH;

                double newLeft = (_cropRect.left + dx).clamp(0.0, 1.0 - _cropRect.width);
                double newTop = (_cropRect.top + dy).clamp(0.0, 1.0 - _cropRect.height);

                _cropRect = Rect.fromLTWH(newLeft, newTop, _cropRect.width, _cropRect.height);
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.secondary, width: 2.5),
              ),
              child: Stack(
                children: [
                  // Grid lines
                  Column(
                    children: [
                      const Expanded(child: SizedBox()),
                      Divider(color: Colors.white.withValues(alpha: 0.4), height: 1),
                      const Expanded(child: SizedBox()),
                      Divider(color: Colors.white.withValues(alpha: 0.4), height: 1),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                  Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      VerticalDivider(color: Colors.white.withValues(alpha: 0.4), width: 1),
                      const Expanded(child: SizedBox()),
                      VerticalDivider(color: Colors.white.withValues(alpha: 0.4), width: 1),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Corner Handle 1: Top-Left
        Positioned(
          left: rectLeft - handleSize / 2,
          top: rectTop - handleSize / 2,
          child: _buildCornerHandle(
            onDrag: (dx, dy) {
              setState(() {
                final ndx = dx / containerW;
                final ndy = dy / containerH;

                double newLeft = (_cropRect.left + ndx).clamp(0.0, _cropRect.right - 0.1);
                double newTop = (_cropRect.top + ndy).clamp(0.0, _cropRect.bottom - 0.1);
                double newW = _cropRect.right - newLeft;
                double newH = _cropRect.bottom - newTop;

                if (!_isFreeform) {
                  newH = newW / _aspectRatio;
                }

                _cropRect = Rect.fromLTWH(newLeft, newTop, newW, newH);
              });
            },
          ),
        ),

        // Corner Handle 2: Top-Right
        Positioned(
          left: rectLeft + rectW - handleSize / 2,
          top: rectTop - handleSize / 2,
          child: _buildCornerHandle(
            onDrag: (dx, dy) {
              setState(() {
                final ndx = dx / containerW;
                final ndy = dy / containerH;

                double newRight = (_cropRect.right + ndx).clamp(_cropRect.left + 0.1, 1.0);
                double newTop = (_cropRect.top + ndy).clamp(0.0, _cropRect.bottom - 0.1);
                double newW = newRight - _cropRect.left;
                double newH = _cropRect.bottom - newTop;

                if (!_isFreeform) {
                  newH = newW / _aspectRatio;
                }

                _cropRect = Rect.fromLTWH(_cropRect.left, newTop, newW, newH);
              });
            },
          ),
        ),

        // Corner Handle 3: Bottom-Left
        Positioned(
          left: rectLeft - handleSize / 2,
          top: rectTop + rectH - handleSize / 2,
          child: _buildCornerHandle(
            onDrag: (dx, dy) {
              setState(() {
                final ndx = dx / containerW;
                final ndy = dy / containerH;

                double newLeft = (_cropRect.left + ndx).clamp(0.0, _cropRect.right - 0.1);
                double newBottom = (_cropRect.bottom + ndy).clamp(_cropRect.top + 0.1, 1.0);
                double newW = _cropRect.right - newLeft;
                double newH = newBottom - _cropRect.top;

                if (!_isFreeform) {
                  newH = newW / _aspectRatio;
                }

                _cropRect = Rect.fromLTWH(newLeft, _cropRect.top, newW, newH);
              });
            },
          ),
        ),

        // Corner Handle 4: Bottom-Right
        Positioned(
          left: rectLeft + rectW - handleSize / 2,
          top: rectTop + rectH - handleSize / 2,
          child: _buildCornerHandle(
            onDrag: (dx, dy) {
              setState(() {
                final ndx = dx / containerW;
                final ndy = dy / containerH;

                double newRight = (_cropRect.right + ndx).clamp(_cropRect.left + 0.1, 1.0);
                double newBottom = (_cropRect.bottom + ndy).clamp(_cropRect.top + 0.1, 1.0);
                double newW = newRight - _cropRect.left;
                double newH = newBottom - _cropRect.top;

                if (!_isFreeform) {
                  newH = newW / _aspectRatio;
                }

                _cropRect = Rect.fromLTWH(_cropRect.left, _cropRect.top, newW, newH);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCornerHandle({required Function(double dx, double dy) onDrag}) {
    return GestureDetector(
      onPanUpdate: (details) => onDrag(details.delta.dx, details.delta.dy),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppTheme.secondary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      color: const Color(0xFF181818),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Colors.white, size: 24),
            tooltip: 'Zoom Out',
            onPressed: () {
              setState(() {
                _zoom = (_zoom - 0.2).clamp(1.0, 3.0);
              });
            },
          ),
          Expanded(
            child: Slider(
              value: _zoom,
              min: 1.0,
              max: 3.0,
              activeColor: AppTheme.secondary,
              inactiveColor: Colors.white24,
              onChanged: (val) => setState(() => _zoom = val),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Colors.white, size: 24),
            tooltip: 'Zoom In',
            onPressed: () {
              setState(() {
                _zoom = (_zoom + 0.2).clamp(1.0, 3.0);
              });
            },
          ),
        ],
      ),
    );
  }
}

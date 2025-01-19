import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_multi_select_items/flutter_multi_select_items.dart';
import 'dart:ui' as ui;

class ColorAdjustmentEditor extends StatefulWidget {
  final Uint8List image;

  const ColorAdjustmentEditor({super.key, required this.image});

  @override
  State<ColorAdjustmentEditor> createState() => _ColorAdjustmentEditorState();
}

class _ColorAdjustmentEditorState extends State<ColorAdjustmentEditor> {
  double _defaultValue = 1.0; // Initial saturation value (1.0 = no change)
  double _minValue = -100;
  double _maxValue = 100;

  // ColorAdjustFilter? _selectedFilter;
  List<ColorAdjustFilter> filters = [
    ColorAdjustFilter("Saturation", 1, 0, 2),
    ColorAdjustFilter("Hue", 0, -100, 100),
    ColorAdjustFilter("Brightness", 0, -1, 1),
    ColorAdjustFilter("Contrast", 0, -1, 1),
  ];
  int _selectedFilterIndex = 0;

  @override
  void initState() {
    var selected = filters[_selectedFilterIndex];
    _minValue = selected.minValue;
    _maxValue = selected.maxValue;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title:
            const Text('Color Adjust', style: TextStyle(color: Colors.white)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.arrow_back_ios_new_sharp,
                color: Colors.white)),
        actions: [
          IconButton(
              onPressed: () async {
                final updatedImage =
                    await _getModifiedImage(widget.image, filters);
                if (mounted) Navigator.pop(context, updatedImage);
              },
              icon: const Icon(
                Icons.check,
                color: Colors.white,
              ))
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(
                    _applyFilters(filters),
                  ),
                  child: Image.memory(widget.image)),
            ),
          ),
          SizedBox(
              height: 100,
              child: MultiSelectContainer(
                  singleSelectedItem: true,
                  showInListView: true,
                  itemsDecoration:
                      const MultiSelectDecorations(decoration: BoxDecoration()),
                  listViewSettings:
                      const ListViewSettings(scrollDirection: Axis.horizontal),
                  items: filters
                      .map((filter) => MultiSelectCard(
                          // highlightColor: Colors.red,
                          // splashColor: Colors.redAccent,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          margin: const EdgeInsets.symmetric(horizontal: 15),
                          textStyles: const MultiSelectItemTextStyles(
                              textStyle: TextStyle(color: Colors.white)),
                          decorations: MultiSelectItemDecorations(
                              selectedDecoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10))),
                          child: Text(filter.name),
                          value: filter))
                      .toList(),
                  onChange: (allSelectedItems, selectedItem) {
                    setState(() {
                      final selectedObjects = selectedItem as ColorAdjustFilter;
                      _defaultValue = selectedObjects.value;
                      _selectedFilterIndex = filters.indexOf(selectedObjects);
                      _minValue = selectedObjects.minValue;
                      _maxValue = selectedObjects.maxValue;
                    });
                  })),
          Slider(
            value: _defaultValue,
            min: _minValue,
            max: _maxValue,
            divisions: 20,
            activeColor: Colors.red,
            label: filters[_selectedFilterIndex].value.toStringAsFixed(2),
            onChanged: (value) {
              setState(() {
                _defaultValue = value;
                filters[_selectedFilterIndex].value = value;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '${filters[_selectedFilterIndex].name}: ${filters[_selectedFilterIndex].value.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Gets the modified image as Uint8List
  Future<Uint8List?> _getModifiedImage(
      Uint8List image, List<ColorAdjustFilter> filters) async {
    try {
      // Decode the image into a UI image
      ui.Image originalImage = await decodeImageFromList(image);

      // Create a PictureRecorder and Canvas to apply filters
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw the original image
      final paint = Paint()
        ..colorFilter = ColorFilter.matrix(_applyFilters(filters));
      final srcRect = Rect.fromLTWH(0, 0, originalImage.width.toDouble(),
          originalImage.height.toDouble());
      final dstRect = Rect.fromLTWH(0, 0, originalImage.width.toDouble(),
          originalImage.height.toDouble());
      canvas.drawImageRect(originalImage, srcRect, dstRect, paint);

      // End recording and convert to an image
      final picture = recorder.endRecording();
      final ui.Image filteredImage =
          await picture.toImage(originalImage.width, originalImage.height);

      // Encode the filtered image as PNG and return it as Uint8List
      final ByteData? byteData =
          await filteredImage.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error getting modified image: $e');
      return null;
    }
  }

  /// Combines all selected filter matrices into one
  List<double> _applyFilters(List<ColorAdjustFilter> filters) {
    List<double> combinedMatrix = List<double>.filled(20, 0);
    combinedMatrix[0] = 1; // Initialize as identity matrix
    combinedMatrix[6] = 1;
    combinedMatrix[12] = 1;
    combinedMatrix[18] = 1;

    for (var filter in filters) {
      List<double> filterMatrix;
      switch (filter.name) {
        case 'Saturation':
          filterMatrix = _createSaturationMatrix(filter.value);
          break;
        case 'Brightness':
          filterMatrix = _createBrightnessMatrix(filter.value);
          break;
        case 'Hue':
          filterMatrix = _createHueMatrix(filter.value);
          break;
        case 'Contrast':
          filterMatrix = _createContrastMatrix(filter.value);
          break;
        default:
          continue;
      }
      combinedMatrix = _matrixMultiplication(combinedMatrix, filterMatrix);
    }

    return combinedMatrix;
  }

  /// Creates a color matrix for adjusting saturation.
  List<double> _createSaturationMatrix(double saturation) {
    final double rWeight = 0.213;
    final double gWeight = 0.715;
    final double bWeight = 0.072;

    return [
      rWeight * (1 - saturation) + saturation,
      gWeight * (1 - saturation),
      bWeight * (1 - saturation),
      0,
      0,
      rWeight * (1 - saturation),
      gWeight * (1 - saturation) + saturation,
      bWeight * (1 - saturation),
      0,
      0,
      rWeight * (1 - saturation),
      gWeight * (1 - saturation),
      bWeight * (1 - saturation) + saturation,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _createBrightnessMatrix(double brightness) {
    // Brightness is expected to be in the range of -1.0 to 1.0
    return [
      1,
      0,
      0,
      0,
      brightness * 255,
      0,
      1,
      0,
      0,
      brightness * 255,
      0,
      0,
      1,
      0,
      brightness * 255,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _createHueMatrix(double hueDegrees) {
    final angle = hueDegrees * pi / 180; // Convert degrees to radians
    final cosVal = cos(angle);
    final sinVal = sin(angle);

    return [
      0.213 + cosVal * 0.787 - sinVal * 0.213,
      0.715 - cosVal * 0.715 - sinVal * 0.715,
      0.072 - cosVal * 0.072 + sinVal * 0.928,
      0,
      0,
      0.213 - cosVal * 0.213 + sinVal * 0.143,
      0.715 + cosVal * 0.285 + sinVal * 0.140,
      0.072 - cosVal * 0.072 - sinVal * 0.283,
      0,
      0,
      0.213 - cosVal * 0.213 - sinVal * 0.787,
      0.715 - cosVal * 0.715 + sinVal * 0.715,
      0.072 + cosVal * 0.928 + sinVal * 0.072,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _createContrastMatrix(double contrast) {
    // Ensure contrast is within a reasonable range
    contrast = contrast.clamp(-1.0, 1.0);
    double scale = 1.0 + contrast; // Scale factor for contrast
    double translate = (-0.5 * scale + 0.5) * 255.0;

    return [
      scale, 0, 0, 0, translate, // Red
      0, scale, 0, 0, translate, // Green
      0, 0, scale, 0, translate, // Blue
      0, 0, 0, 1, 0, // Alpha
    ];
  }

  /// Multiplies two 4x5 matrices.
  List<double> _matrixMultiplication(List<double> a, List<double> b) {
    final result = List<double>.filled(20, 0);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 5; col++) {
        result[row * 5 + col] = a[row * 5] * b[col] +
            a[row * 5 + 1] * b[col + 5] +
            a[row * 5 + 2] * b[col + 10] +
            a[row * 5 + 3] * b[col + 15] +
            (col == 4 ? a[row * 5 + 4] : 0);
      }
    }
    return result;
  }

  /// Creates a color matrix for combining saturation, brightness, and hue adjustments.
// List<double> _createColorMatrix(
//     double saturation, double brightness, double hue) {
//   // Brightness matrix
//   final List<double> brightnessMatrix = [
//     1,
//     0,
//     0,
//     0,
//     brightness * 255,
//     0,
//     1,
//     0,
//     0,
//     brightness * 255,
//     0,
//     0,
//     1,
//     0,
//     brightness * 255,
//     0,
//     0,
//     0,
//     1,
//     0,
//   ];
//
//   // Saturation matrix
//   final rWeight = 0.213;
//   final gWeight = 0.715;
//   final bWeight = 0.072;
//   final List<double> saturationMatrix = [
//     rWeight * (1 - saturation) + saturation,
//     gWeight * (1 - saturation),
//     bWeight * (1 - saturation),
//     0,
//     0,
//     rWeight * (1 - saturation),
//     gWeight * (1 - saturation) + saturation,
//     bWeight * (1 - saturation),
//     0,
//     0,
//     rWeight * (1 - saturation),
//     gWeight * (1 - saturation),
//     bWeight * (1 - saturation) + saturation,
//     0,
//     0,
//     0,
//     0,
//     0,
//     1,
//     0,
//   ];
//
//   // Hue matrix
//   final angle = hue * pi / 180; // Convert degrees to radians
//   final cosVal = cos(angle);
//   final sinVal = sin(angle);
//   final List<double> hueMatrix = [
//     0.213 + cosVal * 0.787 - sinVal * 0.213,
//     0.715 - cosVal * 0.715 - sinVal * 0.715,
//     0.072 - cosVal * 0.072 + sinVal * 0.928,
//     0,
//     0,
//     0.213 - cosVal * 0.213 + sinVal * 0.143,
//     0.715 + cosVal * 0.285 + sinVal * 0.140,
//     0.072 - cosVal * 0.072 - sinVal * 0.283,
//     0,
//     0,
//     0.213 - cosVal * 0.213 - sinVal * 0.787,
//     0.715 - cosVal * 0.715 + sinVal * 0.715,
//     0.072 + cosVal * 0.928 + sinVal * 0.072,
//     0,
//     0,
//     0,
//     0,
//     0,
//     1,
//     0,
//   ];
//
//   // Combine matrices (brightness * hue * saturation)
//   return _matrixMultiplication(
//     _matrixMultiplication(brightnessMatrix, hueMatrix),
//     saturationMatrix,
//   );
// }
}

class ColorAdjustFilter {
  String name;
  double value;
  double minValue;
  double maxValue;

  ColorAdjustFilter(this.name, this.value, this.minValue, this.maxValue);
}

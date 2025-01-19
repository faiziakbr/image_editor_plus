library image_editor_plus;

import 'dart:async';
import 'dart:math' as math;
import 'package:colorfilter_generator/colorfilter_generator.dart';
import 'package:colorfilter_generator/presets.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hand_signature/signature.dart';
import 'package:image/image.dart' as img;
import 'package:image_editor_plus/bottom_button.dart';
import 'package:image_editor_plus/data/image_item.dart';
import 'package:image_editor_plus/data/layer.dart';
import 'package:image_editor_plus/image_cropper.dart';
import 'package:image_editor_plus/image_editor_drawing.dart';
import 'package:image_editor_plus/image_filters.dart';
import 'package:image_editor_plus/layers_viewer.dart';
import 'package:image_editor_plus/loading_screen.dart';
import 'package:image_editor_plus/modules/all_emojies.dart';
import 'package:image_editor_plus/modules/layers_overlay.dart';
import 'package:image_editor_plus/modules/link.dart';
import 'package:image_editor_plus/modules/text.dart';
import 'package:image_editor_plus/multi_image_editor.dart';
import 'package:image_editor_plus/options.dart' as o;
import 'package:image_editor_plus/saturation_editor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';

import 'modules/colors_picker.dart';

late Size viewportSize;
double viewportRatio = 1;

List<Layer> layers = [], undoLayers = [], removedLayers = [];
Map<String, String> _translations = {};

String i18n(String sourceString) =>
    _translations[sourceString.toLowerCase()] ?? sourceString;

/// Single endpoint for MultiImageEditor & SingleImageEditor
class ImageEditor extends StatelessWidget {
  final dynamic image;
  final List? images;
  final String? savePath;
  final o.OutputFormat outputFormat;

  final o.ImagePickerOption imagePickerOption;
  final o.CropOption? cropOption;
  final o.BlurOption? blurOption;
  final o.BrushOption? brushOption;
  final o.EmojiOption? emojiOption;
  final o.FiltersOption? filtersOption;
  final o.FlipOption? flipOption;
  final o.RotateOption? rotateOption;
  final o.TextOption? textOption;

  const ImageEditor({
    super.key,
    this.image,
    this.images,
    this.savePath,
    this.imagePickerOption = const o.ImagePickerOption(),
    this.outputFormat = o.OutputFormat.jpeg,
    this.cropOption = const o.CropOption(),
    this.blurOption = const o.BlurOption(),
    this.brushOption = const o.BrushOption(),
    this.emojiOption = const o.EmojiOption(),
    this.filtersOption = const o.FiltersOption(),
    this.flipOption = const o.FlipOption(),
    this.rotateOption = const o.RotateOption(),
    this.textOption = const o.TextOption(),
  });

  @override
  Widget build(BuildContext context) {
    if (image == null &&
        images == null &&
        !imagePickerOption.captureFromCamera &&
        !imagePickerOption.pickFromGallery) {
      throw Exception(
          'No image to work with, provide an image or allow the image picker.');
    }

    if (image != null) {
      return SingleImageEditor(
        image: image,
        savePath: savePath,
        imagePickerOption: imagePickerOption,
        outputFormat: outputFormat,
        cropOption: cropOption,
        blurOption: blurOption,
        brushOption: brushOption,
        emojiOption: emojiOption,
        filtersOption: filtersOption,
        flipOption: flipOption,
        rotateOption: rotateOption,
        textOption: textOption,
      );
    } else {
      return MultiImageEditor(
        images: images ?? [],
        savePath: savePath,
        imagePickerOption: imagePickerOption,
        outputFormat: outputFormat,
        cropOption: cropOption,
        blurOption: blurOption,
        brushOption: brushOption,
        emojiOption: emojiOption,
        filtersOption: filtersOption,
        flipOption: flipOption,
        rotateOption: rotateOption,
        textOption: textOption,
      );
    }
  }

  static setI18n(Map<String, String> translations) {
    translations.forEach((key, value) {
      _translations[key.toLowerCase()] = value;
    });
  }

  /// Set custom theme properties default is dark theme with white text
  static ThemeData theme = ThemeData(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      surface: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black87,
      iconTheme: IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      toolbarTextStyle: TextStyle(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.black,
    ),
    iconTheme: const IconThemeData(
      color: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white),
    ),
  );
}

/// Image editor with all option available
class SingleImageEditor extends StatefulWidget {
  final dynamic image;
  final String? savePath;
  final o.OutputFormat outputFormat;

  final o.ImagePickerOption imagePickerOption;
  final o.CropOption? cropOption;
  final o.BlurOption? blurOption;
  final o.BrushOption? brushOption;
  final o.EmojiOption? emojiOption;
  final o.FiltersOption? filtersOption;
  final o.FlipOption? flipOption;
  final o.RotateOption? rotateOption;
  final o.TextOption? textOption;

  const SingleImageEditor({
    super.key,
    this.image,
    this.savePath,
    this.imagePickerOption = const o.ImagePickerOption(),
    this.outputFormat = o.OutputFormat.jpeg,
    this.cropOption = const o.CropOption(),
    this.blurOption = const o.BlurOption(),
    this.brushOption = const o.BrushOption(),
    this.emojiOption = const o.EmojiOption(),
    this.filtersOption = const o.FiltersOption(),
    this.flipOption = const o.FlipOption(),
    this.rotateOption = const o.RotateOption(),
    this.textOption = const o.TextOption(),
  });

  @override
  createState() => _SingleImageEditorState();
}

class _SingleImageEditorState extends State<SingleImageEditor> {
  ImageItem currentImage = ImageItem();

  ScreenshotController screenshotController = ScreenshotController();

  PermissionStatus galleryPermission = PermissionStatus.permanentlyDenied,
      cameraPermission = PermissionStatus.permanentlyDenied;

  @override
  void initState() {
    if (widget.image != null) {
      loadImage(widget.image!);
    }

    checkPermissions();

    super.initState();
  }

  checkPermissions() async {
    if (widget.imagePickerOption.pickFromGallery) {
      galleryPermission = await Permission.photos.status;
    }

    if (widget.imagePickerOption.captureFromCamera) {
      cameraPermission = await Permission.camera.status;
    }

    if (widget.imagePickerOption.pickFromGallery ||
        widget.imagePickerOption.captureFromCamera) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    layers.clear();
    super.dispose();
  }

  List<Widget> get filterActions {
    return [
      const BackButton(),
      SizedBox(
        width: MediaQuery.of(context).size.width - 48,
        child: SingleChildScrollView(
          reverse: true,
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: Icon(Icons.undo,
                  color: layers.length > 1 || removedLayers.isNotEmpty
                      ? Colors.white
                      : Colors.grey),
              onPressed: () {
                if (removedLayers.isNotEmpty) {
                  layers.add(removedLayers.removeLast());
                  setState(() {});
                  return;
                }

                if (layers.length <= 1) return; // do not remove image layer

                undoLayers.add(layers.removeLast());

                setState(() {});
              },
            ),
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: Icon(Icons.redo,
                  color: undoLayers.isNotEmpty ? Colors.white : Colors.grey),
              onPressed: () {
                if (undoLayers.isEmpty) return;

                layers.add(undoLayers.removeLast());

                setState(() {});
              },
            ),
            if (widget.imagePickerOption.pickFromGallery)
              Opacity(
                opacity: galleryPermission.isPermanentlyDenied ? 0.5 : 1,
                child: IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  icon: const Icon(Icons.photo),
                  onPressed: () async {
                    if (await Permission.photos.isPermanentlyDenied) {
                      openAppSettings();
                    }

                    var image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );

                    if (image == null) return;

                    // loadImage(image);

                    var imageItem = ImageItem(image);
                    await imageItem.loader.future;

                    layers.add(ImageLayerData(image: imageItem));
                    setState(() {});
                  },
                ),
              ),
            if (widget.imagePickerOption.captureFromCamera)
              Opacity(
                opacity: cameraPermission.isPermanentlyDenied ? 0.5 : 1,
                child: IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () async {
                    if (await Permission.camera.isPermanentlyDenied) {
                      openAppSettings();
                    }

                    var image = await picker.pickImage(
                      source: ImageSource.camera,
                    );

                    if (image == null) return;

                    // loadImage(image);

                    var imageItem = ImageItem(image);
                    await imageItem.loader.future;

                    layers.add(ImageLayerData(image: imageItem));
                    setState(() {});
                  },
                ),
              ),
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: const Icon(Icons.check),
              onPressed: () async {
                resetTransformation();
                setState(() {});

                var loadingScreen = showLoadingScreen(context);

                if (widget.outputFormat == o.OutputFormat.json) {
                  var json = layers.map((e) => e.toJson()).toList();

                  // if ((widget.outputFormat & 0xFE) > 0) {
                  //   var editedImageBytes =
                  //       await getMergedImage(widget.outputFormat & 0xFE);

                  //   json.insert(0, {
                  //     'type': 'MergedLayer',
                  //     'image': editedImageBytes,
                  //   });
                  // }

                  loadingScreen.hide();

                  if (mounted) Navigator.pop(context, json);
                } else {
                  var editedImageBytes =
                      await getMergedImage(widget.outputFormat);

                  loadingScreen.hide();

                  if (mounted) Navigator.pop(context, editedImageBytes);
                }
              },
            ),
          ]),
        ),
      ),
    ];
  }

  double flipValue = 0;
  int rotateValue = 0;

  double x = 0;
  double y = 0;
  double z = 0;

  double lastScaleFactor = 1, scaleFactor = 1;
  double widthRatio = 1, heightRatio = 1, pixelRatio = 1;

  resetTransformation() {
    scaleFactor = 1;
    x = 0;
    y = 0;
    setState(() {});
  }

  /// obtain image Uint8List by merging layers
  Future<Uint8List?> getMergedImage([
    o.OutputFormat format = o.OutputFormat.png,
  ]) async {
    Uint8List? image;

    if (flipValue != 0 || rotateValue != 0 || layers.length > 1) {
      image = await screenshotController.capture(pixelRatio: pixelRatio);
    } else if (layers.length == 1) {
      if (layers.first is BackgroundLayerData) {
        image = (layers.first as BackgroundLayerData).image.bytes;
      } else if (layers.first is ImageLayerData) {
        image = (layers.first as ImageLayerData).image.bytes;
      }
    }

    // conversion for non-png
    if (image != null && format == o.OutputFormat.jpeg) {
      var decodedImage = img.decodeImage(image);

      if (decodedImage == null) {
        throw Exception('Unable to decode image for conversion.');
      }

      return img.encodeJpg(decodedImage);
    }

    return image;
  }

  @override
  Widget build(BuildContext context) {
    viewportSize = MediaQuery.of(context).size;
    pixelRatio = MediaQuery.of(context).devicePixelRatio;

    // widthRatio = currentImage.width / viewportSize.width;
    // heightRatio = currentImage.height / viewportSize.height;
    // pixelRatio = math.max(heightRatio, widthRatio);

    return Theme(
      data: ImageEditor.theme,
      child: Scaffold(
        body: Stack(children: [
          GestureDetector(
            onScaleUpdate: (details) {
              // print(details);

              // move
              if (details.pointerCount == 1) {
                // print(details.focalPointDelta);
                x += details.focalPointDelta.dx;
                y += details.focalPointDelta.dy;
                setState(() {});
              }

              // scale
              if (details.pointerCount == 2) {
                // print([details.horizontalScale, details.verticalScale]);
                if (details.horizontalScale != 1) {
                  scaleFactor = lastScaleFactor *
                      math.min(details.horizontalScale, details.verticalScale);
                  setState(() {});
                }
              }
            },
            onScaleEnd: (details) {
              lastScaleFactor = scaleFactor;
            },
            child: Center(
              child: SizedBox(
                height: currentImage.height / pixelRatio,
                width: currentImage.width / pixelRatio,
                child: Screenshot(
                  controller: screenshotController,
                  child: RotatedBox(
                    quarterTurns: rotateValue,
                    child: Transform(
                      transform: Matrix4(
                        1,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                        x,
                        y,
                        0,
                        1 / scaleFactor,
                      )..rotateY(flipValue),
                      alignment: FractionalOffset.center,
                      child: LayersViewer(
                        layers: layers,
                        onUpdate: () {
                          setState(() {});
                        },
                        editable: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
              ),
              child: SafeArea(
                child: Row(
                  children: filterActions,
                ),
              ),
            ),
          ),
          if (layers.length > 1)
            Positioned(
              bottom: 64,
              left: 0,
              child: SafeArea(
                child: Container(
                  height: 48,
                  width: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(100),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(19),
                      bottomRight: Radius.circular(19),
                    ),
                  ),
                  child: IconButton(
                    iconSize: 20,
                    padding: const EdgeInsets.all(0),
                    onPressed: () {
                      showModalBottomSheet(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(10),
                            topLeft: Radius.circular(10),
                          ),
                        ),
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => SafeArea(
                          child: ManageLayersOverlay(
                            layers: layers,
                            onUpdate: () => setState(() {}),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.layers),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 64,
            right: 0,
            child: SafeArea(
              child: Container(
                height: 48,
                width: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(100),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(19),
                    bottomLeft: Radius.circular(19),
                  ),
                ),
                child: IconButton(
                  iconSize: 20,
                  padding: const EdgeInsets.all(0),
                  onPressed: () {
                    resetTransformation();
                  },
                  icon: Icon(
                    scaleFactor > 1 ? Icons.zoom_in_map : Icons.zoom_out_map,
                  ),
                ),
              ),
            ),
          ),
        ]),
        bottomNavigationBar: Container(
          // color: Colors.black45,
          alignment: Alignment.bottomCenter,
          height: 86 + MediaQuery.of(context).padding.bottom,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.black87,
            shape: BoxShape.rectangle,
            //   boxShadow: [
            //     BoxShadow(blurRadius: 1),
            //   ],
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  BottomButton(
                    icon: Icons.water_drop,
                    text: i18n("Adjust"),
                    onTap: () async {
                      resetTransformation();
                      var loadingScreen = showLoadingScreen(context);
                      var mergedImage = await getMergedImage();
                      loadingScreen.hide();

                      if (!mounted) return;
                      Uint8List? adjustedColor = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ColorAdjustmentEditor(
                            image: mergedImage!,
                          ),
                        ),
                      );

                      if (adjustedColor == null) return;

                      flipValue = 0;
                      rotateValue = 0;

                      await currentImage.load(adjustedColor);
                      setState(() {});
                    },
                  ),
                  if (widget.cropOption != null)
                    BottomButton(
                      icon: Icons.crop,
                      text: i18n('Crop'),
                      onTap: () async {
                        resetTransformation();
                        var loadingScreen = showLoadingScreen(context);
                        var mergedImage = await getMergedImage();
                        loadingScreen.hide();

                        if (!mounted) return;

                        Uint8List? croppedImage = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImageCropper(
                              image: mergedImage!,
                              reversible: widget.cropOption!.reversible,
                              availableRatios: widget.cropOption!.ratios,
                            ),
                          ),
                        );

                        if (croppedImage == null) return;

                        flipValue = 0;
                        rotateValue = 0;

                        await currentImage.load(croppedImage);
                        setState(() {});
                      },
                    ),
                  if (widget.brushOption != null)
                    BottomButton(
                      icon: Icons.edit,
                      text: i18n('Brush'),
                      onTap: () async {
                        if (widget.brushOption!.translatable) {
                          var drawing = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageEditorDrawing(
                                image: currentImage,
                                options: widget.brushOption!,
                              ),
                            ),
                          );

                          if (drawing != null) {
                            undoLayers.clear();
                            removedLayers.clear();

                            layers.add(
                              ImageLayerData(
                                image: ImageItem(drawing),
                                offset: Offset(
                                  -currentImage.width / 4,
                                  -currentImage.height / 4,
                                ),
                              ),
                            );

                            setState(() {});
                          }
                        } else {
                          resetTransformation();
                          var loadingScreen = showLoadingScreen(context);
                          var mergedImage = await getMergedImage();
                          loadingScreen.hide();

                          if (!mounted) return;

                          var drawing = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageEditorDrawing(
                                image: ImageItem(mergedImage!),
                                options: widget.brushOption!,
                              ),
                            ),
                          );

                          if (drawing != null) {
                            currentImage.load(drawing);

                            setState(() {});
                          }
                        }
                      },
                    ),
                  if (widget.textOption != null)
                    BottomButton(
                      icon: Icons.text_fields,
                      text: i18n('Text'),
                      onTap: () async {
                        TextLayerData? layer = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TextEditorImage(),
                          ),
                        );

                        if (layer == null) return;

                        undoLayers.clear();
                        removedLayers.clear();

                        layers.add(layer);

                        setState(() {});
                      },
                    ),
                  if (widget.textOption != null)
                    BottomButton(
                      icon: Icons.link,
                      text: i18n('Link'),
                      onTap: () async {
                        LinkLayerData? layer = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LinkEditorImage(),
                          ),
                        );

                        if (layer == null) return;

                        undoLayers.clear();
                        removedLayers.clear();

                        layers.add(layer);

                        setState(() {});
                      },
                    ),
                  if (widget.flipOption != null)
                    BottomButton(
                      icon: Icons.flip,
                      text: i18n('Flip'),
                      onTap: () {
                        setState(() {
                          flipValue = flipValue == 0 ? math.pi : 0;
                        });
                      },
                    ),
                  if (widget.rotateOption != null)
                    BottomButton(
                      icon: Icons.rotate_left,
                      text: i18n('Rotate left'),
                      onTap: () {
                        var t = currentImage.width;
                        currentImage.width = currentImage.height;
                        currentImage.height = t;

                        rotateValue--;
                        setState(() {});
                      },
                    ),
                  if (widget.rotateOption != null)
                    BottomButton(
                      icon: Icons.rotate_right,
                      text: i18n('Rotate right'),
                      onTap: () {
                        var t = currentImage.width;
                        currentImage.width = currentImage.height;
                        currentImage.height = t;

                        rotateValue++;
                        setState(() {});
                      },
                    ),
                  if (widget.blurOption != null)
                    BottomButton(
                      icon: Icons.blur_on,
                      text: i18n('Blur'),
                      onTap: () {
                        var blurLayer = BackgroundBlurLayerData(
                          color: Colors.transparent,
                          radius: 0.0,
                          opacity: 0.0,
                        );

                        undoLayers.clear();
                        removedLayers.clear();
                        layers.add(blurLayer);
                        setState(() {});

                        showModalBottomSheet(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                topRight: Radius.circular(10),
                                topLeft: Radius.circular(10)),
                          ),
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) {
                            return StatefulBuilder(
                              builder: (context, setS) {
                                return SingleChildScrollView(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.only(
                                          topRight: Radius.circular(10),
                                          topLeft: Radius.circular(10)),
                                    ),
                                    padding: const EdgeInsets.all(20),
                                    height: 400,
                                    child: Column(
                                      children: [
                                        Center(
                                            child: Text(
                                          i18n('Slider Filter Color')
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white),
                                        )),
                                        const SizedBox(height: 20.0),
                                        Text(
                                          i18n('Slider Color'),
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(children: [
                                          Expanded(
                                            child: BarColorPicker(
                                              width: 300,
                                              thumbColor: Colors.white,
                                              cornerRadius: 10,
                                              pickMode: PickMode.color,
                                              colorListener: (int value) {
                                                setS(() {
                                                  setState(() {
                                                    blurLayer.color =
                                                        Color(value);
                                                  });
                                                });
                                              },
                                            ),
                                          ),
                                          TextButton(
                                            child: Text(
                                              i18n('Reset'),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                setS(() {
                                                  blurLayer.color =
                                                      Colors.transparent;
                                                });
                                              });
                                            },
                                          )
                                        ]),
                                        const SizedBox(height: 5.0),
                                        Text(
                                          i18n('Blur Radius'),
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        const SizedBox(height: 10.0),
                                        Row(children: [
                                          Expanded(
                                            child: Slider(
                                              activeColor: Colors.white,
                                              inactiveColor: Colors.grey,
                                              value: blurLayer.radius,
                                              min: 0.0,
                                              max: 10.0,
                                              onChanged: (v) {
                                                setS(() {
                                                  setState(() {
                                                    blurLayer.radius = v;
                                                  });
                                                });
                                              },
                                            ),
                                          ),
                                          TextButton(
                                            child: Text(
                                              i18n('Reset'),
                                            ),
                                            onPressed: () {
                                              setS(() {
                                                setState(() {
                                                  blurLayer.color =
                                                      Colors.white;
                                                });
                                              });
                                            },
                                          )
                                        ]),
                                        const SizedBox(height: 5.0),
                                        Text(
                                          i18n('Color Opacity'),
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        const SizedBox(height: 10.0),
                                        Row(children: [
                                          Expanded(
                                            child: Slider(
                                              activeColor: Colors.white,
                                              inactiveColor: Colors.grey,
                                              value: blurLayer.opacity,
                                              min: 0.00,
                                              max: 1.0,
                                              onChanged: (v) {
                                                setS(() {
                                                  setState(() {
                                                    blurLayer.opacity = v;
                                                  });
                                                });
                                              },
                                            ),
                                          ),
                                          TextButton(
                                            child: Text(
                                              i18n('Reset'),
                                            ),
                                            onPressed: () {
                                              setS(() {
                                                setState(() {
                                                  blurLayer.opacity = 0.0;
                                                });
                                              });
                                            },
                                          )
                                        ]),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  // BottomButton(
                  //   icon: FontAwesomeIcons.eraser,
                  //   text: 'Eraser',
                  //   onTap: () {
                  //     _controller.clear();
                  //     layers.removeWhere((layer) => layer['type'] == 'drawing');
                  //     setState(() {});
                  //   },
                  // ),
                  if (widget.filtersOption != null)
                    BottomButton(
                      icon: Icons.color_lens,
                      text: i18n('Filter'),
                      onTap: () async {
                        resetTransformation();

                        /// Use case: if you don't want to stack your filter, use
                        /// this logic. Along with code on line 888 and
                        /// remove line 889
                        // for (int i = 1; i < layers.length; i++) {
                        //   if (layers[i] is BackgroundLayerData) {
                        //     layers.removeAt(i);
                        //     break;
                        //   }
                        // }

                        var loadingScreen = showLoadingScreen(context);
                        var mergedImage = await getMergedImage();
                        loadingScreen.hide();

                        if (!mounted) return;

                        Uint8List? filterAppliedImage = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImageFilters(
                              image: mergedImage!,
                              options: widget.filtersOption,
                            ),
                          ),
                        );

                        if (filterAppliedImage == null) return;

                        removedLayers.clear();
                        undoLayers.clear();

                        var layer = BackgroundLayerData(
                          image: ImageItem(filterAppliedImage),
                        );

                        /// Use case, if you don't want your filter to effect your
                        /// other elements such as emoji and text. Use insert
                        /// instead of add like in line 888
                        //layers.insert(1, layer);
                        layers.add(layer);

                        await layer.image.loader.future;

                        setState(() {});
                      },
                    ),
                  if (widget.emojiOption != null)
                    BottomButton(
                      icon: FontAwesomeIcons.faceSmile,
                      text: i18n('Emoji'),
                      onTap: () async {
                        EmojiLayerData? layer = await showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.black,
                          builder: (BuildContext context) {
                            return const Emojies();
                          },
                        );

                        if (layer == null) return;

                        undoLayers.clear();
                        removedLayers.clear();
                        layers.add(layer);

                        setState(() {});
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  final picker = ImagePicker();

  Future<void> loadImage(dynamic imageFile) async {
    await currentImage.load(imageFile);

    layers.clear();

    layers.add(BackgroundLayerData(
      image: currentImage,
    ));

    setState(() {});
  }

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
}
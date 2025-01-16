import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_editor_plus/data/image_item.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:image_editor_plus/image_filters.dart';
import 'package:image_editor_plus/options.dart' as o;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
/// Show multiple image carousel to edit multple images at one and allow more images to be added
class MultiImageEditor extends StatefulWidget {
  final List images;
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

  const MultiImageEditor({
    super.key,
    this.images = const [],
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
  createState() => _MultiImageEditorState();
}

class _MultiImageEditorState extends State<MultiImageEditor> {
  List<ImageItem> images = [];
  PermissionStatus galleryPermission = PermissionStatus.permanentlyDenied,
      cameraPermission = PermissionStatus.permanentlyDenied;

  checkPermissions() async {
    if (widget.imagePickerOption.pickFromGallery) {
      galleryPermission = await Permission.photos.status;
    }

    if (widget.imagePickerOption.captureFromCamera) {
      cameraPermission = await Permission.camera.status;
    }

    setState(() {});
  }

  @override
  void initState() {
    images = widget.images.map((e) => ImageItem(e)).toList();
    checkPermissions();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    viewportSize = MediaQuery.of(context).size;

    return Theme(
      data: ImageEditor.theme,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            const BackButton(),
            const Spacer(),
            if (images.length < widget.imagePickerOption.maxLength &&
                widget.imagePickerOption.pickFromGallery)
              Opacity(
                opacity: galleryPermission.isPermanentlyDenied ? 0.5 : 1,
                child: IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  icon: const Icon(Icons.photo),
                  onPressed: () async {
                    if (await Permission.photos.isPermanentlyDenied) {
                      openAppSettings();
                    }

                    var selected = await imagePicker.pickMultiImage(
                      requestFullMetadata: false,
                    );

                    images.addAll(selected.map((e) => ImageItem(e)).toList());
                    setState(() {});
                  },
                ),
              ),
            if (images.length < widget.imagePickerOption.maxLength &&
                widget.imagePickerOption.captureFromCamera)
              Opacity(
                opacity: cameraPermission.isPermanentlyDenied ? 0.5 : 1,
                child: IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () async {
                    if (await Permission.camera.isPermanentlyDenied) {
                      openAppSettings();
                    }

                    var selected = await imagePicker.pickImage(
                      source: ImageSource.camera,
                    );

                    if (selected == null) return;

                    images.add(ImageItem(selected));
                    setState(() {});
                  },
                ),
              ),
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: const Icon(Icons.check),
              onPressed: () async {
                Navigator.pop(context, images);
              },
            ),
          ],
        ),
        body: Column(
          children: [
            SizedBox(
              height: 332,
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const SizedBox(width: 32),
                    for (var image in images)
                      Stack(children: [
                        GestureDetector(
                          onTap: () async {
                            var img = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SingleImageEditor(
                                  image: image,
                                  outputFormat: o.OutputFormat.jpeg,
                                ),
                              ),
                            );

                            // print(img);

                            if (img != null) {
                              image.load(img);
                              setState(() {});
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(
                                top: 32, right: 32, bottom: 32),
                            width: 200,
                            height: 300,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              border:
                              Border.all(color: Colors.white.withAlpha(80)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.memory(
                                image.bytes,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 36,
                          right: 36,
                          child: Container(
                            height: 32,
                            width: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(60),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: IconButton(
                              iconSize: 20,
                              padding: const EdgeInsets.all(0),
                              onPressed: () {
                                // print('removing');
                                images.remove(image);
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear_outlined),
                            ),
                          ),
                        ),
                        if (widget.filtersOption != null)
                          Positioned(
                            bottom: 32,
                            left: 0,
                            child: Container(
                              height: 38,
                              width: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(100),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(19),
                                ),
                              ),
                              child: IconButton(
                                iconSize: 20,
                                padding: const EdgeInsets.all(0),
                                onPressed: () async {
                                  Uint8List? editedImage = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ImageFilters(
                                        image: image.bytes,
                                        options: widget.filtersOption,
                                      ),
                                    ),
                                  );

                                  if (editedImage != null) {
                                    image.load(editedImage);
                                  }

                                  setState(() {});
                                },
                                icon: const Icon(Icons.photo_filter_sharp),
                              ),
                            ),
                          ),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final imagePicker = ImagePicker();
}
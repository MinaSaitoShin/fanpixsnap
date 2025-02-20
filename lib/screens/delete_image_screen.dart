import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';

class DeleteImageScreen extends StatefulWidget {
  // 削除対象のフォルダ名
  final String folderName;

  const DeleteImageScreen({Key? key, required this.folderName}) : super(key: key);

  @override
  _DeleteImageScreenState createState() => _DeleteImageScreenState();
}

class _DeleteImageScreenState extends State<DeleteImageScreen> {
  List<File> images = [];
  Set<File> selectedImages = {}; // 選択した画像

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  // ストレージ権限確認（API29以降）
  Future<bool> requestManageExternalStoragePermission() async {
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }
    PermissionStatus status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  // ストレージ権限確認（API29未満）
  Future<bool> requestStoragePermission() async {
    // ストレージアクセス権限の状態を確認
    PermissionStatus status = await Permission.storage.status;

    if (status.isGranted) {
      return true;
    }
    PermissionStatus newStatus = await Permission.storage.request();
    return newStatus.isGranted;
  }

  // SDKバージョンを取得する関数
  Future<int> _getSdkVersion() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final int version = androidInfo.version.sdkInt;;
    return version;
  }

  // **画像を取得**
  Future<void> _loadImages() async {
    List<File> imageList = await getLocalImages(widget.folderName);
    for (var image in imageList) {
      print("取得した画像: ${image.path} (存在: ${image.existsSync()})");
    }
    setState(() {
      images = imageList;
    });
  }

  Future<List<File>> getLocalImages(String folderName) async {
    Directory directory;
    List<File> images;

    if (Platform.isIOS) {
      // **iOS のローカルストレージ**
      Directory appDocDir = await getApplicationDocumentsDirectory();
      directory = Directory('${appDocDir.path}/$folderName');
      // jpgファイルのみ取得し、最新順にソート
      images = directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith(".jpg"))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    } else if (Platform.isAndroid) {
      // **Android のローカルストレージ**
      directory = Directory('/storage/emulated/0/Pictures/$folderName');
      images = directory
          .listSync()
          .whereType<File>()
          .where((file) =>
      file.path.endsWith(".jpg") &&
          !file.path.contains("/.trashed-")) // **ゴミ箱フォルダを無視**
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    } else {
      throw UnsupportedError("このプラットフォームはサポートされていません");
    }

    if (!directory.existsSync()) {
      return [];
    }

    return images;
  }


  Future<void> deleteImage(File image) async {
    try {
      print("削除開始: ${image.path}");

      if (Platform.isIOS) {
        List<AssetEntity> mediaList = await PhotoManager.getAssetListPaged(
          type: RequestType.image,
          page: 0,
          pageCount: 200,
        );

        AssetEntity? targetAsset;
        for (var asset in mediaList) {
          File? file = await asset.file;
          if (file != null && file.path == image.path) {
            targetAsset = asset;
            break;
          }
        }

        if (targetAsset != null) {
          List<String> deletedIds = await PhotoManager.editor.deleteWithIds([targetAsset.id]);
          if (deletedIds.isNotEmpty) {
            print("PhotoManager で削除成功 (iOS): ${image.path}");
          } else {
            print("PhotoManager で削除失敗 (iOS): ${image.path}");
          }
        } else {
          print("画像が `PhotoManager` に見つかりませんでした: ${image.path}");
        }
      }

      if (await image.exists()) {
        await image.delete();
        print("ローカルファイル削除成功: ${image.path}");
      }

      if (Platform.isAndroid) {
        try {
          const platform = MethodChannel('com.example.fan_pix_snap/media_store');
          await platform.invokeMethod('scanFile', {'path': image.path});
          print("MediaStore 更新成功: ${image.path}");
        } catch (e) {
          print("MediaStore 更新エラー: $e");
        }
      }
    } catch (e) {
      print("削除時のエラー: $e");
    }
  }

  // **画像を削除**
  Future<void> _deleteSelectedImages() async {
    if (Platform.isAndroid) {
      if (Platform.isAndroid && (await _getSdkVersion()) >= 29) {
        // Android 10 (API 29) 以上の場合は管理権限を確認
        bool hasPermission = await requestManageExternalStoragePermission();
        if (!hasPermission) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("ストレージの管理権限が必要です")),
          );
          return;
        }
      } else {
        // API 28以下では通常のストレージ権限を確認
        bool hasPermission = await requestStoragePermission();
        if (!hasPermission) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("ストレージアクセス権限が必要です")),
          );
          return;
        }
      }
    }

    for (var image in selectedImages) {
      if (await image.exists()) {
        if (Platform.isAndroid) {
          await deleteImage(image);
        } else {
          try {
            await image.delete();
            print("削除成功: ${image.path}");
          } catch (e) {
            print("削除失敗: ${image.path}, エラー: $e");
          }
        }
      } else {
        print("削除対象のファイルが存在しません: ${image.path}");
      }
    }

    setState(() {
      selectedImages.clear();
    });
    await _loadImages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('画像を削除'),
        actions: [
          if (selectedImages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: _deleteSelectedImages,
            ),
        ],
      ),
      body: images.isEmpty
          ? Center(child: Text('削除できる画像がありません'))
          : GridView.builder(
              padding: EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 画像を3列で表示
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final image = images[index];
                final isSelected = selectedImages.contains(image);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selectedImages.remove(image);
                      } else {
                        selectedImages.add(image);
                      }
                    });
                  },
                  child: Stack(
                    children: [
                      Image.file(image, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                      if (isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(Icons.check_circle, color: Colors.redAccent, size: 24),
                        ),
                    ],
                  ),
                );
              },
          ),
    );
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:photo_manager/photo_manager.dart';
import 'local_qr_code_screen.dart';
import 'storage_qr_code_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../services/app_state.dart';
// import '../services/firebase_service.dart';
 import '../services/supabase_service.dart';
import '../services/local_server_page.dart';
import '../services/local_client_page.dart';
import '../services/local_server_manager.dart';

// カメラ画面を管理するウィジェット
class CameraScreenState extends ChangeNotifier {
  // ログを保持するリスト
  final List<String> _logs = [];

  // ログリストを取得するゲッター
  List<String> get logs => _logs;

  // ログを追加するメソッド
  void addLog(String message) {
    final logMessage = "[${DateTime.now()}] $message";
    _logs.add(logMessage);
  }
}

class CameraScreen extends StatefulWidget {

  @override
  _CameraClassState createState() => _CameraClassState();
}

class _CameraClassState extends State<CameraScreen> with WidgetsBindingObserver {
  // 画像を保持するためのFile型変数 初期値はnull
  File? _image;

  // ロード状態
  bool _isLoading = false;

  // カメラアクセス権の付与有無 初期値はfalse
  bool _permissionsGranted = false;

  // ストレージアクセス権の付与有無 初期値はfalse
  bool _storagePermissionsGranted = false;

  // ダイアログが開いているか
  bool _isDialogOpen = false;

  // 接続しているデバイスの情報
  String? _connectedDevice;

  bool uploadSuccess = false;

  String? _accessKey;



  // static DateTime? _lastCheckedTime;
  // static bool? _lastOnlineStatus;
  // static const Duration cacheDuration = Duration(seconds: 30); // キャッシュ時間

  @override
  // ウィジエット初期化時に、カメラアクセス権を確認
  void initState() {
    // 親クラスのinitStateメソッドを呼び出し
    super.initState();
    // ユーザーの設定をロード
    _loadPreferences();
    // 画像の初期化
    _image = null;
    // ライフサイクルの変更祖監視するためのオブザーバーを登録
    WidgetsBinding.instance.addObserver(this);
    // パーミッションの状態をチェック
    _checkPermissionsState();
  }

  @override
  // ウィジエット破棄時にオブザーバを削除
  void dispose() {
    // オブザーバを削除して、メモリリークを防ぐ
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ユーザー設定をロード（保存先設定・接続デバイス情報）
  Future<void> _loadPreferences() async {
    final storageProvider = Provider.of<AppState>(context, listen: false);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // **保存先の取得**（デフォルトは "firebase"）
    String storedValue = prefs.getString('selectedStorage') ?? "firebase";
    storageProvider.setSelectedStorage(storedValue);
    // **接続デバイス情報の取得**
    setState(() {
      _connectedDevice = prefs.getString('connectedDevice');
    });
    // 設定を即時反映
    storageProvider.notifyListeners();
  }

  // ユーザー設定を保存（保存先設定・接続デバイス情報）
  Future<void> _savePreferences() async {
    final storageProvider = Provider.of<AppState>(context, listen: false);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // **保存先の保存**
    await prefs.setString('selectedStorage', storageProvider.selectedStorage);
    // **接続デバイス情報の保存**
    await prefs.setString('connectedDevice', _connectedDevice ?? '');
    // 設定を即時反映
    storageProvider.notifyListeners();
  }

  // // カメラのパーミッションを確認し、状態に応じたダイアログを表示
  // Future<void> _checkCameraPermissions() async {
  //   // カメラのパーミッションをリクエスト
  //   var cameraRequest = await Permission.camera.request();
  //   Future.microtask(() {
  //     Provider.of<CameraScreenState>(context, listen: false)
  //         .addLog('カメラの権限：$cameraRequest');
  //   });
  //   // パーミッションが許可された場合
  //   if (cameraRequest.isGranted) {
  //     setState(() {
  //       _permissionsGranted = true;
  //     });
  //     // 権限が永久に拒否された場合
  //   } else if (cameraRequest.isPermanentlyDenied) {
  //     // ユーザーが「今後表示しない」を選択した場合、設定画面を開く
  //     openAppSettings();
  //     // 権限が一時的に拒否された場合
  //   } else if (cameraRequest.isDenied) {
  //     // ユーザーが拒否した場合、ダイアログで再確認
  //     _showCameraPermissionDialog();
  //     // 権限が制限された場合
  //   } else if (cameraRequest.isLimited) {
  //     // 制限付きアクセスの場合、フルアクセスを促すダイアログを表示
  //     _showCameraLimitedPermissionDialog();
  //   }
  // }
  //
  // // 写真ストレージのパーミッションを確認
  // Future<void> _checkStoragePermission() async {
  //   final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  //
  //   // Android端末
  //   if (Platform.isAndroid) {
  //     final androidInfo = await deviceInfo.androidInfo;
  //     final int androidOsVersion = androidInfo.version.sdkInt;
  //     Future.microtask(() {
  //       Provider.of<CameraScreenState>(context, listen: false)
  //           .addLog('Androidのバージョン：$androidOsVersion');
  //     });
  //
  //     // バージョンに応じて適切なPermissionオブジェクトを取得
  //     Permission permission = androidOsVersion >= 33
  //         ? Permission.photos // Android 13以上
  //         : Permission.storage; // Android 13未満
  //
  //     // 権限の状態を確認
  //     var status = await permission.status;
  //     Future.microtask(() {
  //       Provider.of<CameraScreenState>(context, listen: false)
  //           .addLog('ストレージアクセスの権限(Android)：$status');
  //     });
  //
  //     if (status.isGranted) {
  //       setState(() {
  //         _storagePermissionsGranted = true;
  //       });
  //     } else {
  //       // 権限をリクエスト
  //       var requestResult = await permission.request();
  //       Future.microtask(() {
  //         Provider.of<CameraScreenState>(context, listen: false)
  //             .addLog('権限リクエストの結果(Android)：$requestResult');
  //       });
  //       if (requestResult.isPermanentlyDenied) {
  //         // 設定画面を開く
  //         openAppSettings();
  //       } else if (requestResult.isDenied) {
  //         // 拒否時のダイアログ表示
  //         _showStoragePermissionDialog();
  //       } else if (requestResult.isLimited) {
  //         // 制限付きアクセスの場合の処理
  //         _showLimitedStoragePermissionDialog();
  //       }
  //     }
  //   }
  //   // ios端末の場合
  //   if (Platform.isIOS) {
  //     // IOSのバージョンを確認
  //     final iosInfo = await deviceInfo.iosInfo;
  //     final iosOsVersion = iosInfo.systemVersion ?? "0.0";
  //     Future.microtask(() {
  //       Provider.of<CameraScreenState>(context, listen: false)
  //           .addLog('IOSのバージョン； $iosOsVersion');
  //     });
  //     // IOS14以上の場合
  //     if (int.parse(iosOsVersion.split('.')[0]) >= 14) {
  //       // 現在の写真ストレージへのアクセス権限を確認
  //       var photoStatus = await Permission.photos.status;
  //       Future.microtask(() {
  //         Provider.of<CameraScreenState>(context, listen: false)
  //             .addLog('写真アクセスの権限(IOS)：$photoStatus');
  //       });
  //       if (photoStatus.isGranted) {
  //         setState(() {
  //           _storagePermissionsGranted = true;
  //         });
  //       } else {
  //         // 写真ストレージへのアクセス権限が付与されていない場合はユーザに許可を求める。
  //         var photoRequest = await Permission.photos.request();
  //         // 権限が永久に拒否された場合
  //         if (photoRequest.isPermanentlyDenied) {
  //           // アプリ側では再度権限リクエストができないため、デバイスの設定画面を開く
  //           openAppSettings();
  //           // 権限が一時的に拒否された場合
  //         } else if (photoRequest.isDenied) {
  //           // 権限を再度要求するためのダイアログ（アプリ側で表示）
  //           _showStoragePermissionDialog();
  //           // 権限が制限された場合
  //         } else if (photoRequest.isLimited) {
  //           // フルアクセスを促すダイアログ（アプリ側で表示）
  //           _showLimitedStoragePermissionDialog();
  //         }
  //       }
  //     } else {
  //       // IOS14未満の場合
  //       // 現在の写真ストレージへのアクセス権限を確認
  //       var photoStatus = await Permission.photos.status;
  //       Future.microtask(() {
  //         Provider.of<CameraScreenState>(context, listen: false)
  //             .addLog('写真アクセスの権限(IOS)：$photoStatus');
  //       });
  //       if (photoStatus.isGranted) {
  //         setState(() {
  //           _storagePermissionsGranted = true;
  //         });
  //       } else {
  //         // 写真ストレージへのアクセス権限が付与されていない場合はユーザに許可を求める。
  //         var photoRequest = await Permission.photos.request();
  //         // 権限が永久に拒否された場合
  //         if (photoRequest.isPermanentlyDenied) {
  //           // アプリ側では再度権限リクエストができないため、デバイスの設定画面を開く
  //           openAppSettings();
  //           // 権限が一時的に拒否された場合
  //         } else if (photoRequest.isDenied) {
  //           // 権限を再度要求するためのダイアログ（アプリ側で表示）
  //           _showStoragePermissionDialog();
  //           // 権限が制限された場合
  //         } else if (photoRequest.isLimited) {
  //           // フルアクセスを促すダイアログ（アプリ側で表示）
  //           _showLimitedStoragePermissionDialog();
  //         }
  //       }
  //     }
  //   }
  // }
  //
  // // 権限を再度要求するためのダイアログ（カメラ用）
  // void _showCameraPermissionDialog() {
  //   _isDialogOpen = true;
  //   showDialog(
  //       context: context,
  //       builder: (BuildContext context) {
  //         return AlertDialog(
  //           title: Text('アプリ使用には権限の設定が必要です'),
  //           content: Text('このアプリを使用するために、カメラへのアクセス許可が必要です。設定画面に移動して権限を有効にしてください。'),
  //           actions: [
  //             TextButton(
  //               onPressed: () {
  //                 Navigator.of(context).pop();
  //                 _isDialogOpen = false;
  //               },
  //               child: Text('閉じる'),
  //             ),
  //             TextButton(
  //                 onPressed: () {
  //                   openAppSettings();
  //                 },
  //                 child: Text('設定に移動')
  //             ),
  //           ],
  //         );
  //       }
  //   );
  // }
  //
  // // フルアクセスを許可するように促すダイアログ
  // void _showCameraLimitedPermissionDialog() {
  //   _isDialogOpen = true;
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text('権限が制限されています'),
  //         content: Text('このアプリではカメラへのアクセスが制限されています。アプリを使用するために、カメラへのアクセスを許可してください。'),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //               _isDialogOpen = false;
  //             },
  //             child: Text('閉じる'),
  //           ),
  //           TextButton(
  //             onPressed: () {
  //               openAppSettings();
  //               Navigator.of(context).pop();
  //             },
  //             child: Text('設定に移動'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
  //
  // // ストレージのアクセス許可をリクエストするダイアログ
  // void _showStoragePermissionDialog() {
  //   if (!mounted) return;
  //   _isDialogOpen = true;
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text('ストレージへのアクセス権限が必要です'),
  //         content: Text('このアプリを使用するためには、ストレージへのアクセスが必要です。設定画面に移動して権限を有効にしてください。'),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //               _isDialogOpen = false;
  //             },
  //             child: Text('閉じる'),
  //           ),
  //           TextButton(
  //             onPressed: () {
  //               openAppSettings();
  //             },
  //             child: Text('設定に移動'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
  //
  //
  // // ストレージのフルアクセスを許可するように促すダイアログ
  // void _showLimitedStoragePermissionDialog() {
  //   _isDialogOpen = true;
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text('権限付きの写真アクセス'),
  //         content: Text('このアプリでは制限された写真アクセスが有効になっています。フルアクセスを許可してください。'),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //               _isDialogOpen = false;
  //             },
  //             child: Text('閉じる'),
  //           ),
  //           TextButton(
  //             onPressed: () {
  //               openAppSettings();
  //             },
  //             child: Text('設定に移動'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
  // パーミッションの状態をチェック
  void _checkPermissionsState() {
    final storageProvider = Provider.of<AppState>(context, listen: false);
    setState(() {
      _permissionsGranted = storageProvider.cameraPermission;
      _storagePermissionsGranted = storageProvider.storagePermission;
    });
  }
  // カメラを開く
  Future<void> _openCamera() async {
      final storageProvider = Provider.of<AppState>(context, listen: false);
      // カメラ・ストレージへのパーミッションが有効以外の場合、ダイアログを表示する
      if (!_permissionsGranted || !_storagePermissionsGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('カメラ又はストレージへのアクセス権限がありません')),
        );
        return;
      }

    // 各パーミッションが有効な場合のみカメラを開く。
    // カメラを起動し、画像撮影を待つ。
    final XFile? pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    // 画像が撮影された場合の処理
    if(pickedFile != null) {
      setState(() {
        // image変数に画像を格納。
        _image = File(pickedFile.path);
      });
      // 画像編集画面へ遷移
      _editImage(pickedFile.path);
    }
  }

  // 撮影した画像を編集
  Future<void> _editImage(String imagePath) async {
    // 画像パスからFileオブジェクトを作成
    final File imageFile = File(imagePath);

    // 画像編集画面に遷移
    final editedImage = await Navigator.push(
      context,
      // ImageEditorに編集対象の画像データを渡す
      MaterialPageRoute(
        builder: (context) => ImageEditor(
          image: imageFile.readAsBytesSync(),
        ),
      ),
    );

    // 編集後、画像がnullでない場合は保存処理を行う。
    if(editedImage != null) {
      // プログレスインジゲータを表示。ロード状態に変更する
      setState(() {
        _isLoading = true;
      });
      // 加工した画像を保存
      _saveEditedImage(editedImage);
    } else {
      // 画像がnullの場合はログを出力
      Future.microtask(() {
        Provider.of<CameraScreenState>(context, listen: false)
            .addLog('編集画像がありません。');
        });
    }
  }

  // ローカルストレージへ保存
  Future<String> _saveImageToLocalStorage(Uint8List imageBytes) async {
    String filePath = '';
    // Android端末の場合
    if(Platform.isAndroid) {
      filePath = await _saveImageToLocalStorageAndroid(imageBytes);
    // IOS端末の場合
    } else if(Platform.isIOS) {
      filePath = await _saveImageToLocalStorageIOS(imageBytes, context);
    } else {
      throw Exception('未対応のプラットフォームです');
    }
    _image = null;
    return filePath;
  }

  // ローカル保存（Android端末の場合）
  Future<String> _saveImageToLocalStorageAndroid(Uint8List imageBytes) async {
    // 保存先を指定（/storage/emulated/0/ は Android の一般的なローカルストレージパス）
    final storageProvider = Provider.of<AppState>(context, listen: false);
    final Directory directory;
    if (storageProvider.selectedStorage == 'device') {
      directory = Directory(
          '/storage/emulated/0/Pictures/fanpixsnap');
    } else {
      directory = Directory(
          '/storage/emulated/0/Pictures/fanpixsnaperr');
    }
    String dirPath = directory.path;
    Directory newDirectory = Directory(dirPath);

    // 保存先が存在するか確認
    if (!await newDirectory.exists()) {
      try {
        // 保存先が存在しない場合ディレクトリを作成する
        await newDirectory.create(recursive: true);
      } catch (e) {
        throw Exception("ディレクトリ作成に失敗しました: $e");
      }
    }

    // ファイル名は「edited_image_<タイムスタンプ>.jpg」として保存
    final String filePath = '$dirPath/edited_image_${DateTime.now().toLocal().toIso8601String().replaceAll(':', '-')}.jpg';
    final file = File(filePath);
    // 画像ファイルを作成して保存
    try {
      await file.writeAsBytes(imageBytes);
    } catch (e) {
      throw Exception("画像の保存に失敗しました: $e");
    }
    Future.microtask(() {
      Provider.of<CameraScreenState>(context, listen: false)
          .addLog('ローカルストレージに画像が保存されました(Android端末)：$filePath');
    });
    return filePath;
  }

  // ローカル保存（IOS端末の場合）
  // Future<String> _saveImageToLocalStorageIOS(Uint8List imageBytes) async  {
  //   // IOSのアプリ専用ドキュメントディレクトリを取得
  //   final storageProvider = Provider.of<AppState>(context, listen: false);
  //   final Directory directory = await getApplicationDocumentsDirectory();
  //   final Directory dirPath;
  //   if (storageProvider.selectedStorage == 'device') {
  //     dirPath = Directory('${directory.path}/fanpixsnap');
  //   } else {
  //     dirPath = Directory('${directory.path}/fanpixsnaperr');
  //   }
  //
  //   // 保存先が存在するか確認
  //   if (dirPath != null) {
  //     try {
  //       if (!await dirPath.exists()) {
  //         // 保存先が存在しない場合ディレクトリを作成する
  //         await dirPath.create(recursive: true);
  //       }
  //     } catch (e) {
  //       throw Exception("ディレクトリ作成に失敗しました: $e");
  //     }
  //   } else {
  //     throw Exception("保存ディレクトリの取得に失敗しました");
  //   }
  //
  //
  //   // ファイル名は「edited_image_<タイムスタンプ>.jpg」として保存
  //   final String filename = 'edited_image_${DateTime.now().toLocal().toIso8601String().replaceAll(':', '-')}.jpg';
  //   final String filePath = '$dirPath/$filename';
  //   final file = File(filePath);
  //   // 画像ファイルを作成してドキュメントディレクトリに保存
  //   await file.writeAsBytes(imageBytes);
  //   Future.microtask(() {
  //     Provider.of<CameraScreenState>(context, listen: false)
  //         .addLog('ローカルストレージに画像が保存されました（IOS）：$filePath');
  //   });
  //   return filePath;
  //   try {
  //     // iosのフォトライブラリに画像を保存
  //     final AssetEntity asset = await PhotoManager.editor.saveImage(imageBytes, filename: filename);
  //     print('画像がフォトライブラリに保存されました：${asset.id}');
  //     // フォトライブラリに保存された場合は画像のIDを返却
  //     return asset.id;
  //   } catch(e) {
  //     throw Exception('フォトライブラリへの保存に失敗しました：$e');
  //   }
  // }
  Future<String> _saveImageToLocalStorageIOS(Uint8List imageBytes, BuildContext context) async {
    final String filename = 'edited_image_${DateTime.now()
        .toLocal()
        .toIso8601String()
        .replaceAll(':', '-')}.jpg';
    final storageProvider = Provider.of<AppState>(context, listen: false);
    String folderName = storageProvider.selectedStorage == 'device'
        ? "fanpixsnap"
        : "fanpixsnaperr";

    // 写真ライブラリの権限をリクエスト
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      throw Exception("写真ライブラリへのアクセス権限がありません");
    }

    // ローカルストレージに保存先のパスを設定
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String folderPath = '${appDocDir.path}/$folderName';
    await Directory(folderPath).create(recursive: true); // フォルダを作成

    String filePath = '$folderPath/$filename';

    // 画像をローカルストレージに保存
    final File imageFile = File(filePath);
    await imageFile.writeAsBytes(imageBytes);

    Provider.of<CameraScreenState>(context, listen: false)
        .addLog('ローカルストレージに画像が保存されました（iOS）：$filePath');
    // 保存されたファイルのパスを返す
    return filePath;
  }

  Future<File> resizeImage(File file) async {
    final bytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return file;

    img.Image resized = img.copyResize(image, width: 800); // 幅800pxにリサイズ
    final resizedFile = File(file.path)
      ..writeAsBytesSync(img.encodeJpg(resized, quality: 85)); // JPEG圧縮率85%

    return resizedFile;
  }

  // 加工した画像を保存
  Future<void> _saveEditedImage(Uint8List editedImageData) async {
    try {
      String imageUrl;
      String localUrl;
      final storageProvider = Provider.of<AppState>(context, listen: false);
      // 保存先が外部ストレージサーバ
      if(storageProvider.selectedStorage == 'firebase') {
        // オンラインの場合
        if(await _isOnline()) {
          // デバイスの一時保存先パスを取得し、一時ディレクトリに画像を保存
          final directory = await getTemporaryDirectory();
          final fileName = 'edited_image_${DateTime.now().toLocal().toIso8601String().replaceAll(':', '-')}.jpg';
          final editedImagePath = '${directory.path}/$fileName';
          final File editedImageFile = File(editedImagePath);
          await editedImageFile.writeAsBytes(editedImageData);
          File resizedImageFile = await resizeImage(editedImageFile);

          // 保存した画像を外部のストレージサーバーにアップロードする
          // imageUrl = await FirebaseService.uploadImage(editedImageFile);
          // Future.microtask(() {
          //   Provider.of<CameraScreenState>(context, listen: false)
          //       .addLog('imageUrlの確認； $imageUrl');
          // });
          //
          // if (imageUrl.isNotEmpty) {
          // アップロードが成功した場合、QRコード表示画面へ遷移
          uploadSuccess = await Navigator.push(
              context,
              MaterialPageRoute(
                //builder: (context) => StorageQRCodeScreen(imageFuture: FirebaseService.uploadImage(resizedImageFile)),
                builder: (context) => StorageQRCodeScreen(imageFuture: SupabaseService.uploadImage(resizedImageFile)),
              ),
            );
          Future.microtask(() {
            Provider.of<CameraScreenState>(context, listen: false)
                .addLog('外部ストレージサーバに画像を保存しました：$resizedImageFile');
          });

          // } else {
          if (!uploadSuccess) {
            // アップロード処理に失敗した場合（アップロード先のURLがEmpty）
            localUrl = await _saveImageToLocalStorage(editedImageData) ?? "ローカル保存失敗";
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  content: Text('外部ストレージサーバーへの保存に失敗しました。ローカルに保存しました：$localUrl'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        // OKボタンが押されたときにダイアログを閉じる
                        Navigator.of(context).pop();
                      },
                      child: Text('OK'),
                    ),
                  ],
                );
              },
            );
            Future.microtask(() {
              Provider.of<CameraScreenState>(context, listen: false)
                  .addLog('ローカルサーバーへの保存失敗。ローカルに保存：$localUrl');
            });
          }
        } else {
          // オフライン状態の場合はローカルに保存
          localUrl = await _saveImageToLocalStorage(editedImageData) ?? "ローカル保存失敗";
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                content: Text('現在オフラインです。ローカルに保存しました：$localUrl'),
                actions: [
                  TextButton(
                    onPressed: () {
                      // OKボタンが押されたときにダイアログを閉じる
                      Navigator.of(context).pop();
                    },
                    child: Text('OK'),
                  ),
                ],
              );
            },
          );
          Future.microtask(() {
            Provider.of<CameraScreenState>(context, listen: false)
                .addLog('オフラインのためローカルに保存：$localUrl');
          });
        }
      } else if (storageProvider.selectedStorage == 'local_server') {
        // 保存先がローカルの場合は、ローカルサーバに送信
        localUrl = await _sendImageToLocalServer(editedImageData);
        if (localUrl.isNotEmpty) {
          Future.microtask(() {
            Provider.of<CameraScreenState>(context, listen: false)
                .addLog('ローカルサーバに保存：$localUrl');
          });
        } else {
          Future.microtask(() {
            Provider.of<CameraScreenState>(context, listen: false)
                .addLog('ローカルサーバへの送信に失敗');
          });
        }
      } else if (storageProvider.selectedStorage == 'device') {
        localUrl = await _saveImageToLocalStorage(editedImageData) ?? "ローカル保存失敗";
        if (localUrl.isNotEmpty) {
          Future.microtask(() {
            Provider.of<CameraScreenState>(context, listen: false)
                .addLog('自端末に保存：$localUrl');
          });
          final appState = Provider.of<AppState>(context, listen: false);
          final timestamp = DateTime.now().toLocal().millisecondsSinceEpoch;
          final expirationTime = 5 * 60 * 1000;
          _accessKey = localUrl;
          final serverUrl =
          _accessKey != null
              ? 'http://${appState.localIpAddress}:${appState.port}?file=$_accessKey&timestamp=$timestamp&expiresIn=$expirationTime'
              : '';

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LocalQRCodeDisplayScreen(
                serverUrl: serverUrl,
                onBack: _resetSelection,
              ),
            ),
          );
        } else {
          Future.microtask(() {
            Provider.of<CameraScreenState>(context, listen: false)
                .addLog('自端末への保存失敗');
          });
        }
      }
    } catch (e) {
      // ファイルの保存やアップデートに失敗した場合
      if(uploadSuccess == false) {
        Future.microtask(() {
          Provider.of<CameraScreenState>(context, listen: false)
              .addLog('ファイルの保存に失敗: $e');
        });
      }
    } finally {
      // すべての処理が終わったらローディング状態を解除
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetSelection() {
    if (mounted) {
      setState(() {
        _accessKey = null;
      });
      Navigator.pop(context); // QRコード画面から戻る
    }
  }
  // Future<bool> _isOnline() async {
  //   // キャッシュが有効であれば、前回の結果を返す
  //   if (_lastCheckedTime != null &&
  //       DateTime.now().difference(_lastCheckedTime!) < cacheDuration &&
  //       _lastOnlineStatus != null) {
  //     return _lastOnlineStatus!;
  //   }
  //
  //   // 実際のオンラインチェックを実行
  //   bool onlineStatus = await _checkInternetConnection();
  //
  //   // 結果をキャッシュ
  //   _lastCheckedTime = DateTime.now();
  //   _lastOnlineStatus = onlineStatus;
  //
  //   return onlineStatus;
  // }

  // オフライン状態を確認する
  Future<bool> _isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      bool isConnected = connectivityResult.toString() == "[ConnectivityResult.mobile]" ||
          connectivityResult.toString() == "[ConnectivityResult.wifi]";
      Future.microtask(() {
        Provider.of<CameraScreenState>(context, listen: false)
            .addLog(isConnected ? 'ネットワークオンライン' : 'ネットワークオフライン');
      });
      return isConnected;
    } catch (e) {
      Future.microtask(() {
        Provider.of<CameraScreenState>(context, listen: false)
            .addLog('ネットワーク状態の取得に失敗: $e');
      });
      // エラー時はオフラインとみなす
      return false;
    }
  }

  // ローカルサーバーに画像を送信
  Future<String> _sendImageToLocalServer(Uint8List editedImageData) async {
    String localUrl;
    try {
      final ipAddress = Provider.of<AppState>(context).ipAddress;
      final port = Provider.of<AppState>(context).port;
      final Uri uri = Uri.parse('http://$ipAddress:$port/upload');

      // 送信中のメッセージを更新
      Future.microtask(() {
        Provider.of<CameraScreenState>(context, listen: false)
            .addLog("画像送信中...");
      });

      // 画像を送信するためのHTTP POSTリクエスト
      final response = await http.post(
        uri,
        headers: {
          // バイナリデータとして送信
          'Content-Type': 'application/octet-stream',
        },
        // 画像のバイトデータをリクエストボディに追加
        body: editedImageData,
        // タイムアウトを設定
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        // 成功メッセージを表示
        Future.microtask(() {
          Provider.of<CameraScreenState>(context, listen: false)
              .addLog('画像がサーバーに送信されました $editedImageData');
        });
        // サーバーからのレスポンス（成功時のメッセージなど）
        return response.body;
      } else {
        // 画像送信に失敗した場合
        localUrl = await _saveImageToLocalStorage(editedImageData);
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Text('画像送信中にエラーが発生しました。ローカルに保存しました：$localUrl'),
              actions: [
                TextButton(
                  onPressed: () {
                    // OKボタンが押されたときにダイアログを閉じる
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
        Future.microtask(() {
          Provider.of<CameraScreenState>(context, listen: false)
              .addLog('画像送信失敗: ${response.statusCode}');
        });
        return '画像送信失敗: ${response.statusCode}';
      }
    } catch (e) {
      // 画像送信に失敗した場合
      localUrl = await _saveImageToLocalStorage(editedImageData);
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text('画像送信中にエラーが発生しました。ローカルに保存しました：$localUrl'),
            actions: [
              TextButton(
                onPressed: () {
                  // OKボタンが押されたときにダイアログを閉じる
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );

      // エラーメッセージを表示
      Future.microtask(() {
        Provider.of<CameraScreenState>(context, listen: false)
            .addLog('画像送信中にエラーが発生しました: $e');
      });
      return '画像送信中にエラーが発生しました: $e';
    }
  }

  void _onStorageSelected(String value) async {
    final storageProvider = Provider.of<AppState>(context, listen: false);

    setState(() {
      storageProvider.setSelectedStorage(value);
      _savePreferences();
    });

    Navigator.of(context).pop();
  }

  // 保存先選択画面
  void _showStorageSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final storageProvider = Provider.of<AppState>(context, listen: false);
        return AlertDialog(
          title: Text('保存先を選択'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('外部ストレージサーバーに保存'),
                leading: Radio(
                  value: 'firebase',
                  groupValue: storageProvider.selectedStorage,
                  onChanged: (String? value) {
                    if (value != null) _onStorageSelected(value);
                  },
                ),
              ),
              ListTile(
                title: Text('ローカルサーバーに保存'),
                leading: Radio(
                  value: 'local_server',
                  groupValue: storageProvider.selectedStorage,
                  onChanged: (String? value) {
                    if (value != null) _onStorageSelected(value);
                  },
                ),
              ),
              ListTile(
                title: Text('自分の端末に保存'),
                leading: Radio(
                  value: 'device',
                  groupValue: storageProvider.selectedStorage,
                  onChanged: (String? value) {
                    if (value != null) _onStorageSelected(value);
                  },
                ),
              ),
            ],
          ),
          actions:[
            TextButton(
              onPressed:() {
                Navigator.of(context).pop();
              },
              child: Text('キャンセル'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final storageProvider = Provider.of<AppState>(context);
    // サーバー管理インスタンス
    final serverManager = Provider.of<LocalServerManager>(context);

    return Scaffold(
      // アプリ上部に表示されるタイトル
      appBar: AppBar(title: Text('FanPixSnap')),
      // Centerウィジエットを使用して表示
      body: Center(
        child: _isLoading
        // ローディング中の場合は、プログレスインジケータを表示
            ? CircularProgressIndicator()
            : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _openCamera,
                  child: Text(' カメラを起動 '),
                ),
                SizedBox(height: 50),
                ElevatedButton(
                  onPressed: _showStorageSelectionDialog,
                  child: Text(' 保存先を選択 '),
                ),
                SizedBox(height: 15),
                Text(
                  '現在の保存先: ${storageProvider.selectedStorage == 'firebase' ? '外部ストレージサーバー' : storageProvider.selectedStorage == 'local_server' ? 'ローカルサーバー' : '自分の端末'}',
                    style: TextStyle(fontSize: 20),),
                SizedBox(height: 10),
                if (!serverManager.isRunning && storageProvider.selectedStorage == 'device')
                  Text('「ローカルサーバに設定」から\nローカルサーバを起動してください。',
                    style: TextStyle(fontSize: 15),),
                SizedBox(height: 30),
                if (storageProvider.selectedStorage != 'firebase')
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LocalServerPage()),
                    );
                  },
                  child: Text(' ローカルサーバに設定 '),
                ),
                SizedBox(height: 30),
                if (storageProvider.selectedStorage == 'local_server')
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LocalClientPage(
                        onConnected:(String deviceName) {
                          setState(() {
                            _savePreferences();
                          });
                        })
                      ),
                    );
                  },
                  child: Text(' ローカルサーバに接続 '),
                ),
              ],
            ),
      ),
    );
  }
}
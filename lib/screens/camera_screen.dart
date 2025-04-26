import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import '../services/local_client_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'image_edit_screen.dart';
import '../services/app_state.dart';
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

class _CameraClassState extends State<CameraScreen>
    with WidgetsBindingObserver {
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
    // **保存先の取得**（デフォルトは "cloud"）
    String storedValue = prefs.getString('selectedStorage') ?? "cloud";
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
    final XFile? pickedFile =
    await ImagePicker().pickImage(source: ImageSource.camera);
    // 画像が撮影された場合の処理
    if (pickedFile != null) {
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

    // 画像編集画面に遷移(新規作成画面)
    final editedImage = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageEditScreen(imageFile: File(imageFile.path)),
      ),
      // 旧バージョン（Flutterパッケージのため拡張できないのでカスタマイズに変更）
      // //ImageEditor(Flutterのパッケージ)に編集対象の画像データを渡す
      // MaterialPageRoute(
      //   builder:(context) => ImageEditor(
      //     image:imageFile.readAsBytesSync(),
      //   ),
      // ),
    );

    // 保存処理をimage_edit_screenに移動
    // // 編集後、画像がnullでない場合は保存処理を行う。
    // if(editedImage != null) {
    //   // プログレスインジゲータを表示。ロード状態に変更する
    //   setState(() {
    //     _isLoading = true;
    //   });
    //   // 加工した画像を保存
    //   _saveEditedImage(editedImage);
    // } else {
    //   // 画像がnullの場合はログを出力
    //   Future.microtask(() {
    //     Provider.of<CameraScreenState>(context, listen: false)
    //         .addLog('編集画像がありません。');
    //     });
    // }
  }

  // // ローカルストレージへ保存
  // Future<String> _saveImageToLocalStorage(Uint8List imageBytes) async {
  //   String filePath = '';
  //   // Android端末の場合
  //   if(Platform.isAndroid) {
  //     filePath = await _saveImageToLocalStorageAndroid(imageBytes);
  //   // IOS端末の場合
  //   } else if(Platform.isIOS) {
  //     filePath = await _saveImageToLocalStorageIOS(imageBytes, context);
  //   } else {
  //     throw Exception('未対応のプラットフォームです');
  //   }
  //   _image = null;
  //   return filePath;
  // }
  //
  // // ローカル保存（Android端末の場合）
  // Future<String> _saveImageToLocalStorageAndroid(Uint8List imageBytes) async {
  //   // 保存先を指定（/storage/emulated/0/ は Android の一般的なローカルストレージパス）
  //   final storageProvider = Provider.of<AppState>(context, listen: false);
  //   final Directory directory;
  //   if (storageProvider.selectedStorage == 'device') {
  //     directory = Directory(
  //         '/storage/emulated/0/Pictures/fanpixsnap');
  //   } else {
  //     directory = Directory(
  //         '/storage/emulated/0/Pictures/fanpixsnaperr');
  //   }
  //   String dirPath = directory.path;
  //   Directory newDirectory = Directory(dirPath);
  //
  //   // 保存先が存在するか確認
  //   if (!await newDirectory.exists()) {
  //     try {
  //       // 保存先が存在しない場合ディレクトリを作成する
  //       await newDirectory.create(recursive: true);
  //     } catch (e) {
  //       throw Exception("ディレクトリ作成に失敗しました: $e");
  //     }
  //   }
  //
  //   // ファイル名は「edited_image_<タイムスタンプ>.jpg」として保存
  //   final String filePath = '$dirPath/edited_image_${DateTime.now().toLocal().toIso8601String().replaceAll(':', '-')}.jpg';
  //   final file = File(filePath);
  //   // 画像ファイルを作成して保存
  //   try {
  //     await file.writeAsBytes(imageBytes);
  //   } catch (e) {
  //     throw Exception("画像の保存に失敗しました: $e");
  //   }
  //   Future.microtask(() {
  //     Provider.of<CameraScreenState>(context, listen: false)
  //         .addLog('ローカルストレージに画像が保存されました(Android端末)：$filePath');
  //   });
  //   return filePath;
  // }
  //
  // Future<String> _saveImageToLocalStorageIOS(Uint8List imageBytes, BuildContext context) async {
  //   final String filename = 'edited_image_${DateTime.now()
  //       .toLocal()
  //       .toIso8601String()
  //       .replaceAll(':', '-')}.jpg';
  //   final storageProvider = Provider.of<AppState>(context, listen: false);
  //   String folderName = storageProvider.selectedStorage == 'device'
  //       ? "fanpixsnap"
  //       : "fanpixsnaperr";
  //
  //   // 写真ライブラリの権限をリクエスト
  //   final PermissionState ps = await PhotoManager.requestPermissionExtend();
  //   if (!ps.isAuth) {
  //     throw Exception("写真ライブラリへのアクセス権限がありません");
  //   }
  //
  //   // ローカルストレージに保存先のパスを設定
  //   Directory appDocDir = await getApplicationDocumentsDirectory();
  //   String folderPath = '${appDocDir.path}/$folderName';
  //   await Directory(folderPath).create(recursive: true); // フォルダを作成
  //
  //   String filePath = '$folderPath/$filename';
  //
  //   // 画像をローカルストレージに保存
  //   final File imageFile = File(filePath);
  //   await imageFile.writeAsBytes(imageBytes);
  //
  //   Provider.of<CameraScreenState>(context, listen: false)
  //       .addLog('ローカルストレージに画像が保存されました（iOS）：$filePath');
  //
  //   // 保存されたファイルのパスを返す
  //   return filePath;
  // }
  //
  // Future<File> resizeImage(File file) async {
  //   final bytes = await file.readAsBytes();
  //   img.Image? image = img.decodeImage(bytes);
  //   if (image == null) return file;
  //
  //   img.Image resized = img.copyResize(image, width: 800); // 幅800pxにリサイズ
  //   final resizedFile = File(file.path)
  //     ..writeAsBytesSync(img.encodeJpg(resized, quality: 85)); // JPEG圧縮率85%
  //
  //   // リサイズ後のファイルを返す
  //   return resizedFile;
  // }
  //
  // // 加工した画像を保存
  // Future<void> _saveEditedImage(Uint8List editedImageData) async {
  //   try {
  //     String imageUrl;
  //     String localUrl;
  //     final storageProvider = Provider.of<AppState>(context, listen: false);
  //     // 保存先が外部ストレージサーバ
  //     if(storageProvider.selectedStorage == 'cloud') {
  //       // オンラインの場合
  //       if(await _isOnline()) {
  //         // デバイスの一時保存先パスを取得し、一時ディレクトリに画像を保存
  //         final directory = await getTemporaryDirectory();
  //         final fileName = 'edited_image_${DateTime.now().toLocal().toIso8601String().replaceAll(':', '-')}.jpg';
  //         final editedImagePath = '${directory.path}/$fileName';
  //         final File editedImageFile = File(editedImagePath);
  //         await editedImageFile.writeAsBytes(editedImageData);
  //         File resizedImageFile = await resizeImage(editedImageFile);
  //
  //         uploadSuccess = await Navigator.push(
  //             context,
  //             MaterialPageRoute(
  //               //builder: (context) => StorageQRCodeScreen(imageFuture: cloudService.uploadImage(resizedImageFile)),
  //               builder: (context) => StorageQRCodeScreen(imageFuture: SupabaseService.uploadImage(resizedImageFile)),
  //             ),
  //           );
  //         Future.microtask(() {
  //           Provider.of<CameraScreenState>(context, listen: false)
  //               .addLog('外部ストレージサーバに画像を保存しました：$resizedImageFile');
  //         });
  //
  //         if (!uploadSuccess) {
  //           // アップロード処理に失敗した場合（アップロード先のURLがEmpty）
  //           localUrl = await _saveImageToLocalStorage(editedImageData) ?? "ローカル保存失敗";
  //           showDialog(
  //             context: context,
  //             builder: (context) {
  //               return AlertDialog(
  //                 content: Text('外部ストレージサーバーへの保存に失敗しました。ローカルに保存しました：$localUrl'),
  //                 actions: [
  //                   TextButton(
  //                     onPressed: () {
  //                       // OKボタンが押されたときにダイアログを閉じる
  //                       Navigator.of(context).pop();
  //                     },
  //                     child: Text('OK'),
  //                   ),
  //                 ],
  //               );
  //             },
  //           );
  //           Future.microtask(() {
  //             Provider.of<CameraScreenState>(context, listen: false)
  //                 .addLog('ローカルサーバーへの保存失敗。ローカルに保存：$localUrl');
  //           });
  //         }
  //       } else {
  //         // オフライン状態の場合はローカルに保存
  //         localUrl = await _saveImageToLocalStorage(editedImageData) ?? "ローカル保存失敗";
  //         showDialog(
  //           context: context,
  //           builder: (context) {
  //             return AlertDialog(
  //               content: Text('現在オフラインです。ローカルに保存しました：$localUrl'),
  //               actions: [
  //                 TextButton(
  //                   onPressed: () {
  //                     // OKボタンが押されたときにダイアログを閉じる
  //                     Navigator.of(context).pop();
  //                   },
  //                   child: Text('OK'),
  //                 ),
  //               ],
  //             );
  //           },
  //         );
  //         Future.microtask(() {
  //           Provider.of<CameraScreenState>(context, listen: false)
  //               .addLog('オフラインのためローカルに保存：$localUrl');
  //         });
  //       }
  //     } else if (storageProvider.selectedStorage == 'local_server') {
  //       // 保存先がローカルの場合は、ローカルサーバに送信
  //       localUrl = await _sendImageToLocalServer(editedImageData);
  //       if (localUrl.isNotEmpty) {
  //         Future.microtask(() {
  //           Provider.of<CameraScreenState>(context, listen: false)
  //               .addLog('ローカルサーバに保存：$localUrl');
  //         });
  //       } else {
  //         Future.microtask(() {
  //           Provider.of<CameraScreenState>(context, listen: false)
  //               .addLog('ローカルサーバへの送信に失敗');
  //         });
  //       }
  //     } else if (storageProvider.selectedStorage == 'device') {
  //       localUrl = await _saveImageToLocalStorage(editedImageData) ?? "ローカル保存失敗";
  //       if (localUrl.isNotEmpty) {
  //         Future.microtask(() {
  //           Provider.of<CameraScreenState>(context, listen: false)
  //               .addLog('自端末に保存：$localUrl');
  //         });
  //         final appState = Provider.of<AppState>(context, listen: false);
  //         final timestamp = DateTime.now().toLocal().millisecondsSinceEpoch;
  //         final expirationTime = 5 * 60 * 1000;
  //         _accessKey = localUrl;
  //         final serverUrl =
  //         _accessKey != null
  //             ? 'http://${appState.localIpAddress}:${appState.port}?file=$_accessKey&timestamp=$timestamp&expiresIn=$expirationTime'
  //             : '';
  //
  //         Navigator.push(
  //           context,
  //           MaterialPageRoute(
  //             builder: (context) => LocalQRCodeDisplayScreen(
  //               serverUrl: serverUrl,
  //               onBack: _resetSelection,
  //             ),
  //           ),
  //         );
  //       } else {
  //         Future.microtask(() {
  //           Provider.of<CameraScreenState>(context, listen: false)
  //               .addLog('自端末への保存失敗');
  //         });
  //       }
  //     }
  //   } catch (e) {
  //     // ファイルの保存やアップデートに失敗した場合
  //     if(uploadSuccess == false) {
  //       Future.microtask(() {
  //         Provider.of<CameraScreenState>(context, listen: false)
  //             .addLog('ファイルの保存に失敗: $e');
  //       });
  //     }
  //   } finally {
  //     // すべての処理が終わったらローディング状態を解除
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }
  //
  // void _resetSelection() {
  //   if (mounted) {
  //     setState(() {
  //       _accessKey = null;
  //     });
  //     Navigator.pop(context); // QRコード画面から戻る
  //   }
  // }
  //
  // // オフライン状態を確認する
  // Future<bool> _isOnline() async {
  //   try {
  //     final connectivityResult = await Connectivity().checkConnectivity();
  //     bool isConnected = connectivityResult.toString() == "[ConnectivityResult.mobile]" ||
  //         connectivityResult.toString() == "[ConnectivityResult.wifi]";
  //     Future.microtask(() {
  //       Provider.of<CameraScreenState>(context, listen: false)
  //           .addLog(isConnected ? 'ネットワークオンライン' : 'ネットワークオフライン');
  //     });
  //     return isConnected;
  //   } catch (e) {
  //     Future.microtask(() {
  //       Provider.of<CameraScreenState>(context, listen: false)
  //           .addLog('ネットワーク状態の取得に失敗: $e');
  //     });
  //     // エラー時はオフラインとみなす
  //     return false;
  //   }
  // }
  //
  // // ローカルサーバーに画像を送信
  // Future<String> _sendImageToLocalServer(Uint8List editedImageData) async {
  //   String localUrl;
  //   try {
  //     final ipAddress = Provider.of<AppState>(context, listen: false).ipAddress;
  //     final port = Provider.of<AppState>(context, listen: false).port;
  //     final Uri uri = Uri.parse('http://$ipAddress:$port/upload');
  //
  //     // 送信中のメッセージを更新
  //     Future.microtask(() {
  //       Provider.of<CameraScreenState>(context, listen: false)
  //           .addLog("画像送信中...");
  //     });
  //
  //     // 画像を送信するためのHTTP POSTリクエスト
  //     final response = await http.post(
  //       uri,
  //       headers: {
  //         // バイナリデータとして送信
  //         'Content-Type': 'application/octet-stream',
  //       },
  //       // 画像のバイトデータをリクエストボディに追加
  //       body: editedImageData,
  //       // タイムアウトを設定
  //     ).timeout(Duration(seconds: 30));
  //
  //     if (response.statusCode == 200) {
  //       // 成功メッセージを表示
  //       Future.microtask(() {
  //         Provider.of<CameraScreenState>(context, listen: false)
  //             .addLog('画像がサーバーに送信されました');
  //       });
  //       // サーバーからのレスポンス（成功時のメッセージなど）
  //       return response.body;
  //     } else {
  //       // 画像送信に失敗した場合
  //       localUrl = await _saveImageToLocalStorage(editedImageData);
  //       showDialog(
  //         context: context,
  //         builder: (context) {
  //           return AlertDialog(
  //             content: Text('画像送信中にエラーが発生しました。ローカルに保存しました：$localUrl'),
  //             actions: [
  //               TextButton(
  //                 onPressed: () {
  //                   // OKボタンが押されたときにダイアログを閉じる
  //                   Navigator.of(context).pop();
  //                 },
  //                 child: Text('OK'),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //       Future.microtask(() {
  //         Provider.of<CameraScreenState>(context, listen: false)
  //             .addLog('画像送信失敗: ${response.statusCode}');
  //       });
  //       return '画像送信失敗: ${response.statusCode}';
  //     }
  //   } catch (e) {
  //     // 画像送信に失敗した場合
  //     localUrl = await _saveImageToLocalStorage(editedImageData);
  //     showDialog(
  //       context: context,
  //       builder: (context) {
  //         return AlertDialog(
  //           content: Text('画像送信中にエラーが発生しました。ローカルに保存しました：$localUrl'),
  //           actions: [
  //             TextButton(
  //               onPressed: () {
  //                 // OKボタンが押されたときにダイアログを閉じる
  //                 Navigator.of(context).pop();
  //               },
  //               child: Text('OK'),
  //             ),
  //           ],
  //         );
  //       },
  //     );
  //
  //     // エラーメッセージを表示
  //     Future.microtask(() {
  //       Provider.of<CameraScreenState>(context, listen: false)
  //           .addLog('画像送信中にエラーが発生しました: $e');
  //     });
  //     print('画像送信中にエラーが発生しました: $e');
  //     return '画像送信中にエラーが発生しました: $e';
  //   }
  // }

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
              // 保存先選択リスト
              StorageSelectionTile(
                title: '外部ストレージサーバーに保存',
                value: 'cloud',
                groupValue: storageProvider.selectedStorage,
                onChanged: (String? value) {
                  if (value != null) _onStorageSelected(value);
                },
              ),
              StorageSelectionTile(
                title: 'ローカルサーバーに保存',
                value: 'local_server',
                groupValue: storageProvider.selectedStorage,
                onChanged: (String? value) {
                  if (value != null) _onStorageSelected(value);
                },
              ),
              StorageSelectionTile(
                title: '自分の端末に保存',
                value: 'device',
                groupValue: storageProvider.selectedStorage,
                onChanged: (String? value) {
                  if (value != null) _onStorageSelected(value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('キャンセル'),
            ),
          ],
        );
      },
    );
  }

  Widget StorageSelectionTile({
    required String title,
    required String value,
    required String? groupValue,
    required Function(String?) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      leading: Radio<String>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storageProvider = Provider.of<AppState>(context);
    final serverManager = Provider.of<LocalServerManager>(context);
    final clientManager = Provider.of<LocalClientManager>(context);

    // 保存先に基づくカメラボタンの活性化状態を設定
    bool isCameraButtonEnabled = true;

    // 1. 保存先がローカルサーバーの場合、ローカルサーバに接続していなければ非活性に
    if (storageProvider.selectedStorage == 'local_server' &&
        !clientManager.isConnected) {
      isCameraButtonEnabled = false;
    }

    // 2. 保存先が自分の端末の場合、ローカルサーバに設定していなければ非活性に
    if (storageProvider.selectedStorage == 'device' &&
        !serverManager.isRunning) {
      isCameraButtonEnabled = false;
    }

    return Scaffold(
      appBar: AppBar(title: Text('FanPixSnap')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Center(
          child: _isLoading
              ? CircularProgressIndicator()
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // カメラ起動ボタン（条件に応じて活性/非活性）
              SectionButton(
                onPressed: isCameraButtonEnabled
                    ? _openCamera
                    : null, // ボタンが非活性の場合はnullを渡す
                label: 'カメラを起動',
                icon: Icons.camera_alt,
                enabled: isCameraButtonEnabled,
              ),
              SizedBox(height: 50),
              // 保存先選択ボタン
              SectionButton(
                onPressed: _showStorageSelectionDialog,
                label: '保存先を選択',
                icon: Icons.storage,
              ),
              SizedBox(height: 15),
              // 現在の保存先表示
              Text(
                '現在の保存先: ${storageProvider.selectedStorage == 'cloud' ? '外部ストレージサーバー' : storageProvider.selectedStorage == 'local_server' ? 'ローカルサーバー' : '自分の端末'}',
                style: TextStyle(fontSize: 20),
              ),
              SizedBox(height: 10),
              // ローカルサーバー起動案内
              if (!serverManager.isRunning &&
                  storageProvider.selectedStorage == 'device')
                Text(
                  '「ローカルサーバに設定」から\nローカルサーバを起動してください。',
                  style: TextStyle(fontSize: 15),
                ),
              SizedBox(height: 30),
              // ローカルサーバ設定ボタン（非cloud時）
              if (storageProvider.selectedStorage != 'cloud')
                SectionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LocalServerPage()),
                    );
                  },
                  label: 'ローカルサーバに設定',
                  icon: Icons.settings_remote,
                ),
              SizedBox(height: 30),
              // ローカルサーバ接続ボタン（local_server選択時）
              if (storageProvider.selectedStorage == 'local_server')
                SectionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocalClientPage(
                          onConnected: (String deviceName) {
                            setState(() {
                              _savePreferences();
                            });
                          },
                        ),
                      ),
                    );
                  },
                  label: 'ローカルサーバに接続',
                  icon: Icons.link,
                ),
            ],
          ),
        ),
      ),
    );
  }

// SectionButton ウィジェットに enabled プロパティを追加して、非活性化状態を管理
  Widget SectionButton({
    required VoidCallback? onPressed,
    required String label,
    required IconData icon,
    bool enabled = true,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
        backgroundColor: enabled ? null : Colors.grey,
        textStyle: TextStyle(fontSize: 16), // 非活性時の色を変更
      ),
    );
  }
}
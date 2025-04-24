import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fan_pix_snap/screens/storage_qr_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../services/app_state.dart';
import '../services/supabase_service.dart';
import 'camera_screen.dart';
import 'color_picker_widget.dart';
import 'local_qr_code_screen.dart';

// ペンの種類を設定
enum BrushType {
  normal, // 通常
  crayon, // クレヨン風
  pencil, // 色鉛筆風
  ballpoint, // ボールペン
  watercolor, // 水彩
  chalk, // チョーク
  oil, // 油彩
  fountainPen // 万年筆
}

// 使用中のブラシの種類（初期値は通常ブラシ）
BrushType _selectedBrushType = BrushType.normal;

class ImageEditScreen extends StatefulWidget {
  // 元画像
  final File imageFile;
  // フレーム画像（未定義）
  final File? frameFile;

  const ImageEditScreen({Key? key, required this.imageFile, this.frameFile})
      : super(key: key);

  @override
  _ImageEditScreenState createState() => _ImageEditScreenState();
}

class _ImageEditScreenState extends State<ImageEditScreen> {
  List<TextData> _texts = [];
  List<EmojiData> _emojis = [];
  // 表示順序保持用（描画、絵文字、テキスト）
  List<Widget> _drawOrder = [];

  // ブラシ初期値）
  double _brushSize = 5.0;
  double _opacity = 1.0;
  Color _selectedColor = Colors.red;
  // 絵文字初期値
  String _selectedEmoji = "✨";
  // 状態管理用
  bool _isSaving = false;
  bool uploadSuccess = false;
  String? _accessKey;
  // 表示スケール
  late double scaleX = 1.0;
  late double scaleY = 1.0;
  // 利用可能なフォント一覧
  final List<String> fontList = [
    "Poppins",
    "Lobster",
    "Permanent Marker",
    "Roboto",
    "Hachi Maru Pop"
  ];
  // フォント初期値
  String _selectedFont = "Roboto";
  // 描画データ
  List<DrawingPath> _paths = [];
  Path _currentPath = Path();
  //　実際に表示されている画像のサイズ
  Size? _displayedImageSize;

  @override
  void initState() {
    super.initState();
    // レイヤー順を設定
    _updateDrawOrder();
  }

  // レイヤーの順番を更新
  void _updateDrawOrder() {
    setState(() {
      _drawOrder = [
        // 手書きレイヤー
        Positioned.fill(
          child: CustomPaint(
            painter: ImageEditorPainter(_paths, _emojis, 1.0, 1.0),
          ),
        ),

        // 絵文字
        for (var emoji in _emojis) _buildEmojiWidget(emoji),
        // テキスト
        for (var text in _texts) _buildTextWidget(text),
      ];
    });
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 表示画像サイズの計算
    _calculateDisplayedImageSize();
    // 実際の画像サイズを取得し、スケールを計算
    _getImageSize(widget.imageFile).then((imageSize) {
      final screenWidth = MediaQuery
          .of(context)
          .size
          .width;
      final screenHeight = MediaQuery
          .of(context)
          .size
          .height;

      setState(() {
        scaleX = imageSize.width / screenWidth;
        scaleY = imageSize.height / screenHeight;
      });
    });
  }

  // 実際の画像が画面上にどのように表示されるのか計算する
  void _calculateDisplayedImageSize() async {
    final Uint8List imageBytes = await widget.imageFile.readAsBytes();
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(imageBytes, (ui.Image img) {
      completer.complete(img);
    });
    final ui.Image image = await completer.future;

    final double imageAspectRatio = image.width / image.height;
    final Size screenSize = MediaQuery
        .of(context)
        .size;
    final double screenAspectRatio = screenSize.width / screenSize.height;

    double displayedWidth, displayedHeight;
    if (imageAspectRatio > screenAspectRatio) {
      // 横長画像：横幅に合わせて高さを調整
      displayedWidth = screenSize.width;
      displayedHeight = screenSize.width / imageAspectRatio;
    } else {
      // 縦長画像：縦幅に合わせて横幅を調整
      displayedHeight = screenSize.height;
      displayedWidth = screenSize.height * imageAspectRatio;
    }

    setState(() {
      _displayedImageSize = Size(displayedWidth, displayedHeight);
    });
  }

  // 画像ファイルのサイズ（実寸）を取得
  Future<Size> _getImageSize(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    // バイトから画像をデコード
    final image = await decodeImageFromList(bytes);
    return Size(image.width.toDouble(), image.height.toDouble());
  }

  // 絵文字追加処理
  void _addEmoji(Offset position) {
    setState(() {
      _emojis.add(EmojiData(_selectedEmoji, position));
      _updateDrawOrder();
    });
  }

  // 絵文字ウィジエットを構築
  Widget _buildEmojiWidget(EmojiData emoji) {
    return Positioned(
      left: emoji.position.dx,
      top: emoji.position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            emoji.position += details.delta;
            _updateDrawOrder();
          });
        },
        child: Text(emoji.emoji, style: TextStyle(fontSize: 30)),
      ),
    );
  }

  // テキストウィジエットを構築
  Widget _buildTextWidget(TextData text) {
    return Positioned(
      left: text.position.dx,
      top: text.position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            text.position += details.delta;
            _updateDrawOrder();
          });
        },
        child: Text(
          text.text,
          style: text.getTextStyle(1.0, 1.0),
        ),
      ),
    );
  }

  // キャンバスをクリア（全削除）
  void _clearCanvas() {
    setState(() {
      _paths.clear();
      _texts.clear();
      _emojis.clear();
    });
  }

  // ローカルストレージへ保存
  Future<String> _saveImageToLocalStorage(Uint8List imageBytes) async {
    String filePath = '';
    // Android端末の場合
    if (Platform.isAndroid) {
      filePath = await _saveImageToLocalStorageAndroid(imageBytes);
      // IOS端末の場合
    } else if (Platform.isIOS) {
      filePath = await _saveImageToLocalStorageIOS(imageBytes, context);
    } else {
      throw Exception('未対応のプラットフォームです');
    }
    return filePath;
  }

  // Android: ローカルストレージに保存
  Future<String> _saveImageToLocalStorageAndroid(Uint8List imageBytes) async {
    // 保存先を指定（/storage/emulated/0/ は Android の一般的なローカルストレージパス）
    final storageProvider = Provider.of<AppState>(context, listen: false);
    final Directory directory;
    if (storageProvider.selectedStorage == 'device') {
      directory = Directory('/storage/emulated/0/Pictures/fanpixsnap');
    } else {
      directory = Directory('/storage/emulated/0/Pictures/fanpixsnaperr');
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
    final String filePath =
        '$dirPath/edited_image_${DateTime.now().toLocal()
        .toIso8601String()
        .replaceAll(':', '-')}.jpg';
    final file = File(filePath);
    // 画像ファイルを作成して保存
    try {
      await file.writeAsBytes(imageBytes);
    } catch (e) {
      throw Exception("画像の保存に失敗しました: $e");
    }
    Future.microtask(() {
      Provider.of<CameraScreenState>(context, listen: false)
          .addLog(
          'ローカルストレージに画像が保存されました(Android端末)：$filePath');
    });
    return filePath;
  }

  Future<String> _saveImageToLocalStorageIOS(Uint8List imageBytes,
      BuildContext context) async {
    final String filename =
        'edited_image_${DateTime.now().toLocal().toIso8601String().replaceAll(
        ':', '-')}.jpg';
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
    // フォルダを作成
    await Directory(folderPath).create(recursive: true);

    String filePath = '$folderPath/$filename';

    // 画像をローカルストレージに保存
    final File imageFile = File(filePath);
    await imageFile.writeAsBytes(imageBytes);

    Provider.of<CameraScreenState>(context, listen: false)
        .addLog('ローカルストレージに画像が保存されました（iOS）：$filePath');

    // 保存されたファイルのパスを返す
    return filePath;
  }

  Future<File> _resizeImage(File file) async {
    final bytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return file;
    // 幅800pxにリサイズ
    img.Image resized = img.copyResize(image, width: 800);
    // JPEG圧縮率85%
    final resizedFile = File(file.path)
      ..writeAsBytesSync(img.encodeJpg(resized, quality: 85));

    // リサイズ後のファイルを返す
    return resizedFile;
  }

  Future<void> _saveEditedImage(Uint8List editedImageData) async {
    setState(() {
      _isSaving = true;
    });

    try {
      String localUrl;
      final storageProvider = Provider.of<AppState>(context, listen: false);
      // 保存先が外部ストレージサーバ
      if (storageProvider.selectedStorage == 'cloud') {
        // オンラインの場合
        if (await _isOnline()) {
          // デバイスの一時保存先パスを取得し、一時ディレクトリに画像を保存
          final directory = await getTemporaryDirectory();
          final fileName =
              'edited_image_${DateTime.now().toLocal()
              .toIso8601String()
              .replaceAll(':', '-')}.jpg';
          final editedImagePath = '${directory.path}/$fileName';
          final File editedImageFile = File(editedImagePath);
          await editedImageFile.writeAsBytes(editedImageData);

          File resizedImageFile = await _resizeImage(editedImageFile);

          uploadSuccess = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  StorageQRCodeScreen(
                      imageFuture: SupabaseService.uploadImage(
                          resizedImageFile)),
            ),
          );
          Future.microtask(() {
            Provider.of<CameraScreenState>(context, listen: false)
                .addLog(
                '外部ストレージサーバに画像を保存しました：$resizedImageFile');
          });

          if (!uploadSuccess) {
            // アップロード処理に失敗した場合（アップロード先のURLがEmpty）
            localUrl =
                await _saveImageToLocalStorage(editedImageData) ??
                    "ローカル保存失敗";
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  content: Text(
                      '外部ストレージサーバーへの保存に失敗しました。ローカルに保存しました：$localUrl'),
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
                  .addLog(
                  'ローカルサーバーへの保存失敗。ローカルに保存：$localUrl');
            });
          }
        } else {
          // オフライン状態の場合はローカルに保存
          localUrl =
              await _saveImageToLocalStorage(editedImageData) ??
                  "ローカル保存失敗";
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                content: Text(
                    '現在オフラインです。ローカルに保存しました：$localUrl'),
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
        localUrl =
            await _saveImageToLocalStorage(editedImageData) ??
                "ローカル保存失敗";
        if (localUrl.isNotEmpty) {
          Future.microtask(() {
            Provider.of<CameraScreenState>(context, listen: false)
                .addLog('自端末に保存：$localUrl');
          });
          final appState = Provider.of<AppState>(context, listen: false);
          final timestamp = DateTime
              .now()
              .toLocal()
              .millisecondsSinceEpoch;
          final expirationTime = 5 * 60 * 1000;
          _accessKey = localUrl;
          final serverUrl = _accessKey != null
              ? 'http://${appState.localIpAddress}:${appState
              .port}?file=$_accessKey&timestamp=$timestamp&expiresIn=$expirationTime'
              : '';

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  LocalQRCodeDisplayScreen(
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
      setState(() {
        _isSaving = false;
      });
    } catch (e) {
      // ファイルの保存やアップデートに失敗した場合
      if (uploadSuccess == false) {
        Future.microtask(() {
          Provider.of<CameraScreenState>(context, listen: false)
              .addLog('ファイルの保存に失敗: $e');
        });
      }
    } finally {}
  }

  // ローカルサーバーに画像を送信
  Future<String> _sendImageToLocalServer(Uint8List editedImageData) async {
    String localUrl;
    try {
      final ipAddress = Provider
          .of<AppState>(context, listen: false)
          .ipAddress;
      final port = Provider
          .of<AppState>(context, listen: false)
          .port;
      final Uri uri = Uri.parse('http://$ipAddress:$port/upload');

      // 送信中のメッセージを更新
      Future.microtask(() {
        Provider.of<CameraScreenState>(context, listen: false)
            .addLog("画像送信中...");
      });

      // 画像を送信するためのHTTP POSTリクエスト
      final response = await http
          .post(
        uri,
        headers: {
          // バイナリデータとして送信
          'Content-Type': 'application/octet-stream',
        },
        // 画像のバイトデータをリクエストボディに追加
        body: editedImageData,
      )
          // タイムアウトを設定
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        // 成功メッセージを表示
        Future.microtask(() {
          Provider.of<CameraScreenState>(context, listen: false)
              .addLog('画像がサーバーに送信されました');
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
              content: Text(
                  '画像送信中にエラーが発生しました。ローカルに保存しました：$localUrl'),
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
            content: Text(
                '画像送信中にエラーが発生しました。ローカルに保存しました：$localUrl'),
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
      print('画像送信中にエラーが発生しました: $e');
      return '画像送信中にエラーが発生しました: $e';
    }
  }

  void _resetSelection() {
    if (mounted) {
      setState(() {
        _accessKey = null;
      });
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => MainScreen()),
            (Route<dynamic> route) => false,
      );
    }
  }

  // オフライン状態を確認する
  Future<bool> _isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      bool isConnected =
          connectivityResult.toString() == "[ConnectivityResult.mobile]" ||
              connectivityResult.toString() == "[ConnectivityResult.wifi]";
      Future.microtask(() {
        Provider.of<CameraScreenState>(context, listen: false)
            .addLog(
            isConnected ? 'ネットワークオンライン' : 'ネットワークオフライン');
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

  // 編集後の画像を合成して取得
  Future<ui.Image> _captureEditedImage() async {
    final recorder = ui.PictureRecorder();
    final ui.Image backgroundImage = await _loadUiImage(widget.imageFile);
    final Size imageSize = Size(
        backgroundImage.width.toDouble(), backgroundImage.height.toDouble());

    // 表示されている画像のサイズを取得
    final Size displayedImageSize = await _getDisplayedImageSize();

    // スケール計算（表示⇒実画像へのスケール変換）
    final double scaleX = imageSize.width / displayedImageSize.width;
    final double scaleY = imageSize.height / displayedImageSize.height;

    // 表示エリアのオフセットを計算
    final double offsetX =
        (MediaQuery
            .of(context)
            .size
            .width - displayedImageSize.width) / 2;
    final double offsetY = await _getImageTopOffset();

    final Canvas canvas = Canvas(
      recorder,
      Rect.fromPoints(Offset(0, 0), Offset(imageSize.width, imageSize.height)),
    );

    // 背景画像の描画
    canvas.drawImage(backgroundImage, Offset.zero, Paint());

    // テキストの描画
    for (var text in _texts) {
      final double scaledX = (text.position.dx - offsetX) * scaleX;
      final double scaledY = (text.position.dy - offsetY) * scaleY;

      TextSpan span = TextSpan(
        style: text.getTextStyle(scaleX, scaleY),
        text: text.text,
      );
      TextPainter tp =
      TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(scaledX, scaledY));
    }

    // 絵文字の描画
    for (var emoji in _emojis) {
      final double scaledX = (emoji.position.dx - offsetX) * scaleX;
      final double scaledY = (emoji.position.dy - offsetY) * scaleY;

      TextSpan span =
      TextSpan(text: emoji.emoji, style: TextStyle(fontSize: 30 * scaleX));
      TextPainter tp =
      TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(scaledX, scaledY));
    }

    // 手書きの描画
    canvas.save();
    // スケールを適用
    canvas.scale(scaleX, scaleY);
    canvas.translate(-offsetX, -offsetY);
    for (var pathData in _paths) {
      Paint paint = Paint()
        ..color = pathData.color.withOpacity(pathData.opacity)
        ..strokeWidth = pathData.size
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // ブラシの質感を適用
      switch (pathData.brushType) {
        case BrushType.crayon:
          paint.blendMode = BlendMode.multiply;
          paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 2);
          break;
        case BrushType.pencil:
          paint.blendMode = BlendMode.srcOver;
          paint.maskFilter = MaskFilter.blur(BlurStyle.inner, 2);
          break;
        case BrushType.watercolor:
          paint.blendMode = BlendMode.multiply;
          paint.maskFilter = MaskFilter.blur(BlurStyle.outer, 3);
          break;
        case BrushType.chalk:
          paint.blendMode = BlendMode.srcOver;
          paint.maskFilter = MaskFilter.blur(BlurStyle.solid, 3);
          break;
        case BrushType.oil:
          paint.blendMode = BlendMode.hardLight;
          paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 1);
          break;
        default:
          paint.blendMode = BlendMode.srcOver;
          paint.maskFilter = null;
          break;
      }

      // スケール済みの Path をそのまま描画
      canvas.drawPath(pathData.path, paint);
    }
    // スケールを元に戻す
    canvas.restore();

    final picture = recorder.endRecording();
    return await picture.toImage(
        imageSize.width.toInt(), imageSize.height.toInt());
  }

  // 表示画像のサイズを取得
  Future<Size> _getDisplayedImageSize() async {
    final Uint8List imageBytes = await widget.imageFile.readAsBytes();
    final Completer<ui.Image> completer = Completer();

    ui.decodeImageFromList(imageBytes, (ui.Image img) {
      completer.complete(img);
    });

    final ui.Image image = await completer.future;
    final double imageAspectRatio = image.width / image.height;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Size screenSize = renderBox.size;
    final double screenAspectRatio = screenSize.width / screenSize.height;

    double displayedWidth;
    double displayedHeight;

    if (imageAspectRatio > screenAspectRatio) {
      // 画像の横幅が画面より大きい場合
      displayedWidth = screenSize.width;
      displayedHeight = screenSize.width / imageAspectRatio;
    } else {
      // 画像の縦幅が画面より大きい場合
      displayedHeight = screenSize.height;
      displayedWidth = screenSize.height * imageAspectRatio;
    }

    return Size(displayedWidth, displayedHeight);
  }

  // 画像の縦位置のオフセットを取得
  double _getImageTopOffset() {
    if (_displayedImageSize == null) return 0.0;
    final Size screenSize = MediaQuery
        .of(context)
        .size;
    double offsetY = (screenSize.height - _displayedImageSize!.height) / 2;
    return offsetY - 43.0;
  }

  // ファイルからui.Imageを読み込み
  Future<ui.Image> _loadUiImage(File file) async {
    final Uint8List data = await file.readAsBytes();
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(data, (ui.Image img) {
      completer.complete(img);
    });
    return completer.future;
  }

  // テキスト入力用のダイアログ表示（フォント選択付き）
  void _showTextInputDialog() {
    TextEditingController _textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // モーダル内で状態変更可能とする
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text("テキストを追加"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // テキスト入力
                  TextField(
                      controller: _textController,
                      decoration: InputDecoration(labelText: "テキストを入力")),
                  SizedBox(height: 10),

                  // フォント選択ドロップダウン
                  DropdownButton<String>(
                    value: _selectedFont,
                    onChanged: (String? newFont) {
                      setModalState(() {
                        _selectedFont = newFont!;
                      });
                      setState(() {
                        _selectedFont = newFont!;
                      });
                    },
                    items: fontList.map((font) {
                      return DropdownMenuItem<String>(
                        value: font,
                        child: Text(font, style: GoogleFonts.getFont(font)),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("キャンセル")),
                TextButton(
                  onPressed: () async {
                    if (_textController.text.isNotEmpty) {
                      // 画面と画像サイズを取得
                      final Size screenSize = MediaQuery
                          .of(context)
                          .size;
                      final Size displayedImageSize = await _getDisplayedImageSize();
                      final double offsetX =
                          (screenSize.width - displayedImageSize.width) / 2;
                      final double offsetY = await _getImageTopOffset();

                      // 画像の左上から少し内側に配置
                      Offset initialPosition =
                      Offset(offsetX + 20, offsetY + 20);
                      setState(() {
                        _texts.add(TextData(_textController.text,
                            initialPosition, _selectedFont, _selectedColor));
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: Text("追加"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 最後の操作を元に戻す
  void _undoLastAction() {
    setState(() {
      if (_paths.isNotEmpty) {
        _paths.removeLast();
      } else if (_texts.isNotEmpty) {
        _texts.removeLast();
      } else if (_emojis.isNotEmpty) {
        _emojis.removeLast();
      }
    });
  }

  void _showBrushSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              color: Colors.transparent,
              padding: EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("ペンの種類"),
                  DropdownButton<BrushType>(
                    value: _selectedBrushType,
                    onChanged: (BrushType? newType) {
                      setModalState(() {
                        _selectedBrushType = newType!;
                      });
                    },
                    // ペンの種類を設定
                    items: [
                      DropdownMenuItem(
                          value: BrushType.normal, child: Text("通常")),
                      DropdownMenuItem(
                          value: BrushType.crayon, child: Text("クレヨン風")),
                      DropdownMenuItem(
                          value: BrushType.pencil, child: Text("色鉛筆風")),
                      DropdownMenuItem(
                          value: BrushType.ballpoint,
                          child: Text("ボールペン風")),
                      DropdownMenuItem(
                          value: BrushType.watercolor, child: Text("水彩風")),
                      DropdownMenuItem(
                          value: BrushType.chalk, child: Text("チョーク風")),
                      DropdownMenuItem(
                          value: BrushType.oil, child: Text("油彩風")),
                      DropdownMenuItem(
                          value: BrushType.fountainPen,
                          child: Text("万年筆風")),
                    ],
                  ),
                  Text("ペンの太さ"),
                  Slider(
                    value: _brushSize,
                    min: 1.0,
                    max: 20.0,
                    label: _brushSize.round().toString(),
                    onChanged: (value) {
                      setModalState(() {
                        _brushSize = value;
                      });
                    },
                  ),
                  Text("透明度"),
                  Slider(
                    value: _opacity,
                    min: 0.1,
                    max: 1.0,
                    label: _opacity.toStringAsFixed(1),
                    onChanged: (value) {
                      setModalState(() {
                        _opacity = value;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var color in [
                        Colors.red,
                        Colors.green,
                        Colors.blue,
                        Colors.yellow
                      ])
                        GestureDetector(
                          onTap: () =>
                              setModalState(() => _selectedColor = color),
                          child: Container(
                            width: 30,
                            height: 30,
                            margin: EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              // 選択中の色を分かりやすく
                              border: Border.all(
                                color: _selectedColor == color
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: 10),

                      // カラーピッカーボタン
                      ColorPickerWidget(
                        onColorSelected: (color) {
                          setModalState(() {
                            _selectedColor = color;
                          });
                          setState(() {
                            _selectedColor = color;
                          });
                        },
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      // 現在の選択色を表示
                      Text("選択中の色"),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _selectedColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("閉じる"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("絵文字を選択", style: TextStyle(fontSize: 18)),
              Wrap(
                spacing: 10,
                children: ["✨", "💖", "🎉", "🌟", "🔥", "😊", "👍", "🎶"]
                    .map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedEmoji = emoji;
                      });
                      Navigator.pop(context);
                    },
                    child: Text(emoji, style: TextStyle(fontSize: 30)),
                  );
                }).toList(),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text("閉じる"),
              ),
            ],
          ),
        );
      },
    );
  }

  // 指定位置が画像内かを判定
  bool _isWithinImageBounds(Offset position, {double extraHeight = 0}) {
    if (_displayedImageSize == null) return false;
    final Size screenSize = MediaQuery
        .of(context)
        .size;
    final double offsetX = (screenSize.width - _displayedImageSize!.width) / 2;
    final double offsetY = _getImageTopOffset();
    return position.dx >= offsetX &&
        position.dx <= offsetX + _displayedImageSize!.width &&
        position.dy >= offsetY &&
        position.dy + extraHeight <= offsetY + _displayedImageSize!.height;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("画像編集"),
        actions: [
          // ペン設定
          IconButton(
              icon: Icon(Icons.brush),
              onPressed: _showBrushSettings),
          // テキスト追加
          IconButton(
              icon: Icon(Icons.text_fields),
              onPressed: _showTextInputDialog),
          // 絵文字ピッカーを表示
          IconButton(
            icon: Text(_selectedEmoji, style: TextStyle(fontSize: 24)),
            onPressed: _showEmojiPicker,
          ),
          // 1つ前に戻る
          IconButton(
              icon: Icon(Icons.undo), onPressed: _undoLastAction),
          // 全削除
          IconButton(
              icon: Icon(Icons.delete), onPressed: _clearCanvas),
          // 保存
          IconButton(
              icon: Icon(Icons.save),
              onPressed: () async {
                final ui.Image image = await _captureEditedImage();
                final ByteData? byteData =
                    await image.toByteData(format: ui.ImageByteFormat.png);
                if (byteData != null) {
                  final Uint8List editedImageData =
                      byteData.buffer.asUint8List();
                  await _saveEditedImage(editedImageData);
                }
              }),
        ],
      ),
      body: Stack(
        children: [
          // 背景画像
          Positioned.fill(
            child: Image.file(widget.imageFile, fit: BoxFit.contain),
          ),

          // フレーム画像（未定義）
          if (widget.frameFile != null)
            Positioned.fill(
              child: Image.file(widget.frameFile!, fit: BoxFit.contain),
            ),

          // 手書き描画処理
          GestureDetector(
            onPanStart: (details) {
              final Offset localPosition = details.localPosition;
              if (_isWithinImageBounds(localPosition)) {
                setState(() {
                  _currentPath = Path()
                    ..moveTo(localPosition.dx, localPosition.dy);
                  _paths.add(DrawingPath(_currentPath, _selectedColor,
                      _brushSize, _opacity, _selectedBrushType));
                });
              }
            },
            onPanUpdate: (details) {
              final Offset localPosition = details.localPosition;
              if (_isWithinImageBounds(localPosition)) {
                setState(() {
                  _currentPath.lineTo(localPosition.dx, localPosition.dy);
                });
              }
            },
            onPanEnd: (details) {
              // 新しい線のためのパスをリセット
              setState(() {
                _currentPath = Path();
              });
            },
            onTapUp: (details) {
              final Offset localPosition = details.localPosition;
              final double emojiSize = 30;
              if (_isWithinImageBounds(localPosition, extraHeight: emojiSize)) {
                _addEmoji(localPosition);
              }
            },
            child: CustomPaint(
              // 画像加工時点では、scaleX, scaleYを適用しない。（書き位置がずれるため）
              painter: ImageEditorPainter(_paths, _emojis, 1.0, 1.0),
              size: Size.infinite,
            ),
          ),
          // 絵文字の移動処理
          for (int i = 0; i < _emojis.length; i++)
            Positioned(
              left: _emojis[i].position.dx,
              top: _emojis[i].position.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    Offset newPos = _emojis[i].position + Offset(details.delta.dx, details.delta.dy);
                    if (_isWithinImageBounds(newPos, extraHeight: 30)) {
                      _emojis[i].position = newPos;
                    }
                  });
                },
                child: Text(
                  _emojis[i].emoji,
                  style: TextStyle(fontSize: 30),
                ),
              ),
            ),
          // テキストの移動処理
          for (int i = 0; i < _texts.length; i++)
            Positioned(
              left: _texts[i].position.dx,
              top: _texts[i].position.dy,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _texts[i].isSelected = !_texts[i].isSelected;
                  });
                },
                onPanUpdate: (details) {
                  double textHeight = 40;
                  setState(() {
                    Offset newPos = _texts[i].position +
                        Offset(details.delta.dx, details.delta.dy);
                    if (_isWithinImageBounds(newPos, extraHeight: textHeight)) {
                      _texts[i].position = newPos;
                    }
                  });
                },
                child: Text(
                  _texts[i].text,
                  style: _texts[i].getTextStyle(1.0, 1.0),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 手書きデータ
class DrawingPoint {
  Offset position;
  Color color;
  double size;
  double opacity;
  BrushType brushType;
  DrawingPoint(
      this.position, this.color, this.size, this.opacity, this.brushType);
}

// 手書きのPathデータ
class DrawingPath {
  Path path;
  Color color;
  double size;
  double opacity;
  BrushType brushType;

  DrawingPath(this.path, this.color, this.size, this.opacity, this.brushType);
}

// テキストデータ
class TextData {
  String text;
  Offset position;
  String font;
  Color color;
  bool isSelected;

  TextData(this.text, this.position, this.font, this.color,
      {this.isSelected = false});

  TextStyle getTextStyle(double aspectRatioX, double aspectRatioY) {
    // 画像の縦横比で調整
    double scaledFontSize =
        30 * ((aspectRatioX + aspectRatioY) / 2);
    return GoogleFonts.getFont(this.font,
        color: this.color, fontSize: scaledFontSize);
  }
}

// 絵文字データ
class EmojiData {
  String emoji;
  Offset position;
  EmojiData(this.emoji, this.position);
}

// CustomPainter で手書き描画処理
class ImageEditorPainter extends CustomPainter {
  List<DrawingPath> paths;
  List<EmojiData> emojis;
  final double scaleX, scaleY;

  ImageEditorPainter(this.paths, this.emojis, this.scaleX, this.scaleY);

  @override
  void paint(Canvas canvas, Size size) {
    if (paths.isEmpty) return;
    for (var pathData in paths) {
      Paint paint = Paint()
        ..color = pathData.color.withOpacity(pathData.opacity)
        ..strokeWidth = pathData.size * scaleX
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      //　ブラシの種類ごとに質感を適用
      switch (pathData.brushType) {
        case BrushType.crayon:
          paint.blendMode = BlendMode.multiply;
          paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 2);
          break;
        case BrushType.pencil:
          paint.blendMode = BlendMode.srcOver;
          paint.maskFilter = MaskFilter.blur(BlurStyle.inner, 2);
          break;
        case BrushType.ballpoint:
          paint.blendMode = BlendMode.srcOver;
          break;
        case BrushType.watercolor:
          paint.blendMode = BlendMode.multiply;
          paint.maskFilter = MaskFilter.blur(BlurStyle.outer, 3);
          break;
        case BrushType.chalk:
          paint.blendMode = BlendMode.srcOver;
          paint.maskFilter = MaskFilter.blur(BlurStyle.solid, 3);
          break;
        case BrushType.oil:
          paint.blendMode = BlendMode.hardLight;
          paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 1);
          break;
        case BrushType.fountainPen:
          paint.blendMode = BlendMode.srcOver;
          paint.strokeCap = StrokeCap.square;
          break;
        case BrushType.normal:
        default:
          paint.blendMode = BlendMode.srcOver;
          paint.maskFilter = null;
          break;
      }
      // Path を描画
      canvas.drawPath(pathData.path, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class FirebaseService {
  // 受け取った画像をFirebaseStorageに格納する
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Future<String> uploadImage(File image) async {
    // Storageに保存できたら格納先Urlを返す
    try {
      // 画像ファイル名の生成。現在の日時をミリ単位で取得しファイル名とすることで同一名のファイルが生成されるのを防ぐ
      // String fileName = 'edited_image_' + DateTime.now().millisecondsSinceEpoch.toString() + '.jpg';
      String fileName = 'edited_image_${DateTime.now().toLocal().toIso8601String().replaceAll(':', '-')}_image.jpg';
      // FirebaseStorageのルートを参照
      Reference storageReference = FirebaseStorage.instance.ref().child('images/$fileName');
      // 指定した画像のアップロード
      SettableMetadata metadata = SettableMetadata(contentType: 'image/jpeg');

      print("Uploading with contentType: ${metadata.contentType}");

      //UploadTask uploadTask = storageReference.putFile(image , SettableMetadata(contentType: 'image/jpeg',
      //   customMetadata: {'contentType': 'image/jpeg'}));
      UploadTask uploadTask = storageReference.putData(await image.readAsBytes(), SettableMetadata(contentType: 'image/jpeg',
          customMetadata: {'contentType': 'image/jpeg'}));

      // アップロード処理が完了するのを待つ。
      TaskSnapshot taskSnapshot = await uploadTask;
      // アップロードが完了したらtaskSnapshotからアップロードしたファイルのダウンロードURLを取得
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      //一時帝にコメントアウト（サーバの画像自動削除には必要）
      // final uploadTime = DateTime.now().toLocal();
      // await FirebaseFirestore.instance.collection('images').add({
      //   'url': downloadUrl,
      //   'uploadTime': uploadTime.toIso8601String(),
      // });
      return downloadUrl;
    } catch(e) {
      // アップロード処理に失敗した場合
      print('Error uploading image $e');
      return '';
    }
  }
}
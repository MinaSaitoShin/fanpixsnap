import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient supabase = Supabase.instance.client;

  // 画像をSupabaseのストレージにアップロードし、URLを取得する
  static Future<String> uploadImage(File image) async {
    try {
      // 画像ファイル名の生成
      String fileName =
          'edited_image_${DateTime.now().toLocal().toIso8601String().replaceAll(':', '-')}_image.jpg';

      // バケット名（SupabaseのStorageに作成するバケットの名前）
      const String bucketName = 'images';

      // Supabase Storageへアップロード
      await supabase.storage.from(bucketName).upload(
        fileName,
        image,
        fileOptions: const FileOptions(
          upsert: true, // 既存ファイルを上書きする場合はtrue
        ),
      );

      // 公開URLを取得
      String downloadUrl = supabase.storage.from(bucketName).getPublicUrl(fileName);

      // 現在のユーザーID（AuthのUID）を取得
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        print("ユーザーIDが取得できません");
        return '';
      }

      // データベースに記録（ユーザーIDを追加）
      await supabase.from('files').insert({
        'file_name': fileName,
        'url': downloadUrl,
        'created_at': DateTime.now().toIso8601String(),
        'user_id': userId,
      });

      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return '';
    }
  }
}

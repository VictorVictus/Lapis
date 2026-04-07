import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/sync_provider.dart';

final userServiceProvider = Provider((ref) => UserService(ref));

class UserService {
  final Ref _ref;
  UserService(this._ref);

  Future<void> _runWithSyncStatus(Future<void> Function() action) async {
    _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.syncing);
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('Offline: Connect to use the internet.');
      }

      await action().timeout(
        const Duration(seconds: 15), // Profile pics might need longer
        onTimeout: () => throw TimeoutException('Upload timeout: Connection too slow.'),
      );
      
      _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.idle);
      _ref.read(showSuccessIndicatorProvider.notifier).setVisible(true);
      Future.delayed(const Duration(seconds: 3), () {
        _ref.read(showSuccessIndicatorProvider.notifier).setVisible(false);
      });
    } catch (e) {
      _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.error);
      _ref.read(lastSyncErrorProvider.notifier).setError(e.toString());
      rethrow;
    }
  }

  Future<String?> pickAndUploadImage(String userId) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );

    if (image == null) return null;

    String? downloadUrl;
    await _runWithSyncStatus(() async {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('$userId.jpg');

      final bytes = await image.readAsBytes();
      await storageRef.putData(bytes);
      downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'profilePictureUrl': downloadUrl});
    });

    return downloadUrl;
  }
}

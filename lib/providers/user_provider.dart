import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/user.dart';

import 'package:to_do_app/services/user_service.dart';

final userStreamProvider = StreamProvider.family<User?, String>((ref, userId) {
  return ref.read(userServiceProvider).getUserStream(userId);
});

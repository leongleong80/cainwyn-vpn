import 'package:hiddify/features/profile/data/profile_data_mapper.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';

part 'active_profile_notifier.g.dart';

@Riverpod(keepAlive: true)
class ActiveProfile extends _$ActiveProfile with AppLogger {
  @override
  Stream<ProfileEntity?> build() {
    loggy.debug("watching active profile");
    // CainWyn Auto-add: 如果没有节点，自动添加你的专属订阅
    Future.microtask(() async {
      final count = await ref.read(profileDataSourceProvider).watchProfilesCount().first;
      if (count == 0) {
        ref.read(addProfileNotifierProvider.notifier).addCainWyn();
      }
    });
    return ref.watch(profileDataSourceProvider).watchActiveProfile().map((event) => event?.toEntity());
  }
}

// TODO: move to specific feature
@Riverpod(keepAlive: true)
Stream<bool> hasAnyProfile(Ref ref) {
  return ref.watch(profileDataSourceProvider).watchProfilesCount().map((event) => event != 0).distinct();
}
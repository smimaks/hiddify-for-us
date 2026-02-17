import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/config_option/data/config_option_repository.dart';
import 'package:hiddify/features/connection/data/connection_data_providers.dart';
import 'package:hiddify/features/connection/data/connection_repository.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:fpdart/src/unit.dart';
import 'package:rxdart/rxdart.dart';

part 'connection_notifier.g.dart';

@Riverpod(keepAlive: true)
class ConnectionNotifier extends _$ConnectionNotifier with AppLogger {
  @override
  Stream<ConnectionStatus> build() async* {
    ref.listenSelf(
      (previous, next) async {
        if (previous == next) return;
        if (previous case AsyncData(:final value) when !value.isConnected) {
          if (next case AsyncData(value: final Connected _)) {
            await ref.read(hapticServiceProvider.notifier).heavyImpact();

            if (Platform.isAndroid && !ref.read(Preferences.storeReviewedByUser)) {
              if (await InAppReview.instance.isAvailable()) {
                InAppReview.instance.requestReview();
                ref.read(Preferences.storeReviewedByUser.notifier).update(true);
              }
            }
          }
        }
      },
    );

    ref.listen(
      activeProfileProvider.select((value) => value.asData?.value),
      (previous, next) async {
        if (previous == null) return;
        final shouldReconnect = next == null || previous.id != next.id;
        if (shouldReconnect) {
          await reconnect(next);
        }
      },
    );
    yield* _connectionRepo.watchConnectionStatus().doOnData((event) {
      if (event case Disconnected(connectionFailure: final _?)) {
        if (PlatformUtils.isDesktop) {
          ref.read(Preferences.startedByUser.notifier).update(false);
        }
      }
      if (event case Disconnected()) {
        if (PlatformUtils.isDesktop) {
          final hadSystemProxy = ref.read(connectionRepositoryProvider).configOptionsSnapshot?.setSystemProxy ?? false;
          if (hadSystemProxy) {
            const unsetCmd = 'unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy';
            Clipboard.setData(const ClipboardData(text: unsetCmd));
            ref.read(inAppNotificationControllerProvider).showInfoToast(
              ref.read(translationsProvider).connection.proxyClearedTerminalHint,
              duration: const Duration(seconds: 6),
            );
          }
        }
      }
      loggy.info("connection status: ${event.format()}");
    });
  }

  ConnectionRepository get _connectionRepo => ref.read(connectionRepositoryProvider);

  Future<void> mayConnect() async {
    if (state case AsyncData(:final value)) {
      if (value case Disconnected()) return _connect();
    }
  }

  Future<void> toggleConnection() async {
    final haptic = ref.read(hapticServiceProvider.notifier);
    if (state case AsyncError()) {
      await haptic.lightImpact();
      await _connect();
    } else if (state case AsyncData(:final value)) {
      switch (value) {
        case Disconnected():
          await haptic.lightImpact();
          await ref.read(Preferences.startedByUser.notifier).update(true);
          await _connect();
        case Connected():
          await haptic.mediumImpact();
          await ref.read(Preferences.startedByUser.notifier).update(false);
          await _disconnect();
        default:
          loggy.warning("switching status, debounce");
      }
    }
  }

  Future<void> reconnect(ProfileEntity? profile) async {
    if (state case AsyncData(:final value) when value == const Connected()) {
      if (profile == null) {
        loggy.info("no active profile, disconnecting");
        return _disconnect();
      }
      loggy.info("active profile changed, reconnecting");
      await ref.read(Preferences.startedByUser.notifier).update(true);
      await _connectionRepo
          .reconnect(
        profile.id,
        profile.name,
        ref.read(Preferences.disableMemoryLimit),
        profile.testUrl,
      )
          .mapLeft((err) {
        loggy.warning("error reconnecting", err);
        state = AsyncError(err, StackTrace.current);
      }).run();
    }
  }

  Future<void> abortConnection() async {
    if (state case AsyncData(:final value)) {
      switch (value) {
        case Connected() || Connecting():
          loggy.debug("aborting connection");
          await _disconnect();
        default:
      }
    }
  }

  Future<void> _connect() async {
    final activeProfile = await ref.read(activeProfileProvider.future);
    if (activeProfile == null) {
      loggy.info("no active profile, not connecting");
      return;
    }
    await _connectionRepo
        .connect(
      activeProfile.id,
      activeProfile.name,
      ref.read(Preferences.disableMemoryLimit),
      activeProfile.testUrl,
    )
        .mapLeft((err) async {
      loggy.warning("error connecting", err);
      //Go err is not normal object to see the go errors are string and need to be dumped
      loggy.warning(err);
      await ref.read(Preferences.startedByUser.notifier).update(false);
      state = AsyncError(err, StackTrace.current);
    }).run();
  }

  Future<void> _disconnect() async {
    await _connectionRepo.disconnect().mapLeft((err) {
      loggy.warning("error disconnecting", err);
      state = AsyncError(err, StackTrace.current);
    }).run();
  }
}

@Riverpod(keepAlive: true)
Future<bool> serviceRunning(ServiceRunningRef ref) => ref
    .watch(
      connectionNotifierProvider.selectAsync((data) => data.isConnected),
    )
    .onError((error, stackTrace) => false);

@Riverpod(keepAlive: true)
class PeriodicUrlTest extends _$PeriodicUrlTest with AppLogger {
  @override
  bool build() {
    Timer? timer;
    ref.listen(connectionNotifierProvider, (prev, next) {
      next.whenOrNull(
        data: (status) {
          if (status.isConnected) {
            timer?.cancel();
            final interval = ref.read(ConfigOptions.urlTestInterval);
            Future.delayed(const Duration(seconds: 2), () {
              if (!ref.exists(connectionNotifierProvider)) return;
              ref.read(connectionNotifierProvider).whenOrNull(
                data: (s) {
                  if (s.isConnected) {
                    ref.read(proxyRepositoryProvider).urlTest("auto").getOrElse((_) => unit).run();
                  }
                },
              );
            });
            timer = Timer.periodic(interval, (_) {
              ref.read(proxyRepositoryProvider).urlTest("auto").getOrElse((err) {
                loggy.debug("periodic urlTest", err);
                return unit;
              }).run();
            });
          } else {
            timer?.cancel();
            timer = null;
          }
        },
      );
    });
    ref.onDispose(() => timer?.cancel());
    return true;
  }
}

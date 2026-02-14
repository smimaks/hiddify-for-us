import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:hiddify/core/utils/ffi_utils.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:posix/posix.dart';
import 'package:win32/win32.dart';

abstract interface class ConnectionPlatformSource {
  Future<bool> checkPrivilege();
  Future<void> clearSystemProxy();
}

class ConnectionPlatformSourceImpl
    with InfraLogger
    implements ConnectionPlatformSource {
  @override
  Future<bool> checkPrivilege() async {
    try {
      if (Platform.isWindows) {
        bool isElevated = false;
        withMemory<void, Uint32>(sizeOf<Uint32>(), (phToken) {
          withMemory<void, Uint32>(sizeOf<Uint32>(), (pReturnedSize) {
            withMemory<void, _TokenElevation>(sizeOf<_TokenElevation>(),
                (pElevation) {
              if (OpenProcessToken(
                    GetCurrentProcess(),
                    TOKEN_QUERY,
                    phToken.cast(),
                  ) ==
                  1) {
                if (GetTokenInformation(
                      phToken.value,
                      TOKEN_INFORMATION_CLASS.TokenElevation,
                      pElevation,
                      sizeOf<_TokenElevation>(),
                      pReturnedSize,
                    ) ==
                    1) {
                  isElevated = pElevation.ref.tokenIsElevated != 0;
                }
              }
              if (phToken.value != 0) {
                CloseHandle(phToken.value);
              }
            });
          });
        });
        return isElevated;
      } else if (Platform.isLinux || Platform.isMacOS) {
        final euid = geteuid();
        return euid == 0;
      } else {
        return true;
      }
    } catch (e) {
      loggy.warning("error checking privilege", e);
      return true;
    }
  }

  @override
  Future<void> clearSystemProxy() async {
    try {
      if (Platform.isLinux) {
        const cmds = [
          ['set', 'org.gnome.system.proxy', 'mode', 'none'],
          ['set', 'org.gnome.system.proxy.http', 'host', ''],
          ['set', 'org.gnome.system.proxy.http', 'port', '0'],
          ['set', 'org.gnome.system.proxy.https', 'host', ''],
          ['set', 'org.gnome.system.proxy.https', 'port', '0'],
        ];
        for (final args in cmds) {
          final r = await Process.run('gsettings', args, runInShell: true);
          if (r.exitCode != 0) {
            loggy.debug("gsettings ${args.join(' ')}: ${r.stderr}");
          }
        }
        loggy.info("system proxy cleared. If curl in terminal still uses proxy, run: unset http_proxy https_proxy all_proxy");
      }
    } catch (e) {
      loggy.warning("clearSystemProxy", e);
    }
  }
}

sealed class _TokenElevation extends Struct {
  /// A nonzero value if the token has elevated privileges;
  /// otherwise, a zero value.
  @Int32()
  external int tokenIsElevated;
}

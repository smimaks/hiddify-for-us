import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sliver_tools/sliver_tools.dart';

class IntroPage extends HookConsumerWidget {
  IntroPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final isStarting = useState(false);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          shrinkWrap: true,
          slivers: [
            const SliverGap(32),
            SliverToBoxAdapter(
              child: Center(
                child: Image.asset(
                  'assets/images/Stalin.png',
                  height: 160,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SliverGap(24),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Добро пожаловать',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SliverGap(16),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Для Своих — удобный клиент для подключения по подписке. Добавьте профиль, выберите сервер и подключайтесь.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SliverCrossAxisConstrained(
              maxCrossAxisExtent: 368,
              child: SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 48,
                ),
                sliver: SliverToBoxAdapter(
                  child: FilledButton(
                    onPressed: () async {
                      if (isStarting.value) return;
                      isStarting.value = true;
                      await ref.read(Preferences.introCompleted.notifier).update(true);
                    },
                    child: isStarting.value
                        ? SizedBox(
                            height: 20,
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.transparent,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          )
                        : Text(t.intro.start),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/widget/adaptive_icon.dart';
import 'package:hiddify/features/common/nested_app_bar.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AboutPage extends HookConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final appInfo = ref.watch(appInfoProvider).requireValue;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          NestedAppBar(
            title: Text(t.about.pageTitle),
            actions: [
              PopupMenuButton(
                icon: Icon(AdaptiveIcon(context).more),
                itemBuilder: (context) {
                  return [
                    PopupMenuItem(
                      child: Text(t.general.addToClipboard),
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: appInfo.format()),
                        );
                      },
                    ),
                  ];
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Assets.images.logo.svg(width: 64, height: 64),
                  const Gap(16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.general.appTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Gap(4),
                      Text(
                        "${t.about.version} ${appInfo.presentVersion}",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SelectableText(
                    t.about.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                        ),
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                ListTile(
                  title: Text(t.about.sourceCode),
                  trailing: const Icon(FluentIcons.open_24_regular),
                  onTap: () async {
                    await UriUtils.tryLaunch(
                      Uri.parse(Constants.githubUrl),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

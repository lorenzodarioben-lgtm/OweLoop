import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'router.dart';

class OweLoopBootstrap extends ConsumerWidget {
  const OweLoopBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OweLoopApp(router: ref.watch(appRouterProvider));
  }
}

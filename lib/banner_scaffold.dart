import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Offline visual fixture only: no ad SDK, timers, taps, tracking or network.
class TestAdBanner extends StatefulWidget {
  const TestAdBanner({super.key});
  @override
  State<TestAdBanner> createState() => _TestAdBannerState();
}

class _TestAdBannerState extends State<TestAdBanner> {
  static var next = 0;
  late final int index = next++ % 3;
  static const assets = [
    'assets/test_ads/mint.png',
    'assets/test_ads/peach.png',
    'assets/test_ads/blue.png',
  ];
  @override
  Widget build(BuildContext context) => Semantics(
    label: '테스트 광고, 실제 광고가 아닙니다.',
    image: true,
    child: ExcludeSemantics(
      child: SizedBox(
        height: 50,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              assets[index],
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(0xffdcf2e9)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '테스트 광고 · 실제 광고가 아닙니다',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff19342e),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A route-local banner stays behind modal barriers, unlike a Navigator overlay.
class BannerScaffold extends StatelessWidget {
  const BannerScaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.showBanner = true,
  });
  final PreferredSizeWidget? appBar;
  final Widget? body, bottomNavigationBar;
  final bool showBanner;
  @override
  Widget build(BuildContext context) {
    if (!showBanner) {
      return Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
      );
    }
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: Theme.of(context).brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: const SafeArea(bottom: false, child: TestAdBanner()),
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
      body: Column(
        children: [
          if (appBar != null)
            SizedBox(
              height: appBar!.preferredSize.height,
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: appBar!,
              ),
            ),
          Expanded(child: body ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}

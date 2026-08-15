import 'package:flutter/material.dart';

import '../../../../core/utils/app_assets.dart';

/// Service+ invitation page shown from the start-live tools.
class ServicePlusPage extends StatelessWidget {
  const ServicePlusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              const _ServiceHeader(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const SizedBox(height: 24),
                              const _ServiceArtwork(),
                              const SizedBox(height: 6),
                              const Text(
                                'انضم إلى Service+',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'لتحقيق أرباح من\nمهاراتك',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 40,
                                 fontWeight: FontWeight.w900,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                        'تستطيع الوصول إلى عملاء أكثر مع سيرة ذاتية مخصصة\nللخدمات.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF444444),
                                  fontSize: 15,
                                  height: 1.55,
                                ),
                              ),
                              const SizedBox(height: 40),
                              const Text(
                        'بإتمام الانضمام، فأنت تؤكد أن خدماتك الاحترافية شرعية وقانونية ولا تستلزم ترخيصًا أو اعتمادًا لممارستها في المناطق حيث تقدمها، وأنك مؤهل لتقديم هذه الخدمات.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF777777),
                                  fontSize: 12,
                                  height: 1.55,
                                ),
                              ),
                                const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text(
                      'انضمام',
                      style: TextStyle(
                        fontSize: 14,
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
}

class _ServiceHeader extends StatelessWidget {
  const _ServiceHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        children: [
          const Positioned(
            left: 10,
            top: 8,
            child: Icon(Icons.help_outline, color: Colors.black, size: 26),
          ),
          Positioned(
            right: 4,
            top: 1,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: const Icon(
                Icons.chevron_left,
                color: Colors.black,
                size: 38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Service+ promotional artwork.
class _ServiceArtwork extends StatelessWidget {
  const _ServiceArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final artworkSize = constraints.maxWidth * 0.9;

          return Center(
            child: Image.asset(
              AppAssets.servicePlus,
              width: artworkSize,
              height: artworkSize,
              fit: BoxFit.contain,
            ),
          );
        },
      ),
    );
  }
}

import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:flutter/material.dart';

/// Footer shown while paginating profile posts (matches app Lottie loading).
class ProfilePostsLoadMoreFooter extends StatelessWidget {
  const ProfilePostsLoadMoreFooter({super.key});

  static const double _loaderSize = 48;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.p16),
      child: Center(
        child: CustomLoadingWidget(size: _loaderSize),
      ),
    );
  }
}

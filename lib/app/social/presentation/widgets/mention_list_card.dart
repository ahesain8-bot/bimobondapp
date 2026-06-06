import 'package:bimobondapp/app/social/domain/entities/user_mention_entity.dart';
import 'package:bimobondapp/app/social/presentation/utils/mention_post_navigation.dart';
import 'package:flutter/material.dart';

/// Tappable shell for a mention inbox card — opens the related post.
class MentionListCard extends StatelessWidget {
  const MentionListCard({
    required this.mention,
    required this.child,
    super.key,
  });

  final UserMentionEntity mention;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openMentionPost(context, mention),
        child: child,
      ),
    );
  }
}

/// Name aliases matching the schema / Phase 1 naming.
///
/// The app uses `*Entity` (existing convention). These typedefs map the
/// schema-oriented `*Model` names without creating a second type tree.
library;

import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';

typedef VideoTemplateModel = VideoTemplateCardEntity;
typedef TemplateSlotModel = VideoTemplateSlotEntity;
typedef TemplateTrackModel = TemplateTrackEntity;
typedef TemplateClipModel = TemplateClipEntity;
typedef TemplateEffectModel = TemplateEffectEntity;
typedef TemplateFilterModel = TemplateFilterEntity;
typedef TemplateTransitionModel = VideoTemplateTransitionEntity;
typedef TemplateTextModel = TemplateTextEntity;
typedef TemplateStickerModel = TemplateStickerEntity;
typedef TemplateOverlayModel = TemplateOverlayEntity;
typedef TemplateKeyframeModel = TemplateKeyframeEntity;
typedef TemplateAssetModel = TemplateAssetEntity;
typedef TemplateMusicModel = TemplateMusicEntity;
typedef TemplateCategoryModel = TemplateCategoryEntity;
typedef TemplateVersionModel = TemplateVersionEntity;
typedef UserTemplateProjectModel = VideoTemplateProjectEntity;
typedef UserProjectSlotModel = VideoTemplateProjectSlotEntity;
typedef ProjectExportModel = VideoTemplateExportEntity;
typedef VideoTemplateRecipeModel = VideoTemplateRecipeEntity;
typedef BeatMapModel = TemplateBeatMapEntity;

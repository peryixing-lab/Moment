import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { SceneType, SceneTypes } from '../model/SceneType';
import { ScenePresentationService } from '../service/ScenePresentationService';
import { HDS_PRIMARY_BUTTON, HDS_SECONDARY_BUTTON } from './HdsImmersiveButton';

@Component
export struct SceneSwitchDialog {
  currentSceneProvider: () => SceneType = () => SceneType.LIBRARY;
  onConfirm: (scene: SceneType, durationMinutes: number) => boolean = () => false;
  onCancel: () => void = () => {};
  @State private selectedScene: SceneType = SceneType.LIBRARY;
  @State private selectedDurationMinutes: number = 120;
  private scenes: SceneType[] = SceneTypes.all();
  private durations: number[] = [30, 60, 120, 0];

  aboutToAppear(): void {
    this.selectedScene = this.currentSceneProvider();
    this.selectedDurationMinutes = 120;
  }

  private durationLabel(durationMinutes: number): Resource {
    switch (durationMinutes) {
      case 30:
        return $r('app.string.scene_duration_30_minutes');
      case 60:
        return $r('app.string.scene_duration_1_hour');
      case 120:
        return $r('app.string.scene_duration_2_hours');
      case 0:
        return $r('app.string.scene_duration_until_restored');
      default:
        return $r('app.string.scene_duration_2_hours');
    }
  }

  private confirmSelection(): void {
    if (this.onConfirm(this.selectedScene, this.selectedDurationMinutes)) {
      this.onCancel();
    }
  }

  build() {
    Column({ space: 18 }) {
      Column({ space: 6 }) {
        Text($r('app.string.scene_switch_dialog_title'))
          .width('100%')
          .fontSize(AppTypography.TITLE_MEDIUM)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
        Text($r('app.string.scene_switch_dialog_description'))
          .width('100%')
          .fontSize(AppTypography.CAPTION)
          .fontColor(AppColors.TEXT_SECONDARY)
          .maxLines(2)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        Text($r('app.string.scene_switch_scene_label'))
          .width('100%')
          .fontSize(AppTypography.CAPTION)
          .fontColor(AppColors.TEXT_SECONDARY)
        Row({ space: 6 }) {
          ForEach(this.scenes, (scene: SceneType) => {
            Button(ScenePresentationService.getPresentation(scene).name)
              .layoutWeight(1)
              .height(AppDimensions.MIN_TOUCH_TARGET)
              .fontSize(AppTypography.CAPTION)
              .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
                maxFontSize: AppTypography.CAPTION, overflow: TextOverflow.Clip })
              .fontColor(this.selectedScene === scene ? AppColors.TEXT_PRIMARY : AppColors.TEXT_SECONDARY)
              .borderRadius(AppDimensions.RADIUS_PILL)
              .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
                right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
              .attributeModifier(this.selectedScene === scene ? HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
              .onClick(() => this.selectedScene = scene)
          }, (scene: SceneType) => scene)
        }
        .width('100%')
      }
      .width('100%')

      Column({ space: 8 }) {
        Text($r('app.string.scene_switch_duration_label'))
          .width('100%')
          .fontSize(AppTypography.CAPTION)
          .fontColor(AppColors.TEXT_SECONDARY)
        Row({ space: 6 }) {
          ForEach(this.durations, (durationMinutes: number) => {
            Button(this.durationLabel(durationMinutes))
              .layoutWeight(1)
              .height(AppDimensions.MIN_TOUCH_TARGET)
              .fontSize(AppTypography.CAPTION)
              .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
                maxFontSize: AppTypography.CAPTION, overflow: TextOverflow.Clip })
              .fontColor(this.selectedDurationMinutes === durationMinutes ? AppColors.TEXT_PRIMARY :
                AppColors.TEXT_SECONDARY)
              .borderRadius(AppDimensions.RADIUS_PILL)
              .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
                right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
              .attributeModifier(this.selectedDurationMinutes === durationMinutes ?
                HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
              .onClick(() => this.selectedDurationMinutes = durationMinutes)
          }, (durationMinutes: number) => durationMinutes.toString())
        }
        .width('100%')
      }
      .width('100%')

      Row({ space: 10 }) {
        Button($r('app.string.cancel'))
          .layoutWeight(1)
          .height(AppDimensions.BUTTON_HEIGHT)
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(AppColors.ACCENT)
          .borderRadius(AppDimensions.RADIUS_PILL)
          .attributeModifier(HDS_SECONDARY_BUTTON)
          .onClick(() => this.onCancel())
        Button($r('app.string.scene_switch_confirm'))
          .layoutWeight(1)
          .height(AppDimensions.BUTTON_HEIGHT)
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(AppColors.ACCENT)
          .borderRadius(AppDimensions.RADIUS_PILL)
          .attributeModifier(HDS_PRIMARY_BUTTON)
          .onClick(() => this.confirmSelection())
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ minWidth: 280, maxWidth: 420 })
    .padding(AppDimensions.CARD_PADDING)
    .borderRadius(AppDimensions.RADIUS_PRIMARY)
  }
}

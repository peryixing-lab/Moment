import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { SceneType } from '../model/SceneType';
import { ScenePresentationService } from '../service/ScenePresentationService';
import { HDS_PRIMARY_BUTTON, HDS_SECONDARY_BUTTON } from './HdsImmersiveButton';

@Component
export struct SceneOptionCard {
  @Prop sceneType: SceneType = SceneType.LIBRARY;
  @Prop selected: boolean = false;
  onSelect: (sceneType: SceneType) => void = () => {};

  build() {
    Button(ScenePresentationService.getPresentation(this.sceneType).name)
    .width('25%')
    .height(AppDimensions.MIN_TOUCH_TARGET)
    .fontSize(AppTypography.BODY_MEDIUM)
    .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
      maxFontSize: AppTypography.BODY_MEDIUM, overflow: TextOverflow.Clip })
    .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Regular)
    .fontColor(this.selected ? AppColors.ACCENT : AppColors.TEXT_PRIMARY)
    .borderRadius(AppDimensions.RADIUS_SECONDARY)
    .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
      right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
    .attributeModifier(this.selected ? HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
    .onClick(() => this.onSelect(this.sceneType))
  }
}

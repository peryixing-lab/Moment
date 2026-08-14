import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { HDS_SECONDARY_BUTTON } from './HdsImmersiveButton';

@Component
export struct ErrorState {
  onRetry: () => void = () => {};

  build() {
    Column({ space: 10 }) {
      Text($r('app.string.data_error_title'))
        .fontSize(AppTypography.BODY_LARGE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.WARNING_TEXT)
      Text($r('app.string.data_error_description'))
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(AppColors.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
      Button($r('app.string.retry'))
        .height(AppDimensions.MIN_TOUCH_TARGET)
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(AppColors.ACCENT)
        .borderRadius(AppDimensions.RADIUS_SECONDARY)
        .attributeModifier(HDS_SECONDARY_BUTTON)
        .onClick(() => this.onRetry())
    }
    .width('100%')
    .padding(AppDimensions.CARD_PADDING)
    .borderRadius(AppDimensions.RADIUS_PRIMARY)
    .systemMaterial(ImmersiveMaterials.WARNING_SURFACE)
  }
}

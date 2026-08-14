import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { HDS_SECONDARY_BUTTON } from './HdsImmersiveButton';

@Component
export struct FocusStatusCard {
  @Prop remainingMinutes: number = 0;
  onOpen: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.clock'))
          .fontSize(20)
          .fontColor([AppColors.ACCENT])
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .systemMaterial(ImmersiveMaterials.ACCENT_CHIP)

      Column({ space: 4 }) {
        Text($r('app.string.focus_running'))
          .fontSize(AppTypography.BODY_LARGE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
        Row({ space: 4 }) {
          Text($r('app.string.focus_remaining'))
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(AppColors.ACCENT)
          Text(this.remainingMinutes.toString())
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(AppColors.ACCENT)
          Text($r('app.string.unit_minute'))
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(AppColors.ACCENT)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Button($r('app.string.manage_focus'))
        .height(AppDimensions.MIN_TOUCH_TARGET)
        .fontSize(AppTypography.CAPTION)
        .fontColor(AppColors.ACCENT)
        .borderRadius(AppDimensions.RADIUS_PILL)
        .attributeModifier(HDS_SECONDARY_BUTTON)
        .onClick(() => this.onOpen())
    }
    .width('100%')
    .padding(AppDimensions.CARD_PADDING)
    .borderRadius(AppDimensions.RADIUS_PRIMARY)
    .systemMaterial(ImmersiveMaterials.CARD)
  }
}

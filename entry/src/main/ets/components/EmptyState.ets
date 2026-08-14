import { AppColors } from '../common/AppColors';
import { AppTypography } from '../common/AppTypography';

@Component
export struct EmptyState {
  title: Resource = $r('app.string.empty_title');
  description: Resource = $r('app.string.empty_description');

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontSize(AppTypography.BODY_LARGE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_PRIMARY)
      Text(this.description)
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(AppColors.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 24, bottom: 24 })
  }
}

import { AppColors } from '../common/AppColors';
import { AppTypography } from '../common/AppTypography';

@Component
export struct SectionHeader {
  title: Resource = $r('app.string.today_information');

  build() {
    Text(this.title)
      .width('100%')
      .fontSize(AppTypography.TITLE_MEDIUM)
      .fontWeight(FontWeight.Bold)
      .fontColor(AppColors.TEXT_PRIMARY)
  }
}

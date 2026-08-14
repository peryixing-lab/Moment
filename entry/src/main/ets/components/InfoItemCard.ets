import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { SceneInfoItem } from '../model/SceneModels';

@Component
export struct InfoItemCard {
  item: SceneInfoItem = new SceneInfoItem();
  showDivider: boolean = true;

  build() {
    Column() {
      Row() {
        Column({ space: 4 }) {
          Text(this.item.title)
            .fontSize(AppTypography.CAPTION)
            .fontColor(AppColors.TEXT_SECONDARY)
            .maxLines(1)
          Text(this.item.value)
            .fontSize(AppTypography.BODY_LARGE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.item.description !== undefined) {
            Text(this.item.description)
              .fontSize(AppTypography.CAPTION)
              .fontColor(AppColors.TEXT_TERTIARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: 14, bottom: 14 })

      if (this.showDivider) {
        Divider()
          .width('100%')
          .strokeWidth(1)
          .color(AppColors.BORDER)
      }
    }
    .width('100%')
  }
}

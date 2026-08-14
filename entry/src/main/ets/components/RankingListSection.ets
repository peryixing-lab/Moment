import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { RankingItem } from '../model/ViewModels';

@Component
export struct RankingListSection {
  @Prop title: Resource = $r('app.string.today_focus');
  @Prop items: RankingItem[] = new Array<RankingItem>();

  private symbolForItem(item: RankingItem): Resource {
    switch (item.type) {
      case 'course':
        return $r('sys.symbol.doc');
      case 'task':
        return $r('sys.symbol.checkmark');
      case 'focus':
        return $r('sys.symbol.clock');
      default:
        return $r('sys.symbol.bell');
    }
  }

  build() {
    Column({ space: 10 }) {
      Text(this.title)
        .width('100%')
        .fontSize(AppTypography.TITLE_MEDIUM)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
      Column() {
        ForEach(this.items, (item: RankingItem, index: number) => {
          Row({ space: 12 }) {
            Stack() {
              SymbolGlyph(this.symbolForItem(item))
                .fontSize(18)
                .fontColor([AppColors.ACCENT])
            }
            .width(36)
            .height(36)
            .borderRadius(18)
            .systemMaterial(ImmersiveMaterials.ACCENT_CHIP)

            Column({ space: 3 }) {
              Text(item.title)
                .width('100%')
                .fontSize(AppTypography.CAPTION)
                .fontColor(AppColors.TEXT_SECONDARY)
              Text(item.value)
                .width('100%')
                .fontSize(AppTypography.BODY_LARGE)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_PRIMARY)
                .maxLines(2)
              if (item.description.length > 0) {
                Text(item.description)
                  .width('100%')
                  .fontSize(AppTypography.CAPTION)
                  .fontColor(AppColors.TEXT_TERTIARY)
                  .maxLines(2)
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .alignItems(VerticalAlign.Center)

          if (index < this.items.length - 1) {
            Divider()
              .color(AppColors.BORDER)
              .margin({ left: 62 })
          }
        }, (item: RankingItem) => item.id)
      }
      .width('100%')
      .borderRadius(AppDimensions.RADIUS_PRIMARY)
      .systemMaterial(ImmersiveMaterials.CARD)
    }
    .width('100%')
  }
}

import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { RankingItem, SceneViewModel } from '../model/ViewModels';
import { HDS_PRIMARY_BUTTON, HDS_SECONDARY_BUTTON } from './HdsImmersiveButton';

@Component
export struct SceneHeroCard {
  @Prop model: SceneViewModel = SceneViewModel.empty();
  @Prop interactionEnabled: boolean = true;
  onPrimaryAction: () => void = () => {};
  onSwitchScene: () => void = () => {};
  onRestoreAuto: () => void = () => {};
  onToggleManualLock: () => void = () => {};

  @Builder
  private SecondaryRow(item: RankingItem, isLast: boolean) {
    Row({ space: 12 }) {
      Stack() {
        SymbolGlyph(this.symbolForItem(item))
          .fontSize(18)
          .fontColor([AppColors.ACCENT])
      }
      .width(34)
      .height(34)
      .borderRadius(17)
      .systemMaterial(ImmersiveMaterials.ACCENT_CHIP)

      Column({ space: 3 }) {
        Text(item.title)
          .width('100%')
          .fontSize(AppTypography.CAPTION)
          .fontColor(AppColors.TEXT_SECONDARY)
        Text(item.value)
          .width('100%')
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 11, bottom: 11 })
    .alignItems(VerticalAlign.Center)

    if (!isLast) {
      Divider()
        .color(AppColors.BORDER)
        .margin({ left: 46 })
    }
  }

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

  @Builder
  private SourceSummary() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.model.sourceLabel)
          .fontSize(AppTypography.CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.ACCENT)
        Text(this.model.reasonText)
          .fontSize(AppTypography.CAPTION)
          .fontColor(AppColors.TEXT_SECONDARY)
          .maxLines(2)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.model.isManualOverride) {
        Column({ space: 10 }) {
          Row({ space: 4 }) {
            if (this.model.isManualLocked) {
              Text($r('app.string.manual_locked'))
                .fontSize(AppTypography.CAPTION)
                .fontColor(AppColors.TEXT_SECONDARY)
            } else {
              Text($r('app.string.manual_remaining'))
                .fontSize(AppTypography.CAPTION)
                .fontColor(AppColors.TEXT_SECONDARY)
              Text(this.model.manualOverrideRemainingMinutes.toString())
                .fontSize(AppTypography.CAPTION)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_PRIMARY)
              Text($r('app.string.unit_minute'))
                .fontSize(AppTypography.CAPTION)
                .fontColor(AppColors.TEXT_SECONDARY)
            }
          }
          .width('100%')

          Row({ space: 10 }) {
            Button(this.model.isManualLocked ? $r('app.string.unlock_manual_scene') :
              $r('app.string.lock_manual_scene'))
              .layoutWeight(1)
              .height(44)
              .fontSize(AppTypography.CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.ACCENT)
              .labelStyle({
                maxLines: 1,
                minFontSize: AppTypography.COMPACT_MIN,
                maxFontSize: AppTypography.CAPTION,
                overflow: TextOverflow.Clip
              })
              .borderRadius(AppDimensions.RADIUS_PILL)
              .attributeModifier(HDS_SECONDARY_BUTTON)
              .onClick(() => this.onToggleManualLock())
            Button($r('app.string.restore_auto_scene'))
              .layoutWeight(1)
              .height(44)
              .fontSize(AppTypography.CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.ACCENT)
              .labelStyle({
                maxLines: 1,
                minFontSize: AppTypography.COMPACT_MIN,
                maxFontSize: AppTypography.CAPTION,
                overflow: TextOverflow.Clip
              })
              .borderRadius(AppDimensions.RADIUS_PILL)
              .attributeModifier(HDS_SECONDARY_BUTTON)
              .onClick(() => this.onRestoreAuto())
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(AppDimensions.RADIUS_SECONDARY)
    .systemMaterial(ImmersiveMaterials.SUBTLE_SURFACE)
  }

  @Builder
  private EmptyPrimaryInfo() {
    Column({ space: 6 }) {
      Text($r('app.string.no_today_focus'))
        .fontSize(AppTypography.TITLE_MEDIUM)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_PRIMARY)
      Text($r('app.string.no_today_focus_desc'))
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(AppColors.TEXT_SECONDARY)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private PrimaryInfo() {
    if (this.model.primaryInfo !== undefined) {
      Column({ space: 7 }) {
        Text(this.model.primaryInfo.title)
          .fontSize(AppTypography.CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_SECONDARY)
        Text(this.model.primaryInfo.value)
          .fontSize(AppTypography.DISPLAY)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.model.primaryInfo.description.length > 0) {
          Text(this.model.primaryInfo.description)
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.ACCENT)
            .maxLines(2)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    } else {
      this.EmptyPrimaryInfo()
    }
  }

  build() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph(this.model.sceneSymbolResource)
            .fontSize(22)
            .fontColor([AppColors.ACCENT])
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .systemMaterial(ImmersiveMaterials.ACCENT_CHIP)

        Column({ space: 4 }) {
          Text(this.model.sceneName)
            .fontSize(AppTypography.TITLE_LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)
          Text(this.model.subtitle)
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(AppColors.TEXT_SECONDARY)
            .maxLines(2)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.model.sourceLabel.length > 0) {
          Text(this.model.sourceLabel)
            .fontSize(AppTypography.CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.ACCENT)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(AppDimensions.RADIUS_PILL)
            .systemMaterial(ImmersiveMaterials.ACCENT_CHIP)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Column() {
        this.PrimaryInfo()
      }
      .width('100%')
      .padding(18)
      .borderRadius(AppDimensions.RADIUS_SECONDARY)
      .systemMaterial(ImmersiveMaterials.SUBTLE_SURFACE)

      if (this.model.secondaryInfo.length > 0) {
        Column() {
          ForEach(this.model.secondaryInfo, (item: RankingItem, index: number) => {
            this.SecondaryRow(item, index === this.model.secondaryInfo.length - 1)
          }, (item: RankingItem) => item.id)
        }
        .width('100%')
        .padding({ left: 14, right: 14 })
        .borderRadius(AppDimensions.RADIUS_SECONDARY)
        .systemMaterial(ImmersiveMaterials.SUBTLE_SURFACE)
      }

      Row({ space: 10 }) {
        Button(this.model.primaryAction.label)
          .layoutWeight(1)
          .height(AppDimensions.BUTTON_HEIGHT)
          .fontSize(AppTypography.BODY_MEDIUM)
          .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
            maxFontSize: AppTypography.BODY_MEDIUM, overflow: TextOverflow.Clip })
          .fontWeight(FontWeight.Medium)
          .fontColor(this.interactionEnabled ? AppColors.ACCENT : AppColors.DISABLED)
          .borderRadius(AppDimensions.RADIUS_PILL)
          .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
            right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
          .enabled(this.interactionEnabled)
          .attributeModifier(HDS_PRIMARY_BUTTON)
          .onClick(() => this.onPrimaryAction())
        Button($r('app.string.action_switch_scene'))
          .layoutWeight(1)
          .height(AppDimensions.BUTTON_HEIGHT)
          .fontSize(AppTypography.BODY_MEDIUM)
          .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
            maxFontSize: AppTypography.BODY_MEDIUM, overflow: TextOverflow.Clip })
          .fontWeight(FontWeight.Medium)
          .fontColor(this.interactionEnabled ? AppColors.ACCENT : AppColors.DISABLED)
          .borderRadius(AppDimensions.RADIUS_PILL)
          .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
            right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
          .enabled(this.interactionEnabled)
          .attributeModifier(HDS_SECONDARY_BUTTON)
          .onClick(() => this.onSwitchScene())
      }
      .width('100%')

      this.SourceSummary()
    }
    .width('100%')
    .padding(AppDimensions.CARD_PADDING)
    .borderRadius(AppDimensions.RADIUS_PRIMARY)
    .systemMaterial(ImmersiveMaterials.CARD)
  }
}

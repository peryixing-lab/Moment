import { common } from '@kit.AbilityKit';
import { AppColors, AppSpacing, AppTypography } from '../common/AppTheme';
import { SceneType, SceneTypes } from '../model/SceneType';
import { SceneStateStore } from '../service/SceneStateStore';

@Entry
@Component
struct SceneSwitchPage {
  @State private current: SceneType = SceneType.LIBRARY;

  aboutToAppear(): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    this.current = SceneStateStore.load(context).sceneType;
  }

  private sceneName(sceneType: SceneType): Resource {
    switch (sceneType) {
      case SceneType.CLASS:
        return $r('app.string.scene_class_name');
      case SceneType.MEETING:
        return $r('app.string.scene_meeting_name');
      case SceneType.COMMUTE:
        return $r('app.string.scene_commute_name');
      default:
        return $r('app.string.scene_library_name');
    }
  }

  private sceneSymbol(sceneType: SceneType): Resource {
    switch (sceneType) {
      case SceneType.CLASS:
        return $r('sys.symbol.doc');
      case SceneType.MEETING:
        return $r('sys.symbol.person_2');
      case SceneType.COMMUTE:
        return $r('sys.symbol.car');
      default:
        return $r('sys.symbol.book');
    }
  }

  private applyScene(sceneType: SceneType): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    SceneStateStore.save(context, sceneType);
    try {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.scene_switch_done') });
    } catch (_) {
    }
    this.getUIContext().getRouter().back();
  }

  private goBack(): void {
    this.getUIContext().getRouter().back();
  }

  @Builder
  private SceneCell(sceneType: SceneType) {
    Column({ space: 8 }) {
      Stack() {
        SymbolGlyph(this.sceneSymbol(sceneType))
          .fontSize(24)
          .fontColor([sceneType === this.current ? AppColors.ACCENT : AppColors.TEXT_SECONDARY])
      }
      .width(52)
      .height(52)
      .borderRadius(26)
      .backgroundColor(sceneType === this.current ? AppColors.SURFACE_SELECTED : AppColors.SURFACE_ELEVATED)

      Text(this.sceneName(sceneType))
        .fontSize(AppTypography.BODY)
        .fontWeight(sceneType === this.current ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(sceneType === this.current ? AppColors.TEXT_PRIMARY : AppColors.TEXT_SECONDARY)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .borderRadius(AppSpacing.CARD_RADIUS)
    .backgroundColor(sceneType === this.current ? AppColors.SURFACE_SECONDARY : Color.Transparent)
    .onClick(() => this.applyScene(sceneType))
  }

  build() {
    Column({ space: 16 }) {
      Stack() {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.chevron_backward'))
            .fontSize(16)
            .fontColor([AppColors.TEXT_SECONDARY])
          Text($r('app.string.back'))
            .fontSize(AppTypography.CAPTION)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .height(AppSpacing.TOUCH_TARGET)
        .padding({ left: 12, right: 12 })
        .alignItems(VerticalAlign.Center)
        .onClick(() => this.goBack())
        .position({ x: 0, y: 0 })

        Text($r('app.string.scene_switch_title'))
          .fontSize(AppTypography.BODY_LARGE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
      }
      .width('100%')
      .height(36)

      Column({ space: 12 }) {
        Row({ space: 12 }) {
          this.SceneCell(SceneTypes.all()[0])
          this.SceneCell(SceneTypes.all()[1])
        }
        .width('100%')

        Row({ space: 12 }) {
          this.SceneCell(SceneTypes.all()[2])
          this.SceneCell(SceneTypes.all()[3])
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding({
      left: AppSpacing.PAGE_HORIZONTAL,
      right: AppSpacing.PAGE_HORIZONTAL,
      top: AppSpacing.PAGE_TOP,
      bottom: AppSpacing.PAGE_BOTTOM
    })
    .backgroundColor(AppColors.PAGE_BACKGROUND)
  }
}

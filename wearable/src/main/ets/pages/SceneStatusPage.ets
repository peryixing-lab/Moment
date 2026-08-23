import { common } from '@kit.AbilityKit';
import { AppColors, AppSpacing, AppTypography } from '../common/AppTheme';
import { SceneType } from '../model/SceneType';
import { SceneState, SceneStateStore } from '../service/SceneStateStore';

@Entry
@Component
struct SceneStatusPage {
  @State private sceneType: SceneType = SceneType.LIBRARY;
  @State private isManual: boolean = false;
  @State private now: Date = new Date();
  private timerId: number = -1;

  aboutToAppear(): void {
    this.loadState();
    this.timerId = setInterval(() => {
      this.now = new Date();
    }, 30000);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  onPageShow(): void {
    this.loadState();
  }

  private loadState(): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    const state: SceneState = SceneStateStore.load(context);
    this.sceneType = state.sceneType;
    this.isManual = state.isManual;
  }

  private sceneName(): Resource {
    switch (this.sceneType) {
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

  private sceneSubtitle(): Resource {
    switch (this.sceneType) {
      case SceneType.CLASS:
        return $r('app.string.scene_class_subtitle');
      case SceneType.MEETING:
        return $r('app.string.scene_meeting_subtitle');
      case SceneType.COMMUTE:
        return $r('app.string.scene_commute_subtitle');
      default:
        return $r('app.string.scene_library_subtitle');
    }
  }

  private sceneSymbol(): Resource {
    switch (this.sceneType) {
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

  private statusLabel(): Resource {
    return this.isManual ? $r('app.string.scene_manual_label') : $r('app.string.scene_default_label');
  }

  private clockText(): string {
    const hour: number = this.now.getHours();
    const minute: number = this.now.getMinutes();
    return `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`;
  }

  private openSceneSwitch(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SceneSwitchPage' }).catch(() => {
    });
  }

  build() {
    Column({ space: 10 }) {
      Text(this.clockText())
        .fontSize(AppTypography.TIME)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_TERTIARY)

      Column({ space: 12 }) {
        Stack() {
          SymbolGlyph(this.sceneSymbol())
            .fontSize(30)
            .fontColor([AppColors.ACCENT])
        }
        .width(100)
        .height(100)
        .borderRadius(50)
        .backgroundColor(AppColors.SURFACE_ELEVATED)

        Column({ space: 6 }) {
          Text(this.sceneName())
            .fontSize(AppTypography.TITLE_LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)
          Text(this.sceneSubtitle())
            .fontSize(AppTypography.CAPTION)
            .fontColor(AppColors.TEXT_SECONDARY)
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 12, right: 12 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      Column({ space: 8 }) {
        Row({ space: 6 }) {
          Stack() {}
            .width(6)
            .height(6)
            .borderRadius(3)
            .backgroundColor(AppColors.ACCENT)
          Text(this.statusLabel())
            .fontSize(AppTypography.CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_TERTIARY)
        }
        .height(20)
        .alignItems(VerticalAlign.Center)

        Button($r('app.string.action_switch_scene'))
          .width('100%')
          .height(48)
          .fontSize(AppTypography.BODY_LARGE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.ON_ACCENT)
          .borderRadius(AppSpacing.CARD_RADIUS)
          .backgroundColor(AppColors.ACCENT)
          .onClick(() => this.openSceneSwitch())
      }
      .width('100%')
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

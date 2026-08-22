import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppLogger } from '../common/AppLogger';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import {
  HDS_ICON_ONLY_BUTTON,
  HDS_PRIMARY_BUTTON,
  HDS_SECONDARY_BUTTON
} from '../components/HdsImmersiveButton';
import { SceneType } from '../model/SceneType';
import { OnboardingService } from '../service/OnboardingService';
import { ScenePresentationService } from '../service/ScenePresentationService';

@Entry
@Component
struct OnboardingPage {
  @State private step: number = 1;
  @State private defaultScene: SceneType = SceneType.LIBRARY;
  @State private hasError: boolean = false;
  @State private topAvoidVp: number = 40;
  @State private bottomAvoidVp: number = 24;
  private mainWindow: window.Window | undefined = undefined;
  private readonly onAvoidAreaChange = (_options: window.AvoidAreaOptions): void => {
    if (this.mainWindow !== undefined) {
      this.refreshAvoidArea(this.mainWindow);
    }
  };

  aboutToAppear(): void {
    this.observeAvoidArea();
  }

  aboutToDisappear(): void {
    if (this.mainWindow !== undefined) {
      this.mainWindow.off('avoidAreaChange', this.onAvoidAreaChange);
      this.mainWindow = undefined;
    }
  }

  private context(): common.Context | undefined {
    return this.getUIContext().getHostContext();
  }

  private observeAvoidArea(): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined) {
      return;
    }
    window.getLastWindow(context).then((mainWindow: window.Window) => {
      this.mainWindow = mainWindow;
      this.refreshAvoidArea(mainWindow);
      mainWindow.on('avoidAreaChange', this.onAvoidAreaChange);
    }).catch((error: Object) => {
      AppLogger.error('Unable to observe the onboarding avoid area', error);
    });
  }

  private refreshAvoidArea(mainWindow: window.Window): void {
    try {
      const systemArea: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const cutoutArea: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const gestureArea: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM_GESTURE);
      const topHeightPx: number = Math.max(systemArea.topRect.height, cutoutArea.topRect.height);
      const bottomHeightPx: number =
        Math.max(systemArea.bottomRect.height, gestureArea.bottomRect.height);
      this.topAvoidVp = Math.max(0, this.getUIContext().px2vp(topHeightPx));
      this.bottomAvoidVp = Math.max(0, this.getUIContext().px2vp(bottomHeightPx));
    } catch (error) {
      AppLogger.error('Unable to refresh the onboarding avoid area', error as Object);
    }
  }

  private complete(destination: string = ''): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined || !OnboardingService.complete(context, this.defaultScene)) {
      this.hasError = true;
      return;
    }
    this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' }).then(() => {
      if (destination.length > 0) {
        this.getUIContext().getRouter().pushUrl({ url: destination });
      }
    }).catch(() => {
      this.hasError = true;
    });
  }

  private goToStep(nextStep: number): void {
    this.hasError = false;
    this.step = Math.max(1, Math.min(3, nextStep));
  }

  private sceneIcon(scene: SceneType): Resource {
    switch (scene) {
      case SceneType.LIBRARY:
        return $r('sys.symbol.book_open_fill');
      case SceneType.CLASS:
        return $r('sys.symbol.character_book');
      case SceneType.MEETING:
        return $r('sys.symbol.person_2_fill');
      case SceneType.COMMUTE:
        return $r('sys.symbol.car_fill');
      default:
        return $r('sys.symbol.circle_fill');
    }
  }

  private sceneShort(scene: SceneType): Resource {
    switch (scene) {
      case SceneType.LIBRARY:
        return $r('app.string.scene_library_short');
      case SceneType.CLASS:
        return $r('app.string.scene_class_short');
      case SceneType.MEETING:
        return $r('app.string.scene_meeting_short');
      case SceneType.COMMUTE:
        return $r('app.string.scene_commute_short');
      default:
        return $r('app.string.scene_library_short');
    }
  }

  @Builder
  private StepHeader() {
    Row({ space: 12 }) {
      if (this.step > 1) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_backward'))
            .fontSize(20)
            .fontColor([AppColors.TEXT_PRIMARY])
        }
        .width(40)
        .height(40)
        .attributeModifier(HDS_ICON_ONLY_BUTTON)
        .accessibilityText($r('app.string.onboarding_back'))
        .onClick(() => this.goToStep(this.step - 1))
      } else {
        Image($r('app.media.image'))
          .width(40)
          .height(40)
          .borderRadius(12)
          .objectFit(ImageFit.Cover)
          .accessibilityText($r('app.string.onboarding_logo_description'))
      }

      Progress({ value: this.step, total: 3, type: ProgressType.Linear })
        .layoutWeight(1)
        .height(5)
        .color(AppColors.ACCENT)
        .backgroundColor(AppColors.SURFACE_SECONDARY)
        .borderRadius(3)
        .style({ strokeWidth: 5 })

      Text(`${this.step} / 3`)
        .fontSize(AppTypography.CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_SECONDARY)
        .width(34)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(48)
  }

  @Builder
  private BenefitRow(icon: Resource, title: Resource, description: Resource) {
    Row({ space: 14 }) {
      Row() {
        SymbolGlyph(icon)
          .fontSize(22)
          .fontColor([AppColors.ACCENT])
      }
      .width(42)
      .height(42)
      .justifyContent(FlexAlign.Center)
      .borderRadius(12)
      .systemMaterial(ImmersiveMaterials.ACCENT_CHIP)

      Column({ space: 3 }) {
        Text(title)
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
        Text(description)
          .fontSize(AppTypography.CAPTION)
          .fontColor(AppColors.TEXT_SECONDARY)
          .lineHeight(18)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }

  @Builder
  private SceneChoice(scene: SceneType) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 11 }) {
        Row() {
          Row() {
            SymbolGlyph(this.sceneIcon(scene))
              .fontSize(24)
              .fontColor([scene === this.defaultScene ? AppColors.ON_ACCENT : AppColors.ACCENT])
          }
          .width(44)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .borderRadius(13)
          .systemMaterial(scene === this.defaultScene ?
            ImmersiveMaterials.ACCENT_CHIP : ImmersiveMaterials.SUBTLE_SURFACE)

          Blank()

          if (scene === this.defaultScene) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(21)
              .fontColor([AppColors.ACCENT])
          }
        }
        .width('100%')

        Column({ space: 4 }) {
          Text(ScenePresentationService.getPresentation(scene).name)
            .fontSize(AppTypography.BODY_LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)
          Text(this.sceneShort(scene))
            .fontSize(AppTypography.CAPTION)
            .fontColor(AppColors.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .height(128)
    .padding(16)
    .borderRadius(AppDimensions.RADIUS_PRIMARY)
    .attributeModifier(scene === this.defaultScene ? HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
    .accessibilityText(ScenePresentationService.getPresentation(scene).name)
    .accessibilityDescription(scene === this.defaultScene ?
      $r('app.string.onboarding_scene_selected') : this.sceneShort(scene))
    .onClick(() => this.defaultScene = scene)
  }

  @Builder
  private StartAction(icon: Resource, title: Resource, description: Resource, destination: string,
    primary: boolean) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        Row() {
          SymbolGlyph(icon)
            .fontSize(23)
            .fontColor([primary ? AppColors.ON_ACCENT : AppColors.ACCENT])
        }
        .width(46)
        .height(46)
        .justifyContent(FlexAlign.Center)
        .borderRadius(14)
        .systemMaterial(primary ? ImmersiveMaterials.ACCENT_CHIP : ImmersiveMaterials.SUBTLE_SURFACE)

        Column({ space: 4 }) {
          Text(title)
            .fontSize(AppTypography.BODY_LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)
          Text(description)
            .fontSize(AppTypography.CAPTION)
            .fontColor(AppColors.TEXT_SECONDARY)
            .lineHeight(18)
            .maxLines(2)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(18)
          .fontColor([AppColors.TEXT_TERTIARY])
      }
      .width('100%')
    }
    .width('100%')
    .height(88)
    .padding({ left: 16, right: 16 })
    .borderRadius(AppDimensions.RADIUS_PRIMARY)
    .attributeModifier(primary ? HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
    .accessibilityText(title)
    .accessibilityDescription(description)
    .onClick(() => this.complete(destination))
  }

  @Builder
  private WelcomeStep() {
    Column({ space: 26 }) {
      Column({ space: 16 }) {
        Image($r('app.media.image'))
          .width(112)
          .height(112)
          .borderRadius(28)
          .objectFit(ImageFit.Cover)
          .accessibilityText($r('app.string.onboarding_logo_description'))

        Column({ space: 10 }) {
          Text($r('app.string.onboarding_welcome_eyebrow'))
            .fontSize(AppTypography.CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.ACCENT)
          Text($r('app.string.onboarding_title'))
            .fontSize(AppTypography.DISPLAY)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)
            .textAlign(TextAlign.Center)
          Text($r('app.string.onboarding_intro'))
            .fontSize(AppTypography.BODY_LARGE)
            .fontColor(AppColors.TEXT_SECONDARY)
            .lineHeight(27)
            .textAlign(TextAlign.Center)
            .constraintSize({ maxWidth: 420 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Column({ space: 18 }) {
        this.BenefitRow($r('sys.symbol.clock'), $r('app.string.onboarding_benefit_context_title'),
          $r('app.string.onboarding_benefit_context_description'))
        this.BenefitRow($r('sys.symbol.list_bullet'), $r('app.string.onboarding_benefit_priority_title'),
          $r('app.string.onboarding_benefit_priority_description'))
        this.BenefitRow($r('sys.symbol.rectangle_stack'), $r('app.string.onboarding_benefit_glance_title'),
          $r('app.string.onboarding_benefit_glance_description'))
      }
      .width('100%')
      .padding(20)
      .borderRadius(AppDimensions.RADIUS_PRIMARY)
      .systemMaterial(ImmersiveMaterials.CARD)
    }
    .width('100%')
  }

  @Builder
  private SceneStep() {
    Column({ space: 24 }) {
      Column({ space: 9 }) {
        Text($r('app.string.onboarding_default'))
          .width('100%')
          .fontSize(AppTypography.TITLE_LARGE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
        Text($r('app.string.onboarding_default_description'))
          .width('100%')
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(AppColors.TEXT_SECONDARY)
          .lineHeight(23)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 12 }) {
        Row({ space: 12 }) {
          this.SceneChoice(SceneType.LIBRARY)
          this.SceneChoice(SceneType.CLASS)
        }
        .width('100%')
        Row({ space: 12 }) {
          this.SceneChoice(SceneType.MEETING)
          this.SceneChoice(SceneType.COMMUTE)
        }
        .width('100%')
      }
      .width('100%')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.arrow_clockwise_circle_fill'))
          .fontSize(19)
          .fontColor([AppColors.ACCENT])
        Text($r('app.string.onboarding_default_note'))
          .layoutWeight(1)
          .fontSize(AppTypography.CAPTION)
          .fontColor(AppColors.TEXT_SECONDARY)
          .lineHeight(19)
      }
      .width('100%')
      .padding(14)
      .borderRadius(AppDimensions.RADIUS_SECONDARY)
      .systemMaterial(ImmersiveMaterials.SUBTLE_SURFACE)
    }
    .width('100%')
  }

  @Builder
  private FirstItemStep() {
    Column({ space: 24 }) {
      Column({ space: 9 }) {
        Text($r('app.string.onboarding_add_first'))
          .width('100%')
          .fontSize(AppTypography.TITLE_LARGE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
        Text($r('app.string.onboarding_add_first_description'))
          .width('100%')
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(AppColors.TEXT_SECONDARY)
          .lineHeight(23)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 8 }) {
        Text($r('app.string.onboarding_selected_scene'))
          .fontSize(AppTypography.CAPTION)
          .fontColor(AppColors.TEXT_SECONDARY)
        SymbolGlyph(this.sceneIcon(this.defaultScene))
          .fontSize(16)
          .fontColor([AppColors.ACCENT])
        Text(ScenePresentationService.getPresentation(this.defaultScene).name)
          .fontSize(AppTypography.CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.ACCENT)
      }
      .width('100%')

      Column({ space: 12 }) {
        this.StartAction($r('sys.symbol.calendar_badge_plus'), $r('app.string.onboarding_add_course'),
          $r('app.string.onboarding_add_course_description'), 'pages/CourseEditPage', true)
        this.StartAction($r('sys.symbol.list_bullet_square_fill'), $r('app.string.onboarding_add_task'),
          $r('app.string.onboarding_add_task_description'), 'pages/TaskEditPage', false)
      }
      .width('100%')

      Text($r('app.string.onboarding_ready_note'))
        .width('100%')
        .padding(16)
        .fontSize(AppTypography.CAPTION)
        .fontColor(AppColors.TEXT_SECONDARY)
        .lineHeight(20)
        .textAlign(TextAlign.Center)
        .borderRadius(AppDimensions.RADIUS_SECONDARY)
        .systemMaterial(ImmersiveMaterials.SUBTLE_SURFACE)
    }
    .width('100%')
  }

  @Builder
  private Footer() {
    Column({ space: 8 }) {
      if (this.hasError) {
        Text($r('app.string.save_failed'))
          .width('100%')
          .padding(12)
          .fontSize(AppTypography.CAPTION)
          .fontColor(AppColors.WARNING_TEXT)
          .borderRadius(AppDimensions.RADIUS_SECONDARY)
          .systemMaterial(ImmersiveMaterials.WARNING_SURFACE)
          .accessibilityGroup(true)
      }

      if (this.step < 3) {
        Button(this.step === 1 ? $r('app.string.onboarding_get_started') : $r('app.string.onboarding_continue'))
          .width('100%')
          .height(52)
          .fontSize(AppTypography.BODY_LARGE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.ACCENT)
          .borderRadius(AppDimensions.RADIUS_SECONDARY)
          .attributeModifier(HDS_PRIMARY_BUTTON)
          .onClick(() => this.goToStep(this.step + 1))
      } else {
        Button($r('app.string.onboarding_later'))
          .width('100%')
          .height(AppDimensions.MIN_TOUCH_TARGET)
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(AppColors.TEXT_SECONDARY)
          .attributeModifier(HDS_SECONDARY_BUTTON)
          .onClick(() => this.complete())
      }
    }
    .width('100%')
  }

  build() {
    Stack() {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor(AppColors.PAGE_BACKGROUND)

      Row() {
        Column({ space: 12 }) {
          this.StepHeader()

          Scroll() {
            Column() {
              if (this.step === 1) {
                this.WelcomeStep()
              } else if (this.step === 2) {
                this.SceneStep()
              } else {
                this.FirstItemStep()
              }
            }
            .width('100%')
            .padding({ top: 12, bottom: 16 })
          }
          .width('100%')
          .align(Alignment.Top)
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)

          this.Footer()
        }
        .width('100%')
        .height('100%')
        .constraintSize({ maxWidth: 560 })
        .padding({
          left: AppDimensions.PAGE_HORIZONTAL_PADDING,
          right: AppDimensions.PAGE_HORIZONTAL_PADDING,
          top: this.topAvoidVp + 12,
          bottom: this.bottomAvoidVp + 16
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BACKGROUND)
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

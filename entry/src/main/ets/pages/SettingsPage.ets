import { common } from '@kit.AbilityKit';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { HDS_PRIMARY_BUTTON, HDS_SECONDARY_BUTTON } from '../components/HdsImmersiveButton';
import { HdsImmersiveNavigation } from '../components/HdsImmersiveNavigation';
import { SectionHeader } from '../components/SectionHeader';
import { AppSettings, SettingsReadResult } from '../model/SceneModels';
import { SceneType, SceneTypes } from '../model/SceneType';
import { AppStateService } from '../service/AppStateService';
import { FormRefreshCoordinator } from '../service/FormRefreshCoordinator';
import { SceneContextRuntime } from '../service/SceneContextRuntime';
import { ScenePresentationService } from '../service/ScenePresentationService';

@Entry
@Component
struct SettingsPage {
  @State private autoRecommendationEnabled: boolean = true;
  @State private defaultScene: SceneType = SceneType.LIBRARY;
  @State private showSecondaryInfo: boolean = true;
  @State private hasStorageError: boolean = false;
  private contentScroller: Scroller = new Scroller();
  private scenes: SceneType[] = SceneTypes.all();

  aboutToAppear(): void {
    this.loadSettings();
  }

  private abilityContext(): common.Context | undefined {
    return this.getUIContext().getHostContext();
  }

  private loadSettings(): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined) {
      this.hasStorageError = true;
      return;
    }
    const result: SettingsReadResult = AppStateService.settings(context);
    this.applySettings(result.settings);
    this.hasStorageError = !result.success;
  }

  private applySettings(settings: AppSettings): void {
    this.autoRecommendationEnabled = settings.autoRecommendationEnabled;
    this.defaultScene = settings.defaultScene;
    this.showSecondaryInfo = settings.showSecondaryInfo;
  }

  private updateAuto(value: boolean): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined || !AppStateService.updateAutoRecommendation(context, value)) {
      this.hasStorageError = true;
      this.loadSettings();
      return;
    }
    this.autoRecommendationEnabled = value;
    this.hasStorageError = false;
    SceneContextRuntime.notifyRulesChanged();
    FormRefreshCoordinator.schedule(context, 'settings_auto_changed');
  }

  private updateDefault(scene: SceneType): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined || !AppStateService.updateDefaultScene(context, scene)) {
      this.hasStorageError = true;
      return;
    }
    this.defaultScene = scene;
    this.hasStorageError = false;
    FormRefreshCoordinator.schedule(context, 'settings_default_changed');
  }

  private updateSecondary(value: boolean): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined || !AppStateService.updateSecondaryInfo(context, value)) {
      this.hasStorageError = true;
      return;
    }
    this.showSecondaryInfo = value;
    this.hasStorageError = false;
    FormRefreshCoordinator.schedule(context, 'settings_secondary_changed');
  }

  private resetSettings(): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined || !AppStateService.resetDisplaySettings(context)) {
      this.hasStorageError = true;
      this.showToast($r('app.string.reset_failed'));
      return;
    }
    this.loadSettings();
    this.showToast($r('app.string.reset_done'));
    FormRefreshCoordinator.schedule(context, 'settings_reset');
  }

  private openPage(url: string): void {
    this.getUIContext().getRouter().pushUrl({ url: url }).catch(() => {
      this.showToast($r('app.string.operation_failed'));
    });
  }

  private showToast(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  @Builder
  private SwitchRow(title: Resource, description: Resource, checked: boolean,
    onChange: (value: boolean) => void) {
    Row() {
      Column({ space: 4 }) {
        Text(title).fontSize(AppTypography.BODY_LARGE).fontColor(AppColors.TEXT_PRIMARY)
        Text(description)
          .fontSize(AppTypography.CAPTION)
          .fontColor(AppColors.TEXT_SECONDARY)
          .maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: checked })
        .selectedColor(AppColors.ACCENT)
        .onChange((value: boolean) => onChange(value))
    }
    .width('100%')
    .height(76)
  }

  @Builder
  private ManagementRow(title: Resource, url: string, showDivider: boolean) {
    Column() {
      Row({ space: 12 }) {
        Text(title)
          .fontSize(AppTypography.BODY_LARGE)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([AppColors.TEXT_TERTIARY])
      }
      .width('100%')
      .height(56)
      .focusable(true)
      .accessibilityText(title)
      .onClick(() => this.openPage(url))
      if (showDivider) {
        Divider().color(AppColors.BORDER)
      }
    }
    .width('100%')
  }

  build() {
    Stack() {
      HdsImmersiveNavigation({
        title: $r('app.string.settings_title'),
        backLabel: $r('app.string.back'),
        scrollController: this.contentScroller,
        onBack: () => this.getUIContext().getRouter().back()
      }) {
        Scroll(this.contentScroller) {
          Row() {
            Column({ space: 24 }) {
              if (this.hasStorageError) {
              Text($r('app.string.storage_warning'))
                .width('100%')
                .padding(12)
                .fontSize(AppTypography.CAPTION)
                .fontColor(AppColors.WARNING_TEXT)
                .borderRadius(AppDimensions.RADIUS_SECONDARY)
                .systemMaterial(ImmersiveMaterials.WARNING_SURFACE)
            }

            SectionHeader({ title: $r('app.string.settings_scene_section') })
            Column() {
              this.SwitchRow($r('app.string.auto_recommendation'),
                $r('app.string.auto_recommendation_desc'), this.autoRecommendationEnabled,
                (value: boolean) => this.updateAuto(value))
              Divider().color(AppColors.BORDER)
              Column({ space: 10 }) {
                Text($r('app.string.default_scene'))
                  .width('100%')
                  .fontSize(AppTypography.BODY_LARGE)
                  .fontColor(AppColors.TEXT_PRIMARY)
                Text($r('app.string.default_scene_desc'))
                  .width('100%')
                  .fontSize(AppTypography.CAPTION)
                  .fontColor(AppColors.TEXT_SECONDARY)
                Row({ space: 8 }) {
                  ForEach(this.scenes, (sceneType: SceneType) => {
                    Button(ScenePresentationService.getPresentation(sceneType).name)
                      .layoutWeight(1)
                      .height(AppDimensions.MIN_TOUCH_TARGET)
                      .fontSize(AppTypography.CAPTION)
                      .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
                        maxFontSize: AppTypography.CAPTION, overflow: TextOverflow.Clip })
                      .fontColor(sceneType === this.defaultScene ? AppColors.TEXT_PRIMARY :
                        AppColors.TEXT_SECONDARY)
                      .borderRadius(AppDimensions.RADIUS_SECONDARY)
                      .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
                        right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
                      .attributeModifier(sceneType === this.defaultScene ?
                        HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
                      .onClick(() => this.updateDefault(sceneType))
                  }, (sceneType: SceneType) => sceneType)
                }
                .width('100%')
              }
              .width('100%')
              .padding({ top: 16, bottom: 12 })
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: 18, right: 18 })
            .borderRadius(AppDimensions.RADIUS_PRIMARY)
            .systemMaterial(ImmersiveMaterials.CARD)

            SectionHeader({ title: $r('app.string.settings_display_section') })
            Column() {
              this.SwitchRow($r('app.string.show_secondary'), $r('app.string.show_secondary_desc'),
                this.showSecondaryInfo, (value: boolean) => this.updateSecondary(value))
            }
            .width('100%')
            .padding({ left: 18, right: 18 })
            .borderRadius(AppDimensions.RADIUS_PRIMARY)
            .systemMaterial(ImmersiveMaterials.CARD)

            SectionHeader({ title: $r('app.string.management') })
            Column() {
              this.ManagementRow($r('app.string.manage_courses'), 'pages/CourseListPage', true)
              this.ManagementRow($r('app.string.manage_tasks'), 'pages/TaskListPage', true)
              this.ManagementRow($r('app.string.manage_rules'), 'pages/SceneRuleListPage', true)
              this.ManagementRow($r('app.string.manage_context_rules'),
                'pages/SceneContextRuleListPage', true)
              this.ManagementRow($r('app.string.manage_focus'), 'pages/FocusPage', false)
            }
            .width('100%')
            .padding({ left: 18, right: 18 })
            .borderRadius(AppDimensions.RADIUS_PRIMARY)
            .systemMaterial(ImmersiveMaterials.CARD)

            SectionHeader({ title: $r('app.string.settings_data_section') })
            Column({ space: 18 }) {
              Button($r('app.string.reset_settings'))
                .width('100%')
                .height(AppDimensions.BUTTON_HEIGHT)
                .fontSize(AppTypography.BODY_MEDIUM)
                .fontColor(AppColors.ACCENT)
                .borderRadius(AppDimensions.RADIUS_PILL)
                .attributeModifier(HDS_SECONDARY_BUTTON)
                .onClick(() => this.resetSettings())
              Divider().color(AppColors.BORDER)
              Column({ space: 6 }) {
                Text($r('app.string.about_moment'))
                  .fontSize(AppTypography.BODY_LARGE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.TEXT_PRIMARY)
                Text($r('app.string.about_description'))
                  .fontSize(AppTypography.BODY_MEDIUM)
                  .fontColor(AppColors.TEXT_SECONDARY)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(18)
            .borderRadius(AppDimensions.RADIUS_PRIMARY)
            .systemMaterial(ImmersiveMaterials.CARD)
            }
            .width('100%')
            .constraintSize({ maxWidth: AppDimensions.MAX_CONTENT_WIDTH })
            .padding({ left: AppDimensions.PAGE_HORIZONTAL_PADDING, right: AppDimensions.PAGE_HORIZONTAL_PADDING,
              top: AppDimensions.PAGE_TOP_PADDING, bottom: AppDimensions.PAGE_BOTTOM_PADDING })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .align(Alignment.Top)
        .height('100%')
        .scrollBar(BarState.Off)
        .backgroundColor(AppColors.PAGE_BACKGROUND)
      }
    }
    .width('100%')
    .height('100%')
  }
}

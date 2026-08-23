import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppLogger } from '../common/AppLogger';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { EmptyState } from '../components/EmptyState';
import {
  HDS_DANGER_BUTTON,
  HDS_PRIMARY_BUTTON,
  HDS_SECONDARY_BUTTON
} from '../components/HdsImmersiveButton';
import { HdsImmersiveNavigation } from '../components/HdsImmersiveNavigation';
import { SceneContextRule, SceneContextTriggerType } from '../model/SceneContextModels';
import { CloudSyncService } from '../service/CloudSyncService';
import { FormRefreshCoordinator } from '../service/FormRefreshCoordinator';
import { SceneContextRuleService } from '../service/SceneContextRuleService';
import { SceneContextRuntime } from '../service/SceneContextRuntime';
import { ScenePresentationService } from '../service/ScenePresentationService';

@Entry
@Component
struct SceneContextRuleListPage {
  @State private rules: SceneContextRule[] = new Array<SceneContextRule>();
  @State private hasError: boolean = false;
  private contentScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadRules();
  }

  onPageShow(): void {
    this.loadRules();
  }

  private context(): common.Context | undefined {
    return this.getUIContext().getHostContext();
  }

  private loadRules(): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined) {
      this.hasError = true;
      return;
    }
    this.rules = new SceneContextRuleService(context).listRules();
    this.hasError = false;
  }

  private openEditor(id: number = 0): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/SceneContextRuleEditPage',
      params: { id: id }
    }).catch(() => this.showToast($r('app.string.operation_failed')));
  }

  private toggleRule(rule: SceneContextRule, enabled: boolean): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined ||
      !new SceneContextRuleService(context).setRuleEnabled(rule.id, enabled)) {
      this.showToast($r('app.string.operation_failed'));
      return;
    }
    this.loadRules();
    SceneContextRuntime.notifyRulesChanged();
    FormRefreshCoordinator.schedule(context, 'scene_context_rule_enabled_changed');
  }

  private confirmDelete(rule: SceneContextRule): void {
    this.getUIContext().getPromptAction().showDialog({
      title: $r('app.string.delete_context_rule_title'),
      message: $r('app.string.delete_context_rule_message'),
      buttons: [
        { text: $r('app.string.cancel'), color: AppColors.TEXT_SECONDARY },
        { text: $r('app.string.delete'), color: AppColors.DANGER }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.deleteRule(rule.id);
      }
    }).catch(() => this.showToast($r('app.string.operation_failed')));
  }

  private deleteRule(id: number): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined || !new SceneContextRuleService(context).deleteRule(id)) {
      this.showToast($r('app.string.operation_failed'));
      return;
    }
    this.loadRules();
    SceneContextRuntime.notifyRulesChanged();
    FormRefreshCoordinator.schedule(context, 'scene_context_rule_deleted');
    CloudSyncService.triggerAutoSync(context).catch((error: Object) => {
      AppLogger.error('Auto cloud sync failed', error);
    });
  }

  private triggerLabel(rule: SceneContextRule): Resource {
    return rule.triggerType === SceneContextTriggerType.WIFI ?
      $r('app.string.context_trigger_wifi') : $r('app.string.context_trigger_location');
  }

  private triggerValue(rule: SceneContextRule): string {
    if (rule.triggerType === SceneContextTriggerType.WIFI) {
      return rule.wifiSsid;
    }
    return `${rule.addressName} · ${rule.radiusMeters} 米`;
  }

  private showToast(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  build() {
    Stack() {
      HdsImmersiveNavigation({
        title: $r('app.string.context_rule_list_title'),
        backLabel: $r('app.string.back'),
        showMenu: true,
        menuLabel: $r('app.string.add_context_rule'),
        menuIcon: $r('sys.symbol.plus'),
        scrollController: this.contentScroller,
        contentMaxWidth: AppDimensions.MAX_PAGE_WIDTH,
        onBack: () => this.getUIContext().getRouter().back(),
        onMenu: () => this.openEditor()
      }) {
        if (this.hasError) {
          Column({ space: 16 }) {
            Text($r('app.string.storage_warning'))
              .fontSize(AppTypography.BODY_MEDIUM)
              .fontColor(AppColors.WARNING_TEXT)
            Button($r('app.string.retry'))
              .fontColor(AppColors.ACCENT)
              .attributeModifier(HDS_PRIMARY_BUTTON)
              .onClick(() => this.loadRules())
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .padding(AppDimensions.PAGE_HORIZONTAL_PADDING)
        } else if (this.rules.length === 0) {
          Column({ space: 20 }) {
            EmptyState({
              title: $r('app.string.context_rule_empty_title'),
              description: $r('app.string.context_rule_empty_description')
            })
            Button($r('app.string.add_context_rule'))
              .width('100%')
              .constraintSize({ maxWidth: 280 })
              .height(AppDimensions.BUTTON_HEIGHT)
              .fontSize(AppTypography.BODY_MEDIUM)
              .fontColor(AppColors.ACCENT)
              .attributeModifier(HDS_PRIMARY_BUTTON)
              .onClick(() => this.openEditor())
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .padding(AppDimensions.PAGE_HORIZONTAL_PADDING)
        } else {
          Scroll(this.contentScroller) {
            Column({ space: 12 }) {
              Text($r('app.string.context_rule_foreground_note'))
                .width('100%')
                .padding(12)
                .fontSize(AppTypography.CAPTION)
                .fontColor(AppColors.TEXT_SECONDARY)
                .borderRadius(AppDimensions.RADIUS_SECONDARY)
                .systemMaterial(ImmersiveMaterials.WARNING_SURFACE)

              GridRow({
                columns: { xs: 1, sm: 1, md: 2 },
                gutter: 12,
                breakpoints: { value: ['600vp', '840vp'] }
              }) {
                ForEach(this.rules, (rule: SceneContextRule) => {
                  GridCol({ span: 1 }) {
                    Column({ space: 14 }) {
                  Row({ space: 12 }) {
                    Column({ space: 5 }) {
                      Text(rule.name)
                        .fontSize(AppTypography.BODY_LARGE)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(AppColors.TEXT_PRIMARY)
                      Text(ScenePresentationService.getPresentation(rule.sceneType).name)
                        .fontSize(AppTypography.CAPTION)
                        .fontColor(AppColors.ACCENT)
                      Text(this.triggerLabel(rule))
                        .fontSize(AppTypography.CAPTION)
                        .fontColor(AppColors.TEXT_SECONDARY)
                      Text(this.triggerValue(rule))
                        .fontSize(AppTypography.CAPTION)
                        .fontColor(AppColors.TEXT_TERTIARY)
                        .maxLines(2)
                      Text(rule.autoSwitchEnabled ?
                        $r('app.string.context_switch_automatic') :
                        $r('app.string.context_switch_prompt'))
                        .fontSize(AppTypography.CAPTION)
                        .fontColor(rule.autoSwitchEnabled ? AppColors.ACCENT : AppColors.TEXT_SECONDARY)
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                    Toggle({ type: ToggleType.Switch, isOn: rule.isEnabled })
                      .selectedColor(AppColors.ACCENT)
                      .onChange((value: boolean) => this.toggleRule(rule, value))
                  }
                  .width('100%')

                  Row({ space: 10 }) {
                    Button($r('app.string.edit'))
                      .layoutWeight(1)
                      .height(AppDimensions.MIN_TOUCH_TARGET)
                      .fontSize(AppTypography.CAPTION)
                      .fontColor(AppColors.ACCENT)
                      .borderRadius(AppDimensions.RADIUS_PILL)
                      .attributeModifier(HDS_SECONDARY_BUTTON)
                      .onClick(() => this.openEditor(rule.id))
                    Button($r('app.string.delete'))
                      .layoutWeight(1)
                      .height(AppDimensions.MIN_TOUCH_TARGET)
                      .fontSize(AppTypography.CAPTION)
                      .fontColor(AppColors.DANGER)
                      .borderRadius(AppDimensions.RADIUS_PILL)
                      .attributeModifier(HDS_DANGER_BUTTON)
                      .onClick(() => this.confirmDelete(rule))
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(AppDimensions.CARD_PADDING)
                .borderRadius(AppDimensions.RADIUS_PRIMARY)
                .systemMaterial(ImmersiveMaterials.CARD)
                  }
                }, (rule: SceneContextRule) => rule.id.toString())
              }
              .width('100%')
            }
            .width('100%')
            .constraintSize({ maxWidth: AppDimensions.MAX_PAGE_WIDTH })
            .padding({
              left: AppDimensions.PAGE_HORIZONTAL_PADDING,
              right: AppDimensions.PAGE_HORIZONTAL_PADDING,
              top: AppDimensions.PAGE_TOP_PADDING,
              bottom: AppDimensions.PAGE_BOTTOM_PADDING
            })
          }
          .width('100%')
          .align(Alignment.Top)
          .height('100%')
          .scrollBar(BarState.Off)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.PAGE_BACKGROUND)
  }
}

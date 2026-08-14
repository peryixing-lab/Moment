import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { TimeUtils } from '../common/TimeUtils';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import {
  HDS_DANGER_BUTTON,
  HDS_PRIMARY_BUTTON,
  HDS_SECONDARY_BUTTON
} from '../components/HdsImmersiveButton';
import { HdsImmersiveNavigation } from '../components/HdsImmersiveNavigation';
import { SceneRule } from '../model/SceneRuleModels';
import { DataHealthService } from '../service/DataHealthService';
import { FormRefreshCoordinator } from '../service/FormRefreshCoordinator';
import { ScenePresentationService } from '../service/ScenePresentationService';
import { SceneRuleService } from '../service/SceneRuleService';

@Entry
@Component
struct SceneRuleListPage {
  @State private rules: SceneRule[] = new Array<SceneRule>();
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
    this.rules = new SceneRuleService(context).listRules();
    this.hasError = DataHealthService.hasError();
  }

  private retryData(): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined) {
      this.hasError = true;
      return;
    }
    DataHealthService.retry(context);
    this.loadRules();
  }

  private openEditor(id: number = 0): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SceneRuleEditPage', params: { id: id } }).catch(() => {
      this.showToast($r('app.string.operation_failed'));
    });
  }

  private toggleRule(rule: SceneRule, enabled: boolean): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined || !new SceneRuleService(context).setRuleEnabled(rule.id, enabled)) {
      this.showToast($r('app.string.operation_failed'));
      return;
    }
    this.loadRules();
    FormRefreshCoordinator.schedule(context, 'scene_rule_enabled_changed');
  }

  private confirmDelete(rule: SceneRule): void {
    this.getUIContext().getPromptAction().showDialog({
      title: $r('app.string.delete_rule_title'),
      message: $r('app.string.delete_rule_message'),
      buttons: [
        { text: $r('app.string.cancel'), color: AppColors.TEXT_SECONDARY },
        { text: $r('app.string.delete'), color: AppColors.DANGER }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.deleteRule(rule.id);
      }
    }).catch(() => {
      this.showToast($r('app.string.operation_failed'));
    });
  }

  private deleteRule(id: number): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined || !new SceneRuleService(context).deleteRule(id)) {
      this.showToast($r('app.string.operation_failed'));
      return;
    }
    this.loadRules();
    FormRefreshCoordinator.schedule(context, 'scene_rule_deleted');
  }

  private dayLabel(day: number): Resource {
    switch (day) {
      case 0: return $r('app.string.weekday_sunday');
      case 1: return $r('app.string.weekday_monday');
      case 2: return $r('app.string.weekday_tuesday');
      case 3: return $r('app.string.weekday_wednesday');
      case 4: return $r('app.string.weekday_thursday');
      case 5: return $r('app.string.weekday_friday');
      case 6: return $r('app.string.weekday_saturday');
      default: return $r('app.string.weekday_monday');
    }
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
        title: $r('app.string.rule_list_title'),
        backLabel: $r('app.string.back'),
        showMenu: true,
        menuLabel: $r('app.string.add_rule'),
        menuIcon: $r('sys.symbol.plus'),
        scrollController: this.contentScroller,
        onBack: () => this.getUIContext().getRouter().back(),
        onMenu: () => this.openEditor()
      }) {
        Column({ space: 20 }) {
          if (this.hasError) {
        ErrorState({ onRetry: () => this.retryData() })
      }

      if (this.rules.length === 0 && !this.hasError) {
        EmptyState({
          title: $r('app.string.rule_empty_title'),
          description: $r('app.string.rule_empty_description')
        })
        Button($r('app.string.add_rule'))
          .width('100%')
          .height(AppDimensions.BUTTON_HEIGHT)
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(AppColors.ACCENT)
          .borderRadius(AppDimensions.RADIUS_SECONDARY)
          .attributeModifier(HDS_PRIMARY_BUTTON)
          .onClick(() => this.openEditor())
      } else {
        List({ space: 12, scroller: this.contentScroller }) {
          ForEach(this.rules, (rule: SceneRule) => {
            ListItem() {
              Column({ space: 12 }) {
                Row() {
                  Column({ space: 6 }) {
                    Text(rule.name)
                      .fontSize(AppTypography.BODY_LARGE)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColors.TEXT_PRIMARY)
                    Row({ space: 8 }) {
                      Text(ScenePresentationService.getPresentation(rule.sceneType).name)
                        .fontSize(AppTypography.CAPTION)
                        .fontColor(AppColors.ACCENT)
                      Text(`${TimeUtils.formatClock(rule.startMinutes)}—${TimeUtils.formatClock(rule.endMinutes)}`)
                        .fontSize(AppTypography.CAPTION)
                        .fontColor(AppColors.TEXT_SECONDARY)
                      Text(rule.priority.toString())
                        .fontSize(AppTypography.CAPTION)
                        .fontColor(AppColors.TEXT_TERTIARY)
                    }
                    Row({ space: 5 }) {
                      ForEach(rule.daysOfWeek, (day: number) => {
                        Text(this.dayLabel(day))
                          .fontSize(AppTypography.CAPTION)
                          .fontColor(AppColors.TEXT_TERTIARY)
                      }, (day: number) => day.toString())
                    }
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
                    .layoutWeight(1).height(AppDimensions.MIN_TOUCH_TARGET)
                    .fontSize(AppTypography.CAPTION).fontColor(AppColors.ACCENT)
                    .borderRadius(AppDimensions.RADIUS_PILL)
                    .attributeModifier(HDS_SECONDARY_BUTTON)
                    .onClick(() => this.openEditor(rule.id))
                  Button($r('app.string.delete'))
                    .layoutWeight(1).height(AppDimensions.MIN_TOUCH_TARGET)
                    .fontSize(AppTypography.CAPTION).fontColor(AppColors.DANGER)
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
          }, (rule: SceneRule) => rule.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: AppDimensions.PAGE_HORIZONTAL_PADDING, right: AppDimensions.PAGE_HORIZONTAL_PADDING,
          top: AppDimensions.PAGE_TOP_PADDING, bottom: AppDimensions.PAGE_BOTTOM_PADDING })
        .backgroundColor(AppColors.PAGE_BACKGROUND)
      }
    }
    .width('100%')
    .height('100%')
  }
}

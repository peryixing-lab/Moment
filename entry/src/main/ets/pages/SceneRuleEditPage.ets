import { common } from '@kit.AbilityKit';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { TimeUtils } from '../common/TimeUtils';
import { FormField } from '../components/FormField';
import { HDS_PRIMARY_BUTTON, HDS_SECONDARY_BUTTON } from '../components/HdsImmersiveButton';
import { HdsImmersiveNavigation } from '../components/HdsImmersiveNavigation';
import { OperationResult } from '../model/ServiceModels';
import { SceneRule } from '../model/SceneRuleModels';
import { SceneType } from '../model/SceneType';
import { FormRefreshCoordinator } from '../service/FormRefreshCoordinator';
import { ScenePresentationService } from '../service/ScenePresentationService';
import { SceneRuleService } from '../service/SceneRuleService';

@Entry
@Component
struct SceneRuleEditPage {
  @State private ruleId: number = 0;
  @State private name: string = '';
  @State private selectedDays: number[] = [1, 2, 3, 4, 5];
  @State private startTime: string = '09:00';
  @State private endTime: string = '12:00';
  @State private sceneType: SceneType = SceneType.CLASS;
  @State private priority: string = '10';
  @State private errorMessage: Resource | undefined = undefined;
  private contentScroller: Scroller = new Scroller();
  private days: number[] = [0, 1, 2, 3, 4, 5, 6];
  private scenes: SceneType[] = [SceneType.LIBRARY, SceneType.CLASS, SceneType.MEETING, SceneType.COMMUTE];

  aboutToAppear(): void {
    const rawParams: Object | undefined = this.getUIContext().getRouter().getParams();
    if (rawParams === undefined || rawParams === null) {
      return;
    }
    const params: Record<string, Object> = rawParams as Record<string, Object>;
    const idValue: Object | undefined = params['id'];
    if (typeof idValue === 'number' && Number.isInteger(idValue) && idValue > 0) {
      this.loadRule(idValue);
    }
  }

  private context(): common.Context | undefined {
    return this.getUIContext().getHostContext();
  }

  private loadRule(id: number): void {
    const context: common.Context | undefined = this.context();
    const rule: SceneRule | undefined = context === undefined ? undefined : new SceneRuleService(context).getRule(id);
    if (rule === undefined) {
      return;
    }
    this.ruleId = rule.id;
    this.name = rule.name;
    this.selectedDays = rule.daysOfWeek.slice();
    this.startTime = TimeUtils.formatClock(rule.startMinutes);
    this.endTime = TimeUtils.formatClock(rule.endMinutes);
    this.sceneType = rule.sceneType;
    this.priority = rule.priority.toString();
  }

  private toggleDay(day: number): void {
    const next: number[] = this.selectedDays.slice();
    const index: number = next.indexOf(day);
    if (index >= 0) {
      next.splice(index, 1);
    } else {
      next.push(day);
    }
    next.sort((left: number, right: number) => left - right);
    this.selectedDays = next;
  }

  private save(): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined) {
      this.errorMessage = $r('app.string.save_failed');
      return;
    }
    const service: SceneRuleService = new SceneRuleService(context);
    const rule: SceneRule = this.ruleId > 0 ? service.getRule(this.ruleId) ?? new SceneRule() : new SceneRule();
    rule.id = this.ruleId;
    rule.name = this.name.trim();
    rule.daysOfWeek = this.selectedDays.slice();
    rule.startMinutes = TimeUtils.parseClock(this.startTime);
    rule.endMinutes = TimeUtils.parseClock(this.endTime);
    rule.sceneType = this.sceneType;
    const parsedPriority: number = Number.parseInt(this.priority);
    rule.priority = Number.isNaN(parsedPriority) ? -1 : parsedPriority;
    const result: OperationResult = service.saveRule(rule);
    if (!result.success) {
      this.errorMessage = this.errorFor(result.errorCode);
      return;
    }
    FormRefreshCoordinator.schedule(context, 'scene_rule_saved');
    this.getUIContext().getRouter().back();
  }

  private errorFor(code: string): Resource {
    if (code === 'name') return $r('app.string.rule_validation_name');
    if (code === 'days') return $r('app.string.rule_validation_days');
    if (code === 'time') return $r('app.string.course_validation_time');
    if (code === 'priority') return $r('app.string.rule_validation_priority');
    return $r('app.string.save_failed');
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

  build() {
    Stack() {
      HdsImmersiveNavigation({
        title: this.ruleId > 0 ? $r('app.string.edit_rule') : $r('app.string.add_rule'),
        backLabel: $r('app.string.cancel'),
        showMenu: true,
        menuLabel: $r('app.string.save'),
        menuIcon: $r('sys.symbol.checkmark'),
        scrollController: this.contentScroller,
        onBack: () => this.getUIContext().getRouter().back(),
        onMenu: () => this.save()
      }) {
        Scroll(this.contentScroller) {
          Column({ space: 20 }) {
            if (this.errorMessage !== undefined) {
          Text(this.errorMessage)
            .width('100%').padding(12).fontSize(AppTypography.CAPTION)
            .fontColor(AppColors.WARNING_TEXT)
            .borderRadius(AppDimensions.RADIUS_SECONDARY)
            .systemMaterial(ImmersiveMaterials.WARNING_SURFACE)
        }

        FormField({ label: $r('app.string.rule_name'), value: this.name,
          placeholder: $r('app.string.rule_name'), onValueChange: (value: string) => this.name = value })

        Column({ space: 8 }) {
          Text($r('app.string.rule_days'))
            .width('100%').fontSize(AppTypography.CAPTION).fontColor(AppColors.TEXT_SECONDARY)
          Row() {
            ForEach(this.days, (day: number) => {
              Button(this.dayLabel(day))
                .layoutWeight(1).height(AppDimensions.MIN_TOUCH_TARGET).fontSize(AppTypography.CAPTION)
                .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
                  maxFontSize: AppTypography.CAPTION, overflow: TextOverflow.Clip })
                .fontColor(this.selectedDays.indexOf(day) >= 0 ? AppColors.TEXT_PRIMARY :
                  AppColors.TEXT_SECONDARY)
                .borderRadius(AppDimensions.RADIUS_SECONDARY)
                .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
                  right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
                .attributeModifier(this.selectedDays.indexOf(day) >= 0 ?
                  HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
                .onClick(() => this.toggleDay(day))
            }, (day: number) => day.toString())
          }
          .width('100%')
        }
        .width('100%')

        FormField({ label: $r('app.string.start_time'), value: this.startTime,
          placeholder: $r('app.string.start_time'), onValueChange: (value: string) => this.startTime = value })
        FormField({ label: $r('app.string.end_time'), value: this.endTime,
          placeholder: $r('app.string.end_time'), onValueChange: (value: string) => this.endTime = value })

        Column({ space: 8 }) {
          Text($r('app.string.rule_scene'))
            .width('100%').fontSize(AppTypography.CAPTION).fontColor(AppColors.TEXT_SECONDARY)
          Row({ space: 8 }) {
            ForEach(this.scenes, (scene: SceneType) => {
              Button(ScenePresentationService.getPresentation(scene).name)
                .layoutWeight(1).height(AppDimensions.MIN_TOUCH_TARGET).fontSize(AppTypography.CAPTION)
                .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
                  maxFontSize: AppTypography.CAPTION, overflow: TextOverflow.Clip })
                .fontColor(this.sceneType === scene ? AppColors.TEXT_PRIMARY : AppColors.TEXT_SECONDARY)
                .borderRadius(AppDimensions.RADIUS_SECONDARY)
                .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
                  right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
                .attributeModifier(this.sceneType === scene ? HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
                .onClick(() => this.sceneType = scene)
            }, (scene: SceneType) => scene)
          }
          .width('100%')
        }
        .width('100%')

            FormField({ label: $r('app.string.rule_priority'), value: this.priority,
              placeholder: $r('app.string.rule_priority'), inputType: InputType.Number,
              onValueChange: (value: string) => this.priority = value })
          }
          .width('100%')
          .constraintSize({ maxWidth: AppDimensions.MAX_CONTENT_WIDTH })
          .padding({ left: AppDimensions.PAGE_HORIZONTAL_PADDING, right: AppDimensions.PAGE_HORIZONTAL_PADDING,
            top: AppDimensions.PAGE_TOP_PADDING, bottom: AppDimensions.PAGE_BOTTOM_PADDING })
        }
        .width('100%')
        .align(Alignment.Top)
        .height('100%')
        .backgroundColor(AppColors.PAGE_BACKGROUND)
      }
    }
    .width('100%')
    .height('100%')
  }
}

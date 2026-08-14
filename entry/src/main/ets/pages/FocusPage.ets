import { common } from '@kit.AbilityKit';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { TimeUtils } from '../common/TimeUtils';
import { EmptyState } from '../components/EmptyState';
import { FormField } from '../components/FormField';
import {
  HDS_DANGER_BUTTON,
  HDS_PRIMARY_BUTTON,
  HDS_SECONDARY_BUTTON
} from '../components/HdsImmersiveButton';
import { HdsImmersiveNavigation } from '../components/HdsImmersiveNavigation';
import { FocusSession, FocusStatus } from '../model/FocusModels';
import { FocusService } from '../service/FocusService';
import { FormRefreshCoordinator } from '../service/FormRefreshCoordinator';

@Entry
@Component
struct FocusPage {
  @State private active: FocusSession | undefined = undefined;
  @State private history: FocusSession[] = new Array<FocusSession>();
  @State private now: number = Date.now();
  @State private customDuration: string = '30';
  @State private errorMessage: Resource | undefined = undefined;
  private timerId: number = -1;
  private contentScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.reload();
    this.startTicker();
  }

  aboutToDisappear(): void {
    this.stopTicker();
  }

  private context(): common.Context | undefined {
    return this.getUIContext().getHostContext();
  }

  private reload(): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined) {
      return;
    }
    const service: FocusService = new FocusService(context);
    this.now = Date.now();
    this.active = service.getActiveSession(this.now);
    this.history = service.listHistory();
  }

  private startTicker(): void {
    this.stopTicker();
    this.timerId = setInterval(() => {
      const previouslyRunning: boolean = this.active !== undefined;
      this.reload();
      if (previouslyRunning && this.active === undefined) {
        const context: common.Context | undefined = this.context();
        if (context !== undefined) {
          FormRefreshCoordinator.schedule(context, 'focus_completed');
        }
      }
    }, 1000);
  }

  private stopTicker(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private startFocus(duration: number): void {
    const context: common.Context | undefined = this.context();
    if (duration < 1 || duration > 240) {
      this.errorMessage = $r('app.string.focus_validation');
      return;
    }
    if (context === undefined || !new FocusService(context).startFocus(duration)) {
      this.errorMessage = $r('app.string.focus_already_running');
      return;
    }
    this.errorMessage = undefined;
    this.reload();
    FormRefreshCoordinator.schedule(context, 'focus_started');
  }

  private startCustom(): void {
    const duration: number = Number.parseInt(this.customDuration);
    this.startFocus(Number.isNaN(duration) ? -1 : duration);
  }

  private stopFocus(): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined || !new FocusService(context).stopFocus()) {
      this.errorMessage = $r('app.string.operation_failed');
      return;
    }
    this.reload();
    FormRefreshCoordinator.schedule(context, 'focus_stopped');
  }

  private remainingMinutes(): number {
    if (this.active === undefined) {
      return 0;
    }
    return Math.max(0, Math.ceil((this.active.plannedEndAt - this.now) / 60000));
  }

  private statusLabel(status: FocusStatus): Resource {
    switch (status) {
      case FocusStatus.RUNNING: return $r('app.string.focus_running');
      case FocusStatus.COMPLETED: return $r('app.string.focus_completed');
      case FocusStatus.CANCELLED: return $r('app.string.focus_cancelled');
      default: return $r('app.string.focus_completed');
    }
  }

  build() {
    Stack() {
      HdsImmersiveNavigation({
        title: $r('app.string.focus_page_title'),
        backLabel: $r('app.string.back'),
        scrollController: this.contentScroller,
        onBack: () => this.getUIContext().getRouter().back()
      }) {
        Column({ space: 22 }) {
        if (this.errorMessage !== undefined) {
          Text(this.errorMessage)
            .width('100%').padding(12).fontSize(AppTypography.CAPTION)
            .fontColor(AppColors.WARNING_TEXT)
            .borderRadius(AppDimensions.RADIUS_SECONDARY)
            .systemMaterial(ImmersiveMaterials.WARNING_SURFACE)
        }

        if (this.active !== undefined) {
          Column({ space: 12 }) {
            Text($r('app.string.focus_running'))
              .fontSize(AppTypography.TITLE_MEDIUM).fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
            Text(this.remainingMinutes().toString())
              .fontSize(AppTypography.TIMER).fontWeight(FontWeight.Bold).fontColor(AppColors.ACCENT)
            Text($r('app.string.unit_minute'))
              .fontSize(AppTypography.BODY_MEDIUM).fontColor(AppColors.TEXT_SECONDARY)
            Text(`${TimeUtils.formatTime(this.active.startedAt)}—${TimeUtils.formatTime(this.active.plannedEndAt)}`)
              .fontSize(AppTypography.CAPTION).fontColor(AppColors.TEXT_TERTIARY)
            Button($r('app.string.action_stop_focus'))
              .width('100%').height(AppDimensions.BUTTON_HEIGHT).fontSize(AppTypography.BODY_MEDIUM)
              .fontColor(AppColors.DANGER)
              .borderRadius(AppDimensions.RADIUS_PILL)
              .attributeModifier(HDS_DANGER_BUTTON)
              .onClick(() => this.stopFocus())
          }
          .width('100%')
          .padding(AppDimensions.CARD_PADDING)
          .borderRadius(AppDimensions.RADIUS_PRIMARY)
          .systemMaterial(ImmersiveMaterials.CARD)
        } else {
          Column({ space: 14 }) {
            Text($r('app.string.start_focus'))
              .width('100%').fontSize(AppTypography.TITLE_MEDIUM).fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
            Row({ space: 12 }) {
              Button($r('app.string.focus_25'))
                .layoutWeight(1).height(AppDimensions.BUTTON_HEIGHT).fontSize(AppTypography.BODY_MEDIUM)
                .fontColor(AppColors.ACCENT)
                .borderRadius(AppDimensions.RADIUS_PILL)
                .attributeModifier(HDS_PRIMARY_BUTTON)
                .onClick(() => this.startFocus(25))
              Button($r('app.string.focus_45'))
                .layoutWeight(1).height(AppDimensions.BUTTON_HEIGHT).fontSize(AppTypography.BODY_MEDIUM)
                .fontColor(AppColors.ACCENT)
                .borderRadius(AppDimensions.RADIUS_PILL)
                .attributeModifier(HDS_SECONDARY_BUTTON)
                .onClick(() => this.startFocus(45))
            }
            .width('100%')
            FormField({ label: $r('app.string.focus_custom'), value: this.customDuration,
              placeholder: $r('app.string.focus_custom'), inputType: InputType.Number,
              onValueChange: (value: string) => this.customDuration = value })
            Button($r('app.string.start_focus'))
              .width('100%').height(AppDimensions.BUTTON_HEIGHT).fontSize(AppTypography.BODY_MEDIUM)
              .fontColor(AppColors.ACCENT)
              .borderRadius(AppDimensions.RADIUS_PILL)
              .attributeModifier(HDS_SECONDARY_BUTTON)
              .onClick(() => this.startCustom())
          }
          .width('100%')
          .padding(AppDimensions.CARD_PADDING)
          .borderRadius(AppDimensions.RADIUS_PRIMARY)
          .systemMaterial(ImmersiveMaterials.CARD)
        }

        Text($r('app.string.focus_history'))
          .width('100%').fontSize(AppTypography.TITLE_MEDIUM).fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)

        if (this.history.length === 0) {
          EmptyState({ title: $r('app.string.focus_no_history'), description: $r('app.string.no_today_focus_desc') })
        } else {
          List({ space: 10, scroller: this.contentScroller }) {
            ForEach(this.history, (session: FocusSession) => {
              ListItem() {
                Row() {
                  Column({ space: 4 }) {
                    Text(this.statusLabel(session.status))
                      .fontSize(AppTypography.BODY_MEDIUM).fontWeight(FontWeight.Medium)
                      .fontColor(AppColors.TEXT_PRIMARY)
                    Text(TimeUtils.formatDateTime(session.startedAt))
                      .fontSize(AppTypography.CAPTION).fontColor(AppColors.TEXT_SECONDARY)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Text(`${session.durationMinutes}`)
                    .fontSize(AppTypography.BODY_LARGE).fontColor(AppColors.ACCENT)
                }
                .width('100%')
                .padding(16)
                .borderRadius(AppDimensions.RADIUS_PRIMARY)
                .systemMaterial(ImmersiveMaterials.CARD)
              }
            }, (session: FocusSession) => session.id.toString())
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

import { common } from '@kit.AbilityKit';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { TimeUtils } from '../common/TimeUtils';
import { HDS_PRIMARY_BUTTON, HDS_SECONDARY_BUTTON } from '../components/HdsImmersiveButton';
import { HdsImmersiveNavigation } from '../components/HdsImmersiveNavigation';
import { CourseImportCandidate, CourseImportLoadResult, CourseImportSaveResult } from '../model/CourseImportModels';
import { CourseImportService } from '../service/CourseImportService';
import { FormRefreshCoordinator } from '../service/FormRefreshCoordinator';

@Entry
@Component
struct CourseImportPage {
  @State private candidates: CourseImportCandidate[] = new Array<CourseImportCandidate>();
  @State private selectedKeys: string[] = new Array<string>();
  @State private source: string = '';
  @State private isLoading: boolean = false;
  @State private errorMessage: Resource | undefined = undefined;
  private contentScroller: Scroller = new Scroller();

  private context(): common.Context | undefined {
    return this.getUIContext().getHostContext();
  }

  private openCalendarImporter(): void {
    if (this.isLoading) {
      return;
    }
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CalendarImportSelectPage' }).catch(() => {
      this.errorMessage = $r('app.string.operation_failed');
    });
  }

  private async loadVcs(): Promise<void> {
    const context: common.Context | undefined = this.context();
    if (context === undefined || this.isLoading) {
      return;
    }
    this.isLoading = true;
    this.errorMessage = undefined;
    this.candidates = new Array<CourseImportCandidate>();
    this.selectedKeys = new Array<string>();
    this.source = '';
    const result: CourseImportLoadResult = await new CourseImportService(context).loadFromVcs();
    this.applyLoadResult(result);
  }

  private applyLoadResult(result: CourseImportLoadResult): void {
    this.isLoading = false;
    if (!result.success) {
      if (result.errorCode !== 'cancelled') {
        this.errorMessage = this.errorFor(result.errorCode);
      }
      return;
    }
    this.source = result.source;
    this.candidates = result.candidates;
    this.selectedKeys = new Array<string>();
    if (result.candidates.length === 0) {
      if (result.source === 'calendar') {
        this.errorMessage = $r('app.string.calendar_import_empty_default');
      } else {
        this.errorMessage = $r('app.string.course_import_empty');
      }
    }
  }

  private errorFor(code: string): Resource {
    if (code === 'permission_denied') return $r('app.string.calendar_permission_denied');
    if (code === 'calendar_read_failed') return $r('app.string.calendar_import_failed');
    return $r('app.string.vcs_import_failed');
  }

  private toggleSelection(key: string, selected: boolean): void {
    const next: string[] = this.selectedKeys.slice();
    const index: number = next.indexOf(key);
    if (selected && index < 0) {
      next.push(key);
    } else if (!selected && index >= 0) {
      next.splice(index, 1);
    }
    this.selectedKeys = next;
  }

  private selectAll(): void {
    this.selectedKeys = this.candidates.map((candidate: CourseImportCandidate) => candidate.key);
  }

  private clearSelection(): void {
    this.selectedKeys = new Array<string>();
  }

  private importSelected(): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined) {
      this.errorMessage = $r('app.string.operation_failed');
      return;
    }
    const selected: CourseImportCandidate[] = this.candidates.filter((candidate: CourseImportCandidate) =>
      this.selectedKeys.indexOf(candidate.key) >= 0);
    if (selected.length === 0) {
      this.errorMessage = $r('app.string.course_import_select_first');
      return;
    }
    const result: CourseImportSaveResult = new CourseImportService(context).importCandidates(selected);
    if (result.failedCount > 0 && result.importedCount === 0) {
      this.errorMessage = $r('app.string.course_import_save_failed');
      return;
    }
    FormRefreshCoordinator.schedule(context, 'courses_imported');
    try {
      this.getUIContext().getPromptAction().showToast({
        message: result.importedCount > 0 ? $r('app.string.course_import_done') :
          $r('app.string.course_import_all_duplicate')
      });
    } catch (_) {
    }
    this.getUIContext().getRouter().back();
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

  private dateRange(validFrom: number, validUntil: number): string {
    if (validFrom > 0 && validUntil > 0) {
      return `${TimeUtils.formatDate(validFrom)}—${TimeUtils.formatDate(validUntil)}`;
    }
    if (validFrom > 0) {
      return `${TimeUtils.formatDate(validFrom)} 起`;
    }
    return '';
  }

  build() {
    Stack() {
      HdsImmersiveNavigation({
        title: $r('app.string.course_import_title'),
        backLabel: $r('app.string.back'),
        scrollController: this.contentScroller,
        onBack: () => this.getUIContext().getRouter().back()
      }) {
        Scroll(this.contentScroller) {
          Column({ space: 20 }) {
            Column({ space: 12 }) {
          Text($r('app.string.course_import_source_title'))
            .width('100%')
            .fontSize(AppTypography.BODY_LARGE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
          Button($r('app.string.import_from_calendar'))
            .width('100%')
            .height(AppDimensions.BUTTON_HEIGHT)
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(AppColors.ACCENT)
            .borderRadius(AppDimensions.RADIUS_SECONDARY)
            .enabled(!this.isLoading)
            .attributeModifier(HDS_PRIMARY_BUTTON)
            .onClick(() => this.openCalendarImporter())
          Text($r('app.string.import_from_calendar_desc'))
            .width('100%')
            .fontSize(AppTypography.CAPTION)
            .fontColor(AppColors.TEXT_SECONDARY)
          Button($r('app.string.import_from_vcs'))
            .width('100%')
            .height(AppDimensions.BUTTON_HEIGHT)
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(AppColors.ACCENT)
            .borderRadius(AppDimensions.RADIUS_SECONDARY)
            .enabled(!this.isLoading)
            .attributeModifier(HDS_SECONDARY_BUTTON)
            .onClick(() => this.loadVcs())
          Text($r('app.string.import_from_vcs_desc'))
            .width('100%')
            .fontSize(AppTypography.CAPTION)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .width('100%')
        .padding(AppDimensions.CARD_PADDING)
        .borderRadius(AppDimensions.RADIUS_PRIMARY)
        .systemMaterial(ImmersiveMaterials.CARD)

        if (this.isLoading) {
          Row({ space: 10 }) {
            LoadingProgress().width(22).height(22).color(AppColors.ACCENT)
            Text($r('app.string.course_import_loading'))
              .fontSize(AppTypography.BODY_MEDIUM)
              .fontColor(AppColors.TEXT_SECONDARY)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }

        if (this.errorMessage !== undefined) {
          Text(this.errorMessage)
            .width('100%')
            .padding(12)
            .fontSize(AppTypography.CAPTION)
            .fontColor(AppColors.WARNING_TEXT)
            .borderRadius(AppDimensions.RADIUS_SECONDARY)
            .systemMaterial(ImmersiveMaterials.WARNING_SURFACE)
        }

        if (this.candidates.length > 0) {
          Column({ space: 12 }) {
            Row() {
              Column({ space: 4 }) {
                Text($r('app.string.course_import_preview'))
                  .fontSize(AppTypography.BODY_LARGE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.TEXT_PRIMARY)
                Text(this.source === 'calendar' ? $r('app.string.course_import_source_calendar') :
                  $r('app.string.course_import_source_vcs'))
                  .fontSize(AppTypography.CAPTION)
                  .fontColor(AppColors.TEXT_TERTIARY)
              }
              .alignItems(HorizontalAlign.Start)
              Blank()
              Button($r('app.string.select_all'))
                .height(AppDimensions.MIN_TOUCH_TARGET)
                .fontSize(AppTypography.CAPTION)
                .fontColor(AppColors.ACCENT)
                .attributeModifier(HDS_SECONDARY_BUTTON)
                .onClick(() => this.selectAll())
              Button($r('app.string.clear_selection'))
                .height(AppDimensions.MIN_TOUCH_TARGET)
                .fontSize(AppTypography.CAPTION)
                .fontColor(AppColors.ACCENT)
                .attributeModifier(HDS_SECONDARY_BUTTON)
                .onClick(() => this.clearSelection())
            }
            .width('100%')

            Text($r('app.string.course_import_weekly_note'))
              .width('100%')
              .fontSize(AppTypography.CAPTION)
              .fontColor(AppColors.TEXT_SECONDARY)

            ForEach(this.candidates, (candidate: CourseImportCandidate) => {
              Row({ space: 12 }) {
                Toggle({ type: ToggleType.Checkbox, isOn: this.selectedKeys.indexOf(candidate.key) >= 0 })
                  .selectedColor(AppColors.ACCENT)
                  .onChange((selected: boolean) => this.toggleSelection(candidate.key, selected))
                Column({ space: 4 }) {
                  Text(candidate.name)
                    .width('100%')
                    .fontSize(AppTypography.BODY_MEDIUM)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Row({ space: 6 }) {
                    Text(this.dayLabel(candidate.dayOfWeek))
                      .fontSize(AppTypography.CAPTION)
                      .fontColor(AppColors.TEXT_SECONDARY)
                    Text(
                      `${TimeUtils.formatClock(candidate.startMinutes)}—` +
                      `${TimeUtils.formatClock(candidate.endMinutes)}`
                    )
                      .fontSize(AppTypography.CAPTION)
                      .fontColor(AppColors.TEXT_SECONDARY)
                  }
                  if (candidate.validFrom > 0) {
                    Text(this.dateRange(candidate.validFrom, candidate.validUntil))
                      .width('100%')
                      .fontSize(AppTypography.CAPTION)
                      .fontColor(AppColors.ACCENT)
                  }
                  if (candidate.teacher.length > 0) {
                    Text(candidate.teacher)
                      .width('100%')
                      .fontSize(AppTypography.CAPTION)
                      .fontColor(AppColors.TEXT_SECONDARY)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  if (candidate.location.length > 0) {
                    Text(candidate.location)
                      .width('100%')
                      .fontSize(AppTypography.CAPTION)
                      .fontColor(AppColors.TEXT_TERTIARY)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(12)
              .borderRadius(AppDimensions.RADIUS_SECONDARY)
              .systemMaterial(this.selectedKeys.indexOf(candidate.key) >= 0 ?
                ImmersiveMaterials.ACCENT_CHIP : ImmersiveMaterials.SUBTLE_SURFACE)
            }, (candidate: CourseImportCandidate) => candidate.key)

            Button($r('app.string.import_selected_courses'))
              .width('100%')
              .height(AppDimensions.BUTTON_HEIGHT)
              .fontSize(AppTypography.BODY_MEDIUM)
              .fontColor(AppColors.ACCENT)
              .borderRadius(AppDimensions.RADIUS_SECONDARY)
              .attributeModifier(HDS_PRIMARY_BUTTON)
              .onClick(() => this.importSelected())
          }
          .width('100%')
            }
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

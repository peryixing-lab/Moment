import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import {
  HDS_DANGER_BUTTON,
  HDS_PRIMARY_BUTTON,
  HDS_SECONDARY_BUTTON
} from '../components/HdsImmersiveButton';
import { HdsImmersiveNavigation } from '../components/HdsImmersiveNavigation';
import { TimeUtils } from '../common/TimeUtils';
import { Course } from '../model/CourseModels';
import { CourseService } from '../service/CourseService';
import { DataHealthService } from '../service/DataHealthService';
import { FormRefreshCoordinator } from '../service/FormRefreshCoordinator';

@Entry
@Component
struct CourseListPage {
  @State private courses: Course[] = new Array<Course>();
  @State private hasError: boolean = false;
  @State private isSelecting: boolean = false;
  @State private selectedIds: number[] = new Array<number>();
  private contentScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadCourses();
  }

  onPageShow(): void {
    this.loadCourses();
  }

  private context(): common.Context | undefined {
    return this.getUIContext().getHostContext();
  }

  private loadCourses(): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined) {
      this.hasError = true;
      return;
    }
    this.courses = new CourseService(context).listCourses();
    const availableIds: number[] = this.courses.map((course: Course) => course.id);
    this.selectedIds = this.selectedIds.filter((id: number) => availableIds.indexOf(id) >= 0);
    if (this.courses.length === 0) {
      this.isSelecting = false;
      this.selectedIds = new Array<number>();
    }
    this.hasError = DataHealthService.hasError();
  }

  private openEditor(id: number = 0): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CourseEditPage', params: { id: id } }).catch(() => {
      this.showToast($r('app.string.operation_failed'));
    });
  }

  private openImporter(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CourseImportPage' }).catch(() => {
      this.showToast($r('app.string.operation_failed'));
    });
  }

  private toggleCourse(course: Course, enabled: boolean): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined || !new CourseService(context).setCourseEnabled(course.id, enabled)) {
      this.showToast($r('app.string.operation_failed'));
      return;
    }
    this.loadCourses();
    FormRefreshCoordinator.schedule(context, 'course_enabled_changed');
  }

  private confirmDelete(course: Course): void {
    this.getUIContext().getPromptAction().showDialog({
      title: $r('app.string.delete_course_title'),
      message: $r('app.string.delete_course_message'),
      buttons: [
        { text: $r('app.string.cancel'), color: AppColors.TEXT_SECONDARY },
        { text: $r('app.string.delete'), color: AppColors.DANGER }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.deleteCourse(course.id);
      }
    }).catch(() => {
      this.showToast($r('app.string.operation_failed'));
    });
  }

  private deleteCourse(id: number): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined || !new CourseService(context).deleteCourse(id)) {
      this.showToast($r('app.string.operation_failed'));
      return;
    }
    this.loadCourses();
    FormRefreshCoordinator.schedule(context, 'course_deleted');
  }

  private startBatchSelection(): void {
    this.isSelecting = true;
    this.selectedIds = new Array<number>();
  }

  private cancelBatchSelection(): void {
    this.isSelecting = false;
    this.selectedIds = new Array<number>();
  }

  private toggleSelection(id: number, selected: boolean): void {
    const next: number[] = this.selectedIds.slice();
    const index: number = next.indexOf(id);
    if (selected && index < 0) {
      next.push(id);
    } else if (!selected && index >= 0) {
      next.splice(index, 1);
    }
    this.selectedIds = next;
  }

  private selectAll(): void {
    this.selectedIds = this.courses.map((course: Course) => course.id);
  }

  private clearSelection(): void {
    this.selectedIds = new Array<number>();
  }

  private confirmBatchDelete(): void {
    if (this.selectedIds.length === 0) {
      this.showToast($r('app.string.batch_delete_select_first'));
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: $r('app.string.batch_delete_course_title'),
      message: $r('app.string.batch_delete_course_message'),
      buttons: [
        { text: $r('app.string.cancel'), color: AppColors.TEXT_SECONDARY },
        { text: $r('app.string.delete'), color: AppColors.DANGER }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.deleteSelectedCourses();
      }
    }).catch(() => {
      this.showToast($r('app.string.operation_failed'));
    });
  }

  private deleteSelectedCourses(): void {
    const context: common.Context | undefined = this.context();
    const ids: number[] = this.selectedIds.slice();
    if (context === undefined || ids.length === 0 || !new CourseService(context).deleteCourses(ids)) {
      this.showToast($r('app.string.operation_failed'));
      return;
    }
    this.cancelBatchSelection();
    this.loadCourses();
    this.showToast($r('app.string.batch_delete_course_done'));
    FormRefreshCoordinator.schedule(context, 'courses_batch_deleted');
  }

  private retry(): void {
    const context: common.Context | undefined = this.context();
    if (context !== undefined) {
      DataHealthService.retry(context);
      this.loadCourses();
    }
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

  private dateRange(course: Course): string {
    if (course.validFrom > 0 && course.validUntil > 0) {
      return `${TimeUtils.formatDate(course.validFrom)}—${TimeUtils.formatDate(course.validUntil)}`;
    }
    if (course.validFrom > 0) {
      return `${TimeUtils.formatDate(course.validFrom)} 起`;
    }
    return '';
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
        title: $r('app.string.course_list_title'),
        backLabel: $r('app.string.back'),
        showMenu: true,
        menuLabel: this.isSelecting ? $r('app.string.cancel') : $r('app.string.add_course'),
        menuIcon: this.isSelecting ? $r('sys.symbol.xmark') : $r('sys.symbol.plus'),
        scrollController: this.contentScroller,
        onBack: () => this.getUIContext().getRouter().back(),
        onMenu: () => {
          if (this.isSelecting) {
            this.cancelBatchSelection();
          } else {
            this.openEditor();
          }
        }
      }) {
        Column({ space: 20 }) {
          if (this.isSelecting) {
        Column({ space: 10 }) {
          Row() {
            Text($r('app.string.selected_count_label'))
              .fontSize(AppTypography.BODY_MEDIUM)
              .fontColor(AppColors.TEXT_PRIMARY)
            Text(` ${this.selectedIds.length}/${this.courses.length}`)
              .fontSize(AppTypography.BODY_MEDIUM)
              .fontColor(AppColors.ACCENT)
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

          Button($r('app.string.delete_selected_courses'))
            .width('100%')
            .height(AppDimensions.MIN_TOUCH_TARGET)
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(this.selectedIds.length > 0 ? AppColors.DANGER : AppColors.DISABLED)
            .borderRadius(AppDimensions.RADIUS_SECONDARY)
            .enabled(this.selectedIds.length > 0)
            .attributeModifier(HDS_DANGER_BUTTON)
            .onClick(() => this.confirmBatchDelete())
        }
        .width('100%')
      } else {
        Row({ space: 10 }) {
          Button($r('app.string.import_courses'))
            .layoutWeight(1)
            .height(AppDimensions.MIN_TOUCH_TARGET)
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(AppColors.ACCENT)
            .borderRadius(AppDimensions.RADIUS_PILL)
            .attributeModifier(HDS_SECONDARY_BUTTON)
            .onClick(() => this.openImporter())
          Button($r('app.string.batch_delete'))
            .layoutWeight(1)
            .height(AppDimensions.MIN_TOUCH_TARGET)
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(AppColors.DANGER)
            .borderRadius(AppDimensions.RADIUS_PILL)
            .enabled(this.courses.length > 0)
            .attributeModifier(HDS_DANGER_BUTTON)
            .onClick(() => this.startBatchSelection())
        }
          .width('100%')
      }

      if (this.hasError) {
        ErrorState({ onRetry: () => this.retry() })
      }

      if (this.courses.length === 0 && !this.hasError) {
        EmptyState({
          title: $r('app.string.course_empty_title'),
          description: $r('app.string.course_empty_description')
        })
        Button($r('app.string.add_course'))
          .width('100%')
          .height(AppDimensions.BUTTON_HEIGHT)
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(AppColors.ACCENT)
          .borderRadius(AppDimensions.RADIUS_SECONDARY)
          .attributeModifier(HDS_PRIMARY_BUTTON)
          .onClick(() => this.openEditor())
      } else {
        List({ space: 12, scroller: this.contentScroller }) {
          ForEach(this.courses, (course: Course) => {
            ListItem() {
              Column({ space: 12 }) {
                Row() {
                  if (this.isSelecting) {
                    Toggle({ type: ToggleType.Checkbox, isOn: this.selectedIds.indexOf(course.id) >= 0 })
                      .selectedColor(AppColors.ACCENT)
                      .margin({ right: 12 })
                      .onChange((selected: boolean) => this.toggleSelection(course.id, selected))
                  }
                  Column({ space: 5 }) {
                    Text(course.name)
                      .fontSize(AppTypography.BODY_LARGE)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColors.TEXT_PRIMARY)
                    Row({ space: 6 }) {
                      Text(this.dayLabel(course.dayOfWeek))
                        .fontSize(AppTypography.CAPTION)
                        .fontColor(AppColors.TEXT_SECONDARY)
                      Text(
                        `${TimeUtils.formatClock(course.startMinutes)}—` +
                        `${TimeUtils.formatClock(course.endMinutes)}`
                      )
                        .fontSize(AppTypography.CAPTION)
                        .fontColor(AppColors.TEXT_SECONDARY)
                    }
                    if (course.validFrom > 0) {
                      Text(this.dateRange(course))
                        .fontSize(AppTypography.CAPTION)
                        .fontColor(AppColors.ACCENT)
                    }
                    if (course.teacher.length > 0) {
                      Text(course.teacher)
                        .fontSize(AppTypography.CAPTION)
                        .fontColor(AppColors.TEXT_SECONDARY)
                    }
                    if (course.location.length > 0) {
                      Text(course.location)
                        .fontSize(AppTypography.CAPTION)
                        .fontColor(AppColors.TEXT_TERTIARY)
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  if (!this.isSelecting) {
                    Toggle({ type: ToggleType.Switch, isOn: course.isEnabled })
                      .selectedColor(AppColors.ACCENT)
                      .onChange((value: boolean) => this.toggleCourse(course, value))
                  }
                }
                .width('100%')
                if (!this.isSelecting) {
                  Row({ space: 10 }) {
                    Button($r('app.string.edit'))
                      .layoutWeight(1)
                      .height(AppDimensions.MIN_TOUCH_TARGET)
                      .fontSize(AppTypography.CAPTION)
                      .fontColor(AppColors.ACCENT)
                      .borderRadius(AppDimensions.RADIUS_PILL)
                      .attributeModifier(HDS_SECONDARY_BUTTON)
                      .onClick(() => this.openEditor(course.id))
                    Button($r('app.string.delete'))
                      .layoutWeight(1)
                      .height(AppDimensions.MIN_TOUCH_TARGET)
                      .fontSize(AppTypography.CAPTION)
                      .fontColor(AppColors.DANGER)
                      .borderRadius(AppDimensions.RADIUS_PILL)
                      .attributeModifier(HDS_DANGER_BUTTON)
                      .onClick(() => this.confirmDelete(course))
                  }
                  .width('100%')
                }
              }
              .width('100%')
              .padding(AppDimensions.CARD_PADDING)
              .borderRadius(AppDimensions.RADIUS_PRIMARY)
              .systemMaterial(ImmersiveMaterials.CARD)
            }
          }, (course: Course) => course.id.toString())
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

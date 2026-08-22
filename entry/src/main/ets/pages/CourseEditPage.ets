import { common } from '@kit.AbilityKit';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { FormField } from '../components/FormField';
import { HDS_PRIMARY_BUTTON, HDS_SECONDARY_BUTTON } from '../components/HdsImmersiveButton';
import { HdsImmersiveNavigation } from '../components/HdsImmersiveNavigation';
import { TimeUtils } from '../common/TimeUtils';
import { Course } from '../model/CourseModels';
import { OperationResult } from '../model/ServiceModels';
import { CourseService } from '../service/CourseService';
import { FormRefreshCoordinator } from '../service/FormRefreshCoordinator';

@Entry
@Component
struct CourseEditPage {
  @State private courseId: number = 0;
  @State private name: string = '';
  @State private dayOfWeek: number = 1;
  @State private startTime: string = '09:00';
  @State private endTime: string = '10:00';
  @State private location: string = '';
  @State private teacher: string = '';
  @State private validFrom: string = '';
  @State private validUntil: string = '';
  @State private reminder: string = '30';
  @State private errorMessage: Resource | undefined = undefined;
  private contentScroller: Scroller = new Scroller();
  private days: number[] = [0, 1, 2, 3, 4, 5, 6];

  aboutToAppear(): void {
    const rawParams: Object | undefined = this.getUIContext().getRouter().getParams();
    if (rawParams === undefined || rawParams === null) {
      return;
    }
    const params: Record<string, Object> = rawParams as Record<string, Object>;
    const idValue: Object | undefined = params['id'];
    if (typeof idValue === 'number' && Number.isInteger(idValue) && idValue > 0) {
      this.loadCourse(idValue);
    }
  }

  private context(): common.Context | undefined {
    return this.getUIContext().getHostContext();
  }

  private loadCourse(id: number): void {
    const context: common.Context | undefined = this.context();
    const course: Course | undefined = context === undefined ? undefined : new CourseService(context).getCourse(id);
    if (course === undefined) {
      return;
    }
    this.courseId = course.id;
    this.name = course.name;
    this.dayOfWeek = course.dayOfWeek;
    this.startTime = TimeUtils.formatClock(course.startMinutes);
    this.endTime = TimeUtils.formatClock(course.endMinutes);
    this.location = course.location;
    this.teacher = course.teacher;
    this.validFrom = course.validFrom > 0 ? TimeUtils.formatDate(course.validFrom) : '';
    this.validUntil = course.validUntil > 0 ? TimeUtils.formatDate(course.validUntil) : '';
    this.reminder = course.reminderMinutes.toString();
  }

  private save(): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined) {
      this.errorMessage = $r('app.string.save_failed');
      return;
    }
    const startMinutes: number = TimeUtils.parseClock(this.startTime);
    const endMinutes: number = TimeUtils.parseClock(this.endTime);
    const validFrom: number = TimeUtils.parseDate(this.validFrom);
    const validUntil: number = TimeUtils.parseDate(this.validUntil);
    const reminderMinutes: number = Number.parseInt(this.reminder);
    const course: Course = this.courseId > 0 ?
      new CourseService(context).getCourse(this.courseId) ?? new Course() : new Course();
    course.id = this.courseId;
    course.name = this.name.trim();
    course.dayOfWeek = this.dayOfWeek;
    course.startMinutes = startMinutes;
    course.endMinutes = endMinutes;
    course.location = this.location.trim();
    course.teacher = this.teacher.trim();
    course.validFrom = validFrom;
    course.validUntil = validUntil;
    course.reminderMinutes = Number.isNaN(reminderMinutes) ? -1 : reminderMinutes;
    const result: OperationResult = new CourseService(context).saveCourse(course);
    if (!result.success) {
      this.errorMessage = this.errorFor(result.errorCode);
      return;
    }
    FormRefreshCoordinator.schedule(context, 'course_saved');
    this.getUIContext().getRouter().back();
  }

  private errorFor(code: string): Resource {
    if (code === 'name') {
      return $r('app.string.course_validation_name');
    }
    if (code === 'time') {
      return $r('app.string.course_validation_time');
    }
    if (code === 'reminder') {
      return $r('app.string.course_validation_reminder');
    }
    if (code === 'date') {
      return $r('app.string.course_validation_date');
    }
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
        title: this.courseId > 0 ? $r('app.string.edit_course') : $r('app.string.add_course'),
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
            .width('100%')
            .padding(12)
            .fontSize(AppTypography.CAPTION)
            .fontColor(AppColors.WARNING_TEXT)
            .borderRadius(AppDimensions.RADIUS_SECONDARY)
            .systemMaterial(ImmersiveMaterials.WARNING_SURFACE)
        }

        FormField({
          label: $r('app.string.course_name'), value: this.name,
          placeholder: $r('app.string.course_name'), onValueChange: (value: string) => this.name = value
        })

        Column({ space: 8 }) {
          Text($r('app.string.course_day'))
            .width('100%')
            .fontSize(AppTypography.CAPTION)
            .fontColor(AppColors.TEXT_SECONDARY)
          Row() {
            ForEach(this.days, (day: number) => {
              Button(this.dayLabel(day))
                .layoutWeight(1)
                .height(AppDimensions.MIN_TOUCH_TARGET)
                .fontSize(AppTypography.CAPTION)
                .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
                  maxFontSize: AppTypography.CAPTION, overflow: TextOverflow.Clip })
                .fontColor(day === this.dayOfWeek ? AppColors.TEXT_PRIMARY : AppColors.TEXT_SECONDARY)
                .borderRadius(AppDimensions.RADIUS_SECONDARY)
                .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
                  right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
                .attributeModifier(day === this.dayOfWeek ? HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
                .onClick(() => this.dayOfWeek = day)
            }, (day: number) => day.toString())
          }
          .width('100%')
        }
        .width('100%')

        FormField({ label: $r('app.string.start_time'), value: this.startTime,
          placeholder: $r('app.string.start_time'), onValueChange: (value: string) => this.startTime = value })
        FormField({ label: $r('app.string.end_time'), value: this.endTime,
          placeholder: $r('app.string.end_time'), onValueChange: (value: string) => this.endTime = value })

        FormField({ label: $r('app.string.course_location'), value: this.location,
          placeholder: $r('app.string.course_location'), onValueChange: (value: string) => this.location = value })
        FormField({ label: $r('app.string.course_teacher'), value: this.teacher,
          placeholder: $r('app.string.course_teacher'), onValueChange: (value: string) => this.teacher = value })
        FormField({ label: $r('app.string.course_valid_from'), value: this.validFrom,
          placeholder: $r('app.string.course_date_placeholder'),
          onValueChange: (value: string) => this.validFrom = value })
        FormField({ label: $r('app.string.course_valid_until'), value: this.validUntil,
          placeholder: $r('app.string.course_date_placeholder'),
          onValueChange: (value: string) => this.validUntil = value })
            FormField({ label: $r('app.string.course_reminder'), value: this.reminder,
              placeholder: $r('app.string.course_reminder'), inputType: InputType.Number,
              onValueChange: (value: string) => this.reminder = value })
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

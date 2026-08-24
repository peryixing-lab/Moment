import { common } from '@kit.AbilityKit';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { CourseColorPalette } from '../common/CourseColorPalette';
import { TimeUtils } from '../common/TimeUtils';
import { EmptyState } from '../components/EmptyState';
import { HDS_PRIMARY_BUTTON, HDS_SECONDARY_BUTTON } from '../components/HdsImmersiveButton';
import { HdsImmersiveNavigation } from '../components/HdsImmersiveNavigation';
import { Course } from '../model/CourseModels';
import { CourseService } from '../service/CourseService';

/**
 * Visual weekly/day course timetable.
 *
 * Unlike a fixed-section (node) timetable, this app's courses have arbitrary
 * startMinutes/endMinutes, so the grid is a time axis: every course is rendered
 * as a colour block absolutely positioned by its day column and its start/end
 * minutes. This follows the official ArkUI Stack layout guidance and the
 * conventional "coloured-block" timetable pattern used by OpenHarmony samples.
 */
@Entry
@Component
struct SchedulePage {
  @State private courses: Course[] = new Array<Course>();
  @State private weekMode: boolean = false;
  @State private selectedDay: number = 1;
  private contentScroller: Scroller = new Scroller();
  private weekScroller: Scroller = new Scroller();

  private readonly timeAxisWidth: number = 48;
  private readonly dayHeaderHeight: number = 38;
  private readonly tabHeight: number = 34;
  private readonly pxPerHour: number = 88;
  private readonly weekColumnWidth: number = 88;
  // Rooms the first and last hour labels so they are not clipped by the grid edge.
  private readonly verticalPadding: number = 18;
  private readonly dayOrder: number[] = [1, 2, 3, 4, 5, 6, 0];

  aboutToAppear(): void {
    this.selectedDay = this.todayDayOfWeek();
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
      this.courses = new Array<Course>();
      return;
    }
    this.courses = new CourseService(context).listCourses();
  }

  private openEditor(id: number, day: number): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/CourseEditPage',
      params: { id: id, day: day }
    }).catch(() => {
      this.showToast($r('app.string.operation_failed'));
    });
  }

  private showToast(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  private todayDayOfWeek(): number {
    return new Date().getDay();
  }

  private nowMinute(): number {
    const date: Date = new Date();
    return date.getHours() * 60 + date.getMinutes();
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

  private previousDay(): void {
    const index: number = this.dayOrder.indexOf(this.selectedDay);
    const prevIndex: number = (index + this.dayOrder.length - 1) % this.dayOrder.length;
    this.selectedDay = this.dayOrder[prevIndex];
  }

  private nextDay(): void {
    const index: number = this.dayOrder.indexOf(this.selectedDay);
    const nextIndex: number = (index + 1) % this.dayOrder.length;
    this.selectedDay = this.dayOrder[nextIndex];
  }

  private dateForDay(day: number): string {
    const now: Date = new Date();
    const todayWeekday: number = now.getDay();
    const daysSinceMonday: number = (todayWeekday + 6) % 7;
    const monday: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate() - daysSinceMonday);
    const dayOffset: number = day === 0 ? 6 : day - 1;
    const target: Date = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + dayOffset);
    return `${target.getMonth() + 1}-${target.getDate()}`;
  }

  private weekContentWidth(): number {
    return this.timeAxisWidth + this.dayOrder.length * (this.weekColumnWidth + 4);
  }

  /**
   * Courses that define the visible time range for the current view.
   *
   * In week mode the whole week's courses drive the axis, because every column
   * shares one time scale. In day mode only the selected day matters: looking at
   * Monday must not stretch the axis to cover a 20:00 course that lives on Friday.
   */
  private visibleCourses(): Course[] {
    if (this.weekMode) {
      return this.courses;
    }
    return this.coursesForDay(this.selectedDay);
  }

  private rangeStartMinutes(): number {
    const source: Course[] = this.visibleCourses();
    if (source.length === 0) {
      return 8 * 60;
    }
    let minimum: number = 1440;
    for (let index: number = 0; index < source.length; index += 1) {
      if (source[index].startMinutes < minimum) {
        minimum = source[index].startMinutes;
      }
    }
    const rounded: number = Math.floor(minimum / 30) * 30;
    return Math.max(0, Math.min(1439, rounded));
  }

  private rangeEndMinutes(): number {
    const source: Course[] = this.visibleCourses();
    if (source.length === 0) {
      return 18 * 60;
    }
    let maximum: number = 0;
    for (let index: number = 0; index < source.length; index += 1) {
      if (source[index].endMinutes > maximum) {
        maximum = source[index].endMinutes;
      }
    }
    const rounded: number = Math.ceil(maximum / 30) * 30;
    const safeEnd: number = Math.min(1440, Math.max(rounded, this.rangeStartMinutes() + 30));
    return safeEnd;
  }

  private pixelPerMinute(): number {
    return this.pxPerHour / 60;
  }

  private minuteY(minutes: number): number {
    return this.verticalPadding + (minutes - this.rangeStartMinutes()) * this.pixelPerMinute();
  }

  private gridHeight(): number {
    const minutes: number = this.rangeEndMinutes() - this.rangeStartMinutes();
    return Math.max(120, minutes * this.pixelPerMinute()) + 2 * this.verticalPadding;
  }

  private hourTicks(): number[] {
    const ticks: number[] = new Array<number>();
    const start: number = this.rangeStartMinutes();
    const end: number = this.rangeEndMinutes();
    let tick: number = Math.ceil(start / 60) * 60;
    while (tick <= end) {
      ticks.push(tick);
      tick += 60;
    }
    return ticks;
  }

  private coursesForDay(day: number): Course[] {
    const result: Course[] = new Array<Course>();
    for (let index: number = 0; index < this.courses.length; index += 1) {
      if (this.courses[index].dayOfWeek === day) {
        result.push(this.courses[index]);
      }
    }
    return result;
  }

  private courseTop(course: Course): number {
    return this.minuteY(course.startMinutes) + 1;
  }

  private courseHeight(course: Course): number {
    const raw: number = (course.endMinutes - course.startMinutes) * this.pixelPerMinute() - 2;
    return Math.max(26, raw);
  }

  @Builder
  private segmentedControl() {
    Row({ space: 8 }) {
      Button($r('app.string.schedule_view_day'))
        .layoutWeight(1)
        .height(this.tabHeight)
        .fontSize(AppTypography.CAPTION)
        .fontColor(this.weekMode ? AppColors.TEXT_SECONDARY : AppColors.ACCENT)
        .borderRadius(AppDimensions.RADIUS_SECONDARY)
        .attributeModifier(this.weekMode ? HDS_SECONDARY_BUTTON : HDS_PRIMARY_BUTTON)
        .onClick(() => this.weekMode = false)
      Button($r('app.string.schedule_view_week'))
        .layoutWeight(1)
        .height(this.tabHeight)
        .fontSize(AppTypography.CAPTION)
        .fontColor(this.weekMode ? AppColors.ACCENT : AppColors.TEXT_SECONDARY)
        .borderRadius(AppDimensions.RADIUS_SECONDARY)
        .attributeModifier(this.weekMode ? HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
        .onClick(() => this.weekMode = true)
    }
    .width('100%')
  }

  @Builder
  private dayNavigator() {
    Row() {
      Column() {
        SymbolGlyph($r('sys.symbol.chevron_backward'))
          .fontSize(18)
          .fontColor([AppColors.TEXT_PRIMARY])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .justifyContent(FlexAlign.Center)
      .systemMaterial(ImmersiveMaterials.SUBTLE_SURFACE)
      .onClick(() => this.previousDay())

      Column({ space: 2 }) {
        Text(this.dayLabel(this.selectedDay))
          .fontSize(AppTypography.BODY_LARGE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
        Row()
          .width(20)
          .height(3)
          .borderRadius(2)
          .backgroundColor(this.selectedDay === this.todayDayOfWeek() ? AppColors.ACCENT : Color.Transparent)
        Text(this.dateForDay(this.selectedDay))
          .fontSize(AppTypography.CAPTION)
          .fontColor(AppColors.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column() {
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(18)
          .fontColor([AppColors.TEXT_PRIMARY])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .justifyContent(FlexAlign.Center)
      .systemMaterial(ImmersiveMaterials.SUBTLE_SURFACE)
      .onClick(() => this.nextDay())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private weekHeader() {
    Row({ space: 4 }) {
      Column()
        .width(this.timeAxisWidth)
      ForEach(this.dayOrder, (day: number) => {
        Column({ space: 3 }) {
          Text(this.dayLabel(day))
            .fontSize(AppTypography.CAPTION)
            .fontWeight(day === this.todayDayOfWeek() ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(day === this.todayDayOfWeek() ? AppColors.ACCENT : AppColors.TEXT_SECONDARY)
          Row()
            .width(18)
            .height(3)
            .borderRadius(2)
            .backgroundColor(day === this.todayDayOfWeek() ? AppColors.ACCENT : Color.Transparent)
        }
        .width(this.weekColumnWidth)
        .height(this.dayHeaderHeight)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }, (day: number) => day.toString())
    }
    .width(this.weekContentWidth())
  }

  @Builder
  private timeAxis() {
    Stack() {
      ForEach(this.hourTicks(), (tick: number) => {
        Text(TimeUtils.formatClock(tick))
          .fontSize(AppTypography.CAPTION)
          .fontColor(AppColors.TEXT_TERTIARY)
          .width('100%')
          .textAlign(TextAlign.End)
          .position({ x: 0, y: this.minuteY(tick) - 7 })
      }, (tick: number) => tick.toString())
    }
    .width(this.timeAxisWidth)
    .height(this.gridHeight())
    .clip(true)
  }

  @Builder
  private nowLine() {
    if (this.nowMinute() >= this.rangeStartMinutes() && this.nowMinute() <= this.rangeEndMinutes()) {
      Row()
        .width('100%')
        .height(2)
        .backgroundColor(AppColors.ACCENT)
        .position({ x: 0, y: this.minuteY(this.nowMinute()) - 1 })
    }
  }

  @Builder
  private courseBlock(course: Course) {
    Row({ space: 6 }) {
      Column()
        .width(3)
        .height('100%')
        .backgroundColor(CourseColorPalette.colorFor(course.name))
      Column({ space: 2 }) {
        Text(course.name)
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.courseHeight(course) > 40) {
          Text(`${TimeUtils.formatClock(course.startMinutes)}–${TimeUtils.formatClock(course.endMinutes)}`)
            .fontSize(AppTypography.CAPTION)
            .fontColor(AppColors.TEXT_SECONDARY)
            .maxLines(1)
            .width('100%')
        }
        if (this.courseHeight(course) > 66 && course.location.length > 0) {
          Text(course.location)
            .fontSize(AppTypography.CAPTION)
            .fontColor(AppColors.TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(this.courseHeight(course))
    .padding({ left: 6, right: 6, top: 3, bottom: 3 })
    .borderRadius(8)
    .backgroundColor(CourseColorPalette.backgroundFor(course.name))
    .position({ x: 0, y: this.courseTop(course) })
    .opacity(course.isEnabled ? 1 : 0.5)
    .onClick(() => this.openEditor(course.id, course.dayOfWeek))
  }

  @Builder
  private dayColumn(day: number, colWidth: number) {
    Stack() {
      if (day === this.todayDayOfWeek()) {
        this.nowLine()
      }
      ForEach(this.coursesForDay(day), (course: Course) => {
        this.courseBlock(course)
      }, (course: Course) => course.id.toString())
    }
    .width(colWidth > 0 ? colWidth : '100%')
    .layoutWeight(colWidth > 0 ? 0 : 1)
    .height(this.gridHeight())
    .clip(true)
    .onClick(() => this.openEditor(0, day))
  }

  @Builder
  private grid(week: boolean) {
    Stack() {
      ForEach(this.hourTicks(), (tick: number) => {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor(AppColors.BORDER)
          .position({ x: 0, y: this.minuteY(tick) })
      }, (tick: number) => tick.toString())
      Row({ space: 4 }) {
        this.timeAxis()
        if (week) {
          ForEach(this.dayOrder, (day: number) => {
            this.dayColumn(day, this.weekColumnWidth)
          }, (day: number) => day.toString())
        } else {
          this.dayColumn(this.selectedDay, 0)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width(week ? this.weekContentWidth() : '100%')
    .height(this.gridHeight())
    .alignContent(Alignment.TopStart)
  }

  build() {
    Stack() {
      HdsImmersiveNavigation({
        title: $r('app.string.schedule_page_title'),
        backLabel: $r('app.string.back'),
        showMenu: true,
        menuLabel: $r('app.string.add_course'),
        menuIcon: $r('sys.symbol.plus'),
        scrollController: this.contentScroller,
        contentMaxWidth: AppDimensions.MAX_PAGE_WIDTH,
        onBack: () => this.getUIContext().getRouter().back(),
        onMenu: () => this.openEditor(0, this.selectedDay)
      }) {
        Column({ space: 16 }) {
          this.segmentedControl()
          if (this.courses.length === 0) {
            Column({ space: 16 }) {
              EmptyState({
                title: $r('app.string.schedule_empty_title'),
                description: $r('app.string.schedule_empty_description')
              })
              Button($r('app.string.add_course'))
                .width('100%')
                .height(AppDimensions.BUTTON_HEIGHT)
                .fontSize(AppTypography.BODY_MEDIUM)
                .fontColor(AppColors.ACCENT)
                .borderRadius(AppDimensions.RADIUS_SECONDARY)
                .attributeModifier(HDS_PRIMARY_BUTTON)
                .onClick(() => this.openEditor(0, this.selectedDay))
            }
            .width('100%')
          } else if (this.weekMode) {
            Scroll(this.contentScroller) {
              Scroll(this.weekScroller) {
                Column() {
                  this.weekHeader()
                  this.grid(true)
                }
                .width(this.weekContentWidth())
              }
              .scrollable(ScrollDirection.Horizontal)
              .width('100%')
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
            }
            .width('100%')
            .layoutWeight(1)
            .align(Alignment.Top)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
          } else {
            this.dayNavigator()
            Scroll(this.contentScroller) {
              Column() {
                this.grid(false)
              }
              .width('100%')
            }
            .width('100%')
            .layoutWeight(1)
            .align(Alignment.Top)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: AppDimensions.MAX_CONTENT_WIDTH })
        .padding({
          left: AppDimensions.PAGE_HORIZONTAL_PADDING,
          right: AppDimensions.PAGE_HORIZONTAL_PADDING,
          top: AppDimensions.PAGE_TOP_PADDING,
          bottom: AppDimensions.PAGE_BOTTOM_PADDING
        })
        .backgroundColor(AppColors.PAGE_BACKGROUND)
      }
    }
    .width('100%')
    .height('100%')
    .background(AppColors.PAGE_BACKGROUND)
  }
}

import { common } from '@kit.AbilityKit';
import { Course, CourseOccurrence } from '../model/CourseModels';
import { OperationResult } from '../model/ServiceModels';
import { CourseRepository } from '../repository/CourseRepository';

const DAY_MS: number = 24 * 60 * 60 * 1000;

export class CourseService {
  private readonly repository: CourseRepository;

  constructor(context: common.Context) {
    this.repository = new CourseRepository(context);
  }

  listCourses(): Course[] {
    return this.repository.list(false);
  }

  getCourse(id: number): Course | undefined {
    return this.repository.getById(id);
  }

  saveCourse(course: Course): OperationResult {
    const validation: OperationResult = CourseService.validate(course);
    if (!validation.success) {
      return validation;
    }
    return this.repository.save(course) ? OperationResult.ok() : OperationResult.fail('storage');
  }

  deleteCourse(id: number): boolean {
    return id > 0 && this.repository.remove(id);
  }

  deleteCourses(ids: number[]): boolean {
    return ids.length > 0 && this.repository.removeMany(ids);
  }

  setCourseEnabled(id: number, enabled: boolean): boolean {
    return id > 0 && this.repository.setEnabled(id, enabled);
  }

  getCurrentCourse(now: number): CourseOccurrence | undefined {
    const date: Date = new Date(now);
    const minute: number = date.getHours() * 60 + date.getMinutes();
    const courses: Course[] = this.repository.list(true);
    let selected: CourseOccurrence | undefined = undefined;
    for (let index: number = 0; index < courses.length; index += 1) {
      const course: Course = courses[index];
      if (course.dayOfWeek === date.getDay() && this.isActiveOnDate(course, now) &&
        minute >= course.startMinutes && minute < course.endMinutes) {
        const occurrence: CourseOccurrence = this.todayOccurrence(course, now);
        occurrence.isCurrent = true;
        if (selected === undefined || occurrence.startAt > selected.startAt) {
          selected = occurrence;
        }
      }
    }
    return selected;
  }

  getUpcomingCourse(now: number, withinMinutes: number): CourseOccurrence | undefined {
    const next: CourseOccurrence | undefined = this.getNextCourse(now);
    if (next === undefined || next.startAt - now > withinMinutes * 60 * 1000) {
      return undefined;
    }
    return next;
  }

  getNextCourse(now: number): CourseOccurrence | undefined {
    const courses: Course[] = this.repository.list(true);
    let selected: CourseOccurrence | undefined = undefined;
    for (let index: number = 0; index < courses.length; index += 1) {
      const occurrence: CourseOccurrence | undefined = this.nextOccurrence(courses[index], now);
      if (occurrence === undefined) {
        continue;
      }
      if (selected === undefined || occurrence.startAt < selected.startAt) {
        selected = occurrence;
      }
    }
    return selected;
  }

  static validate(course: Course): OperationResult {
    if (course.name.trim().length === 0) {
      return OperationResult.fail('name');
    }
    if (course.dayOfWeek < 0 || course.dayOfWeek > 6) {
      return OperationResult.fail('day');
    }
    if (course.startMinutes < 0 || course.startMinutes >= 1440 || course.endMinutes <= 0 ||
      course.endMinutes > 1440 || course.startMinutes >= course.endMinutes) {
      return OperationResult.fail('time');
    }
    if (course.reminderMinutes < 0 || course.reminderMinutes > 1440) {
      return OperationResult.fail('reminder');
    }
    if (course.validFrom < 0 || course.validUntil < 0 ||
      (course.validFrom > 0 && course.validUntil > 0 && course.validUntil < course.validFrom)) {
      return OperationResult.fail('date');
    }
    return OperationResult.ok();
  }

  private todayOccurrence(course: Course, now: number): CourseOccurrence {
    const startOfDay: number = new Date(new Date(now).setHours(0, 0, 0, 0)).getTime();
    const occurrence: CourseOccurrence = new CourseOccurrence();
    occurrence.course = course;
    occurrence.startAt = startOfDay + course.startMinutes * 60 * 1000;
    occurrence.endAt = startOfDay + course.endMinutes * 60 * 1000;
    return occurrence;
  }

  private nextOccurrence(course: Course, now: number): CourseOccurrence | undefined {
    const todayStart: number = new Date(new Date(now).setHours(0, 0, 0, 0)).getTime();
    const searchStart: number = course.validFrom > todayStart ? course.validFrom : todayStart;
    const date: Date = new Date(searchStart);
    let dayOffset: number = (course.dayOfWeek - date.getDay() + 7) % 7;
    let occurrenceDay: number = searchStart + dayOffset * DAY_MS;
    let startAt: number = occurrenceDay + course.startMinutes * 60 * 1000;
    if (startAt < now) {
      dayOffset += 7;
      occurrenceDay = searchStart + dayOffset * DAY_MS;
      startAt = occurrenceDay + course.startMinutes * 60 * 1000;
    }
    if (course.validUntil > 0 && occurrenceDay > course.validUntil) {
      return undefined;
    }
    const occurrence: CourseOccurrence = new CourseOccurrence();
    occurrence.course = course;
    occurrence.startAt = startAt;
    occurrence.endAt = startAt + (course.endMinutes - course.startMinutes) * 60 * 1000;
    return occurrence;
  }

  private isActiveOnDate(course: Course, timestamp: number): boolean {
    const dayStart: number = new Date(new Date(timestamp).setHours(0, 0, 0, 0)).getTime();
    return (course.validFrom <= 0 || dayStart >= course.validFrom) &&
      (course.validUntil <= 0 || dayStart <= course.validUntil);
  }
}

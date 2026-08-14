import { common } from '@kit.AbilityKit';
import { AppLogger } from '../common/AppLogger';
import { DatabaseManager } from '../database/DatabaseManager';
import { TABLE_COURSE } from '../database/DatabaseSchema';
import { Course } from '../model/CourseModels';

export class CourseRepository {
  private readonly context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  list(enabledOnly: boolean = false): Course[] {
    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_COURSE);
    const courses: Course[] = new Array<Course>();
    for (let index: number = 0; index < rows.length; index += 1) {
      const course: Course | undefined = this.decode(rows[index]);
      if (course !== undefined && (!enabledOnly || course.isEnabled)) {
        courses.push(course);
      }
    }
    courses.sort((left: Course, right: Course) => {
      if (left.dayOfWeek !== right.dayOfWeek) {
        return left.dayOfWeek - right.dayOfWeek;
      }
      return left.startMinutes - right.startMinutes;
    });
    AppLogger.info(`Course query returned ${courses.length} rows`);
    return courses;
  }

  getById(id: number): Course | undefined {
    const courses: Course[] = this.list(false);
    for (let index: number = 0; index < courses.length; index += 1) {
      if (courses[index].id === id) {
        return courses[index];
      }
    }
    return undefined;
  }

  save(course: Course): boolean {
    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_COURSE);
    const now: number = Date.now();
    if (course.id <= 0) {
      course.id = DatabaseManager.nextId(this.context, TABLE_COURSE);
      if (course.id <= 0) {
        return false;
      }
      course.createdAt = course.createdAt > 0 ? course.createdAt : now;
    }
    course.updatedAt = now;
    const encoded: string = JSON.stringify(course);
    let replaced: boolean = false;
    for (let index: number = 0; index < rows.length; index += 1) {
      const existing: Course | undefined = this.decode(rows[index]);
      if (existing !== undefined && existing.id === course.id) {
        rows[index] = encoded;
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      rows.push(encoded);
    }
    const saved: boolean = DatabaseManager.writeRows(this.context, TABLE_COURSE, rows);
    if (saved) {
      AppLogger.info('Course saved');
    }
    return saved;
  }

  remove(id: number): boolean {
    return this.change(id, undefined, undefined);
  }

  removeMany(ids: number[]): boolean {
    const uniqueIds: number[] = new Array<number>();
    for (let index: number = 0; index < ids.length; index += 1) {
      const id: number = ids[index];
      if (id > 0 && uniqueIds.indexOf(id) < 0) {
        uniqueIds.push(id);
      }
    }
    if (uniqueIds.length === 0) {
      return false;
    }

    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_COURSE);
    const nextRows: string[] = new Array<string>();
    let removedCount: number = 0;
    for (let index: number = 0; index < rows.length; index += 1) {
      const course: Course | undefined = this.decode(rows[index]);
      if (course !== undefined && uniqueIds.indexOf(course.id) >= 0) {
        removedCount += 1;
      } else {
        nextRows.push(rows[index]);
      }
    }
    if (removedCount === 0) {
      return false;
    }
    const saved: boolean = DatabaseManager.writeRows(this.context, TABLE_COURSE, nextRows);
    if (saved) {
      AppLogger.info(`Removed ${removedCount} courses`);
    }
    return saved;
  }

  setEnabled(id: number, enabled: boolean): boolean {
    return this.change(id, enabled, Date.now());
  }

  private change(id: number, enabled: boolean | undefined, updatedAt: number | undefined): boolean {
    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_COURSE);
    const nextRows: string[] = new Array<string>();
    let found: boolean = false;
    for (let index: number = 0; index < rows.length; index += 1) {
      const course: Course | undefined = this.decode(rows[index]);
      if (course !== undefined && course.id === id) {
        found = true;
        if (enabled !== undefined) {
          course.isEnabled = enabled;
          course.updatedAt = updatedAt === undefined ? Date.now() : updatedAt;
          nextRows.push(JSON.stringify(course));
        }
      } else {
        nextRows.push(rows[index]);
      }
    }
    return found && DatabaseManager.writeRows(this.context, TABLE_COURSE, nextRows);
  }

  private decode(value: string): Course | undefined {
    try {
      const raw: Course = JSON.parse(value) as Course;
      if (typeof raw.id !== 'number' || typeof raw.name !== 'string' ||
        typeof raw.dayOfWeek !== 'number' || typeof raw.startMinutes !== 'number' ||
        typeof raw.endMinutes !== 'number') {
        return undefined;
      }
      const course: Course = new Course();
      course.id = raw.id;
      course.name = raw.name;
      course.dayOfWeek = raw.dayOfWeek;
      course.startMinutes = raw.startMinutes;
      course.endMinutes = raw.endMinutes;
      course.location = typeof raw.location === 'string' ? raw.location : '';
      course.teacher = typeof raw.teacher === 'string' ? raw.teacher : '';
      course.validFrom = typeof raw.validFrom === 'number' ? raw.validFrom : 0;
      course.validUntil = typeof raw.validUntil === 'number' ? raw.validUntil : 0;
      course.reminderMinutes = typeof raw.reminderMinutes === 'number' ? raw.reminderMinutes : 30;
      course.isEnabled = typeof raw.isEnabled === 'boolean' ? raw.isEnabled : true;
      course.createdAt = typeof raw.createdAt === 'number' ? raw.createdAt : 0;
      course.updatedAt = typeof raw.updatedAt === 'number' ? raw.updatedAt : 0;
      return course;
    } catch (error) {
      AppLogger.error('Ignored invalid course row', error as Object);
      return undefined;
    }
  }
}

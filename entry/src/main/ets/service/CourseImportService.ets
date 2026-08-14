import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { calendarManager } from '@kit.CalendarKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { AppLogger } from '../common/AppLogger';
import { CourseImportCandidate, CourseImportLoadResult, CourseImportSaveResult } from '../model/CourseImportModels';
import { Course } from '../model/CourseModels';
import { CourseService } from './CourseService';

const DAY_MS: number = 24 * 60 * 60 * 1000;
const CALENDAR_QUERY_PAST_DAYS: number = 180;
const CALENDAR_QUERY_FUTURE_DAYS: number = 180;
const MAX_IMPORT_CANDIDATES: number = 200;
const MAX_VCS_FILE_BYTES: number = 2 * 1024 * 1024;
const CALENDAR_SOURCE: string = 'calendar';
const VCS_SOURCE: string = 'vcs';

class VcsEventData {
  summary: string = '';
  location: string = '';
  description: string = '';
  organizer: string = '';
  attendees: string[] = new Array<string>();
  startValue: string = '';
  endValue: string = '';
  recurrenceRule: string = '';
}

class CourseDateRange {
  validFrom: number = 0;
  validUntil: number = 0;
}

class VcsRecurrenceInfo {
  frequency: string = '';
  interval: number = 1;
  until: number = 0;
  count: number = 0;
  days: number[] = new Array<number>();
}

export class CourseImportService {
  private readonly context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  async loadFromCalendar(): Promise<CourseImportLoadResult> {
    try {
      const permissions: Permissions[] = ['ohos.permission.READ_WHOLE_CALENDAR'];
      const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const permissionResult: PermissionRequestResult =
        await manager.requestPermissionsFromUser(this.context, permissions);
      if (permissionResult.authResults.length === 0 ||
        permissionResult.authResults[0] !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return CourseImportLoadResult.fail('permission_denied');
      }

      const calendarService: calendarManager.CalendarManager = calendarManager.getCalendarManager(this.context);
      const calendars: calendarManager.Calendar[] = await this.getReadableCalendars(calendarService);
      const today: number = new Date(new Date().setHours(0, 0, 0, 0)).getTime();
      const start: number = today - CALENDAR_QUERY_PAST_DAYS * DAY_MS;
      const end: number = today + CALENDAR_QUERY_FUTURE_DAYS * DAY_MS;
      const eventKeys: (keyof calendarManager.Event)[] = ['title', 'location', 'startTime', 'endTime',
        'isAllDay', 'instanceStartTime', 'instanceEndTime', 'description', 'attendee'];
      const baseEventKeys: (keyof calendarManager.Event)[] = ['title', 'location', 'startTime', 'endTime',
        'isAllDay', 'recurrenceRule', 'description', 'attendee'];
      const candidates: CourseImportCandidate[] = new Array<CourseImportCandidate>();
      let queriedCalendarCount: number = 0;
      for (let calendarIndex: number = 0; calendarIndex < calendars.length &&
        candidates.length < MAX_IMPORT_CANDIDATES; calendarIndex += 1) {
        let calendarReadSucceeded: boolean = false;
        try {
          const baseEvents: calendarManager.Event[] =
            await calendars[calendarIndex].getEvents(undefined, baseEventKeys);
          calendarReadSucceeded = true;
          for (let eventIndex: number = 0; eventIndex < baseEvents.length &&
            candidates.length < MAX_IMPORT_CANDIDATES; eventIndex += 1) {
            CourseImportService.appendBaseCalendarEvent(candidates, baseEvents[eventIndex]);
          }
        } catch (error) {
          AppLogger.error('Failed to read base events from a calendar account', error as Object);
        }
        try {
          const instanceEvents: calendarManager.Event[] =
            await calendars[calendarIndex].queryEventInstances(start, end, undefined, eventKeys);
          calendarReadSucceeded = true;
          for (let eventIndex: number = 0; eventIndex < instanceEvents.length &&
            candidates.length < MAX_IMPORT_CANDIDATES; eventIndex += 1) {
            CourseImportService.appendCalendarInstance(candidates, instanceEvents[eventIndex]);
          }
        } catch (error) {
          AppLogger.error('Failed to query event instances from a calendar account', error as Object);
        }
        if (calendarReadSucceeded) {
          queriedCalendarCount += 1;
        }
      }
      if (queriedCalendarCount === 0) {
        return CourseImportLoadResult.fail('calendar_read_failed');
      }
      return CourseImportLoadResult.ok(CALENDAR_SOURCE, candidates);
    } catch (error) {
      AppLogger.error('Failed to read calendar courses', error as Object);
      return CourseImportLoadResult.fail('calendar_read_failed');
    }
  }

  private async getReadableCalendars(manager: calendarManager.CalendarManager):
    Promise<calendarManager.Calendar[]> {
    try {
      const calendars: calendarManager.Calendar[] = await manager.getAllCalendars();
      if (calendars.length > 0) {
        return calendars;
      }
    } catch (error) {
      AppLogger.error('Failed to list calendar accounts, falling back to default calendar', error as Object);
    }
    const fallback: calendarManager.Calendar[] = new Array<calendarManager.Calendar>();
    try {
      fallback.push(await manager.getCalendar());
    } catch (error) {
      AppLogger.error('Failed to open default calendar', error as Object);
    }
    return fallback;
  }

  private static appendBaseCalendarEvent(candidates: CourseImportCandidate[], event: calendarManager.Event): void {
    if (event.isAllDay === true) {
      return;
    }
    const title: string = event.title === undefined ? '' : event.title.trim();
    const location: string = event.location?.location === undefined ? '' : event.location.location.trim();
    const teacher: string = CourseImportService.extractCalendarTeacher(event, location);
    const candidate: CourseImportCandidate | undefined =
      CourseImportService.fromTimedEvent(title, event.startTime, event.endTime, location, teacher);
    if (candidate === undefined) {
      return;
    }
    const recurrenceDays: number[] | undefined = event.recurrenceRule?.daysOfWeek;
    if (event.recurrenceRule === undefined) {
      CourseImportService.appendUnique(candidates, candidate);
      return;
    }
    const sourceDays: number[] = recurrenceDays === undefined || recurrenceDays.length === 0 ?
      [candidate.dayOfWeek] : recurrenceDays;
    const interval: number = event.recurrenceRule.interval === undefined ? 1 : event.recurrenceRule.interval;
    const until: number = event.recurrenceRule.expire === undefined ? 0 : event.recurrenceRule.expire;
    const count: number = event.recurrenceRule.count === undefined ? 0 : event.recurrenceRule.count;
    let appendedRecurrenceDay: boolean = false;
    for (let index: number = 0; index < sourceDays.length &&
      candidates.length < MAX_IMPORT_CANDIDATES; index += 1) {
      const day: number = CourseImportService.normalizeCalendarWeekday(sourceDays[index]);
      if (day < 0) {
        continue;
      }
      const range: CourseDateRange = CourseImportService.weeklyDateRange(event.startTime, day, interval,
        until, count);
      if (range.validFrom <= 0) {
        continue;
      }
      CourseImportService.appendUnique(candidates, CourseImportService.createCandidate(candidate.name, day,
        candidate.startMinutes, candidate.endMinutes, candidate.location, teacher, range.validFrom,
        range.validUntil));
      appendedRecurrenceDay = true;
    }
    if (!appendedRecurrenceDay) {
      CourseImportService.appendUnique(candidates, candidate);
    }
  }

  private static appendCalendarInstance(candidates: CourseImportCandidate[], event: calendarManager.Event): void {
    if (event.isAllDay === true) {
      return;
    }
    const eventStart: number = event.instanceStartTime ?? event.startTime;
    const eventEnd: number = event.instanceEndTime ?? event.endTime;
    const title: string = event.title === undefined ? '' : event.title.trim();
    const location: string = event.location?.location === undefined ? '' : event.location.location.trim();
    const teacher: string = CourseImportService.extractCalendarTeacher(event, location);
    const candidate: CourseImportCandidate | undefined =
      CourseImportService.fromTimedEvent(title, eventStart, eventEnd, location, teacher);
    if (candidate !== undefined) {
      CourseImportService.appendUnique(candidates, candidate);
    }
  }

  private static normalizeCalendarWeekday(day: number): number {
    if (day >= 0 && day <= 6) {
      return day;
    }
    if (day === 7) {
      return 0;
    }
    return -1;
  }

  async loadFromVcs(): Promise<CourseImportLoadResult> {
    try {
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context);
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.fileSuffixFilters = ['日历文件|.vcs,.ics'];
      options.maxSelectNumber = 1;
      const selectedUris: string[] = await documentPicker.select(options);
      if (selectedUris.length === 0) {
        return CourseImportLoadResult.fail('cancelled');
      }
      const content: string = CourseImportService.readUtf8FileUri(selectedUris[0]);
      if (content.length === 0) {
        return CourseImportLoadResult.fail('vcs_read_failed');
      }
      return CourseImportLoadResult.ok(VCS_SOURCE, CourseImportService.parseVcs(content));
    } catch (error) {
      AppLogger.error('Failed to read VCS course file', error as Object);
      return CourseImportLoadResult.fail('vcs_read_failed');
    }
  }

  private static readUtf8FileUri(uri: string): string {
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const size: number = fileIo.statSync(file.fd).size;
      if (size <= 0 || size > MAX_VCS_FILE_BYTES) {
        return '';
      }
      const buffer: ArrayBuffer = new ArrayBuffer(size);
      const readLength: number = fileIo.readSync(file.fd, buffer, { length: size });
      if (readLength <= 0) {
        return '';
      }
      const bytes: Uint8Array = new Uint8Array(buffer, 0, readLength);
      return util.TextDecoder.create('utf-8').decodeToString(bytes);
    } catch (error) {
      AppLogger.error('Failed to read selected VCS file URI', error as Object);
      return '';
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file);
        } catch (_) {
        }
      }
    }
  }

  importCandidates(candidates: CourseImportCandidate[]): CourseImportSaveResult {
    const result: CourseImportSaveResult = new CourseImportSaveResult();
    const courseService: CourseService = new CourseService(this.context);
    const existing: Course[] = courseService.listCourses();

    for (let index: number = 0; index < candidates.length; index += 1) {
      const candidate: CourseImportCandidate = candidates[index];
      let mergeTarget: Course | undefined = undefined;
      for (let existingIndex: number = 0; existingIndex < existing.length; existingIndex += 1) {
        const course: Course = existing[existingIndex];
        if (CourseImportService.sameSchedule(course, candidate) &&
          CourseImportService.rangesCanMerge(course.validFrom, course.validUntil,
            candidate.validFrom, candidate.validUntil)) {
          mergeTarget = course;
          break;
        }
      }
      if (mergeTarget !== undefined) {
        let changed: boolean = false;
        if (mergeTarget.validFrom <= 0 && mergeTarget.validUntil <= 0 && candidate.validFrom > 0) {
          mergeTarget.validFrom = candidate.validFrom;
          mergeTarget.validUntil = candidate.validUntil;
          changed = true;
        } else {
          const mergedStart: number = CourseImportService.earliestDate(mergeTarget.validFrom, candidate.validFrom);
          const mergedEnd: number = CourseImportService.latestEndDate(mergeTarget.validUntil, candidate.validUntil);
          if (mergedStart !== mergeTarget.validFrom || mergedEnd !== mergeTarget.validUntil) {
            mergeTarget.validFrom = mergedStart;
            mergeTarget.validUntil = mergedEnd;
            changed = true;
          }
        }
        if (mergeTarget.teacher.length === 0 && candidate.teacher.length > 0) {
          mergeTarget.teacher = candidate.teacher;
          changed = true;
        }
        if (!changed) {
          result.skippedCount += 1;
        } else if (courseService.saveCourse(mergeTarget).success) {
          result.importedCount += 1;
        } else {
          result.failedCount += 1;
        }
        continue;
      }
      const course: Course = Course.create(candidate.name, candidate.dayOfWeek, candidate.startMinutes,
        candidate.endMinutes, candidate.location, candidate.teacher, candidate.reminderMinutes);
      course.validFrom = candidate.validFrom;
      course.validUntil = candidate.validUntil;
      if (courseService.saveCourse(course).success) {
        existing.push(course);
        result.importedCount += 1;
      } else {
        result.failedCount += 1;
      }
    }
    return result;
  }

  static parseVcs(content: string): CourseImportCandidate[] {
    const unfoldedLines: string[] = CourseImportService.unfoldLines(content);
    const candidates: CourseImportCandidate[] = new Array<CourseImportCandidate>();
    let current: VcsEventData | undefined = undefined;
    for (let index: number = 0; index < unfoldedLines.length; index += 1) {
      const line: string = unfoldedLines[index].trim();
      if (line.toUpperCase() === 'BEGIN:VEVENT') {
        current = new VcsEventData();
        continue;
      }
      if (line.toUpperCase() === 'END:VEVENT') {
        if (current !== undefined) {
          CourseImportService.appendVcsEvent(candidates, current);
        }
        current = undefined;
        if (candidates.length >= MAX_IMPORT_CANDIDATES) {
          break;
        }
        continue;
      }
      if (current === undefined) {
        continue;
      }
      const separator: number = line.indexOf(':');
      if (separator <= 0) {
        continue;
      }
      const propertyParts: string[] = line.substring(0, separator).split(';');
      const propertyName: string = propertyParts[0].toUpperCase();
      const propertyValue: string = line.substring(separator + 1);
      if (propertyName === 'SUMMARY') current.summary = CourseImportService.unescapeText(propertyValue);
      if (propertyName === 'LOCATION') current.location = CourseImportService.unescapeText(propertyValue);
      if (propertyName === 'DESCRIPTION') current.description = CourseImportService.unescapeDescription(propertyValue);
      if (propertyName === 'ORGANIZER') {
        current.organizer = CourseImportService.personNameFromProperty(propertyParts, propertyValue);
      }
      if (propertyName === 'ATTENDEE') {
        const attendee: string = CourseImportService.personNameFromProperty(propertyParts, propertyValue);
        if (attendee.length > 0 && current.attendees.indexOf(attendee) < 0) {
          current.attendees.push(attendee);
        }
      }
      if (propertyName === 'DTSTART') current.startValue = propertyValue;
      if (propertyName === 'DTEND') current.endValue = propertyValue;
      if (propertyName === 'RRULE') current.recurrenceRule = propertyValue;
    }
    return candidates;
  }

  private static appendVcsEvent(candidates: CourseImportCandidate[], event: VcsEventData): void {
    const start: number = CourseImportService.parseVcsDate(event.startValue);
    const end: number = CourseImportService.parseVcsDate(event.endValue);
    if (event.summary.trim().length === 0 || start <= 0 || end <= start) {
      return;
    }
    const startDate: Date = new Date(start);
    const endDate: Date = new Date(end);
    if (startDate.getFullYear() !== endDate.getFullYear() || startDate.getMonth() !== endDate.getMonth() ||
      startDate.getDate() !== endDate.getDate()) {
      return;
    }
    const startMinutes: number = startDate.getHours() * 60 + startDate.getMinutes();
    const endMinutes: number = endDate.getHours() * 60 + endDate.getMinutes();
    if (startMinutes >= endMinutes) {
      return;
    }
    const people: string[] = new Array<string>();
    if (event.organizer.length > 0) {
      people.push(event.organizer);
    } else if (event.attendees.length === 1) {
      people.push(event.attendees[0]);
    }
    const teacher: string = CourseImportService.extractTeacher(event.description, event.location, people);
    const recurrence: VcsRecurrenceInfo = CourseImportService.parseRecurrence(event.recurrenceRule);
    const isWeekly: boolean = recurrence.frequency === 'WEEKLY' ||
      event.recurrenceRule.trim().toUpperCase().startsWith('W');
    const days: number[] = isWeekly && recurrence.days.length > 0 ? recurrence.days : [startDate.getDay()];
    for (let index: number = 0; index < days.length && candidates.length < MAX_IMPORT_CANDIDATES; index += 1) {
      const range: CourseDateRange = isWeekly ?
        CourseImportService.weeklyDateRange(start, days[index], recurrence.interval, recurrence.until,
          recurrence.count) : CourseImportService.singleDateRange(start);
      if (range.validFrom <= 0) {
        continue;
      }
      const candidate: CourseImportCandidate = CourseImportService.createCandidate(event.summary.trim(), days[index],
        startMinutes, endMinutes, event.location.trim(), teacher, range.validFrom, range.validUntil);
      CourseImportService.appendUnique(candidates, candidate);
    }
  }

  private static fromTimedEvent(title: string, start: number, end: number,
    location: string, teacher: string): CourseImportCandidate | undefined {
    if (title.length === 0 || start <= 0 || end <= start) {
      return undefined;
    }
    const startDate: Date = new Date(start);
    const endDate: Date = new Date(end);
    if (startDate.getFullYear() !== endDate.getFullYear() || startDate.getMonth() !== endDate.getMonth() ||
      startDate.getDate() !== endDate.getDate()) {
      return undefined;
    }
    const startMinutes: number = startDate.getHours() * 60 + startDate.getMinutes();
    const endMinutes: number = endDate.getHours() * 60 + endDate.getMinutes();
    if (startMinutes >= endMinutes) {
      return undefined;
    }
    const eventDate: number = CourseImportService.dayStart(start);
    return CourseImportService.createCandidate(title, startDate.getDay(), startMinutes, endMinutes, location,
      teacher, eventDate, eventDate);
  }

  private static createCandidate(name: string, day: number, startMinutes: number, endMinutes: number,
    location: string, teacher: string, validFrom: number, validUntil: number): CourseImportCandidate {
    const candidate: CourseImportCandidate = new CourseImportCandidate();
    candidate.name = name;
    candidate.dayOfWeek = day;
    candidate.startMinutes = startMinutes;
    candidate.endMinutes = endMinutes;
    candidate.location = location;
    candidate.teacher = teacher;
    candidate.validFrom = validFrom;
    candidate.validUntil = validUntil;
    candidate.key = CourseImportService.courseKey(name, day, startMinutes, endMinutes, location,
      validFrom, validUntil);
    return candidate;
  }

  private static appendUnique(candidates: CourseImportCandidate[], candidate: CourseImportCandidate): void {
    for (let index: number = 0; index < candidates.length; index += 1) {
      const existing: CourseImportCandidate = candidates[index];
      if (CourseImportService.sameCandidateSchedule(existing, candidate) &&
        CourseImportService.rangesCanMerge(existing.validFrom, existing.validUntil,
          candidate.validFrom, candidate.validUntil)) {
        existing.validFrom = CourseImportService.earliestDate(existing.validFrom, candidate.validFrom);
        existing.validUntil = CourseImportService.latestEndDate(existing.validUntil, candidate.validUntil);
        if (existing.teacher.length === 0 && candidate.teacher.length > 0) {
          existing.teacher = candidate.teacher;
        }
        existing.key = CourseImportService.courseKey(existing.name, existing.dayOfWeek, existing.startMinutes,
          existing.endMinutes, existing.location, existing.validFrom, existing.validUntil);
        return;
      }
    }
    candidates.push(candidate);
  }

  private static courseKey(name: string, day: number, startMinutes: number, endMinutes: number,
    location: string, validFrom: number, validUntil: number): string {
    return `${CourseImportService.scheduleKey(name, day, startMinutes, endMinutes, location)}` +
      `|${validFrom}|${validUntil}`;
  }

  private static scheduleKey(name: string, day: number, startMinutes: number, endMinutes: number,
    location: string): string {
    return `${name.trim().toLowerCase()}|${day}|${startMinutes}|${endMinutes}|${location.trim().toLowerCase()}`;
  }

  private static sameCandidateSchedule(left: CourseImportCandidate, right: CourseImportCandidate): boolean {
    return CourseImportService.scheduleKey(left.name, left.dayOfWeek, left.startMinutes, left.endMinutes,
      left.location) === CourseImportService.scheduleKey(right.name, right.dayOfWeek, right.startMinutes,
      right.endMinutes, right.location);
  }

  private static sameSchedule(course: Course, candidate: CourseImportCandidate): boolean {
    return CourseImportService.scheduleKey(course.name, course.dayOfWeek, course.startMinutes, course.endMinutes,
      course.location) === CourseImportService.scheduleKey(candidate.name, candidate.dayOfWeek,
      candidate.startMinutes, candidate.endMinutes, candidate.location);
  }

  private static rangesCanMerge(leftStart: number, leftEnd: number, rightStart: number, rightEnd: number): boolean {
    if ((leftStart <= 0 && leftEnd <= 0) || (rightStart <= 0 && rightEnd <= 0) ||
      leftEnd <= 0 || rightEnd <= 0) {
      return true;
    }
    return rightStart <= leftEnd + 7 * DAY_MS && leftStart <= rightEnd + 7 * DAY_MS;
  }

  private static earliestDate(left: number, right: number): number {
    if (left <= 0) return right;
    if (right <= 0) return left;
    return Math.min(left, right);
  }

  private static latestEndDate(left: number, right: number): number {
    if (left <= 0 || right <= 0) return 0;
    return Math.max(left, right);
  }

  private static unfoldLines(content: string): string[] {
    const rawLines: string[] = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
    const lines: string[] = new Array<string>();
    for (let index: number = 0; index < rawLines.length; index += 1) {
      const line: string = rawLines[index];
      if ((line.startsWith(' ') || line.startsWith('\t')) && lines.length > 0) {
        lines[lines.length - 1] = lines[lines.length - 1] + line.substring(1);
      } else {
        lines.push(line);
      }
    }
    return lines;
  }

  private static unescapeText(value: string): string {
    return value.replace(/\\n/gi, ' ').replace(/\\,/g, ',').replace(/\\;/g, ';').replace(/\\\\/g, '\\').trim();
  }

  private static unescapeDescription(value: string): string {
    return value.replace(/\\n/gi, '\n').replace(/\\,/g, ',').replace(/\\;/g, ';').replace(/\\\\/g, '\\').trim();
  }

  private static personNameFromProperty(parts: string[], value: string): string {
    for (let index: number = 1; index < parts.length; index += 1) {
      const parameter: string = parts[index];
      const separator: number = parameter.indexOf('=');
      if (separator > 0 && parameter.substring(0, separator).trim().toUpperCase() === 'CN') {
        return CourseImportService.cleanTeacherName(parameter.substring(separator + 1));
      }
    }
    const fallback: string = CourseImportService.unescapeText(value).replace(/^mailto:/i, '');
    return fallback.indexOf('@') >= 0 ? '' : CourseImportService.cleanTeacherName(fallback);
  }

  private static extractCalendarTeacher(event: calendarManager.Event, location: string): string {
    const people: string[] = new Array<string>();
    const attendees: calendarManager.Attendee[] = event.attendee === undefined ?
      new Array<calendarManager.Attendee>() : event.attendee;
    for (let index: number = 0; index < attendees.length; index += 1) {
      if (attendees[index].role === calendarManager.AttendeeRole.ORGANIZER && attendees[index].name.trim().length > 0) {
        people.push(attendees[index].name.trim());
      }
    }
    if (people.length === 0 && attendees.length === 1 && attendees[0].name.trim().length > 0) {
      people.push(attendees[0].name.trim());
    }
    return CourseImportService.extractTeacher(event.description === undefined ? '' : event.description,
      location, people);
  }

  private static extractTeacher(description: string, location: string, people: string[]): string {
    const normalized: string = description.replace(/\\n/gi, '\n').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    const lines: string[] = normalized.split('\n');
    const labels: string[] = ['授课教师', '任课教师', '主讲教师', '教师', '老师', '讲师'];
    for (let lineIndex: number = 0; lineIndex < lines.length; lineIndex += 1) {
      const line: string = lines[lineIndex].trim();
      for (let labelIndex: number = 0; labelIndex < labels.length; labelIndex += 1) {
        const position: number = line.indexOf(labels[labelIndex]);
        if (position < 0 || position > 2) {
          continue;
        }
        const named: string = CourseImportService.cleanTeacherName(
          line.substring(position + labels[labelIndex].length).replace(/^[\s:：-]+/, ''));
        if (CourseImportService.looksLikeTeacherName(named)) {
          return named;
        }
      }
    }
    for (let index: number = 0; index < people.length; index += 1) {
      const named: string = CourseImportService.cleanTeacherName(people[index]);
      if (named.length > 0) {
        return named;
      }
    }
    for (let index: number = 0; index < lines.length; index += 1) {
      const line: string = CourseImportService.cleanTeacherName(lines[index]);
      if (line.length === 0 || line === location || line.indexOf('学分') >= 0 ||
        (line.indexOf('第') >= 0 && line.indexOf('周') >= 0) || line.indexOf('学院') >= 0 ||
        line.indexOf('大学') >= 0 || line.indexOf('课程') >= 0 || line.indexOf('教室') >= 0 ||
        line.indexOf('校区') >= 0 || line.indexOf('实验室') >= 0) {
        continue;
      }
      if (CourseImportService.looksLikeTeacherName(line)) {
        return line;
      }
    }
    return '';
  }

  private static cleanTeacherName(value: string): string {
    return CourseImportService.unescapeText(value).replace(/^mailto:/i, '').replace(/["']/g, '')
      .replace(/[，、;；/]+/g, ',').replace(/\s*,\s*/g, ',').replace(/\s+/g, ' ').trim()
      .replace(/(老师|教师)$/g, '').trim();
  }

  private static looksLikeTeacherName(value: string): boolean {
    const compact: string = value.replace(/\s+/g, '');
    return /^[\u3400-\u9fff·•]{2,12}([,][\u3400-\u9fff·•]{2,12})*$/.test(compact);
  }

  private static parseVcsDate(value: string): number {
    const normalized: string = value.trim();
    const timeSeparator: number = normalized.indexOf('T');
    if (timeSeparator < 0 && normalized.length === 8) {
      const year: number = Number.parseInt(normalized.substring(0, 4));
      const month: number = Number.parseInt(normalized.substring(4, 6));
      const day: number = Number.parseInt(normalized.substring(6, 8));
      const date: Date = new Date(year, month - 1, day, 0, 0, 0, 0);
      if (Number.isNaN(year) || Number.isNaN(month) || Number.isNaN(day) || date.getFullYear() !== year ||
        date.getMonth() !== month - 1 || date.getDate() !== day) {
        return 0;
      }
      return date.getTime();
    }
    if (timeSeparator !== 8 || normalized.length < 13) {
      return 0;
    }
    const year: number = Number.parseInt(normalized.substring(0, 4));
    const month: number = Number.parseInt(normalized.substring(4, 6));
    const day: number = Number.parseInt(normalized.substring(6, 8));
    const hour: number = Number.parseInt(normalized.substring(9, 11));
    const minute: number = Number.parseInt(normalized.substring(11, 13));
    const second: number = normalized.length >= 15 ? Number.parseInt(normalized.substring(13, 15)) : 0;
    if (Number.isNaN(year) || Number.isNaN(month) || Number.isNaN(day) || Number.isNaN(hour) ||
      Number.isNaN(minute) || Number.isNaN(second) || month < 1 || month > 12 || day < 1 || day > 31 ||
      hour < 0 || hour > 23 || minute < 0 || minute > 59 || second < 0 || second > 59) {
      return 0;
    }
    const isUtc: boolean = normalized.endsWith('Z');
    const timestamp: number = isUtc ? Date.UTC(year, month - 1, day, hour, minute, second, 0) :
      new Date(year, month - 1, day, hour, minute, second, 0).getTime();
    const parsed: Date = new Date(timestamp);
    if ((isUtc ? parsed.getUTCFullYear() : parsed.getFullYear()) !== year ||
      (isUtc ? parsed.getUTCMonth() : parsed.getMonth()) !== month - 1 ||
      (isUtc ? parsed.getUTCDate() : parsed.getDate()) !== day) {
      return 0;
    }
    return timestamp;
  }

  private static parseRecurrence(rule: string): VcsRecurrenceInfo {
    const info: VcsRecurrenceInfo = new VcsRecurrenceInfo();
    const trimmed: string = rule.trim();
    if (trimmed.length === 0) {
      return info;
    }
    if (trimmed.toUpperCase().startsWith('W')) {
      info.frequency = 'WEEKLY';
      const legacyParts: string[] = trimmed.split(' ');
      for (let index: number = 1; index < legacyParts.length; index += 1) {
        const legacyCode: string = legacyParts[index].trim().toUpperCase();
        if (legacyCode.startsWith('#')) {
          const count: number = Number.parseInt(legacyCode.substring(1));
          info.count = Number.isNaN(count) ? 0 : count;
          break;
        }
        const mapped: number = CourseImportService.weekdayCode(legacyCode);
        if (mapped >= 0 && info.days.indexOf(mapped) < 0) {
          info.days.push(mapped);
        }
      }
      return info;
    }
    const sections: string[] = trimmed.split(';');
    let byDay: string = '';
    for (let index: number = 0; index < sections.length; index += 1) {
      const section: string = sections[index];
      const separator: number = section.indexOf('=');
      if (separator <= 0) continue;
      const name: string = section.substring(0, separator).trim().toUpperCase();
      const value: string = section.substring(separator + 1).trim();
      if (name === 'FREQ') info.frequency = value.toUpperCase();
      if (name === 'BYDAY') byDay = value;
      if (name === 'INTERVAL') {
        const interval: number = Number.parseInt(value);
        info.interval = Number.isNaN(interval) || interval <= 0 ? 1 : interval;
      }
      if (name === 'COUNT') {
        const count: number = Number.parseInt(value);
        info.count = Number.isNaN(count) || count <= 0 ? 0 : count;
      }
      if (name === 'UNTIL') {
        info.until = CourseImportService.parseVcsDate(value);
        if (value.length === 8 && info.until > 0) {
          info.until += DAY_MS - 1;
        }
      }
    }
    const tokens: string[] = byDay.split(',');
    for (let index: number = 0; index < tokens.length; index += 1) {
      const token: string = tokens[index].trim().toUpperCase();
      const code: string = token.length >= 2 ? token.substring(token.length - 2) : token;
      const mapped: number = CourseImportService.weekdayCode(code);
      if (mapped >= 0 && info.days.indexOf(mapped) < 0) {
        info.days.push(mapped);
      }
    }
    return info;
  }

  private static singleDateRange(timestamp: number): CourseDateRange {
    const range: CourseDateRange = new CourseDateRange();
    range.validFrom = CourseImportService.dayStart(timestamp);
    range.validUntil = range.validFrom;
    return range;
  }

  private static weeklyDateRange(start: number, dayOfWeek: number, intervalValue: number,
    until: number, count: number): CourseDateRange {
    const range: CourseDateRange = new CourseDateRange();
    const interval: number = intervalValue <= 0 ? 1 : intervalValue;
    const first: number = CourseImportService.firstOccurrence(start, dayOfWeek);
    if (first <= 0 || (until > 0 && first > until)) {
      return range;
    }
    range.validFrom = CourseImportService.dayStart(first);
    if (count > 0) {
      let lastByCount: number = first;
      for (let index: number = 1; index < count && index < 1000; index += 1) {
        lastByCount = CourseImportService.addDays(lastByCount, interval * 7);
      }
      range.validUntil = CourseImportService.dayStart(lastByCount);
      return range;
    }
    if (until <= 0) {
      range.validUntil = 0;
      return range;
    }
    let last: number = first;
    for (let index: number = 0; index < 1000; index += 1) {
      const next: number = CourseImportService.addDays(last, interval * 7);
      if (next > until) {
        break;
      }
      last = next;
    }
    range.validUntil = CourseImportService.dayStart(last);
    return range;
  }

  private static firstOccurrence(start: number, dayOfWeek: number): number {
    const date: Date = new Date(start);
    const offset: number = (dayOfWeek - date.getDay() + 7) % 7;
    date.setDate(date.getDate() + offset);
    return date.getTime();
  }

  private static addDays(timestamp: number, days: number): number {
    const date: Date = new Date(timestamp);
    date.setDate(date.getDate() + days);
    return date.getTime();
  }

  private static dayStart(timestamp: number): number {
    const date: Date = new Date(timestamp);
    date.setHours(0, 0, 0, 0);
    return date.getTime();
  }

  private static weekdayCode(code: string): number {
    if (code === 'SU') return 0;
    if (code === 'MO') return 1;
    if (code === 'TU') return 2;
    if (code === 'WE') return 3;
    if (code === 'TH') return 4;
    if (code === 'FR') return 5;
    if (code === 'SA') return 6;
    return -1;
  }
}

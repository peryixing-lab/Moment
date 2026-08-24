import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo, picker } from '@kit.CoreFileKit';
import { AppLogger } from '../common/AppLogger';
import { BackupCounts, BackupResult } from '../model/BackupModels';
import { Course } from '../model/CourseModels';
import { CourseImportCandidate } from '../model/CourseImportModels';
import { SceneContextRule, SceneContextTriggerType } from '../model/SceneContextModels';
import { SceneRule } from '../model/SceneRuleModels';
import { SceneType, SceneTypeCodec } from '../model/SceneType';
import { LocalTask } from '../model/TaskModels';
import { CourseImportService } from './CourseImportService';
import { CourseService } from './CourseService';
import { SceneContextRuleService } from './SceneContextRuleService';
import { SceneRuleService } from './SceneRuleService';
import { TaskService } from './TaskService';

export const BACKUP_FORMAT: string = 'MomentBackup';
export const BACKUP_VERSION: number = 1;
const MAX_BACKUP_FILE_BYTES: number = 8 * 1024 * 1024;

class BackupEnvelope {
  format: string = BACKUP_FORMAT;
  version: number = BACKUP_VERSION;
  exportedAt: number = 0;
  courses: Course[] = new Array<Course>();
  tasks: LocalTask[] = new Array<LocalTask>();
  sceneRules: SceneRule[] = new Array<SceneRule>();
  sceneContextRules: SceneContextRule[] = new Array<SceneContextRule>();
}

export class BackupService {
  static async exportToFile(context: common.Context): Promise<BackupResult> {
    try {
      const envelope: BackupEnvelope = BackupService.collect(context);
      const text: string = JSON.stringify(envelope);
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      options.newFileNames = [BackupService.suggestedFileName()];
      options.fileSuffixChoices = ['JSON|.json'];
      const uris: string[] = await documentPicker.save(options);
      if (uris.length === 0 || uris[0].length === 0) {
        return BackupResult.fail('cancelled');
      }
      if (!BackupService.writeTextFile(uris[0], text)) {
        return BackupResult.fail('write_failed');
      }
      const result: BackupResult = BackupResult.ok('exported');
      result.exportedCourseCount = envelope.courses.length;
      result.exportedTaskCount = envelope.tasks.length;
      result.exportedRuleCount = envelope.sceneRules.length + envelope.sceneContextRules.length;
      return result;
    } catch (error) {
      AppLogger.error('Unable to export backup', error as Object);
      return BackupResult.fail('export_failed');
    }
  }

  static async importFromFile(context: common.Context): Promise<BackupResult> {
    try {
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.fileSuffixFilters = ['JSON|.json'];
      options.maxSelectNumber = 1;
      const selectedUris: string[] = await documentPicker.select(options);
      if (selectedUris.length === 0) {
        return BackupResult.fail('cancelled');
      }
      const content: string = BackupService.readUtf8FileUri(selectedUris[0]);
      if (content.length === 0) {
        return BackupResult.fail('read_failed');
      }
      const envelope: BackupEnvelope | undefined = BackupService.parseEnvelope(content);
      if (envelope === undefined) {
        return BackupResult.fail('invalid_file');
      }
      return BackupService.apply(context, envelope);
    } catch (error) {
      AppLogger.error('Unable to import backup', error as Object);
      return BackupResult.fail('import_failed');
    }
  }

  private static collect(context: common.Context): BackupEnvelope {
    const envelope: BackupEnvelope = new BackupEnvelope();
    envelope.exportedAt = Date.now();
    envelope.courses = new CourseService(context).listCourses();
    envelope.tasks = new TaskService(context).listTasks(true);
    envelope.sceneRules = new SceneRuleService(context).listRules();
    envelope.sceneContextRules = new SceneContextRuleService(context).listRules();
    return envelope;
  }

  private static parseEnvelope(content: string): BackupEnvelope | undefined {
    try {
      const raw: Record<string, Object> = JSON.parse(content) as Record<string, Object>;
      if (raw['format'] !== BACKUP_FORMAT) {
        return undefined;
      }
      const version: number = typeof raw['version'] === 'number' ? raw['version'] : 0;
      if (version < 0 || version > BACKUP_VERSION) {
        return undefined;
      }
      const envelope: BackupEnvelope = new BackupEnvelope();
      envelope.exportedAt = typeof raw['exportedAt'] === 'number' ? raw['exportedAt'] : 0;
      envelope.courses = BackupService.decodeCourses(raw['courses']);
      envelope.tasks = BackupService.decodeTasks(raw['tasks']);
      envelope.sceneRules = BackupService.decodeSceneRules(raw['sceneRules']);
      envelope.sceneContextRules = BackupService.decodeSceneContextRules(raw['sceneContextRules']);
      return envelope;
    } catch (error) {
      AppLogger.error('Backup file is not valid JSON', error as Object);
      return undefined;
    }
  }

  private static decodeCourses(value: Object | undefined): Course[] {
    const courses: Course[] = new Array<Course>();
    if (!(value instanceof Array)) {
      return courses;
    }
    for (let index: number = 0; index < value.length; index += 1) {
      const raw: Record<string, Object> = value[index] as Record<string, Object>;
      const course: Course = new Course();
      course.id = typeof raw['id'] === 'number' ? raw['id'] : 0;
      course.name = typeof raw['name'] === 'string' ? raw['name'] : '';
      course.dayOfWeek = typeof raw['dayOfWeek'] === 'number' ? raw['dayOfWeek'] : 1;
      course.startMinutes = typeof raw['startMinutes'] === 'number' ? raw['startMinutes'] : 540;
      course.endMinutes = typeof raw['endMinutes'] === 'number' ? raw['endMinutes'] : 600;
      course.location = typeof raw['location'] === 'string' ? raw['location'] : '';
      course.teacher = typeof raw['teacher'] === 'string' ? raw['teacher'] : '';
      course.validFrom = typeof raw['validFrom'] === 'number' ? raw['validFrom'] : 0;
      course.validUntil = typeof raw['validUntil'] === 'number' ? raw['validUntil'] : 0;
      course.reminderMinutes = typeof raw['reminderMinutes'] === 'number' ? raw['reminderMinutes'] : 30;
      course.isEnabled = typeof raw['isEnabled'] === 'boolean' ? raw['isEnabled'] : true;
      course.createdAt = typeof raw['createdAt'] === 'number' ? raw['createdAt'] : 0;
      course.updatedAt = typeof raw['updatedAt'] === 'number' ? raw['updatedAt'] : 0;
      courses.push(course);
    }
    return courses;
  }

  private static decodeTasks(value: Object | undefined): LocalTask[] {
    const tasks: LocalTask[] = new Array<LocalTask>();
    if (!(value instanceof Array)) {
      return tasks;
    }
    for (let index: number = 0; index < value.length; index += 1) {
      const raw: Record<string, Object> = value[index] as Record<string, Object>;
      const task: LocalTask = new LocalTask();
      task.id = typeof raw['id'] === 'number' ? raw['id'] : 0;
      task.title = typeof raw['title'] === 'string' ? raw['title'] : '';
      task.description = typeof raw['description'] === 'string' ? raw['description'] : '';
      task.dueAt = typeof raw['dueAt'] === 'number' ? raw['dueAt'] : 0;
      task.priority = typeof raw['priority'] === 'number' ? raw['priority'] : 2;
      task.sceneType = typeof raw['sceneType'] === 'string' ? raw['sceneType'] as SceneType : undefined;
      task.isCompleted = typeof raw['isCompleted'] === 'boolean' ? raw['isCompleted'] : false;
      task.completedAt = typeof raw['completedAt'] === 'number' ? raw['completedAt'] : 0;
      task.createdAt = typeof raw['createdAt'] === 'number' ? raw['createdAt'] : 0;
      task.updatedAt = typeof raw['updatedAt'] === 'number' ? raw['updatedAt'] : 0;
      tasks.push(task);
    }
    return tasks;
  }

  private static decodeSceneRules(value: Object | undefined): SceneRule[] {
    const rules: SceneRule[] = new Array<SceneRule>();
    if (!(value instanceof Array)) {
      return rules;
    }
    for (let index: number = 0; index < value.length; index += 1) {
      const raw: Record<string, Object> = value[index] as Record<string, Object>;
      const rule: SceneRule = new SceneRule();
      rule.id = typeof raw['id'] === 'number' ? raw['id'] : 0;
      rule.name = typeof raw['name'] === 'string' ? raw['name'] : '';
      rule.sceneType = typeof raw['sceneType'] === 'string' ?
        SceneTypeCodec.fromStorage(raw['sceneType'], SceneType.LIBRARY) : SceneType.LIBRARY;
      const days: Object | undefined = raw['daysOfWeek'];
      if (days instanceof Array) {
        for (let i: number = 0; i < days.length; i += 1) {
          if (typeof days[i] === 'number') {
            rule.daysOfWeek.push(days[i] as number);
          }
        }
      }
      rule.startMinutes = typeof raw['startMinutes'] === 'number' ? raw['startMinutes'] : 540;
      rule.endMinutes = typeof raw['endMinutes'] === 'number' ? raw['endMinutes'] : 600;
      rule.priority = typeof raw['priority'] === 'number' ? raw['priority'] : 10;
      rule.isEnabled = typeof raw['isEnabled'] === 'boolean' ? raw['isEnabled'] : true;
      rule.createdAt = typeof raw['createdAt'] === 'number' ? raw['createdAt'] : 0;
      rule.updatedAt = typeof raw['updatedAt'] === 'number' ? raw['updatedAt'] : 0;
      rules.push(rule);
    }
    return rules;
  }

  private static decodeSceneContextRules(value: Object | undefined): SceneContextRule[] {
    const rules: SceneContextRule[] = new Array<SceneContextRule>();
    if (!(value instanceof Array)) {
      return rules;
    }
    for (let index: number = 0; index < value.length; index += 1) {
      const raw: Record<string, Object> = value[index] as Record<string, Object>;
      const rule: SceneContextRule = new SceneContextRule();
      rule.id = typeof raw['id'] === 'number' ? raw['id'] : 0;
      rule.name = typeof raw['name'] === 'string' ? raw['name'] : '';
      rule.sceneType = typeof raw['sceneType'] === 'string' ?
        SceneTypeCodec.fromStorage(raw['sceneType'], SceneType.LIBRARY) : SceneType.LIBRARY;
      rule.triggerType = typeof raw['triggerType'] === 'string' ? raw['triggerType'] as SceneContextTriggerType : SceneContextTriggerType.WIFI;
      rule.wifiSsid = typeof raw['wifiSsid'] === 'string' ? raw['wifiSsid'] : '';
      rule.addressName = typeof raw['addressName'] === 'string' ? raw['addressName'] : '';
      rule.latitude = typeof raw['latitude'] === 'number' ? raw['latitude'] : 0;
      rule.longitude = typeof raw['longitude'] === 'number' ? raw['longitude'] : 0;
      rule.radiusMeters = typeof raw['radiusMeters'] === 'number' ? raw['radiusMeters'] : 300;
      rule.autoSwitchEnabled = typeof raw['autoSwitchEnabled'] === 'boolean' ? raw['autoSwitchEnabled'] : false;
      rule.isEnabled = typeof raw['isEnabled'] === 'boolean' ? raw['isEnabled'] : true;
      rule.createdAt = typeof raw['createdAt'] === 'number' ? raw['createdAt'] : 0;
      rule.updatedAt = typeof raw['updatedAt'] === 'number' ? raw['updatedAt'] : 0;
      rules.push(rule);
    }
    return rules;
  }

  private static apply(context: common.Context, envelope: BackupEnvelope): BackupResult {
    const result: BackupResult = BackupResult.ok('imported');
    result.importedCourses = new CourseImportService(context).importCandidates(
      BackupService.courseCandidates(envelope.courses)).importedCount;
    const taskResult: BackupCounts = BackupService.importTasks(context, envelope.tasks);
    result.importedTasks = taskResult.imported;
    result.skippedTasks = taskResult.skipped;
    result.failedTasks = taskResult.failed;
    const ruleResult: BackupCounts =
      BackupService.importRules(context, envelope.sceneRules, envelope.sceneContextRules);
    result.importedRules = ruleResult.imported;
    result.skippedRules = ruleResult.skipped;
    result.failedRules = ruleResult.failed;
    return result;
  }

  private static courseCandidates(courses: Course[]): CourseImportCandidate[] {
    const candidates: CourseImportCandidate[] = new Array<CourseImportCandidate>();
    for (let index: number = 0; index < courses.length; index += 1) {
      const course: Course = courses[index];
      const candidate: CourseImportCandidate = new CourseImportCandidate();
      candidate.name = course.name;
      candidate.dayOfWeek = course.dayOfWeek;
      candidate.startMinutes = course.startMinutes;
      candidate.endMinutes = course.endMinutes;
      candidate.location = course.location;
      candidate.teacher = course.teacher;
      candidate.validFrom = course.validFrom;
      candidate.validUntil = course.validUntil;
      candidate.reminderMinutes = course.reminderMinutes;
      candidates.push(candidate);
    }
    return candidates;
  }

  private static importTasks(
    context: common.Context, tasks: LocalTask[]): BackupCounts {
    const counts: BackupCounts = new BackupCounts();
    const service: TaskService = new TaskService(context);
    const existingTitles: Set<string> = new Set<string>();
    const existing: LocalTask[] = service.listTasks(true);
    for (let index: number = 0; index < existing.length; index += 1) {
      existingTitles.add(existing[index].title.trim());
    }
    for (let index: number = 0; index < tasks.length; index += 1) {
      const task: LocalTask = tasks[index];
      const title: string = task.title.trim();
      if (title.length === 0 || existingTitles.has(title)) {
        counts.skipped += 1;
        continue;
      }
      task.id = 0;
      task.title = title;
      task.updatedAt = 0;
      if (service.saveTask(task).success) {
        counts.imported += 1;
        existingTitles.add(title);
      } else {
        counts.failed += 1;
      }
    }
    return counts;
  }

  private static importRules(
    context: common.Context, sceneRules: SceneRule[],
    sceneContextRules: SceneContextRule[]): BackupCounts {
    const counts: BackupCounts = new BackupCounts();
    const ruleService: SceneRuleService = new SceneRuleService(context);
    const existingNames: Set<string> = new Set<string>();
    const existingRules: SceneRule[] = ruleService.listRules();
    for (let index: number = 0; index < existingRules.length; index += 1) {
      existingNames.add(existingRules[index].name.trim());
    }
    for (let index: number = 0; index < sceneRules.length; index += 1) {
      const rule: SceneRule = sceneRules[index];
      const name: string = rule.name.trim();
      if (name.length === 0 || existingNames.has(name)) {
        counts.skipped += 1;
        continue;
      }
      rule.id = 0;
      rule.name = name;
      rule.updatedAt = 0;
      if (ruleService.saveRule(rule).success) {
        counts.imported += 1;
        existingNames.add(name);
      } else {
        counts.failed += 1;
      }
    }
    const contextService: SceneContextRuleService = new SceneContextRuleService(context);
    const contextNames: Set<string> = new Set<string>();
    const existingContextRules: SceneContextRule[] = contextService.listRules();
    for (let index: number = 0; index < existingContextRules.length; index += 1) {
      contextNames.add(existingContextRules[index].name.trim());
    }
    for (let index: number = 0; index < sceneContextRules.length; index += 1) {
      const rule: SceneContextRule = sceneContextRules[index];
      const name: string = rule.name.trim();
      if (name.length === 0 || contextNames.has(name)) {
        counts.skipped += 1;
        continue;
      }
      rule.id = 0;
      rule.name = name;
      rule.updatedAt = 0;
      if (contextService.saveRule(rule).success) {
        counts.imported += 1;
        contextNames.add(name);
      } else {
        counts.failed += 1;
      }
    }
    return counts;
  }

  private static readUtf8FileUri(uri: string): string {
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const size: number = fileIo.statSync(file.fd).size;
      if (size <= 0 || size > MAX_BACKUP_FILE_BYTES) {
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
      AppLogger.error('Failed to read the selected backup file URI', error as Object);
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

  private static writeTextFile(uri: string, text: string): boolean {
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(uri,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, text);
      fileIo.closeSync(file);
      file = undefined;
      return true;
    } catch (error) {
      AppLogger.error('Failed to write the backup file URI', error as Object);
      return false;
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file);
        } catch (_) {
        }
      }
    }
  }

  private static suggestedFileName(): string {
    const date: Date = new Date();
    const pad: (value: number) => string = (value: number): string => value < 10 ? `0${value}` : `${value}`;
    return `moment-backup-${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}.json`;
  }
}

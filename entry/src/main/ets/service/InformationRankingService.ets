import { common } from '@kit.AbilityKit';
import { ResourceText } from '../common/ResourceText';
import { TimeUtils } from '../common/TimeUtils';
import { CourseOccurrence } from '../model/CourseModels';
import { FocusSession } from '../model/FocusModels';
import { SceneType } from '../model/SceneType';
import { LocalTask, TaskPriority } from '../model/TaskModels';
import { RankingItem, SceneAction, SceneActionType } from '../model/ViewModels';
import { CourseService } from './CourseService';
import { FocusService } from './FocusService';
import { TaskService } from './TaskService';

export class InformationRankingService {
  static build(context: common.Context, scene: SceneType, now: number = Date.now()): RankingItem[] {
    const items: RankingItem[] = new Array<RankingItem>();
    InformationRankingService.appendCourses(context, now, items);
    InformationRankingService.appendTasks(context, scene, now, items);
    InformationRankingService.appendFocus(context, now, items);
    items.sort((left: RankingItem, right: RankingItem) => {
      if (left.score !== right.score) {
        return right.score - left.score;
      }
      return left.id.localeCompare(right.id);
    });
    return InformationRankingService.unique(items);
  }

  private static appendCourses(context: common.Context, now: number, items: RankingItem[]): void {
    const service: CourseService = new CourseService(context);
    const current: CourseOccurrence | undefined = service.getCurrentCourse(now);
    if (current !== undefined) {
      const elapsed: number = Math.max(0, Math.floor((now - current.startAt) / 60000));
      const item: RankingItem = new RankingItem();
      item.id = `course:${current.course.id}:${current.startAt}`;
      item.type = 'course';
      item.title = ResourceText.get(context, $r('app.string.ranking_course_current'), '正在上课');
      item.value = current.course.name;
      item.description = `${TimeUtils.formatClock(current.course.startMinutes)}—` +
        `${TimeUtils.formatClock(current.course.endMinutes)}` +
        `${current.course.location.length > 0 ? ` · ${current.course.location}` : ''} · ` +
        `${ResourceText.get(context, $r('app.string.ranking_started'), '已开始')} ${elapsed} ` +
        ResourceText.get(context, $r('app.string.unit_minute'), '分钟');
      item.score = 1000;
      item.action = SceneAction.create(SceneActionType.OPEN_COURSES,
        ResourceText.get(context, $r('app.string.action_open_course'), '打开课程'));
      items.push(item);
    }
    const next: CourseOccurrence | undefined = service.getNextCourse(now);
    if (next !== undefined && (current === undefined || next.course.id !== current.course.id ||
      next.startAt !== current.startAt)) {
      const remaining: number = Math.max(0, Math.ceil((next.startAt - now) / 60000));
      const item: RankingItem = new RankingItem();
      item.id = `course:${next.course.id}:${next.startAt}`;
      item.type = 'course';
      item.title = ResourceText.get(context, $r('app.string.ranking_course_upcoming'), '即将上课');
      item.value = next.course.name;
      item.description = `${TimeUtils.formatDate(next.startAt)} ${TimeUtils.formatTime(next.startAt)}` +
        `${next.course.location.length > 0 ? ` · ${next.course.location}` : ''} · ` +
        `${remaining} ${ResourceText.get(context, $r('app.string.minutes_later'), '分钟后')}`;
      item.score = remaining <= 10 ? 900 : remaining <= 30 ? 800 : remaining <= 24 * 60 ? 420 : 260;
      item.action = SceneAction.create(SceneActionType.OPEN_COURSES,
        ResourceText.get(context, $r('app.string.action_open_course'), '打开课程'));
      items.push(item);
    }
  }

  private static appendTasks(context: common.Context, scene: SceneType, now: number,
    items: RankingItem[]): void {
    const tasks: LocalTask[] = new TaskService(context).listTasks(false, scene);
    const todayStart: number = TimeUtils.startOfDay(now);
    const tomorrowStart: number = todayStart + 24 * 60 * 60 * 1000;
    for (let index: number = 0; index < tasks.length; index += 1) {
      const task: LocalTask = tasks[index];
      const item: RankingItem = new RankingItem();
      item.id = `task:${task.id}`;
      item.type = 'task';
      item.title = ResourceText.get(context, $r('app.string.ranking_task'), '待办任务');
      item.value = task.title;
      item.description = InformationRankingService.taskDescription(context, task, now);
      item.score = task.priority * 100;
      if (task.dueAt > 0 && task.dueAt < now) {
        item.score += 400;
      } else if (task.dueAt >= todayStart && task.dueAt < tomorrowStart) {
        item.score += 250;
      } else if (task.dueAt > 0 && task.dueAt - now <= 60 * 60 * 1000) {
        item.score += 180;
      }
      if (task.sceneType === scene) {
        item.score += 80;
      }
      item.action = SceneAction.create(SceneActionType.COMPLETE_TASK,
        ResourceText.get(context, $r('app.string.action_complete_task'), '完成任务'), task.id);
      items.push(item);
    }
  }

  private static appendFocus(context: common.Context, now: number, items: RankingItem[]): void {
    const service: FocusService = new FocusService(context);
    const session: FocusSession | undefined = service.getActiveSession(now);
    if (session === undefined) {
      return;
    }
    const remaining: number = service.remainingMinutes(session, now);
    const item: RankingItem = new RankingItem();
    item.id = `focus:${session.id}`;
    item.type = 'focus';
    item.title = ResourceText.get(context, $r('app.string.focus_running'), '专注中');
    item.value = `${ResourceText.get(context, $r('app.string.focus_remaining'), '还剩')} ${remaining} ` +
      ResourceText.get(context, $r('app.string.unit_minute'), '分钟');
    item.description = `${TimeUtils.formatTime(session.startedAt)}—${TimeUtils.formatTime(session.plannedEndAt)}`;
    item.score = 850;
    item.action = SceneAction.create(SceneActionType.STOP_FOCUS,
      ResourceText.get(context, $r('app.string.action_stop_focus'), '结束专注'));
    items.push(item);
  }

  private static taskDescription(context: common.Context, task: LocalTask, now: number): string {
    if (task.dueAt <= 0) {
      return InformationRankingService.priorityLabel(context, task.priority);
    }
    if (task.dueAt < now) {
      return `${ResourceText.get(context, $r('app.string.task_overdue'), '已过期')} · ` +
        TimeUtils.formatDateTime(task.dueAt);
    }
    return `${ResourceText.get(context, $r('app.string.task_due'), '截止')} ` +
      `${TimeUtils.formatDateTime(task.dueAt)} · ` +
      InformationRankingService.priorityLabel(context, task.priority);
  }

  private static priorityLabel(context: common.Context, priority: TaskPriority): string {
    switch (priority) {
      case TaskPriority.URGENT:
        return ResourceText.get(context, $r('app.string.priority_urgent'), '紧急');
      case TaskPriority.HIGH:
        return ResourceText.get(context, $r('app.string.priority_high'), '高');
      case TaskPriority.MEDIUM:
        return ResourceText.get(context, $r('app.string.priority_medium'), '中');
      case TaskPriority.LOW:
        return ResourceText.get(context, $r('app.string.priority_low'), '低');
      default:
        return '';
    }
  }

  private static unique(items: RankingItem[]): RankingItem[] {
    const result: RankingItem[] = new Array<RankingItem>();
    const keys: string[] = new Array<string>();
    for (let index: number = 0; index < items.length; index += 1) {
      const key: string = `${items[index].type}:${items[index].value}`;
      if (keys.indexOf(key) < 0) {
        keys.push(key);
        result.push(items[index]);
      }
    }
    return result;
  }
}

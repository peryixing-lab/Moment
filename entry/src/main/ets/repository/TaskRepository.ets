import { common } from '@kit.AbilityKit';
import { AppLogger } from '../common/AppLogger';
import { DatabaseManager } from '../database/DatabaseManager';
import { TABLE_TASK } from '../database/DatabaseSchema';
import { LocalTask, TaskPriority } from '../model/TaskModels';

export class TaskRepository {
  private readonly context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  list(includeCompleted: boolean = false): LocalTask[] {
    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_TASK);
    const tasks: LocalTask[] = new Array<LocalTask>();
    for (let index: number = 0; index < rows.length; index += 1) {
      const task: LocalTask | undefined = this.decode(rows[index]);
      if (task !== undefined && (includeCompleted || !task.isCompleted)) {
        tasks.push(task);
      }
    }
    tasks.sort((left: LocalTask, right: LocalTask) => {
      if (left.isCompleted !== right.isCompleted) {
        return left.isCompleted ? 1 : -1;
      }
      if (left.priority !== right.priority) {
        return right.priority - left.priority;
      }
      if (left.dueAt === 0 || right.dueAt === 0) {
        return left.dueAt === right.dueAt ? right.updatedAt - left.updatedAt : left.dueAt === 0 ? 1 : -1;
      }
      return left.dueAt - right.dueAt;
    });
    return tasks;
  }

  getById(id: number): LocalTask | undefined {
    const tasks: LocalTask[] = this.list(true);
    for (let index: number = 0; index < tasks.length; index += 1) {
      if (tasks[index].id === id) {
        return tasks[index];
      }
    }
    return undefined;
  }

  save(task: LocalTask): boolean {
    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_TASK);
    const now: number = Date.now();
    if (task.id <= 0) {
      task.id = DatabaseManager.nextId(this.context, TABLE_TASK);
      if (task.id <= 0) {
        return false;
      }
      task.createdAt = task.createdAt > 0 ? task.createdAt : now;
    }
    task.updatedAt = now;
    const encoded: string = JSON.stringify(task);
    let replaced: boolean = false;
    for (let index: number = 0; index < rows.length; index += 1) {
      const existing: LocalTask | undefined = this.decode(rows[index]);
      if (existing !== undefined && existing.id === task.id) {
        rows[index] = encoded;
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      rows.push(encoded);
    }
    const saved: boolean = DatabaseManager.writeRows(this.context, TABLE_TASK, rows);
    if (saved) {
      AppLogger.info('Task saved');
    }
    return saved;
  }

  remove(id: number): boolean {
    return this.change(id, undefined);
  }

  setCompleted(id: number, completed: boolean): boolean {
    return this.change(id, completed);
  }

  private change(id: number, completed: boolean | undefined): boolean {
    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_TASK);
    const nextRows: string[] = new Array<string>();
    let found: boolean = false;
    for (let index: number = 0; index < rows.length; index += 1) {
      const task: LocalTask | undefined = this.decode(rows[index]);
      if (task !== undefined && task.id === id) {
        found = true;
        if (completed !== undefined) {
          task.isCompleted = completed;
          task.completedAt = completed ? Date.now() : 0;
          task.updatedAt = Date.now();
          nextRows.push(JSON.stringify(task));
        }
      } else {
        nextRows.push(rows[index]);
      }
    }
    return found && DatabaseManager.writeRows(this.context, TABLE_TASK, nextRows);
  }

  private decode(value: string): LocalTask | undefined {
    try {
      const raw: LocalTask = JSON.parse(value) as LocalTask;
      if (typeof raw.id !== 'number' || typeof raw.title !== 'string') {
        return undefined;
      }
      const task: LocalTask = new LocalTask();
      task.id = raw.id;
      task.title = raw.title;
      task.description = typeof raw.description === 'string' ? raw.description : '';
      task.dueAt = typeof raw.dueAt === 'number' ? raw.dueAt : 0;
      task.priority = typeof raw.priority === 'number' ? raw.priority : TaskPriority.MEDIUM;
      task.sceneType = typeof raw.sceneType === 'string' ? raw.sceneType : undefined;
      task.isCompleted = typeof raw.isCompleted === 'boolean' ? raw.isCompleted : false;
      task.completedAt = typeof raw.completedAt === 'number' ? raw.completedAt : 0;
      task.createdAt = typeof raw.createdAt === 'number' ? raw.createdAt : 0;
      task.updatedAt = typeof raw.updatedAt === 'number' ? raw.updatedAt : 0;
      return task;
    } catch (error) {
      AppLogger.error('Ignored invalid task row', error as Object);
      return undefined;
    }
  }
}

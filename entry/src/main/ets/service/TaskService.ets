import { common } from '@kit.AbilityKit';
import { OperationResult } from '../model/ServiceModels';
import { SceneType } from '../model/SceneType';
import { LocalTask } from '../model/TaskModels';
import { TaskRepository } from '../repository/TaskRepository';

export class TaskService {
  private readonly repository: TaskRepository;

  constructor(context: common.Context) {
    this.repository = new TaskRepository(context);
  }

  listTasks(includeCompleted: boolean = false, scene: SceneType | undefined = undefined): LocalTask[] {
    const tasks: LocalTask[] = this.repository.list(includeCompleted);
    if (scene === undefined) {
      return tasks;
    }
    const filtered: LocalTask[] = new Array<LocalTask>();
    for (let index: number = 0; index < tasks.length; index += 1) {
      if (tasks[index].sceneType === undefined || tasks[index].sceneType === scene) {
        filtered.push(tasks[index]);
      }
    }
    return filtered;
  }

  getTask(id: number): LocalTask | undefined {
    return this.repository.getById(id);
  }

  saveTask(task: LocalTask): OperationResult {
    if (task.title.trim().length === 0) {
      return OperationResult.fail('title');
    }
    if (task.dueAt < 0) {
      return OperationResult.fail('due');
    }
    if (task.priority < 1 || task.priority > 4) {
      return OperationResult.fail('priority');
    }
    return this.repository.save(task) ? OperationResult.ok() : OperationResult.fail('storage');
  }

  deleteTask(id: number): boolean {
    return id > 0 && this.repository.remove(id);
  }

  completeTask(id: number): boolean {
    return id > 0 && this.repository.setCompleted(id, true);
  }

  restoreTask(id: number): boolean {
    return id > 0 && this.repository.setCompleted(id, false);
  }
}

import { SceneType } from './SceneType';

export enum TaskPriority {
  LOW = 1,
  MEDIUM = 2,
  HIGH = 3,
  URGENT = 4
}

export class LocalTask {
  id: number = 0;
  title: string = '';
  description: string = '';
  dueAt: number = 0;
  priority: TaskPriority = TaskPriority.MEDIUM;
  sceneType: SceneType | undefined = undefined;
  isCompleted: boolean = false;
  completedAt: number = 0;
  createdAt: number = 0;
  updatedAt: number = 0;

  static create(title: string, description: string, dueAt: number, priority: TaskPriority,
    sceneType: SceneType | undefined): LocalTask {
    const task: LocalTask = new LocalTask();
    task.title = title;
    task.description = description;
    task.dueAt = dueAt;
    task.priority = priority;
    task.sceneType = sceneType;
    task.createdAt = Date.now();
    task.updatedAt = task.createdAt;
    return task;
  }
}

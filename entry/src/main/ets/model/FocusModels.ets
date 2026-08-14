import { SceneType } from './SceneType';

export enum FocusStatus {
  RUNNING = 'running',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled'
}

export class FocusSession {
  id: number = 0;
  durationMinutes: number = 25;
  startedAt: number = 0;
  plannedEndAt: number = 0;
  endedAt: number = 0;
  status: FocusStatus = FocusStatus.RUNNING;
  sceneType: SceneType = SceneType.LIBRARY;
  createdAt: number = 0;
}

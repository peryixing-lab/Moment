import { common } from '@kit.AbilityKit';
import { AppLogger } from '../common/AppLogger';
import { FocusSession, FocusStatus } from '../model/FocusModels';
import { SceneType } from '../model/SceneType';
import { FocusRepository } from '../repository/FocusRepository';

export class FocusService {
  private readonly repository: FocusRepository;

  constructor(context: common.Context) {
    this.repository = new FocusRepository(context);
  }

  getActiveSession(now: number = Date.now()): FocusSession | undefined {
    const running: FocusSession | undefined = this.repository.getRunning();
    if (running === undefined) {
      return undefined;
    }
    if (now >= running.plannedEndAt) {
      if (this.repository.updateStatus(running.id, FocusStatus.COMPLETED, running.plannedEndAt)) {
        AppLogger.info('Focus session completed from timestamp recovery');
      }
      return undefined;
    }
    return running;
  }

  startFocus(durationMinutes: number, scene: SceneType = SceneType.LIBRARY,
    now: number = Date.now()): boolean {
    if (durationMinutes < 1 || durationMinutes > 240 || this.getActiveSession(now) !== undefined) {
      return false;
    }
    const session: FocusSession = new FocusSession();
    session.durationMinutes = durationMinutes;
    session.startedAt = now;
    session.plannedEndAt = now + durationMinutes * 60 * 1000;
    session.endedAt = 0;
    session.status = FocusStatus.RUNNING;
    session.sceneType = scene;
    session.createdAt = now;
    return this.repository.create(session);
  }

  stopFocus(now: number = Date.now()): boolean {
    const running: FocusSession | undefined = this.getActiveSession(now);
    if (running === undefined) {
      return false;
    }
    return this.repository.updateStatus(running.id, FocusStatus.CANCELLED, now);
  }

  listHistory(): FocusSession[] {
    this.getActiveSession(Date.now());
    return this.repository.listHistory(30);
  }

  remainingMinutes(session: FocusSession, now: number = Date.now()): number {
    return Math.max(0, Math.ceil((session.plannedEndAt - now) / 60000));
  }
}

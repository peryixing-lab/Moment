import { common } from '@kit.AbilityKit';
import { AppLogger } from '../common/AppLogger';
import { DatabaseManager } from '../database/DatabaseManager';
import { TABLE_FOCUS_SESSION } from '../database/DatabaseSchema';
import { FocusSession, FocusStatus } from '../model/FocusModels';

export class FocusRepository {
  private readonly context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  getRunning(): FocusSession | undefined {
    const sessions: FocusSession[] = this.listHistory(100);
    for (let index: number = 0; index < sessions.length; index += 1) {
      if (sessions[index].status === FocusStatus.RUNNING) {
        return sessions[index];
      }
    }
    return undefined;
  }

  listHistory(limit: number = 30): FocusSession[] {
    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_FOCUS_SESSION);
    const sessions: FocusSession[] = new Array<FocusSession>();
    for (let index: number = 0; index < rows.length; index += 1) {
      const session: FocusSession | undefined = this.decode(rows[index]);
      if (session !== undefined) {
        sessions.push(session);
      }
    }
    sessions.sort((left: FocusSession, right: FocusSession) => right.startedAt - left.startedAt);
    return sessions.slice(0, Math.max(1, limit));
  }

  create(session: FocusSession): boolean {
    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_FOCUS_SESSION);
    session.id = DatabaseManager.nextId(this.context, TABLE_FOCUS_SESSION);
    if (session.id <= 0) {
      return false;
    }
    rows.push(JSON.stringify(session));
    const saved: boolean = DatabaseManager.writeRows(this.context, TABLE_FOCUS_SESSION, rows);
    if (saved) {
      AppLogger.info('Focus session created');
    }
    return saved;
  }

  updateStatus(id: number, status: FocusStatus, endedAt: number): boolean {
    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_FOCUS_SESSION);
    let found: boolean = false;
    for (let index: number = 0; index < rows.length; index += 1) {
      const session: FocusSession | undefined = this.decode(rows[index]);
      if (session !== undefined && session.id === id) {
        session.status = status;
        session.endedAt = endedAt;
        rows[index] = JSON.stringify(session);
        found = true;
        break;
      }
    }
    const saved: boolean = found && DatabaseManager.writeRows(this.context, TABLE_FOCUS_SESSION, rows);
    if (saved) {
      AppLogger.info(`Focus status changed to ${status}`);
    }
    return saved;
  }

  private decode(value: string): FocusSession | undefined {
    try {
      const raw: FocusSession = JSON.parse(value) as FocusSession;
      if (typeof raw.id !== 'number' || typeof raw.durationMinutes !== 'number' ||
        typeof raw.startedAt !== 'number' || typeof raw.plannedEndAt !== 'number' ||
        typeof raw.status !== 'string') {
        return undefined;
      }
      const session: FocusSession = new FocusSession();
      session.id = raw.id;
      session.durationMinutes = raw.durationMinutes;
      session.startedAt = raw.startedAt;
      session.plannedEndAt = raw.plannedEndAt;
      session.endedAt = typeof raw.endedAt === 'number' ? raw.endedAt : 0;
      session.status = raw.status;
      session.sceneType = raw.sceneType;
      session.createdAt = typeof raw.createdAt === 'number' ? raw.createdAt : raw.startedAt;
      return session;
    } catch (error) {
      AppLogger.error('Ignored invalid focus row', error as Object);
      return undefined;
    }
  }
}

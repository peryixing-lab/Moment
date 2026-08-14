import { AppLogger } from '../common/AppLogger';

const MAX_FORM_ACTION_MESSAGE_LENGTH: number = 1024;

export class SceneFormAction {
  action: string = '';
  taskId: number = 0;
  durationMinutes: number = 0;
}

export class FormActionParser {
  static parse(message: string): SceneFormAction | undefined {
    const normalizedMessage: string = message.trim();
    if (normalizedMessage.length === 0 || normalizedMessage.length > MAX_FORM_ACTION_MESSAGE_LENGTH) {
      return undefined;
    }
    try {
      const value: Object = JSON.parse(normalizedMessage) as Object;
      const record: Record<string, Object> = value as Record<string, Object>;
      const actionValue: Object | undefined = record['action'];
      if (typeof actionValue !== 'string' || !FormActionParser.isSupported(actionValue)) {
        return undefined;
      }
      const action: SceneFormAction = new SceneFormAction();
      action.action = actionValue;
      const taskValue: Object | undefined = record['taskId'];
      if (typeof taskValue === 'number' && Number.isInteger(taskValue)) {
        action.taskId = taskValue;
      }
      const durationValue: Object | undefined = record['durationMinutes'];
      if (typeof durationValue === 'number' && Number.isInteger(durationValue)) {
        action.durationMinutes = durationValue;
      }
      if (action.action === 'completeTask' && action.taskId <= 0) {
        AppLogger.error('Rejected form action without a valid task id');
        return undefined;
      }
      if (action.action === 'startFocus' &&
        (action.durationMinutes < 1 || action.durationMinutes > 240)) {
        AppLogger.error('Rejected form action with an invalid focus duration');
        return undefined;
      }
      return action;
    } catch (error) {
      AppLogger.error('Unable to parse form action JSON', error as Object);
      return undefined;
    }
  }

  private static isSupported(action: string): boolean {
    return action === 'switchScene' || action === 'openService' || action === 'completeTask' ||
      action === 'startFocus' || action === 'stopFocus' || action === 'restoreAutoScene';
  }
}

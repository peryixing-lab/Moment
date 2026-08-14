import { common } from '@kit.AbilityKit';
import { DatabaseManager } from '../database/DatabaseManager';

export class DataHealthService {
  static hasError(): boolean {
    return DatabaseManager.hasInitializationError();
  }

  static retry(context: common.Context): boolean {
    return DatabaseManager.retry(context);
  }
}

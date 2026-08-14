import { AppLogger } from '../common/AppLogger';
import { DATABASE_VERSION } from './DatabaseSchema';

export class DatabaseMigration {
  static validateVersion(previousVersion: number): number {
    if (previousVersion < DATABASE_VERSION) {
      AppLogger.info(`Local record schema upgraded from ${previousVersion} to ${DATABASE_VERSION}`);
    }
    return DATABASE_VERSION;
  }
}

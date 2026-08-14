import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AppLogger } from '../common/AppLogger';
import { DatabaseMigration } from './DatabaseMigration';
import { DATABASE_VERSION } from './DatabaseSchema';

const STORE_NAME: string = 'moment_local_records';
const KEY_VERSION: string = 'schema_version';
const KEY_PREFIX_TABLE: string = 'table_';
const KEY_PREFIX_SEQUENCE: string = 'sequence_';

export class DatabaseManager {
  private static store: preferences.Preferences | undefined = undefined;
  private static initializationFailed: boolean = false;

  static initialize(context: common.Context): boolean {
    const store: preferences.Preferences | undefined = DatabaseManager.getStore(context);
    if (store === undefined) {
      return false;
    }
    try {
      const versionValue: preferences.ValueType = store.getSync(KEY_VERSION, 0);
      const previousVersion: number = typeof versionValue === 'number' ? versionValue : 0;
      const nextVersion: number = DatabaseMigration.validateVersion(previousVersion);
      if (previousVersion !== nextVersion) {
        store.putSync(KEY_VERSION, DATABASE_VERSION);
        store.flushSync();
      }
      DatabaseManager.initializationFailed = false;
      return true;
    } catch (error) {
      DatabaseManager.initializationFailed = true;
      AppLogger.error('Local record store initialization failed', error as Object);
      return false;
    }
  }

  static readRows(context: common.Context, table: string): string[] {
    const store: preferences.Preferences | undefined = DatabaseManager.getStore(context);
    if (store === undefined) {
      return new Array<string>();
    }
    try {
      const fallback: string[] = new Array<string>();
      const value: preferences.ValueType = store.getSync(KEY_PREFIX_TABLE + table, fallback);
      if (!(value instanceof Array)) {
        return new Array<string>();
      }
      const rows: string[] = new Array<string>();
      for (let index: number = 0; index < value.length; index += 1) {
        if (typeof value[index] === 'string') {
          rows.push(value[index] as string);
        }
      }
      return rows;
    } catch (error) {
      DatabaseManager.initializationFailed = true;
      AppLogger.error(`Unable to read local table ${table}`, error as Object);
      return new Array<string>();
    }
  }

  static writeRows(context: common.Context, table: string, rows: string[]): boolean {
    const store: preferences.Preferences | undefined = DatabaseManager.getStore(context);
    if (store === undefined) {
      return false;
    }
    try {
      store.putSync(KEY_PREFIX_TABLE + table, rows);
      store.flushSync();
      DatabaseManager.initializationFailed = false;
      return true;
    } catch (error) {
      DatabaseManager.initializationFailed = true;
      AppLogger.error(`Unable to write local table ${table}`, error as Object);
      return false;
    }
  }

  static nextId(context: common.Context, table: string): number {
    const store: preferences.Preferences | undefined = DatabaseManager.getStore(context);
    if (store === undefined) {
      return 0;
    }
    try {
      const key: string = KEY_PREFIX_SEQUENCE + table;
      const value: preferences.ValueType = store.getSync(key, 0);
      const current: number = typeof value === 'number' ? value : 0;
      const next: number = current + 1;
      store.putSync(key, next);
      store.flushSync();
      return next;
    } catch (error) {
      DatabaseManager.initializationFailed = true;
      AppLogger.error(`Unable to allocate id for ${table}`, error as Object);
      return 0;
    }
  }

  static hasInitializationError(): boolean {
    return DatabaseManager.initializationFailed;
  }

  static retry(context: common.Context): boolean {
    DatabaseManager.store = undefined;
    DatabaseManager.initializationFailed = false;
    return DatabaseManager.initialize(context);
  }

  private static getStore(context: common.Context): preferences.Preferences | undefined {
    if (DatabaseManager.store !== undefined) {
      return DatabaseManager.store;
    }
    try {
      const options: preferences.Options = {
        name: STORE_NAME,
        storageType: preferences.StorageType.XML
      };
      DatabaseManager.store = preferences.getPreferencesSync(context, options);
      AppLogger.info('Local record store opened');
      return DatabaseManager.store;
    } catch (error) {
      DatabaseManager.initializationFailed = true;
      DatabaseManager.store = undefined;
      AppLogger.error('Local record store open failed', error as Object);
      return undefined;
    }
  }
}

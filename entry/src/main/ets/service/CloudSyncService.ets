import { cloudCommon, cloudDatabase } from '@kit.CloudFoundationKit';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import agconnectAuth from '@hw-agconnect/auth';
import { AppLogger } from '../common/AppLogger';
import { DatabaseManager } from '../database/DatabaseManager';
import { TABLE_COURSE, TABLE_TASK, TABLE_SCENE_RULE, TABLE_SCENE_CONTEXT_RULE } from '../database/DatabaseSchema';
import { AccountService } from './AccountService';
import { AppStateService } from './AppStateService';
import { CloudSyncRecord } from '../model/CloudSyncModels';
import { DataResetService } from './DataResetService';

const SYNC_STORE_NAME: string = 'moment_cloud_sync';
const KEY_MANIFEST: string = 'uploadManifest';
const MANIFEST_SEPARATOR: string = '|';

class DynamicCloudAuthProvider implements cloudCommon.AuthProvider {
  async getAccessToken(isForceRefresh: boolean): Promise<string> {
    const provider: cloudCommon.AuthProvider = agconnectAuth.getAuthProvider();
    return await provider.getAccessToken(isForceRefresh);
  }
}

export class CloudSyncResult {
  success: boolean = false;
  detail: string = '';
  uploadedCount: number = 0;
  downloadedCount: number = 0;

  static ok(uploaded: number, downloaded: number, detail: string): CloudSyncResult {
    const result: CloudSyncResult = new CloudSyncResult();
    result.success = true;
    result.uploadedCount = uploaded;
    result.downloadedCount = downloaded;
    result.detail = detail;
    return result;
  }

  static fail(detail: string): CloudSyncResult {
    const result: CloudSyncResult = new CloudSyncResult();
    result.detail = detail;
    return result;
  }
}

export class CloudSyncService {
  private static readonly ZONE_NAME: string = 'moment';
  private static readonly KIND_TASK: string = 'Task';
  private static readonly KIND_COURSE: string = 'Course';
  private static readonly KIND_SCENE_RULE: string = 'SceneRule';
  private static readonly KIND_CONTEXT_RULE: string = 'SceneContextRule';
  private static cloudReady: boolean = false;
  private static readonly KINDS: string[] = [
    CloudSyncService.KIND_TASK,
    CloudSyncService.KIND_COURSE,
    CloudSyncService.KIND_SCENE_RULE,
    CloudSyncService.KIND_CONTEXT_RULE
  ];
  private static readonly KIND_TABLE: Map<string, string> = CloudSyncService.buildKindTable();

  private static buildKindTable(): Map<string, string> {
    const table: Map<string, string> = new Map<string, string>();
    table.set(CloudSyncService.KIND_TASK, TABLE_TASK);
    table.set(CloudSyncService.KIND_COURSE, TABLE_COURSE);
    table.set(CloudSyncService.KIND_SCENE_RULE, TABLE_SCENE_RULE);
    table.set(CloudSyncService.KIND_CONTEXT_RULE, TABLE_SCENE_CONTEXT_RULE);
    return table;
  }

  static prepareCloud(): boolean {
    if (CloudSyncService.cloudReady) {
      return true;
    }
    try {
      cloudCommon.init({
        region: cloudCommon.CloudRegion.CHINA,
        authProvider: new DynamicCloudAuthProvider(),
        databaseOptions: { schema: 'schema.json' }
      });
      CloudSyncService.cloudReady = true;
      return true;
    } catch (error) {
      AppLogger.error('Unable to initialize the cloud service', error as Object);
      return false;
    }
  }

  static async sync(context: common.Context): Promise<CloudSyncResult> {
    if (!DatabaseManager.initialize(context)) {
      return CloudSyncResult.fail('local_store_unavailable');
    }
    if (AccountService.load(context) === undefined) {
      return CloudSyncResult.fail('not_signed_in');
    }
    if (!AccountService.initialize(context)) {
      return CloudSyncResult.fail('auth_init_failed');
    }
    if (!await AccountService.refreshSession(context)) {
      return CloudSyncResult.fail('session_expired');
    }
    if (!CloudSyncService.prepareCloud()) {
      return CloudSyncResult.fail('init_failed');
    }
    return await CloudSyncService.syncWithRecovery(context);
  }

  private static inFlight: boolean = false;

  static isAutoSyncApplicable(context: common.Context): boolean {
    return AppStateService.isFullMode(context) &&
      AppStateService.isAutoSyncEnabled(context) &&
      AccountService.isSignedIn(context);
  }

  static async triggerAutoSync(context: common.Context): Promise<CloudSyncResult> {
    if (!CloudSyncService.isAutoSyncApplicable(context)) {
      return CloudSyncResult.fail('auto_sync_not_applicable');
    }
    if (CloudSyncService.inFlight) {
      return CloudSyncResult.fail('already_syncing');
    }
    CloudSyncService.inFlight = true;
    try {
      return await CloudSyncService.sync(context);
    } finally {
      CloudSyncService.inFlight = false;
    }
  }

  static clearManifest(context: common.Context): void {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, {
        name: SYNC_STORE_NAME,
        storageType: preferences.StorageType.XML
      });
      store.putSync(KEY_MANIFEST, new Array<string>());
      store.flushSync();
    } catch (error) {
      AppLogger.error('Unable to clear the sync manifest', error as Object);
    }
  }

  static async syncForAccount(context: common.Context, replaceLocal: boolean): Promise<CloudSyncResult> {
    if (replaceLocal) {
      if (!DataResetService.resetSyncedTables(context)) {
        return CloudSyncResult.fail('local_reset_failed');
      }
      CloudSyncService.clearManifest(context);
    }
    return await CloudSyncService.sync(context);
  }

  private static appendDiagnostic(context: common.Context, message: string): void {
    try {
      const file: string = `${context.filesDir}/cloud_sync_diag.txt`;
      let existing: string = '';
      try {
        existing = fs.readTextSync(file);
      } catch (_) {
      }
      const next: string = `${existing}${existing.length > 0 ? '\n' : ''}${message}`;
      const fileHandle: fs.File = fs.openSync(file, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(fileHandle.fd, next);
      fs.closeSync(fileHandle);
    } catch (error) {
      AppLogger.error('Unable to append the cloud sync diagnostic', error as Object);
    }
  }

  private static async syncWithRecovery(context: common.Context): Promise<CloudSyncResult> {
    try {
      return await CloudSyncService.syncAll(context);
    } catch (error) {
      if (!CloudSyncService.isAuthenticationFailure(error as Object)) {
        return CloudSyncService.errorResult(error as Object);
      }
      AppLogger.info('Cloud request authentication expired, refreshing the user session');
      if (!await AccountService.refreshSession(context, true)) {
        return CloudSyncResult.fail('session_expired');
      }
      try {
        return await CloudSyncService.syncAll(context);
      } catch (retryError) {
        return CloudSyncService.errorResult(retryError as Object);
      }
    }
  }

  private static isAuthenticationFailure(error: Object): boolean {
    const businessError: BusinessError = error as BusinessError;
    const message: string = typeof businessError.message === 'string' ?
      businessError.message.toLowerCase() : '';
    return message.includes('401') || message.includes('response empty') ||
      message.includes('token') || message.includes('authentication');
  }

  private static errorResult(error: Object): CloudSyncResult {
    AppLogger.error('Unable to sync data with the cloud', error);
    const businessError: BusinessError = error as BusinessError;
    const code: number = typeof businessError.code === 'number' ? businessError.code : 0;
    const message: string = typeof businessError.message === 'string' ?
      businessError.message : '';
    return CloudSyncResult.fail(`sync_failed(${code})${message.length > 0 ? `：${message}` : ''}`);
  }

  private static async syncAll(context: common.Context): Promise<CloudSyncResult> {
    const zone: cloudDatabase.DatabaseZone = cloudDatabase.zone(CloudSyncService.ZONE_NAME);
    const manifest: Set<string> = CloudSyncService.loadManifest(context);
    let uploaded: number = 0;
    let downloaded: number = 0;
    const ownerUid: string = AccountService.load(context)?.uid ?? '';
    for (let kindIndex: number = 0; kindIndex < CloudSyncService.KINDS.length; kindIndex += 1) {
      const kind: string = CloudSyncService.KINDS[kindIndex];
      const table: string =
        CloudSyncService.KIND_TABLE.get(kind) ?? TABLE_TASK;
      const locals: string[] = DatabaseManager.readRows(context, table);
      const localById: Map<string, number> = new Map<string, number>();
      for (let index: number = 0; index < locals.length; index += 1) {
        localById.set(CloudSyncService.recordKey(locals[index]),
          CloudSyncService.localUpdatedAt(locals[index]));
      }
      const remote: CloudSyncRecord[] = await zone.query(
        new cloudDatabase.DatabaseQuery<CloudSyncRecord>(CloudSyncRecord)
          .equalTo('kind', kind).equalTo('ownerUid', ownerUid));
      const remoteById: Map<string, CloudSyncRecord> = new Map<string, CloudSyncRecord>();
      const recordsToUpload: CloudSyncRecord[] = new Array<CloudSyncRecord>();
      for (let index: number = 0; index < remote.length; index += 1) {
        remoteById.set(remote[index].recordId, remote[index]);
        const localUpdatedAt: number | undefined = localById.get(remote[index].recordId);
        if (localUpdatedAt === undefined) {
          if (!remote[index].isDeleted) {
            const applied: boolean = CloudSyncService.applyRemote(context, table, remote[index]);
            if (applied) {
              downloaded += 1;
            }
          }
          continue;
        }
        if (localUpdatedAt > remote[index].updatedAt) {
          recordsToUpload.push(CloudSyncService.recordFromLocal(kind,
            remote[index].recordId, localById, locals, ownerUid));
        }
      }
      for (let index: number = 0; index < locals.length; index += 1) {
        const key: string = CloudSyncService.recordKey(locals[index]);
        if (key.length === 0) {
          continue;
        }
        if (!remoteById.has(key)) {
          recordsToUpload.push(CloudSyncService.recordFromLocal(kind, key, localById, locals, ownerUid));
        }
      }
      const tombstones: string[] = new Array<string>();
      for (const manifestKey of manifest) {
        if (CloudSyncService.kindOfManifestKey(manifestKey) !== kind) {
          continue;
        }
        const recordId: string = CloudSyncService.recordIdOfManifestKey(manifestKey);
        if (recordId.length === 0) {
          continue;
        }
        if (!localById.has(recordId) && !remoteById.has(recordId)) {
          tombstones.push(recordId);
        } else if (!localById.has(recordId) && remoteById.has(recordId)) {
          const tombstone: CloudSyncRecord = new CloudSyncRecord();
          tombstone.kind = kind;
          tombstone.recordId = recordId;
          tombstone.ownerUid = ownerUid;
          tombstone.updatedAt = Date.now();
          tombstone.isDeleted = true;
          tombstone.payload = '{}';
          recordsToUpload.push(tombstone);
        }
      }
      if (recordsToUpload.length > 0) {
        const batch: number = 5;
        for (let start: number = 0; start < recordsToUpload.length; start += batch) {
          const chunk: CloudSyncRecord[] = recordsToUpload.slice(start, start + batch);
          for (let i: number = 0; i < chunk.length; i += 1) {
            const record: CloudSyncRecord = chunk[i];
            const detail: string = `Upload record [${start + i}] kind=${record.kind} ` +
              `id=${record.recordId} updatedAt=${record.updatedAt} ` +
              `isDeleted=${record.isDeleted} payloadLength=${record.payload.length} ` +
              `payloadHead=${record.payload.substring(0, 60)}`;
            AppLogger.info(detail);
            CloudSyncService.appendDiagnostic(context, detail);
          }
          try {
            await zone.upsert(chunk);
            uploaded += chunk.length;
          } catch (error) {
            const businessError: BusinessError = error as BusinessError;
            const message: string = typeof businessError.message === 'string' ?
              businessError.message : 'upsert batch failed';
            const failDetail: string = `Upsert failed for batch starting at ${start}: ${message}`;
            AppLogger.error(failDetail, error as Object);
            CloudSyncService.appendDiagnostic(context, failDetail);
            throw new Error(`batch_${start}: ${message}`);
          }
        }
      }
      manifest.delete(tombstones.map((value: string) => `${kind}${MANIFEST_SEPARATOR}${value}`)[0] ?? '');
      for (let index = 0; index < locals.length; index += 1) {
        const key: string = CloudSyncService.recordKey(locals[index]);
        if (key.length > 0) {
          manifest.add(`${kind}${MANIFEST_SEPARATOR}${key}`);
        }
      }
    }
    CloudSyncService.saveManifest(context, manifest);
    return CloudSyncResult.ok(uploaded, downloaded, 'sync_completed');
  }

  private static recordFromLocal(kind: string, recordId: string,
    localById: Map<string, number>, locals: string[], ownerUid: string): CloudSyncRecord {
    const record: CloudSyncRecord = new CloudSyncRecord();
    record.kind = kind;
    record.recordId = recordId;
    record.ownerUid = ownerUid;
    record.updatedAt = localById.get(recordId) ?? Date.now();
    record.isDeleted = false;
    record.payload = '{}';
    for (let index: number = 0; index < locals.length; index += 1) {
      if (CloudSyncService.recordKey(locals[index]) === recordId) {
        record.payload = locals[index];
        break;
      }
    }
    return record;
  }

  private static localUpdatedAt(raw: string): number {
    try {
      const parsed: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
      const value: Object | undefined = parsed['updatedAt'];
      return typeof value === 'number' ? value : 0;
    } catch (_) {
      return 0;
    }
  }

  private static recordKey(raw: string): string {
    try {
      const parsed: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
      const value: Object | undefined = parsed['id'];
      return typeof value === 'number' ? value.toString() : '';
    } catch (_) {
      return '';
    }
  }

  private static applyRemote(context: common.Context, table: string,
    record: CloudSyncRecord): boolean {
    const rows: string[] = DatabaseManager.readRows(context, table);
    const existingIndex: number = CloudSyncService.indexOf(rows, record.recordId);
    if (record.isDeleted) {
      if (existingIndex < 0) {
        return true;
      }
      const next: string[] = new Array<string>();
      for (let index: number = 0; index < rows.length; index += 1) {
        if (CloudSyncService.recordKey(rows[index]) !== record.recordId) {
          next.push(rows[index]);
        }
      }
      return DatabaseManager.writeRows(context, table, next);
    }
    if (existingIndex >= 0 &&
      CloudSyncService.localUpdatedAt(rows[existingIndex]) >= record.updatedAt) {
      return true;
    }
    if (existingIndex >= 0) {
      rows[existingIndex] = record.payload;
    } else {
      rows.push(record.payload);
    }
    return DatabaseManager.writeRows(context, table, rows);
  }

  private static indexOf(rows: string[], recordId: string): number {
    for (let index: number = 0; index < rows.length; index += 1) {
      if (CloudSyncService.recordKey(rows[index]) === recordId) {
        return index;
      }
    }
    return -1;
  }

  private static kindOfManifestKey(key: string): string {
    const index: number = key.indexOf(MANIFEST_SEPARATOR);
    return index < 0 ? '' : key.substring(0, index);
  }

  private static recordIdOfManifestKey(key: string): string {
    const index: number = key.indexOf(MANIFEST_SEPARATOR);
    return index < 0 ? '' : key.substring(index + 1);
  }

  private static loadManifest(context: common.Context): Set<string> {
    const manifest: Set<string> = new Set<string>();
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, {
        name: SYNC_STORE_NAME,
        storageType: preferences.StorageType.XML
      });
      const rows: preferences.ValueType = store.getSync(KEY_MANIFEST, new Array<string>());
      if (rows instanceof Array) {
        for (let index: number = 0; index < rows.length; index += 1) {
          if (typeof rows[index] === 'string') {
            manifest.add(rows[index] as string);
          }
        }
      }
    } catch (error) {
      AppLogger.error('Unable to load the sync manifest', error as Object);
    }
    return manifest;
  }

  private static saveManifest(context: common.Context, manifest: Set<string>): void {
    try {
      const rows: string[] = new Array<string>();
      for (const key of manifest) {
        rows.push(key);
      }
      const store: preferences.Preferences = preferences.getPreferencesSync(context, {
        name: SYNC_STORE_NAME,
        storageType: preferences.StorageType.XML
      });
      store.putSync(KEY_MANIFEST, rows);
      store.flushSync();
    } catch (error) {
      AppLogger.error('Unable to save the sync manifest', error as Object);
    }
  }
}

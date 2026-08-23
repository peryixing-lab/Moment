import { cloudDatabase } from '@kit.CloudFoundationKit';

export class CloudSyncRecord extends cloudDatabase.DatabaseObject {
  kind: string = '';
  recordId: string = '';
  ownerUid: string = '';
  updatedAt: number = 0;
  isDeleted: boolean = false;
  payload: string = '';

  naturalbase_ClassName(): string {
    return 'moment';
  }
}

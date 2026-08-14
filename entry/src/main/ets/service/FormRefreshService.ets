import { common } from '@kit.AbilityKit';
import { FormRefreshCoordinator } from './FormRefreshCoordinator';

export class FormRefreshService {
  static async refreshAll(context: common.Context): Promise<void> {
    await FormRefreshCoordinator.refreshNow(context, 'legacy_request');
  }
}

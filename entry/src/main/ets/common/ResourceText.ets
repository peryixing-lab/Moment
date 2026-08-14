import { common } from '@kit.AbilityKit';
import { AppLogger } from './AppLogger';

export class ResourceText {
  static get(context: common.Context, resource: Resource, fallback: string = ''): string {
    try {
      return context.resourceManager.getStringSync(resource.id);
    } catch (error) {
      AppLogger.error('Unable to resolve text resource', error as Object);
      return fallback;
    }
  }
}

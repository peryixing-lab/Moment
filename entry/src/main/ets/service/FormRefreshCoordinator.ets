import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { formProvider } from '@kit.FormKit';
import { AppLogger } from '../common/AppLogger';
import { SceneFormDataAdapter } from '../form/SceneFormDataAdapter';
import { FormIdRepository } from '../repository/FormIdRepository';

const DEBOUNCE_MS: number = 1000;
const FORM_NOT_FOUND: number = 16501001;
const FORM_NOT_OWNED: number = 16501003;

export class FormRefreshCoordinator {
  private static timerId: number = -1;

  static schedule(context: common.Context, reason: string = 'data_changed'): void {
    if (FormRefreshCoordinator.timerId >= 0) {
      clearTimeout(FormRefreshCoordinator.timerId);
    }
    const applicationContext: common.ApplicationContext = context.getApplicationContext();
    FormRefreshCoordinator.timerId = setTimeout(() => {
      FormRefreshCoordinator.timerId = -1;
      FormRefreshCoordinator.refreshNow(applicationContext, reason).catch((error: Object) => {
        AppLogger.error('Scheduled form refresh failed', error);
      });
    }, DEBOUNCE_MS);
  }

  static isPermanentFormError(error: Object): boolean {
    const businessError: BusinessError = error as BusinessError;
    return businessError.code === FORM_NOT_FOUND || businessError.code === FORM_NOT_OWNED;
  }

  static async refreshNow(context: common.Context, reason: string = 'requested'): Promise<void> {
    const repository: FormIdRepository = new FormIdRepository(context);
    const formIds: string[] = repository.getFormIds();
    if (formIds.length === 0) {
      return;
    }
    for (let index: number = 0; index < formIds.length; index += 1) {
      const formId: string = formIds[index];
      try {
        const data = SceneFormDataAdapter.createBindingData(context, repository.getFormDimension(formId));
        await formProvider.updateForm(formId, data);
      } catch (error) {
        if (FormRefreshCoordinator.isPermanentFormError(error as Object)) {
          repository.removeFormId(formId);
        }
        AppLogger.error('Unable to refresh a form', error as Object);
      }
    }
    AppLogger.info(`Form refresh completed for ${formIds.length} forms: ${reason}`);
  }
}

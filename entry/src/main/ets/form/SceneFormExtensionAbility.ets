import { Want } from '@kit.AbilityKit';
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { AppLogger } from '../common/AppLogger';
import { FormIdRepository } from '../repository/FormIdRepository';
import { FormActionParser, SceneFormAction } from '../service/FormActionParser';
import { FormRefreshCoordinator } from '../service/FormRefreshCoordinator';
import { SceneActionService } from '../service/SceneActionService';
import { SceneFormDataAdapter } from './SceneFormDataAdapter';

export default class SceneFormExtensionAbility extends FormExtensionAbility {
  private lastActionAt: number = 0;
  private lastActionKey: string = '';

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = this.extractFormId(want);
    const dimension: number = this.extractDimension(want.parameters);
    if (formId.length > 0) {
      new FormIdRepository(this.context).addFormId(formId, dimension);
    }
    return SceneFormDataAdapter.createBindingData(this.context, dimension);
  }

  onUpdateForm(formId: string, wantParams?: Record<string, Object>): void {
    const repository: FormIdRepository = new FormIdRepository(this.context);
    const requestedDimension: number = this.extractDimension(wantParams, repository.getFormDimension(formId));
    repository.setFormDimension(formId, requestedDimension);
    const data: formBindingData.FormBindingData =
      SceneFormDataAdapter.createBindingData(this.context, requestedDimension);
    formProvider.updateForm(formId, data).catch((error: Object) => {
      if (FormRefreshCoordinator.isPermanentFormError(error)) {
        repository.removeFormId(formId);
      }
      AppLogger.error('Unable to update requested form', error);
    });
  }

  onFormEvent(formId: string, message: string): void {
    const action: SceneFormAction | undefined = FormActionParser.parse(message);
    if (action === undefined) {
      return;
    }
    const now: number = Date.now();
    const actionKey: string =
      `${formId}:${action.action}:${action.taskId}:${action.durationMinutes}`;
    if (actionKey === this.lastActionKey && now - this.lastActionAt < 600) {
      AppLogger.info('Ignored duplicate form action');
      return;
    }
    this.lastActionKey = actionKey;
    this.lastActionAt = now;
    if (!SceneActionService.execute(this.context, action)) {
      AppLogger.error(`Form action failed: ${action.action}`);
      return;
    }
    AppLogger.info(`Form action completed: ${action.action}`);
    FormRefreshCoordinator.refreshNow(this.context, `form_action:${formId}`).catch((error: Object) => {
      AppLogger.error('Unable to refresh forms after an action', error);
    });
  }

  onRemoveForm(formId: string): void {
    new FormIdRepository(this.context).removeFormId(formId);
  }

  onAcquireFormState(_want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  private extractFormId(want: Want): string {
    if (want.parameters === undefined) {
      return '';
    }
    const value: Object | undefined = want.parameters[formInfo.FormParam.IDENTITY_KEY];
    return typeof value === 'string' ? value : '';
  }

  private extractDimension(parameters: Record<string, Object> | undefined, fallback: number = 3): number {
    if (parameters === undefined) {
      return fallback;
    }
    const value: Object | undefined = parameters[formInfo.FormParam.DIMENSION_KEY];
    if (typeof value !== 'number') {
      return fallback;
    }
    return value === formInfo.FormDimension.Dimension_2_2 ||
      value === formInfo.FormDimension.Dimension_4_4 ? value : formInfo.FormDimension.Dimension_2_4;
  }
}

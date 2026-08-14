import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AppLogger } from '../common/AppLogger';

const FORM_STORE_NAME: string = 'moment_form_ids';
const KEY_FORM_IDS: string = 'form_ids';
const KEY_FORM_DIMENSIONS: string = 'form_dimensions';
const DEFAULT_FORM_DIMENSION: number = 3;

export class FormIdRepository {
  private readonly context: common.Context;
  private store: preferences.Preferences | undefined = undefined;

  constructor(context: common.Context) {
    this.context = context;
  }

  getFormIds(): string[] {
    return this.readArray(KEY_FORM_IDS);
  }

  addFormId(formId: string, dimension: number = DEFAULT_FORM_DIMENSION): boolean {
    const normalizedId: string = formId.trim();
    if (normalizedId.length === 0) {
      return false;
    }
    const formIds: string[] = this.getFormIds();
    if (formIds.indexOf(normalizedId) >= 0) {
      return this.setFormDimension(normalizedId, dimension);
    }
    formIds.push(normalizedId);
    const saved: boolean = this.writeArray(KEY_FORM_IDS, formIds) &&
      this.setFormDimension(normalizedId, dimension);
    if (saved) {
      AppLogger.info('Form id saved');
    }
    return saved;
  }

  getFormDimension(formId: string): number {
    const normalizedId: string = formId.trim();
    if (normalizedId.length === 0) {
      return DEFAULT_FORM_DIMENSION;
    }
    const records: string[] = this.readArray(KEY_FORM_DIMENSIONS);
    const prefix: string = `${normalizedId}=`;
    for (let index: number = 0; index < records.length; index += 1) {
      if (records[index].startsWith(prefix)) {
        return FormIdRepository.normalizeDimension(Number.parseInt(records[index].substring(prefix.length)));
      }
    }
    return DEFAULT_FORM_DIMENSION;
  }

  setFormDimension(formId: string, dimension: number): boolean {
    const normalizedId: string = formId.trim();
    if (normalizedId.length === 0) {
      return false;
    }
    const records: string[] = this.readArray(KEY_FORM_DIMENSIONS);
    const prefix: string = `${normalizedId}=`;
    const record: string = `${normalizedId}=${FormIdRepository.normalizeDimension(dimension)}`;
    for (let index: number = 0; index < records.length; index += 1) {
      if (records[index].startsWith(prefix)) {
        records[index] = record;
        return this.writeArray(KEY_FORM_DIMENSIONS, records);
      }
    }
    records.push(record);
    return this.writeArray(KEY_FORM_DIMENSIONS, records);
  }

  removeFormId(formId: string): boolean {
    const normalizedId: string = formId.trim();
    if (normalizedId.length === 0) {
      return false;
    }
    const formIds: string[] = this.getFormIds();
    const index: number = formIds.indexOf(normalizedId);
    if (index < 0) {
      return true;
    }
    formIds.splice(index, 1);
    const saved: boolean = this.writeArray(KEY_FORM_IDS, formIds);
    this.removeFormDimension(normalizedId);
    if (saved) {
      AppLogger.info('Form id removed');
    }
    return saved;
  }

  replaceFormIds(formIds: string[]): boolean {
    return this.writeArray(KEY_FORM_IDS, formIds);
  }

  clear(): boolean {
    const idsSaved: boolean = this.writeArray(KEY_FORM_IDS, new Array<string>());
    const dimensionsSaved: boolean = this.writeArray(KEY_FORM_DIMENSIONS, new Array<string>());
    return idsSaved && dimensionsSaved;
  }

  private removeFormDimension(formId: string): boolean {
    const records: string[] = this.readArray(KEY_FORM_DIMENSIONS);
    const prefix: string = `${formId}=`;
    for (let index: number = records.length - 1; index >= 0; index -= 1) {
      if (records[index].startsWith(prefix)) {
        records.splice(index, 1);
      }
    }
    return this.writeArray(KEY_FORM_DIMENSIONS, records);
  }

  private readArray(key: string): string[] {
    const store: preferences.Preferences | undefined = this.getStore();
    if (store === undefined) {
      return new Array<string>();
    }
    try {
      const fallback: string[] = new Array<string>();
      const value: preferences.ValueType = store.getSync(key, fallback);
      return FormIdRepository.toStringArray(value);
    } catch (error) {
      AppLogger.error('Unable to read form ids', error as Object);
      return new Array<string>();
    }
  }

  private writeArray(key: string, values: string[]): boolean {
    const store: preferences.Preferences | undefined = this.getStore();
    if (store === undefined) {
      return false;
    }
    try {
      store.putSync(key, FormIdRepository.sanitize(values));
      store.flushSync();
      return true;
    } catch (error) {
      AppLogger.error('Unable to save form ids', error as Object);
      return false;
    }
  }

  private getStore(): preferences.Preferences | undefined {
    if (this.store !== undefined) {
      return this.store;
    }
    try {
      const options: preferences.Options = {
        name: FORM_STORE_NAME,
        storageType: preferences.StorageType.XML
      };
      this.store = preferences.getPreferencesSync(this.context, options);
    } catch (error) {
      this.store = undefined;
      AppLogger.error('Unable to open form id preferences', error as Object);
    }
    return this.store;
  }

  private static toStringArray(value: preferences.ValueType): string[] {
    const result: string[] = new Array<string>();
    if (value instanceof Array) {
      for (let index: number = 0; index < value.length; index += 1) {
        const item: number | string | boolean = value[index];
        if (typeof item === 'string') {
          const normalizedId: string = item.trim();
          if (normalizedId.length > 0 && result.indexOf(normalizedId) < 0) {
            result.push(normalizedId);
          }
        }
      }
    }
    return result;
  }

  private static sanitize(formIds: string[]): string[] {
    const result: string[] = new Array<string>();
    for (let index: number = 0; index < formIds.length; index += 1) {
      const normalizedId: string = formIds[index].trim();
      if (normalizedId.length > 0 && result.indexOf(normalizedId) < 0) {
        result.push(normalizedId);
      }
    }
    return result;
  }

  private static normalizeDimension(dimension: number): number {
    return dimension === 2 || dimension === 4 ? dimension : DEFAULT_FORM_DIMENSION;
  }
}

import { SceneType } from './SceneType';

export enum SceneSource {
  MANUAL = 'manual',
  CONTEXT_RULE = 'context_rule',
  TIME_RULE = 'time_rule',
  SCHEDULE = 'schedule',
  DEFAULT = 'default'
}

export interface SceneState {
  currentScene: SceneType;
  source: SceneSource;
  activatedAt: number;
  expiresAt?: number;
  isLocked: boolean;
  reason: string;
  confidence: number;
}

export interface SceneSignal {
  source: SceneSource;
  targetScene: SceneType;
  score: number;
  reason: string;
  timestamp: number;
  priority: number;
  expiresAt?: number;
  isLocked: boolean;
}

export interface SceneDecision {
  scene: SceneType;
  confidence: number;
  source: SceneSource;
  reasons: string[];
  activatedAt: number;
  expiresAt?: number;
  isLocked: boolean;
}

export class SceneInfoItem {
  id: string = '';
  title: Resource = $r('app.string.info_next_class');
  value: Resource = $r('app.string.value_data_structure');
  description: Resource | undefined = undefined;
  priority: number = 0;

  static create(id: string, title: Resource, value: Resource, description: Resource | undefined,
    priority: number): SceneInfoItem {
    const item: SceneInfoItem = new SceneInfoItem();
    item.id = id;
    item.title = title;
    item.value = value;
    item.description = description;
    item.priority = priority;
    return item;
  }
}

export class ScenePresentation {
  type: SceneType = SceneType.LIBRARY;
  name: Resource = $r('app.string.scene_library_name');
  subtitle: Resource = $r('app.string.scene_library_subtitle');
  primaryActionText: Resource = $r('app.string.action_start_focus');
  heroTime: Resource = $r('app.string.value_class_time');
  heroTitle: Resource = $r('app.string.value_data_structure');
  heroNote: Resource = $r('app.string.value_class_distance');
  infoItems: SceneInfoItem[] = new Array<SceneInfoItem>();

  static create(type: SceneType, name: Resource, subtitle: Resource, primaryActionText: Resource,
    heroTime: Resource, heroTitle: Resource, heroNote: Resource,
    infoItems: SceneInfoItem[]): ScenePresentation {
    const presentation: ScenePresentation = new ScenePresentation();
    presentation.type = type;
    presentation.name = name;
    presentation.subtitle = subtitle;
    presentation.primaryActionText = primaryActionText;
    presentation.heroTime = heroTime;
    presentation.heroTitle = heroTitle;
    presentation.heroNote = heroNote;
    presentation.infoItems = infoItems;
    return presentation;
  }
}

export class AppSettings {
  autoRecommendationEnabled: boolean = true;
  defaultScene: SceneType = SceneType.LIBRARY;
  manualScene: SceneType | undefined = undefined;
  manualSceneActivatedAt: number = 0;
  manualSceneExpireAt: number = 0;
  manualSceneLocked: boolean = false;
  showSecondaryInfo: boolean = true;
  lastSceneUpdateTime: number = 0;
  onboardingCompleted: boolean = false;

  static create(autoRecommendationEnabled: boolean, defaultScene: SceneType,
    manualScene: SceneType | undefined, manualSceneActivatedAt: number, manualSceneExpireAt: number,
    manualSceneLocked: boolean, showSecondaryInfo: boolean, lastSceneUpdateTime: number,
    onboardingCompleted: boolean): AppSettings {
    const settings: AppSettings = new AppSettings();
    settings.autoRecommendationEnabled = autoRecommendationEnabled;
    settings.defaultScene = defaultScene;
    settings.manualScene = manualScene;
    settings.manualSceneActivatedAt = manualSceneActivatedAt;
    settings.manualSceneExpireAt = manualSceneExpireAt;
    settings.manualSceneLocked = manualSceneLocked;
    settings.showSecondaryInfo = showSecondaryInfo;
    settings.lastSceneUpdateTime = lastSceneUpdateTime;
    settings.onboardingCompleted = onboardingCompleted;
    return settings;
  }

  static defaults(onboardingCompleted: boolean = false): AppSettings {
    return AppSettings.create(true, SceneType.LIBRARY, undefined, 0, 0, false, true, 0,
      onboardingCompleted);
  }
}

export class SettingsReadResult {
  settings: AppSettings = AppSettings.defaults();
  success: boolean = true;

  static create(settings: AppSettings, success: boolean): SettingsReadResult {
    const result: SettingsReadResult = new SettingsReadResult();
    result.settings = settings;
    result.success = success;
    return result;
  }
}

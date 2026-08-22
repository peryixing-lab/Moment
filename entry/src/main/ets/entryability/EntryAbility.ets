import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { promptAction, window } from '@kit.ArkUI';
import { AppLogger } from '../common/AppLogger';
import { ResourceText } from '../common/ResourceText';
import { SceneContextRule, SceneContextTriggerType } from '../model/SceneContextModels';
import { SceneViewModel } from '../model/ViewModels';
import { FormRefreshCoordinator } from '../service/FormRefreshCoordinator';
import { SceneContextMonitor } from '../service/SceneContextMonitor';
import { SceneContextRuntime } from '../service/SceneContextRuntime';
import { ScenePresentationService } from '../service/ScenePresentationService';
import { SceneViewModelService } from '../service/SceneViewModelService';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | undefined = undefined;
  private pendingRoute: string = '';
  private pendingRouteAction: string = '';
  private contextMonitor: SceneContextMonitor | undefined = undefined;
  private contextPromptVisible: boolean = false;

  private routeFromWant(want: Want): string {
    if (want.parameters === undefined) {
      return '';
    }
    const value: Object | undefined = want.parameters['targetPage'];
    if (typeof value !== 'string') {
      return '';
    }
    if (value === 'pages/Index' || value === 'pages/CourseListPage' || value === 'pages/TaskListPage') {
      return value;
    }
    return '';
  }

  private routeActionFromWant(want: Want): string {
    if (want.parameters === undefined) {
      return '';
    }
    const value: Object | undefined = want.parameters['targetAction'];
    return typeof value === 'string' && value === 'openSceneSwitcher' ? value : '';
  }

  private openPendingRoute(): void {
    if (this.mainWindow === undefined || this.pendingRoute.length === 0) {
      return;
    }
    const route: string = this.pendingRoute;
    const routeAction: string = this.pendingRouteAction;
    this.pendingRoute = '';
    this.pendingRouteAction = '';
    try {
      const appRouter = this.mainWindow.getUIContext().getRouter();
      if (route === 'pages/Index') {
        appRouter.clear();
        appRouter.replaceUrl({
          url: route,
          params: { cardAction: routeAction }
        }).then(() => {
          AppLogger.info(`Opened card route: ${route}`);
        }).catch((error: Object) => {
          AppLogger.error(`Unable to open card route: ${route}`, error);
        });
        return;
      }
      appRouter.pushUrl({
        url: route,
        params: { cardAction: routeAction }
      }).then(() => {
        AppLogger.info(`Opened card route: ${route}`);
      }).catch((error: Object) => {
        AppLogger.error(`Unable to open card route: ${route}`, error);
      });
    } catch (error) {
      AppLogger.error(`Unable to dispatch card route: ${route}`, error as Object);
    }
  }

  private colorToHex(color: number): string {
    return `#${(color >>> 0).toString(16).padStart(8, '0')}`;
  }

  private shouldUseLightSystemBarIcons(color: number): boolean {
    const red: number = (color >>> 16) & 0xFF;
    const green: number = (color >>> 8) & 0xFF;
    const blue: number = color & 0xFF;
    const luminance: number = (red * 299 + green * 587 + blue * 114) / 255000;
    return luminance < 0.5;
  }

  private applyWindowTheme(mainWindow: window.Window): void {
    try {
      const backgroundColorValue: number =
        this.context.resourceManager.getColorByNameSync('page_background');
      const backgroundColor: string = this.colorToHex(backgroundColorValue);
      const contentColor: string = this.colorToHex(
        this.context.resourceManager.getColorByNameSync('text_primary')
      );
      const useLightIcons: boolean = this.shouldUseLightSystemBarIcons(backgroundColorValue);

      mainWindow.setWindowBackgroundColor(backgroundColor);
      // Let page content render edge-to-edge. Page and HDS navigation
      // containers keep interactive content inside their safe areas.
      mainWindow.setWindowLayoutFullScreen(true)
        .then(() => mainWindow.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          statusBarContentColor: contentColor,
          isStatusBarLightIcon: useLightIcons,
          navigationBarColor: '#00000000',
          navigationBarContentColor: contentColor,
          isNavigationBarLightIcon: useLightIcons
        }))
        .catch((err: Object) => {
          AppLogger.error('Unable to configure the immersive window theme', err);
        });
    } catch (err) {
      AppLogger.error('Unable to apply the window theme', err as Object);
    }
  }

  private showContextScenePrompt(rule: SceneContextRule): boolean {
    if (this.mainWindow === undefined || this.contextPromptVisible) {
      return false;
    }
    try {
      const current: SceneViewModel = SceneViewModelService.build(this.context);
      if (current.isManualOverride) {
        return false;
      }
      const sceneName: string = ResourceText.get(this.context,
        ScenePresentationService.getPresentation(rule.sceneType).name, '目标');
      const condition: string = rule.triggerType === SceneContextTriggerType.WIFI ?
        `已连接 Wi-Fi“${rule.wifiSsid}”` : `已进入“${rule.addressName}”附近`;
      const uiPrompt = this.mainWindow.getUIContext().getPromptAction();
      this.contextPromptVisible = true;
      uiPrompt.showDialog({
        title: $r('app.string.context_switch_prompt_title'),
        message: `${condition}，是否切换到“${sceneName}”场景？`,
        buttons: [
          { text: $r('app.string.cancel'), color: '#6B7280' },
          { text: $r('app.string.context_switch_once'), color: '#1F6FEB' },
          { text: $r('app.string.context_switch_always'), color: '#1F6FEB' }
        ]
      }).then((result: promptAction.ShowDialogSuccessResponse) => {
        if (this.contextMonitor === undefined) {
          return;
        }
        if (result.index === 1 || result.index === 2) {
          if (this.contextMonitor.acceptRule(rule, result.index === 2)) {
            uiPrompt.showToast({ message: $r('app.string.context_switch_applied') });
          }
        } else {
          this.contextMonitor.dismissRule(rule.id);
        }
      }).catch((error: Object) => {
        this.contextMonitor?.dismissRule(rule.id);
        AppLogger.error('Unable to present a scene context prompt', error);
      }).finally(() => {
        this.contextPromptVisible = false;
      });
      return true;
    } catch (error) {
      this.contextPromptVisible = false;
      AppLogger.error('Unable to prepare a scene context prompt', error as Object);
      return false;
    }
  }

  private publishContextSceneChange(): void {
    const current: number | undefined = AppStorage.get<number>('contextSceneRefreshToken');
    AppStorage.setOrCreate('contextSceneRefreshToken', (current ?? 0) + 1);
    FormRefreshCoordinator.schedule(this.context, 'scene_context_changed');
  }

  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    this.pendingRoute = this.routeFromWant(want);
    this.pendingRouteAction = this.routeActionFromWant(want);
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      AppLogger.error('Unable to follow the system color mode', err as Object);
    }
    AppStorage.setOrCreate('contextSceneRefreshToken', 0);
    this.contextMonitor = new SceneContextMonitor(
      this.context,
      (rule: SceneContextRule): boolean => this.showContextScenePrompt(rule),
      (): void => this.publishContextSceneChange()
    );
    SceneContextRuntime.attach(this.contextMonitor);
    AppLogger.info('Ability created');
  }

  onDestroy(): void {
    if (this.contextMonitor !== undefined) {
      this.contextMonitor.stop();
      SceneContextRuntime.detach(this.contextMonitor);
      this.contextMonitor = undefined;
    }
    AppLogger.info('Ability destroyed');
  }

  private applyFreeWindowSupport(mainWindow: window.Window, windowStage: window.WindowStage): void {
    try {
      windowStage.setWindowRectAutoSave(true)
        .then(() => {
          AppLogger.info('Enabled the free-window rect auto-save');
        })
        .catch((err: Object) => {
          AppLogger.error('Unable to enable the free-window rect auto-save', err);
        });
    } catch (err) {
      AppLogger.error('Unable to configure the free-window rect auto-save', err as Object);
    }
    try {
      const limits: window.WindowLimits = {
        minWidth: 360,
        minHeight: 240
      };
      mainWindow.setWindowLimits(limits)
        .then((applied: window.WindowLimits) => {
          AppLogger.info(`Applied the free-window size limit ${applied.minWidth}x${applied.minHeight}`);
        })
        .catch((err: Object) => {
          AppLogger.error('Unable to apply the free-window size limit', err);
        });
    } catch (err) {
      AppLogger.error('Unable to configure the free-window size limit', err as Object);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    AppLogger.info('Main window stage created');

    try {
      this.mainWindow = windowStage.getMainWindowSync();
      this.applyWindowTheme(this.mainWindow);
      this.applyFreeWindowSupport(this.mainWindow, windowStage);
    } catch (err) {
      AppLogger.error('Unable to configure the main window', err as Object);
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        AppLogger.error('Unable to load the home page', err);
        return;
      }
      AppLogger.info('Home page loaded');
      if (this.mainWindow !== undefined) {
        this.applyWindowTheme(this.mainWindow);
      }
      this.openPendingRoute();
    });
  }

  onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    this.pendingRoute = this.routeFromWant(want);
    this.pendingRouteAction = this.routeActionFromWant(want);
    this.openPendingRoute();
  }

  onWindowStageDestroy(): void {
    this.contextMonitor?.stop();
    this.mainWindow = undefined;
    AppLogger.info('Main window stage destroyed');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    AppLogger.info(`Configuration updated, color mode: ${newConfig.colorMode}`);
    if (this.mainWindow !== undefined) {
      this.applyWindowTheme(this.mainWindow);
    }
  }

  onForeground(): void {
    this.contextMonitor?.start();
    AppLogger.info('Ability entered foreground');
  }

  onBackground(): void {
    this.contextMonitor?.stop();
    AppLogger.info('Ability entered background');
  }
}

import { common } from '@kit.AbilityKit';
import { curves, window } from '@kit.ArkUI';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppLogger } from '../common/AppLogger';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { DataHealthService } from '../service/DataHealthService';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { FocusStatusCard } from '../components/FocusStatusCard';
import { HDS_SECONDARY_BUTTON } from '../components/HdsImmersiveButton';
import { RankingListSection } from '../components/RankingListSection';
import { SceneHeroCard } from '../components/SceneHeroCard';
import { SceneSwitchDialog } from '../components/SceneSwitchDialog';
import { SectionHeader } from '../components/SectionHeader';
import { SceneType } from '../model/SceneType';
import { SceneActionType, SceneViewModel } from '../model/ViewModels';
import { AppStateService } from '../service/AppStateService';
import { FocusService } from '../service/FocusService';
import { FormRefreshCoordinator } from '../service/FormRefreshCoordinator';
import { SceneStateService } from '../service/SceneStateService';
import { SceneViewModelService } from '../service/SceneViewModelService';
import { TaskService } from '../service/TaskService';

@Entry
@Component
struct Index {
  @StorageLink('contextSceneRefreshToken') @Watch('onContextSceneChanged')
  private contextSceneRefreshToken: number = 0;
  @State private isLoading: boolean = true;
  @State private isSwitching: boolean = false;
  @State private viewModel: SceneViewModel = SceneViewModel.empty();
  @State private contentOpacity: number = 1;
  @State private heroScale: number = 1;
  @State private isSceneSwitcherShown: boolean = false;
  @State private topAvoidVp: number = 40;
  @State private bottomAvoidVp: number = 44;
  private lastLoadAt: number = 0;
  private onboardingNavigationStarted: boolean = false;
  private openSceneSwitcherOnShow: boolean = false;
  private mainWindow: window.Window | undefined = undefined;
  private readonly onAvoidAreaChange = (_options: window.AvoidAreaOptions): void => {
    if (this.mainWindow !== undefined) {
      this.refreshTopAvoidArea(this.mainWindow);
    }
  };

  aboutToAppear(): void {
    this.observeAvoidArea();
    this.loadState();
    this.openSceneSwitcherOnShow = this.requestedCardAction() === 'openSceneSwitcher';
  }

  aboutToDisappear(): void {
    if (this.mainWindow !== undefined) {
      this.mainWindow.off('avoidAreaChange', this.onAvoidAreaChange);
      this.mainWindow = undefined;
    }
  }

  onPageShow(): void {
    if (Date.now() - this.lastLoadAt > 500) {
      this.loadState();
    }
    if (this.openSceneSwitcherOnShow) {
      this.openSceneSwitcherOnShow = false;
      setTimeout(() => this.openSceneSwitcher(), 0);
    }
  }

  private abilityContext(): common.Context | undefined {
    return this.getUIContext().getHostContext();
  }

  private observeAvoidArea(): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined) {
      return;
    }
    window.getLastWindow(context).then((mainWindow: window.Window) => {
      this.mainWindow = mainWindow;
      this.refreshTopAvoidArea(mainWindow);
      mainWindow.on('avoidAreaChange', this.onAvoidAreaChange);
    }).catch((error: Object) => {
      AppLogger.error('Unable to observe the home-page avoid area', error);
    });
  }

  private refreshTopAvoidArea(mainWindow: window.Window): void {
    try {
      const systemArea: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const cutoutArea: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const gestureArea: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM_GESTURE);
      const topHeightPx: number = Math.max(systemArea.topRect.height, cutoutArea.topRect.height);
      const bottomHeightPx: number = Math.max(systemArea.bottomRect.height, gestureArea.bottomRect.height);
      this.topAvoidVp = Math.max(0, this.getUIContext().px2vp(topHeightPx));
      this.bottomAvoidVp = Math.max(44, this.getUIContext().px2vp(bottomHeightPx));
    } catch (error) {
      AppLogger.error('Unable to refresh the home-page avoid area', error as Object);
    }
  }

  private requestedCardAction(): string {
    try {
      const rawParams: Object | undefined = this.getUIContext().getRouter().getParams();
      if (rawParams === undefined || rawParams === null) {
        return '';
      }
      const params: Record<string, Object> = rawParams as Record<string, Object>;
      const action: Object | undefined = params['cardAction'];
      return typeof action === 'string' ? action : '';
    } catch (_) {
      return '';
    }
  }

  private loadState(): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined) {
      const empty: SceneViewModel = SceneViewModel.empty();
      empty.hasDataError = true;
      this.viewModel = empty;
      this.isLoading = false;
      return;
    }
    if (AppStateService.shouldShowOnboarding(context) && !this.onboardingNavigationStarted) {
      this.onboardingNavigationStarted = true;
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/OnboardingPage' }).catch(() => {
        this.onboardingNavigationStarted = false;
      });
      return;
    }
    try {
      this.viewModel = SceneViewModelService.build(context);
    } catch (_) {
      this.viewModel = SceneViewModelService.safeEmpty(context);
    }
    this.lastLoadAt = Date.now();
    this.isLoading = false;
  }

  private onContextSceneChanged(): void {
    this.loadState();
  }

  private openSceneSwitcher(): void {
    if (this.isSwitching) {
      this.showToast($r('app.string.scene_switch_busy'));
      return;
    }
    this.isSceneSwitcherShown = true;
  }

  private applySceneSelection(sceneType: SceneType, durationMinutes: number): boolean {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined) {
      this.showToast($r('app.string.operation_failed'));
      return false;
    }
    this.isSwitching = true;
    this.getUIContext().animateTo({
      duration: 100,
      curve: Curve.EaseOut
    }, () => {
      this.contentOpacity = 0.72;
      this.heroScale = 0.985;
    });
    try {
      const locked: boolean = durationMinutes === 0;
      const validDuration: number = locked ? 120 : durationMinutes;
      if (!SceneStateService.activateManual(context, sceneType, locked, validDuration)) {
        this.showToast($r('app.string.operation_failed'));
        return false;
      }
      const nextModel: SceneViewModel = SceneViewModelService.build(context);
      if (nextModel.scene !== sceneType || !nextModel.isManualOverride) {
        AppLogger.error(`Scene switch verification failed for ${sceneType}`);
        this.showToast($r('app.string.scene_switch_not_applied'));
        return false;
      }
      this.viewModel = nextModel;
      this.lastLoadAt = Date.now();
      FormRefreshCoordinator.schedule(context, 'home_scene_changed');
      this.showToast($r('app.string.scene_switch_success'));
      AppLogger.info(`Home scene switched to ${sceneType} for ${locked ? 'locked' : durationMinutes}`);
      return true;
    } catch (error) {
      AppLogger.error('Unable to switch the home scene', error as Object);
      this.showToast($r('app.string.operation_failed'));
      return false;
    } finally {
      this.finishSwitch();
    }
  }

  private finishSwitch(): void {
    setTimeout(() => {
      this.isSwitching = false;
      this.getUIContext().animateTo({
        curve: curves.springMotion(0.38, 1.0)
      }, () => {
        this.contentOpacity = 1;
        this.heroScale = 1;
      });
    }, 80);
  }

  private restoreAutomatic(): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined || !SceneStateService.restoreAutomatic(context)) {
      this.showToast($r('app.string.operation_failed'));
      return;
    }
    this.viewModel = SceneViewModelService.build(context);
    FormRefreshCoordinator.schedule(context, 'automatic_scene_restored');
  }

  private toggleManualLock(): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined ||
      !SceneStateService.setManualLocked(context, !this.viewModel.isManualLocked)) {
      this.showToast($r('app.string.operation_failed'));
      return;
    }
    this.viewModel = SceneViewModelService.build(context);
    FormRefreshCoordinator.schedule(context, 'manual_lock_changed');
  }

  private performPrimaryAction(): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined) {
      return;
    }
    let success: boolean = true;
    switch (this.viewModel.primaryAction.type) {
      case SceneActionType.COMPLETE_TASK:
        success = new TaskService(context).completeTask(this.viewModel.primaryAction.taskId);
        break;
      case SceneActionType.START_FOCUS:
        success = new FocusService(context).startFocus(this.viewModel.primaryAction.durationMinutes,
          this.viewModel.scene);
        break;
      case SceneActionType.STOP_FOCUS:
        success = new FocusService(context).stopFocus();
        break;
      case SceneActionType.OPEN_COURSES:
        this.openPage('pages/CourseListPage');
        return;
      case SceneActionType.OPEN_TASKS:
        this.openPage('pages/TaskListPage');
        return;
      case SceneActionType.OPEN_SERVICE:
        this.showToast($r('app.string.action_feedback'));
        return;
      default:
        return;
    }
    if (!success) {
      this.showToast($r('app.string.operation_failed'));
      return;
    }
    this.viewModel = SceneViewModelService.build(context);
    FormRefreshCoordinator.schedule(context, 'home_primary_action');
  }

  private retryData(): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context !== undefined) {
      DataHealthService.retry(context);
      this.loadState();
    }
  }

  private openPage(url: string): void {
    this.getUIContext().getRouter().pushUrl({ url: url }).catch(() => {
      this.showToast($r('app.string.operation_failed'));
    });
  }

  private showToast(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  private greeting(): Resource {
    const hour: number = new Date().getHours();
    if (hour < 11) {
      return $r('app.string.greeting_morning');
    }
    if (hour < 13) {
      return $r('app.string.greeting_noon');
    }
    if (hour < 18) {
      return $r('app.string.greeting_afternoon');
    }
    return $r('app.string.greeting_evening');
  }

  private currentDate(): string {
    const date: Date = new Date();
    return `${date.getMonth() + 1}月${date.getDate()}日`;
  }

  private weekday(): Resource {
    switch (new Date().getDay()) {
      case 0: return $r('app.string.weekday_sunday');
      case 1: return $r('app.string.weekday_monday');
      case 2: return $r('app.string.weekday_tuesday');
      case 3: return $r('app.string.weekday_wednesday');
      case 4: return $r('app.string.weekday_thursday');
      case 5: return $r('app.string.weekday_friday');
      case 6: return $r('app.string.weekday_saturday');
      default: return $r('app.string.weekday_monday');
    }
  }

  @Builder
  private ManagementRow(title: Resource, symbol: Resource, url: string, isLast: boolean) {
    Row({ space: 12 }) {
      Stack() {
        SymbolGlyph(symbol)
          .fontSize(18)
          .fontColor([AppColors.ACCENT])
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .systemMaterial(ImmersiveMaterials.ACCENT_CHIP)

      Text(title)
        .fontSize(AppTypography.BODY_LARGE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_PRIMARY)
        .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([AppColors.TEXT_TERTIARY])
    }
    .width('100%')
    .height(60)
    .padding({ left: 14, right: 14 })
    .focusable(true)
    .accessibilityText(title)
    .onClick(() => this.openPage(url))

    if (!isLast) {
      Divider()
        .color(AppColors.BORDER)
        .margin({ left: 62 })
    }
  }

  @Builder
  private SceneSwitcherContent() {
    SceneSwitchDialog({
      currentSceneProvider: () => this.viewModel.scene,
      onConfirm: (scene: SceneType, durationMinutes: number) =>
        this.applySceneSelection(scene, durationMinutes),
      onCancel: () => this.isSceneSwitcherShown = false
    })
  }

  @Builder
  private SceneHeroBlock() {
    Column() {
      SceneHeroCard({
        model: this.viewModel,
        interactionEnabled: !this.isSwitching,
        onPrimaryAction: () => this.performPrimaryAction(),
        onSwitchScene: () => this.openSceneSwitcher(),
        onRestoreAuto: () => this.restoreAutomatic(),
        onToggleManualLock: () => this.toggleManualLock()
      })
    }
    .width('100%')
    .opacity(this.contentOpacity)
    .scale({ x: this.heroScale, y: this.heroScale })
  }

  @Builder
  private RunningFocusBlock() {
    if (this.viewModel.hasRunningFocus) {
      FocusStatusCard({
        remainingMinutes: this.viewModel.focusRemainingMinutes,
        onOpen: () => this.openPage('pages/FocusPage')
      })
    }
  }

  @Builder
  private TodayFocusBlock() {
    if (this.viewModel.todayFocus.length > 0) {
      RankingListSection({ title: $r('app.string.today_focus'), items: this.viewModel.todayFocus })
    } else {
      SectionHeader({ title: $r('app.string.today_focus') })
      EmptyState({
        title: $r('app.string.no_today_focus'),
        description: $r('app.string.no_today_focus_desc')
      })
    }
  }

  @Builder
  private UpcomingBlock() {
    if (this.viewModel.upcoming.length > 0) {
      RankingListSection({ title: $r('app.string.upcoming'), items: this.viewModel.upcoming })
    }
  }

  @Builder
  private ManagementBlock() {
    SectionHeader({ title: $r('app.string.management') })
    Column() {
      this.ManagementRow($r('app.string.schedule_page_title'), $r('sys.symbol.calendar'),
        'pages/SchedulePage', false)
      this.ManagementRow($r('app.string.manage_courses'), $r('sys.symbol.doc'),
        'pages/CourseListPage', false)
      this.ManagementRow($r('app.string.manage_tasks'), $r('sys.symbol.checkmark'),
        'pages/TaskListPage', false)
      this.ManagementRow($r('app.string.manage_rules'), $r('sys.symbol.clock'),
        'pages/SceneRuleListPage', false)
      this.ManagementRow($r('app.string.manage_focus'), $r('sys.symbol.star'),
        'pages/FocusPage', true)
    }
    .width('100%')
    .borderRadius(AppDimensions.RADIUS_PRIMARY)
    .systemMaterial(ImmersiveMaterials.CARD)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Row() {}
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [AppColors.HERO_TINT_TOP, 0],
            [AppColors.PAGE_BACKGROUND, 0.28],
            [AppColors.PAGE_BACKGROUND, 1]
          ]
        })
        .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT],
          [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      Column() {
        Scroll() {
          Row() {
            Column({ space: 24 }) {
              Row() {
                Column({ space: 6 }) {
                  Row({ space: 8 }) {
                    Text(this.currentDate())
                      .fontSize(AppTypography.BODY_MEDIUM)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColors.ACCENT)
                    Text(this.weekday())
                      .fontSize(AppTypography.BODY_MEDIUM)
                      .fontColor(AppColors.TEXT_SECONDARY)
                  }
                  Text(this.greeting())
                    .fontSize(AppTypography.DISPLAY)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppColors.TEXT_PRIMARY)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Button($r('app.string.settings'))
                  .height(44)
                  .fontSize(AppTypography.LABEL)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.ACCENT)
                  .borderRadius(AppDimensions.RADIUS_PILL)
                  .padding({ left: 16, right: 16 })
                  .attributeModifier(HDS_SECONDARY_BUTTON)
                  .onClick(() => this.openPage('pages/SettingsPage'))
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              if (this.isLoading) {
                LoadingProgress().width(32).height(32).color(AppColors.ACCENT)
              } else {
                if (this.viewModel.hasDataError) {
                  ErrorState({ onRetry: () => this.retryData() })
                }
                GridRow({
                  columns: { xs: 4, sm: 4, md: 12 },
                  gutter: { x: 24, y: 24 },
                  breakpoints: { value: ['600vp', '840vp'] }
                }) {
                  GridCol({ span: { xs: 4, sm: 4, md: 5 } }) {
                    Column({ space: 24 }) {
                      this.SceneHeroBlock()
                      this.RunningFocusBlock()
                    }
                    .width('100%')
                  }

                  GridCol({ span: { xs: 4, sm: 4, md: 7 } }) {
                    Column({ space: 24 }) {
                      this.TodayFocusBlock()
                      this.UpcomingBlock()
                      this.ManagementBlock()
                    }
                    .width('100%')
                  }
                }
                .width('100%')
              }
            }
            .width('100%')
            .constraintSize({ maxWidth: AppDimensions.MAX_PAGE_WIDTH })
            .padding({
              left: AppDimensions.PAGE_HORIZONTAL_PADDING,
              right: AppDimensions.PAGE_HORIZONTAL_PADDING,
              top: this.topAvoidVp + 12,
              bottom: this.bottomAvoidVp
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .align(Alignment.Top)
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .clip(true)
      }
      .width('100%')
      .height('100%')

      Row() {}
        .width('100%')
        .height(this.topAvoidVp + 18)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [AppColors.PAGE_BACKGROUND, 0],
            [AppColors.HERO_TINT_TOP, 0.82],
            [AppColors.PAGE_BACKGROUND_TRANSPARENT, 1]
          ]
        })
        .zIndex(10)
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .background(AppColors.PAGE_BACKGROUND)
    .bindSheet($$this.isSceneSwitcherShown, this.SceneSwitcherContent(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: false,
      preferType: SheetType.BOTTOM,
      backgroundColor: Color.Transparent,
      systemMaterial: ImmersiveMaterials.HALF_MODAL
    })
  }
}

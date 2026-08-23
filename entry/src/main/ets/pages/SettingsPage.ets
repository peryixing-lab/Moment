import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppLogger } from '../common/AppLogger';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { HDS_BRAND_RED_BUTTON, HDS_DANGER_BUTTON, HDS_PRIMARY_BUTTON, HDS_SECONDARY_BUTTON } from '../components/HdsImmersiveButton';
import { HdsImmersiveNavigation } from '../components/HdsImmersiveNavigation';
import { SectionHeader } from '../components/SectionHeader';
import { AppMode, AppSettings, SettingsReadResult } from '../model/SceneModels';
import { SceneType, SceneTypes } from '../model/SceneType';
import { AccountService, HuaweiAccount } from '../service/AccountService';
import { AppStateService } from '../service/AppStateService';
import { CloudSyncResult, CloudSyncService } from '../service/CloudSyncService';
import { DataResetService } from '../service/DataResetService';
import { FormRefreshCoordinator } from '../service/FormRefreshCoordinator';
import { SceneContextRuntime } from '../service/SceneContextRuntime';
import { ScenePresentationService } from '../service/ScenePresentationService';
import { SystemLinkageService } from '../service/SystemLinkageService';

@Entry
@Component
struct SettingsPage {
  @State private autoRecommendationEnabled: boolean = true;
  @State private defaultScene: SceneType = SceneType.LIBRARY;
  @State private showSecondaryInfo: boolean = true;
  @State private silentLinkageEnabled: boolean = false;
  @State private hasStorageError: boolean = false;
  @State private account: HuaweiAccount | undefined = undefined;
  @State private syncing: boolean = false;
  @State private loggingIn: boolean = false;
  @State private accountErrorText: string = '';
  @State private avatarFailed: boolean = false;
  @State private syncStateText: Resource = $r('app.string.account_sync_idle');
  @State private appMode: AppMode = AppMode.FULL;
  @State private autoSyncEnabled: boolean = true;
  private contentScroller: Scroller = new Scroller();
  private scenes: SceneType[] = SceneTypes.all();

  aboutToAppear(): void {
    this.loadSettings();
    this.loadSilentLinkage();
    this.loadAccount();
  }

  private abilityContext(): common.Context | undefined {
    return this.getUIContext().getHostContext();
  }

  private loadSettings(): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined) {
      this.hasStorageError = true;
      return;
    }
    const result: SettingsReadResult = AppStateService.settings(context);
    this.applySettings(result.settings);
    this.hasStorageError = !result.success;
  }

  private applySettings(settings: AppSettings): void {
    this.autoRecommendationEnabled = settings.autoRecommendationEnabled;
    this.defaultScene = settings.defaultScene;
    this.showSecondaryInfo = settings.showSecondaryInfo;
    this.appMode = settings.appMode;
    this.autoSyncEnabled = settings.autoSyncEnabled;
  }

  private updateAuto(value: boolean): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined || !AppStateService.updateAutoRecommendation(context, value)) {
      this.hasStorageError = true;
      this.loadSettings();
      return;
    }
    this.autoRecommendationEnabled = value;
    this.hasStorageError = false;
    SceneContextRuntime.notifyRulesChanged();
    FormRefreshCoordinator.schedule(context, 'settings_auto_changed');
  }

  private updateDefault(scene: SceneType): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined || !AppStateService.updateDefaultScene(context, scene)) {
      this.hasStorageError = true;
      return;
    }
    this.defaultScene = scene;
    this.hasStorageError = false;
    FormRefreshCoordinator.schedule(context, 'settings_default_changed');
  }

  private updateSecondary(value: boolean): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined || !AppStateService.updateSecondaryInfo(context, value)) {
      this.hasStorageError = true;
      return;
    }
    this.showSecondaryInfo = value;
    this.hasStorageError = false;
    FormRefreshCoordinator.schedule(context, 'settings_secondary_changed');
  }

  private resetSettings(): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined || !AppStateService.resetDisplaySettings(context)) {
      this.hasStorageError = true;
      this.showToast($r('app.string.reset_failed'));
      return;
    }
    this.loadSettings();
    this.showToast($r('app.string.reset_done'));
    FormRefreshCoordinator.schedule(context, 'settings_reset');
  }

  private loadSilentLinkage(): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined) {
      return;
    }
    this.silentLinkageEnabled = SystemLinkageService.isEnabled(context);
  }

  private updateSilentLinkage(value: boolean): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined || !SystemLinkageService.setEnabled(context, value)) {
      this.hasStorageError = true;
      this.silentLinkageEnabled = !value;
      return;
    }
    this.silentLinkageEnabled = value;
  }

  private loadAccount(): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined) {
      this.account = undefined;
      return;
    }
    this.account = AccountService.load(context);
    if (this.account === undefined) {
      this.syncStateText = $r('app.string.account_sync_idle');
      this.syncing = false;
    }
    this.avatarFailed = false;
  }

  private loginHuaweiAccount(): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined || this.loggingIn) {
      return;
    }
    this.loggingIn = true;
    this.accountErrorText = '';
    const previous: HuaweiAccount | undefined = AccountService.load(context);
    AccountService.login(context).then((errorDetail: string) => {
      this.loggingIn = false;
      if (errorDetail.length > 0) {
        this.accountErrorText = errorDetail;
        return;
      }
      this.loadAccount();
      this.syncStateText = $r('app.string.account_sync_idle');
      const current: HuaweiAccount | undefined = AccountService.load(context);
      const isSwitch: boolean = previous !== undefined && current !== undefined && previous.uid !== current.uid;
      if (isSwitch && DataResetService.hasLocalData(context)) {
        this.promptAccountMerge(context);
        return;
      }
      if (isSwitch) {
        this.runSyncAfterSwitch(context, false);
        return;
      }
      CloudSyncService.prepareCloud();
      this.showToast($r('app.string.account_signed_in'));
    }).catch((error: Object) => {
      this.loggingIn = false;
      const businessError: BusinessError = error as BusinessError;
      const message: string = typeof businessError.message === 'string' ?
        businessError.message : '未知错误';
      this.accountErrorText = `登录失败：${message}`;
      AppLogger.error('HUAWEI ID sign-in failed', error);
    });
  }

  private promptAccountMerge(context: common.Context): void {
    this.getUIContext().getPromptAction().showDialog({
      title: $r('app.string.account_switch_title'),
      message: $r('app.string.account_switch_message'),
      buttons: [
        { text: $r('app.string.cancel'), color: AppColors.TEXT_SECONDARY },
        { text: $r('app.string.account_merge'), color: AppColors.ACCENT },
        { text: $r('app.string.account_replace'), color: AppColors.DANGER }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.runSyncAfterSwitch(context, false);
      } else if (result.index === 2) {
        this.runSyncAfterSwitch(context, true);
      }
    }).catch(() => {
      this.showToast($r('app.string.operation_failed'));
    });
  }

  private runSyncAfterSwitch(context: common.Context, replaceLocal: boolean): void {
    this.syncing = true;
    this.accountErrorText = '';
    this.syncStateText = $r('app.string.account_syncing');
    CloudSyncService.syncForAccount(context, replaceLocal).then((result: CloudSyncResult) => {
      this.applySyncResult(result);
    }).catch((error: Object) => {
      this.syncing = false;
      this.syncStateText = $r('app.string.account_sync_failed');
      this.accountErrorText = '同步失败：未知错误';
      AppLogger.error('Cloud sync failed after account switch', error);
    });
  }

  private applySyncResult(result: CloudSyncResult): void {
    this.syncing = false;
    if (result.success) {
      this.syncStateText = $r('app.string.account_sync_done');
      this.showToast($r('app.string.account_sync_done'));
    } else if (result.detail === 'not_signed_in') {
      this.syncStateText = $r('app.string.account_sync_idle');
    } else if (result.detail === 'session_expired') {
      this.syncStateText = $r('app.string.account_sync_failed');
      this.accountErrorText = '云端会话正在刷新失败，请检查网络；若仍失败再重新登录。';
    } else if (result.detail === 'auth_init_failed') {
      this.syncStateText = $r('app.string.account_sync_failed');
      this.accountErrorText = '认证服务初始化失败，请重启应用后重试。';
    } else if (result.detail === 'init_failed') {
      this.syncStateText = $r('app.string.account_sync_failed');
      this.accountErrorText = '云服务初始化失败，请重启应用后重试。';
    } else if (result.detail === 'local_reset_failed') {
      this.syncStateText = $r('app.string.account_sync_failed');
      this.accountErrorText = '清除本机数据失败，请重试。';
    } else {
      this.syncStateText = $r('app.string.account_sync_failed');
      this.accountErrorText = result.detail.startsWith('sync_failed(') ?
        `同步失败：${result.detail}` : result.detail;
    }
  }

  private runCloudSync(): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined || this.syncing) {
      return;
    }
    this.syncing = true;
    this.accountErrorText = '';
    this.syncStateText = $r('app.string.account_syncing');
    CloudSyncService.sync(context).then((result: CloudSyncResult) => {
      this.applySyncResult(result);
    }).catch((error: Object) => {
      this.syncing = false;
      this.syncStateText = $r('app.string.account_sync_failed');
      this.accountErrorText = '同步失败：未知错误';
      AppLogger.error('Cloud sync failed unexpectedly', error);
    });
  }

  private updateAppMode(mode: AppMode): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined) {
      return;
    }
    if (mode === AppMode.LITE) {
      AccountService.logout(context).then(() => {
        if (!AppStateService.updateAppMode(context, AppMode.LITE)) {
          this.hasStorageError = true;
          return;
        }
        this.loadSettings();
        this.loadAccount();
      });
      return;
    }
    if (!AppStateService.updateAppMode(context, AppMode.FULL)) {
      this.hasStorageError = true;
      return;
    }
    this.loadSettings();
  }

  private updateAutoSync(value: boolean): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined || !AppStateService.updateAutoSync(context, value)) {
      this.hasStorageError = true;
      return;
    }
    this.autoSyncEnabled = value;
    this.hasStorageError = false;
  }

  private logout(): void {
    const context: common.Context | undefined = this.abilityContext();
    if (context === undefined) {
      this.showToast($r('app.string.operation_failed'));
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: $r('app.string.account_logout_title'),
      message: $r('app.string.account_logout_message'),
      buttons: [
        { text: $r('app.string.cancel'), color: AppColors.TEXT_SECONDARY },
        { text: $r('app.string.account_keep_data'), color: AppColors.TEXT_SECONDARY },
        { text: $r('app.string.account_clear_data'), color: AppColors.DANGER }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.performLogout(context, false);
      } else if (result.index === 2) {
        this.performLogout(context, true);
      }
    }).catch(() => {
      this.showToast($r('app.string.operation_failed'));
    });
  }

  private performLogout(context: common.Context, clearData: boolean): void {
    if (clearData) {
      DataResetService.resetSyncedTables(context);
      CloudSyncService.clearManifest(context);
    }
    AccountService.logout(context).then((cleared: boolean) => {
      if (!cleared) {
        this.showToast($r('app.string.account_logout_failed'));
        return;
      }
      this.loadAccount();
      this.showToast($r('app.string.account_signed_out'));
    });
  }

  private maskedUid(value: string): string {
    if (value.length <= 8) {
      return value;
    }
    return `${value.substring(0, 4)}****${value.substring(value.length - 4)}`;
  }

  private maskedEmail(): string {
    const email: string = this.account?.email ?? '';
    if (email.length > 0) {
      const at: number = email.indexOf('@');
      if (at > 0) {
        const prefix: string = email.substring(0, at);
        const suffix: string = email.substring(at);
        return `${prefix.charAt(0)}***${suffix}`;
      }
      return this.maskedUid(email);
    }
    return this.maskedUid(this.account?.uid ?? '');
  }

  private accountAvatarChar(): string {
    const name: string = this.account?.displayName ?? '';
    if (name.length > 0) {
      return name.substring(0, 1);
    }
    const email: string = this.account?.email ?? '';
    if (email.length > 0) {
      return email.substring(0, 1);
    }
    return '华';
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

  @Builder
  private SwitchRow(title: Resource, description: Resource, checked: boolean,
    onChange: (value: boolean) => void) {
    Row() {
      Column({ space: 4 }) {
        Text(title).fontSize(AppTypography.BODY_LARGE).fontColor(AppColors.TEXT_PRIMARY)
        Text(description)
          .fontSize(AppTypography.CAPTION)
          .fontColor(AppColors.TEXT_SECONDARY)
          .maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: checked })
        .selectedColor(AppColors.ACCENT)
        .onChange((value: boolean) => onChange(value))
    }
    .width('100%')
    .height(76)
  }

  @Builder
  private ManagementRow(title: Resource, url: string, showDivider: boolean) {
    Column() {
      Row({ space: 12 }) {
        Text(title)
          .fontSize(AppTypography.BODY_LARGE)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([AppColors.TEXT_TERTIARY])
      }
      .width('100%')
      .height(56)
      .focusable(true)
      .accessibilityText(title)
      .onClick(() => this.openPage(url))
      if (showDivider) {
        Divider().color(AppColors.BORDER)
      }
    }
    .width('100%')
  }

  build() {
    Stack() {
      HdsImmersiveNavigation({
        title: $r('app.string.settings_title'),
        backLabel: $r('app.string.back'),
        scrollController: this.contentScroller,
        onBack: () => this.getUIContext().getRouter().back()
      }) {
        Scroll(this.contentScroller) {
          Row() {
            Column({ space: 24 }) {
              if (this.hasStorageError) {
              Text($r('app.string.storage_warning'))
                .width('100%')
                .padding(12)
                .fontSize(AppTypography.CAPTION)
                .fontColor(AppColors.WARNING_TEXT)
                .borderRadius(AppDimensions.RADIUS_SECONDARY)
                .systemMaterial(ImmersiveMaterials.WARNING_SURFACE)
            }

            SectionHeader({ title: $r('app.string.settings_app_mode') })
            Column() {
              Text($r('app.string.settings_app_mode_desc'))
                .width('100%')
                .fontSize(AppTypography.CAPTION)
                .fontColor(AppColors.TEXT_SECONDARY)
                .maxLines(2)
              Row({ space: 8 }) {
                Button($r('app.string.app_mode_full'))
                  .layoutWeight(1)
                  .height(AppDimensions.MIN_TOUCH_TARGET)
                  .fontSize(AppTypography.CAPTION)
                  .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
                    maxFontSize: AppTypography.CAPTION, overflow: TextOverflow.Clip })
                  .fontColor(this.appMode === AppMode.FULL ? AppColors.TEXT_PRIMARY :
                    AppColors.TEXT_SECONDARY)
                  .borderRadius(AppDimensions.RADIUS_SECONDARY)
                  .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
                    right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
                  .attributeModifier(this.appMode === AppMode.FULL ?
                    HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
                  .onClick(() => this.updateAppMode(AppMode.FULL))
                Button($r('app.string.app_mode_lite'))
                  .layoutWeight(1)
                  .height(AppDimensions.MIN_TOUCH_TARGET)
                  .fontSize(AppTypography.CAPTION)
                  .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
                    maxFontSize: AppTypography.CAPTION, overflow: TextOverflow.Clip })
                  .fontColor(this.appMode === AppMode.LITE ? AppColors.TEXT_PRIMARY :
                    AppColors.TEXT_SECONDARY)
                  .borderRadius(AppDimensions.RADIUS_SECONDARY)
                  .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
                    right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
                  .attributeModifier(this.appMode === AppMode.LITE ?
                    HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
                  .onClick(() => this.updateAppMode(AppMode.LITE))
              }
              .width('100%')
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 16, bottom: 16 })
            .borderRadius(AppDimensions.RADIUS_PRIMARY)
            .systemMaterial(ImmersiveMaterials.CARD)

            if (this.appMode === AppMode.FULL) {
            Column() {
              this.SwitchRow($r('app.string.auto_sync'), $r('app.string.auto_sync_desc'),
                this.autoSyncEnabled, (value: boolean) => this.updateAutoSync(value))
            }
            .width('100%')
            .padding({ left: 18, right: 18 })
            .borderRadius(AppDimensions.RADIUS_PRIMARY)
            .systemMaterial(ImmersiveMaterials.CARD)

            SectionHeader({ title: $r('app.string.account_section_title') })
            if (this.account === undefined) {
              Column({ space: 16 }) {
                Text($r('app.string.account_login_desc'))
                  .width('100%')
                  .fontSize(AppTypography.BODY_MEDIUM)
                  .fontColor(AppColors.TEXT_SECONDARY)
                if (this.accountErrorText.length > 0) {
                  Text(this.accountErrorText)
                    .width('100%')
                    .fontSize(AppTypography.CAPTION)
                    .fontColor(AppColors.WARNING_TEXT)
                    .maxLines(3)
                }
                Button($r('app.string.account_login_now'))
                  .width('100%')
                  .height(AppDimensions.BUTTON_HEIGHT)
                  .fontSize(AppTypography.BODY_MEDIUM)
                  .fontColor(Color.White)
                  .borderRadius(AppDimensions.RADIUS_PILL)
                  .attributeModifier(HDS_BRAND_RED_BUTTON)
                  .enabled(!this.loggingIn)
                  .onClick(() => this.loginHuaweiAccount())
              }
              .width('100%')
              .padding({
                left: 20,
                right: 20,
                top: 20,
                bottom: 20
              })
              .borderRadius(AppDimensions.RADIUS_PRIMARY)
              .systemMaterial(ImmersiveMaterials.CARD)
            } else {
              Column({ space: 16 }) {
                Row({ space: 12 }) {
                  Stack() {
                    Text(this.accountAvatarChar())
                      .width(52)
                      .height(52)
                      .padding(0)
                      .textAlign(TextAlign.Center)
                      .borderRadius(26)
                      .fontSize(AppTypography.BODY_LARGE)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColors.ON_ACCENT)
                      .backgroundColor(AppColors.ACCENT)
                    if (this.account.photoUrl.length > 0 && !this.avatarFailed) {
                      Image(this.account.photoUrl)
                        .width(52)
                        .height(52)
                        .borderRadius(26)
                        .objectFit(ImageFit.Cover)
                        .onError(() => this.avatarFailed = true)
                    }
                  }
                  .width(52)
                  .height(52)

                  Column({ space: 4 }) {
                    Text(this.account.displayName.length > 0 ?
                      this.account.displayName : this.maskedUid(this.account.uid))
                      .fontSize(AppTypography.BODY_LARGE)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColors.TEXT_PRIMARY)
                    Text(this.maskedEmail())
                      .fontSize(AppTypography.CAPTION)
                      .fontColor(AppColors.TEXT_SECONDARY)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text(this.syncStateText)
                    .fontSize(AppTypography.CAPTION)
                    .fontColor(this.syncing ? AppColors.ACCENT : AppColors.TEXT_TERTIARY)
                }
                if (this.accountErrorText.length > 0) {
                  Text(this.accountErrorText)
                    .width('100%')
                    .fontSize(AppTypography.CAPTION)
                    .fontColor(AppColors.WARNING_TEXT)
                    .maxLines(3)
                }
                Divider().color(AppColors.BORDER)
                Button($r('app.string.account_sync_now'))
                  .width('100%')
                  .height(AppDimensions.BUTTON_HEIGHT)
                  .fontSize(AppTypography.BODY_MEDIUM)
                  .fontColor(AppColors.ACCENT)
                  .borderRadius(AppDimensions.RADIUS_PILL)
                  .attributeModifier(HDS_PRIMARY_BUTTON)
                  .enabled(!this.syncing)
                  .onClick(() => this.runCloudSync())
                Button($r('app.string.account_logout'))
                  .width('100%')
                  .height(AppDimensions.BUTTON_HEIGHT)
                  .fontSize(AppTypography.BODY_MEDIUM)
                  .fontColor(AppColors.DANGER)
                  .borderRadius(AppDimensions.RADIUS_PILL)
                  .attributeModifier(HDS_SECONDARY_BUTTON)
                  .onClick(() => this.logout())
              }
              .width('100%')
              .padding({
                left: 20,
                right: 20,
                top: 20,
                bottom: 20
              })
              .borderRadius(AppDimensions.RADIUS_PRIMARY)
              .systemMaterial(ImmersiveMaterials.CARD)
            }
            }

            SectionHeader({ title: $r('app.string.settings_scene_section') })
            Column() {
              this.SwitchRow($r('app.string.auto_recommendation'),
                $r('app.string.auto_recommendation_desc'), this.autoRecommendationEnabled,
                (value: boolean) => this.updateAuto(value))
              Divider().color(AppColors.BORDER)
              Column({ space: 10 }) {
                Text($r('app.string.default_scene'))
                  .width('100%')
                  .fontSize(AppTypography.BODY_LARGE)
                  .fontColor(AppColors.TEXT_PRIMARY)
                Text($r('app.string.default_scene_desc'))
                  .width('100%')
                  .fontSize(AppTypography.CAPTION)
                  .fontColor(AppColors.TEXT_SECONDARY)
                Row({ space: 8 }) {
                  ForEach(this.scenes, (sceneType: SceneType) => {
                    Button(ScenePresentationService.getPresentation(sceneType).name)
                      .layoutWeight(1)
                      .height(AppDimensions.MIN_TOUCH_TARGET)
                      .fontSize(AppTypography.CAPTION)
                      .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
                        maxFontSize: AppTypography.CAPTION, overflow: TextOverflow.Clip })
                      .fontColor(sceneType === this.defaultScene ? AppColors.TEXT_PRIMARY :
                        AppColors.TEXT_SECONDARY)
                      .borderRadius(AppDimensions.RADIUS_SECONDARY)
                      .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
                        right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
                      .attributeModifier(sceneType === this.defaultScene ?
                        HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
                      .onClick(() => this.updateDefault(sceneType))
                  }, (sceneType: SceneType) => sceneType)
                }
                .width('100%')
              }
              .width('100%')
              .padding({ top: 16, bottom: 12 })
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: 18, right: 18 })
            .borderRadius(AppDimensions.RADIUS_PRIMARY)
            .systemMaterial(ImmersiveMaterials.CARD)

            Column() {
              this.SwitchRow($r('app.string.scene_silent_toggle'),
                $r('app.string.scene_silent_toggle_desc'), this.silentLinkageEnabled,
                (value: boolean) => this.updateSilentLinkage(value))
            }
            .width('100%')
            .padding({ left: 18, right: 18 })
            .borderRadius(AppDimensions.RADIUS_PRIMARY)
            .systemMaterial(ImmersiveMaterials.CARD)

            SectionHeader({ title: $r('app.string.settings_display_section') })
            Column() {
              this.SwitchRow($r('app.string.show_secondary'), $r('app.string.show_secondary_desc'),
                this.showSecondaryInfo, (value: boolean) => this.updateSecondary(value))
            }
            .width('100%')
            .padding({ left: 18, right: 18 })
            .borderRadius(AppDimensions.RADIUS_PRIMARY)
            .systemMaterial(ImmersiveMaterials.CARD)

            SectionHeader({ title: $r('app.string.management') })
            Column() {
              this.ManagementRow($r('app.string.manage_courses'), 'pages/CourseListPage', true)
              this.ManagementRow($r('app.string.manage_tasks'), 'pages/TaskListPage', true)
              this.ManagementRow($r('app.string.manage_rules'), 'pages/SceneRuleListPage', true)
              this.ManagementRow($r('app.string.manage_context_rules'),
                'pages/SceneContextRuleListPage', true)
              this.ManagementRow($r('app.string.manage_focus'), 'pages/FocusPage', false)
            }
            .width('100%')
            .padding({ left: 18, right: 18 })
            .borderRadius(AppDimensions.RADIUS_PRIMARY)
            .systemMaterial(ImmersiveMaterials.CARD)

            SectionHeader({ title: $r('app.string.settings_data_section') })
            Column({ space: 18 }) {
              Button($r('app.string.reset_settings'))
                .width('100%')
                .height(AppDimensions.BUTTON_HEIGHT)
                .fontSize(AppTypography.BODY_MEDIUM)
                .fontColor(AppColors.ACCENT)
                .borderRadius(AppDimensions.RADIUS_PILL)
                .attributeModifier(HDS_SECONDARY_BUTTON)
                .onClick(() => this.resetSettings())
              Divider().color(AppColors.BORDER)
              Column({ space: 6 }) {
                Text($r('app.string.about_moment'))
                  .fontSize(AppTypography.BODY_LARGE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.TEXT_PRIMARY)
                Text($r('app.string.about_description'))
                  .fontSize(AppTypography.BODY_MEDIUM)
                  .fontColor(AppColors.TEXT_SECONDARY)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(18)
            .borderRadius(AppDimensions.RADIUS_PRIMARY)
            .systemMaterial(ImmersiveMaterials.CARD)
            }
            .width('100%')
            .constraintSize({ maxWidth: AppDimensions.MAX_CONTENT_WIDTH })
            .padding({ left: AppDimensions.PAGE_HORIZONTAL_PADDING, right: AppDimensions.PAGE_HORIZONTAL_PADDING,
              top: AppDimensions.PAGE_TOP_PADDING, bottom: AppDimensions.PAGE_BOTTOM_PADDING })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .align(Alignment.Top)
        .height('100%')
        .scrollBar(BarState.Off)
        .backgroundColor(AppColors.PAGE_BACKGROUND)
      }
    }
    .width('100%')
    .height('100%')
  }
}

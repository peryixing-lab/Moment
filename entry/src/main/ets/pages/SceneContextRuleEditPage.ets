import { common } from '@kit.AbilityKit';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppLogger } from '../common/AppLogger';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { FormField } from '../components/FormField';
import { HDS_PRIMARY_BUTTON, HDS_SECONDARY_BUTTON } from '../components/HdsImmersiveButton';
import { HdsImmersiveNavigation } from '../components/HdsImmersiveNavigation';
import {
  ResolvedSceneLocation,
  ResolvedSceneWifi,
  SceneContextRule,
  SceneContextTriggerType
} from '../model/SceneContextModels';
import { OperationResult } from '../model/ServiceModels';
import { SceneType, SceneTypes } from '../model/SceneType';
import { FormRefreshCoordinator } from '../service/FormRefreshCoordinator';
import { SceneContextLocationService } from '../service/SceneContextLocationService';
import { SceneContextPermissionService } from '../service/SceneContextPermissionService';
import { SceneContextRuleService } from '../service/SceneContextRuleService';
import { SceneContextRuntime } from '../service/SceneContextRuntime';
import { SceneContextWifiService } from '../service/SceneContextWifiService';
import { ScenePresentationService } from '../service/ScenePresentationService';

@Entry
@Component
struct SceneContextRuleEditPage {
  @State private ruleId: number = 0;
  @State private name: string = '';
  @State private sceneType: SceneType = SceneType.LIBRARY;
  @State private triggerType: SceneContextTriggerType = SceneContextTriggerType.WIFI;
  @State private wifiSsid: string = '';
  @State private addressName: string = '';
  @State private radiusMeters: string = '300';
  @State private latitude: number = 0;
  @State private longitude: number = 0;
  @State private autoSwitchEnabled: boolean = false;
  @State private isWorking: boolean = false;
  @State private errorMessage: Resource | undefined = undefined;
  private resolvedAddressInput: string = '';
  private contentScroller: Scroller = new Scroller();
  private scenes: SceneType[] = SceneTypes.all();

  aboutToAppear(): void {
    const rawParams: Object | undefined = this.getUIContext().getRouter().getParams();
    if (rawParams === undefined || rawParams === null) {
      return;
    }
    const params: Record<string, Object> = rawParams as Record<string, Object>;
    const idValue: Object | undefined = params['id'];
    if (typeof idValue === 'number' && Number.isInteger(idValue) && idValue > 0) {
      this.loadRule(idValue);
    }
  }

  private context(): common.UIAbilityContext | undefined {
    return this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
  }

  private loadRule(id: number): void {
    const context: common.Context | undefined = this.context();
    const rule: SceneContextRule | undefined =
      context === undefined ? undefined : new SceneContextRuleService(context).getRule(id);
    if (rule === undefined) {
      return;
    }
    this.ruleId = rule.id;
    this.name = rule.name;
    this.sceneType = rule.sceneType;
    this.triggerType = rule.triggerType;
    this.wifiSsid = rule.wifiSsid;
    this.addressName = rule.addressName;
    this.resolvedAddressInput = rule.addressName;
    this.radiusMeters = rule.radiusMeters.toString();
    this.latitude = rule.latitude;
    this.longitude = rule.longitude;
    this.autoSwitchEnabled = rule.autoSwitchEnabled;
  }

  private changeAddress(value: string): void {
    this.addressName = value;
    if (value.trim() !== this.resolvedAddressInput) {
      this.latitude = 0;
      this.longitude = 0;
    }
  }

  private async useCurrentWifi(): Promise<void> {
    if (this.isWorking) {
      return;
    }
    this.isWorking = true;
    this.errorMessage = undefined;
    try {
      const result: ResolvedSceneWifi = await SceneContextWifiService.currentWifi();
      if (!result.success) {
        this.errorMessage = this.wifiErrorFor(result.errorCode);
        return;
      }
      this.wifiSsid = result.ssid;
    } catch (error) {
      AppLogger.error('Unable to use current Wi-Fi in context rule', error as Object);
      this.errorMessage = $r('app.string.context_wifi_unavailable');
    } finally {
      this.isWorking = false;
    }
  }

  private async resolveAddress(): Promise<boolean> {
    if (this.addressName.trim().length === 0) {
      this.errorMessage = $r('app.string.context_validation_address');
      return false;
    }
    const result: ResolvedSceneLocation =
      await SceneContextLocationService.resolveAddress(this.addressName);
    if (!result.success) {
      this.errorMessage = result.errorCode === 'geocode_timeout' ?
        $r('app.string.context_address_timeout') : $r('app.string.context_address_not_found');
      return false;
    }
    this.applyResolvedLocation(result);
    return true;
  }

  private async resolveAddressAction(): Promise<void> {
    if (this.isWorking) {
      return;
    }
    this.isWorking = true;
    this.errorMessage = undefined;
    try {
      await this.resolveAddress();
    } catch (error) {
      AppLogger.error('Unable to resolve the entered scene address', error as Object);
      this.errorMessage = $r('app.string.context_address_not_found');
    } finally {
      this.isWorking = false;
    }
  }

  private async useCurrentLocation(): Promise<void> {
    const context: common.UIAbilityContext | undefined = this.context();
    if (context === undefined || this.isWorking) {
      return;
    }
    this.isWorking = true;
    this.errorMessage = undefined;
    try {
      if (!await SceneContextPermissionService.requestPreciseLocation(context)) {
        this.errorMessage = $r('app.string.context_location_permission_denied');
        return;
      }
      if (!await SceneContextPermissionService.ensureLocationSwitch(context)) {
        this.errorMessage = $r('app.string.context_location_disabled');
        return;
      }
      const result: ResolvedSceneLocation = await SceneContextLocationService.currentLocation();
      if (!result.success) {
        this.errorMessage = this.locationErrorFor(result.errorCode);
        return;
      }
      this.applyResolvedLocation(result);
    } catch (error) {
      AppLogger.error('Unable to use the current scene location', error as Object);
      this.errorMessage = $r('app.string.context_location_unavailable');
    } finally {
      this.isWorking = false;
    }
  }

  private applyResolvedLocation(result: ResolvedSceneLocation): void {
    this.addressName = result.addressName;
    this.resolvedAddressInput = result.addressName;
    this.latitude = result.latitude;
    this.longitude = result.longitude;
  }

  private async save(): Promise<void> {
    const context: common.UIAbilityContext | undefined = this.context();
    if (context === undefined || this.isWorking) {
      return;
    }
    this.isWorking = true;
    this.errorMessage = undefined;
    try {
      if (this.triggerType === SceneContextTriggerType.LOCATION) {
        if (!await SceneContextPermissionService.requestPreciseLocation(context)) {
          this.errorMessage = $r('app.string.context_location_permission_denied');
          return;
        }
        if (!await SceneContextPermissionService.ensureLocationSwitch(context)) {
          this.errorMessage = $r('app.string.context_location_disabled');
          return;
        }
        if (!SceneContextRuleService.validCoordinates(this.latitude, this.longitude) ||
          this.addressName.trim() !== this.resolvedAddressInput) {
          if (!await this.resolveAddress()) {
            return;
          }
        }
      }

      const service: SceneContextRuleService = new SceneContextRuleService(context);
      const rule: SceneContextRule = this.ruleId > 0 ?
        service.getRule(this.ruleId) ?? new SceneContextRule() : new SceneContextRule();
      rule.id = this.ruleId;
      rule.name = this.name.trim();
      rule.sceneType = this.sceneType;
      rule.triggerType = this.triggerType;
      rule.wifiSsid = this.wifiSsid.trim();
      rule.addressName = this.addressName.trim();
      rule.latitude = this.latitude;
      rule.longitude = this.longitude;
      const parsedRadius: number = Number.parseInt(this.radiusMeters);
      rule.radiusMeters = Number.isNaN(parsedRadius) ? -1 : parsedRadius;
      rule.autoSwitchEnabled = this.autoSwitchEnabled;
      const result: OperationResult = service.saveRule(rule);
      if (!result.success) {
        this.errorMessage = this.errorFor(result.errorCode);
        return;
      }
      SceneContextRuntime.notifyRulesChanged();
      FormRefreshCoordinator.schedule(context, 'scene_context_rule_saved');
      this.getUIContext().getRouter().back();
    } catch (error) {
      AppLogger.error('Unable to save the scene context rule', error as Object);
      this.errorMessage = $r('app.string.save_failed');
    } finally {
      this.isWorking = false;
    }
  }

  private wifiErrorFor(code: string): Resource {
    if (code === 'permission') return $r('app.string.context_wifi_permission_missing');
    if (code === 'wifi_disabled') return $r('app.string.context_wifi_disabled');
    if (code === 'timeout') return $r('app.string.context_wifi_timeout');
    if (code === 'not_connected') return $r('app.string.context_wifi_not_connected');
    return $r('app.string.context_wifi_unavailable');
  }

  private locationErrorFor(code: string): Resource {
    if (code === 'location_disabled') return $r('app.string.context_location_disabled');
    if (code === 'location_timeout') return $r('app.string.context_location_timeout');
    return $r('app.string.context_location_unavailable');
  }

  private errorFor(code: string): Resource {
    if (code === 'name') return $r('app.string.context_validation_name');
    if (code === 'wifi') return $r('app.string.context_validation_wifi');
    if (code === 'address') return $r('app.string.context_validation_address');
    if (code === 'coordinates') return $r('app.string.context_address_not_found');
    if (code === 'radius') return $r('app.string.context_validation_radius');
    return $r('app.string.save_failed');
  }

  build() {
    Stack() {
      HdsImmersiveNavigation({
        title: this.ruleId > 0 ?
          $r('app.string.edit_context_rule') : $r('app.string.add_context_rule'),
        backLabel: $r('app.string.cancel'),
        showMenu: true,
        menuLabel: this.isWorking ? $r('app.string.context_working') : $r('app.string.save'),
        menuIcon: $r('sys.symbol.checkmark'),
        scrollController: this.contentScroller,
        onBack: () => this.getUIContext().getRouter().back(),
        onMenu: () => {
          this.save();
        }
      }) {
        Scroll(this.contentScroller) {
          Column({ space: 20 }) {
            if (this.errorMessage !== undefined) {
              Text(this.errorMessage)
                .width('100%')
                .padding(12)
                .fontSize(AppTypography.CAPTION)
                .fontColor(AppColors.WARNING_TEXT)
                .borderRadius(AppDimensions.RADIUS_SECONDARY)
                .systemMaterial(ImmersiveMaterials.WARNING_SURFACE)
            }

            FormField({
              label: $r('app.string.context_rule_name'),
              value: this.name,
              placeholder: $r('app.string.context_rule_name_placeholder'),
              onValueChange: (value: string) => this.name = value
            })

            Column({ space: 8 }) {
              Text($r('app.string.context_target_scene'))
                .width('100%')
                .fontSize(AppTypography.CAPTION)
                .fontColor(AppColors.TEXT_SECONDARY)
              Row({ space: 8 }) {
                ForEach(this.scenes, (scene: SceneType) => {
                  Button(ScenePresentationService.getPresentation(scene).name)
                    .layoutWeight(1)
                    .height(AppDimensions.MIN_TOUCH_TARGET)
                    .fontSize(AppTypography.CAPTION)
                    .labelStyle({
                      maxLines: 1,
                      minFontSize: AppTypography.COMPACT_MIN,
                      maxFontSize: AppTypography.CAPTION,
                      overflow: TextOverflow.Clip
                    })
                    .fontColor(this.sceneType === scene ? AppColors.TEXT_PRIMARY : AppColors.TEXT_SECONDARY)
                    .borderRadius(AppDimensions.RADIUS_SECONDARY)
                    .padding({
                      left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
                      right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING
                    })
                    .attributeModifier(this.sceneType === scene ? HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
                    .onClick(() => this.sceneType = scene)
                }, (scene: SceneType) => scene)
              }
              .width('100%')
            }
            .width('100%')

            Column({ space: 8 }) {
              Text($r('app.string.context_trigger_type'))
                .width('100%')
                .fontSize(AppTypography.CAPTION)
                .fontColor(AppColors.TEXT_SECONDARY)
              Row({ space: 8 }) {
                Button($r('app.string.context_trigger_wifi'))
                  .layoutWeight(1)
                  .height(AppDimensions.MIN_TOUCH_TARGET)
                  .fontSize(AppTypography.BODY_MEDIUM)
                  .fontColor(this.triggerType === SceneContextTriggerType.WIFI ?
                    AppColors.TEXT_PRIMARY : AppColors.TEXT_SECONDARY)
                  .attributeModifier(this.triggerType === SceneContextTriggerType.WIFI ?
                    HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
                  .onClick(() => this.triggerType = SceneContextTriggerType.WIFI)
                Button($r('app.string.context_trigger_location'))
                  .layoutWeight(1)
                  .height(AppDimensions.MIN_TOUCH_TARGET)
                  .fontSize(AppTypography.BODY_MEDIUM)
                  .fontColor(this.triggerType === SceneContextTriggerType.LOCATION ?
                    AppColors.TEXT_PRIMARY : AppColors.TEXT_SECONDARY)
                  .attributeModifier(this.triggerType === SceneContextTriggerType.LOCATION ?
                    HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
                  .onClick(() => this.triggerType = SceneContextTriggerType.LOCATION)
              }
              .width('100%')
            }
            .width('100%')

            if (this.triggerType === SceneContextTriggerType.WIFI) {
              FormField({
                label: $r('app.string.context_wifi_ssid'),
                value: this.wifiSsid,
                placeholder: $r('app.string.context_wifi_ssid_placeholder'),
                onValueChange: (value: string) => this.wifiSsid = value
              })
              Button($r('app.string.context_use_current_wifi'))
                .width('100%')
                .height(AppDimensions.BUTTON_HEIGHT)
                .fontSize(AppTypography.BODY_MEDIUM)
                .fontColor(AppColors.ACCENT)
                .borderRadius(AppDimensions.RADIUS_PILL)
                .attributeModifier(HDS_SECONDARY_BUTTON)
                .enabled(!this.isWorking)
                .onClick(() => {
                  this.useCurrentWifi();
                })
            } else {
              FormField({
                label: $r('app.string.context_address'),
                value: this.addressName,
                placeholder: $r('app.string.context_address_placeholder'),
                onValueChange: (value: string) => this.changeAddress(value)
              })
              FormField({
                label: $r('app.string.context_radius'),
                value: this.radiusMeters,
                placeholder: $r('app.string.context_radius_placeholder'),
                inputType: InputType.Number,
                onValueChange: (value: string) => this.radiusMeters = value
              })
              Row({ space: 10 }) {
                Button($r('app.string.context_resolve_address'))
                  .layoutWeight(1)
                  .height(AppDimensions.BUTTON_HEIGHT)
                  .fontSize(AppTypography.CAPTION)
                  .fontColor(AppColors.ACCENT)
                  .borderRadius(AppDimensions.RADIUS_PILL)
                  .attributeModifier(HDS_SECONDARY_BUTTON)
                  .enabled(!this.isWorking)
                  .onClick(() => {
                    this.resolveAddressAction();
                  })
                Button($r('app.string.context_use_current_location'))
                  .layoutWeight(1)
                  .height(AppDimensions.BUTTON_HEIGHT)
                  .fontSize(AppTypography.CAPTION)
                  .fontColor(AppColors.ACCENT)
                  .borderRadius(AppDimensions.RADIUS_PILL)
                  .attributeModifier(HDS_SECONDARY_BUTTON)
                  .enabled(!this.isWorking)
                  .onClick(() => {
                    this.useCurrentLocation();
                  })
              }
              .width('100%')
              if (SceneContextRuleService.validCoordinates(this.latitude, this.longitude)) {
                Text(`${this.latitude.toFixed(5)}, ${this.longitude.toFixed(5)}`)
                  .width('100%')
                  .fontSize(AppTypography.CAPTION)
                  .fontColor(AppColors.TEXT_TERTIARY)
              }
            }

            Row() {
              Column({ space: 4 }) {
                Text($r('app.string.context_auto_switch'))
                  .fontSize(AppTypography.BODY_LARGE)
                  .fontColor(AppColors.TEXT_PRIMARY)
                Text($r('app.string.context_auto_switch_desc'))
                  .fontSize(AppTypography.CAPTION)
                  .fontColor(AppColors.TEXT_SECONDARY)
                  .maxLines(3)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.autoSwitchEnabled })
                .selectedColor(AppColors.ACCENT)
                .onChange((value: boolean) => this.autoSwitchEnabled = value)
            }
            .width('100%')
            .padding(16)
            .borderRadius(AppDimensions.RADIUS_PRIMARY)
            .systemMaterial(ImmersiveMaterials.CARD)
          }
          .width('100%')
          .constraintSize({ maxWidth: AppDimensions.MAX_CONTENT_WIDTH })
          .padding({
            left: AppDimensions.PAGE_HORIZONTAL_PADDING,
            right: AppDimensions.PAGE_HORIZONTAL_PADDING,
            top: AppDimensions.PAGE_TOP_PADDING,
            bottom: AppDimensions.PAGE_BOTTOM_PADDING
          })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .backgroundColor(AppColors.PAGE_BACKGROUND)
      }
    }
    .width('100%')
    .height('100%')
  }
}

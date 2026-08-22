import {
  hdsMaterial,
  HdsNavigation,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { common } from '@kit.AbilityKit';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';

/**
 * HDS page title bar with the system-managed immersive-light material.
 *
 * hdsMaterial is exposed by the current SDK only through supported HDS
 * components such as HdsNavigation and HdsTabs. The title bar actions below
 * are native HDS buttons; no custom material or light effect is drawn here.
 */
@Component
export struct HdsImmersiveNavigation {
  @Prop title: ResourceStr = '';
  @Prop showSubTitle: boolean = false;
  @Prop subTitle: ResourceStr = '';
  @Prop backLabel: ResourceStr = '';
  @Prop showMenu: boolean = false;
  @Prop menuLabel: ResourceStr = '';
  @Prop menuIcon: Resource = $r('sys.symbol.plus');
  @Prop menuEnabled: boolean = true;
  scrollController: Scroller = new Scroller();
  onBack: () => void = () => {};
  onMenu: () => void = () => {};

  @Builder
  private emptyContent() {
    Blank()
  }

  @BuilderParam content: () => void = this.emptyContent;

  private menuItems(): Array<HdsNavigationMenuItemOptions> | undefined {
    if (!this.showMenu) {
      return undefined;
    }
    return [{
      content: {
        label: this.menuLabel,
        icon: this.menuIcon,
        isEnabled: this.menuEnabled,
        action: () => this.onMenu()
      }
    }];
  }

  private colorToHex(color: number): string {
    return `#${(color >>> 0).toString(16).padStart(8, '0')}`;
  }

  private resolveSystemBarStyle(): SystemBarStyle {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      return {};
    }
    try {
      return {
        statusBarContentColor: this.colorToHex(
          context.resourceManager.getColorByNameSync('text_primary')
        )
      };
    } catch (_) {
      return {};
    }
  }

  build() {
    Stack() {
      Row() {}
        .width('100%')
        .height('100%')
        .background(AppColors.PAGE_BACKGROUND)
        .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT],
          [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      HdsNavigation() {
        Row() {
          Stack() {
            this.content()
          }
          .width('100%')
          .height('100%')
          .constraintSize({ maxWidth: AppDimensions.MAX_CONTENT_WIDTH })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
      .mode(NavigationMode.Stack)
      .titleBar({
        content: {
          title: {
            mainTitle: this.title,
            subTitle: this.showSubTitle ? this.subTitle : undefined
          },
          menu: {
            value: this.menuItems()
          },
          backIcon: {
            label: this.backLabel,
            icon: $r('sys.symbol.chevron_backward'),
            isEnabled: true,
            action: () => this.onBack()
          }
        },
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.COMMON_BLUR
          },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        },
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: true
      })
      .hideBackButton(false)
      .titleMode(HdsNavigationTitleMode.MINI)
      .bindToScrollable([this.scrollController])
      .systemBarStyle(this.resolveSystemBarStyle(), this.resolveSystemBarStyle())
      .width('100%')
      .height('100%')
      .background(AppColors.PAGE_BACKGROUND)
    }
    .width('100%')
    .height('100%')
    .background(AppColors.PAGE_BACKGROUND)
  }
}

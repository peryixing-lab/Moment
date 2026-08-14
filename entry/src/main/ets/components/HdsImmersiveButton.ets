import { uiMaterial } from '@kit.ArkUI';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';

/**
 * Semantic button roles backed by the API 26 immersive system material.
 * Interactive deformation and light feedback are provided by
 * uiMaterial.ImmersiveMaterial rather than a hand-authored lookalike effect.
 */
export enum HdsImmersiveButtonType {
  PRIMARY = 'primary',
  SECONDARY = 'secondary',
  ICON_ONLY = 'iconOnly',
  DANGER = 'danger'
}

export class HdsImmersiveButtonModifier implements AttributeModifier<ButtonAttribute> {
  private readonly buttonType: HdsImmersiveButtonType;

  constructor(buttonType: HdsImmersiveButtonType) {
    this.buttonType = buttonType;
  }

  applyNormalAttribute(instance: ButtonAttribute): void {
    this.applyMaterial(instance, this.getMaterial());
  }

  applyPressedAttribute(instance: ButtonAttribute): void {
    this.applyMaterial(instance, this.getMaterial());
  }

  applyFocusedAttribute(instance: ButtonAttribute): void {
    this.applyMaterial(instance, this.getMaterial());
  }

  applyDisabledAttribute(instance: ButtonAttribute): void {
    instance
      .stateEffect(false)
      // Huawei's API 26 Button example explicitly clears the native theme
      // background before systemMaterial takes ownership of the surface.
      .backgroundColor(Color.Transparent)
      .systemMaterial(ImmersiveMaterials.SUBTLE_SURFACE);
  }

  private getMaterial(): uiMaterial.Material {
    if (this.buttonType === HdsImmersiveButtonType.PRIMARY) {
      return ImmersiveMaterials.PRIMARY_ACTION;
    }
    if (this.buttonType === HdsImmersiveButtonType.DANGER) {
      return ImmersiveMaterials.DANGER_ACTION;
    }
    return ImmersiveMaterials.SECONDARY_ACTION;
  }

  private applyMaterial(instance: ButtonAttribute, material: uiMaterial.Material): void {
    instance
      .stateEffect(false)
      // Without this baseline, Button may paint its native accent background
      // on the first frame or in recycled list nodes, obscuring accent text.
      .backgroundColor(Color.Transparent)
      .systemMaterial(material);
  }
}

export const HDS_PRIMARY_BUTTON: HdsImmersiveButtonModifier =
  new HdsImmersiveButtonModifier(HdsImmersiveButtonType.PRIMARY);

export const HDS_SECONDARY_BUTTON: HdsImmersiveButtonModifier =
  new HdsImmersiveButtonModifier(HdsImmersiveButtonType.SECONDARY);

export const HDS_ICON_ONLY_BUTTON: HdsImmersiveButtonModifier =
  new HdsImmersiveButtonModifier(HdsImmersiveButtonType.ICON_ONLY);

export const HDS_DANGER_BUTTON: HdsImmersiveButtonModifier =
  new HdsImmersiveButtonModifier(HdsImmersiveButtonType.DANGER);

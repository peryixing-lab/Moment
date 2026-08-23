import { uiMaterial } from '@kit.ArkUI';
import { AppColors } from './AppColors';

/**
 * API 26 immersive system-material policy for the whole application.
 *
 * Thickness follows Huawei's spatial UI guidance:
 * - content and floating controls use ultra-thin/thin materials;
 * - temporary overlays use thick materials;
 * - half-modal surfaces use ultra-thick materials.
 *
 * Background, border and shadow must not be set on the same component because
 * systemMaterial owns those visual properties.
 */
export class ImmersiveMaterials {
  static readonly CARD: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
    applyShadow: true
  });

  static readonly SUBTLE_SURFACE: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
    applyShadow: false
  });

  static readonly INPUT: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN,
    applyShadow: false
  });

  static readonly SECONDARY_ACTION: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
    applyShadow: true,
    interactive: true,
    lightEffect: { color: undefined }
  });

  static readonly PRIMARY_ACTION: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN,
    materialColor: AppColors.ACCENT_SOFT,
    applyShadow: true,
    interactive: true,
    lightEffect: { color: undefined }
  });

  static readonly ACCENT_CHIP: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
    materialColor: AppColors.ACCENT_SOFT,
    applyShadow: false
  });

  static readonly WARNING_SURFACE: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN,
    materialColor: AppColors.WARNING_MATERIAL_TINT,
    applyShadow: false
  });

  static readonly DANGER_ACTION: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN,
    materialColor: AppColors.DANGER_MATERIAL_TINT,
    applyShadow: true,
    interactive: true,
    lightEffect: { color: undefined }
  });

  static readonly BRAND_RED_ACTION: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN,
    materialColor: AppColors.BRAND_RED_TINT,
    applyShadow: true,
    interactive: true,
    lightEffect: { color: undefined }
  });

  static readonly TEMPORARY_OVERLAY: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THICK,
    applyShadow: true
  });

  static readonly HALF_MODAL: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
    applyShadow: true
  });
}

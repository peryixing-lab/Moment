import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';

@Component
export struct FormField {
  label: Resource = $r('app.string.task_title');
  value: string = '';
  placeholder: Resource = $r('app.string.task_title');
  inputType: InputType = InputType.Normal;
  onValueChange: (value: string) => void = () => {};

  build() {
    Column({ space: 7 }) {
      Text(this.label)
        .width('100%')
        .fontSize(AppTypography.CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_SECONDARY)
      TextInput({ text: this.value, placeholder: this.placeholder })
        .width('100%')
        .height(AppDimensions.BUTTON_HEIGHT)
        .type(this.inputType)
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(AppColors.TEXT_PRIMARY)
        .placeholderColor(AppColors.TEXT_TERTIARY)
        .caretColor(AppColors.ACCENT)
        .borderRadius(AppDimensions.RADIUS_SECONDARY)
        .systemMaterial(ImmersiveMaterials.INPUT)
        .onChange((value: string) => this.onValueChange(value))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

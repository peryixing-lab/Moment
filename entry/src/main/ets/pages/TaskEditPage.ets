import { common } from '@kit.AbilityKit';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { TimeUtils } from '../common/TimeUtils';
import { FormField } from '../components/FormField';
import { HDS_PRIMARY_BUTTON, HDS_SECONDARY_BUTTON } from '../components/HdsImmersiveButton';
import { HdsImmersiveNavigation } from '../components/HdsImmersiveNavigation';
import { OperationResult } from '../model/ServiceModels';
import { SceneType } from '../model/SceneType';
import { LocalTask, TaskPriority } from '../model/TaskModels';
import { FormRefreshCoordinator } from '../service/FormRefreshCoordinator';
import { ScenePresentationService } from '../service/ScenePresentationService';
import { TaskService } from '../service/TaskService';

@Entry
@Component
struct TaskEditPage {
  @State private taskId: number = 0;
  @State private title: string = '';
  @State private description: string = '';
  @State private dueText: string = '';
  @State private priority: TaskPriority = TaskPriority.MEDIUM;
  @State private sceneType: SceneType | undefined = undefined;
  @State private errorMessage: Resource | undefined = undefined;
  private contentScroller: Scroller = new Scroller();
  private priorities: TaskPriority[] = [TaskPriority.LOW, TaskPriority.MEDIUM, TaskPriority.HIGH,
    TaskPriority.URGENT];
  private scenes: SceneType[] = [SceneType.LIBRARY, SceneType.CLASS, SceneType.MEETING, SceneType.COMMUTE];

  aboutToAppear(): void {
    const rawParams: Object | undefined = this.getUIContext().getRouter().getParams();
    if (rawParams === undefined || rawParams === null) {
      return;
    }
    const params: Record<string, Object> = rawParams as Record<string, Object>;
    const idValue: Object | undefined = params['id'];
    if (typeof idValue === 'number' && Number.isInteger(idValue) && idValue > 0) {
      this.loadTask(idValue);
    }
  }

  private context(): common.Context | undefined {
    return this.getUIContext().getHostContext();
  }

  private loadTask(id: number): void {
    const context: common.Context | undefined = this.context();
    const task: LocalTask | undefined = context === undefined ? undefined : new TaskService(context).getTask(id);
    if (task === undefined) {
      return;
    }
    this.taskId = task.id;
    this.title = task.title;
    this.description = task.description;
    this.dueText = task.dueAt > 0 ? TimeUtils.formatDateTime(task.dueAt) : '';
    this.priority = task.priority;
    this.sceneType = task.sceneType;
  }

  private save(): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined) {
      this.errorMessage = $r('app.string.save_failed');
      return;
    }
    const dueAt: number = TimeUtils.parseDateTime(this.dueText);
    if (dueAt < 0) {
      this.errorMessage = $r('app.string.task_validation_due');
      return;
    }
    const service: TaskService = new TaskService(context);
    const task: LocalTask = this.taskId > 0 ? service.getTask(this.taskId) ?? new LocalTask() : new LocalTask();
    task.id = this.taskId;
    task.title = this.title.trim();
    task.description = this.description.trim();
    task.dueAt = dueAt;
    task.priority = this.priority;
    task.sceneType = this.sceneType;
    const result: OperationResult = service.saveTask(task);
    if (!result.success) {
      this.errorMessage = result.errorCode === 'title' ? $r('app.string.task_validation_title') :
        $r('app.string.save_failed');
      return;
    }
    FormRefreshCoordinator.schedule(context, 'task_saved');
    this.getUIContext().getRouter().back();
  }

  private priorityLabel(priority: TaskPriority): Resource {
    switch (priority) {
      case TaskPriority.LOW: return $r('app.string.priority_low');
      case TaskPriority.MEDIUM: return $r('app.string.priority_medium');
      case TaskPriority.HIGH: return $r('app.string.priority_high');
      case TaskPriority.URGENT: return $r('app.string.priority_urgent');
      default: return $r('app.string.priority_medium');
    }
  }

  build() {
    Stack() {
      HdsImmersiveNavigation({
        title: this.taskId > 0 ? $r('app.string.edit_task') : $r('app.string.add_task'),
        backLabel: $r('app.string.cancel'),
        showMenu: true,
        menuLabel: $r('app.string.save'),
        menuIcon: $r('sys.symbol.checkmark'),
        scrollController: this.contentScroller,
        onBack: () => this.getUIContext().getRouter().back(),
        onMenu: () => this.save()
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

        FormField({ label: $r('app.string.task_title'), value: this.title,
          placeholder: $r('app.string.task_title'), onValueChange: (value: string) => this.title = value })
        FormField({ label: $r('app.string.task_description'), value: this.description,
          placeholder: $r('app.string.task_description'),
          onValueChange: (value: string) => this.description = value })
        FormField({ label: $r('app.string.task_deadline'), value: this.dueText,
          placeholder: $r('app.string.task_deadline_hint'), onValueChange: (value: string) => this.dueText = value })

        Column({ space: 8 }) {
          Text($r('app.string.task_priority'))
            .width('100%').fontSize(AppTypography.CAPTION).fontColor(AppColors.TEXT_SECONDARY)
          Row({ space: 8 }) {
            ForEach(this.priorities, (value: TaskPriority) => {
              Button(this.priorityLabel(value))
                .layoutWeight(1)
                .height(AppDimensions.MIN_TOUCH_TARGET)
                .fontSize(AppTypography.CAPTION)
                .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
                  maxFontSize: AppTypography.CAPTION, overflow: TextOverflow.Clip })
                .fontColor(value === this.priority ? AppColors.TEXT_PRIMARY : AppColors.TEXT_SECONDARY)
                .borderRadius(AppDimensions.RADIUS_SECONDARY)
                .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
                  right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
                .attributeModifier(value === this.priority ? HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
                .onClick(() => this.priority = value)
            }, (value: TaskPriority) => value.toString())
          }
          .width('100%')
        }
        .width('100%')

        Column({ space: 8 }) {
          Text($r('app.string.task_scene'))
            .width('100%').fontSize(AppTypography.CAPTION).fontColor(AppColors.TEXT_SECONDARY)
          Row() {
            Button($r('app.string.all_scenes'))
              .width('20%')
              .height(AppDimensions.MIN_TOUCH_TARGET)
              .fontSize(AppTypography.CAPTION)
              .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
                maxFontSize: AppTypography.CAPTION, overflow: TextOverflow.Clip })
              .fontColor(this.sceneType === undefined ? AppColors.ACCENT : AppColors.TEXT_SECONDARY)
              .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
                right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
              .attributeModifier(this.sceneType === undefined ? HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
              .onClick(() => this.sceneType = undefined)
            ForEach(this.scenes, (scene: SceneType) => {
              Button(ScenePresentationService.getPresentation(scene).name)
                .width('20%')
                .height(AppDimensions.MIN_TOUCH_TARGET)
                .fontSize(AppTypography.CAPTION)
                .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
                  maxFontSize: AppTypography.CAPTION, overflow: TextOverflow.Clip })
                .fontColor(this.sceneType === scene ? AppColors.ACCENT : AppColors.TEXT_SECONDARY)
                .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
                  right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
                .attributeModifier(this.sceneType === scene ? HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
                .onClick(() => this.sceneType = scene)
            }, (scene: SceneType) => scene)
          }
          .width('100%')
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ maxWidth: AppDimensions.MAX_CONTENT_WIDTH })
          .padding({ left: AppDimensions.PAGE_HORIZONTAL_PADDING, right: AppDimensions.PAGE_HORIZONTAL_PADDING,
            top: AppDimensions.PAGE_TOP_PADDING, bottom: AppDimensions.PAGE_BOTTOM_PADDING })
        }
        .width('100%')
        .align(Alignment.Top)
        .height('100%')
        .backgroundColor(AppColors.PAGE_BACKGROUND)
      }
    }
    .width('100%')
    .height('100%')
  }
}

import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppColors } from '../common/AppColors';
import { AppDimensions } from '../common/AppDimensions';
import { AppTypography } from '../common/AppTypography';
import { ImmersiveMaterials } from '../common/ImmersiveMaterials';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import {
  HDS_DANGER_BUTTON,
  HDS_PRIMARY_BUTTON,
  HDS_SECONDARY_BUTTON
} from '../components/HdsImmersiveButton';
import { HdsImmersiveNavigation } from '../components/HdsImmersiveNavigation';
import { TimeUtils } from '../common/TimeUtils';
import { SceneType } from '../model/SceneType';
import { LocalTask, TaskPriority } from '../model/TaskModels';
import { DataHealthService } from '../service/DataHealthService';
import { FormRefreshCoordinator } from '../service/FormRefreshCoordinator';
import { ScenePresentationService } from '../service/ScenePresentationService';
import { TaskService } from '../service/TaskService';

@Entry
@Component
struct TaskListPage {
  @State private tasks: LocalTask[] = new Array<LocalTask>();
  @State private showCompleted: boolean = false;
  @State private filterScene: SceneType | undefined = undefined;
  @State private hasError: boolean = false;
  private contentScroller: Scroller = new Scroller();
  private scenes: SceneType[] = [SceneType.LIBRARY, SceneType.CLASS, SceneType.MEETING, SceneType.COMMUTE];

  aboutToAppear(): void {
    this.loadTasks();
  }

  onPageShow(): void {
    this.loadTasks();
  }

  private context(): common.Context | undefined {
    return this.getUIContext().getHostContext();
  }

  private loadTasks(): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined) {
      this.hasError = true;
      return;
    }
    this.tasks = new TaskService(context).listTasks(this.showCompleted, this.filterScene);
    this.hasError = DataHealthService.hasError();
  }

  private retryData(): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined) {
      this.hasError = true;
      return;
    }
    DataHealthService.retry(context);
    this.loadTasks();
  }

  private setFilter(scene: SceneType | undefined): void {
    this.filterScene = scene;
    this.loadTasks();
  }

  private openEditor(id: number = 0): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/TaskEditPage', params: { id: id } }).catch(() => {
      this.showToast($r('app.string.operation_failed'));
    });
  }

  private toggleCompleted(task: LocalTask): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined) {
      return;
    }
    const service: TaskService = new TaskService(context);
    const success: boolean = task.isCompleted ? service.restoreTask(task.id) : service.completeTask(task.id);
    if (!success) {
      this.showToast($r('app.string.operation_failed'));
      return;
    }
    this.loadTasks();
    FormRefreshCoordinator.schedule(context, 'task_completion_changed');
  }

  private confirmDelete(task: LocalTask): void {
    this.getUIContext().getPromptAction().showDialog({
      title: $r('app.string.delete_task_title'),
      message: $r('app.string.delete_task_message'),
      buttons: [
        { text: $r('app.string.cancel'), color: AppColors.TEXT_SECONDARY },
        { text: $r('app.string.delete'), color: AppColors.DANGER }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.deleteTask(task.id);
      }
    }).catch(() => {
      this.showToast($r('app.string.operation_failed'));
    });
  }

  private deleteTask(id: number): void {
    const context: common.Context | undefined = this.context();
    if (context === undefined || !new TaskService(context).deleteTask(id)) {
      this.showToast($r('app.string.operation_failed'));
      return;
    }
    this.loadTasks();
    FormRefreshCoordinator.schedule(context, 'task_deleted');
  }

  private priorityLabel(priority: TaskPriority): Resource {
    switch (priority) {
      case TaskPriority.URGENT: return $r('app.string.priority_urgent');
      case TaskPriority.HIGH: return $r('app.string.priority_high');
      case TaskPriority.MEDIUM: return $r('app.string.priority_medium');
      case TaskPriority.LOW: return $r('app.string.priority_low');
      default: return $r('app.string.priority_medium');
    }
  }

  private showToast(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  build() {
    Stack() {
      HdsImmersiveNavigation({
        title: $r('app.string.task_list_title'),
        backLabel: $r('app.string.back'),
        showMenu: true,
        menuLabel: $r('app.string.add_task'),
        menuIcon: $r('sys.symbol.plus'),
        scrollController: this.contentScroller,
        onBack: () => this.getUIContext().getRouter().back(),
        onMenu: () => this.openEditor()
      }) {
        Column({ space: 18 }) {
          Row() {
        Button($r('app.string.all_scenes'))
          .width('20%')
          .height(AppDimensions.MIN_TOUCH_TARGET)
          .fontSize(AppTypography.CAPTION)
          .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
            maxFontSize: AppTypography.CAPTION, overflow: TextOverflow.Clip })
          .fontColor(this.filterScene === undefined ? AppColors.ACCENT : AppColors.TEXT_SECONDARY)
          .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
            right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
          .attributeModifier(this.filterScene === undefined ? HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
          .onClick(() => this.setFilter(undefined))
        ForEach(this.scenes, (scene: SceneType) => {
          Button(ScenePresentationService.getPresentation(scene).name)
            .width('20%')
            .height(AppDimensions.MIN_TOUCH_TARGET)
            .fontSize(AppTypography.CAPTION)
            .labelStyle({ maxLines: 1, minFontSize: AppTypography.COMPACT_MIN,
              maxFontSize: AppTypography.CAPTION, overflow: TextOverflow.Clip })
            .fontColor(this.filterScene === scene ? AppColors.ACCENT : AppColors.TEXT_SECONDARY)
            .padding({ left: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING,
              right: AppDimensions.COMPACT_BUTTON_HORIZONTAL_PADDING })
            .attributeModifier(this.filterScene === scene ? HDS_PRIMARY_BUTTON : HDS_SECONDARY_BUTTON)
            .onClick(() => this.setFilter(scene))
        }, (scene: SceneType) => scene)
      }
      .width('100%')
      .padding(4)
      .borderRadius(AppDimensions.RADIUS_PILL)
      .systemMaterial(ImmersiveMaterials.SUBTLE_SURFACE)

      Button(this.showCompleted ? $r('app.string.hide_completed') : $r('app.string.show_completed'))
        .height(AppDimensions.MIN_TOUCH_TARGET)
        .fontSize(AppTypography.CAPTION)
        .fontColor(AppColors.ACCENT)
        .attributeModifier(HDS_SECONDARY_BUTTON)
        .onClick(() => {
          this.showCompleted = !this.showCompleted;
          this.loadTasks();
        })

      if (this.hasError) {
        ErrorState({ onRetry: () => this.retryData() })
      }

      if (this.tasks.length === 0 && !this.hasError) {
        EmptyState({
          title: $r('app.string.task_empty_title'),
          description: $r('app.string.task_empty_description')
        })
        Button($r('app.string.add_task'))
          .width('100%')
          .height(AppDimensions.BUTTON_HEIGHT)
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(AppColors.ACCENT)
          .borderRadius(AppDimensions.RADIUS_SECONDARY)
          .attributeModifier(HDS_PRIMARY_BUTTON)
          .onClick(() => this.openEditor())
      } else {
        List({ space: 12, scroller: this.contentScroller }) {
          ForEach(this.tasks, (task: LocalTask) => {
            ListItem() {
              Column({ space: 12 }) {
                Column({ space: 5 }) {
                  Row({ space: 8 }) {
                    Text(this.priorityLabel(task.priority))
                      .fontSize(AppTypography.CAPTION)
                      .fontColor(task.priority === TaskPriority.URGENT ? AppColors.DANGER : AppColors.ACCENT)
                    if (task.isCompleted) {
                      Text($r('app.string.focus_completed'))
                        .fontSize(AppTypography.CAPTION)
                        .fontColor(AppColors.TEXT_TERTIARY)
                    }
                  }
                  .width('100%')
                  Text(task.title)
                    .width('100%')
                    .fontSize(AppTypography.BODY_LARGE)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(task.isCompleted ? AppColors.TEXT_TERTIARY : AppColors.TEXT_PRIMARY)
                    .maxLines(2)
                  if (task.dueAt > 0) {
                    Row({ space: 4 }) {
                      Text($r('app.string.task_due'))
                        .fontSize(AppTypography.CAPTION)
                        .fontColor(task.dueAt < Date.now() && !task.isCompleted ? AppColors.DANGER :
                          AppColors.TEXT_SECONDARY)
                      Text(TimeUtils.formatDateTime(task.dueAt))
                        .fontSize(AppTypography.CAPTION)
                        .fontColor(task.dueAt < Date.now() && !task.isCompleted ? AppColors.DANGER :
                          AppColors.TEXT_SECONDARY)
                    }
                    .width('100%')
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                Row({ space: 8 }) {
                  Button(task.isCompleted ? $r('app.string.restore') : $r('app.string.complete'))
                    .layoutWeight(1)
                    .height(AppDimensions.MIN_TOUCH_TARGET)
                    .fontSize(AppTypography.CAPTION)
                    .fontColor(AppColors.ACCENT)
                    .borderRadius(AppDimensions.RADIUS_PILL)
                    .attributeModifier(HDS_SECONDARY_BUTTON)
                    .onClick(() => this.toggleCompleted(task))
                  Button($r('app.string.edit'))
                    .layoutWeight(1)
                    .height(AppDimensions.MIN_TOUCH_TARGET)
                    .fontSize(AppTypography.CAPTION)
                    .fontColor(AppColors.ACCENT)
                    .borderRadius(AppDimensions.RADIUS_PILL)
                    .attributeModifier(HDS_SECONDARY_BUTTON)
                    .onClick(() => this.openEditor(task.id))
                  Button($r('app.string.delete'))
                    .layoutWeight(1)
                    .height(AppDimensions.MIN_TOUCH_TARGET)
                    .fontSize(AppTypography.CAPTION)
                    .fontColor(AppColors.DANGER)
                    .borderRadius(AppDimensions.RADIUS_PILL)
                    .attributeModifier(HDS_DANGER_BUTTON)
                    .onClick(() => this.confirmDelete(task))
                }
                .width('100%')
              }
              .width('100%')
              .padding(AppDimensions.CARD_PADDING)
              .borderRadius(AppDimensions.RADIUS_PRIMARY)
              .systemMaterial(ImmersiveMaterials.CARD)
            }
          }, (task: LocalTask) => task.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: AppDimensions.PAGE_HORIZONTAL_PADDING, right: AppDimensions.PAGE_HORIZONTAL_PADDING,
          top: AppDimensions.PAGE_TOP_PADDING, bottom: AppDimensions.PAGE_BOTTOM_PADDING })
        .backgroundColor(AppColors.PAGE_BACKGROUND)
      }
    }
    .width('100%')
    .height('100%')
  }
}

import { SceneType, SceneTypes } from '../model/SceneType';
import { SceneOptionCard } from './SceneOptionCard';

@Component
export struct SceneSelector {
  @Prop currentScene: SceneType = SceneType.LIBRARY;
  @Prop interactionEnabled: boolean = true;
  onSceneSelected: (sceneType: SceneType) => void = () => {};
  private scenes: SceneType[] = SceneTypes.all();

  build() {
    Row() {
      ForEach(this.scenes, (sceneType: SceneType) => {
        SceneOptionCard({
          sceneType: sceneType,
          selected: sceneType === this.currentScene,
          onSelect: (selected: SceneType) => {
            if (this.interactionEnabled) {
              this.onSceneSelected(selected);
            }
          }
        })
      }, (sceneType: SceneType) => sceneType)
    }
    .width('100%')
  }
}

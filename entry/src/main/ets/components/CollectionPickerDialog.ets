/**
 * 收藏夹选择器对话框组件
 *
 * 展示用户收藏夹列表，每项带复选框，用户可勾选/取消勾选收藏夹。
 * 确认后触发收藏/取消收藏操作。
 *
 * 使用方式：
 * - 在父页面中维护 @Local showDialog: boolean = false
 * - 在 build() 的条件渲染中引用此组件
 * - 通过 options 回调与父页面通信
 */

import { Collection } from '../model/Collection';
import { CollectionsViewModel } from '../viewmodel/CollectionsViewModel';

/** 收藏夹选择器对话框参数 */
interface CollectionPickerDialogOptions {
  /** 是否显示 */
  show: boolean;
  /** 关闭回调 */
  onClose: () => void;
  /** 确认回调（勾选的收藏夹 ID 列表） */
  onConfirm: (selectedIds: string[]) => void;
}

@ComponentV2
export struct CollectionPickerDialog {
  /** 对话框参数 */
  @Param options: CollectionPickerDialogOptions = { show: false, onClose: () => {}, onConfirm: (ids: string[]) => {} };
  /** 收藏夹 ViewModel */
  @Local collectionsVM: CollectionsViewModel = CollectionsViewModel.getInstance();
  /** 临时选中的收藏夹 ID 集合 */
  @Local tempSelectedIds: string[] = [];

  /**
   * 当对话框打开时，初始化临时选中状态。
   */
  @Monitor('options')
  onOptionsChange(): void {
    if (this.options.show) {
      this.tempSelectedIds = [...this.collectionsVM.contentCollectionIds];
    }
  }

  build() {
    Column() {
      if (this.options.show) {
        // 半透明背景
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.4)')
          .onClick(() => {
            this.options.onClose();
          });

        // 底部弹出面板
        Column() {
          // 标题栏
          Row() {
            Text('收藏到')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.app_on_surface'));
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 16, bottom: 12 });

          // 分割线
          Divider()
            .height(1)
            .color($r('app.color.app_divider'))
            .width('100%');

          // 收藏夹列表
          if (this.collectionsVM.collections.length > 0) {
            Scroll() {
              Column() {
                ForEach(this.collectionsVM.collections, (collection: Collection) => {
                  this.CollectionItem(collection);
                }, (collection: Collection) => collection.id);
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 });
            }
            .layoutWeight(1)
            .width('100%');
          } else {
            // 空状态
            Column() {
              Text('暂无收藏夹')
                .fontSize(14)
                .fontColor($r('app.color.app_on_surface_secondary'))
                .margin({ top: 32, bottom: 8 });
              Text('请先在知乎网页版创建收藏夹')
                .fontSize(12)
                .fontColor($r('app.color.app_on_surface_disabled'))
                .margin({ bottom: 32 });
            }
            .width('100%')
            .layoutWeight(1);
          }

          // 分割线
          Divider()
            .height(1)
            .color($r('app.color.app_divider'))
            .width('100%');

          // 底部按钮
          Row() {
            // 取消按钮
            Text('取消')
              .fontSize(16)
              .fontColor($r('app.color.app_on_surface_secondary'))
              .padding({ top: 12, bottom: 12 })
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.options.onClose();
              });

            // 分割线
            Divider()
              .width(1)
              .height(24)
              .color($r('app.color.app_divider'));

            // 确定按钮
            Text('确定')
              .fontSize(16)
              .fontColor($r('app.color.app_primary'))
              .fontWeight(FontWeight.Medium)
              .padding({ top: 12, bottom: 12 })
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.options.onConfirm(this.tempSelectedIds);
              });
          }
          .width('100%')
          .height(48)
          .padding({ bottom: 12 });
        }
        .width('100%')
        .backgroundColor($r('app.color.app_surface'))
        .borderRadius({ topLeft: 16, topRight: 16 });
      }
    }
    .width('100%')
    .height('100%');
  }

  /**
   * 单个收藏夹项（带复选框）。
   */
  @Builder
  CollectionItem(collection: Collection) {
    Row() {
      // 复选框
      Row()
        .width(20)
        .height(20)
        .borderRadius(4)
        .border({
          width: 2,
          color: this.isTempSelected(collection.id)
            ? $r('app.color.app_primary')
            : $r('app.color.app_divider')
        })
        .backgroundColor(this.isTempSelected(collection.id)
          ? $r('app.color.app_primary')
          : Color.Transparent)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.toggleTempSelection(collection.id);
        });

      // 收藏夹信息
      Column() {
        Text(collection.title)
          .fontSize(15)
          .fontColor($r('app.color.app_on_surface'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Row() {
          Text(collection.isPublic ? '公开' : '私密')
            .fontSize(12)
            .fontColor($r('app.color.app_on_surface_disabled'));
          Text(collection.itemCount + '条内容')
            .fontSize(12)
            .fontColor($r('app.color.app_on_surface_disabled'))
            .margin({ left: 8 });
        }
        .margin({ top: 2 });
      }
      .margin({ left: 12 })
      .layoutWeight(1);
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .onClick(() => {
      this.toggleTempSelection(collection.id);
    });
  }

  /**
   * 检查指定收藏夹 ID 是否在临时选中列表中。
   */
  private isTempSelected(collectionId: string): boolean {
    for (let i = 0; i < this.tempSelectedIds.length; i++) {
      if (this.tempSelectedIds[i] === collectionId) {
        return true;
      }
    }
    return false;
  }

  /**
   * 切换临时选中状态。
   */
  private toggleTempSelection(collectionId: string): void {
    const newIds: string[] = [...this.tempSelectedIds];
    for (let i = 0; i < newIds.length; i++) {
      if (newIds[i] === collectionId) {
        // 移除
        const removed: string[] = [];
        for (let j = 0; j < newIds.length; j++) {
          if (j !== i) {
            removed.push(newIds[j]);
          }
        }
        this.tempSelectedIds = removed;
        return;
      }
    }
    // 添加
    newIds.push(collectionId);
    this.tempSelectedIds = newIds;
  }
}
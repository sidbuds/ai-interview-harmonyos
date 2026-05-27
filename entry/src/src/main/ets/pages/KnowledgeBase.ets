import { promptAction } from '@kit.ArkUI';
import { KbService, KbDoc } from '../services/ApiServices';

@Component
struct KnowledgeBasePage {
  @State kbList: KbDoc[] = [];
  @State isLoading: boolean = false;
  @State searchKeyword: string = '';
  private stack: NavPathStack | undefined = undefined;

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      const listRes = await KbService.list();
      this.kbList = listRes.data;
    } catch (e) {
      promptAction.showToast({ message: '加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  async handleDelete(id: string, name: string): Promise<void> {
    promptAction.showDialog({
      title: '确认删除',
      message: `确定要删除知识库 "${name}" 吗？`,
      buttons: [
        { text: '取消', color: '#999' },
        { text: '删除', color: '#FF4D4F' }
      ]
    }).then(async (result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        try {
          await KbService.delete(Number(id));
          promptAction.showToast({ message: '删除成功' });
          await this.loadData();
        } catch (e) {
          promptAction.showToast({ message: '删除失败' });
        }
      }
    });
  }

  getStatusColor(status: string): string {
    if (status === 'COMPLETED') return '#52C41A';
    if (status === 'PROCESSING') return '#1890FF';
    if (status === 'PENDING') return '#FAAD14';
    if (status === 'FAILED') return '#FF4D4F';
    return '#999';
  }

  getStatusText(status: string): string {
    if (status === 'COMPLETED') return '已完成';
    if (status === 'PROCESSING') return '处理中';
    if (status === 'PENDING') return '待处理';
    if (status === 'FAILED') return '失败';
    return status;
  }

  build() {
    NavDestination() {
      Column() {
        // Row() {
        //
        // }
        // .width('100%')
        // .height(56)
        // .padding({ left: 16, right: 16 })
        // .backgroundColor('#FFFFFF')

        Row({ space: 8 }) {
          TextInput({ placeholder: '搜索知识库...', text: this.searchKeyword })
            .layoutWeight(1)
            .height(36)
            .fontSize(14)
            .backgroundColor('#F5F5F5')
            .borderRadius(18)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.searchKeyword = value;
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor('#FFFFFF')

        Divider().color('#F0F0F0')

        if (this.isLoading) {
          Column() {
            LoadingProgress().width(40).height(40)
            Text('加载中...').fontSize(14).fontColor('#999').margin({ top: 8 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.kbList.length === 0) {
          Column() {
            Text('暂无知识库').fontSize(14).fontColor('#999')
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Column() {
            Scroll() {
              Column({ space: 8 }) {
                ForEach(this.kbList, (item: KbDoc) => {
                  Column({ space: 8 }) {
                    Row() {
                      Text(item.name)
                        .fontSize(16)
                        .fontWeight(FontWeight.Medium)
                        .layoutWeight(1)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(this.getStatusText(item.vectorStatus))
                        .fontSize(12)
                        .fontColor(this.getStatusColor(item.vectorStatus))
                        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                        .backgroundColor(this.getStatusColor(item.vectorStatus) + '15')
                        .borderRadius(4)
                    }
                    .width('100%')

                    if (item.category) {
                      Text(`分类: ${item.category}`)
                        .fontSize(12)
                        .fontColor('#666')
                    }

                    Row({ space: 8 }) {
                      Button('删除')
                        .fontSize(12)
                        .height(28)
                        .backgroundColor('#F0F0F0')
                        .fontColor('#333')
                        .onClick(() => this.handleDelete(item.id, item.name))
                    }
                    .width('100%')
                  }
                  .width('100%')
                  .padding(16)
                  .backgroundColor('#FFFFFF')
                  .borderRadius(8)
                }, (item: KbDoc) => item.id)
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .scrollBar(BarState.Auto)
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
    }
    .title('知识库管理')
    .onReady((ctx: NavDestinationContext) => {
      this.stack = ctx.pathStack;
    })
  }
}

@Builder
function KnowledgeBaseBuilder() {
  KnowledgeBasePage()
}

import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { ResumeService, Resume } from '../services/ApiServices';

@Entry
@ComponentV2
struct ResumeList {
  @Local resumeList: Resume[] = [];
  @Local isLoading: boolean = false;
  @Local showMore: boolean = false;

  aboutToAppear(): void {
    this.loadResumes();
  }

  async loadResumes(): Promise<void> {
    this.isLoading = true;
    try {
      const res = await ResumeService.getList();
      this.resumeList = res.data;
    } catch (e) {
      promptAction.showToast({ message: '简历加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  getDisplayList(): Resume[] {
    return this.showMore ? this.resumeList : this.resumeList.slice(0, 10);
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor('#333')
          .onClick(() => router.back())
        Text('简历库')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
        Blank()
        Text('刷新')
          .fontSize(14)
          .fontColor('#1890FF')
          .onClick(() => this.loadResumes())
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF')

      Divider().color('#F0F0F0')

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
          Text('加载中...')
            .fontSize(14)
            .fontColor('#999')
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.resumeList.length === 0) {
        Column() {
          Text('暂无简历')
            .fontSize(16)
            .fontColor('#999')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Scroll() {
            Column() {
              ForEach(this.getDisplayList(), (item: Resume) => {
              Row() {
                Column({ space: 4 }) {
                  Text(decodeURIComponent(item.filename))
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#333')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Row({ space: 8 }) {
                    Text(item.latestScore > 0 ? `评分: ${item.latestScore}` : '待分析')
                      .fontSize(12)
                      .fontColor('#999')
                    Text(item.uploadedAt.substring(0, 10))
                      .fontSize(12)
                      .fontColor('#999')
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text('>')
                  .fontSize(16)
                  .fontColor('#999')
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/ResumeDetail',
                  params: { id: Number(item.id) }
                });
              })
            }, (item: Resume) => item.id.toString())

            if (this.resumeList.length > 10 && !this.showMore) {
              Text('查看更多')
                .fontSize(14)
                .fontColor('#1890FF')
                .width('100%')
                .height(44)
                .textAlign(TextAlign.Center)
                .onClick(() => {
                  this.showMore = true;
                })
            }
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }
      .layoutWeight(1)
      .width('100%')
    }}
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}

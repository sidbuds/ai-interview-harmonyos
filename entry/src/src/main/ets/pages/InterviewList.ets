import { promptAction } from '@kit.ArkUI';
import { ResumeService, InterviewItem } from '../services/ApiServices';

@Component
struct InterviewListPage {
  @State interviewList: InterviewItem[] = [];
  @State isLoading: boolean = false;
  private stack: NavPathStack | undefined = undefined;

  aboutToAppear(): void {
    this.loadInterviews();
  }

  async loadInterviews(): Promise<void> {
    this.isLoading = true;
    try {
      const resumeRes = await ResumeService.getList();
      const resumes = resumeRes.data;
      const allInterviews: InterviewItem[] = [];
      for (let i = 0; i < resumes.length; i++) {
        const resume = resumes[i];
        try {
          const detailRes = await ResumeService.getDetail(resume.id);
          const detail = detailRes.data;
          if (detail.interviews && detail.interviews.length > 0) {
            for (let j = 0; j < detail.interviews.length; j++) {
              const interview = detail.interviews[j] as InterviewItem;
              interview.resumeFilename = decodeURIComponent(resume.filename);
              allInterviews.push(interview);
            }
          }
        } catch (e) {
          // 忽略
        }
      }
      allInterviews.sort((a: InterviewItem, b: InterviewItem) => {
        return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
      });
      this.interviewList = allInterviews;
    } catch (e) {
      promptAction.showToast({ message: '加载面试记录失败' });
    } finally {
      this.isLoading = false;
    }
  }

  formatDate(dateStr: string): string {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    return `${month}-${day} ${hours}:${minutes}`;
  }

  getStatusText(status: string): string {
    if (status === 'EVALUATED') return '已完成';
    if (status === 'COMPLETED') return '待评估';
    if (status === 'IN_PROGRESS') return '进行中';
    if (status === 'CREATED') return '已创建';
    return status;
  }

  getStatusColor(status: string): string {
    if (status === 'EVALUATED') return '#52C41A';
    if (status === 'COMPLETED') return '#FAAD14';
    if (status === 'IN_PROGRESS') return '#1890FF';
    return '#999';
  }

  build() {
    NavDestination() {
      Column() {
        Row() {

          Blank()
          Text('刷新')
            .fontSize(14)
            .fontColor('#1890FF')
            .onClick(() => this.loadInterviews())
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .backgroundColor('#FFFFFF')

        Divider().color('#F0F0F0')

        if (this.isLoading) {
          Column() {
            LoadingProgress().width(40).height(40)
            Text('加载中...').fontSize(14).fontColor('#999').margin({ top: 8 })
          }
          .width('100%')
          .height(120)
          .justifyContent(FlexAlign.Center)
        } else if (this.interviewList.length === 0) {
          Column() {
            Text('暂无面试记录').fontSize(16).fontColor('#999')
            Text('上传简历后可开始模拟面试').fontSize(14).fontColor('#999').margin({ top: 8 })
          }
          .width('100%')
          .height(120)
          .justifyContent(FlexAlign.Center)
        } else {
          Column() {
            Scroll() {
              Column({ space: 8 }) {
                ForEach(this.interviewList, (item: InterviewItem) => {
                  Row() {
                    Column({ space: 6 }) {
                      Row() {
                        Text(`面试 #${item.id}`)
                          .fontSize(16)
                          .fontWeight(FontWeight.Medium)
                          .fontColor('#333')
                        Blank()
                        Text(this.getStatusText(item.status))
                          .fontSize(12)
                          .fontColor(this.getStatusColor(item.status))
                          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                          .backgroundColor(this.getStatusColor(item.status) + '15')
                          .borderRadius(4)
                      }
                      .width('100%')

                      if (item.resumeFilename) {
                        Text(`简历: ${item.resumeFilename}`)
                          .fontSize(12)
                          .fontColor('#666')
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                      }

                      Row({ space: 12 }) {
                        Text(`${item.totalQuestions}题`).fontSize(12).fontColor('#999')
                        Text(this.formatDate(item.createdAt)).fontSize(12).fontColor('#999')
                        if (item.overallScore > 0) {
                          Text(`评分: ${item.overallScore}`).fontSize(12).fontColor('#1890FF')
                        }
                      }
                      .width('100%')
                    }
                    .layoutWeight(1)

                    Text('>').fontSize(16).fontColor('#999')
                  }
                  .width('100%')
                  .padding(16)
                  .backgroundColor('#FFFFFF')
                  .borderRadius(8)
                  .onClick(() => {
                    if (item.status === 'EVALUATED' || item.status === 'COMPLETED') {
                      this.stack?.pushPath(new NavPathInfo('InterviewReport', item.sessionId));
                    } else if (item.status === 'IN_PROGRESS') {
                      promptAction.showToast({ message: '报告生成中，请稍后查看' });
                    }
                  })
                }, (item: InterviewItem) => item.id.toString())
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
    .title('面试记录')
    .onReady((ctx: NavDestinationContext) => {
      this.stack = ctx.pathStack;
    })
  }
}

@Builder
function InterviewListBuilder() {
  InterviewListPage()
}

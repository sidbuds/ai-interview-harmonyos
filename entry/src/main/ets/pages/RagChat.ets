import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { RagChatService, KbService, KbDoc } from '../services/ApiServices';

interface ChatMessage {
  id: number;
  role: string;
  content: string;
  time: string;
}

@Entry
@ComponentV2
struct RagChatPage {
  @Local sessionId: number = 0;
  @Local messageList: ChatMessage[] = [];
  @Local chatInput: string = '';
  @Local isLoading: boolean = false;
  @Local isSending: boolean = false;
  @Local kbList: KbDoc[] = [];
  @Local selectedKbIds: number[] = [];
  @Local refreshCounter: number = 0;
  @Local showKbSelector: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, number>;
    if (params && params['sessionId']) {
      this.sessionId = params['sessionId'];
      this.loadSessionDetail();
    } else {
      this.loadKbList();
    }
  }

  async loadKbList(): Promise<void> {
    try {
      const res = await KbService.list();
      this.kbList = res.data.filter((item: KbDoc) => item.vectorStatus === 'COMPLETED');
    } catch (e) {
      console.error('加载知识库失败');
    }
  }

  async loadSessionDetail(): Promise<void> {
    this.isLoading = true;
    try {
      const res = await RagChatService.getDetail(this.sessionId);
      const messages: ChatMessage[] = [];
      for (let i = 0; i < res.data.messages.length; i++) {
        const msg = res.data.messages[i];
        messages.push({
          id: msg.id,
          role: msg.type,
          content: msg.content,
          time: this.formatTime(msg.createdAt)
        });
      }
      this.messageList = messages;
    } catch (e) {
      promptAction.showToast({ message: '加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  async handleCreateSession(): Promise<void> {
    if (this.selectedKbIds.length === 0) {
      promptAction.showToast({ message: '请选择至少一个知识库' });
      return;
    }

    try {
      const res = await RagChatService.create(this.selectedKbIds);
      this.sessionId = res.data.id;
      this.showKbSelector = false;
      await this.loadSessionDetail();
    } catch (e) {
      promptAction.showToast({ message: '创建会话失败' });
    }
  }

  async handleSendMessage(): Promise<void> {
    if (!this.chatInput.trim() || this.isSending) {
      return;
    }

    if (this.sessionId === 0) {
      this.showKbSelector = true;
      return;
    }

    const question = this.chatInput;
    this.chatInput = '';

    const userMsg: ChatMessage = {
      id: Date.now(),
      role: 'user',
      content: question,
      time: this.formatTime(new Date().toISOString())
    };
    this.messageList = [...this.messageList, userMsg];

    const aiMsg: ChatMessage = {
      id: Date.now() + 1,
      role: 'assistant',
      content: '',
      time: this.formatTime(new Date().toISOString())
    };
    this.messageList = [...this.messageList, aiMsg];

    this.isSending = true;

    try {
      // Send message to trigger AI response (don't await - SSE stream blocks)
      RagChatService.sendMessage(this.sessionId, question).catch(() => {});
      
      // Poll for AI response (up to 90 seconds)
      const userMsgContent = question;
      let responseReceived = false;
      for (let i = 0; i < 45; i++) {
        await new Promise<void>((resolve) => {
          setTimeout(() => {
            resolve();
          }, 2000);
        });

        try {
          const detailRes = await RagChatService.getDetail(this.sessionId);
          const messages = detailRes.data.messages;
          
          // Find user message index first
          let userMsgIndex = -1;
          for (let j = messages.length - 1; j >= 0; j--) {
            if (messages[j].type === 'user' && messages[j].content === userMsgContent) {
              userMsgIndex = j;
              break;
            }
          }
          
          // Look for assistant message after the user message
          if (userMsgIndex >= 0) {
            for (let j = userMsgIndex + 1; j < messages.length; j++) {
              if (messages[j].type === 'assistant' && messages[j].content && messages[j].content.trim().length > 0) {
                this.updateAiMessage(aiMsg.id, messages[j].content);
                responseReceived = true;
                break;
              }
            }
          }
          
          if (responseReceived) {
            break;
          }
        } catch (e) {
          console.error('轮询获取回复失败');
        }
      }

      if (!responseReceived) {
        this.updateAiMessage(aiMsg.id, '回答生成超时，请重试。');
      }
    } catch (e) {
      this.updateAiMessage(aiMsg.id, '抱歉，回答生成失败，请重试。');
    } finally {
      this.isSending = false;
    }
  }

  updateAiMessage(msgId: number, content: string): void {
    const newList: ChatMessage[] = [];
    for (let i = 0; i < this.messageList.length; i++) {
      const msg = this.messageList[i];
      if (msg.id === msgId) {
        newList.push({
          id: msg.id,
          role: msg.role,
          content: content,
          time: msg.time
        });
      } else {
        newList.push({
          id: msg.id,
          role: msg.role,
          content: msg.content,
          time: msg.time
        });
      }
    }
    this.messageList = newList;
    this.refreshCounter++;
  }

  toggleKbSelection(kbId: number): void {
    const newList: number[] = [];
    let found = false;
    for (let i = 0; i < this.selectedKbIds.length; i++) {
      if (this.selectedKbIds[i] === kbId) {
        found = true;
      } else {
        newList.push(this.selectedKbIds[i]);
      }
    }
    if (!found) {
      newList.push(kbId);
    }
    this.selectedKbIds = newList;
  }

  isKbSelected(kbId: number): boolean {
    for (let i = 0; i < this.selectedKbIds.length; i++) {
      if (this.selectedKbIds[i] === kbId) {
        return true;
      }
    }
    return false;
  }

  formatTime(dateStr: string): string {
    if (!dateStr) {
      return '';
    }
    const date = new Date(dateStr);
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    return `${hours}:${minutes}`;
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor('#333')
          .onClick(() => router.back())
        Text(this.sessionId > 0 ? 'RAG 对话' : '新建对话')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF')

      Divider().color('#F0F0F0')

      if (this.showKbSelector) {
        Column({ space: 12 }) {
          Text('选择知识库')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)

          if (this.kbList.length === 0) {
            Text('暂无可用知识库，请先上传并完成向量化')
              .fontSize(14)
              .fontColor('#999')
          } else {
            ForEach(this.kbList, (item: KbDoc) => {
              Row({ space: 8 }) {
                Checkbox()
                  .select(this.isKbSelected(Number(item.id)))
                  .onChange((value: boolean) => {
                    this.toggleKbSelection(Number(item.id));
                  })
                Text(item.name)
                  .fontSize(14)
                  .layoutWeight(1)
              }
              .width('100%')
            }, (item: KbDoc) => item.id.toString())
          }

          Row({ space: 12 }) {
            Button('取消')
              .layoutWeight(1)
              .height(40)
              .backgroundColor('#F0F0F0')
              .fontColor('#333')
              .onClick(() => {
                this.showKbSelector = false;
              })
            Button('创建会话')
              .layoutWeight(1)
              .height(40)
              .backgroundColor('#1890FF')
              .onClick(() => this.handleCreateSession())
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .margin(16)
      }

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
      } else if (this.messageList.length === 0 && !this.showKbSelector) {
        Column({ space: 16 }) {
          Text('RAG 智能问答')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
          Text('基于知识库的智能问答，提供精准答案')
            .fontSize(14)
            .fontColor('#999')
          Button('选择知识库开始')
            .width(200)
            .height(44)
            .backgroundColor('#1890FF')
            .onClick(() => {
              this.showKbSelector = true;
            })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.messageList, (message: ChatMessage) => {
              Row() {
                if (message.role === 'user') {
                  Blank()
                  Column({ space: 4 }) {
                    Text(message.content)
                      .fontSize(14)
                      .fontColor('#FFFFFF')
                      .padding(12)
                      .backgroundColor('#1890FF')
                      .borderRadius(12)
                    Text(message.time)
                      .fontSize(10)
                      .fontColor('#999')
                      .textAlign(TextAlign.End)
                  }
                  .width('70%')
                } else {
                  Column({ space: 4 }) {
                    Text(message.content || (this.isSending ? '思考中...' : ''))
                      .fontSize(14)
                      .fontColor('#333')
                      .padding(12)
                      .backgroundColor('#F5F5F5')
                      .borderRadius(12)
                    Text(message.time)
                      .fontSize(10)
                      .fontColor('#999')
                  }
                  .width('70%')
                  Blank()
                }
              }
              .width('100%')
            }, (message: ChatMessage) => message.id.toString() + '_' + this.refreshCounter.toString())
          }
          .width('100%')
          .padding(16)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }

      Column() {
        Divider().color('#F0F0F0')
        Row({ space: 8 }) {
          TextInput({ placeholder: '输入你的问题...', text: this.chatInput })
            .layoutWeight(1)
            .height(40)
            .fontSize(14)
            .backgroundColor('#F5F5F5')
            .borderRadius(20)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.chatInput = value;
            })
            .onSubmit(() => this.handleSendMessage())

          Button('发送')
            .height(40)
            .backgroundColor('#1890FF')
            .borderRadius(20)
            .enabled(!this.isSending && this.chatInput.trim().length > 0)
            .onClick(() => this.handleSendMessage())
        }
        .width('100%')
        .padding(12)
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}

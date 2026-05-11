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
struct ChatPage {
  @Local sessionId: number = 0;
  @Local messageList: ChatMessage[] = [];
  @Local chatInput: string = '';
  @Local isLoading: boolean = false;
  @Local isSending: boolean = false;
  @Local kbList: KbDoc[] = [];
  @Local selectedKbIds: number[] = [];
  @Local showKbSelector: boolean = false;
  @Local initialQuestion: string = '';
  @Local refreshCounter: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params && params['question']) {
      this.initialQuestion = params['question'];
    }
    if (params && params['kbIds']) {
      try {
        this.selectedKbIds = JSON.parse(params['kbIds']) as number[];
      } catch (e) {
        console.error('解析知识库ID失败');
      }
    }
    this.loadKbList();
  }

  async loadKbList(): Promise<void> {
    try {
      const res = await KbService.list();
      this.kbList = res.data.filter((item: KbDoc) => item.vectorStatus === 'COMPLETED');
      // If kbIds are passed from Index page, create session and send immediately
      if (this.selectedKbIds.length > 0 && this.initialQuestion.length > 0) {
        this.handleCreateSessionAndSend();
      }
    } catch (e) {
      console.error('加载知识库失败');
    }
  }

  async handleCreateSessionAndSend(): Promise<void> {
    if (this.selectedKbIds.length === 0) {
      promptAction.showToast({ message: '请选择至少一个知识库' });
      return;
    }

    this.showKbSelector = false;
    this.isSending = true;

    try {
      const createRes = await RagChatService.create(this.selectedKbIds, this.initialQuestion.substring(0, 20));
      this.sessionId = createRes.data.id;

      const userMsg: ChatMessage = {
        id: Date.now(),
        role: 'user',
        content: this.initialQuestion,
        time: this.formatTime(new Date().toISOString())
      };
      this.messageList = [...this.messageList, userMsg];
      this.initialQuestion = '';

      const aiMsg: ChatMessage = {
        id: Date.now() + 1,
        role: 'assistant',
        content: '',
        time: this.formatTime(new Date().toISOString())
      };
      this.messageList = [...this.messageList, aiMsg];

      // Send message to trigger AI response (don't await - SSE stream blocks)
      console.info('[Chat] Sending message: ' + userMsg.content);
      RagChatService.sendMessage(this.sessionId, userMsg.content)
        .then(() => console.info('[Chat] sendMessage completed'))
        .catch((e: Error) => console.error('[Chat] sendMessage failed: ' + e.message));
      
      // Poll for AI response (up to 90 seconds)
      // Track user message content to find the correct assistant reply
      const userMsgContent = userMsg.content;
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
      promptAction.showToast({ message: '发送失败' });
    } finally {
      this.isSending = false;
    }
  }

  async handleSendMessage(): Promise<void> {
    if (!this.chatInput.trim() || this.isSending) {
      return;
    }

    if (this.sessionId === 0) {
      this.initialQuestion = this.chatInput;
      this.chatInput = '';
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
    console.info('[Chat] updateAiMessage called, msgId=' + msgId + ', content length=' + content.length);
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
    console.info('[Chat] UI updated, messageList length=' + this.messageList.length);
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
        Text('AI 智能问答')
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
            Text('暂无可用知识库')
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
            Button('开始对话')
              .layoutWeight(1)
              .height(40)
              .backgroundColor('#1890FF')
              .onClick(() => this.handleCreateSessionAndSend())
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .margin(16)
      }

      if (this.messageList.length === 0 && !this.showKbSelector) {
        Column({ space: 16 }) {
          Text('AI 智能问答')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
          Text('输入你的问题，AI 将为你解答')
            .fontSize(14)
            .fontColor('#999')
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
            .enabled(!this.isSending && (this.chatInput.trim().length > 0 || this.initialQuestion.length > 0))
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

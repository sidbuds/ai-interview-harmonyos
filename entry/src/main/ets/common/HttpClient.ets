import http from '@ohos.net.http';
import { promptAction } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';

export interface Result<T> {
  code: number;
  message: string;
  data: T;
}

interface HttpHeader {
  'Content-Type': string;
  'Accept': string;
  Authorization?: string;
}

export class HttpClient {
  private baseUrl: string = 'http://10.0.2.2:8080';
  private httpInstance = http.createHttp();
  private token: string = '';

  setToken(token: string): void {
    this.token = token;
  }

  setBaseUrl(url: string): void {
    this.baseUrl = url;
  }

  async request<T>(
    method: http.RequestMethod,
    path: string,
    body?: Object,
    queryString?: string,
    timeout?: number
  ): Promise<Result<T>> {
    let url = `${this.baseUrl}${path}`;
    if (queryString) {
      url += `?${queryString}`;
    }

    const headers: HttpHeader = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
    if (this.token) {
      headers.Authorization = `Bearer ${this.token}`;
    }

    const readTimeout = timeout || 30000;

    try {
      const options: http.HttpRequestOptions = {
        method: method,
        header: headers,
        extraData: body ? JSON.stringify(body) : undefined,
        connectTimeout: 10000,
        readTimeout: readTimeout
      };
      console.info('[HTTP] ' + method + ' ' + url);
      const res = await this.httpInstance.request(url, options);
      console.info('[HTTP] Response: ' + res.responseCode);

      if (res.responseCode !== 200) {
        throw new Error(`HTTP错误: ${res.responseCode}`);
      }

      const resultText = res.result as string;
      console.info('[HTTP] Result length: ' + resultText.length);
      const result: Result<T> = JSON.parse(resultText) as Result<T>;
      if (result.code !== 200) {
        if (result.code === 429) {
          promptAction.showToast({ message: '请求过于频繁，请稍后再试' });
        }
        throw new Error(result.message);
      }
      return result;
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      promptAction.showToast({ message: `网络异常: ${errorMsg}` });
      throw new Error(errorMsg);
    }
  }

  async requestStream(
    path: string,
    body?: Object,
    timeout?: number
  ): Promise<void> {
    const url = `${this.baseUrl}${path}`;
    console.info('[HTTP Stream] POST ' + url);

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream'
    };
    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }

    const readTimeout = timeout || 180000;

    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body ? JSON.stringify(body) : undefined,
        connectTimeout: 10000,
        readTimeout: readTimeout
      };
      const res = await this.httpInstance.request(url, options);
      console.info('[HTTP Stream] Response code: ' + res.responseCode);

      if (res.responseCode !== 200) {
        throw new Error(`HTTP错误: ${res.responseCode}`);
      }
      console.info('[HTTP Stream] Request sent successfully');
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      console.error('[HTTP Stream] Error: ' + errorMsg);
      throw new Error(errorMsg);
    }
  }

  stringToUint8Array(str: string): Uint8Array {
    const buffer: number[] = [];
    for (let i = 0; i < str.length; i++) {
      const code = str.charCodeAt(i);
      if (code < 0x80) {
        buffer.push(code);
      } else if (code < 0x800) {
        buffer.push(0xC0 | (code >> 6));
        buffer.push(0x80 | (code & 0x3F));
      } else {
        buffer.push(0xE0 | (code >> 12));
        buffer.push(0x80 | ((code >> 6) & 0x3F));
        buffer.push(0x80 | (code & 0x3F));
      }
    }
    return new Uint8Array(buffer);
  }

  async downloadFile(path: string, savePath: string): Promise<void> {
    const url = `${this.baseUrl}${path}`;

    const headers: Record<string, string> = {
      'Accept': 'application/pdf'
    };
    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }

    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 10000,
        readTimeout: 60000,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      };
      const res = await this.httpInstance.request(url, options);

      if (res.responseCode !== 200) {
        throw new Error(`HTTP错误: ${res.responseCode}`);
      }

      // 保存文件
      const file = fileIo.openSync(savePath, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE);
      const data = res.result as ArrayBuffer;
      fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      throw new Error(errorMsg);
    }
  }

  async uploadFile<T>(
    path: string,
    fileUri: string,
    fieldName: string = 'file',
    extraFields?: Record<string, string>
  ): Promise<Result<T>> {
    const url = `${this.baseUrl}${path}`;

    try {
      const file = fileIo.openSync(fileUri, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(file.fd);
      const readBuffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, readBuffer, { offset: 0, length: stat.size });
      fileIo.closeSync(file);
      const fileData = readBuffer;

      const boundary = '----HarmonyOSBoundary' + Date.now();
      const header: Record<string, string> = {
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
        'Accept': 'application/json'
      };
      if (this.token) {
        header['Authorization'] = `Bearer ${this.token}`;
      }

      const bodyParts: number[] = [];

      if (extraFields) {
        const keys = Object.keys(extraFields);
        for (let i = 0; i < keys.length; i++) {
          const key = keys[i];
          const value = extraFields[key];
          const part = `--${boundary}\r\nContent-Disposition: form-data; name="${key}"\r\n\r\n${value}\r\n`;
          const partBytes = this.stringToUint8Array(part);
          for (let j = 0; j < partBytes.length; j++) {
            bodyParts.push(partBytes[j]);
          }
        }
      }

      const fileName = fileUri.split('/').pop() || 'file';
      const fileHeader = `--${boundary}\r\nContent-Disposition: form-data; name="${fieldName}"; filename="${fileName}"\r\nContent-Type: application/octet-stream\r\n\r\n`;
      const fileHeaderBytes = this.stringToUint8Array(fileHeader);
      for (let i = 0; i < fileHeaderBytes.length; i++) {
        bodyParts.push(fileHeaderBytes[i]);
      }
      const fileBytes = new Uint8Array(fileData);
      for (let i = 0; i < fileBytes.length; i++) {
        bodyParts.push(fileBytes[i]);
      }
      const lineBreak = this.stringToUint8Array('\r\n');
      for (let i = 0; i < lineBreak.length; i++) {
        bodyParts.push(lineBreak[i]);
      }

      const endBoundary = `--${boundary}--\r\n`;
      const endBytes = this.stringToUint8Array(endBoundary);
      for (let i = 0; i < endBytes.length; i++) {
        bodyParts.push(endBytes[i]);
      }

      const bodyBuffer = new Uint8Array(bodyParts);
      const arrayBuffer = new ArrayBuffer(bodyBuffer.byteLength);
      const uint8View = new Uint8Array(arrayBuffer);
      for (let i = 0; i < bodyBuffer.length; i++) {
        uint8View[i] = bodyBuffer[i];
      }

      const uploadOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: header,
        extraData: arrayBuffer,
        connectTimeout: 10000,
        readTimeout: 60000
      };
      const res = await this.httpInstance.request(url, uploadOptions);

      if (res.responseCode !== 200) {
        throw new Error(`HTTP错误: ${res.responseCode}`);
      }

      const result: Result<T> = JSON.parse(res.result as string) as Result<T>;
      if (result.code !== 200) {
        throw new Error(result.message);
      }
      return result;
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      promptAction.showToast({ message: `上传失败: ${errorMsg}` });
      throw new Error(errorMsg);
    }
  }
}

export const apiClient: HttpClient = new HttpClient();

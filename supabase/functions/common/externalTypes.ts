///////////////////////////////////////////////////////////
// From OpenAI
///////////////////////////////////////////////////////////

export enum ChatCompletionRequestMessageRoleEnum {
    System = 'system',
    Assistant = 'assistant',
    User = 'user',
    Function = 'function',
}

export type ChatCompletionRole = 'system' | 'assistant' | 'user' | 'function';

export interface ChatCompletionRequestMessage {
    content: string;
    role: ChatCompletionRole;
    name?: string;
}

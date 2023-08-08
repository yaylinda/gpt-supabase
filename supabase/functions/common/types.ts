import moment from 'moment';
import { GPTChatModel, GPTEmbedModel } from './enums.ts';
import {
    ChatCompletionRequestMessage, ChatCompletionRole, CustomerInfo, PurchasesStoreProduct,
} from './externalTypes.ts';

///////////////////////////////////////////////////////////
// chats
///////////////////////////////////////////////////////////

export interface Chat {
    id: string;
    name: string;
    emoji: string;
    createdAt: moment.Moment;
    createdBy: string;
    members: string[];
    updatedAt: moment.Moment;
    lastMessage: MessageWithTokenUsage;
    aiName: string;
    gptChatModel: GPTChatModel;
    gptEmbedModel: GPTEmbedModel;
    leastRecentlyFetchedMessage: ChatMessage | null;
    numMessageCreditsUsed: number;
    numMessageCreditsTotal: number;
    numTokensUsed: number;
    promptMessageContent: string;
    initialMessageCredits: number;
}

export interface CreateChatRequest extends APIRequest {
    userId: string;
    promptMessageContent: string;
    memberIds: string[];
    chatName: string;
    aiName: string;
    gptChatModel: GPTChatModel;
    gptEmbedModel: GPTEmbedModel;
    platform: 'ios' | 'android';
}

export interface CreateChatResponse {
    chat: Chat;
    chatMessage: ChatMessage;
}

///////////////////////////////////////////////////////////
// chat_messages
///////////////////////////////////////////////////////////

export interface ChatMessage {
    id: string;
    timestamp: moment.Moment;
    sender: string | null;
    content: string;
    role: ChatCompletionRole;
    responseToSender: string | null;
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
}

export interface MessageWithTokenUsage extends ChatCompletionRequestMessage {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
}

export interface SendUserMessageRequest extends APIRequest {
    chatId: string;
    sender: string | null;
    responseToSender: string | null;
    message: ChatCompletionRequestMessage;
    chatModel: GPTChatModel;
    embedModel: GPTEmbedModel;
    generateResponse: boolean;
}

export interface EmbedMessageRequest extends APIRequest {
    chatMessageId: string;
    messageContent: string;
    model: GPTEmbedModel;
}

export interface EmbededMessage {
    embedding: number[];
    promptTokens: number;
}

export interface GenerateResponseMessageRequest extends APIRequest {
    chatId: string;
    chatMessageId: string;
    responseToSender: string;
    message: ChatCompletionRequestMessage;
    embedding: number[];
}

export interface SearchMessagesRequest {
    chat_id: string;
    query_embedding: number[];
    similarity_threshold: number;
    max_rows: number;
    exclude_id: string;
}

///////////////////////////////////////////////////////////
// profile / person / user
///////////////////////////////////////////////////////////

export interface Person {
    id: string;
    username: string;
    discriminator: string;
}

export interface Profile extends Person {
    createdAt: moment.Moment;
    numChatCreditsUsed: number;
    numChatCreditsTotal: number;
    numFriends: number;
    initialMessageCredits: number;
    email: string;
}

///////////////////////////////////////////////////////////
// friends
///////////////////////////////////////////////////////////

export interface RequestFriendRequest extends APIRequest {
    userId: string;
    requesteeUsernameDiscriminator: string;
}

export interface RequestFriendResponse {
    success: boolean;
    message: string;
}

///////////////////////////////////////////////////////////
// api request
///////////////////////////////////////////////////////////

export interface APIRequest {
    correlationId: string;
}

///////////////////////////////////////////////////////////
// api response
///////////////////////////////////////////////////////////

export type APIResponse<D, E> = APISuccessResponse<D> | APIErrorResponse<E>;

export interface APISuccessResponse<T> {
    data: T;
    error: null;
}

export interface APIErrorResponse<T> {
    data: null;
    error: T;
}

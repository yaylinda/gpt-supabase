import moment from 'moment';
import {ChatMessages, Chats, Profiles} from './schema.ts';
import {Chat, ChatMessage, Profile} from './types.ts';
import {ChatCompletionRequestMessage} from "./externalTypes.ts";

/**
 *
 * @param chat
 * @returns
 */
export const chatAdapter = (chat: Chats): Chat => ({
    id: chat.id,
    name: chat.name,
    emoji: '🤖',
    createdAt: moment(chat.created_at),
    createdBy: chat.created_by,
    members: chat.members,
    updatedAt: moment(chat.updated_at),
    lastMessage: chat.last_message,
    aiName: chat.ai_name,
    gptChatModel: chat.gpt_chat_model,
    gptEmbedModel: chat.gpt_embed_model,
    leastRecentlyFetchedMessage: null,
    numMessageCreditsTotal: chat.num_message_credits_total,
    numMessageCreditsUsed: chat.num_message_credits_used,
    numTokensUsed: chat.num_tokens_used,
    promptMessageContent: chat.prompt_message_content,
    initialMessageCredits: chat.initial_message_credits,
});

/**
 *
 * @param chatMessage
 * @returns
 */
export const chatMessageAdapter = (chatMessage: ChatMessages): ChatMessage => ({
    id: chatMessage.id,
    timestamp: moment(chatMessage.timestamp),
    sender: chatMessage.sender_id || null,
    content: chatMessage.content,
    role: chatMessage.role,
    responseToSender: chatMessage.response_to_sender_id || null,
    promptTokens: chatMessage.prompt_tokens,
    completionTokens: chatMessage.completion_tokens,
    totalTokens: chatMessage.total_tokens,
});

/**
 *
 * @param chatMessage
 * @returns
 */
export const gptMessageAdapter = (
    chatMessage: ChatMessages
): ChatCompletionRequestMessage => ({
    role: chatMessage.role,
    content: chatMessage.content,
    name: chatMessage.content.split(':')[0],
});

/**
 *
 * @param profile
 */
export const profileAdapter = (profile: Profiles): Profile => ({
    id: profile.id,
    username: profile.username,
    discriminator: profile.discriminator,
    createdAt: moment(profile.created_at),
    numChatCreditsTotal: profile.num_chat_credits_total,
    numChatCreditsUsed: profile.num_chat_credits_used,
    numFriends: profile.num_friends,
    initialMessageCredits: profile.initial_message_credits,
    email: profile.email,
});

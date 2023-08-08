import {GPTChatModel, GPTEmbedModel} from './enums.ts';
import {ChatCompletionRole, CustomerInfo, PurchasesStoreProduct} from './externalTypes.ts';
import {MessageWithTokenUsage} from './types.ts';

///////////////////////////////////////////////////////////
// chats table
///////////////////////////////////////////////////////////

export interface ChatsInput {
    name: string;
    created_by: string;
    members: string[];
    ai_name: string;
    gpt_chat_model: GPTChatModel;
    gpt_embed_model: GPTEmbedModel;
    num_message_credits_total: number;
    prompt_message_content: string;
    initial_message_credits: number;
}

export interface Chats extends ChatsInput {
    id: string;
    created_at: string;
    updated_at: string;
    last_message: MessageWithTokenUsage;
    num_message_credits_used: number;
    num_tokens_used: number;
}

///////////////////////////////////////////////////////////
// chat_messages table
///////////////////////////////////////////////////////////

export interface ChatMessagesInput {
    chat_id: string;
    sender_id: string | null;
    role: ChatCompletionRole;
    content: string;
    response_to_sender_id: string | null;
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
}

export interface ChatMessages extends ChatMessagesInput {
    id: string;
    timestamp: string;
}

///////////////////////////////////////////////////////////
// profiles table
///////////////////////////////////////////////////////////

export interface Profiles {
    id: string,
    username: string,
    discriminator: string;
    created_at: string,
    num_chat_credits_used: number;
    num_chat_credits_total: number;
    num_friends: number;
    initial_message_credits: number;
    email: string;
}

///////////////////////////////////////////////////////////
// friends table
///////////////////////////////////////////////////////////

export interface AcceptFriendsInput {
    request_accepted: boolean | null;
    responded_on: string;
}

export interface Friends extends FriendsInput, AcceptFriendsInput {
    requested_on: string,
}

export interface FriendsInput {
    friend_pair: string, // `${user_1}${user_2}` not uuid, call getUniqueFriendRequestId()
    requester: string,
    requestee: string,
}

///////////////////////////////////////////////////////////
// purchases table
///////////////////////////////////////////////////////////

export interface FreePurchaseInput {
    user_id: string;
    chat_id: string | null;
    type: 'chats' | 'messages';
    platform: 'ios' | 'android';
    applied: true;
}

///////////////////////////////////////////////////////////
// admin_settings table
///////////////////////////////////////////////////////////

export interface AdminSettings {
    initial_chat_credits: number;
    initial_message_credits: number;
}

import {PostgrestError, SupabaseClient} from '@supabase/supabase-js';
import {ChatCompletionMessage, OpenAI} from 'openai';
import {chatAdapter, profileAdapter} from './adapters.ts';
import {GPTChatModel, GPTEmbedModel, SupabaseEdgeFunctions, Tables,} from './enums.ts';
import {ChatCompletionRequestMessageRoleEnum} from './externalTypes.ts';
import {AdminSettings, Chats, FreePurchaseInput, Profiles} from './schema.ts';
import {
    APIResponse, Chat, ChatMessage, EmbededMessage, MessageWithTokenUsage, Profile, SendUserMessageRequest,
} from './types.ts';

/**
 *
 * @param client
 * @param model
 * @param messages
 * @returns
 */
export const getChatCompletion = async (client: OpenAI, model: GPTChatModel,
    messages: ChatCompletionMessage[]
): Promise<APIResponse<MessageWithTokenUsage, Error>> => {
    try {
        const chatCompletionResponse = await client.createChatCompletion({
                                                                             model, messages,
                                                                         });

        const messageWithUsage: MessageWithTokenUsage = {
            role: chatCompletionResponse.choices[0].message.role as ChatCompletionRequestMessageRoleEnum,
            content: chatCompletionResponse.choices[0].message.content || '',
            promptTokens: chatCompletionResponse.usage!.prompt_tokens,
            completionTokens: chatCompletionResponse.usage!.completion_tokens,
            totalTokens: chatCompletionResponse.usage!.total_tokens,
        };

        return {
            data: messageWithUsage, error: null,
        };
    } catch (e) {
        console.error(e);
        return {
            data: null, error: e,
        };
    }
};

/**
 *
 * @param openAIClient
 * @param supabaseClient
 * @param correlationId
 * @param chatId
 * @param chatModel
 * @param embedModel
 * @param responseToSender
 * @param messages
 * @returns
 */
export const generateAndSendChatCompletionMessage = async (openAIClient: OpenAI, supabaseClient: SupabaseClient,
    correlationId: string, chatId: string, chatModel: GPTChatModel, embedModel: GPTEmbedModel,
    responseToSender: string | null, messages: ChatCompletionMessage[]
): Promise<APIResponse<ChatMessage, Error>> => {
    //
    // Give prompt to ChatGPT and get response message
    //

    const {data: message, error: chatError} = await getChatCompletion(openAIClient, chatModel, messages);

    console.log(`[generateAndSendChatCompletionMessage] messages:` + messages.map((m) => `\n\t${JSON.stringify(m)}`));

    if (chatError || !message) {
        return {
            data: null, error: chatError,
        };
    }

    //
    // Insert ChatGPT's response as row into chat_message table
    //

    const sendUserMessageRequest: SendUserMessageRequest = {
        correlationId,
        chatId,
        sender: null,
        responseToSender: responseToSender,
        chatModel,
        embedModel,
        message,
        generateResponse: false,
    };

    const {data: chatMessage, error: sendError} = await supabaseClient.functions.invoke(
        SupabaseEdgeFunctions.SEND_USER_MESSAGE, {
            body: sendUserMessageRequest,
        });

    if (sendError || !chatMessage) {
        return {
            data: null, error: sendError,
        };
    }

    return {
        data: chatMessage as ChatMessage, error: null,
    };
};

/**
 *
 * @param client
 * @param model
 * @param content
 * @returns
 */
export const getEmbedding = async (client: OpenAI, model: GPTEmbedModel,
    content: string
): Promise<APIResponse<EmbededMessage, Error>> => {
    try {
        const {data, usage} = await client.createEmbeddings({
                                                                model, input: content,
                                                            });

        return {
            data: {
                embedding: data[0].embedding, promptTokens: usage.prompt_tokens,
            }, error: null,
        };
    } catch (e) {
        return {
            data: null, error: e,
        };
    }
};

/**
 *
 * @param client
 * @param chatId
 * @returns
 */
export const fetchChat = async (client: SupabaseClient, chatId: string): Promise<APIResponse<Chat, PostgrestError>> => {
    const {data, error} = await client
        .from(Tables.CHATS)
        .select()
        .eq('id', chatId)
        .single();

    if (error || !data) {
        return {
            data: null, error: error!,
        };
    }

    return {
        data: chatAdapter(data as Chats), error: null,
    };
};

/**
 *
 * @param client
 * @returns
 */
export const fetchAdminSettings = async (client: SupabaseClient): Promise<APIResponse<AdminSettings, PostgrestError>> => {
    const {data, error} = await client
        .from(Tables.ADMIN_SETTINGS)
        .select()
        .single();

    if (error || !data) {
        return {
            data: null, error: error!,
        };
    }

    return {
        data: data as AdminSettings, error: null,
    };
};

/**
 *
 * @param client
 * @param username
 * @param discriminator
 */
export const fetchProfile = async (client: SupabaseClient, username: string,
    discriminator: string
): Promise<APIResponse<Profile, PostgrestError>> => {
    const {data, error} = await client
        .from(Tables.PROFILES)
        .select()
        .eq('username', username)
        .eq('discriminator', discriminator)
        .maybeSingle();

    if (error || !data) {
        return {
            data: null, error: error!,
        };
    }

    return {
        data: profileAdapter(data as Profiles), error: null,
    };
};

/**
 *
 * @param client
 * @param correlationId
 * @param userId
 * @param chatId
 * @param type
 * @param platform
 */
export const insertFreePurchaseRow = async (
    client: SupabaseClient,
    correlationId: string,
    userId: string,
    chatId: string | null,
    type: 'chats' | 'messages',
    platform: 'ios' | 'android',
) => {

    const input: FreePurchaseInput = {
        user_id: userId,
        chat_id: chatId,
        type,
        platform,
        applied: true,
    };

    const { data, error } = await client
        .from(Tables.PURCHASES)
        .insert(input)
        .select()
        .single();

    if (error) {
        console.error(`[${correlationId}] error inserting free purchase row: ${JSON.stringify(error)}`);
    } else {
        console.info(`[${correlationId}] successfully inserted free purchase row: ${JSON.stringify(data)}`);
    }
};

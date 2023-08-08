import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { chatAdapter } from '../common/adapters.ts';
import {
    fetchAdminSettings, generateAndSendChatCompletionMessage, insertFreePurchaseRow,
} from '../common/api.ts';
import { getOpenAIClient, getSupabaseClient } from '../common/clients.ts';
import { DEFAULT_HEADERS } from '../common/constants.ts';
import { Tables } from '../common/enums.ts';
import { ChatCompletionRequestMessageRoleEnum } from '../common/externalTypes.ts';
import { ChatsInput } from '../common/schema.ts';
import {
    Chat,
    CreateChatRequest,
    CreateChatResponse,
} from '../common/types.ts';
import { serverErrorResponse } from '../common/response.ts';

serve(async (req: Request) => {
    const request = (await req.json()) as CreateChatRequest;

    console.log(
        `[${request.correlationId}] request=${JSON.stringify(request)}`
    );

    //
    // Fetch admin_settings
    //

    const supabaseClient = getSupabaseClient(req);

    const { data: adminSettings, error: adminError } = await fetchAdminSettings(
        supabaseClient
    );

    if (adminError || !adminSettings) {
        return serverErrorResponse(
            adminError,
            `call fetchAdminSettings`,
            request.correlationId
        );
    } else {
        console.log(
            `[${request.correlationId}] got adminSettings: ${JSON.stringify(
                adminSettings
            )}`
        );
    }

    //
    // Insert new row into chats table
    //

    const chatInput: ChatsInput = {
        name: request.chatName,
        created_by: request.userId,
        members: request.memberIds,
        ai_name: request.aiName,
        gpt_chat_model: request.gptChatModel,
        gpt_embed_model: request.gptEmbedModel,
        prompt_message_content: request.promptMessageContent,
        num_message_credits_total: adminSettings.initial_message_credits,
        initial_message_credits: adminSettings.initial_message_credits,
    };

    const { data: chatData, error: chatError } = await supabaseClient
        .from(Tables.CHATS)
        .insert(chatInput)
        .select()
        .single();

    if (chatError || !chatData) {
        return serverErrorResponse(
            chatError,
            `insert ${Tables.CHATS}`,
            request.correlationId
        );
    } else {
        console.log(
            `[${
                request.correlationId
            }] inserted new chats row: ${JSON.stringify(chatData)}`
        );
    }

    const chat: Chat = chatAdapter(chatData);

    //
    // Grant the new chat some sent message credits
    //

    insertFreePurchaseRow(
        supabaseClient,
        request.correlationId,
        request.userId,
        chat.id,
        "messages",
        request.platform,
    );

    //
    // Call generateAndSendChatCompletionMessage to generate and send initial message from ChatGPT
    //

    const openAIClient = getOpenAIClient();

    const { data: chatMessage, error } =
        await generateAndSendChatCompletionMessage(
            openAIClient,
            supabaseClient,
            request.correlationId,
            chat.id,
            request.gptChatModel,
            request.gptEmbedModel,
            null,
            [
                {
                    role: ChatCompletionRequestMessageRoleEnum.System,
                    content: request.promptMessageContent,
                },
            ]
        );

    if (error || !chatMessage) {
        return serverErrorResponse(
            error,
            'call generateAndSendChatCompletionMessage',
            request.correlationId
        );
    } else {
        console.log(
            `[${
                request.correlationId
            }] got initial ChatGPT response message: ${JSON.stringify(
                chatMessage
            )}`
        );
    }

    //
    // Return and log CreateChatResponse
    //

    const responseBody: CreateChatResponse = {
        chat,
        chatMessage,
    };

    console.log(
        `[${request.correlationId}] returning ${JSON.stringify(responseBody)}`
    );

    return new Response(JSON.stringify(responseBody), DEFAULT_HEADERS);
});

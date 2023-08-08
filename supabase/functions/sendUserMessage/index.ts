import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { chatMessageAdapter } from '../common/adapters.ts';
import { getSupabaseClient } from '../common/clients.ts';
import { DEFAULT_HEADERS } from '../common/constants.ts';
import { SupabaseEdgeFunctions, Tables } from '../common/enums.ts';
import { ChatCompletionRole } from '../common/externalTypes.ts';
import { ChatMessagesInput } from '../common/schema.ts';
import {
    ChatMessage,
    EmbedMessageRequest,
    EmbededMessage,
    GenerateResponseMessageRequest,
    SendUserMessageRequest,
} from '../common/types.ts';
import { serverErrorResponse } from '../common/response.ts';

serve(async (req: Request) => {
    const request = (await req.json()) as SendUserMessageRequest;

    console.log(
        `[${request.correlationId}] request=${JSON.stringify(request)}`
    );

    //
    // Insert new row into chat_messages table without embeddings column yet
    //

    const supabaseClient = getSupabaseClient(req);

    const chatMessageInput: ChatMessagesInput = {
        chat_id: request.chatId,
        sender_id: request.sender,
        role: request.message.role as ChatCompletionRole,
        content: request.message.content!,
        response_to_sender_id: request.responseToSender,
        prompt_tokens: 0,
        completion_tokens: 0,
        total_tokens: 0,
    };

    const { data: chatMessageRow, error: chatMessageError } =
        await supabaseClient
            .from(Tables.CHAT_MESSAGES)
            .insert(chatMessageInput)
            .select()
            .single();

    if (chatMessageError || !chatMessageRow) {
        return serverErrorResponse(
            chatMessageError,
            `insert ${Tables.CHAT_MESSAGES}`,
            request.correlationId
        );
    } else {
        console.log(
            `[${
                request.correlationId
            }] inserted new chat_message row: ${JSON.stringify(chatMessageRow)}`
        );
    }

    const chatMessage: ChatMessage = chatMessageAdapter(chatMessageRow);

    //
    // Call EMBED_MESSAGE
    //

    const embedMessageRequest: EmbedMessageRequest = {
        correlationId: request.correlationId,
        chatMessageId: chatMessage.id,
        messageContent: request.message.content!,
        model: request.embedModel,
    };

    const { data: embedData, error: embedError } =
        await supabaseClient.functions.invoke(
            SupabaseEdgeFunctions.EMBED_MESSAGE,
            {
                body: embedMessageRequest,
            }
        );

    if (embedError || !embedData) {
        return serverErrorResponse(
            embedError,
            'call EMBED_MESSAGE',
            request.correlationId
        );
    } else {
        console.log(
            `[${
                request.correlationId
            }] generated embeddings data: ${JSON.stringify(embedData)}`
        );
    }

    //
    // Asynchronously, call GENERATE_RESPONSE_MESSAGE (if requested and responding to user)
    //

    if (request.generateResponse && request.sender) {
        const genResponseRequest: GenerateResponseMessageRequest = {
            correlationId: request.correlationId,
            chatId: request.chatId,
            chatMessageId: chatMessage.id,
            responseToSender: request.sender!,
            message: request.message,
            embedding: (embedData as EmbededMessage).embedding,
        };

        supabaseClient.functions
            .invoke(SupabaseEdgeFunctions.GENERATE_RESPONSE_MESSAGE, {
                body: genResponseRequest,
            })
            .then(({ error: genError }) => {
                if (genError) {
                    console.error(
                        `[${
                            request.correlationId
                        }][call GENERATE_RESPONSE_MESSAGE] ${JSON.stringify(
                            genError
                        )}`
                    );
                } else {
                    console.log(
                        `[${request.correlationId}] successfully called GENERATE_RESPONSE_MESSAGE`
                    );
                }
            });
    }

    //
    // Return and log ChatMessage
    //

    console.log(
        `[${request.correlationId}] returning ${JSON.stringify(chatMessage)}`
    );

    return new Response(JSON.stringify(chatMessage), DEFAULT_HEADERS);
});

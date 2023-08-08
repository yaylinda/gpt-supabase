import {serve} from 'https://deno.land/std@0.168.0/http/server.ts';
import {fetchChat, generateAndSendChatCompletionMessage,} from '../common/api.ts';
import {getOpenAIClient, getSupabaseClient} from '../common/clients.ts';
import {DEFAULT_HEADERS} from '../common/constants.ts';
import {GenerateResponseMessageRequest,} from '../common/types.ts';
import {serverErrorResponse} from '../common/response.ts';
import {getMessageHistory} from "./messageHistory.ts";

serve(async (req: Request) => {
    const request = (await req.json()) as GenerateResponseMessageRequest;

    console.log(
        `[${request.correlationId}] request=${JSON.stringify(request)}`
    );

    //
    // Fetch chat
    //

    const supabaseClient = getSupabaseClient(req);

    const {data: chat, error: chatError} = await fetchChat(
        supabaseClient,
        request.chatId
    );

    if (chatError || !chat) {
        return serverErrorResponse(
            chatError,
            `call fetchChat`,
            request.correlationId
        );
    } else {
        console.log(
            `[${request.correlationId}] got chat: ${JSON.stringify(chat)}`
        );
    }

    //
    // Do a message similarity search
    //

    const messages = await getMessageHistory(
        request.correlationId,
        supabaseClient,
        request,
        chat.promptMessageContent,
        chat.aiName
    );

    console.log(
        `[${request.correlationId}] messages used for prompt:` +
        messages.map((m) => `\n\t${JSON.stringify(m)}`).join('')
    );

    //
    // Use message history to get a response message from ChatGPT
    //

    const openAIClient = getOpenAIClient();

    const {data: chatMessage, error} =
        await generateAndSendChatCompletionMessage(
            openAIClient,
            supabaseClient,
            request.correlationId,
            request.chatId,
            chat.gptChatModel,
            chat.gptEmbedModel,
            request.responseToSender,
            messages
        );

    console.error(error);

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
            }] got ChatGPT response message: ${JSON.stringify(chatMessage)}`
        );
    }

    //
    // Return and log ChatMessage
    //

    console.log(
        `[${request.correlationId}] returning ${JSON.stringify(chatMessage)}`
    );

    return new Response(JSON.stringify(chatMessage), DEFAULT_HEADERS);
});

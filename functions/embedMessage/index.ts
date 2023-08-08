import {serve} from 'https://deno.land/std@0.168.0/http/server.ts';
import {getEmbedding} from '../common/api.ts';
import {getOpenAIClient, getSupabaseClient} from '../common/clients.ts';
import {DEFAULT_HEADERS} from '../common/constants.ts';
import {Tables} from '../common/enums.ts';
import {EmbedMessageRequest} from '../common/types.ts';
import {serverErrorResponse} from '../common/response.ts';

serve(async (req) => {
    const request = (await req.json()) as EmbedMessageRequest;

    console.log(
        `[${request.correlationId}] request=${JSON.stringify(request)}`
    );

    //
    // Generate embeddings for the new message
    //

    const openAIClient = getOpenAIClient();

    const {data: embedData, error: embedError} = await getEmbedding(
        openAIClient,
        request.model,
        request.messageContent
    );

    if (embedError || !embedData) {
        return serverErrorResponse(
            embedError,
            'call getEmbedding',
            request.correlationId
        );
    } else {
        console.log(`[${request.correlationId}] got embedding data`);
    }

    //
    // Asynchronously, update chat_message row with embeddings data
    //

    const supabaseClient = getSupabaseClient(req);

    supabaseClient
        .from(Tables.CHAT_MESSAGES)
        .update({
            embedding: embedData.embedding,
            prompt_tokens: embedData.promptTokens,
        })
        .eq('id', request.chatMessageId)
        .then(({error: updateError}) => {
            if (updateError) {
                console.error(
                    `[${request.correlationId}][update ${
                        Tables.CHAT_MESSAGES
                    }] ${JSON.stringify(updateError)}`
                );
            } else {
                console.log(
                    `[${request.correlationId}] successfully updated chat_messages embedding column`
                );
            }
        });

    //
    // Return and log EmbededMessage
    //

    console.log(
        `[${request.correlationId}] returning ${JSON.stringify(embedData)}`
    );

    return new Response(JSON.stringify(embedData), DEFAULT_HEADERS);
});

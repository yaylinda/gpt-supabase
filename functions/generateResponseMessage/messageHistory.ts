import {GenerateResponseMessageRequest, SearchMessagesRequest} from "../common/types.ts";
import {ChatCompletionMessage} from "https://deno.land/x/openai@1.4.2/src/types.ts";
import {gptMessageAdapter} from "../common/adapters.ts";
import {ChatMessages} from "../common/schema.ts";
import {ChatCompletionRequestMessageRoleEnum} from "../common/externalTypes.ts";
import {SupabaseClient} from '@supabase/supabase-js';

/**
 *
 * @returns
 */
export const getMessageHistory = async (
    correlationId: string,
    supabaseClient: SupabaseClient,
    request: GenerateResponseMessageRequest,
    initialPrompt: string,
    aiName: string
): Promise<ChatCompletionMessage[]> => {
    const searchMessagesRequest: SearchMessagesRequest = {
        chat_id: request.chatId,
        query_embedding: request.embedding,
        similarity_threshold: 0.5,
        max_rows: 10,
        exclude_id: request.chatMessageId,
    };

    // Search for messages in the given chat that are similar to the given user's message.
    // Does NOT include the given user's message, or any other messages inserted afterwards.
    // Return messages in ASC timestamp order, the oldest message is returned first.
    const {data, error} = await supabaseClient.rpc(
        'search_messages',
        searchMessagesRequest
    );

    if (error) {
        console.error(
            `[${correlationId}] error calling search_messages: ${JSON.stringify(
                error
            )}`
        );
    }

    const messages: ChatCompletionMessage[] = (data || []).map(
        // deno-lint-ignore no-explicit-any
        (m: any) => gptMessageAdapter(m as ChatMessages)
    );

    console.log(
        `[${correlationId}] got ${messages.length} messages similar to "${request.message.content}"`
    );

    return [
        {
            role: ChatCompletionRequestMessageRoleEnum.System,
            content: initialPrompt,
        },
        {
            role: ChatCompletionRequestMessageRoleEnum.Assistant,
            content: `${aiName}: Hello friends!`,
            name: aiName,
        },
        ...messages,
        {
            role: request.message.role as 'user',
            content: request.message.content,
            name: request.message.name,
        },
    ];
};

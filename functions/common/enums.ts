export enum Tables {
    CHATS = 'chats',
    CHAT_MESSAGES = 'chat_messages',
    FRIENDS = 'friends',
    PROFILES = 'profiles',
    ADMIN_SETTINGS = 'admin_settings',
    PURCHASES = 'purchases'
}

export enum SupabaseEdgeFunctions {
    CREATE_CHAT = 'createChat',
    SEND_USER_MESSAGE = 'sendUserMessage',
    EMBED_MESSAGE = 'embedMessage',
    GENERATE_RESPONSE_MESSAGE = 'generateResponseMessage',
    REQUEST_FRIEND = 'requestFriend',
}

export enum GPTChatModel {
    GPT_3_5 = 'gpt-3.5-turbo',
    GPT_4 = 'gpt-4',
}

export enum GPTEmbedModel {
    ADA = 'text-embedding-ada-002',
}

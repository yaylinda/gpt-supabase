export const CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

export const DEFAULT_HEADERS = {
    headers: {
        'Content-Type': 'application/json',
        ...CORS_HEADERS,
    },
};

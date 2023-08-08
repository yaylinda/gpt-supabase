import { createClient } from '@supabase/supabase-js';
import { OpenAI } from 'openai';

/**
 *
 * @param req
 * @returns
 */
export const getSupabaseClient = (req: Request) =>
    createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? '',
        {
            global: {
                headers: { Authorization: req.headers.get('Authorization')! },
            },
            auth: { persistSession: false },
        }
    );

/**
 *
 * @returns
 */
export const getOpenAIClient = () => {
    return new OpenAI(Deno.env.get('OPEN_AI_API_KEY')!);
};

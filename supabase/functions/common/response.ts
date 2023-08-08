import {DEFAULT_HEADERS} from './constants.ts';

/**
 *
 * @param data
 * @param correlationId
 * @returns
 */
export const successResponse = <T>(
    data: T,
    correlationId: string
) => {
    console.log(`[${correlationId}][SUCCESS] ${JSON.stringify(data)}`);
    return new Response(JSON.stringify(data), {
        ...DEFAULT_HEADERS,
        status: 200,
        statusText: 'Ok',
    });
};

/**
 *
 * @param error
 * @param operation
 * @param correlationId
 * @returns
 */
export const serverErrorResponse = <T>(
    error: T,
    operation: string,
    correlationId: string
) => {
    console.error(`[${correlationId}][${operation}] ${JSON.stringify(error)}`);
    return new Response(JSON.stringify(error), {
        ...DEFAULT_HEADERS,
        status: 500,
        statusText: 'Server Error',
    });
};

/**
 *
 * @param error
 * @param operation
 * @param correlationId
 * @returns
 */
export const clientErrorResponse = <T>(
    error: T,
    operation: string,
    correlationId: string
) => {
    console.warn(`[${correlationId}][${operation}] ${JSON.stringify(error)}`);
    return new Response(JSON.stringify(error), {
        ...DEFAULT_HEADERS,
        status: 400,
        statusText: 'Bad Request',
    });
};

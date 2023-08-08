import {serve} from "https://deno.land/std@0.168.0/http/server.ts"
import {CORS_HEADERS} from '../common/constants.ts';
import {RequestFriendRequest, RequestFriendResponse} from "../common/types.ts";
import {successResponse} from "../common/response.ts";
import {fetchProfile} from "../common/api.ts";
import {getSupabaseClient} from "../common/clients.ts";
import {evaluateRequest} from "./evaluator.ts";
import {getUniqueFriendRequestId} from "../common/utils.ts";
import {Tables} from "../common/enums.ts";
import {FriendsInput} from "../common/schema.ts";

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: CORS_HEADERS })
    }

    const request = (await req.json()) as RequestFriendRequest;

    console.log(
        `[${request.correlationId}] request=${JSON.stringify(request)}`
    );

    //
    // Verify requestee profile exists
    //

    const supabaseClient = getSupabaseClient(req);

    const [username, discriminator] = request.requesteeUsernameDiscriminator.split('#');

    const {
        data: requesteeProfile,
        error: requesteeError
    } = await fetchProfile(supabaseClient, username.trim(), discriminator.trim());

    if (requesteeError || !requesteeProfile) {
        return successResponse<RequestFriendResponse>(
            {success: false, message: `Oops! That user doesn't exist!`},
            request.correlationId
        );
    }

    //
    // Evaluate friend request can be sent
    //

    const uniqueRequestId = getUniqueFriendRequestId(request.userId, requesteeProfile.id);

    const evaluation = await evaluateRequest(supabaseClient, uniqueRequestId, request.userId, requesteeProfile.id, request.requesteeUsernameDiscriminator.trim());

    if (!evaluation.success) {
        return successResponse<RequestFriendResponse>(
            evaluation,
            request.correlationId
        );
    }

    //
    // Insert new friend request row
    //

    const friendRequestInput: FriendsInput = {
        friend_pair: uniqueRequestId,
        requester: request.userId,
        requestee: requesteeProfile.id,
    };

    const {error} = await supabaseClient
        .from(Tables.FRIENDS)
        .insert(friendRequestInput);

    if (error) {
        return successResponse<RequestFriendResponse>(
            {success: false, message: JSON.stringify(error)},
            request.correlationId
        );
    }

    //
    // Yay! Friend request row got inserted!
    //

    return successResponse({success: true, message: ''}, request.correlationId);
});

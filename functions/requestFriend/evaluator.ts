import {RequestFriendResponse} from "../common/types.ts";
import {
    isFriendRequestDeniedByOtherRow,
    isFriendRequestDeniedByUserRow,
    isFriendRequestReceivedRow,
    isFriendRequestSentRow,
    isFriendRow
} from "../common/utils.ts";
import {Tables} from "../common/enums.ts";
import {SupabaseClient} from '@supabase/supabase-js';

/**
 *
 * @param client
 * @param uniqueRequestId
 * @param requesterId
 * @param requesteeId
 * @param requesteeUsernameDiscriminator
 */
export const evaluateRequest = async (
    client: SupabaseClient,
    uniqueRequestId: string,
    requesterId: string,
    requesteeId: string,
    requesteeUsernameDiscriminator: string
): Promise<RequestFriendResponse> => {

    if (requesterId === requesteeId) {
        return {
            success: false,
            message: `Silly Goose! That's you!`,
        };
    }

    const {data: friendRow, error} = await client
        .from(Tables.FRIENDS)
        .select()
        .eq('friend_pair', uniqueRequestId)
        .maybeSingle();

    if (error) {
        return {
            success: false,
            message: JSON.stringify(error),
        };
    }

    if (!friendRow) {
        return {success: true, message: ''};
    }

    if (isFriendRow(friendRow)) {
        return {
            success: false,
            message: `Looks like you and ${requesteeUsernameDiscriminator} are already friends.`
        };
    }

    if (isFriendRequestReceivedRow(friendRow, requesterId)) {
        return {
            success: false,
            message: `Looks like you have already received a friend request from ${requesteeUsernameDiscriminator}.`
        };
    }

    if (isFriendRequestSentRow(friendRow, requesterId)) {
        return {
            success: false,
            message: `Looks like you have already sent a friend request to ${requesteeUsernameDiscriminator}. Please give them some time to respond.`
        };
    }

    if (isFriendRequestDeniedByUserRow(friendRow, requesterId)) {
        return {
            success: false,
            message: `Looks like you have previously denied a friend request from ${requesteeUsernameDiscriminator}. If you've changed your mind, you can accept their request now!`
        };
    }

    if (isFriendRequestDeniedByOtherRow(friendRow, requesterId)) {
        return {
            success: false,
            message: `Looks like ${requesteeUsernameDiscriminator} has denied your friend request. Maybe they will change their mind.`
        };
    }

    return {success: true, message: ''};
};

import {Friends} from "./schema.ts";

export const getUniqueFriendRequestId = (uid1: string, uid2: string): string => [uid1, uid2].sort().join('+');

export const isFriendRow = (friendRow: Friends): boolean => !!friendRow.request_accepted;

export const isFriendRequestReceivedRow = (friendRow: Friends, userId: string): boolean => !friendRow.request_accepted && friendRow.responded_on === null && friendRow.requester !== userId && friendRow.requestee === userId;

export const isFriendRequestSentRow = (friendRow: Friends, userId: string): boolean => !friendRow.request_accepted && friendRow.responded_on === null && friendRow.requester === userId && friendRow.requestee !== userId;

export const isFriendRequestDeniedByUserRow = (friendRow: Friends, userId: string): boolean => !friendRow.request_accepted && friendRow.responded_on !== null && friendRow.requester !== userId && friendRow.requestee === userId;

export const isFriendRequestDeniedByOtherRow = (friendRow: Friends, userId: string): boolean => !friendRow.request_accepted && friendRow.responded_on !== null && friendRow.requester === userId && friendRow.requestee !== userId;

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

admin.initializeApp();
const db = admin.firestore();

// Region config
const REGION = "europe-west3";

// --- HELPERS ---
function assertAuth(request: any): string {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    return request.auth.uid;
}

// ============================================================================
// FRIEND REQUEST FUNCTIONS
// ============================================================================

// --- Send Friend Request ---
export const sendFriendRequest_eu1 = onCall({ region: REGION }, async (request) => {
    const fromUid = assertAuth(request);
    const { toUid, senderName, senderAvatar } = request.data;

    if (!toUid) throw new HttpsError("invalid-argument", "toUid required");
    if (fromUid === toUid) throw new HttpsError("invalid-argument", "Cannot send request to yourself");

    // Check if request already exists
    const existingQuery = await db.collection("friend_requests")
        .where("fromUid", "==", fromUid)
        .where("toUid", "==", toUid)
        .where("status", "==", "pending")
        .limit(1)
        .get();

    if (!existingQuery.empty) {
        throw new HttpsError("already-exists", "Friend request already pending");
    }

    // Check if already friends
    const friendDoc = await db.collection("friends").doc(fromUid).collection("list").doc(toUid).get();
    if (friendDoc.exists) {
        throw new HttpsError("already-exists", "Already friends");
    }

    // Create the friend request
    const requestId = db.collection("friend_requests").doc().id;
    const requestData: any = {
        id: requestId,
        fromUid: fromUid,
        toUid: toUid,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (senderName) requestData.fromName = senderName;
    if (senderAvatar) requestData.fromAvatar = senderAvatar;

    await db.collection("friend_requests").doc(requestId).set(requestData);

    logger.info(`Friend request sent from ${fromUid} to ${toUid}`);
    return { success: true, requestId };
});

// --- Accept Friend Request ---
export const acceptFriendRequest_eu1 = onCall({ region: REGION }, async (request) => {
    const uid = assertAuth(request);
    const { requestId } = request.data;

    if (!requestId) throw new HttpsError("invalid-argument", "requestId required");

    const requestRef = db.collection("friend_requests").doc(requestId);

    await db.runTransaction(async (tx) => {
        const requestSnap = await tx.get(requestRef);
        if (!requestSnap.exists) {
            throw new HttpsError("not-found", "Friend request not found");
        }

        const requestData = requestSnap.data()!;

        // Security: Only the recipient can accept
        if (requestData.toUid !== uid) {
            throw new HttpsError("permission-denied", "Not authorized to accept this request");
        }

        if (requestData.status !== "pending") {
            throw new HttpsError("failed-precondition", "Request is not pending");
        }

        const fromUid = requestData.fromUid;
        const toUid = requestData.toUid;

        // Update request status
        tx.update(requestRef, {
            status: "accepted",
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Create bidirectional friendship
        const friendData = { since: admin.firestore.FieldValue.serverTimestamp() };

        const ref1 = db.collection("friends").doc(fromUid).collection("list").doc(toUid);
        const ref2 = db.collection("friends").doc(toUid).collection("list").doc(fromUid);

        tx.set(ref1, friendData);
        tx.set(ref2, friendData);
    });

    logger.info(`Friend request ${requestId} accepted by ${uid}`);
    return { success: true };
});

// --- Reject Friend Request ---
export const rejectFriendRequest_eu1 = onCall({ region: REGION }, async (request) => {
    const uid = assertAuth(request);
    const { requestId } = request.data;

    if (!requestId) throw new HttpsError("invalid-argument", "requestId required");

    const requestRef = db.collection("friend_requests").doc(requestId);
    const requestSnap = await requestRef.get();

    if (!requestSnap.exists) {
        throw new HttpsError("not-found", "Friend request not found");
    }

    const requestData = requestSnap.data()!;

    // Security: Only the recipient can reject
    if (requestData.toUid !== uid) {
        throw new HttpsError("permission-denied", "Not authorized to reject this request");
    }

    if (requestData.status !== "pending") {
        throw new HttpsError("failed-precondition", "Request is not pending");
    }

    await requestRef.update({
        status: "rejected",
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    logger.info(`Friend request ${requestId} rejected by ${uid}`);
    return { success: true };
});

// --- Cancel Friend Request ---
export const cancelFriendRequest_eu1 = onCall({ region: REGION }, async (request) => {
    const uid = assertAuth(request);
    const { requestId } = request.data;

    if (!requestId) throw new HttpsError("invalid-argument", "requestId required");

    const requestRef = db.collection("friend_requests").doc(requestId);
    const requestSnap = await requestRef.get();

    if (!requestSnap.exists) {
        throw new HttpsError("not-found", "Friend request not found");
    }

    const requestData = requestSnap.data()!;

    // Security: Only the sender can cancel
    if (requestData.fromUid !== uid) {
        throw new HttpsError("permission-denied", "Not authorized to cancel this request");
    }

    if (requestData.status !== "pending") {
        throw new HttpsError("failed-precondition", "Request is not pending");
    }

    await requestRef.delete();

    logger.info(`Friend request ${requestId} cancelled by ${uid}`);
    return { success: true };
});

// --- Remove Friend ---
export const removeFriend_eu1 = onCall({ region: REGION }, async (request) => {
    const uid = assertAuth(request);
    const { friendUid } = request.data;

    if (!friendUid) throw new HttpsError("invalid-argument", "friendUid required");

    const batch = db.batch();

    // Remove bidirectional friendship
    const ref1 = db.collection("friends").doc(uid).collection("list").doc(friendUid);
    const ref2 = db.collection("friends").doc(friendUid).collection("list").doc(uid);

    batch.delete(ref1);
    batch.delete(ref2);

    await batch.commit();

    logger.info(`Friendship removed between ${uid} and ${friendUid}`);
    return { success: true };
});

// ============================================================================
// EVENT FUNCTIONS - Updated for Your Schema
// ============================================================================
// Schema:
// - attendees: string[] (array of user IDs)
// - usersJoined: [{uid, username, profilePicture}] (denormalized user info)
// - capacity: number
// - isPrivate: boolean
// - creatorId: string
// ============================================================================

// --- 1. Event Creation Trigger ---
export const onEventCreated = onDocumentCreated(
    { region: REGION, document: "events/{eventId}" },
    async (event) => {
        const snap = event.data;
        if (!snap) return;

        const eventId = event.params.eventId;
        const data = snap.data();

        const updates: any = {};

        // Ensure required fields exist
        if (!data.createdAt) updates.createdAt = admin.firestore.FieldValue.serverTimestamp();
        if (!data.id) updates.id = eventId;
        if (!data.attendees) updates.attendees = [];
        if (!data.usersJoined) updates.usersJoined = [];

        if (Object.keys(updates).length > 0) {
            await snap.ref.set(updates, { merge: true });
            logger.info(`Initialized event ${eventId}`);
        }
    }
);

// --- 2. Join Event (Callable) ---
// Uses attendees array and usersJoined array per your schema
export const joinEvent = onCall({ region: REGION }, async (request) => {
    const uid = assertAuth(request);
    const eventId = request.data.eventId;

    if (!eventId) throw new HttpsError("invalid-argument", "Event ID required");

    const eventRef = db.collection("events").doc(eventId);
    const userRef = db.collection("users").doc(uid);

    await db.runTransaction(async (tx) => {
        const eventSnap = await tx.get(eventRef);
        if (!eventSnap.exists) throw new HttpsError("not-found", "Event not found");

        const eventData = eventSnap.data()!;
        const isPrivate = eventData.isPrivate === true;
        const capacity = eventData.capacity || 1000;
        const attendees: string[] = eventData.attendees || [];

        // Check capacity
        if (attendees.length >= capacity) {
            throw new HttpsError("failed-precondition", "Event is full");
        }

        // Check if already joined
        if (attendees.includes(uid)) {
            return; // Already a member
        }

        // For private events, create a join request instead
        if (isPrivate) {
            const joinRequestRef = db.collection("join_requests").doc(`${eventId}_${uid}`);
            tx.set(joinRequestRef, {
                id: `${eventId}_${uid}`,
                eventId: eventId,
                userId: uid,
                status: "pending",
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
            return;
        }

        // Get user data for usersJoined
        const userSnap = await tx.get(userRef);
        const userData = userSnap.data() || {};

        const userJoinedEntry = {
            uid: uid,
            username: userData.username || "Unknown",
            profilePicture: userData.profilePicture || null
        };

        // Update event: add to attendees array and usersJoined array
        tx.update(eventRef, {
            attendees: admin.firestore.FieldValue.arrayUnion(uid),
            usersJoined: admin.firestore.FieldValue.arrayUnion(userJoinedEntry)
        });

        // Add to user's joinedEvents subcollection
        const userJoinedRef = db.collection("users").doc(uid).collection("joinedEvents").doc(eventId);
        tx.set(userJoinedRef, {
            joinedAt: admin.firestore.FieldValue.serverTimestamp()
        });
    });

    logger.info(`User ${uid} joined event ${eventId}`);
    return { success: true };
});

// --- 3. Approve Join Request (For Private Events) ---
export const approveAttendee = onCall({ region: REGION }, async (request) => {
    const hostUid = assertAuth(request);
    const { eventId, attendeeId } = request.data;

    if (!eventId || !attendeeId) throw new HttpsError("invalid-argument", "Missing params");

    const eventRef = db.collection("events").doc(eventId);
    const joinRequestRef = db.collection("join_requests").doc(`${eventId}_${attendeeId}`);
    const userRef = db.collection("users").doc(attendeeId);

    await db.runTransaction(async (tx) => {
        const eventSnap = await tx.get(eventRef);
        if (!eventSnap.exists) throw new HttpsError("not-found", "Event not found");

        const eventData = eventSnap.data()!;

        // Verify host permission
        if (eventData.creatorId !== hostUid) {
            throw new HttpsError("permission-denied", "Not event host");
        }

        // Check join request exists
        const joinRequestSnap = await tx.get(joinRequestRef);
        if (!joinRequestSnap.exists) {
            throw new HttpsError("not-found", "Join request not found");
        }

        const joinRequestData = joinRequestSnap.data()!;
        if (joinRequestData.status !== "pending") {
            throw new HttpsError("failed-precondition", "Request already processed");
        }

        // Check capacity
        const capacity = eventData.capacity || 1000;
        const attendees: string[] = eventData.attendees || [];
        if (attendees.length >= capacity) {
            throw new HttpsError("failed-precondition", "Event is full");
        }

        // Get user data
        const userSnap = await tx.get(userRef);
        const userData = userSnap.data() || {};

        const userJoinedEntry = {
            uid: attendeeId,
            username: userData.username || "Unknown",
            profilePicture: userData.profilePicture || null
        };

        // Update join request status
        tx.update(joinRequestRef, {
            status: "approved",
            respondedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Add to event
        tx.update(eventRef, {
            attendees: admin.firestore.FieldValue.arrayUnion(attendeeId),
            usersJoined: admin.firestore.FieldValue.arrayUnion(userJoinedEntry)
        });

        // Add to user's joinedEvents
        const userJoinedRef = db.collection("users").doc(attendeeId).collection("joinedEvents").doc(eventId);
        tx.set(userJoinedRef, {
            joinedAt: admin.firestore.FieldValue.serverTimestamp()
        });
    });

    logger.info(`Host ${hostUid} approved ${attendeeId} for event ${eventId}`);
    return { success: true };
});

// --- 4. Leave Event (Callable) ---
export const leaveEvent = onCall({ region: REGION }, async (request) => {
    const uid = assertAuth(request);
    const eventId = request.data.eventId;

    if (!eventId) throw new HttpsError("invalid-argument", "Event ID required");

    const eventRef = db.collection("events").doc(eventId);
    const userJoinedRef = db.collection("users").doc(uid).collection("joinedEvents").doc(eventId);

    await db.runTransaction(async (tx) => {
        const eventSnap = await tx.get(eventRef);
        if (!eventSnap.exists) return;

        const eventData = eventSnap.data()!;
        const attendees: string[] = eventData.attendees || [];

        // Check if user is a member
        if (!attendees.includes(uid)) {
            return; // Not a member
        }

        // Remove from attendees array
        tx.update(eventRef, {
            attendees: admin.firestore.FieldValue.arrayRemove(uid)
        });

        // Note: Removing from usersJoined array of objects requires reading and filtering
        // For simplicity, we only remove from attendees array
        // usersJoined can be cleaned up periodically or on next read

        // Remove from user's joinedEvents
        tx.delete(userJoinedRef);
    });

    logger.info(`User ${uid} left event ${eventId}`);
    return { success: true };
});

// --- 5. Message Trigger ---
// Updates message count when a new message is created
export const onMessageCreated = onDocumentCreated(
    { region: REGION, document: "events/{eventId}/messages/{messageId}" },
    async (event) => {
        const eventId = event.params.eventId;
        const messageId = event.params.messageId;

        logger.info(`New message ${messageId} created in event ${eventId}`);

        // Optional: You can add message count tracking here if needed
        // Your schema doesn't have a message count field, so this is just for logging
    }
);

// --- 6. Reject Join Request ---
export const rejectJoinRequest = onCall({ region: REGION }, async (request) => {
    const hostUid = assertAuth(request);
    const { eventId, attendeeId, note } = request.data;

    if (!eventId || !attendeeId) throw new HttpsError("invalid-argument", "Missing params");

    const eventRef = db.collection("events").doc(eventId);
    const joinRequestRef = db.collection("join_requests").doc(`${eventId}_${attendeeId}`);

    const eventSnap = await eventRef.get();
    if (!eventSnap.exists) throw new HttpsError("not-found", "Event not found");

    const eventData = eventSnap.data()!;
    if (eventData.creatorId !== hostUid) {
        throw new HttpsError("permission-denied", "Not event host");
    }

    const updateData: any = {
        status: "rejected",
        respondedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (note) {
        updateData.responseNote = note;
    }

    await joinRequestRef.update(updateData);

    logger.info(`Host ${hostUid} rejected ${attendeeId} for event ${eventId}`);
    return { success: true };
});

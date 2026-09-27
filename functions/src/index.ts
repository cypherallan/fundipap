import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError, onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

initializeApp();
const db = getFirestore();

export const initiateMpesaPayment = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }
    const { phoneNumber, amount, contributionId, groupId } = request.data;
    if (!phoneNumber || !amount) {
        throw new HttpsError("invalid-argument", "Missing phone or amount");
    }
    const checkoutRequestID = "ws_CO_" + Date.now();
    const merchantRequestID = "MERCH_" + Date.now();

    await db.collection("mpesaTransactions").add({
        userId: request.auth.uid,
        contributionId: contributionId || null,
        groupId: groupId || null,
        phoneNumber,
        amount,
        checkoutRequestID,
        merchantRequestID,
        status: "pending",
        simulated: true,
        createdAt: FieldValue.serverTimestamp(),
    });

    return {
        success: true,
        message: "SIMULATED STK Push sent",
        checkoutRequestID,
        merchantRequestID
    };
});

export const mpesaCallback = onRequest(async (req, res) => {
    res.json({ ResultCode: 0, ResultDesc: "Accepted - Simulated" });
});

// AUTO-CANCEL 2h30m - FULL 5350/6400 refund - works even when app closed
export const autoCancelNoArrival = onSchedule('every 5 minutes', async () => {
    const cutoff = new Date(Date.now() - 150 * 60 * 1000);
    const snap = await db.collection('jobs').where('status', '==', 'travelling').get();
    if (snap.empty) return;

    const batch = db.batch();
    let count = 0;

    snap.forEach(doc => {
        const job = doc.data() as any;
        const startedAt = job.siteVisitStartedAt || job.travellingAt;
        if (!startedAt) return;
        const startTime = startedAt.toDate ? startedAt.toDate() : new Date(startedAt);
        if (startTime > cutoff) return;

        const siteDone = job.siteVisitDone === true || job.siteVisited === true || job.fundiArrivedAt != null;
        if (siteDone) return;

        const total = job.escrowAmount || 0;

        batch.update(doc.ref, {
            status: 'auto_cancelled_no_arrival',
            cancelled: true,
            autoCancelled: true,
            cancelledBy: 'system',
            cancelReason: 'Fundi took too long to arrive - 20km rule - Full amount credited back',
            clientRefund: total,
            platformFee: 0,
            fundiPayout: 0,
            escrowStatus: 'refunded',
            autoCancelledAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
        });

        const logRef = db.collection('cancellationLogs').doc();
        batch.set(logRef, {
            jobId: doc.id,
            cancelledBy: 'system',
            reason: 'No arrival within 2h30m',
            clientRefund: total,
            createdAt: FieldValue.serverTimestamp(),
        });
        count++;
    });

    if (count > 0) {
        await batch.commit();
        console.log(`Auto-cancelled ${count} jobs - FULL refund`);
    }
});
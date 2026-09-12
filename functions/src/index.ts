import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

export const initiateMpesaPayment = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Login required");
    }

    const { phoneNumber, amount, contributionId, groupId } = data;

    if (!phoneNumber || !amount) {
        throw new functions.https.HttpsError("invalid-argument", "Missing phone or amount");
    }

    // SIMULATED - no real Mpesa call
    const checkoutRequestID = "ws_CO_" + Date.now();
    const merchantRequestID = "MERCH_" + Date.now();

    await db.collection("mpesaTransactions").add({
        userId: context.auth.uid,
        contributionId: contributionId || null,
        groupId: groupId || null,
        phoneNumber,
        amount,
        checkoutRequestID,
        merchantRequestID,
        status: "pending",
        simulated: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Simulate success after 3 sec
    setTimeout(async () => {
        await db.collection("contributions").doc(contributionId).update({
            status: "paid",
            mpesaCode: "SIM_" + Math.random().toString(36).substring(7).toUpperCase(),
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(() => { });
    }, 3000);

    return {
        success: true,
        message: "SIMULATED STK Push sent",
        checkoutRequestID,
        merchantRequestID
    };
});

export const mpesaCallback = functions.https.onRequest(async (req, res) => {
    res.json({ ResultCode: 0, ResultDesc: "Accepted - Simulated" });
});
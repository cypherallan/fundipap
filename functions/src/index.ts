import * as admin from "firebase-admin";
import { getFirestore, FieldValue, Firestore } from "firebase-admin/firestore";
import { onCall, HttpsError, onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

if (!admin.apps.length) admin.initializeApp();

let _db: Firestore | null = null;
function db() {
    if (!_db) _db = getFirestore();
    return _db;
}

// ============ MPESA ============
export const initiateMpesaPayment = onCall(async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
    const { phoneNumber, amount, contributionId, groupId } = request.data;
    if (!phoneNumber || !amount) throw new HttpsError("invalid-argument", "Missing phone or amount");
    const checkoutRequestID = "ws_CO_" + Date.now();
    const merchantRequestID = "MERCH_" + Date.now();
    await db().collection("mpesaTransactions").add({
        userId: request.auth.uid,
        contributionId: contributionId || null,
        groupId: groupId || null,
        phoneNumber, amount, checkoutRequestID, merchantRequestID,
        status: "pending", simulated: true, createdAt: FieldValue.serverTimestamp(),
    });
    return { success: true, message: "SIMULATED STK Push sent", checkoutRequestID, merchantRequestID };
});

export const mpesaCallback = onRequest(async (req, res) => {
    res.json({ ResultCode: 0, ResultDesc: "Accepted - Simulated" });
});

// ============ AUTO-CANCEL ============
export const autoCancelNoArrival = onSchedule({ schedule: 'every 5 minutes', region: 'us-central1' }, async () => {
    const cutoff = new Date(Date.now() - 150 * 60 * 1000);
    const snap = await db().collection('jobs').where('status', '==', 'travelling').get();
    if (snap.empty) return;
    const batch = db().batch();
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
            status: 'auto_cancelled_no_arrival', cancelled: true, autoCancelled: true,
            cancelledBy: 'system', cancelReason: 'Fundi took too long to arrive - 20km rule',
            clientRefund: total, platformFee: 0, fundiPayout: 0, escrowStatus: 'refunded',
            autoCancelledAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
        });
        count++;
    });
    if (count > 0) await batch.commit();
});

// ============ BADGE SYSTEM ============
type BadgeLevel = "none" | "bronze" | "silver" | "gold";
type FundiLevel = "L1_NEW" | "L2_HUSTLER" | "L3_PRO" | "L4_ELITE";

function calcBadge(user: any) {
    const completedJobs = Number(user.completedJobs ?? user.jobsDone ?? 0);
    const rating = Number(user.rating ?? user.avgRating ?? 0);
    const reviewCount = Number(user.reviewCount ?? user.ratingsCount ?? 0);
    const cancelledJobs = Number(user.cancelledJobs ?? 0);
    const fraudReports = Number(user.fraudReports ?? user.fraudCount ?? 0);
    const hasKyc = !!(user.kycVerified || user.isKycVerified);
    const hasId = !!(user.idUploaded || user.nationalIdUrl);
    const hasGoodConduct = !!(user.goodConductUploaded || user.goodConductUrl);
    const hasTradeCert = !!(user.tradeCertUploaded || user.certificateUrl);
    const hasPhoto = !!(user.photoUrl || user.profilePhotoUrl);
    const hasBio = (user.bio ?? "").toString().length > 20;
    const avgResponseMin = Number(user.avgResponseMinutes ?? 999);
    const avgChatMin = Number(user.avgChatResponseMinutes ?? 999);
    const referrals = Number(user.referralCount ?? 0);

    let score = 0; const b: any = {};
    b.kyc = hasKyc ? 10 : 0; score += b.kyc;
    const profileComplete = hasId && hasGoodConduct && hasTradeCert && hasPhoto && hasBio;
    b.profileComplete = profileComplete ? 10 : 0; score += b.profileComplete;
    let jobsPts = completedJobs >= 100 ? 20 : completedJobs >= 50 ? 15 : completedJobs >= 10 ? 10 : completedJobs >= 1 ? 5 : 0;
    b.jobs = jobsPts; score += jobsPts;
    let ratingPts = 0;
    if (reviewCount >= 3) {
        if (rating >= 4.8) ratingPts = 20; else if (rating >= 4.5) ratingPts = 15;
        else if (rating >= 4.0) ratingPts = 10; else if (rating >= 3.5) ratingPts = 5;
    }
    b.rating = ratingPts; score += ratingPts;
    let cancelPts = cancelledJobs >= 5 ? 0 : cancelledJobs >= 3 ? 3 : cancelledJobs >= 1 ? 6 : 10;
    b.cancellations = cancelPts; score += cancelPts;
    b.fraud = fraudReports > 0 ? 0 : 10; score += b.fraud;
    b.fastResponse = (avgResponseMin <= 5 && avgChatMin <= 10) ? 10 : 0; score += b.fastResponse;
    let referralPts = 0; let referralRate = 0;
    if (completedJobs > 0) {
        referralRate = referrals / completedJobs;
        if (referralRate >= 0.5) referralPts = 10; else if (referralRate >= 0.3) referralPts = 7;
        else if (referralRate >= 0.1) referralPts = 4; else if (referrals > 0) referralPts = 2;
    }
    b.referral = referralPts; score += referralPts;
    const lastActive = user.lastActiveAt?.toDate?.() ?? (user.lastActiveAt ? new Date(user.lastActiveAt) : null);
    let recencyPts = 5;
    if (lastActive) {
        const days = (Date.now() - lastActive.getTime()) / 86400000;
        if (days <= 2) recencyPts = 30; else if (days <= 7) recencyPts = 20; else if (days <= 14) recencyPts = 10;
    }
    b.recency = recencyPts; score += recencyPts;
    score = Math.max(0, Math.min(130, score));

    let badgeLevel: BadgeLevel = score >= 110 ? "gold" : score >= 70 ? "silver" : score >= 35 ? "bronze" : "none";
    let fundiLevel: FundiLevel = completedJobs >= 100 ? "L4_ELITE" : completedJobs >= 50 ? "L3_PRO" : completedJobs >= 10 ? "L2_HUSTLER" : "L1_NEW";

    const createdAt = user.createdAt?.toDate?.() ?? (user.createdAt ? new Date(user.createdAt) : new Date());
    const trialExpDate = new Date(createdAt.getTime() + 7 * 86400000);
    let isTrialGold = false; let trialExpiresAt: any = null; let fundiCommissionPct = 10;
    const isNew = completedJobs < 10;
    if (isNew && Date.now() < trialExpDate.getTime() && profileComplete) {
        isTrialGold = true; trialExpiresAt = trialExpDate; badgeLevel = "gold"; fundiCommissionPct = 10;
    } else {
        fundiCommissionPct = badgeLevel === "gold" ? 5 : badgeLevel === "silver" ? 7 : 10;
    }
    const isVerified = badgeLevel === "gold" && !isTrialGold && hasKyc && profileComplete && completedJobs >= 50 && rating >= 4.5;
    let pointsToNextBadge = badgeLevel === "none" ? 35 - score : badgeLevel === "bronze" ? 70 - score : badgeLevel === "silver" ? 110 - score : 0;
    let jobsToNextLevel = fundiLevel === "L1_NEW" ? 10 - completedJobs : fundiLevel === "L2_HUSTLER" ? 50 - completedJobs : fundiLevel === "L3_PRO" ? 100 - completedJobs : 0;

    return { score, badgeLevel, fundiLevel, fundiCommissionPct, clientCommissionPct: 5, referralRate, isTrialGold, trialExpiresAt, isVerified, pointsToNextBadge: Math.max(0, pointsToNextBadge), jobsToNextLevel: Math.max(0, jobsToNextLevel), breakdown: b };
}

async function updateFundiBadge(uid: string, data: any) {
    const r = calcBadge(data);
    await db().collection("users").doc(uid).set({
        badgeScore: r.score, badgeLevel: r.badgeLevel, fundiLevel: r.fundiLevel,
        fundiCommissionPct: r.fundiCommissionPct, clientCommissionPct: r.clientCommissionPct,
        referralRate: r.referralRate, isTrialGold: r.isTrialGold, trialExpiresAt: r.trialExpiresAt,
        isVerified: r.isVerified, pointsToNextBadge: r.pointsToNextBadge, jobsToNextLevel: r.jobsToNextLevel,
        badgeBreakdown: r.breakdown, badgeUpdatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
}

export const recalcBadgesNightly = onSchedule({ schedule: "0 23 * * *", timeZone: "UTC", region: "us-central1" }, async () => {
    const snap = await db().collection("users").where("role", "==", "fundi").limit(500).get();
    for (const doc of snap.docs) await updateFundiBadge(doc.id, doc.data());
});

export const recalcBadgeOnUserWrite = onDocumentWritten({ document: "users/{uid}", region: "us-central1" }, async (event) => {
    const after = event.data?.after?.data() as any; if (!after || after.role !== "fundi") return;
    await updateFundiBadge(event.params.uid, after);
});

export const recalcBadgeOnJobComplete = onDocumentWritten({ document: "jobs/{jobId}", region: "us-central1" }, async (event) => {
    const after = event.data?.after?.data() as any; if (!after) return;
    if (after.status !== "completed" && after.escrowStatus !== "released") return;
    const fundiId = after.assignedFundiId ?? after.fundiId; if (!fundiId) return;
    const fd = await db().collection("users").doc(fundiId).get(); if (!fd.exists) return;
    await updateFundiBadge(fundiId, fd.data());
});
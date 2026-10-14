import * as admin from "firebase-admin";
import { getFirestore, FieldValue, Firestore } from "firebase-admin/firestore";
import { onCall, HttpsError, onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentWritten, onDocumentCreated } from "firebase-functions/v2/firestore";

if (!admin.apps.length) admin.initializeApp();

let _db: Firestore | null = null;
function db() {
    if (!_db) _db = getFirestore();
    return _db;
}

// ============ YOUR EXISTING MPESA - UNTOUCHED ============
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

// ============ YOUR EXISTING AUTO-CANCEL - UNTOUCHED ============
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

// ============ YOUR EXISTING BADGE SYSTEM - UNTOUCHED ============
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

// ============ NEW: REAL PUSH NOTIFICATIONS - ONLY ADDITION ============
async function getFcmTokens(uid: string): Promise<string[]> {
    if (!uid) return [];
    const [uSnap, fSnap] = await Promise.all([
        db().collection("users").doc(uid).get(),
        db().collection("fundis").doc(uid).get(),
    ]);
    const set = new Set<string>();
    for (const snap of [uSnap, fSnap]) {
        const d = snap.data() as any; if (!d) continue;
        if (d.fcmToken) set.add(d.fcmToken);
        if (d.pushToken) set.add(d.pushToken);
        if (Array.isArray(d.fcmTokens)) d.fcmTokens.forEach((t: string) => { if (t) set.add(t); });
    }
    return [...set];
}

async function sendPush(tokens: string[], title: string, body: string, data: any) {
    if (!tokens.length) return;
    try {
        await admin.messaging().sendEachForMulticast({
            tokens,
            notification: { title, body },
            data: { click_action: "FLUTTER_NOTIFICATION_CLICK", ...Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])) },
            android: { priority: "high", notification: { channelId: "jobs", priority: "high", visibility: "public" } },
            apns: { payload: { aps: { sound: "default", badge: 1 } } },
        });
    } catch (e) { console.log("push error", e); }
}

function distKm(lat1: number, lon1: number, lat2: number, lon2: number) {
    const R = 6371; const dLat = (lat2 - lat1) * Math.PI / 180; const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export const notifyNearbyFundisOnJobCreate = onDocumentCreated({ document: "jobs/{jobId}", region: "us-central1" }, async (event) => {
    const job = event.data?.data() as any;
    if (!job) return;
    const jobId = event.params.jobId;
    const lat = job.location?.latitude || job.geopoint?.latitude || job.lat || job.latitude;
    const lng = job.location?.longitude || job.geopoint?.longitude || job.lng || job.longitude;
    if (!lat || !lng) {
        console.log(`JOB ${jobId} NO LOCATION`);
        return;
    }

    // Only online fundis
    const snap = await db().collection("fundis").where("isOnline", "==", true).get();
    console.log(`NEW JOB ${jobId} at ${lat},${lng} - ${snap.size} online fundis found`);

    for (const doc of snap.docs) {
        const uid = doc.id;
        const fData = doc.data() as any;
        const fLat = fData.geopoint?.latitude || fData.location?.latitude || fData.lat;
        const fLng = fData.geopoint?.longitude || fData.location?.longitude || fData.lng;
        if (!fLat || !fLng) continue;

        const d = distKm(lat, lng, fLat, fLng);

        // Get badge from users collection
        const userSnap = await db().collection("users").doc(uid).get();
        const userData = userSnap.data() as any;
        const badgeLevel = (userData?.badgeLevel || "none").toString().toLowerCase();

        const maxDist = badgeLevel === "gold" ? 100 : badgeLevel === "silver" ? 50 : badgeLevel === "bronze" ? 20 : 10;

        console.log(`Fundi ${uid} badge=${badgeLevel} dist=${d.toFixed(1)}km max=${maxDist}km`);

        if (d <= maxDist) {
            const tokens = await getFcmTokens(uid);
            if (tokens.length === 0) {
                console.log(`Fundi ${uid} NO TOKENS`);
                continue;
            }
            await sendPush(tokens, "New job near you", `${job.title || 'Job'} • KES ${job.budget || ''} • ${d.toFixed(1)}km • ${badgeLevel}`, { jobId, type: "new_job", badgeLevel, distance: d.toFixed(1) });
        }
    }
});

// BIDS = covers your FundiNotificationsPage + CustomerNotificationsSection
export const onBidPush = onDocumentWritten({ document: "jobs/{jobId}/bids/{bidId}", region: "us-central1" }, async (event) => {
    const before = event.data?.before?.data() as any; const after = event.data?.after?.data() as any;
    if (!after) return;
    const jobId = event.params.jobId;
    const fundiId = after.fundiId; const clientId = after.customerId || after.clientId || after.customerId;
    const oldS = (before?.status || "").toString(); const newS = (after?.status || "").toString();
    const lastBy = (after.lastCounterBy || after.counterBy || "").toString();

    if (!before) {
        const tokens = await getFcmTokens(clientId);
        await sendPush(tokens, "New bid received", `${after.fundiName || 'Fundi'} bid KES ${after.amount || after.bidAmount || after.price || ''} • ${after.jobTitle || ''}`, { jobId, type: "bid" });
        return;
    }
    if ((newS === "countered" || newS === "client_counter" || newS === "countered_by_client" || newS === "countered_by_client") && lastBy !== fundiId && oldS !== newS) {
        const tokens = await getFcmTokens(fundiId);
        await sendPush(tokens, `Client countered KES ${after.clientCounterAmount || after.lastCounterAmount || 0}`, `${after.jobTitle || 'Job'} • Tap to Accept/Counter`, { jobId, type: "client_counter" });
    }
    if (newS === "countered" && lastBy === fundiId && oldS !== newS) {
        const tokens = await getFcmTokens(clientId);
        await sendPush(tokens, `Fundi countered KES ${after.lastCounterAmount || 0}`, `${after.jobTitle || 'Job'} • Tap to view`, { jobId, type: "fundi_counter" });
    }
    if (newS === "accepted" && oldS !== "accepted") {
        const tokens = await getFcmTokens(fundiId);
        await sendPush(tokens, "Bid Accepted!", `${after.jobTitle || 'Job'} accepted`, { jobId, type: "accepted" });
    }
    if (newS.includes("counter_accepted_by_fundi") && !oldS.includes("counter_accepted_by_fundi")) {
        const tokens = await getFcmTokens(clientId);
        await sendPush(tokens, `Your counter offer of KES ${after.agreedPrice || after.clientCounterAmount || ''} has been accepted`, `${after.fundiName || 'Fundi'} accepted • Tap to proceed`, { jobId, type: "counter_accepted_by_fundi" });
    }
});

// JOB STATUS = covers HomeStatusWidget + getFundiWaitingState (all orange cards)
export const onJobPush = onDocumentWritten({ document: "jobs/{jobId}", region: "us-central1" }, async (event) => {
    const before = event.data?.before?.data() as any; const after = event.data?.after?.data() as any;
    if (!after) return;
    const jobId = event.params.jobId;
    const fundiId = after.assignedFundiId || after.fundiId; const clientId = after.customerId || after.clientId;
    const oldS = (before?.status || "").toLowerCase(); const newS = (after?.status || "").toLowerCase();
    if (oldS === newS && (before?.escrowStatus === after?.escrowStatus) && (before?.renegotiation?.status === after?.renegotiation?.status)) return;
    const fundiTokens = await getFcmTokens(fundiId); const clientTokens = await getFcmTokens(clientId);
    const title = after.title || 'Job';

    if ((newS === "assigned" || newS === "confirmed") && oldS !== newS) {
        await sendPush(clientTokens, `Escrow locked KES ${after.escrowAmount || ''} • Waiting for fundi`, `${title} • ${after.assignedFundiName || 'Fundi'} has NOT started travelling`, { jobId, type: newS });
        await sendPush(fundiTokens, `Escrow locked KES ${after.escrowAmount || ''} - Start site visit now`, `${title} • Tap to travel`, { jobId, type: "escrow_locked" });
    }
    if ((newS === "travelling" || newS === "on_the_way") && oldS !== newS) {
        await sendPush(clientTokens, "Fundi is on the way", `${after.assignedFundiName || 'Fundi'} is travelling • Tracking live`, { jobId, type: "travelling" });
        await sendPush(fundiTokens, "You are on the way", `${title} • Travelling to client`, { jobId, type: "travelling" });
    }
    if ((newS.includes("site_visit") || newS === "site_visited") && !oldS.includes("site_visit")) {
        await sendPush(fundiTokens, `Waiting for you to start work KES ${after.agreedPrice || ''}`, `${title} • Tap START JOB`, { jobId, type: "site_visited" });
        await sendPush(clientTokens, "Fundi arrived on site", `${after.assignedFundiName || 'Fundi'} • Waiting to start work`, { jobId, type: "site_visited" });
    }
    if ((newS === "in_progress" || newS === "fundi_working") && oldS !== newS) {
        await sendPush(clientTokens, "Fundi is working", `${title} in progress`, { jobId, type: "working" });
    }
    if ((newS === "pending_completion" || newS === "job_completed") && oldS !== newS) {
        await sendPush(clientTokens, `Job Completed - Confirm & release KES ${after.totalClientPays || after.escrowAmount || ''}`, `${title} • Tap to confirm`, { jobId, type: "job_completed" });
        await sendPush(fundiTokens, "Job Completed - Waiting for client", `${title} • Waiting for client to confirm`, { jobId, type: "job_completed" });
    }
    if (newS.includes("awaiting_extra") && !oldS.includes("awaiting_extra")) {
        const extra = after.renegotiation?.extraToLock || after.extraToLock || after.extraTopupToLock || 0;
        await sendPush(clientTokens, `Lock extra KES ${extra} in escrow`, `${title} • Fundi accepted`, { jobId, type: "awaiting_extra_escrow" });
        await sendPush(fundiTokens, `Waiting for client to lock extra KES ${extra}`, `${title}`, { jobId, type: "awaiting_extra_escrow" });
    }
    if (newS.includes("waiting_for_client_to_buy_parts") && !oldS.includes("waiting_for_client_to_buy_parts")) {
        await sendPush(clientTokens, "You will buy parts - Confirm when bought", `${title}`, { jobId, type: "waiting_for_client_to_buy_parts" });
    }
    if (after.renegotiation?.status === "pending" && before?.renegotiation?.status !== "pending") {
        await sendPush(clientTokens, "Fundi requests price review", `${after.renegotiation.reasonDetails || 'New breakdown'} • Tap to REVIEW`, { jobId, type: "price_review" });
    }
    if (after.renegotiation?.status === "countered_by_client" && before?.renegotiation?.status !== "countered_by_client") {
        await sendPush(fundiTokens, `Client countered extra KES ${after.renegotiation.counterExtraLabor || 0}`, `${title} • Tap to view`, { jobId, type: "reneg_countered" });
    }
    if (newS === "completed" || after.escrowStatus === "released") {
        if (oldS !== "completed" && before?.escrowStatus !== "released") {
            await sendPush(fundiTokens, `Client released KES ${after.totalReleasedAmount || after.escrowAmount || ''}`, `${title} • Payment released`, { jobId, type: "released" });
        }
    }
});
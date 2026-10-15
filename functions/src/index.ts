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
export const autoCancelNoArrival = onSchedule({ schedule: 'every 5 minutes', region: 'europe-west1' }, async () => {
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
    const fraudReports = Number(user.fraudReports ?? 0);
    const hasKyc = !!(user.kycVerified || user.isKycVerified);
    const hasId = !!(user.idUploaded || user.nationalIdUrl);
    const hasGoodConduct = !!(user.goodConductUploaded || user.goodConductUrl);
    const hasTradeCert = !!(user.tradeCertUploaded || user.certificateUrl);
    const hasPhoto = !!(user.photoUrl || user.profilePhotoUrl);
    const hasBio = (user.bio ?? "").toString().length > 20;
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
    b.cancellations = cancelledJobs >= 5 ? 0 : cancelledJobs >= 3 ? 3 : cancelledJobs >= 1 ? 6 : 10; score += b.cancellations;
    b.fraud = fraudReports > 0 ? 0 : 10; score += b.fraud;
    b.fastResponse = 0;
    b.referral = referrals > 0 ? 2 : 0; score += b.referral;
    b.recency = 5; score += 5;

    score = Math.max(0, Math.min(130, score));
    let badgeLevel: BadgeLevel = score >= 110 ? "gold" : score >= 70 ? "silver" : score >= 35 ? "bronze" : "none";
    let fundiLevel: FundiLevel = completedJobs >= 100 ? "L4_ELITE" : completedJobs >= 50 ? "L3_PRO" : completedJobs >= 10 ? "L2_HUSTLER" : "L1_NEW";

    const createdAt = user.createdAt?.toDate?.() ?? (user.createdAt ? new Date(user.createdAt) : new Date());
    const trialExpDate = new Date(createdAt.getTime() + 7 * 86400000);
    let isTrialGold = false; let trialExpiresAt: any = null;
    const isNew = completedJobs < 10;
    const withinTrial = Date.now() < trialExpDate.getTime();

    // NEW RULE: every new fundi gets trial gold for 7 days
    if (isNew && withinTrial) {
        isTrialGold = true; trialExpiresAt = trialExpDate; badgeLevel = "gold";
    }

    let fundiCommissionPct = badgeLevel === "gold" ? 5 : badgeLevel === "silver" ? 7 : 10;
    if (isTrialGold) fundiCommissionPct = 5; // trial gold pays 5% too

    return {
        score, badgeLevel, fundiLevel, fundiCommissionPct, clientCommissionPct: 5,
        referralRate: 0, isTrialGold, trialExpiresAt,
        isVerified: badgeLevel === "gold" && !isTrialGold && hasKyc,
        pointsToNextBadge: 0, jobsToNextLevel: Math.max(0, 10 - completedJobs),
        breakdown: b
    };
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

export const recalcBadgesNightly = onSchedule({ schedule: "0 23 * * *", timeZone: "UTC", region: "europe-west1" }, async () => {
    const snap = await db().collection("users").where("role", "==", "fundi").limit(500).get();
    for (const doc of snap.docs) await updateFundiBadge(doc.id, doc.data());
});

export const recalcBadgeOnUserWrite = onDocumentWritten({ document: "users/{uid}", region: "europe-west1" }, async (event) => {
    const after = event.data?.after?.data() as any; if (!after || after.role !== "fundi") return;
    await updateFundiBadge(event.params.uid, after);
});

export const recalcBadgeOnJobComplete = onDocumentWritten({ document: "jobs/{jobId}", region: "europe-west1" }, async (event) => {
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

export const notifyNearbyFundisOnJobCreate = onDocumentCreated({ document: "jobs/{jobId}", region: "europe-west1" }, async (event) => {
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
        let badgeLevel = (fData.badgeLevel || "").toLowerCase();
        if (!badgeLevel) {
            const userSnap = await db().collection("users").doc(uid).get();
            badgeLevel = (userSnap.data() as any)?.badgeLevel?.toLowerCase() || "gold"; // fallback gold for new
        }
        const maxDist = badgeLevel === "gold" ? 100 : badgeLevel === "silver" ? 50 : badgeLevel === "bronze" ? 20 : 100;

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

export const onNotificationPush = onDocumentCreated({ document: "notifications/{notifId}", region: "europe-west1" }, async (event) => {
    const d = event.data?.data() as any;
    if (!d) return;
    const toUserId = d.toUserId as string;
    if (!toUserId) return;

    const tokens = await getFcmTokens(toUserId);
    if (tokens.length === 0) {
        console.log(`NO TOKENS for ${toUserId} type ${d.type}`);
        return;
    }

    await sendPush(tokens, d.title || "Fundipap", d.body || "", {
        jobId: d.jobId || "",
        type: d.type || "bid_sent"
    });
    console.log(`PUSH SENT to ${toUserId}: ${d.title} | type=${d.type}`);
});

// BIDS = covers your FundiNotificationsPage + CustomerNotificationsSection
export const onBidPush = onDocumentWritten({ document: "jobs/{jobId}/bids/{bidId}", region: "europe-west1" }, async (event) => {
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
export const onJobPush = onDocumentWritten({ document: "jobs/{jobId}", region: "europe-west1" }, async (event) => {
    const before = event.data?.before?.data() as any;
    const after = event.data?.after?.data() as any;
    if (!after) return;
    const jobId = event.params.jobId;
    const fundiId = after.assignedFundiId || after.fundiId || (after as any).acceptedFundiId || (after as any).fundiId;
    const clientId = after.customerId || after.clientId;
    const oldS = (before?.status || "").toLowerCase();
    const newS = (after?.status || "").toLowerCase();
    const title = after.title || 'Job';

    const newEscHeld = after.escrowHeld === true;
    const oldEscHeld = before?.escrowHeld === true;
    const newEscStatus = (after?.escrowStatus || "").toLowerCase();
    const oldEscStatus = (before?.escrowStatus || "").toLowerCase();

    const fundiTokens = await getFcmTokens(fundiId);
    const clientTokens = await getFcmTokens(clientId);

    // === LEAK-FREE CALC - single source of truth ===
    const agreed = Number(after.agreedPrice || after.clientCounterAmount || after.lastCounterAmount || after.laborCost || 0);
    const transport = Number(after.transportFee || 0);
    const fundiSees = agreed + transport; // what fundi should see - NO client fee
    const fundiFee = Number((after as any).fundiAppFee || 0) || Math.round(agreed * 0.05);
    const fundiReceives = fundiSees - fundiFee;
    const clientPays = Number((after as any).totalClientPays || after.escrowAmount || after.totalCost || (fundiSees + Math.round(fundiSees * 0.05)));

    console.log(`DEBUG ${jobId} ${oldS}->${newS} escrow ${oldEscStatus}->${newEscStatus} agreed ${agreed} transport ${transport} fundiSees ${fundiSees} fundiReceives ${fundiReceives} clientPays ${clientPays}`);

    // PRIORITY 1: ESCROW LOCKED
    if ((newEscHeld && !oldEscHeld) || (newEscStatus === "held" && oldEscStatus !== "held")) {
        const extraRaw = (after as any).renegotiation?.extraToLock || (after as any).extraToLock || (after as any).extraTopupToLock || 0;
        const extra = Number(extraRaw);
        const beforeStatus = (before?.status || "").toLowerCase();
        const isExtraLock = extra > 0 || beforeStatus.includes("awaiting_extra") || beforeStatus.includes("in_progress") || beforeStatus.includes("site_visit");

        if (isExtraLock) {
            const extraClientPays = extra + Math.round(extra * 0.05); // client sees extra + fee
            await sendPush(fundiTokens, `Extra KES ${extra} locked - Continue job`, `${title} • Resume work`, { jobId, type: "extra_escrow_locked" });
            await sendPush(clientTokens, `Extra KES ${extraClientPays} locked • Fundi resuming`, `${title} • Continue job`, { jobId, type: "extra_escrow_locked" });
        } else {
            await sendPush(fundiTokens, `Escrow locked KES ${fundiSees} - Start site visit now`, `${title} • Tap to travel`, { jobId, type: "escrow_locked" });
            await sendPush(clientTokens, `Escrow locked KES ${clientPays} • Waiting for fundi`, `${title} • ${after.assignedFundiName || 'Fundi'} has NOT started travelling`, { jobId, type: "escrow_locked" });
        }
        return;
    }

    if ((newS === "assigned" || newS === "confirmed") && oldS !== newS && !newEscHeld && newEscStatus !== "held") {
        await sendPush(fundiTokens, "Bid Accepted!", `${title} accepted • Waiting for client to lock escrow KES ${fundiSees}`, { jobId, type: "accepted_waiting_escrow" });
        await sendPush(clientTokens, `Fundi accepted • Lock KES ${clientPays} to start`, `${title} • Tap to pay escrow`, { jobId, type: "lock_escrow" });
    }
    if ((newS === "travelling" || newS === "on_the_way") && oldS !== newS) {
        await sendPush(clientTokens, "Fundi is on the way", `${after.assignedFundiName || 'Fundi'} is travelling • Tracking live`, { jobId, type: "travelling" });
    }
    if ((newS.includes("site_visit") || newS === "site_visited") && !oldS.includes("site_visit")) {
        await sendPush(fundiTokens, `Waiting for you to start work KES ${fundiSees}`, `${title} • Tap START JOB`, { jobId, type: "site_visited" });
        await sendPush(clientTokens, "Fundi arrived on site", `${after.assignedFundiName || 'Fundi'} • Waiting to start work`, { jobId, type: "site_visited" });
    }
    if ((newS === "in_progress" || newS === "fundi_working") && oldS !== newS) {
        await sendPush(clientTokens, "Fundi is working", `${title} in progress`, { jobId, type: "working" });
    }
    if ((newS === "pending_completion" || newS === "job_completed") && oldS !== newS) {
        await sendPush(clientTokens, `Job Completed - Confirm & release KES ${clientPays}`, `${title} • Tap to confirm`, { jobId, type: "job_completed" });
        await sendPush(fundiTokens, "Job Completed - Waiting for client", `${title} • Waiting for client to confirm`, { jobId, type: "job_completed" });
    }
    if (newS.includes("awaiting_extra") && !oldS.includes("awaiting_extra")) {
        const extraRaw = after.renegotiation?.extraToLock || after.extraToLock || after.extraTopupToLock || 0;
        const extra = Number(extraRaw);
        const extraClientPays = extra + Math.round(extra * 0.05);
        await sendPush(clientTokens, `Lock extra KES ${extraClientPays} in escrow`, `${title} • Fundi accepted`, { jobId, type: "awaiting_extra_escrow" });
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

    const wasReleased = oldEscStatus === "released" || before?.escrowReleased === true || before?.escrowStatus === "released";
    const nowReleased = newEscStatus === "released" || after?.escrowReleased === true || after?.escrowStatus === "released";
    if (!wasReleased && nowReleased) {
        console.log(`RELEASE ${jobId}: clientPays ${clientPays} fundiReceives ${fundiReceives}`);
        await sendPush(fundiTokens, `Client released KES ${fundiReceives}`, `${title} • Tap to view receipt`, { jobId, type: "released", clientPays, fundiReceives });
        await sendPush(clientTokens, `You released KES ${clientPays} • Completed`, `${title}`, { jobId, type: "released" });
    }
});
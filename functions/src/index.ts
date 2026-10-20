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
    const trialExpDate = new Date(createdAt.getTime() + 14 * 86400000);
    let isTrialGold = false;
    let trialExpiresAt: any = null;
    const isNew = completedJobs < 10;
    const withinTrial = Date.now() < trialExpDate.getTime();
    if (isNew && withinTrial) {
        isTrialGold = true;
        trialExpiresAt = trialExpDate;
    }

    let fundiCommissionPct = isTrialGold ? 5 : badgeLevel === "gold" ? 5 : badgeLevel === "silver" ? 8 : badgeLevel === "bronze" ? 10 : 15;
    let clientCommissionPct = 5;

    return {
        score,
        badgeLevel,
        fundiLevel,
        fundiCommissionPct,
        clientCommissionPct,
        referralRate: 0,
        isTrialGold,
        trialExpiresAt,
        isVerified: badgeLevel === "gold" && !isTrialGold && hasKyc,
        pointsToNextBadge: 0,
        jobsToNextLevel: Math.max(0, 10 - completedJobs),
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
    const lat = job.location?.latitude || job.geopoint?.latitude || job.lat || job.latitude || job.locationLat;
    const lng = job.location?.longitude || job.geopoint?.longitude || job.lng || job.longitude || job.locationLng;
    if (!lat || !lng) return;

    const snap = await db().collection("fundis").where("isOnline", "==", true).get();

    for (const doc of snap.docs) {
        const uid = doc.id;
        const fData = doc.data() as any;
        const fLat = fData.geopoint?.latitude || fData.location?.latitude || fData.locationLat;
        const fLng = fData.geopoint?.longitude || fData.location?.longitude || fData.locationLng;
        if (!fLat || !fLng) continue;

        const d = distKm(lat, lng, fLat, fLng);

        let badgeLevel = (fData.badgeLevel || fData.badge || "").toLowerCase();
        if (!badgeLevel) {
            const userSnap = await db().collection("users").doc(uid).get();
            badgeLevel = ((userSnap.data() as any)?.badgeLevel || "new").toLowerCase();
        }
        const maxDist = badgeLevel === "gold" ? 100 : badgeLevel === "silver" ? 50 : badgeLevel === "bronze" ? 20 : 15;

        if (d <= maxDist) {
            const tokens = await getFcmTokens(uid);
            if (tokens.length === 0) continue;

            await sendPush(
                tokens,
                "A new job posted",
                `${d.toFixed(1)}km away • Tap to view`,
                { jobId, type: "new_job" }
            );
        }
    }
});

export const onNotificationPush = onDocumentCreated({ document: "notifications/{notifId}", region: "europe-west1" }, async (event) => {
    const d = event.data?.data() as any;
    if (!d) return;
    const toUserId = d.toUserId as string;
    if (!toUserId) return;
    if ((d.title || '').toLowerCase().includes('counter offer received')) return; // <-- ADD THIS LINE HERE

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
// FUNDI PUSHES BELOW ARE LOCKED AS YOU COMMITTED - DO NOT TOUCH
export const onBidPush = onDocumentWritten({ document: "jobs/{jobId}/bids/{bidId}", region: "europe-west1" }, async (event) => {
    const before = event.data?.before?.data() as any;
    const after = event.data?.after?.data() as any;
    if (!after) return;
    const jobId = event.params.jobId;
    const fundiId = after.fundiId;
    const oldS = (before?.status || "").toString();
    const newS = (after?.status || "").toString();
    const lastBy = (after.lastCounterBy || after.counterBy || "").toString();

    // CLIENT FIX: fallback to job doc for clientId
    const jobSnap = await db().collection("jobs").doc(jobId).get();
    const jobData = jobSnap.data() as any;
    const clientId = after.customerId || after.clientId || jobData?.customerId || jobData?.clientId;
    const transport = Number(jobData?.transportFee ?? jobData?.transport ?? 0);
    const jobTitle = after.jobTitle || jobData?.title || 'Job';

    // CLIENT: New bid
    if (!before) {
        const tokens = await getFcmTokens(clientId);
        await sendPush(tokens, "New bid received", `${after.fundiName || 'Fundi'} bid KES ${after.amount || ''} • ${jobTitle}`, { jobId, type: "bid" });
        await db().collection('notifications').add({
            toUserId: clientId,
            title: `New bid KES ${after.amount}`,
            body: `${after.fundiName || 'Fundi'} placed a bid for ${jobTitle}`,
            type: 'bid',
            jobId,
            createdAt: FieldValue.serverTimestamp(),
            isRead: false
        });
        return;
    }

    // FUNDI FLOW - LOCKED
    if ((newS === "countered" || newS === "client_counter") && lastBy !== fundiId && (oldS !== newS || before?.lastCounterAmount !== after?.lastCounterAmount)) {
        const tokens = await getFcmTokens(fundiId);
        await sendPush(tokens, `Client countered KES ${after.clientCounterAmount || after.lastCounterAmount || 0}`, `Tap to Accept/Counter`, { jobId, type: "client_counter" });
    }

    // CLIENT: Fundi countered
    if (newS === "countered" && lastBy === fundiId && (oldS !== newS || before?.lastCounterAmount !== after?.lastCounterAmount)) {
        const tokens = await getFcmTokens(clientId);
        await sendPush(tokens, `Fundi countered KES ${after.lastCounterAmount || 0}`, `${jobTitle} • Tap to view`, { jobId, type: "fundi_counter" });
        await db().collection('notifications').add({
            toUserId: clientId,
            title: `Counter offer received`,
            body: `Fundi countered KES ${after.lastCounterAmount} for ${jobTitle}`,
            type: 'fundi_counter',
            jobId,
            createdAt: FieldValue.serverTimestamp(),
            isRead: false
        });
    }

    // FUNDI FLOW - LOCKED
    if (newS === "accepted" && oldS !== "accepted") {
        const tokens = await getFcmTokens(fundiId);
        const agreed = after.agreedPrice || after.amount || after.bidAmount || 0;
        const escrowLock = Number(agreed) + Number(transport);
        await sendPush(tokens, "Bid accepted", `Bid accepted. Waiting for client to lock escrow KES ${escrowLock} • Tap to view`, { jobId, type: "accepted", escrow: escrowLock.toString() });
    }

    // FUNDI FLOW - LOCKED
    if (newS === "rejected" && oldS !== "rejected") {
        const tokens = await getFcmTokens(fundiId);
        const rejectedAmount = after.amount || after.bidAmount || after.price || 0;
        await sendPush(tokens, "Bid rejected", `Your bid of KES ${rejectedAmount} for ${jobTitle} was rejected`, { jobId, type: "rejected", amount: rejectedAmount.toString() });
    }

    // CLIENT: Fundi accepted client counter
    if (newS.includes("counter_accepted_by_fundi") && !oldS.includes("counter_accepted_by_fundi")) {
        const tokens = await getFcmTokens(clientId);
        await sendPush(tokens, `Your counter offer of KES ${after.agreedPrice || ''} has been accepted`, `${after.fundiName || 'Fundi'} accepted • Tap to proceed`, { jobId, type: "counter_accepted_by_fundi" });
        await db().collection('notifications').add({
            toUserId: clientId,
            title: `Counter accepted`,
            body: `${after.fundiName || 'Fundi'} accepted your counter KES ${after.agreedPrice} for ${jobTitle}`,
            type: 'counter_accepted_by_fundi',
            jobId,
            createdAt: FieldValue.serverTimestamp(),
            isRead: false
        });
    }

    // CLIENT: Fundi withdrew
    if ((newS === 'withdrawn' || newS.includes('cancel')) && !oldS.includes('cancel') && oldS !== 'withdrawn') {
        const tokens = await getFcmTokens(clientId);
        await sendPush(tokens, `Fundi withdrew bid • ${jobTitle}`, `${after.cancelReason || 'Fundi withdrew'}`, { jobId, type: "bid_withdrawn" });
        await db().collection('notifications').add({
            toUserId: clientId,
            title: `Fundi withdrew bid`,
            body: `${jobTitle} • ${after.cancelReason || ''}`,
            type: 'bid_withdrawn',
            jobId,
            createdAt: FieldValue.serverTimestamp(),
            isRead: false
        });
    }
});

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

    // CANCEL - FUNDI FLOW LOCKED
    if (newS.includes('cancel') && !oldS.includes('cancel')) {
        const jobTitle = title;
        const reason = (after.cancelReason || after.fundiCancelReason || '').toString();
        const by = (after.cancelledBy || '').toString().toLowerCase();
        const payout = Number(after.fundiPayout || after.transportReleasedAmount || 0);
        const transportReleased = after.transportReleased === true || payout > 0;
        const isAfterArrival = newS.includes('cancelled_after_arrival');

        if (by === 'fundi') {
            await sendPush(clientTokens, `Fundi cancelled • ${jobTitle}`, reason || 'Fundi cancelled this job • Find another fundi', { jobId, type: "job_cancelled" });
            // CLIENT HOME MIRROR
            await db().collection('notifications').add({ toUserId: clientId, title: `Fundi cancelled • ${jobTitle}`, body: reason || 'Fundi cancelled', type: 'job_cancelled', jobId, createdAt: FieldValue.serverTimestamp(), isRead: false });
        } else if (by === 'client') {
            if (fundiId) {
                await sendPush(fundiTokens, `Client cancelled • ${jobTitle}`, reason || 'Client cancelled', { jobId, type: "job_cancelled" });
                if (isAfterArrival && transportReleased && payout > 0) {
                    await sendPush(fundiTokens, `Transport KES ${payout} released`, `Transport (KES ${payout}) has been released to you - client cancelled after you started travelling for ${jobTitle}`, { jobId, type: "transport_released", amount: payout.toString() });
                }
            }
        } else if (by === 'system') {
            await sendPush(clientTokens, `Job auto-cancelled • Refund KES ${after.clientRefund || 0}`, jobTitle, { jobId, type: "job_cancelled" });
            await db().collection('notifications').add({ toUserId: clientId, title: `Job auto-cancelled`, body: `Refund KES ${after.clientRefund || 0} • ${jobTitle}`, type: 'job_cancelled', jobId, createdAt: FieldValue.serverTimestamp(), isRead: false });
            if (fundiId) await sendPush(fundiTokens, `Job auto-cancelled`, jobTitle, { jobId, type: "job_cancelled" });
        }
        return;
    }

    const transport = Number(after.transportFee ?? after.transport ?? 0);
    const r = after.renegotiation || {};
    const originalExtra = Number(r.extraLabor ?? r.extra ?? after.extraLabor ?? 0);
    const counterExtra = r.counterExtraLabor ?? r.clientCounterExtraLabor ?? null;
    const agreedExtra = r.agreedExtraLabor ?? r.finalExtraLabor ?? r.acceptedCounterExtraLabor ?? null;
    let finalExtra = 0;
    if (agreedExtra != null) finalExtra = Number(agreedExtra);
    else if (counterExtra != null) finalExtra = Number(counterExtra);
    else finalExtra = originalExtra;

    const oldLaborFromRenego = Number((r as any).oldLabor ?? (r as any).oldLabour ?? 0);
    let baseLabor = 0;
    if (oldLaborFromRenego > 0) baseLabor = oldLaborFromRenego;
    else baseLabor = Number(after.laborCost ?? after.originalLaborCost ?? 0) || (Number(after.agreedPrice || 0) - originalExtra) || Number(after.agreedPrice || after.clientCounterAmount || after.lastCounterAmount || 0);
    const totalLabor = oldLaborFromRenego > 0 ? baseLabor + finalExtra : (baseLabor >= 6000 + finalExtra && finalExtra > 0 ? baseLabor : baseLabor + finalExtra);
    const fundiSees = baseLabor + transport;

    const fundiSnap = await db().collection("users").doc(fundiId).get();
    const u = fundiSnap.data() as any || {};
    let fundiPct = Number(u.fundiCommissionPct ?? 5);
    if (u.isTrialGold) fundiPct = 5; else if (u.badgeLevel === "gold") fundiPct = 5; else if (u.badgeLevel === "silver") fundiPct = 8; else if (u.badgeLevel === "bronze") fundiPct = 10; else if (u.badgeLevel === "none") fundiPct = 15; else fundiPct = 5;
    const fundiFee = Math.round(totalLabor * fundiPct / 100);
    const clientFee = Math.round(totalLabor * 0.05);
    const fundiReceives = totalLabor - fundiFee + transport;
    const clientPays = totalLabor + transport + clientFee;

    function getExtraNumbers(jobData: any) {
        const renego = jobData.renegotiation || {};
        const originalLabor = Number(renego.extraLabor ?? renego.extra ?? jobData.extraLabor ?? 0);
        const counterLabor = renego.counterExtraLabor ?? renego.clientCounterExtraLabor ?? null;
        const agreedLabor = renego.agreedExtraLabor ?? renego.finalExtraLabor ?? null;
        let extraLabor = 0;
        if (agreedLabor != null) extraLabor = Number(agreedLabor); else if (counterLabor != null) extraLabor = Number(counterLabor); else extraLabor = originalLabor;
        const originalToLock = Number(renego.extraToLock ?? jobData.extraToLock ?? jobData.extraTopupToLock ?? 0);
        const counterToLock = renego.counterExtraToLock ?? renego.clientCounterExtraToLock ?? null;
        const agreedToLock = renego.agreedExtraToLock ?? null;
        let extraToLock = 0;
        if (agreedToLock != null) extraToLock = Number(agreedToLock); else if (counterToLock != null) extraToLock = Number(counterToLock); else if (originalToLock) extraToLock = Number(originalToLock); else extraToLock = extraLabor + Math.round(extraLabor * 0.05);
        if (extraLabor === 0 && extraToLock > 0) extraLabor = Math.round(extraToLock / 1.05);
        if (extraToLock === 0 && extraLabor > 0) extraToLock = extraLabor + Math.round(extraLabor * 0.05);
        return { extraLabor, extraToLock, originalLabor };
    }
    const { extraLabor, extraToLock } = getExtraNumbers(after);

    if ((newEscHeld && !oldEscHeld) || (newEscStatus === "held" && oldEscStatus !== "held")) {
        const beforeStatus = (before?.status || "").toLowerCase();
        const isExtraLock = extraLabor > 0 || extraToLock > 0 || beforeStatus.includes("awaiting_extra") || beforeStatus.includes("in_progress") || beforeStatus.includes("site_visit");
        if (isExtraLock) {
            await sendPush(fundiTokens, `Extra KES ${extraLabor} locked - Continue job`, `${title} • Resume work`, { jobId, type: "extra_escrow_locked" });
            await sendPush(clientTokens, `Extra KES ${extraToLock} locked • Fundi resuming`, `${title} • Continue job`, { jobId, type: "extra_escrow_locked" });
            await db().collection('notifications').add({ toUserId: clientId, title: `Extra KES ${extraToLock} locked`, body: `${title} • Fundi resuming`, type: 'extra_escrow_locked', jobId, createdAt: FieldValue.serverTimestamp(), isRead: false });
        } else {
            await sendPush(fundiTokens, `Escrow locked KES ${fundiSees} - Start site visit now`, `${title} • Tap to travel`, { jobId, type: "escrow_locked" });
            await sendPush(clientTokens, `Escrow locked KES ${clientPays} • Waiting for fundi`, `${title} • ${after.assignedFundiName || 'Fundi'} has NOT started travelling`, { jobId, type: "escrow_locked" });
            await db().collection('notifications').add({ toUserId: clientId, title: `Escrow locked KES ${clientPays}`, body: `${title} • Waiting for fundi`, type: 'escrow_locked', jobId, createdAt: FieldValue.serverTimestamp(), isRead: false });
        }
        return;
    }

    if ((newS === "assigned" || newS === "confirmed") && oldS !== newS && !newEscHeld && newEscStatus !== "held") {
        await sendPush(clientTokens, `Fundi accepted • Lock KES ${clientPays} to start`, `${title} • Tap to pay escrow`, { jobId, type: "lock_escrow" });
        await db().collection('notifications').add({ toUserId: clientId, title: `Fundi accepted • Lock KES ${clientPays}`, body: `${title} • Tap to pay escrow`, type: 'lock_escrow', jobId, createdAt: FieldValue.serverTimestamp(), isRead: false });
    }
    if ((newS === "travelling" || newS === "on_the_way") && oldS !== newS) {
        await sendPush(clientTokens, "Fundi is on the way", `${after.assignedFundiName || 'Fundi'} is travelling • Tracking live`, { jobId, type: "travelling" });
        await db().collection('notifications').add({ toUserId: clientId, title: `Fundi is on the way`, body: `${after.assignedFundiName || 'Fundi'} is travelling`, type: 'travelling', jobId, createdAt: FieldValue.serverTimestamp(), isRead: false });
    }
    if ((newS.includes("site_visit") || newS === "site_visited") && !oldS.includes("site_visit")) {
        await sendPush(fundiTokens, `Waiting for you to start work KES ${fundiSees}`, `${title} • Tap START JOB`, { jobId, type: "site_visited" });
        await sendPush(clientTokens, "Fundi arrived on site", `${after.assignedFundiName || 'Fundi'} • Waiting to start work`, { jobId, type: "site_visited" });
        await db().collection('notifications').add({ toUserId: clientId, title: `Fundi arrived on site`, body: `${after.assignedFundiName || 'Fundi'} arrived`, type: 'site_visited', jobId, createdAt: FieldValue.serverTimestamp(), isRead: false });
    }
    if ((newS === "in_progress" || newS === "fundi_working") && oldS !== newS) {
        await sendPush(clientTokens, "Fundi is working", `${title} in progress`, { jobId, type: "working" });
        await db().collection('notifications').add({ toUserId: clientId, title: `Fundi is working`, body: `${title} in progress`, type: 'working', jobId, createdAt: FieldValue.serverTimestamp(), isRead: false });
    }
    if ((newS === "pending_completion" || newS === "job_completed") && oldS !== newS) {
        await sendPush(clientTokens, `Job Completed - Confirm & release KES ${clientPays}`, `${title} • Tap to confirm`, { jobId, type: "job_completed" });
        await db().collection('notifications').add({ toUserId: clientId, title: `Job Completed - Confirm & release KES ${clientPays}`, body: `${title} • Tap to confirm`, type: 'job_completed', jobId, createdAt: FieldValue.serverTimestamp(), isRead: false });
        await sendPush(fundiTokens, "Job Completed - Waiting for client", `${title} • Waiting for client to confirm`, { jobId, type: "job_completed" });
    }
    if (newS.includes("awaiting_extra") && !oldS.includes("awaiting_extra")) {
        await sendPush(clientTokens, `Lock extra KES ${extraToLock} in escrow`, `${title} • Fundi accepted`, { jobId, type: "awaiting_extra_escrow" });
        await db().collection('notifications').add({ toUserId: clientId, title: `Lock extra KES ${extraToLock}`, body: `${title} • Extra work needed`, type: 'awaiting_extra_escrow', jobId, createdAt: FieldValue.serverTimestamp(), isRead: false });
        await sendPush(fundiTokens, `Waiting for client to lock extra KES ${extraLabor}`, `${title}`, { jobId, type: "awaiting_extra_escrow" });
    }
    if (newS.includes("waiting_for_client_to_buy_parts") && !oldS.includes("waiting_for_client_to_buy_parts")) {
        await sendPush(clientTokens, "You will buy parts - Confirm when bought", `${title}`, { jobId, type: "waiting_for_client_to_buy_parts" });
        await db().collection('notifications').add({ toUserId: clientId, title: `You will buy parts`, body: `${title} • Confirm when bought`, type: 'waiting_for_client_to_buy_parts', jobId, createdAt: FieldValue.serverTimestamp(), isRead: false });
    }
    if (after.renegotiation?.status === "pending" && before?.renegotiation?.status !== "pending") {
        await sendPush(clientTokens, "Fundi requests price review", `${after.renegotiation.reasonDetails || 'New breakdown'} • Tap to REVIEW`, { jobId, type: "price_review" });
        await db().collection('notifications').add({ toUserId: clientId, title: `Fundi requests price review`, body: `${after.renegotiation.reasonDetails || 'New breakdown'}`, type: 'price_review', jobId, createdAt: FieldValue.serverTimestamp(), isRead: false });
    }
    const wasReleased = oldEscStatus === "released" || before?.escrowReleased === true || before?.escrowStatus === "released";
    const nowReleased = newEscStatus === "released" || after?.escrowReleased === true || after?.escrowStatus === "released";
    if (!wasReleased && nowReleased) {
        await sendPush(fundiTokens, `Client released KES ${fundiReceives}`, `${title} • Tap to view receipt`, { jobId, type: "released" });
        await sendPush(clientTokens, `You released KES ${clientPays} • Completed`, `${title}`, { jobId, type: "released" });
        await db().collection('notifications').add({ toUserId: clientId, title: `You released KES ${clientPays} • Completed`, body: `${title} • Completed`, type: 'released', jobId, createdAt: FieldValue.serverTimestamp(), isRead: false });
    }
});
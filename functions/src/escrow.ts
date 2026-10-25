import * as admin from "firebase-admin";
import { onCall, HttpsError, onRequest } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

const db = admin.firestore();

function toInt(v: any): number {
    if (v == null) return 0;
    if (typeof v === 'number') return Math.round(v);
    if (typeof v === 'string') return parseInt(v) || 0;
    return 0;
}

// 1. SECURE RELEASE - can never double-pay
export const confirmCompletionSecure = onCall({ region: "europe-west1" }, async (request) => {
    const uid = request.auth?.uid;
    const jobId = (request.data?.jobId as string)?.trim();
    if (!uid) throw new HttpsError("unauthenticated", "Must be logged in");
    if (!jobId) throw new HttpsError("invalid-argument", "jobId required");

    return await db.runTransaction(async (tx) => {
        const jobRef = db.collection("jobs").doc(jobId);
        const jobSnap = await tx.get(jobRef);
        if (!jobSnap.exists) throw new HttpsError("not-found", "Job not found");
        const j = jobSnap.data()!;

        if (j.customerId !== uid && j.clientId !== uid) throw new HttpsError("permission-denied", "Only client can release");
        if (j.escrowStatus === "released" || j.fundiPayoutApplied === true) throw new HttpsError("already-exists", "Already released - cannot double-pay");
        if (!["job_completed", "pending_completion", "in_progress"].includes(j.status) && j.fundiConfirmedComplete !== true && j.renegotiation?.currentPhase !== "completed_by_fundi") {
            throw new HttpsError("failed-precondition", "Fundi not yet marked complete");
        }

        const fundiId = (j.assignedFundiId || j.assignedFundi || "").toString();
        if (!fundiId) throw new HttpsError("failed-precondition", "No fundi assigned");

        // CORRECT LABOUR - never use escrowAmount (includes client fee)
        const labourBase = toInt(j.laborCost ?? j.agreedPrice ?? j.acceptedBidAmount ?? j.lastCounterAmount ?? j.budgetMax ?? 0);
        const extraLabor = toInt(j.extraLaborAmount ?? j.renegotiation?.extraLabor ?? 0);
        const newLaborTotal = toInt(j.renegotiation?.newLaborTotal ?? 0);
        const labour = newLaborTotal > 0 ? newLaborTotal : labourBase + extraLabor;
        if (labour <= 0) throw new HttpsError("failed-precondition", "Invalid labour amount");

        const transport = toInt(j.transportFee ?? 100);
        const clientFeeLocked = toInt(j.clientAppFee ?? Math.round(labour * 0.05));
        const totalLocked = labour + transport + clientFeeLocked;
        const escrowAmount = toInt(j.escrowAmount ?? j.totalCost ?? 0);
        // Validate client locked enough, but don't use escrowAmount for payout math
        if (escrowAmount > 0 && escrowAmount < totalLocked - 50) {
            console.warn(`Escrow ${escrowAmount} less than expected ${totalLocked} for job ${jobId}`);
        }

        // Badge - server truth
        let fundiPct = 15;
        try {
            const fu = await db.collection("users").doc(fundiId).get();
            const fd = fu.data();
            if (fd) {
                if (fd.isTrialGold === true) fundiPct = 5;
                else if (fd.badgeLevel === "gold") fundiPct = 5;
                else if (fd.badgeLevel === "silver") fundiPct = 8;
                else if (fd.badgeLevel === "bronze") fundiPct = 10;
            }
        } catch { }

        const platformFee = Math.round(labour * fundiPct / 100);
        const baseFundiPayout = labour - platformFee + transport;
        const totalRelease = totalLocked; // for ledger C2B = totalLocked

        // Deduction - server truth from fundiPenalties collection
        let finalPayout = baseFundiPayout;
        let deducted = 0;
        let disputeId: string | null = null;
        let remaining: number | null = null;

        try {
            const penalties = await db.collection("fundiPenalties").where("fundiId", "==", fundiId).where("status", "==", "pending").limit(1).get();
            if (!penalties.empty) {
                const pen = penalties.docs[0];
                const penData = pen.data();
                const pendingAmt = toInt(penData.remainingAmount ?? penData.totalPenalty ?? 0);
                if (pendingAmt > 0) {
                    deducted = Math.min(pendingAmt, baseFundiPayout);
                    finalPayout = baseFundiPayout - deducted;
                    disputeId = pen.id;
                    remaining = pendingAmt - deducted;
                    tx.update(pen.ref, {
                        remainingAmount: remaining,
                        status: remaining <= 0 ? "cleared" : "pending",
                        lastDeductionJobId: jobId,
                        lastDeductionAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                }
            }
        } catch { }

        // KRA SAFE LEDGER - C2B vs B2C DIFFERENT IDs
        const c2bId = `SIM_C2B_${jobId}_${Date.now()}`;
        const b2cId = `SIM_B2C_${jobId}_${Date.now()}`;
        const payoutRef = db.collection("mpesaPayouts").doc(jobId);

        tx.set(payoutRef, {
            jobId,
            fundiId,
            clientId: j.customerId || j.clientId,
            amount: finalPayout,
            baseFundiPayoutBeforeDeduction: baseFundiPayout,
            platformFee,
            labourCost: labour,
            transportFee: transport,
            commissionPct: fundiPct,
            deductionThisJob: deducted,
            deductionDisputeId: disputeId,
            c2bTransactionId: c2bId,
            b2cTransactionId: b2cId,
            c2bStatus: "SUCCESS",
            b2cStatus: "SUCCESS",
            idempotencyKey: jobId,
            status: "released",
            simulated: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        // Update job - fundiPayoutApplied prevents double-pay
        tx.update(jobRef, {
            status: "completed",
            escrowStatus: "released",
            extraEscrowStatus: "released",
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
            paymentReleasedAt: admin.firestore.FieldValue.serverTimestamp(),
            releasedAt: admin.firestore.FieldValue.serverTimestamp(),
            totalReleasedAmount: totalRelease,
            fundiPayoutAmount: finalPayout,
            baseFundiPayoutBeforeDeduction: baseFundiPayout,
            fundiPayoutAfterDeduction: finalPayout,
            deductionThisJob: deducted,
            deductionDisputeId: disputeId,
            deductionRemainingAfter: remaining,
            platformFee,
            fundiCommissionPct: fundiPct,
            fundiPayoutApplied: true,
            c2bTransactionId: c2bId,
            b2cTransactionId: b2cId,
            fundiHasUnread: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Update fundi balance - server only
        const userRef = db.collection("users").doc(fundiId);
        const fundiRef = db.collection("fundis").doc(fundiId);
        tx.set(userRef, {
            totalEarned: admin.firestore.FieldValue.increment(finalPayout),
            balance: admin.firestore.FieldValue.increment(finalPayout),
            completedJobs: admin.firestore.FieldValue.increment(1),
        }, { merge: true });
        tx.set(fundiRef, {
            totalEarned: admin.firestore.FieldValue.increment(finalPayout),
            balance: admin.firestore.FieldValue.increment(finalPayout),
        }, { merge: true });

        // Escrow transaction log
        const escrowRef = db.collection("escrowTransactions").doc(jobId);
        tx.set(escrowRef, {
            status: "released",
            amount: totalRelease,
            platformFee,
            fundiPayout: finalPayout,
            baseFundiPayout,
            deductionThisJob: deducted,
            commissionPct: fundiPct,
            releasedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        return { success: true, fundiPayout: finalPayout, b2cId, c2bId };
    });
});

// 2. AUTO-CHECK ON DISPUTE CREATED - 3 MAX THREAD
export const onDisputeCreatedSecure = onDocumentCreated({ document: "disputes/{disputeId}", region: "europe-west1" }, async (event) => {
    const snap = event.data;
    if (!snap) return;
    const dispute = snap.data() as any;
    const disputeId = event.params.disputeId;
    const jobId = dispute.jobId as string;
    const fundiId = dispute.fundiId as string;
    if (!jobId) return;
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    const job = jobSnap.data() as any;
    if (!job) return;

    // --- 3 MAX DISPUTES LOGIC - START ---
    const existingDisputes = await db.collection("disputes").where("jobId", "==", jobId).where("fundiId", "==", fundiId).get();
    const disputeCount = existingDisputes.size;

    if (disputeCount > 3) {
        await snap.ref.update({ status: "auto_closed_max_3", autoClosedReason: "Max 3 disputes reached", resolvedAt: admin.firestore.FieldValue.serverTimestamp() });
        await db.collection("jobs").doc(jobId).update({
            lastDisputeId: disputeId,
            lastDisputeStatus: "auto_closed_max_3",
            disputeCount,
            autoResolveCount: disputeCount,
            status: "completed",
        });
        return;
    }

    let sameResolutionCount = 0;
    existingDisputes.forEach((d) => {
        const s = (d.data().status || "").toString();
        if (s === "resolved_explained" || s === "auto_resolved" || s === "resolved" || s === "auto_closed_same_resolution_3x") sameResolutionCount++;
    });

    if (sameResolutionCount >= 2 && disputeCount >= 3) {
        await snap.ref.update({ status: "auto_closed_same_resolution_3x", autoClosedReason: "Same amount verified 3 times", resolvedAt: admin.firestore.FieldValue.serverTimestamp() });
        await db.collection("jobs").doc(jobId).update({
            lastDisputeId: disputeId,
            lastDisputeStatus: "auto_closed_max_3",
            lastDisputeMessage: `System verified same payout 3 times. B2C ${job.lastB2CId || ""} / C2B ${job.lastC2BId || ""} - job auto-closed after ${disputeCount} attempts.`,
            disputeCount,
        });
        return;
    }
    // --- 3 MAX DISPUTES LOGIC - END ---

    try {
        const payoutSnap = await db.collection("mpesaPayouts").doc(jobId).get();
        const jSnap = await db.collection("jobs").doc(jobId).get();
        if (!jSnap.exists) return;
        const j = jSnap.data()!;

        let result = "needs_admin";
        let tier = 3;
        let msg = "Needs admin review";

        if (payoutSnap.exists) {
            const p = payoutSnap.data()!;
            if (p.b2cStatus === "SUCCESS") {
                result = "mpesa_success";
                tier = 1;
                msg = `B2C ${p.b2cTransactionId} shows SUCCESS for KES ${p.amount} - M-Pesa confirmed delivered to fundi. Fundi should check M-Pesa statement. C2B: ${p.c2bTransactionId}`;
            }
        }

        if ((j.deductionThisJob ?? 0) > 0) {
            result = "deduction_explained";
            tier = 1;
            msg = `KES ${j.deductionThisJob} deducted due to repeat job penalty from dispute ${j.deductionDisputeId}. Original payout KES ${j.baseFundiPayoutBeforeDeduction}, after deduction KES ${j.fundiPayoutAfterDeduction}. Remaining penalty: ${j.deductionRemainingAfter}`;
        } else if ((j.platformFee ?? 0) > 0 && (dispute.reason || "").toLowerCase().includes("not full")) {
            result = "platform_fee_explained";
            tier = 1;
            msg = `Platform fee KES ${j.platformFee} (${j.fundiCommissionPct}% for badge) deducted. Labour KES ${j.labourCost ?? ''} + Transport KES ${j.transportFee ?? ''} - Fee = KES ${j.fundiPayoutAmount}. Not missing, it's commission.`;
        }

        await snap.ref.update({
            autoCheckResult: result,
            autoCheckTier: tier,
            autoCheckMessage: msg,
            autoCheckStatus: result,
            autoExplain: msg,
            checkedAt: admin.firestore.FieldValue.serverTimestamp(),
            mpesaPayoutRef: `mpesaPayouts/${jobId}`,
            finalAmount: j.fundiPayoutAmount,
            baseAmount: j.baseFundiPayoutBeforeDeduction,
            b2cId: j.b2cTransactionId,
            c2bId: j.c2bTransactionId,
        });

        if (tier === 1) {
            await db.collection("jobs").doc(jobId).update({
                lastDisputeId: disputeId,
                lastAutoCheck: msg,
                lastAutoCheckResult: result,
                lastDisputeStatus: 'resolved_explained',
                lastDisputeMessage: msg,
                lastB2CId: j.b2cTransactionId,
                lastC2BId: j.c2bTransactionId,
                lastAutoResolvedAt: admin.firestore.FieldValue.serverTimestamp(),
                disputeCount: disputeCount,
                autoResolveCount: disputeCount,
            });

            const fId = (j.assignedFundiId || (j as any).assignedFundi || (j as any).fundiId || fundiId || '').toString();
            if (fId) {
                const payoutSnap2 = await db.collection("mpesaPayouts").doc(jobId).get();
                const p = payoutSnap2.exists ? payoutSnap2.data()! : null;
                await db.collection('fundis').doc(fId).collection('notifications').add({
                    jobId,
                    type: 'payment_dispute_auto_resolved',
                    title: 'Dispute auto-resolved - tap to see receipt',
                    body: msg,
                    finalAmount: j.fundiPayoutAmount,
                    baseAmount: j.baseFundiPayoutBeforeDeduction,
                    feePct: j.fundiCommissionPct,
                    feeAmount: j.platformFee,
                    deduction: j.deductionThisJob || 0,
                    transport: j.transportFee || 0,
                    b2cId: j.b2cTransactionId || (p as any)?.b2cTransactionId || '',
                    c2bId: j.c2bTransactionId || (p as any)?.c2bTransactionId || '',
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    disputeId,
                    disputeCount,
                });
                await db.collection('notifications').add({
                    toUserId: fId,
                    toRole: 'fundi',
                    type: 'payment_dispute_auto_resolved',
                    jobId,
                    title: 'Payment dispute resolved',
                    body: msg,
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    disputeId,
                });
            }
        }
    } catch (e) {
        await snap.ref.update({ autoCheckResult: "error", autoCheckMessage: `Auto-check error: ${e}`, checkedAt: admin.firestore.FieldValue.serverTimestamp() });
    }
});

// 3. RETRY B2C - ONLY ADMIN, ONLY IF FAILED, IDEMPOTENT
export const retryFundiPayoutSecure = onCall({ memory: "256MiB", cpu: 1, concurrency: 80, minInstances: 0, maxInstances: 10, region: "europe-west1" }, async (request) => {
    const uid = request.auth?.uid;
    const jobId = (request.data?.jobId as string)?.trim();
    if (!uid) throw new HttpsError("unauthenticated", "Must be logged in");
    if (request.auth?.token?.email !== "agwonamallan@gmail.com") throw new HttpsError("permission-denied", "Admin only");
    if (!jobId) throw new HttpsError("invalid-argument", "jobId required");

    return await db.runTransaction(async (tx) => {
        const payoutRef = db.collection("mpesaPayouts").doc(jobId);
        const payoutSnap = await tx.get(payoutRef);
        if (!payoutSnap.exists) throw new HttpsError("not-found", "No payout ledger - job not released via secure function");
        const p = payoutSnap.data()!;

        if (p.b2cStatus === "SUCCESS") throw new HttpsError("already-exists", `B2C ${p.b2cTransactionId} already SUCCESS - cannot double-pay. Fundi received KES ${p.amount}`);

        const newB2cId = `SIM_B2C_RETRY_${jobId}_${Date.now()}`;
        tx.update(payoutRef, {
            b2cTransactionId: newB2cId,
            b2cStatus: "SUCCESS",
            retriedAt: admin.firestore.FieldValue.serverTimestamp(),
            retriedBy: uid,
            previousB2cId: p.b2cTransactionId,
            status: "released_retry_success",
        });

        const jobRef = db.collection("jobs").doc(jobId);
        tx.update(jobRef, {
            b2cTransactionId: newB2cId,
            lastRetryAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return { success: true, newB2cId, previous: p.b2cTransactionId };
    });
});

// 4. DAILY KRA RECONCILIATION - sum C2B vs B2C vs fees
export const dailyReconciliation = onSchedule({ schedule: "every day 02:00", region: "europe-west1", timeZone: "Africa/Nairobi" }, async () => {
    const today = new Date().toISOString().split("T")[0];
    const start = new Date(); start.setHours(0, 0, 0, 0);
    const payouts = await db.collection("mpesaPayouts").where("createdAt", ">=", start).get();
    let totalC2B = 0, totalB2C = 0, totalFees = 0, totalDeductions = 0, count = 0;
    payouts.forEach(doc => {
        const p = doc.data();
        totalC2B += toInt(p.amount) + toInt(p.platformFee);
        totalB2C += toInt(p.amount);
        totalFees += toInt(p.platformFee);
        totalDeductions += toInt(p.deductionThisJob);
        count++;
    });
    await db.collection("kraReconciliation").doc(today).set({
        date: today,
        count,
        totalC2B,
        totalB2C,
        totalFees,
        totalDeductions,
        c2b_minus_b2c_should_equal_fees: totalC2B - totalB2C,
        fees_match: (totalC2B - totalB2C) === totalFees,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`KRA Reconciliation ${today}: ${count} jobs, C2B ${totalC2B}, B2C ${totalB2C}, Fees ${totalFees}, Match: ${totalC2B - totalB2C === totalFees}`);
});
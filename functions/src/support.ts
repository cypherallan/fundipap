import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentCreated as onDocCreated } from "firebase-functions/v2/firestore";
const db = admin.firestore();

// When fundi escalates -> email admin + confirm to fundi
export const onSupportEscalationCreated = onDocumentCreated({ document: "supportEscalations/{jobId}", region: "europe-west1" }, async (event) => {
    const data = event.data?.data() as any;
    if (!data) return;
    const jobId = event.params.jobId;
    const fundiId = data.fundiId;
    let fundiEmail = data.fundiEmail as string;
    if (!fundiEmail) {
        try {
            const u = await db.collection("users").doc(fundiId).get();
            fundiEmail = u.data()?.email || "";
        } catch { }
    }
    const adminEmail = "fundipapsupport@gmail.com";
    const mpesaLinks = (data.mpesa_statement as any[] || []).map((f: any) => `<li><a href="${f.url}">${f.name}</a></li>`).join("");
    const shotLinks = (data.screenshots as any[] || []).map((f: any) => `<li><a href="${f.url}">${f.name}</a></li>`).join("");

    // Email to admin - replyTo is fundi email so you can just hit Reply
    await db.collection("mail").add({
        to: [adminEmail],
        replyTo: fundiEmail || adminEmail,
        message: {
            subject: `[Fundipap SUPPORT] Job ${jobId} - KES ${data.finalAmount} - Fundi says got KES ${data.amountFundiSaysReceived}`,
            html: `
        <h2>Support Escalation - Job ${jobId}</h2>
        <p><b>Fundi:</b> ${fundiId}<br><b>Email:</b> ${fundiEmail}<br><b>Client:</b> ${data.clientName}<br><b>Title:</b> ${data.jobTitle}</p>
        <p><b>System says fundi got:</b> KES ${data.finalAmount} - B2C ${data.b2cId} / C2B ${data.c2bId}</p>
        <p><b>Fundi says he got:</b> KES ${data.amountFundiSaysReceived}</p>
        <p><b>Description:</b><br>${data.description}</p>
        <p><b>M-Pesa Statement:</b><ul>${mpesaLinks}</ul></p>
        <p><b>Screenshots:</b><ul>${shotLinks}</ul></p>
        <p>Reply directly to this email to respond to fundi (reply-to is fundi), or reply in admin panel.</p>
        <p>Job link: https://console.firebase.google.com/project/_/firestore/data/~2Fjobs~2F${jobId}</p>
      `,
        },
    });

    // Confirmation email to fundi
    if (fundiEmail) {
        await db.collection("mail").add({
            to: [fundiEmail],
            message: {
                subject: `Fundipap Support Received - Job ${jobId}`,
                html: `<p>Hi, we received your escalation for job ${jobId} (KES ${data.finalAmount}). Admin will review your M-Pesa statement and B2C ${data.b2cId} within 24h. You will get email + in-app notification when admin replies.</p>`,
            },
        });
    }

    // In-app notification for fundi
    await db.collection("fundis").doc(fundiId).collection("notifications").add({
        jobId, type: "escalated_to_support", title: "Support received - we will email you", body: `We emailed admin. You will get reply at ${fundiEmail}`, isRead: false, createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
});

// When admin replies in admin panel -> email fundi + notify
export const onSupportReplyCreated = onDocCreated({ document: "supportEscalations/{jobId}/replies/{replyId}", region: "europe-west1" }, async (event) => {
    const reply = event.data?.data() as any;
    const jobId = event.params.jobId;
    const escSnap = await db.collection("supportEscalations").doc(jobId).get();
    const esc = escSnap.data() as any;
    const fundiEmail = esc?.fundiEmail;
    if (!fundiEmail) return;

    await db.collection("mail").add({
        to: [fundiEmail],
        message: {
            subject: `Fundipap Support Reply - Job ${jobId}`,
            html: `<p><b>Admin reply for job ${jobId}:</b></p><p>${reply.message}</p><p>B2C: ${esc.b2cId} - Final: KES ${esc.finalAmount}</p>`,
        },
    });

    await db.collection("fundis").doc(esc.fundiId).collection("notifications").add({
        jobId, type: "support_reply", title: "Support replied - KES ${esc.finalAmount}", body: reply.message, isRead: false, createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await db.collection("jobs").doc(jobId).update({
        lastDisputeStatus: reply.isResolved ? "resolved_by_support" : "escalated_to_support",
        lastSupportReply: reply.message,
        lastSupportReplyAt: admin.firestore.FieldValue.serverTimestamp(),
    });
});
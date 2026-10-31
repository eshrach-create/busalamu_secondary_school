const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();
const db = admin.firestore();

/**
 * 1. School taps PAY NOW in app
 * App calls this function -> it requests MoMo PIN prompt
 */
exports.requestSubscriptionPayment = functions.https.onCall(async (data, context) => {
  // Optional: require login
  // if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');

  const { packageType, phone, network } = data;
  if (!phone || !packageType) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing phone or package');
  }

  // Clean phone: 07... -> 2567...
  let cleanPhone = phone.toString().replace(/\s|\+/g, '');
  if (cleanPhone.startsWith('0')) cleanPhone = '256' + cleanPhone.substring(1);

  const isYearly = packageType === 'yearly';
  const amount = isYearly ? 700000 : 250000; // UGX - set your real price
  const days = isYearly ? 365 : 120;
  const externalId = `BUSALAMU-${Date.now()}`;

  // === SAVE PENDING FIRST (for accountability) ===
  await db.collection('subscriptionPayments').doc(externalId).set({
    phone: cleanPhone,
    rawPhone: phone,
    amount,
    packageType,
    network: network || 'MTN',
    days,
    status: 'PENDING',
    external_reference: externalId,
    requestedAt: admin.firestore.FieldValue.serverTimestamp(),
    schoolName: 'Busalamu SS',
    ownerWhatsApp: cleanPhone,
    requestedByUid: context.auth ? context.auth.uid : null,
  });

  // === CALL REAL AGGREGATOR HERE ===
  // Replace with your real Yo! / Flutterwave / MTN MoMo credentials
  try {
    // EXAMPLE - YO UGANDA (replace URL & key)
    // const resp = await fetch("https://yo.co.ug/api/v1/request-to-pay", {
    //   method: "POST",
    //   headers: {
    //     "Content-Type": "application/json",
    //     "Authorization": "Bearer YOUR_YO_API_KEY"
    //   },
    //   body: JSON.stringify({
    //     msisdn: cleanPhone,
    //     amount: amount,
    //     network: network, // MTN or AIRTEL
    //     external_reference: externalId,
    //     narration: `Busalamu App ${packageType}`
    //   })
    // });
    // const result = await resp.json();
    // if (!resp.ok) throw new Error(JSON.stringify(result));

    // For now, demo mode: return PENDING and let you manually approve in console
    // When you get real API, uncomment above and comment below

    console.log(`Payment request ${externalId} for ${cleanPhone} UGX ${amount}`);

  } catch (err) {
    await db.collection('subscriptionPayments').doc(externalId).update({
      status: 'FAILED',
      error: err.message,
      failedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    throw new functions.https.HttpsError('internal', `Payment request failed: ${err.message}`);
  }

  return { success: true, ref: externalId, message: "PIN prompt sent to " + cleanPhone };
});

/**
 * 2. MoMo Aggregator calls this URL after customer enters PIN
 * Set this URL in Yo/Flutterwave dashboard as callback
 * https://us-central1-YOUR_PROJECT.cloudfunctions.net/momoCallback
 */
exports.momoCallback = functions.https.onRequest(async (req, res) => {
  try {
    // Yo/Flutterwave sends POST with JSON
    const { external_reference, status, transaction_id, msisdn, amount } = req.body;

    console.log("Callback:", req.body);

    if (!external_reference) {
      return res.status(400).send("Missing external_reference");
    }

    const payRef = db.collection('subscriptionPayments').doc(external_reference);
    const paySnap = await payRef.get();

    if (!paySnap.exists) {
      console.error("Payment doc not found:", external_reference);
      return res.status(404).send("Not found");
    }

    const payData = paySnap.data();

    if (status === 'SUCCESSFUL' || status === 'SUCCESS' || status === 'COMPLETED') {
      const days = payData.days || 120;
      const packageType = payData.packageType || 'termly';

      // GET CURRENT EXPIRY
      const subRef = db.collection('appSubscription').doc('current');
      const subSnap = await subRef.get();

      let currentExpiryMs;
      if (subSnap.exists) {
        const d = subSnap.data();
        // Handle both formats: expiryMillis (int) or expiryDate (ISO string)
        if (d.expiryMillis) {
          currentExpiryMs = d.expiryMillis;
        } else if (d.expiryDate) {
          try {
            currentExpiryMs = new Date(d.expiryDate).getTime();
          } catch (_) {
            currentExpiryMs = Date.now();
          }
        } else {
          currentExpiryMs = Date.now();
        }
      } else {
        currentExpiryMs = Date.now();
      }

      // If already expired, start from now
      if (currentExpiryMs < Date.now()) currentExpiryMs = Date.now();

      const newExpiryMs = currentExpiryMs + days * 24 * 60 * 60 * 1000;
      const newExpiryDate = new Date(newExpiryMs);

      // UPDATE - FORMAT YOUR FLUTTER APP EXPECTS
      await subRef.set({
        expiryDate: newExpiryDate.toISOString(), // Flutter: DateTime.tryParse
        expiryMillis: newExpiryMs, // Flutter: expiryMillis int
        startDate: new Date().toISOString(),
        startMillis: Date.now(),
        isActive: true,
        package: packageType === 'yearly' ? 'Yearly' : 'Termly',
        schoolName: payData.schoolName || 'Busalamu SS',
        ownerWhatsApp: payData.ownerWhatsApp || msisdn,
        termlyPrice: 250000,
        yearlyPrice: 700000,
        lastPaymentRef: external_reference,
        lastPaymentTxId: transaction_id || '',
        lastPaymentPhone: msisdn || payData.phone,
        lastPaymentAmount: amount || payData.amount,
        lastPaymentAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastServerCheck: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      await payRef.update({
        status: 'SUCCESSFUL',
        transaction_id: transaction_id || '',
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        callbackData: req.body
      });

      console.log(`Extended expiry to ${newExpiryDate.toISOString()} for ${external_reference}`);
    } else {
      // FAILED
      await payRef.update({
        status: status || 'FAILED',
        callbackData: req.body,
        failedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    res.status(200).send("OK");
  } catch (e) {
    console.error("Callback error:", e);
    res.status(500).send(e.message);
  }
});
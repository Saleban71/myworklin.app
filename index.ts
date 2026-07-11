// ============================================================
// WorkLink Edge Function: MoMo status webhook / poller target
// Marks escrow 'funded' when the provider confirms payment.
// Also usable as a polling endpoint from a scheduled job if
// callbacks are not enabled on your MoMo API user.
//
// Deploy: supabase functions deploy momo-webhook --no-verify-jwt
// (provider callbacks are unauthenticated; we verify against the
//  MoMo API directly rather than trusting the request body)
// ============================================================

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUB_KEY = Deno.env.get("MTN_MOMO_SUBSCRIPTION_KEY")!;
const API_USER = Deno.env.get("MTN_MOMO_API_USER")!;
const API_KEY = Deno.env.get("MTN_MOMO_API_KEY")!;
const MOMO_ENV = Deno.env.get("MTN_MOMO_ENV") ?? "sandbox";
const BASE = MOMO_ENV === "sandbox"
  ? "https://sandbox.momodeveloper.mtn.com"
  : "https://proxy.momoapi.mtn.com";

Deno.serve(async (req) => {
  try {
    const { reference_id } = await req.json();
    if (!reference_id) return json({ error: "reference_id required" }, 400);

    // Never trust the webhook body — verify status with MoMo directly.
    const tokenRes = await fetch(`${BASE}/collection/token/`, {
      method: "POST",
      headers: {
        "Ocp-Apim-Subscription-Key": SUB_KEY,
        Authorization: "Basic " + btoa(`${API_USER}:${API_KEY}`),
      },
    });
    const { access_token } = await tokenRes.json();

    const statusRes = await fetch(
      `${BASE}/collection/v1_0/requesttopay/${reference_id}`, {
        headers: {
          Authorization: `Bearer ${access_token}`,
          "X-Target-Environment": MOMO_ENV,
          "Ocp-Apim-Subscription-Key": SUB_KEY,
        },
      });
    const status = await statusRes.json();

    const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    if (status.status === "SUCCESSFUL") {
      await db.from("escrow_transactions")
        .update({ status: "funded", funded_at: new Date().toISOString() })
        .eq("provider_reference", reference_id)
        .eq("status", "pending");
      return json({ ok: true, escrow: "funded" }, 200);
    }
    if (status.status === "FAILED" || status.status === "REJECTED") {
      await db.from("escrow_transactions")
        .update({ status: "refunded" })
        .eq("provider_reference", reference_id)
        .eq("status", "pending");
      return json({ ok: true, escrow: "cancelled" }, 200);
    }
    return json({ ok: true, escrow: "still pending" }, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status, headers: { "content-type": "application/json" },
  });
}

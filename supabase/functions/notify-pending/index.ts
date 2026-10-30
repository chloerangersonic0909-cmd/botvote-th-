import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://chloerangersonic0909-cmd.github.io",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405, headers: corsHeaders });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY");
  const resendKey = Deno.env.get("RESEND_API_KEY");
  const adminEmail = Deno.env.get("ADMIN_NOTIFICATION_EMAIL");

  if (!supabaseUrl || !serviceKey || !resendKey || !adminEmail) {
    return Response.json({ error: "Missing required server secrets." }, { status: 500, headers: corsHeaders });
  }

  // This endpoint is intended only for the trusted scheduled server-side caller.
  const auth = req.headers.get("authorization") ?? "";
  if (auth !== `Bearer ${serviceKey}`) {
    return Response.json({ error: "Unauthorized" }, { status: 401, headers: corsHeaders });
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: pending, error: queryError } = await supabase
    .from("botvote_bots")
    .select("id,name,client_id,description,created_at,owner_id")
    .eq("status", "pending")
    .is("notification_sent_at", null)
    .lte("created_at", new Date(Date.now() - 60_000).toISOString())
    .order("created_at", { ascending: true })
    .limit(50);

  if (queryError) {
    console.error("Failed to load pending bot requests:", queryError.message);
    return Response.json({ error: "Could not load pending requests." }, { status: 500, headers: corsHeaders });
  }

  if (!pending?.length) {
    return Response.json({ ok: true, notified: 0 }, { headers: corsHeaders });
  }

  let notified = 0;
  const failed: string[] = [];

  for (const bot of pending) {
    const submittedAt = new Date(bot.created_at).toLocaleString("th-TH", { timeZone: "Asia/Bangkok" });
    const html = `
      <div style="font-family:Arial,sans-serif;line-height:1.6;color:#171725">
        <h2>🔔 BotVote มีคำขอบอทรออนุมัติ</h2>
        <p>มีคำขอที่รอการตรวจสอบมาแล้วอย่างน้อย 1 นาที</p>
        <p><b>ชื่อบอท:</b> ${escapeHtml(bot.name)}<br>
        <b>Client ID:</b> ${escapeHtml(bot.client_id)}<br>
        <b>ส่งคำขอเมื่อ:</b> ${escapeHtml(submittedAt)}</p>
        <p><b>รายละเอียด:</b><br>${escapeHtml(bot.description)}</p>
        <p><a href="https://chloerangersonic0909-cmd.github.io/botvote-th-/admin.html">เปิดหน้า Admin Dashboard เพื่อตรวจสอบ</a></p>
      </div>`;

    const mail = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: Deno.env.get("RESEND_FROM_EMAIL") ?? "BotVote Notifications <onboarding@resend.dev>",
        to: [adminEmail],
        subject: `[BotVote] มีคำขอบอทรออนุมัติ: ${bot.name}`,
        html,
      }),
    });

    if (!mail.ok) {
      const detail = await mail.text();
      console.error("Email send failed:", mail.status, detail);
      failed.push(bot.id);
      continue;
    }

    const { error: markError } = await supabase
      .from("botvote_bots")
      .update({ notification_sent_at: new Date().toISOString() })
      .eq("id", bot.id)
      .is("notification_sent_at", null);

    if (markError) {
      console.error("Email sent but notification marker failed:", bot.id, markError.message);
      failed.push(bot.id);
    } else {
      notified++;
    }
  }

  return Response.json({ ok: failed.length === 0, notified, failed_count: failed.length }, { headers: corsHeaders });
});

function escapeHtml(value: unknown): string {
  return String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[char]!);
}

import React, { useEffect, useState } from "react";
import { supabase } from "./supabase.js";

/* ============================================================
   WorkLink Web Dashboard — PRD §15 (Employer) + §18 (Admin Portal)
   Auth: Supabase email magic link (admin/staff accounts).
   Data: KPI RPC, verification queue RPC, jobs & escrow tables.
   ============================================================ */

export default function App() {
  const [session, setSession] = useState(null);
  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => sub.subscription.unsubscribe();
  }, []);
  return session ? <Dashboard /> : <Login />;
}

function Login() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [error, setError] = useState(null);

  const send = async () => {
    const { error } = await supabase.auth.signInWithOtp({ email });
    error ? setError(error.message) : setSent(true);
  };

  return (
    <div className="login">
      <div style={{ fontWeight: 900, fontSize: 22 }}>
        Work<span style={{ color: "var(--copper)" }}>Link</span> dashboard
      </div>
      <p className="muted">Sign in with your staff email. A magic link will be sent.</p>
      {sent ? (
        <p>Check your inbox — click the link to sign in.</p>
      ) : (
        <>
          <input
            type="email"
            placeholder="you@worklink.co.zm"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
          <button className="btn" style={{ width: "100%" }} onClick={send}>
            Send magic link
          </button>
          {error && <p style={{ color: "var(--red)", fontSize: 13 }}>{error}</p>}
        </>
      )}
    </div>
  );
}

const PAGES = ["Overview", "Verification", "Jobs", "Payments"];

function Dashboard() {
  const [page, setPage] = useState("Overview");
  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="logo">Work<span>Link</span></div>
        {PAGES.map((p) => (
          <button key={p} className={page === p ? "active" : ""} onClick={() => setPage(p)}>
            {p}
          </button>
        ))}
        <button onClick={() => supabase.auth.signOut()} style={{ marginTop: 30 }}>
          Sign out
        </button>
      </aside>
      <main className="main">
        {page === "Overview" && <Overview />}
        {page === "Verification" && <VerificationQueue />}
        {page === "Jobs" && <Jobs />}
        {page === "Payments" && <Payments />}
      </main>
    </div>
  );
}

/* ---------------- Overview: PRD §20 KPIs ---------------- */
function Overview() {
  const [kpis, setKpis] = useState(null);
  const [error, setError] = useState(null);
  useEffect(() => {
    supabase.rpc("get_platform_kpis").then(({ data, error }) => {
      if (error) setError(error.message);
      else setKpis(data?.[0] ?? null);
    });
  }, []);

  if (error) return <Note text={`Could not load KPIs: ${error}. Is your account role set to 'admin' in profiles?`} />;
  if (!kpis) return <Note text="Loading platform metrics…" />;

  const items = [
    ["Registered workers", kpis.registered_workers],
    ["Verified workers", kpis.verified_workers],
    ["Employers", kpis.registered_employers],
    ["Jobs posted", kpis.jobs_posted],
    ["Jobs completed", kpis.jobs_completed],
    ["Payment volume", `ZMW ${Number(kpis.payment_volume_zmw).toLocaleString()}`],
    ["Average rating", `${kpis.avg_rating} ★`],
    ["Open disputes", kpis.open_disputes],
  ];
  return (
    <>
      <h1>Platform overview</h1>
      <div className="kpis">
        {items.map(([label, value]) => (
          <div className="kpi" key={label}>
            <div className="label">{label}</div>
            <div className="value mono">{value}</div>
          </div>
        ))}
      </div>
    </>
  );
}

/* ---------------- Verification queue (PRD §18) ---------------- */
function VerificationQueue() {
  const [rows, setRows] = useState([]);
  const load = () =>
    supabase.rpc("verification_queue").then(({ data }) => setRows(data ?? []));
  useEffect(() => { load(); }, []);

  const approve = async (id) => {
    await supabase.rpc("approve_nrc", { p_worker_id: id });
    load();
  };

  return (
    <>
      <h1>NRC verification queue</h1>
      {rows.length === 0 ? (
        <Note text="No workers awaiting NRC verification." />
      ) : (
        <table>
          <thead>
            <tr><th>Name</th><th>Phone</th><th>NRC</th><th>Town</th><th>Registered</th><th /></tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.worker_id}>
                <td>{r.full_name}</td>
                <td className="mono">{r.phone}</td>
                <td className="mono">{r.nrc_number}</td>
                <td>{r.town}</td>
                <td>{new Date(r.created_at).toLocaleDateString()}</td>
                <td>
                  <button className="btn copper" onClick={() => approve(r.worker_id)}>
                    Approve → L2
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </>
  );
}

/* ---------------- Jobs ---------------- */
function Jobs() {
  const [rows, setRows] = useState([]);
  useEffect(() => {
    supabase
      .from("jobs")
      .select("id, title, town, status, budget_zmw, workers_needed, created_at")
      .order("created_at", { ascending: false })
      .limit(100)
      .then(({ data }) => setRows(data ?? []));
  }, []);
  return (
    <>
      <h1>Jobs</h1>
      <table>
        <thead>
          <tr><th>Title</th><th>Town</th><th>Workers</th><th>Budget</th><th>Status</th><th>Posted</th></tr>
        </thead>
        <tbody>
          {rows.map((j) => (
            <tr key={j.id}>
              <td>{j.title}</td>
              <td>{j.town}</td>
              <td>{j.workers_needed}</td>
              <td className="mono">ZMW {Number(j.budget_zmw).toLocaleString()}</td>
              <td><span className="badge">{j.status}</span></td>
              <td>{new Date(j.created_at).toLocaleDateString()}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  );
}

/* ---------------- Payments / escrow ---------------- */
function Payments() {
  const [rows, setRows] = useState([]);
  useEffect(() => {
    supabase
      .from("escrow_transactions")
      .select("id, job_id, amount_zmw, provider, status, funded_at, released_at")
      .order("created_at", { ascending: false })
      .limit(100)
      .then(({ data }) => setRows(data ?? []));
  }, []);
  return (
    <>
      <h1>Escrow payments</h1>
      <table>
        <thead>
          <tr><th>Escrow</th><th>Amount</th><th>Provider</th><th>Status</th><th>Funded</th><th>Released</th></tr>
        </thead>
        <tbody>
          {rows.map((t) => (
            <tr key={t.id}>
              <td className="mono">{t.id.slice(0, 8)}…</td>
              <td className="mono">ZMW {Number(t.amount_zmw).toLocaleString()}</td>
              <td>{t.provider}</td>
              <td><span className="badge">{t.status}</span></td>
              <td>{t.funded_at ? new Date(t.funded_at).toLocaleString() : "—"}</td>
              <td>{t.released_at ? new Date(t.released_at).toLocaleString() : "—"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  );
}

function Note({ text }) {
  return <p className="muted">{text}</p>;
}

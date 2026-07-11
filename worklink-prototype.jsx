import React, { useState, useEffect } from "react";

/* ============================================================
   WorkLink — Interactive Prototype (Phase 1 flows from PRD v1.0)
   Worker side: dashboard, availability, profile + Digital Work Passport
   Employer side: post job → AI matching → hire → chat → escrow → complete → rate
   Design: Zambian copper (trust) + deep forest green (growth), utility type
   ============================================================ */

const T = {
  bg: "#F4F5F0",
  card: "#FFFFFF",
  ink: "#152119",
  inkSoft: "#4C5A50",
  green: "#1E5631",
  greenDeep: "#123A21",
  copper: "#B06F35",
  copperLight: "#E8D3BC",
  line: "#DDE1D8",
  red: "#B3402A",
};

const FONT_LINK = "https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@75..125,400..900&family=IBM+Plex+Mono:wght@400;500;600&display=swap";

const SKILLS = ["Bricklaying","Plumbing","Electrical","Painting","Welding","Carpentry","Cleaning","Domestic work","Security","Driving","Agriculture","Mechanics","Tailoring","Beauty services","ICT support","Food services","Moving services","General labour"];

const AVAIL_OPTIONS = ["Available now","Available today","Available tomorrow","This week","Busy","Offline"];

const WORKERS = [
  { id: 1, name: "Moses Banda", skill: "Bricklaying", skills: ["Bricklaying","General labour"], town: "Kitwe", km: 3.2, rating: 4.9, jobs: 142, level: 5, years: 8, day: 350, avail: "Available now", response: "~4 min", repeat: 62, langs: ["Bemba","English"], bio: "Master bricklayer with 8 years on residential and commercial sites across the Copperbelt. Known for straight courses, clean joints and finishing on schedule." },
  { id: 2, name: "Joseph Tembo", skill: "Bricklaying", skills: ["Bricklaying","Plumbing"], town: "Kitwe", km: 6.8, rating: 4.6, jobs: 87, level: 4, years: 5, day: 300, avail: "Available today", response: "~12 min", repeat: 41, langs: ["Bemba","English"], bio: "Reliable bricklayer and plumber. Comfortable reading simple plans and working in small teams." },
  { id: 3, name: "Emmanuel Mwansa", skill: "Bricklaying", skills: ["Bricklaying","Welding"], town: "Ndola", km: 14.5, rating: 4.4, jobs: 39, level: 3, years: 3, day: 260, avail: "Available tomorrow", response: "~30 min", repeat: 18, langs: ["Bemba"], bio: "Hardworking bricklayer building his record on WorkLink. Strong on foundations and blockwork." },
  { id: 4, name: "Patrick Chola", skill: "Bricklaying", skills: ["Bricklaying"], town: "Kitwe", km: 4.1, rating: 4.2, jobs: 21, level: 2, years: 2, day: 240, avail: "Available now", response: "~25 min", repeat: 10, langs: ["Bemba","Nyanja"], bio: "Energetic young bricklayer, quick to respond and eager for repeat work." },
  { id: 5, name: "Grace Mulenga", skill: "Cleaning", skills: ["Cleaning","Domestic work"], town: "Lusaka", km: 2.1, rating: 4.8, jobs: 210, level: 5, years: 6, day: 220, avail: "Available now", response: "~3 min", repeat: 74, langs: ["Nyanja","English"], bio: "Trusted domestic professional serving households across Lusaka. Repeat-employer favourite." },
  { id: 6, name: "Chanda Phiri", skill: "Electrical", skills: ["Electrical","ICT support"], town: "Lusaka", km: 5.4, rating: 4.7, jobs: 96, level: 4, years: 7, day: 420, avail: "Available today", response: "~8 min", repeat: 55, langs: ["English","Bemba"], bio: "Certified electrician for wiring, DB boards and solar installs. Safety-first workmanship." },
  { id: 7, name: "Beatrice Zulu", skill: "Tailoring", skills: ["Tailoring"], town: "Lusaka", km: 3.8, rating: 4.9, jobs: 173, level: 5, years: 10, day: 280, avail: "This week", response: "~10 min", repeat: 68, langs: ["Nyanja","English"], bio: "Seamstress specialising in uniforms, chitenge wear and alterations. Ten years of five-star finishes." },
  { id: 8, name: "David Sakala", skill: "Driving", skills: ["Driving","Moving services"], town: "Lusaka", km: 7.9, rating: 4.7, jobs: 118, level: 4, years: 9, day: 380, avail: "Available now", response: "~6 min", repeat: 50, langs: ["English","Nyanja","Tonga"], bio: "Professional driver, clean licence classes B and C. Moves, deliveries and site transport." },
];

const ME = {
  name: "Kelvin Mwape",
  skill: "Carpentry",
  town: "Lusaka",
  level: 4,
  rating: 4.8,
  jobs: 64,
  earnedMonth: 6840,
  wallet: 1420,
  trust: 86,
  passport: [
    { employer: "Chirundu Builders Ltd", what: "Roof trusses — 3-bed house", where: "Chalala, Lusaka", days: 4, paid: 1600, rating: 5, date: "28 Jun 2026" },
    { employer: "Mrs. N. Lungu", what: "Fitted kitchen units", where: "Woodlands", days: 6, paid: 2400, rating: 5, date: "14 Jun 2026" },
    { employer: "St. Agnes School", what: "Repair 22 classroom desks", where: "Libala", days: 2, paid: 900, rating: 4, date: "02 Jun 2026" },
  ],
};

const PAY_METHODS = ["MTN MoMo", "Airtel Money", "Zamtel Money", "Bank transfer"];

/* ---------- matching engine (mirrors PRD ranking factors) ---------- */
function scoreWorker(w, job) {
  const s = {};
  s.skills = w.skills.includes(job.skill) ? 30 : 5;
  s.distance = Math.max(0, 20 - w.km);
  s.rating = w.rating * 4;
  s.availability = w.avail === "Available now" ? 12 : w.avail === "Available today" ? 9 : w.avail === "Available tomorrow" ? 6 : 2;
  s.verification = w.level * 2.5;
  s.repeat = w.repeat / 10;
  s.total = Math.round(s.skills + s.distance + s.rating + s.availability + s.verification + s.repeat);
  return s;
}

/* ---------- small pieces ---------- */
const zmw = (n) => "ZMW " + n.toLocaleString("en-ZM");

function TrustSeal({ level, size = 34 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: "50%",
      background: `conic-gradient(${T.copper} ${level * 20}%, ${T.copperLight} 0)`,
      display: "grid", placeItems: "center", flexShrink: 0,
    }} title={`Verification level ${level} of 5`}>
      <div style={{
        width: size - 8, height: size - 8, borderRadius: "50%", background: T.card,
        display: "grid", placeItems: "center",
        fontFamily: "'IBM Plex Mono', monospace", fontSize: size * 0.34, fontWeight: 600, color: T.copper,
      }}>L{level}</div>
    </div>
  );
}

function Stars({ v }) {
  return <span style={{ color: T.copper, letterSpacing: 1 }}>{"★".repeat(Math.round(v))}<span style={{ color: T.line }}>{"★".repeat(5 - Math.round(v))}</span></span>;
}

function Chip({ children, active, onClick }) {
  return (
    <button onClick={onClick} style={{
      padding: "7px 12px", borderRadius: 999, cursor: onClick ? "pointer" : "default",
      border: `1px solid ${active ? T.green : T.line}`,
      background: active ? T.green : T.card, color: active ? "#fff" : T.inkSoft,
      fontSize: 12.5, fontFamily: "inherit",
    }}>{children}</button>
  );
}

function Btn({ children, onClick, kind = "primary", full, disabled, small }) {
  const styles = {
    primary: { background: disabled ? "#9DB3A4" : T.green, color: "#fff", border: "none" },
    copper: { background: T.copper, color: "#fff", border: "none" },
    ghost: { background: "transparent", color: T.green, border: `1.5px solid ${T.green}` },
    danger: { background: "transparent", color: T.red, border: `1.5px solid ${T.red}` },
  }[kind];
  return (
    <button onClick={disabled ? undefined : onClick} style={{
      ...styles, width: full ? "100%" : "auto",
      padding: small ? "8px 14px" : "13px 18px", borderRadius: 12,
      fontSize: small ? 13 : 15, fontWeight: 600, fontFamily: "inherit",
      cursor: disabled ? "not-allowed" : "pointer",
    }}>{children}</button>
  );
}

function Section({ label, children, right }) {
  return (
    <div style={{ marginBottom: 22 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 10 }}>
        <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.5, textTransform: "uppercase", color: T.inkSoft }}>{label}</div>
        {right}
      </div>
      {children}
    </div>
  );
}

function Card({ children, onClick, pad = 16 }) {
  return (
    <div onClick={onClick} style={{
      background: T.card, border: `1px solid ${T.line}`, borderRadius: 16,
      padding: pad, cursor: onClick ? "pointer" : "default",
    }}>{children}</div>
  );
}

/* ============================================================ APP */
export default function WorkLinkApp() {
  const [role, setRole] = useState("employer"); // employer | worker
  const [screen, setScreen] = useState("home");
  const [job, setJob] = useState({ title: "", skill: "Bricklaying", workers: 4, town: "Kitwe", date: "Tomorrow", days: 2, budget: 3000, notes: "" });
  const [posted, setPosted] = useState(null);
  const [hired, setHired] = useState([]);
  const [escrow, setEscrow] = useState("none"); // none | funded | released
  const [payMethod, setPayMethod] = useState(PAY_METHODS[0]);
  const [chat, setChat] = useState([]);
  const [chatInput, setChatInput] = useState("");
  const [workerDone, setWorkerDone] = useState(false);
  const [employerConfirmed, setEmployerConfirmed] = useState(false);
  const [ratingGiven, setRatingGiven] = useState(0);
  const [myAvail, setMyAvail] = useState("Available now");
  const [toast, setToast] = useState(null);

  useEffect(() => {
    const l = document.createElement("link");
    l.rel = "stylesheet"; l.href = FONT_LINK;
    document.head.appendChild(l);
    return () => document.head.removeChild(l);
  }, []);

  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(null), 2600);
    return () => clearTimeout(t);
  }, [toast]);

  const notify = (msg) => setToast(msg);

  const resetHireFlow = () => {
    setHired([]); setEscrow("none"); setChat([]); setWorkerDone(false);
    setEmployerConfirmed(false); setRatingGiven(0);
  };

  const postJob = () => {
    setPosted({ ...job });
    resetHireFlow();
    setScreen("matches");
    notify("Job posted — matching workers near " + job.town);
  };

  const hire = (w) => {
    if (hired.find((h) => h.id === w.id)) return;
    const next = [...hired, w];
    setHired(next);
    setChat((c) => [...c, { from: "them", who: w.name, text: `Muli bwanji! I accept the job — ${job.title || job.skill}, ${job.date} in ${job.town}. I will be there by 07:00.` }]);
    notify(w.name + " hired");
  };

  const sendChat = () => {
    if (!chatInput.trim()) return;
    setChat((c) => [...c, { from: "me", text: chatInput.trim() }]);
    setChatInput("");
    setTimeout(() => setChat((c) => [...c, { from: "them", who: hired[0]?.name || "Worker", text: "Noted, thank you. See you on site." }]), 700);
  };

  const matches = posted
    ? WORKERS.map((w) => ({ w, s: scoreWorker(w, posted) })).sort((a, b) => b.s.total - a.s.total)
    : [];

  /* ---------------- shared shell ---------------- */
  return (
    <div style={{ minHeight: "100vh", background: T.bg, display: "flex", justifyContent: "center", fontFamily: "'Archivo', system-ui, sans-serif", color: T.ink }}>
      <div style={{ width: "100%", maxWidth: 430, minHeight: "100vh", display: "flex", flexDirection: "column", background: T.bg, position: "relative" }}>

        {/* header */}
        <div style={{ background: T.greenDeep, color: "#fff", padding: "18px 18px 14px" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <div>
              <div style={{ fontWeight: 900, fontSize: 22, letterSpacing: -0.5, fontStretch: "125%" }}>
                Work<span style={{ color: T.copper }}>Link</span>
              </div>
              <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 10, letterSpacing: 1.5, opacity: 0.75, textTransform: "uppercase" }}>Trusted work · Zambia</div>
            </div>
            {/* role switch */}
            <div style={{ display: "flex", background: "rgba(255,255,255,0.12)", borderRadius: 999, padding: 3 }}>
              {["employer", "worker"].map((r) => (
                <button key={r} onClick={() => { setRole(r); setScreen("home"); }} style={{
                  padding: "6px 13px", borderRadius: 999, border: "none", cursor: "pointer",
                  fontSize: 12, fontWeight: 600, fontFamily: "inherit",
                  background: role === r ? T.copper : "transparent",
                  color: role === r ? "#fff" : "rgba(255,255,255,0.75)",
                }}>{r === "employer" ? "Employer" : "Worker"}</button>
              ))}
            </div>
          </div>
        </div>

        {/* body */}
        <div style={{ flex: 1, overflowY: "auto", padding: 18, paddingBottom: 90 }}>
          {role === "employer" ? (
            <>
              {screen === "home" && <EmployerHome onPost={() => setScreen("post")} posted={posted} hired={hired} goJob={() => setScreen("jobDetail")} />}
              {screen === "post" && <PostJob job={job} setJob={setJob} onSubmit={postJob} onBack={() => setScreen("home")} />}
              {screen === "matches" && <Matches matches={matches} posted={posted} hired={hired} hire={hire} onProceed={() => setScreen("jobDetail")} />}
              {screen === "jobDetail" && (
                <JobDetail
                  posted={posted} hired={hired} escrow={escrow} setEscrow={setEscrow}
                  payMethod={payMethod} setPayMethod={setPayMethod}
                  chat={chat} chatInput={chatInput} setChatInput={setChatInput} sendChat={sendChat}
                  workerDone={workerDone} setWorkerDone={setWorkerDone}
                  employerConfirmed={employerConfirmed} setEmployerConfirmed={setEmployerConfirmed}
                  ratingGiven={ratingGiven} setRatingGiven={setRatingGiven}
                  notify={notify} onBack={() => setScreen("matches")}
                />
              )}
            </>
          ) : (
            <>
              {screen === "home" && <WorkerDashboard myAvail={myAvail} setMyAvail={setMyAvail} goProfile={() => setScreen("passport")} posted={posted} hired={hired} workerDone={workerDone} setWorkerDone={setWorkerDone} escrow={escrow} notify={notify} />}
              {screen === "passport" && <Passport onBack={() => setScreen("home")} />}
            </>
          )}
        </div>

        {/* bottom nav */}
        <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, background: T.card, borderTop: `1px solid ${T.line}`, display: "flex", padding: "10px 8px calc(10px + env(safe-area-inset-bottom))" }}>
          {(role === "employer"
            ? [["home", "Home"], ["post", "Post a job"], ["matches", "Matches"], ["jobDetail", "Active job"]]
            : [["home", "Dashboard"], ["passport", "Work Passport"]]
          ).map(([key, label]) => (
            <button key={key} onClick={() => setScreen(key)} style={{
              flex: 1, background: "none", border: "none", cursor: "pointer", fontFamily: "inherit",
              fontSize: 11.5, fontWeight: screen === key ? 700 : 500,
              color: screen === key ? T.green : T.inkSoft, padding: 6,
              borderTop: screen === key ? `2.5px solid ${T.copper}` : "2.5px solid transparent",
            }}>{label}</button>
          ))}
        </div>

        {/* toast */}
        {toast && (
          <div style={{
            position: "absolute", bottom: 74, left: 18, right: 18, background: T.ink, color: "#fff",
            borderRadius: 12, padding: "12px 16px", fontSize: 13.5, textAlign: "center", zIndex: 40,
          }}>{toast}</div>
        )}
      </div>
    </div>
  );
}

/* ============================================================ EMPLOYER */
function EmployerHome({ onPost, posted, hired, goJob }) {
  return (
    <>
      <h1 style={{ fontSize: 26, fontWeight: 900, margin: "4px 0 4px", letterSpacing: -0.5 }}>Find trusted workers, fast.</h1>
      <p style={{ color: T.inkSoft, fontSize: 14, marginTop: 0, marginBottom: 20 }}>
        Every worker is verified with NRC and face ID, ranked by real completed jobs — and paid through escrow only when the work is done.
      </p>

      <Btn full onClick={onPost}>Post a job</Btn>

      {posted && (
        <div style={{ marginTop: 22 }}>
          <Section label="Active job">
            <Card onClick={goJob}>
              <div style={{ fontWeight: 700, fontSize: 15 }}>{posted.title || `${posted.workers} × ${posted.skill}`}</div>
              <div style={{ color: T.inkSoft, fontSize: 13, marginTop: 4 }}>
                {posted.town} · {posted.date} · {posted.days} day{posted.days > 1 ? "s" : ""} · {zmw(posted.budget)}
              </div>
              <div style={{ marginTop: 8, fontSize: 12.5, color: T.green, fontWeight: 600 }}>
                {hired.length} of {posted.workers} hired — tap to manage →
              </div>
            </Card>
          </Section>
        </div>
      )}

      <div style={{ marginTop: 24 }}>
        <Section label="Nearby verified workers">
          {WORKERS.slice(0, 4).map((w) => (
            <div key={w.id} style={{ marginBottom: 10 }}>
              <Card>
                <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
                  <TrustSeal level={w.level} />
                  <div style={{ flex: 1 }}>
                    <div style={{ fontWeight: 700, fontSize: 14.5 }}>{w.name}</div>
                    <div style={{ fontSize: 12.5, color: T.inkSoft }}>{w.skill} · {w.town} · {w.km} km</div>
                  </div>
                  <div style={{ textAlign: "right" }}>
                    <div style={{ fontSize: 13 }}><Stars v={w.rating} /></div>
                    <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.inkSoft }}>{w.jobs} jobs</div>
                  </div>
                </div>
              </Card>
            </div>
          ))}
        </Section>
      </div>
    </>
  );
}

function Field({ label, children }) {
  return (
    <div style={{ marginBottom: 14 }}>
      <div style={{ fontSize: 12.5, fontWeight: 600, color: T.inkSoft, marginBottom: 6 }}>{label}</div>
      {children}
    </div>
  );
}

const inputStyle = {
  width: "100%", boxSizing: "border-box", padding: "12px 13px", borderRadius: 12,
  border: `1px solid ${T.line}`, background: T.card, fontSize: 14.5, fontFamily: "inherit", color: T.ink,
};

function PostJob({ job, setJob, onSubmit, onBack }) {
  const set = (k, v) => setJob({ ...job, [k]: v });
  return (
    <>
      <button onClick={onBack} style={{ background: "none", border: "none", color: T.green, fontFamily: "inherit", fontSize: 13.5, fontWeight: 600, padding: 0, marginBottom: 10, cursor: "pointer" }}>← Back</button>
      <h2 style={{ fontSize: 22, fontWeight: 900, margin: "0 0 14px" }}>Post a job</h2>

      <Field label="Job title">
        <input style={inputStyle} placeholder={`e.g. Need ${job.workers} ${job.skill.toLowerCase()}s`} value={job.title} onChange={(e) => set("title", e.target.value)} />
      </Field>

      <Field label="Skill required">
        <div style={{ display: "flex", flexWrap: "wrap", gap: 7 }}>
          {SKILLS.slice(0, 10).map((s) => <Chip key={s} active={job.skill === s} onClick={() => set("skill", s)}>{s}</Chip>)}
        </div>
      </Field>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
        <Field label="Workers needed">
          <input type="number" min={1} style={inputStyle} value={job.workers} onChange={(e) => set("workers", +e.target.value || 1)} />
        </Field>
        <Field label="Duration (days)">
          <input type="number" min={1} style={inputStyle} value={job.days} onChange={(e) => set("days", +e.target.value || 1)} />
        </Field>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
        <Field label="Location">
          <select style={inputStyle} value={job.town} onChange={(e) => set("town", e.target.value)}>
            {["Kitwe", "Lusaka", "Ndola", "Livingstone", "Chipata"].map((t) => <option key={t}>{t}</option>)}
          </select>
        </Field>
        <Field label="Start date">
          <select style={inputStyle} value={job.date} onChange={(e) => set("date", e.target.value)}>
            {["Today", "Tomorrow", "This week", "Next week"].map((d) => <option key={d}>{d}</option>)}
          </select>
        </Field>
      </div>

      <Field label={`Budget — ${zmw(job.budget)}`}>
        <input type="range" min={500} max={20000} step={100} value={job.budget} onChange={(e) => set("budget", +e.target.value)} style={{ width: "100%", accentColor: T.copper }} />
      </Field>

      <Field label="Notes (optional)">
        <textarea style={{ ...inputStyle, minHeight: 70, resize: "vertical" }} placeholder="Site details, tools provided, transport…" value={job.notes} onChange={(e) => set("notes", e.target.value)} />
      </Field>

      <Btn full onClick={onSubmit}>Find matching workers</Btn>
    </>
  );
}

function Matches({ matches, posted, hired, hire, onProceed }) {
  const [open, setOpen] = useState(null);
  if (!posted) return <EmptyState text="Post a job first — the matching engine ranks workers by skills, distance, rating, availability, verification and repeat-hire rate." />;
  return (
    <>
      <h2 style={{ fontSize: 20, fontWeight: 900, margin: "0 0 4px" }}>{posted.title || `${posted.workers} × ${posted.skill}`}</h2>
      <div style={{ color: T.inkSoft, fontSize: 13, marginBottom: 14 }}>
        {posted.town} · {posted.date} · {zmw(posted.budget)} — ranked by AI match score
      </div>

      {matches.map(({ w, s }, i) => {
        const isHired = hired.find((h) => h.id === w.id);
        return (
          <div key={w.id} style={{ marginBottom: 10 }}>
            <Card>
              <div style={{ display: "flex", gap: 12 }}>
                <TrustSeal level={w.level} size={40} />
                <div style={{ flex: 1 }}>
                  <div style={{ display: "flex", justifyContent: "space-between" }}>
                    <div style={{ fontWeight: 700, fontSize: 15 }}>{i + 1}. {w.name}</div>
                    <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 13, fontWeight: 600, color: s.skills > 10 ? T.green : T.inkSoft }}>{s.total} pts</div>
                  </div>
                  <div style={{ fontSize: 12.5, color: T.inkSoft, marginTop: 2 }}>
                    {w.skill} · {w.km} km · {w.avail} · responds {w.response}
                  </div>
                  <div style={{ fontSize: 13, marginTop: 4 }}>
                    <Stars v={w.rating} /> <span style={{ color: T.inkSoft, fontSize: 12 }}>{w.rating} · {w.jobs} jobs · {zmw(w.day)}/day</span>
                  </div>
                </div>
              </div>

              <div style={{ display: "flex", gap: 8, marginTop: 12 }}>
                <Btn small kind={isHired ? "ghost" : "primary"} onClick={() => hire(w)} disabled={!!isHired}>{isHired ? "✓ Hired" : "Hire"}</Btn>
                <Btn small kind="ghost" onClick={() => setOpen(open === w.id ? null : w.id)}>{open === w.id ? "Hide score" : "Why this rank?"}</Btn>
              </div>

              {open === w.id && (
                <div style={{ marginTop: 12, borderTop: `1px dashed ${T.line}`, paddingTop: 10 }}>
                  <div style={{ fontSize: 12.5, color: T.inkSoft, marginBottom: 8, fontStyle: "italic" }}>"{w.bio}"</div>
                  {[["Skills match", s.skills, 30], ["Distance", s.distance, 20], ["Rating", s.rating, 20], ["Availability", s.availability, 12], ["Verification", s.verification, 12.5], ["Repeat employers", s.repeat, 8]].map(([lbl, val, max]) => (
                    <div key={lbl} style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 5 }}>
                      <div style={{ width: 110, fontSize: 11.5, color: T.inkSoft }}>{lbl}</div>
                      <div style={{ flex: 1, height: 6, background: T.bg, borderRadius: 3 }}>
                        <div style={{ width: `${Math.min(100, (val / max) * 100)}%`, height: "100%", background: T.copper, borderRadius: 3 }} />
                      </div>
                      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, width: 30, textAlign: "right" }}>{Math.round(val)}</div>
                    </div>
                  ))}
                </div>
              )}
            </Card>
          </div>
        );
      })}

      {hired.length > 0 && (
        <div style={{ position: "sticky", bottom: 0, paddingTop: 8 }}>
          <Btn full kind="copper" onClick={onProceed}>Continue with {hired.length} hired worker{hired.length > 1 ? "s" : ""} →</Btn>
        </div>
      )}
    </>
  );
}

function JobDetail({ posted, hired, escrow, setEscrow, payMethod, setPayMethod, chat, chatInput, setChatInput, sendChat, workerDone, setWorkerDone, employerConfirmed, setEmployerConfirmed, ratingGiven, setRatingGiven, notify, onBack }) {
  if (!posted || hired.length === 0) return <EmptyState text="No active job yet. Post a job and hire from your AI shortlist to manage it here." />;

  const released = escrow === "released";
  const steps = ["Hired", "Escrow funded", "Work complete", "Payment released", "Rated"];
  const stepIdx = released && ratingGiven ? 5 : released ? 4 : workerDone && employerConfirmed ? 3 : escrow === "funded" ? 2 : 1;

  return (
    <>
      <button onClick={onBack} style={{ background: "none", border: "none", color: T.green, fontFamily: "inherit", fontSize: 13.5, fontWeight: 600, padding: 0, marginBottom: 10, cursor: "pointer" }}>← Shortlist</button>
      <h2 style={{ fontSize: 20, fontWeight: 900, margin: "0 0 2px" }}>{posted.title || `${posted.workers} × ${posted.skill}`}</h2>
      <div style={{ color: T.inkSoft, fontSize: 13, marginBottom: 14 }}>{posted.town} · {posted.date} · {zmw(posted.budget)}</div>

      {/* progress */}
      <div style={{ display: "flex", gap: 4, marginBottom: 18 }}>
        {steps.map((st, i) => (
          <div key={st} style={{ flex: 1 }}>
            <div style={{ height: 5, borderRadius: 3, background: i < stepIdx ? T.copper : T.line }} />
            <div style={{ fontSize: 9, color: i < stepIdx ? T.ink : T.inkSoft, marginTop: 4, textAlign: "center" }}>{st}</div>
          </div>
        ))}
      </div>

      <Section label="Hired team">
        {hired.map((w) => (
          <div key={w.id} style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 8 }}>
            <TrustSeal level={w.level} size={28} />
            <div style={{ fontSize: 14, fontWeight: 600 }}>{w.name}</div>
            <div style={{ fontSize: 12, color: T.inkSoft }}>{w.skill} · {zmw(w.day)}/day</div>
          </div>
        ))}
      </Section>

      {/* escrow */}
      <Section label="Escrow payment">
        <Card>
          {escrow === "none" && (
            <>
              <div style={{ fontSize: 13.5, color: T.inkSoft, marginBottom: 10 }}>
                Fund {zmw(posted.budget)} into the WorkLink escrow wallet. Money is only released when both sides confirm the work is complete.
              </div>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 7, marginBottom: 12 }}>
                {PAY_METHODS.map((m) => <Chip key={m} active={payMethod === m} onClick={() => setPayMethod(m)}>{m}</Chip>)}
              </div>
              <Btn full kind="copper" onClick={() => { setEscrow("funded"); notify(`${zmw(posted.budget)} secured in escrow via ${payMethod}`); }}>
                Fund escrow — {zmw(posted.budget)}
              </Btn>
            </>
          )}
          {escrow === "funded" && (
            <div style={{ fontSize: 14 }}>
              <span style={{ color: T.copper, fontWeight: 700 }}>● Held in escrow</span> — {zmw(posted.budget)} via {payMethod}
              <div style={{ fontSize: 12.5, color: T.inkSoft, marginTop: 4 }}>Released automatically when both parties confirm completion.</div>
            </div>
          )}
          {escrow === "released" && (
            <div style={{ fontSize: 14, color: T.green, fontWeight: 700 }}>✓ {zmw(posted.budget)} released to workers</div>
          )}
        </Card>
      </Section>

      {/* completion */}
      {escrow !== "none" && (
        <Section label="Completion">
          <Card>
            <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
              <label style={{ display: "flex", gap: 10, alignItems: "center", fontSize: 14 }}>
                <input type="checkbox" checked={workerDone} onChange={(e) => setWorkerDone(e.target.checked)} disabled={released} style={{ accentColor: T.green, width: 18, height: 18 }} />
                Worker marked job complete <span style={{ fontSize: 11, color: T.inkSoft }}>(simulate)</span>
              </label>
              <label style={{ display: "flex", gap: 10, alignItems: "center", fontSize: 14 }}>
                <input type="checkbox" checked={employerConfirmed} onChange={(e) => setEmployerConfirmed(e.target.checked)} disabled={!workerDone || released} style={{ accentColor: T.green, width: 18, height: 18 }} />
                I confirm the work is complete
              </label>
              {workerDone && employerConfirmed && !released && (
                <Btn full onClick={() => { setEscrow("released"); notify("Payment released · work history updated"); }}>Release {zmw(posted.budget)} from escrow</Btn>
              )}
            </div>
          </Card>
        </Section>
      )}

      {/* rating */}
      {released && (
        <Section label="Rate the team">
          <Card>
            <div style={{ display: "flex", gap: 6, fontSize: 30, cursor: "pointer" }}>
              {[1, 2, 3, 4, 5].map((n) => (
                <span key={n} onClick={() => { setRatingGiven(n); notify("Rating saved to each worker's Digital Work Passport"); }}
                  style={{ color: n <= ratingGiven ? T.copper : T.line }}>★</span>
              ))}
            </div>
            {ratingGiven > 0 && <div style={{ fontSize: 12.5, color: T.green, marginTop: 6, fontWeight: 600 }}>Saved — this job is now a permanent entry in each worker's passport.</div>}
          </Card>
        </Section>
      )}

      {/* chat */}
      <Section label="Secure chat">
        <Card pad={12}>
          <div style={{ maxHeight: 190, overflowY: "auto", display: "flex", flexDirection: "column", gap: 8, marginBottom: 10 }}>
            {chat.length === 0 && <div style={{ fontSize: 12.5, color: T.inkSoft }}>Messages are end-to-end encrypted. Say hello to your team.</div>}
            {chat.map((m, i) => (
              <div key={i} style={{
                alignSelf: m.from === "me" ? "flex-end" : "flex-start",
                background: m.from === "me" ? T.green : T.bg,
                color: m.from === "me" ? "#fff" : T.ink,
                borderRadius: 12, padding: "8px 12px", fontSize: 13.5, maxWidth: "82%",
              }}>
                {m.from === "them" && <div style={{ fontSize: 10.5, fontWeight: 700, color: T.copper, marginBottom: 2 }}>{m.who}</div>}
                {m.text}
              </div>
            ))}
          </div>
          <div style={{ display: "flex", gap: 8 }}>
            <input style={{ ...inputStyle, flex: 1, padding: "10px 12px" }} placeholder="Type a message…" value={chatInput}
              onChange={(e) => setChatInput(e.target.value)} onKeyDown={(e) => e.key === "Enter" && sendChat()} />
            <Btn small onClick={sendChat}>Send</Btn>
          </div>
        </Card>
      </Section>
    </>
  );
}

/* ============================================================ WORKER */
function WorkerDashboard({ myAvail, setMyAvail, goProfile, posted, hired, workerDone, setWorkerDone, escrow, notify }) {
  const invited = posted && hired.length > 0;
  return (
    <>
      <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 16 }}>
        <TrustSeal level={ME.level} size={52} />
        <div>
          <div style={{ fontWeight: 900, fontSize: 20 }}>{ME.name}</div>
          <div style={{ fontSize: 13, color: T.inkSoft }}>{ME.skill} · {ME.town} · <Stars v={ME.rating} /> {ME.rating}</div>
        </div>
      </div>

      {/* trust score signature card */}
      <div style={{
        background: T.greenDeep, borderRadius: 18, padding: 18, color: "#fff", marginBottom: 18,
        backgroundImage: "radial-gradient(circle at 85% 15%, rgba(176,111,53,0.35), transparent 55%)",
      }}>
        <div style={{ display: "flex", justifyContent: "space-between" }}>
          <div>
            <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 10, letterSpacing: 1.5, textTransform: "uppercase", opacity: 0.7 }}>Trust score</div>
            <div style={{ fontSize: 40, fontWeight: 900, lineHeight: 1 }}>{ME.trust}<span style={{ fontSize: 16, opacity: 0.6 }}>/100</span></div>
          </div>
          <div style={{ textAlign: "right" }}>
            <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 10, letterSpacing: 1.5, textTransform: "uppercase", opacity: 0.7 }}>This month</div>
            <div style={{ fontSize: 22, fontWeight: 800, fontFamily: "'IBM Plex Mono', monospace" }}>{zmw(ME.earnedMonth)}</div>
            <div style={{ fontSize: 11.5, opacity: 0.75 }}>{ME.jobs} lifetime jobs · wallet {zmw(ME.wallet)}</div>
          </div>
        </div>
        <div style={{ height: 6, background: "rgba(255,255,255,0.15)", borderRadius: 3, marginTop: 14 }}>
          <div style={{ width: `${ME.trust}%`, height: "100%", background: T.copper, borderRadius: 3 }} />
        </div>
        <div style={{ fontSize: 11.5, marginTop: 8, opacity: 0.8 }}>14 more points unlocks micro-loans and tool financing.</div>
      </div>

      <Section label="My availability">
        <div style={{ display: "flex", flexWrap: "wrap", gap: 7 }}>
          {AVAIL_OPTIONS.map((a) => <Chip key={a} active={myAvail === a} onClick={() => setMyAvail(a)}>{a}</Chip>)}
        </div>
      </Section>

      <Section label="Job invitations">
        {invited ? (
          <Card>
            <div style={{ fontWeight: 700, fontSize: 14.5 }}>{posted.title || `${posted.workers} × ${posted.skill}`}</div>
            <div style={{ fontSize: 13, color: T.inkSoft, marginTop: 3 }}>{posted.town} · {posted.date} · {posted.days} day(s) · budget {zmw(posted.budget)}</div>
            <div style={{ fontSize: 12.5, marginTop: 6, color: escrow !== "none" ? T.green : T.copper, fontWeight: 600 }}>
              {escrow === "released" ? "✓ Paid — added to your Work Passport" : escrow === "funded" ? "● Payment secured in escrow" : "Awaiting escrow funding"}
            </div>
            {escrow === "funded" && !workerDone && (
              <div style={{ marginTop: 10 }}>
                <Btn full small onClick={() => { setWorkerDone(true); notify("Marked complete — waiting for employer confirmation"); }}>Mark job complete</Btn>
              </div>
            )}
          </Card>
        ) : (
          <Card><div style={{ fontSize: 13, color: T.inkSoft }}>No invitations yet. Keep your availability on "Available now" to rank higher in AI matching. (Switch to Employer mode to post a job and see the loop.)</div></Card>
        )}
      </Section>

      <Section label="AI career coach">
        <Card>
          <div style={{ fontSize: 13.5, lineHeight: 1.55 }}>
            <span style={{ fontWeight: 700, color: T.copper }}>Suggestion:</span> Your carpentry day rate ({zmw(320)}) is 9% below the Lusaka market median for Level-4 workers. Uploading 3 more portfolio photos and completing the "Site Safety" course would justify {zmw(360)}/day.
          </div>
        </Card>
      </Section>

      <Btn full kind="ghost" onClick={goProfile}>Open my Digital Work Passport →</Btn>
    </>
  );
}

function Passport({ onBack }) {
  return (
    <>
      <button onClick={onBack} style={{ background: "none", border: "none", color: T.green, fontFamily: "inherit", fontSize: 13.5, fontWeight: 600, padding: 0, marginBottom: 10, cursor: "pointer" }}>← Dashboard</button>

      {/* passport cover */}
      <div style={{
        background: T.greenDeep, borderRadius: 18, padding: "22px 20px", color: "#fff", marginBottom: 16,
        border: `1.5px solid ${T.copper}`,
        backgroundImage: "radial-gradient(circle at 15% 85%, rgba(176,111,53,0.3), transparent 50%)",
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
          <div>
            <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 10, letterSpacing: 2.5, textTransform: "uppercase", color: T.copperLight }}>Digital Work Passport</div>
            <div style={{ fontSize: 24, fontWeight: 900, marginTop: 6 }}>{ME.name}</div>
            <div style={{ fontSize: 13, opacity: 0.85 }}>{ME.skill} · {ME.town}, Zambia</div>
          </div>
          <TrustSeal level={ME.level} size={46} />
        </div>
        <div style={{ display: "flex", gap: 18, marginTop: 16, fontFamily: "'IBM Plex Mono', monospace", fontSize: 12 }}>
          <div><div style={{ opacity: 0.6, fontSize: 10 }}>JOBS</div>{ME.jobs}</div>
          <div><div style={{ opacity: 0.6, fontSize: 10 }}>RATING</div>{ME.rating} ★</div>
          <div><div style={{ opacity: 0.6, fontSize: 10 }}>SINCE</div>2024</div>
          <div><div style={{ opacity: 0.6, fontSize: 10 }}>ID</div>WL-LSK-04471</div>
        </div>
        <div style={{ fontSize: 10.5, opacity: 0.65, marginTop: 12 }}>Owned by the worker, permanently. Verifiable by any employer, bank or insurer.</div>
      </div>

      <Section label="Verified badges">
        <div style={{ display: "flex", flexWrap: "wrap", gap: 7 }}>
          {["Verified Worker", "NRC ✓", "Face ID ✓", "Fast Responder", "50 Jobs Completed", "Repeat Employer Favourite"].map((b) => (
            <span key={b} style={{ background: T.copperLight, color: "#6E421A", borderRadius: 999, padding: "6px 12px", fontSize: 12, fontWeight: 600 }}>{b}</span>
          ))}
        </div>
      </Section>

      <Section label="Stamped work history">
        {ME.passport.map((p, i) => (
          <div key={i} style={{ marginBottom: 10 }}>
            <Card>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, fontSize: 14 }}>{p.what}</div>
                  <div style={{ fontSize: 12.5, color: T.inkSoft, marginTop: 2 }}>{p.employer} · {p.where} · {p.days} days</div>
                  <div style={{ fontSize: 12.5, marginTop: 4 }}><Stars v={p.rating} /> <span style={{ fontFamily: "'IBM Plex Mono', monospace", color: T.inkSoft, fontSize: 11.5 }}>{p.date}</span></div>
                </div>
                <div style={{
                  border: `1.5px dashed ${T.copper}`, color: T.copper, borderRadius: 8, padding: "5px 9px",
                  fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, fontWeight: 600, transform: `rotate(${i % 2 ? 2 : -2}deg)`,
                }}>
                  PAID<br />{zmw(p.paid)}
                </div>
              </div>
            </Card>
          </div>
        ))}
      </Section>

      <Section label="Unlocked financial services">
        <Card>
          {[["Micro-loan eligibility", "Up to " + zmw(4500)], ["Savings wallet", "Active — " + zmw(ME.wallet)], ["Tool financing", "Unlocks at Trust 100"], ["Insurance", "Unlocks at Trust 100"]].map(([k, v]) => (
            <div key={k} style={{ display: "flex", justifyContent: "space-between", padding: "7px 0", borderBottom: `1px solid ${T.bg}`, fontSize: 13.5 }}>
              <span style={{ color: T.inkSoft }}>{k}</span><span style={{ fontWeight: 600, fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5 }}>{v}</span>
            </div>
          ))}
        </Card>
      </Section>
    </>
  );
}

function EmptyState({ text }) {
  return (
    <div style={{ textAlign: "center", padding: "60px 24px", color: T.inkSoft, fontSize: 14, lineHeight: 1.6 }}>
      <div style={{ fontSize: 34, marginBottom: 10 }}>⛏</div>
      {text}
    </div>
  );
}

import { useState, useEffect, useRef } from "react";
import { supabase } from "./supabaseClient.js";

const SESSION_KEY = "dcc_session";

const ROLE_LABEL = { champ: "Champion", dec: "Decision-maker", infl: "Influencer", tech: "Technical", appr: "Approver", risk: "Friction" };
const ROLE_STYLE = {
  champ: { bg: "#E3F0EA", fg: "#167A5B" },
  dec: { bg: "#E7EAF6", fg: "#3a4a8a" },
  infl: { bg: "#F6ECD9", fg: "#9A5B00" },
  tech: { bg: "#E3F0EA", fg: "#167A5B" },
  appr: { bg: "#ECEFF1", fg: "#4a5560" },
  risk: { bg: "#F5E3DE", fg: "#A8331F" },
};

function Check() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="20 6 9 17 4 12" />
    </svg>
  );
}

/* ============================ Login ============================ */
function Login({ onLogin }) {
  const [code, setCode] = useState("");
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);

  const submit = async () => {
    const c = code.trim();
    if (!c) return;
    setBusy(true);
    setErr("");
    try {
      const { data, error } = await supabase.rpc("login", { p_code: c });
      if (error) throw error;
      if (data && data.length > 0) {
        onLogin({ code: c, name: data[0].name, role: data[0].role });
      } else {
        setErr("That code didn't match. Try again.");
      }
    } catch (e) {
      setErr("Couldn't reach the server. Check your connection.");
      console.error(e);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="login-wrap">
      <div className="login-card">
        <span className="eyebrow">ExaGrid</span>
        <h1>Deal Command Center</h1>
        <p>Enter your access code to continue.</p>
        <input
          value={code}
          onChange={(e) => setCode(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && submit()}
          placeholder="Access code"
          autoFocus
        />
        <button onClick={submit} disabled={busy}>{busy ? "Checking…" : "Enter"}</button>
        <div className="err">{err}</div>
      </div>
    </div>
  );
}

/* ============================ App ============================ */
export default function App() {
  const [user, setUser] = useState(null);
  const [deals, setDeals] = useState([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState("dashboard");
  const dealsRef = useRef(deals);
  useEffect(() => { dealsRef.current = deals; }, [deals]);

  // restore session
  useEffect(() => {
    try {
      const raw = localStorage.getItem(SESSION_KEY);
      if (raw) setUser(JSON.parse(raw));
    } catch (e) { /* ignore */ }
  }, []);

  const login = (u) => {
    setUser(u);
    try { localStorage.setItem(SESSION_KEY, JSON.stringify(u)); } catch (e) { /* ignore */ }
  };
  const logout = () => {
    setUser(null);
    try { localStorage.removeItem(SESSION_KEY); } catch (e) { /* ignore */ }
  };

  // load deals once logged in
  useEffect(() => {
    if (!user) return;
    let active = true;
    (async () => {
      setLoading(true);
      const { data, error } = await supabase.from("deals").select("*").order("position");
      if (active) {
        if (!error && data) setDeals(data.map((r) => r.body));
        setLoading(false);
      }
    })();
    return () => { active = false; };
  }, [user]);

  // realtime: keep every device in sync
  useEffect(() => {
    if (!user) return;
    const ch = supabase
      .channel("deals-rt")
      .on("postgres_changes", { event: "*", schema: "public", table: "deals" }, (payload) => {
        if (payload.eventType === "DELETE") {
          setDeals((prev) => prev.filter((d) => d.id !== payload.old.id));
          return;
        }
        const body = payload.new.body;
        if (!body) return;
        setDeals((prev) => {
          const exists = prev.some((d) => d.id === body.id);
          return exists ? prev.map((d) => (d.id === body.id ? body : d)) : [...prev, body];
        });
      })
      .subscribe();
    return () => { supabase.removeChannel(ch); };
  }, [user]);

  // persist one deal's full body
  const persistDeal = (deal, index) => {
    supabase
      .from("deals")
      .upsert({ id: deal.id, position: index, body: deal, updated_at: new Date().toISOString() })
      .then(({ error }) => { if (error) console.error("save failed", error); });
  };

  const mutateDeal = (dealId, fn) => {
    const arr = dealsRef.current;
    const idx = arr.findIndex((d) => d.id === dealId);
    if (idx < 0) return;
    const updated = fn(arr[idx]);
    setDeals(arr.map((d, i) => (i === idx ? updated : d)));
    persistDeal(updated, idx);
  };

  const toggleStep = (dealId, stepId) =>
    mutateDeal(dealId, (d) => ({ ...d, steps: d.steps.map((s) => (s.id === stepId ? { ...s, done: !s.done } : s)) }));
  const addStep = (dealId, step) =>
    mutateDeal(dealId, (d) => ({ ...d, steps: [...d.steps, step] }));
  const delStep = (dealId, stepId) =>
    mutateDeal(dealId, (d) => ({ ...d, steps: d.steps.filter((s) => s.id !== stepId) }));
  const addLog = (dealId, entry) =>
    mutateDeal(dealId, (d) => ({ ...d, log: [entry, ...d.log] }));

  // notes: update locally on each keystroke, persist on blur
  const setNotesLocal = (dealId, val) =>
    setDeals((prev) => prev.map((d) => (d.id === dealId ? { ...d, notes: val } : d)));
  const commitDeal = (dealId) => {
    const arr = dealsRef.current;
    const idx = arr.findIndex((d) => d.id === dealId);
    if (idx >= 0) persistDeal(arr[idx], idx);
  };

  const openCount = (dl) => (dl.steps || []).filter((s) => !s.done).length;

  if (!user) return <Login onLogin={login} />;

  return (
    <div className="dcc">
      <div className="topbar"><div className="row">
        <span className="brand">ExaGrid · <b>Deal Command Center</b></span>
        <span className="who">
          <span>{user.name}</span>
          <button className="out" onClick={logout}>Sign out</button>
        </span>
      </div></div>

      <div className="wrap">
        {loading ? (
          <p className="mono" style={{ marginTop: 40, color: "#6B7A74" }}>Loading deals…</p>
        ) : (
          <>
            <div className="tabs">
              <button className={"tab" + (tab === "dashboard" ? " active" : "")} onClick={() => setTab("dashboard")}>Dashboard</button>
              {deals.map((dl) => (
                <button key={dl.id} className={"tab" + (tab === dl.id ? " active" : "")} onClick={() => setTab(dl.id)}>
                  {dl.name}{openCount(dl) > 0 && <span className="dot">{openCount(dl)}</span>}
                </button>
              ))}
            </div>

            {tab === "dashboard" ? (
              <Dashboard deals={deals} go={setTab} toggleStep={toggleStep} />
            ) : (
              <DealView
                deal={deals.find((d) => d.id === tab)}
                onToggle={toggleStep}
                onAddStep={addStep}
                onDelStep={delStep}
                onAddLog={addLog}
                onNotes={setNotesLocal}
                onCommit={commitDeal}
              />
            )}

            <footer>
              Live app · synced via Supabase across every device you sign in on. Signed in as {user.name} ({user.role}).
            </footer>
          </>
        )}
      </div>
    </div>
  );
}

/* ============================ Dashboard ============================ */
function Dashboard({ deals, go, toggleStep }) {
  const attention = [];
  deals.forEach((dl) =>
    (dl.steps || []).filter((s) => !s.done).forEach((s) => attention.push({ ...s, dealId: dl.id, dealName: dl.name }))
  );

  const warm = [];
  deals.forEach((dl) =>
    (dl.contactsToWarm || []).forEach((nm) => {
      const sk = (dl.stakeholders || []).find((x) => x.name === nm);
      warm.push({ dealName: dl.name, name: nm, role: sk ? ROLE_LABEL[sk.role] : "" });
    })
  );

  return (
    <>
      <h1>Dashboard</h1>
      <p className="lead-in">Everything that needs a nudge, across every deal. Check items off as you go — it updates the deal and syncs everywhere.</p>

      <section>
        <div className="sec-head"><span className="num">◉</span><h2>Needs your attention</h2></div>
        {attention.length === 0 ? (
          <div className="empty">All clear — no open action items right now.</div>
        ) : (
          <div className="attn">
            {attention.map((a) => (
              <div className="ai" key={a.dealId + a.id}>
                <button className="chk" onClick={() => toggleStep(a.dealId, a.id)} aria-label="Mark done" />
                <div className="txt">{a.what}
                  <div className="sub2">{a.dealName} · {a.owner} · {a.date}</div>
                </div>
                <span className="tag" style={{ background: a.status === "future" ? "#7C8A93" : "var(--accent)" }}>
                  {a.status === "future" ? "Soon" : "Now"}
                </span>
              </div>
            ))}
          </div>
        )}
      </section>

      <section>
        <div className="sec-head"><span className="num">◉</span><h2>People to keep warm</h2></div>
        {warm.length === 0 ? (
          <div className="empty">No key contacts flagged yet.</div>
        ) : (
          <div className="warm">
            {warm.map((w, i) => (
              <span className="pchip" key={i}>
                <b>{w.name}</b>{w.role ? ` — ${w.role}` : ""} <span style={{ color: "var(--muted)" }}>· {w.dealName}</span>
              </span>
            ))}
          </div>
        )}
      </section>

      <section>
        <div className="sec-head"><span className="num">◉</span><h2>Pipeline at a glance</h2></div>
        <div className="dash-grid">
          {deals.map((dl) => (
            <div className="pipe" key={dl.id} onClick={() => go(dl.id)}>
              <h3>{dl.name}</h3>
              <div className="meta">{dl.status} · {dl.stage}</div>
              <div className="stat">
                <div className="s"><div className="n">{(dl.steps || []).filter((s) => !s.done).length}</div><div className="l">Open items</div></div>
                <div className="s"><div className="n" style={{ fontSize: 14, paddingTop: 6 }}>{dl.nextMilestone}</div><div className="l">Next milestone</div></div>
              </div>
            </div>
          ))}
        </div>
      </section>
    </>
  );
}

/* ============================ Deal view ============================ */
function DealView({ deal, onToggle, onAddStep, onDelStep, onAddLog, onNotes, onCommit }) {
  const [task, setTask] = useState("");
  const [owner, setOwner] = useState("");
  const [due, setDue] = useState("");
  const [logTitle, setLogTitle] = useState("");
  const [logBody, setLogBody] = useState("");

  if (!deal) return null;
  const has = (a) => a && a.length > 0;

  const submitStep = () => {
    if (!task.trim()) return;
    onAddStep(deal.id, { id: "u" + Date.now(), what: task.trim(), owner: owner.trim() || "—", date: due.trim() || "—", status: "open", done: false });
    setTask(""); setOwner(""); setDue("");
  };
  const submitLog = () => {
    if (!logTitle.trim() && !logBody.trim()) return;
    const today = new Date().toISOString().slice(0, 10);
    onAddLog(deal.id, { id: "u" + Date.now(), date: today, title: logTitle.trim() || "Update", body: logBody.trim() });
    setLogTitle(""); setLogBody("");
  };

  const isShell = !has(deal.snapshot) && !has(deal.stakeholders) && !has(deal.sizing);
  const n = (base) => (has(deal.snapshot) ? base : base - 6 < 10 ? "0" + (base - 6) : String(base - 6));

  return (
    <>
      <h1>{deal.name}</h1>
      <p className="sub">{deal.subtitle}</p>
      <div className="chips">
        <div className="chip flag"><span className="k">Status</span><span className="v">{deal.status}</span></div>
        <div className="chip"><span className="k">Stage</span><span className="v">{deal.stage}</span></div>
        <div className="chip"><span className="k">Budget cycle</span><span className="v">{deal.budgetCycle}</span></div>
        <div className="chip flag"><span className="k">Next milestone</span><span className="v">{deal.nextMilestone}</span></div>
        <div className="chip"><span className="k">Updated</span><span className="v">{deal.updated}</span></div>
      </div>

      {isShell && (
        <section><div className="empty">
          No intel captured for {deal.name} yet. Add next steps and notes below as you go, or tell Claude what you learn and it'll populate the full profile.
        </div></section>
      )}

      {has(deal.snapshot) && (
        <section>
          <div className="sec-head"><span className="num">01</span><h2>Snapshot</h2></div>
          <div className="facts">{deal.snapshot.map((f, i) => (
            <div className="fact" key={i}><div className="k">{f.k}</div><div className="v">{f.v}</div></div>))}</div>
        </section>
      )}

      {has(deal.hierarchy) && (
        <section>
          <div className="sec-head"><span className="num">02</span><h2>Decision hierarchy</h2></div>
          <div className="ladder">
            {deal.hierarchy.map((t, ti) => (
              <div key={ti} style={{ width: "100%", display: "flex", flexDirection: "column", alignItems: "center" }}>
                {ti > 0 && <div className="conn" />}
                <div className="tier">
                  <div className="tier-label">{t.label}</div>
                  {t.nodes.length > 1
                    ? <div className="pair">{t.nodes.map((nd, ni) => <Node key={ni} n={nd} />)}</div>
                    : <Node n={t.nodes[0]} />}
                </div>
              </div>
            ))}
            {deal.winLine && <p className="winline">{deal.winLine}</p>}
          </div>
        </section>
      )}

      {has(deal.stakeholders) && (
        <section>
          <div className="sec-head"><span className="num">03</span><h2>Who's who</h2></div>
          <div className="cards">{deal.stakeholders.map((s, i) => {
            const rs = ROLE_STYLE[s.role] || ROLE_STYLE.appr;
            return (
              <div className={"card" + (s.role === "risk" || s.role === "appr" ? " minor" : "")} key={i}>
                <span className="badge" style={{ background: rs.bg, color: rs.fg }}>{ROLE_LABEL[s.role]}</span>
                <h3>{s.name}</h3><div className="tl">{s.title}</div><p>{s.notes}</p>
              </div>
            );
          })}</div>
        </section>
      )}

      {has(deal.sizing) && (
        <section>
          <div className="sec-head"><span className="num">04</span><h2>Sizing &amp; environment</h2></div>
          <table><tbody>{deal.sizing.map((r, i) => (
            <tr key={i}><th>{r.k}</th><td>{r.v}</td></tr>))}</tbody></table>
        </section>
      )}

      {(has(deal.priorities) || has(deal.fit)) && (
        <section>
          <div className="sec-head"><span className="num">05</span><h2>Buying criteria &amp; where we fit</h2></div>
          <div className="split">
            <div className="panel"><h3>Priorities</h3>
              <ol className="rank">{(deal.priorities || []).map((p, i) => <li key={i} className={i === 0 ? "cost" : ""}>{p}</li>)}</ol>
            </div>
            <div className="panel"><h3>ExaGrid angles</h3>
              <ul className="ticks">{(deal.fit || []).map((p, i) => <li key={i}>{p}</li>)}</ul>
            </div>
          </div>
        </section>
      )}

      {has(deal.competitors) && (
        <section>
          <div className="sec-head"><span className="num">06</span><h2>Competitive landscape</h2></div>
          <div className="comp">{deal.competitors.map((c, i) => (
            <div className="card" key={i}><h3>{c.name}</h3><div className="pos">{c.pos}</div>
              <div className="ctr"><b>Our counter</b>{c.ctr}</div></div>))}</div>
        </section>
      )}

      {/* Next steps - interactive */}
      <section>
        <div className="sec-head"><span className="num">{n(13)}</span><h2>Next steps</h2></div>
        <div className="steplist">
          {(deal.steps || []).length === 0 && (
            <div style={{ padding: "14px 15px", fontSize: 13.5, color: "var(--muted)" }}>No steps yet — add one below.</div>
          )}
          {(deal.steps || []).map((s) => (
            <div className={"step" + (s.done ? " is-done" : "")} key={s.id}>
              <button className={"chk" + (s.done ? " on" : "")} onClick={() => onToggle(deal.id, s.id)} aria-label="Toggle done">{s.done && <Check />}</button>
              <div className="body"><div className="what">{s.what}</div><div className="owner">{s.owner}</div></div>
              <div className="right">
                <span className="date">{s.date}</span>
                <span className={"pill " + (s.done ? "pill--done" : s.status === "future" ? "pill--future" : "pill--open")}>
                  {s.done ? "Done" : s.status === "future" ? "Future" : "Open"}
                </span>
                <button className="del" onClick={() => onDelStep(deal.id, s.id)} aria-label="Delete">×</button>
              </div>
            </div>
          ))}
        </div>
        <div className="addrow">
          <input className="in grow" placeholder="New step…" value={task} onChange={(e) => setTask(e.target.value)} onKeyDown={(e) => e.key === "Enter" && submitStep()} />
          <input className="in sm" placeholder="Owner" value={owner} onChange={(e) => setOwner(e.target.value)} onKeyDown={(e) => e.key === "Enter" && submitStep()} />
          <input className="in sm" placeholder="Due" value={due} onChange={(e) => setDue(e.target.value)} onKeyDown={(e) => e.key === "Enter" && submitStep()} />
          <button className="btn" onClick={submitStep}>Add</button>
        </div>
      </section>

      {/* Notes */}
      <section>
        <div className="sec-head"><span className="num">{n(14)}</span><h2>Notes</h2></div>
        <textarea
          className="in notes"
          placeholder="Anything you want to jot down for this account…"
          value={deal.notes || ""}
          onChange={(e) => onNotes(deal.id, e.target.value)}
          onBlur={() => onCommit(deal.id)}
        />
      </section>

      {/* Log */}
      <section>
        <div className="sec-head"><span className="num">{n(15)}</span><h2>Running log</h2></div>
        {(deal.log || []).map((l) => (
          <div className="logentry" key={l.id}>
            <div className="d">{l.date}</div><div className="t">{l.title}</div>{l.body && <p>{l.body}</p>}
          </div>
        ))}
        <div className="panel" style={{ marginTop: 4 }}>
          <h3>Add a log entry</h3>
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            <input className="in" placeholder="Headline (e.g. Demo with Steve West)" value={logTitle} onChange={(e) => setLogTitle(e.target.value)} />
            <textarea className="in" style={{ minHeight: 70, resize: "vertical" }} placeholder="What happened / what you learned…" value={logBody} onChange={(e) => setLogBody(e.target.value)} />
            <div><button className="btn" onClick={submitLog}>Add entry</button></div>
          </div>
        </div>
      </section>
    </>
  );
}

function Node({ n }) {
  const rs = ROLE_STYLE[n.role] || ROLE_STYLE.appr;
  return (
    <div className={"node" + (n.lead ? " lead" : "")}>
      <span className="badge" style={{ background: rs.bg, color: rs.fg }}>{ROLE_LABEL[n.role]}</span>
      <div className="nm">{n.name}</div>
      <div className="rl">{n.sub}</div>
      <div className="mt">{n.meta}</div>
    </div>
  );
}

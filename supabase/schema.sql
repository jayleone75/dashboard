-- =====================================================================
--  ExaGrid Deal Command Center - Supabase schema
--  Run this once in your Supabase project: SQL Editor -> New query -> paste -> Run
-- =====================================================================

-- ---------- USERS / ACCESS CODES ----------
create table if not exists users (
  code text primary key,
  name text not null,
  role text not null default 'member'
);

-- Lock the table down: it is NOT directly readable by the public anon key.
alter table users enable row level security;
-- (no anon SELECT policy on purpose, so codes can't be dumped)

-- Login is validated through this function only, which can read the table
-- even though the public cannot. Returns the matching user, or nothing.
create or replace function login(p_code text)
returns table(name text, role text)
language sql
security definer
set search_path = public
as $$
  select name, role from users where code = p_code;
$$;

grant execute on function login(text) to anon;

-- ---------- DEALS ----------
create table if not exists deals (
  id text primary key,
  position int not null default 0,
  body jsonb not null,
  updated_at timestamptz not null default now()
);

alter table deals enable row level security;

-- Internal-tool access model: the app gates entry with an access code, and the
-- deal data (prospect notes) lives behind an obscure subdomain. These policies
-- let the signed-in app read/write deals with the anon key. If you ever want
-- bank-grade lockdown, switch to Supabase Auth and key these policies to auth.uid().
drop policy if exists "deals_read"   on deals;
drop policy if exists "deals_insert" on deals;
drop policy if exists "deals_update" on deals;
drop policy if exists "deals_delete" on deals;
create policy "deals_read"   on deals for select using (true);
create policy "deals_insert" on deals for insert with check (true);
create policy "deals_update" on deals for update using (true) with check (true);
create policy "deals_delete" on deals for delete using (true);

-- Realtime so a checkbox ticked on your phone shows on your laptop instantly.
alter publication supabase_realtime add table deals;

-- ---------- SEED: USERS ----------
-- IMPORTANT: change this code before going live. Add more rows for Brad / Doug later.
insert into users (code, name, role) values
  ('CHANGE-ME-JAY', 'Jay Leone', 'owner')
on conflict (code) do nothing;

-- ---------- SEED: DEALS ----------
insert into deals (id, position, body) values
('ross', 0, $json$
{
  "id": "ross",
  "name": "Ross Stores",
  "subtitle": "Tiered backup storage via reseller E360 (Doug Kirsten), riding Ross's NetBackup-to-Cohesity transition.",
  "status": "Active - champion-building",
  "stage": "Qualifying -> POC",
  "budgetCycle": "FY2027 (Jan start)",
  "nextMilestone": "July lunch-and-learn",
  "updated": "Jun 8, 2026",
  "winLine": "Path to the win: Blair + Steve -> Art -> Southworth -> Brent / Curtis if > $1M",
  "snapshot": [
    {"k": "Account", "v": "Ross Stores, Inc. - off-price / discount retail"},
    {"k": "Reseller", "v": "E360 - Doug Kirsten owns the relationship & politics"},
    {"k": "Selling", "v": "ExaGrid as a retention/archive tier & cyber-recovery layer alongside their backup software"},
    {"k": "Why now", "v": "Veritas (now Cohesity) forcing a migration off NetBackup appliances over 6-18 months; retention appliances tapped out"},
    {"k": "Where we play", "v": "OST = drop in as another disk pool, write today. Coexists with Cohesity. No rip-and-replace."},
    {"k": "Deal size", "v": "[TBD] - ~275 TB non-prod starting point referenced"}
  ],
  "hierarchy": [
    {"label": "Executive approval - ~$1M+", "nodes": [
      {"name": "Brent [surname TBD]", "sub": "Senior operations exec", "meta": "Old-school Ross, operations-first. Wants to call the man.", "role": "appr"},
      {"name": "Curtis [surname TBD]", "sub": "Executive approver", "meta": "Signs off on large deals (~$1M+).", "role": "appr"}
    ]},
    {"label": "Decision-maker", "nodes": [
      {"name": "Stephen Southworth", "sub": "EVP, Engineering", "meta": "Relationship/exec-tie driven - golf - ~$150K authority (verify).", "role": "dec"}
    ]},
    {"label": "Influencer", "nodes": [
      {"name": "Arthur Art Anderson", "sub": "Blair's manager", "meta": "Brief Art before Southworth.", "role": "infl"}
    ]},
    {"label": "Champion & technical evaluation", "nodes": [
      {"name": "Blair Johnson", "sub": "Infrastructure Architect", "meta": "Surfaced the opening himself. His job is to dream.", "role": "champ", "lead": true},
      {"name": "Steve West", "sub": "Lead Storage Engineer", "meta": "Loves replication talk -> Brad's deep-dive target.", "role": "tech"}
    ]}
  ],
  "stakeholders": [
    {"name": "Blair Johnson", "title": "Infrastructure Architect", "role": "champ", "notes": "Storage guy at heart (Linux admin, came up through HP/3PAR, did a NetApp all-flash modernization). Day trader, tuned to NVMe/DDR5 pricing. Lived through two ransomware events and built an air-gapped clean room himself - the cyber-vault story lands personally. Contractor since ~Sept 2025."},
    {"name": "Steve West", "title": "Lead Storage Engineer", "role": "tech", "notes": "Works closely with Blair; never tires of replication talk. Brad to lead an ExaGrid-to-ExaGrid replication deep-dive. Win him and he reinforces Blair upward."},
    {"name": "Arthur Art Anderson", "title": "Blair's manager", "role": "infl", "notes": "The gate before Southworth. Lunch-and-learn audience - get Art bought in first."},
    {"name": "Stephen Southworth", "title": "EVP, Engineering", "role": "dec", "notes": "Relationship-first, exec-to-exec ties, plays golf. Historical approval ~$150K (verify current)."},
    {"name": "Curtis & Brent", "title": "Executive / operations approvers (~$1M+)", "role": "appr", "notes": "Brent is old-school, operations-first, terse - ExaGrid's dedicated-support-engineer model fits his call-the-man instinct. Surnames TBD."},
    {"name": "Watch-outs: David & Bob", "title": "Legacy attachments", "role": "risk", "notes": "Prior architect David liked NetBackup. Bob is Veritas-trained - retraining is a perceived switching cost worth defusing."}
  ],
  "sizing": [
    {"k": "Backup software", "v": "Veritas NetBackup (20-yr customer), upgrading 10.5 -> 11; Auto Image Replication. Cohesity migration mandated over 6-18 months."},
    {"k": "Scale (Dec 2025)", "v": "2,297 clients - 38 backup appliances - 5+ PB - 60M+ files. Still doing tape-out."},
    {"k": "Annual volume", "v": "941K app backup jobs - 726K incrementals - 1.26M replications."},
    {"k": "Long-term retention", "v": "Veritas/Access appliances (~2 PB raw each, two of them), tapped out & controller-bound."},
    {"k": "Topology", "v": "Hub-and-spoke. Primary DC Rock Hill, SC; HQ Dublin, CA; DR Philadelphia (11:11/Sungard). SD-WAN project shifting to local egress."},
    {"k": "Business lines", "v": "Buyer's offices - Supply chain/DCs (fluid, ~60-day retention) - Corporate. Retention currently uniform - inefficient."},
    {"k": "Workloads", "v": "Heavy virtualization (some sites 90%) but agent-based, not snapshots. Oracle RAC -> RMAN. Some legacy apps Cohesity may not cover."},
    {"k": "Storage posture", "v": "HPE shop, no object storage today. Wants spinning SAS, not flash - no flash tax, dodges NVMe/DDR5 spike."},
    {"k": "Regulatory", "v": "Light - no HIPAA, no SOX; some PCI. Retention largely self-imposed."},
    {"k": "Initial sizing ref", "v": "~275 TB NetBackup workload for non-prod (held by Eric LaSota - Doug to forward)."}
  ],
  "priorities": [
    "Cost / cost avoidance - #1 by far. Always lead here.",
    "Simplicity - not leading-edge technologists.",
    "Productivity",
    "Ransomware / security protection",
    "Retail references - a follower, not a leader. Marshalls / TJX / Walmart / Home Depot / Nordstrom tier."
  ],
  "fit": [
    "Cost-effective deep retention tier (current tiering isn't working)",
    "Oracle RAC / RMAN backups",
    "Archive for stale unstructured data",
    "Cyber vault / clean-room rebuild - Blair's hot button",
    "Replication (Veritas does cascading replication poorly)",
    "Wedge: OST disk pool today - supports NetBackup IT Analytics - scale-out, no forklift"
  ],
  "competitors": [
    {"name": "Cohesity", "pos": "Incumbent successor; Ross must migrate. But open issues with Ross, wants HCI-at-scale on SpanFS (won't run on the appliances Ross just refreshed), no migration collateral.", "ctr": "Coexist - protect their investment through the transition. No rip-and-replace, no flash tax."},
    {"name": "Rubrik", "pos": "Banging on the door. Blair has run it at scale; likes native immutability.", "ctr": "Be the cost-effective retention / cyber tier behind whatever front-end they pick."},
    {"name": "HPE Electra 4120", "pos": "Cohesity-blessed hardware - the only other storage player Blair has involved.", "ctr": "Very likely cheaper. Lead on cost for a discount retailer."}
  ],
  "steps": [
    {"id": "s1", "what": "Confirm lunch-and-learn is scheduled (July Tuesday; Art first)", "owner": "Doug / Jay", "date": "Wk of Jun 15", "status": "open", "done": false},
    {"id": "s2", "what": "Forward ~275 TB non-prod sizing estimate (held by Eric)", "owner": "Doug -> Brad / Jay", "date": "ASAP", "status": "open", "done": false},
    {"id": "s3", "what": "Share backup-trending deck + NetBackup env notes", "owner": "Blair -> Jay / Brad", "date": "Near-term", "status": "open", "done": false},
    {"id": "s4", "what": "ExaGrid-to-ExaGrid replication deep-dive", "owner": "Brad <-> Steve West", "date": "After L&L", "status": "future", "done": false},
    {"id": "s5", "what": "Ross reference one-pager (off-price / big-box names)", "owner": "Jay", "date": "Before L&L", "status": "open", "done": false},
    {"id": "s6", "what": "Try-and-Buy / POC in non-production first", "owner": "Brad / Doug", "date": "H2 2026", "status": "future", "done": false},
    {"id": "s7", "what": "Position pilot -> FY2027 budget conversation", "owner": "Jay / Doug", "date": "Late 26 / early 27", "status": "future", "done": false}
  ],
  "contactsToWarm": ["Blair Johnson", "Stephen Southworth"],
  "log": [
    {"id": "l1", "date": "2026-06-08", "title": "Intro / state-of-the-union call - Doug, Brad, Blair (Srini double-booked)", "body": "First call with the new deal team (Brad as SC) and Blair as Ross architect. Doug briefed the stakeholder map and buying priorities (cost first, then simplicity/productivity/ransomware, then retail references). Blair detailed the environment and volunteered five ExaGrid use cases. Compelling event confirmed: forced migration off Veritas/NetBackup to Cohesity. Agreed next steps captured in the plan."}
  ],
  "notes": ""
}
$json$::jsonb),
('vsp', 1, $json$
{
  "id": "vsp",
  "name": "VSP",
  "subtitle": "Vision Service Plan - multi-entity vision/eyewear group. Backup consolidation play via reseller ePlus (Kat). Target $15-18M GP.",
  "status": "Active - advisory / discovery",
  "stage": "Discovery / assessment",
  "budgetCycle": "Nasuni renewal Sep 16 2026; F5 renewal Dec 2026",
  "nextMilestone": "Strategy review w/ Kat - Jun 11",
  "updated": "Jun 5, 2026",
  "winLine": "Path in: David Gray (gatekeeper) -> Steve Badondo (global architect) -> broaden to Andrew Lee / Derek Dern / Jamie Stark",
  "snapshot": [
    {"k": "Account", "v": "VSP (Vision Service Plan) - multi-entity vision/eyewear; on-prem across 42 states"},
    {"k": "Reseller", "v": "ePlus - Kat (lead relationship), Ben (proxy); advisory-services-led"},
    {"k": "Selling", "v": "ExaGrid as consolidated, standardized backup/DR + ransomware/HIPAA layer across fragmented entities"},
    {"k": "Opportunity", "v": "Target $15-18M GP across entities; separate ~$4M security deal in pursuit; a PO already awarded"},
    {"k": "Why now", "v": "Nasuni support renewal Sep 16 2026; F5 renewal Dec; 500+ retail sites with unmanaged local backup"},
    {"k": "Approach", "v": "Advisory/assessment-led and consultative - avoid premature product push; embed ExaGrid in the larger deal"}
  ],
  "hierarchy": [
    {"label": "Broader leadership - relationship targets", "nodes": [
      {"name": "Andrew Lee", "sub": "VSP leadership", "meta": "Broaden beyond David to de-risk.", "role": "infl"},
      {"name": "Derek Dern / Jamie Stark", "sub": "VSP leadership", "meta": "Additional senior contacts to cultivate.", "role": "infl"}
    ]},
    {"label": "Global architect - multi-entity influence", "nodes": [
      {"name": "Steve Badondo", "sub": "Senior global architect", "meta": "Influences multiple entities; leads the Italy (acquisition) project. Engage after David's endorsement.", "role": "infl"}
    ]},
    {"label": "Primary contact & gatekeeper", "nodes": [
      {"name": "David Gray", "sub": "Central decision-maker / relationship bridge", "meta": "Key vendor influence; high-maintenance; overwhelmed with security incidents. Our path in.", "role": "champ", "lead": true}
    ]}
  ],
  "stakeholders": [
    {"name": "David Gray", "title": "Central decision-maker / relationship bridge", "role": "champ", "notes": "The gatekeeper and key vendor-decision influencer; winning him is essential. High-maintenance and currently overwhelmed with security incidents and personal matters - responses can lag. Open to collaborative quoting and competitive pricing. Build via social touchpoints (concerts, dinners)."},
    {"name": "Steve Badondo", "title": "Senior global architect", "role": "infl", "notes": "Influences multiple VSP entities; leads the Italy acquisition-assessment project. Engage only after David's endorsement; the Italy SOW is the wedge. A concert or dinner could be a casual intro."},
    {"name": "Andrew Lee, Derek Dern, Jamie Stark", "title": "VSP senior leadership", "role": "infl", "notes": "Targets for broadening relationships beyond David to mitigate single-threading risk."},
    {"name": "Watch: Phil Wolf (NetApp), Kevin Hammond (F5)", "title": "Vendor-side contacts", "role": "risk", "notes": "Phil Wolf = NetApp rep pushing on-prem to replace Nasuni. Kevin Hammond = F5 team lead, renewal in Dec. Competitive / renewal touchpoints to track."}
  ],
  "sizing": [
    {"k": "Structure", "v": "Multi-entity: VSP Legacy (insurance), VisionWorks (~750 US retail stores), Eyemart Express (~250 stores), independent ophthalmology + Optos. 10-14 affiliate companies."},
    {"k": "Footprint", "v": "Extensive on-prem storage across 42 states."},
    {"k": "Backup state", "v": "500+ retail locations with varied, unmanaged backup - often local USB drives, minimal management, no centralized backup or tested DR. Limited visibility across entities."},
    {"k": "Primary storage", "v": "NetApp (push for on-prem) + Nasuni (file mgmt / image cataloging, front-end to Azure, mainly VisionWorks). F5 networking."},
    {"k": "Compliance", "v": "HIPAA - patient data across manufacturing and ophthalmology."},
    {"k": "Key dates", "v": "Nasuni support renewal Sep 16 2026; F5 renewal Dec (Kevin Hammond)."},
    {"k": "Goal", "v": "Consolidate and standardize backup to a single data center across business units; economies of scale."}
  ],
  "priorities": [
    "Visibility & consolidation across fragmented, recently-acquired entities",
    "Ransomware protection with TESTED, verifiable recovery (skeptical of vendor claims)",
    "HIPAA-compliant secure backups for patient data",
    "Cost savings amid fragmented infrastructure",
    "Advisory-led, consultative engagement - not a product push"
  ],
  "fit": [
    "Consolidated, standardized backup/DR across 500+ distributed retail sites",
    "Ransomware protection with tested recovery - counters Nasuni/competitor claims",
    "Complements NetApp primary + Nasuni front-end (different use case, rarely competes)",
    "HIPAA-grade secure backups for patient data",
    "Embed ExaGrid inside the larger ePlus advisory / security engagement",
    "Leverage Veeam partnership where applicable"
  ],
  "competitors": [
    {"name": "Nasuni", "pos": "Incumbent file mgmt / image front-end to Azure (mainly VisionWorks). Support renewal Sep 16 2026; conversations on hold per David.", "ctr": "ExaGrid is backup/DR - a different use case. Position as complement, not a Nasuni replacement."},
    {"name": "NetApp", "pos": "Pushing on-prem to replace Nasuni; client dissatisfied with aggressive sales. Rep: Phil Wolf.", "ctr": "ExaGrid as best-of-breed backup behind NetApp primary - sell the synergy, not a fight."},
    {"name": "Rubrik", "pos": "Recent outreach to VSP; expressed interest.", "ctr": "ExaGrid as the cost-effective backup tier with tested recovery."}
  ],
  "steps": [
    {"id": "v1", "what": "Research VSP-owned entities' current backup/storage (any existing ExaGrid/Veeam?)", "owner": "Jay", "date": "This week", "status": "open", "done": false},
    {"id": "v2", "what": "Get affiliate names/websites from David; engage Optos for visibility", "owner": "David -> Jay", "date": "Near-term", "status": "open", "done": false},
    {"id": "v3", "what": "Strategy review of VSP work & proposals with Kat (ePlus)", "owner": "Jay / Kat", "date": "Jun 11, 3:00 PM", "status": "open", "done": false},
    {"id": "v4", "what": "Send David Gray Folsom radio concert invite (soft touch), CC Kat", "owner": "Jay", "date": "Near-term", "status": "open", "done": false},
    {"id": "v5", "what": "Build SOW for Italy project; coordinate intro to Steve Badondo (after David's endorsement)", "owner": "Jay / ePlus", "date": "By end of June", "status": "open", "done": false},
    {"id": "v6", "what": "Work with ePlus advisory on a standardized backup architecture proposal", "owner": "Jay / ePlus", "date": "After discovery", "status": "future", "done": false},
    {"id": "v7", "what": "Reconvene to propose consolidated backup/DR across entities", "owner": "Jay / Kat / David", "date": "After research", "status": "future", "done": false},
    {"id": "v8", "what": "Watch Nasuni renewal window (re-eval at Legacy + VisionWorks)", "owner": "Jay", "date": "Sep 16 2026", "status": "future", "done": false}
  ],
  "contactsToWarm": ["David Gray", "Steve Badondo"],
  "log": [
    {"id": "vl1", "date": "2026-06-05", "title": "Strategic engagement & growth - VSP (w/ Kat)", "body": "Lunch with David Gray done; internal docs and design proposals built and pending David's review. Identified Steve Badondo as a senior global architect across entities - engage after David's endorsement, with the Italy acquisition-assessment SOW as the wedge. Plan to broaden relationships to Andrew Lee, Derek Dern, Jamie Stark to de-risk single-threading. Strategy review set with Kat for Jun 11 3pm; sending David a Folsom concert invite as a soft touch."},
    {"id": "vl2", "date": "2026-05-14", "title": "Backup strategy & consolidation", "body": "500+ retail locations run varied, unmanaged local backup (USB drives), no centralized DR; 10-14 affiliates with limited visibility. Plan: consolidate/standardize backup to a single data center across business units. HIPAA a key driver. ePlus advisory + ExaGrid to lead discovery; David to provide affiliate list and engage Optos. ExaGrid complements Nasuni (front-end) and NetApp (primary)."},
    {"id": "vl3", "date": "2026-03-18", "title": "Initial VSP overview (w/ Kat)", "body": "Four core entities: VSP Legacy (insurance), VisionWorks (750 stores), Eyemart Express (250 stores), independent ophthalmology. On-prem across 42 states. Nasuni renewal Sep 16 2026 is the re-eval trigger. David Gray central to vendor decisions. NetApp pushing on-prem (rep Phil Wolf); F5 renewal Dec (Kevin Hammond); Rubrik made outreach. Position ExaGrid/NetApp synergy - ExaGrid as best-of-breed backup."}
  ],
  "notes": ""
}
$json$::jsonb),
('lumentum', 2, $json$
{
  "id": "lumentum",
  "name": "Lumentum",
  "subtitle": "Photonics / optical manufacturer - established ExaGrid account (~$343K spend). Expanding by site, incl. an EX36 PO for the Ottawa location.",
  "status": "Active - account expansion",
  "stage": "Repeat POs",
  "budgetCycle": "-",
  "nextMilestone": "Follow up on EX36 PO (Ottawa)",
  "updated": "Jun 1, 2026",
  "snapshot": [
    {"k": "Account", "v": "Lumentum - photonics / optical components manufacturer; international (incl. an Ottawa, Canada site)"},
    {"k": "Status", "v": "Established ExaGrid account; current spend ~$343K, approaching the $400K commission-split threshold"},
    {"k": "In motion", "v": "EX36 PO for the Ottawa site to follow up on; part of recent ~$239K in POs received"},
    {"k": "Next", "v": "Account audit as spend approaches $400K; keep expanding the footprint site-by-site"}
  ],
  "hierarchy": [], "stakeholders": [], "sizing": [], "priorities": [], "fit": [], "competitors": [],
  "steps": [
    {"id": "lm1", "what": "Follow up on the EX36 PO for the Ottawa site", "owner": "Jay", "date": "ASAP", "status": "open", "done": false},
    {"id": "lm2", "what": "Account audit - spend approaching $400K (commission-split threshold)", "owner": "Jay", "date": "Near-term", "status": "open", "done": false}
  ],
  "contactsToWarm": [],
  "log": [
    {"id": "ll1", "date": "2026-06-01", "title": "Pipeline review - Lumentum spend & POs", "body": "Lumentum spend at ~$343K; crossing $400K changes the commission split, prompting a full account audit. Part of ~$239K in POs received (one incorrect order being corrected, affecting revenue-recognition timing). EX36 PO for the Ottawa site to follow up on."}
  ],
  "notes": ""
}
$json$::jsonb),
('velo3d', 3, $json$
{
  "id": "velo3d",
  "name": "Velo3D",
  "subtitle": "DoD metal-3D-printing contractor (Fremont, CA). FedRAMP-gated backup deal - EX36 + EX20 via Ingram. Rep: Brian Jang; Jay supporting.",
  "status": "Active - quote out / pre-PO",
  "stage": "Stage 4 - proposal / quote",
  "budgetCycle": "Push to close before July price hike (~40%)",
  "nextMilestone": "Lester purchase-timing reply; Brian's colo mtg (Wed)",
  "updated": "Jun 1, 2026",
  "winLine": "The moat: ExaGrid is FedRAMP / CUI / CMMC compliant - Rubrik, Cohesity & non-compliant vendors are auto-DQ'd.",
  "snapshot": [
    {"k": "Account", "v": "Velo3D - DoD contractor in Fremont, CA; metal 3D printing & mold imaging for aircraft and submarine parts"},
    {"k": "Rep / team", "v": "Brian Jang (ExaGrid, NorCal) leads; Jay supporting on quote, SPIFF & CRM. Inherited from Mitch (left to a competitor)."},
    {"k": "Procurement", "v": "Mandated through Ingram (non-Ingram needs chain-of-command exceptions)"},
    {"k": "Selling", "v": "FedRAMP-compliant backup - EX36 (primary) + EX20 (DR)"},
    {"k": "Why now", "v": "ExaGrid ~40% price increase in July - push Lester to own the gear before the hike"},
    {"k": "Quote", "v": "Out via Ingram at ~47% standard discount; ~$110K now (Brian est. ~$150-160K post-hike). Mitch didn't attach it - Jay to reverse-engineer."}
  ],
  "hierarchy": [
    {"label": "Other contacts on the thread", "nodes": [
      {"name": "Stephanie Curtis / David Ornstein", "sub": "On the deal email thread", "meta": "Roles TBD - clarify (Velo3D vs Ingram).", "role": "infl"}
    ]},
    {"label": "Customer - decision / technical contact", "nodes": [
      {"name": "Lester", "sub": "Velo3D - primary contact", "meta": "Aware of the July hike; shopping Nutanix/Dell/HP. Push for a pre-July win.", "role": "champ", "lead": true}
    ]}
  ],
  "stakeholders": [
    {"name": "Lester", "title": "Velo3D - primary contact", "role": "champ", "notes": "Main technical/decision contact. Fully aware ExaGrid prices rise ~40% in July and is collecting competing quotes (Nutanix, Dell, HP). Incumbent backup may be Unitrends with a renewal coming up. Lever: buy now to future-proof and beat the hike. Jay has texted him for purchase timing."},
    {"name": "Brian Jang", "title": "ExaGrid rep - Northern California", "role": "infl", "notes": "Owns the relationship; meeting Lester Wednesday to start colo planning. ~1.5 yrs at ExaGrid; took over NorCal as Mitch left. Driving the opportunity."},
    {"name": "Stephanie Curtis & David Ornstein", "title": "On the deal email thread (roles TBD)", "role": "infl", "notes": "Surfaced on Mitch's thread from ~a month ago when quotes were provided. Clarify whether Velo3D stakeholders or Ingram contacts."},
    {"name": "Watch: Mitch (former rep)", "title": "Left to a competitor", "role": "risk", "notes": "Originally registered the deal (VAR registration) and met the end user (meeting SPIFF). Didn't attach the quote in CRM - hence the reverse-engineering. Now at a competitor."}
  ],
  "sizing": [
    {"k": "What they do", "v": "Metal 3D printing & mold imaging for parts on aircraft and submarines - defense supply chain."},
    {"k": "Compliance gate", "v": "FedRAMP + CUI protection + CMMC are mandatory. Non-compliant vendors (Rubrik, Cohesity, etc.) are auto-disqualified. ExaGrid qualifies - the key advantage."},
    {"k": "Systems quoted", "v": "ExaGrid EX36 (primary) + EX20 (DR)."},
    {"k": "Locations", "v": "Three. Main site Fremont; gear to live in a colo rack (not Fremont); a DR colo planned ~6-7 months out."},
    {"k": "Procurement", "v": "Mandated through Ingram; non-Ingram requires exception approvals."},
    {"k": "Incumbent", "v": "Possibly Unitrends backup with a renewal approaching (confirm)."}
  ],
  "priorities": [
    "FedRAMP / CUI / CMMC compliance - a hard gate on every vendor",
    "Cost-effectiveness & future-proofing (beat the July price hike)",
    "Primary + DR coverage across colo sites",
    "Procurement simplicity through Ingram"
  ],
  "fit": [
    "FedRAMP-compliant backup - clears the gate that DQs Rubrik/Cohesity",
    "Purpose-built EX36 + EX20 for primary + DR",
    "Lock current pricing before the ~40% July increase",
    "Scales into the future DR colo when it stands up (~6-7 months)"
  ],
  "competitors": [
    {"name": "Nutanix / Dell / HP", "pos": "Lester is getting competing hardware quotes from these.", "ctr": "FedRAMP-compliant, purpose-built backup at a better cost - and lock it before July."},
    {"name": "Unitrends (incumbent?)", "pos": "Possible incumbent backup with a renewal coming up.", "ctr": "Future-proof with ExaGrid now rather than re-upping; own the gear ahead of price hikes."},
    {"name": "Rubrik / Cohesity", "pos": "Typical backup competitors.", "ctr": "Out of the running - not FedRAMP/CUI/CMMC compliant for this account."}
  ],
  "steps": [
    {"id": "e1", "what": "Reverse-engineer the Ingram quote (confirm EX36 + EX20 products/pricing) & attach to the opportunity", "owner": "Jay", "date": "This week", "status": "open", "done": false},
    {"id": "e2", "what": "Fix CRM: flag as VAR registration; chase Mitch's unpaid $1,000 meeting SPIFF (was due 5/7)", "owner": "Jay", "date": "ASAP", "status": "open", "done": false},
    {"id": "e3", "what": "Follow up with Ingram on Mitch's submitted order & confirm pricing before July hike", "owner": "Jay", "date": "Before July", "status": "open", "done": false},
    {"id": "e4", "what": "Get Lester's purchase timing / confirm we're the technical win (texted him)", "owner": "Jay", "date": "Awaiting reply", "status": "open", "done": false},
    {"id": "e5", "what": "Colo planning meeting with Lester (primary rack now; scope DR colo options)", "owner": "Brian", "date": "Wednesday", "status": "open", "done": false},
    {"id": "e6", "what": "Have team scope colo options; revisit DR colo when it comes on the radar", "owner": "Brian", "date": "~6-7 months", "status": "future", "done": false}
  ],
  "contactsToWarm": ["Lester"],
  "log": [
    {"id": "el1", "date": "2026-06-01", "title": "Account handoff & deal review - Velo3D (Jay & Brian Jang)", "body": "Brian Jang briefed Jay on Velo3D (DoD metal-3D-printing contractor, Fremont). The wedge is compliance: FedRAMP + CUI + CMMC are mandatory, which DQs Rubrik/Cohesity and most rivals - ExaGrid qualifies. Quote is out via Ingram (~47% discount): EX36 + EX20 for primary + DR, ~$110K. Mitch (now at a competitor) registered it but didn't attach the quote, so Jay will reverse-engineer it, fix the VAR flag, and chase the unpaid $1,000 SPIFF. Lester is the customer contact, aware of ExaGrid's ~40% July price hike and shopping Nutanix/Dell/HP; lever is to buy before the increase. Gear goes in a colo rack (not Fremont); a DR colo is ~6-7 months out - Brian meets Lester Wednesday to start colo planning."}
  ],
  "notes": ""
}
$json$::jsonb)
on conflict (id) do nothing;

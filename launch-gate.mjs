/* ==========================================================================
   geofleetic.com publication gate. No dependencies.

       node launch-gate.mjs        (run it via: npm run test:launch)

   It reads the ARTIFACT — the generated index.html, fences.js and say.js —
   and refuses when the artifact says something the records do not support: a
   retracted claim reinstated, a rung invented, a call to action the rung has
   not earned, an unrendered token, a mailto:, a caveat nobody can read, an
   animation constant leaking into the copy, a button whose colour is decided
   by the wrong rule, or an artifact that is not what this source emits.

   SHELL.md §4, revision r9. Every check below has a reason and most of them
   have a scar.
   ========================================================================== */
import { readFileSync, existsSync, readdirSync } from "fs";
import { createHash } from "crypto";

const read = (p) => readFileSync(p, "utf8");
const J = (p) => JSON.parse(read(p));
const sha = (p) => createHash("sha256").update(readFileSync(p)).digest("hex");

const surface = J("./records/surface.json");
const specFacts = J("./records/spec-facts.json").facts;
const pkg = J("./package.json");

let pass = 0, fail = 0;
function T(name, ok, detail = "") {
    console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? " — " + detail : ""}`);
    ok ? pass++ : fail++;
}

for (const f of ["./index.html", "./fences.js", "./say.js", "./records/build.json"]) {
    if (!existsSync(f)) { console.error(`FAIL  missing artifact ${f} — run the build first`); process.exit(1); }
}
const landing = read("./index.html");
const anim = read("./fences.js");
const build = J("./records/build.json");

/* ==========================================================================
   0. HTML → VISIBLE TEXT. r8, AND IT IS A CORRECTNESS BUG, NOT A NICETY.

   Every gate in this portfolio strips tags with /<[^>]+>/g. That pattern
   stops at the FIRST ">", so an HTML comment containing one — and source
   comments are full of them — is only partly removed and its remainder is
   counted as visible page text. On opensentience.org a naive strip left a
   character from a hero comment that never renders, and two checks were
   reading it, one of them the retraction counter whose entire job is telling
   visible from hidden.

   So: comments come off first, as their own pass, then script and style, then
   tags. Everything downstream uses this one function, and §0.1 below proves
   it works on this artifact rather than trusting the comment you are reading.
   ========================================================================== */
const ENT = { "&nbsp;": " ", "&ensp;": " ", "&mdash;": "—", "&ndash;": "–", "&minus;": "−",
    "&rarr;": "→", "&uarr;": "↑", "&amp;": "&", "&copy;": "©", "&lt;": "<", "&gt;": ">",
    "&quot;": '"', "&times;": "×", "&middot;": "·", "&hellip;": "…", "&ldquo;": "“",
    "&rdquo;": "”", "&sect;": "§", "&sigma;": "σ" };
function decode(s) { return s.replace(/&\w+;/g, (e) => (e in ENT ? ENT[e] : e)); }
function textNodesOf(html) {
    return html
        .replace(/<!--[\s\S]*?-->/g, " ")
        .replace(/<script[\s\S]*?<\/script>/gi, " ")
        .replace(/<style[\s\S]*?<\/style>/gi, " ")
        /* SPLIT on tags rather than replacing them with a space, so what comes
           out is a list of real TEXT NODES. The first version of this did
           `.replace(/<[^>]+>/g," ").split(" ")`, which shreds every node into
           single words — and then `visible.includes("Get started")` could
           never be true, because the words came back joined by a different
           separator. Two multi-word rules were silently unfalsifiable, one of
           them the "no signup at the spec rung" check. Found by breaking the
           §10 quotation check and watching it fail to fire. */
        .split(/<[^>]+>/)
        .map((s) => decode(s).replace(/\s+/g, " ").trim())
        .filter(Boolean);
}
const textNodes = textNodesOf(landing);
const visible = textNodes.join("   ");

/* The same lesson applied to STRUCTURE, not just text. This gate's first run
   reported "the form does not post to the ruled endpoint" because the first
   `<form` in the file is inside a source comment explaining why the markup is
   a form and not a fetch bolted to a button — and `<form\b([^>]*)>` found the
   comment's bare tag first. Structural checks read `markup`; only the
   artifact-identity and byte-count checks read the raw file. */
const markup = landing.replace(/<!--[\s\S]*?-->/g, "");

/* §0.1 — the extractor, proven on this artifact. "SHELL.md" appears in this
   page's source comments and in no rendered word of it. If the comment pass
   were missing or ordered wrong, this fails. */
T("the visible-text extractor removes comments before tags (r8)",
    landing.includes("SHELL.md") && !visible.includes("SHELL.md"),
    "SHELL.md is in the source and in no text node");

/* ---------- 1. release identity ---------- */
T("release identity: package.json == records/surface.json",
    pkg.version === surface.version, `${pkg.version} / ${surface.version}`);
const STAMP = `GEOFLEETIC v${surface.version} · RECORDS ${surface.verified_at}`;
T("/ carries the canonical stamp", landing.includes(STAMP));
T("the surface records the shell revision it was built against",
    /^shell-r\d+$/.test(surface.shell_revision || ""), surface.shell_revision);
T("the build record carries the same stamp as the page", build.stamp === STAMP);

/* ==========================================================================
   2. THE ARTIFACT IS THIS BUILD'S. r6 hole #2, closed in both directions.

   Nothing checked this before. If build-site.mjs threw, the previous
   index.html stayed on disk and a gate reading it happily approved a STALE
   artifact — which is how two deliberate breaks reported PASS on a sibling
   surface, making every break count published before that an upper bound
   rather than a proof.

   `inputs` catches the stale direction: any source file that has moved since
   the last successful emit. `artifacts` catches the tampered direction: a
   hand-edit of the emitted HTML after the build. Either check alone has a
   hole; the pair does not.
   ========================================================================== */
{
    const moved = Object.entries(build.inputs).filter(([p, h]) => !existsSync(p) || sha(p) !== h);
    T("every build input is byte-identical to what the last emit read", moved.length === 0,
        moved.length ? `STALE: ${moved.map(([p]) => p).join(", ")} changed after the last successful build`
            : `${Object.keys(build.inputs).length} inputs fingerprinted`);
    const edited = Object.entries(build.artifacts).filter(([p, a]) => sha(p) !== a.sha256);
    T("every artifact is byte-identical to what the last emit wrote", edited.length === 0,
        edited.length ? `EDITED: ${edited.map(([p]) => p).join(", ")}` : `${Object.keys(build.artifacts).length} artifacts hashed`);
    /* And the belt to that pair of braces: the artifact still has to BE what
       the current source compiles to, so a build.json edited to match a
       hand-edited page cannot pass either. */
    const emitCss = read("./src/shell.css")
        .replace(/\/\*[\s\S]*?\*\//g, "").replace(/\n\s*/g, "").replace(/;\}/g, "}").trim();
    T("/ carries the stylesheet this source compiles to", landing.includes(emitCss),
        `${Buffer.byteLength(emitCss).toLocaleString()} bytes of CSS`);
    const strip = (p) => read(p).replace(/\/\*[\s\S]*?\*\//g, "").replace(/^[ \t]*\/\/.*$/gm, "")
        .replace(/^[ \t]+/gm, "").replace(/[ \t]+$/gm, "").replace(/\n{2,}/g, "\n").trim();
    T("/fences.js is what src/fences.js compiles to", anim.trim() === strip("./src/fences.js"));
    T("/say.js is what src/say.js compiles to", read("./say.js").trim() === strip("./src/say.js"));
}
T("/ has no unrendered build token", !/\{\{\w+\}\}/.test(landing));
T("/ declares its canonical URL", landing.includes(`<link rel="canonical" href="${surface.origin}/">`));
T("/ declares the surface's falsifiable question",
    landing.includes(`<meta name="falsifiable-question" content="${surface.question}">`));

/* ==========================================================================
   3. THE CONTENT SHIPS WITHOUT JAVASCRIPT — NARROWED 2026-08-17, DELIBERATELY

   This check used to read "the only scripts are the identity animation and
   the form upgrade" — in effect, no JavaScript at all beyond those two. That
   is the rule this surface dropped <amp-nav> to keep, and it dropped it with
   no ruling behind the decision.

   TRAVIS HAS NOW RULED: the ampersand-nav belongs on every website. The nav is
   a WEB COMPONENT; it cannot exist without a script. A check saying "no JS"
   would therefore have had to be DELETED to obey the ruling. So it is narrowed
   instead, to the property that was actually being protected:

       NO JAVASCRIPT THE CONTENT DEPENDS ON.

   The partition is explicit and the members are NAMED, never counted, so a
   third-party tag still cannot slip in on a loosened bound:
     · CHROME    — /amp-nav.js, the shared portfolio nav. Renders the nav bar
                   and nothing else on this page. §3b proves the page's text is
                   character-identical with it deleted.
     · THE OWN   — /fences.js, the identifying animation, which §12 proves
                   writes nothing into the document; and /say.js, which §5
                   proves is an upgrade to a form that already posts.
   ========================================================================== */
const CHROME_SCRIPTS = ["/amp-nav.js"];
const OWN_SCRIPTS = ["/fences.js", "/say.js"];
{
    const tags = [...markup.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)];
    const srcs = tags.map((t) => (/\bsrc="([^"]+)"/.exec(t[1]) || [])[1]);
    T("the landing page ships no inline JavaScript", tags.every((t) => t[2].trim() === ""));
    /* A type="module" script is deferred by specification — the attribute has
       no effect on one — so requiring the literal word would refuse the nav
       for a reason that is not true of it. Both forms are accepted and both
       are named. */
    T("every script is external and deferred", tags.every((t) =>
        /\bsrc="\/[\w.-]+"/.test(t[1]) && (/\bdefer\b/.test(t[1]) || /\btype="module"/.test(t[1]))),
        `${tags.length} script tag(s): ${tags.map((t) => t[1].trim()).join(" | ")}`);
    T("the only scripts are the shared nav chrome and this surface's own two",
        srcs.length === CHROME_SCRIPTS.length + OWN_SCRIPTS.length &&
        CHROME_SCRIPTS.every((s) => srcs.includes(s)) && OWN_SCRIPTS.every((s) => srcs.includes(s)),
        srcs.join(", ") || "none");
    T("no third-party script is loaded", !srcs.some((s) => /^https?:/.test(s)), srcs.join(", "));
}

/* ==========================================================================
   3a. THE PORTFOLIO NAV IS ON THE PAGE. Ruled by Travis 2026-08-17:
   "the ampersand-nav needs to be on each website!"

   This surface and four siblings each dropped <amp-nav> independently when
   they adopted the shell, to protect the zero-JavaScript content property,
   and no ruling was ever made either way. It has now been made, and this
   check exists so it cannot vanish silently a second time — vanishing
   silently is exactly how it vanished the first time.

   SCOPED TO THE ELEMENT (r14). A `<script src="/amp-nav.js">` mentions the
   filename and is NOT the custom element: /amp-nav/.test(landing) would be
   satisfied by the script tag alone and would report PASS with the nav
   deleted. So this matches the element's opening tag, in `markup` (comments
   already stripped, so a commented-out nav cannot satisfy it either).
   ========================================================================== */
{
    const els = [...markup.matchAll(/<amp-nav\b([^>]*)>/gi)];
    T("/ carries the shared portfolio nav ELEMENT, not just its script",
        els.length === 1, `${els.length} <amp-nav> element(s)`);
    T("/ files itself under the nav property this surface is recorded as",
        els.length === 1 && new RegExp(`\\bproperty="${surface.nav_property}"`).test(els[0][1]),
        els.length ? els[0][1].trim() : "no element");
    T("the nav component the page loads is in this tree", existsSync("./amp-nav.js"));
    T("the vendored nav knows this property",
        new RegExp(`^\\s*${surface.nav_property}:\\s*\\{`, "m").test(read("./amp-nav.js")),
        `an unknown key renders an EMPTY bar rather than an error — "${surface.nav_property}"`);
}

/* ---------- 3b. and the nav is CHROME: the content does not depend on it ----
   The constraint the ruling had to survive, made mechanical rather than
   asserted in a comment. Delete the nav element AND its script from the
   artifact, re-extract every text node, and require the result to be
   character-identical. If <amp-nav> ever starts carrying page content — a
   fallback list, a status line, anything a reader would miss — this refuses. */
{
    const withoutNav = markup
        .replace(/<script\b[^>]*src="\/amp-nav\.js"[^>]*>\s*<\/script>/gi, "")
        .replace(/<amp-nav\b[^>]*>[\s\S]*?<\/amp-nav>/gi, "");
    const before = textNodesOf(markup).join("\u0000");
    const after = textNodesOf(withoutNav).join("\u0000");
    T("the page's content does not depend on the nav", before === after,
        `${before.length} extractable characters with the nav, ${after.length} without it`);
    T("the nav element carries no content of its own",
        /<amp-nav\b[^>]*>\s*<\/amp-nav>/i.test(markup), "it must be empty in the artifact");
}

/* ==========================================================================
   4. CLAIMS THAT WERE RETRACTED MAY NOT COME BACK. r6 hole #1, closed.

   The reference implementation of this check asks "is the string inside the
   retraction?" and then permits it everywhere once the answer is yes — so a
   page that KEEPS its retraction and puts the sentence back in the hero
   passes. Confirmed by breaking it on a sibling. COUNT occurrences and BOUND
   them; do not test for presence.
   ========================================================================== */
const RETRACTED = [
    "Every GeoFleetic endpoint is an MCP server",
    "Discover on FleetPrompt",
    "predict demand, and",
];
const retractBlock = (() => {
    /* Depth-counted, not "up to the first </div>": a retraction that grows a
       nested element would otherwise silently shrink the window in which its
       own quotes are allowed, and the check would start refusing the truth. */
    const i = landing.indexOf('<div class="retract">');
    if (i < 0) return "";
    let d = 0, j = i;
    for (const m of landing.slice(i).matchAll(/<div\b|<\/div>/g)) {
        d += m[0] === "</div>" ? -1 : 1;
        if (d === 0) { j = i + m.index + 6; break; }
    }
    return landing.slice(i, j);
})();
const tally = (hay, needle) => hay.split(needle).length - 1;
T("the retraction block is present and findable", retractBlock.length > 0,
    `${Buffer.byteLength(retractBlock)} bytes`);
for (const s of RETRACTED) {
    const onPage = tally(landing, s);
    const inBlock = tally(retractBlock, s);
    T(`/ quotes "${s}" only inside the retraction`,
        onPage === inBlock && inBlock >= 1 && inBlock <= 2,
        `${onPage} on the page, ${inBlock} inside the retraction (bound 1..2)`);
}

/* ==========================================================================
   4b. r15 — THE BUILD PUBLISHES FILES THIS CHECK NEVER READ

   r14 was "the gate reads one file; the HOST serves a directory." This is the
   same defect one layer inward: the BUILD writes more than one file, and a
   blocklist that reads only index.html is not a blocklist. It was demonstrated
   on opensentience.org, where a retracted count was planted in a comment
   inside a published script and the gate reported green — three of that
   build's four emitted files were exempt from every text rule it had.

   This build emits three. So every retracted string is now tested against ALL
   of them, and the two that are not the page get a HARD ZERO: a script has no
   retraction block to hold a quotation, so any occurrence in one is a
   reinstatement with nowhere to hide. Same for a mailto: and an email address.

   The vendored ./amp-nav.js is deliberately NOT in this set — it is not
   written by this build, it is written by ampersand-nav/sync-nav.sh and only
   lane N may change it. It is covered separately, and honestly, in §5.
   ========================================================================== */
const PUBLISHED = Object.keys(build.artifacts).filter((p) => p !== "index.html");
{
    T("every file this build writes is accounted for by these checks",
        PUBLISHED.length === 2 && PUBLISHED.includes("fences.js") && PUBLISHED.includes("say.js"),
        `index.html + ${PUBLISHED.join(", ")}`);
    for (const f of PUBLISHED) {
        const body = read("./" + f);
        const hits = RETRACTED.filter((s) => body.includes(s));
        T(`/${f} reinstates no retracted claim`, hits.length === 0,
            hits.length ? `REINSTATED: ${hits.join(" | ")}` : `${RETRACTED.length} strings checked against ${Buffer.byteLength(body)} bytes`);
        T(`/${f} carries no mailto: and no email address`,
            !body.includes("mailto:") && !/[\w.+-]+@[\w-]+\.[a-z]{2,}/i.test(body));
        T(`/${f} carries no unrendered build token`, !/\{\{\w+\}\}/.test(body));
    }
}
T("/ carries the retraction rather than a silent edit",
    landing.includes("Retraction &mdash;") && /None of it existed/.test(landing));

/* ---------- 5. the correction channel: a live form, never a mailbox ---------- */
T("/ advertises no mailto:", !landing.includes("mailto:"));
T("/ contains no email address at all", !/[\w.+-]+@[\w-]+\.[a-z]{2,}/i.test(visible));

/* THE ONE MAILTO THIS SURFACE PUBLISHES AND CANNOT REMOVE — declared, bounded
   and dated rather than silently exempted. Found 2026-08-17 while restoring
   the nav, and it generalises: the vendored amp-nav.js carries a `contact`
   entry — "Talk to us", hello@ampersandboxdesign.com, href mailto: — which is
   an ITEM IN A RENDERED SECTION, so every surface that ships this nav
   publishes an email address and a mailto: link. That is against the standing
   portfolio rule (SITES.md §0.5, Travis 2026-08-11: no mailto:, not even as a
   fallback) and it has been true on the surfaces that kept the nav all along;
   the rule read index.html and the mailto was in a script, which is r15
   exactly.

   ampersand-nav/ is lane N's and a vendored copy must not be hand-edited, so
   this gate does the only honest thing available to it: BOUND the exception at
   the one occurrence measured, and refuse if it grows. Flagged [TRAVIS] in the
   lane report. If lane N removes it, this still passes at 0. */
{
    const nav = read("./amp-nav.js");
    const mailtos = nav.split("mailto:").length - 1;
    T("the vendored nav's mailto: exception has not grown past the one declared",
        mailtos <= 1,
        `${mailtos} mailto: in amp-nav.js — a KNOWN portfolio-wide defect owned by lane N, not by this repo`);
}
{
    const f = /<form\b([^>]*)>/i.exec(markup);
    T("/ carries a real form, not a fetch bolted to a button", !!f);
    const at = f ? f[1] : "";
    T("the form posts to the ruled endpoint",
        at.includes(`action="${surface.contact.endpoint}"`) && /method="POST"/i.test(at),
        surface.contact.endpoint);
    T("the endpoint is declared once in the record and appears once on the page",
        tally(landing, surface.contact.endpoint) === 1);
    T("the form works with scripting off — it carries novalidate, not a click handler", /\bnovalidate\b/.test(at));
    /* Scoped to the FORM, not the page. The first version tested the whole
       artifact and passed with the honeypot deleted, because the inlined
       stylesheet still carries `.say input[name="_gotcha"]` — a check that a
       CSS selector can satisfy is not checking the markup. Found by breaking
       it. */
    const formBlock = (/<form\b[\s\S]*?<\/form>/i.exec(markup) || [""])[0];
    T("the form carries the honeypot", /name="_gotcha"/.test(formBlock), `${Buffer.byteLength(formBlock)} bytes of form`);
    T("the reply is announced to a screen reader", /role="status" aria-live="polite"/.test(formBlock));
    const say = read("./say.js");
    T("the form upgrade prints success only on a 2xx", /if \(r\.ok\)/.test(say) && !/say\("Sent/.test(say.split("if (r.ok)")[0]));
    T("the correction channel is a live URL, not a mailbox",
        /^https:\/\//.test(surface.contact.url) && surface.contact.kind !== "mailto");
}

/* ---------- 6. every rung on the artifact is a real rung ---------- */
const RUNGS = ["spec", "in_tree", "live_local", "live_deployed", "external", "?"];
{
    const chips = [...markup.matchAll(/<span class="rung" data-rung="([^"]*)"[^>]*>([^<]*)<\/span>/g)];
    T("/ renders at least one rung chip", chips.length > 0, `${chips.length} chips`);
    T("/ renders only real rungs", chips.every((c) => RUNGS.includes(c[1])),
        chips.map((c) => c[1]).filter((r) => !RUNGS.includes(r)).join(", ") || "all valid");
    T("/ chip text always equals its stored rung", chips.every((c) => c[1] === c[2]));
    T("/ never defaults an unknown rung",
        !/data-rung=""/.test(landing) && !/data-rung="undefined"/.test(landing) && !/data-rung="null"/.test(landing));
    T("the surface rung is one of the five", RUNGS.slice(0, 5).includes(surface.surface_rung), surface.surface_rung);
    T("the surface rung is the rung of its best-evidenced artifact",
        surface.artifacts.some((a) => a.rung === surface.surface_rung),
        `${surface.surface_rung} — ${(surface.artifacts.find((a) => a.rung === surface.surface_rung) || {}).name}`);
}

/* ---------- 6a. the band, and it must refuse in BOTH directions ----------
   THREE variants, not two. amp-nav's renderPlacement() gives the layer
   sentence to place 2 ONLY; place 3 gets "a specification in the
   ComputeDriven world" plus a spec link; place 4 gets attribution only.
   Refusing a claim a place has not earned is half of it — a band that
   quietly DROPS the sentence its place requires is the same defect inverted,
   and it passed on a sibling until someone tried it. */
T("the surface declares its place", [1, 2, 3, 4].includes(surface.tier), `place ${surface.tier}`);
T("/ band carries the declared place", landing.includes(`<div class="band" data-tier="${surface.tier}">`));
{
    const SENTENCES = {
        2: `is the <b>${surface.layer}</b> layer of ${surface.parent}`,
        3: `a <b>specification</b> in the ${surface.parent} world`,
        4: `A <b>${surface.parent}</b> project`,
    };
    const mine = SENTENCES[surface.tier];
    T(`/ band carries the sentence place ${surface.tier} requires`, !!mine && landing.includes(mine), mine);
    const wrong = Object.entries(SENTENCES)
        .filter(([p]) => Number(p) !== surface.tier && landing.includes(SENTENCES[p])).map(([p]) => `place ${p}`);
    T("/ band carries no OTHER place's sentence", wrong.length === 0, wrong.join(", ") || "only its own");
    T("/ band at place 3 links the specification, as the nav does",
        surface.tier !== 3 || landing.includes(`<a class="specref" href="${surface.spec_url}">`));
    T("/ band makes no layer claim at place 3",
        surface.tier !== 3 || !landing.includes(`layer of ${surface.parent}`));
}
T("the placement band bounds what its rung covers", landing.includes(surface.surface_rung_covers));

/* THE DOCS ROUTE IS THE #/ ROUTE. Ruled by Travis 2026-08-17 — "all the docs
   have that # in them". This page carried five links in the bare, hash-less
   form. That form is NOT dead: measured the same day it answers HTTP 200 with
   an 80,166-byte prerendered page, and the lane that chose it did so on the
   defensible ground that it resolves with JavaScript off. Travis is ruling the
   canonical form, not repairing a 404 — and the ruling wins.

   The check is on the SHAPE rather than on the one URL, so a second docs link
   added later cannot quietly reintroduce the bare form. */
{
    const docs = [...landing.matchAll(/https:\/\/docs\.ampersandboxdesign\.com\/[^"'\s<)]*/g)].map((m) => m[0]);
    const bare = docs.filter((u) => !u.startsWith("https://docs.ampersandboxdesign.com/#/"));
    T("every docs.ampersandboxdesign.com link is on the #/ route", bare.length === 0,
        bare.length ? `BARE: ${[...new Set(bare)].join(", ")}` : `${docs.length} link(s), all #/`);
}
/* r6: the nav stacking breakpoint is the SURFACE's, measured, and recorded —
   not the shell's 430px, which was measured on a four-item nav. The record
   and the stylesheet must agree or one of them is a guess. */
T("the nav stacking breakpoint is the one this surface measured",
    new RegExp(`@media\\(max-width:${surface.nav_stack_px}px\\)\\{\\.top\\{flex-direction:column`).test(read("./src/shell.css").replace(/\s*\n\s*/g, "")),
    `${surface.nav_stack_px}px`);

/* r11 — AND THE MEASUREMENT IS BOUND TO THE LABELS IT WAS TAKEN WITH.
   A breakpoint measured against a nav whose items can be renamed without
   notice is a stale number waiting to happen: on another surface, renaming one
   item to "Correct us" — five characters — moved the wrap point 538 → 576,
   past a 560 breakpoint, marooning the logo in a broken two-row state between
   561 and 575, and nothing was checking. So the labels are recorded beside the
   number and the gate refuses when the emitted nav drifts from them. */
{
    const navBlock = /<div class="top">[\s\S]*?<\/nav>/.exec(markup);
    const labels = navBlock
        ? [...navBlock[0].matchAll(/<a\b[^>]*>([\s\S]*?)<\/a>/g)]
            .map((m) => decode(m[1].replace(/<[^>]+>/g, "")).replace(/\s+/g, " ").trim())
            .slice(1)                                     /* [0] is the logo */
        : [];
    const want = surface.nav_labels_at_measure || [];
    T("the nav still carries the labels the breakpoint was measured with (r11)",
        labels.length === want.length && labels.every((l, i) => l === want[i]),
        labels.join(" · ") || "no nav found");
}

/* ---------- 6b. every §N on the page resolves in the spec it cites ----------
   Cheap, and it catches a citation that drifted when a spec was rewritten.
   FENCES ARE STRIPPED FIRST: a markdown heading inside a fenced code block is
   not a heading, and reading one as a section has already bitten a lane. Only
   RENDERED text counts — the SHELL.md §8 reference in this page's own source
   comments is not a citation of this specification, and on a sibling it
   passed by coincidence because the spec happened to have a §8. */
{
    const specPath = "./" + surface.spec_file;
    T("the spec file this surface cites exists", existsSync(specPath), surface.spec_file);
    if (existsSync(specPath)) {
        const md = read(specPath).replace(/^```[\s\S]*?^```/gm, "");
        const heads = new Set([...md.matchAll(/^#{1,6}\s+(\d+(?:\.\d+)*)\.?\s/gm)].map((m) => m[1]));
        const used = new Set([...md.matchAll(/§\s?(\d+(?:\.\d+)*)/g)].map((m) => m[1]));
        const cited = [...new Set([...visible.matchAll(/§\s?(\d+(?:\.\d+)*)/g)].map((m) => m[1]))];
        const dangling = cited.filter((c) => !heads.has(c) && !used.has(c));
        T("every § citation on the page resolves in the spec it cites", dangling.length === 0,
            dangling.length ? `DANGLING: ${dangling.map((d) => "§" + d).join(", ")}`
                : `${cited.length} citations resolved against ${heads.size} headings`);
        T("the page cites the spec at all", cited.length >= 3, `${cited.length} citations`);
    }
}

/* ---------- 6c. the rung has a NAMED witness, and it is approved ---------- */
T("the surface names the gate that witnesses its rung",
    !!surface.rung_witness && !!surface.gates[surface.rung_witness], surface.rung_witness);
T("the witnessing gate is approved, with its evidence",
    surface.gates[surface.rung_witness] && surface.gates[surface.rung_witness].status === "approved" &&
    ["evidence", "reviewer", "date"].every((f) => surface.gates[surface.rung_witness][f]), surface.rung_witness);

/* ---------- 7. §0.7 — the rung gates the call to action ---------- */
const VERBS = {
    spec: ["Read", "Challenge", "Implement"],
    in_tree: ["Inspect the source", "Run the tests"],
    live_local: ["Use it", "Reproduce it locally"],
    live_deployed: ["Use the deployed artifact"],
    external: ["See independent evidence", "Contribute another result"],
};
{
    const groups = [...markup.matchAll(/<div class="ctagroup"><div class="tag[^"]*">(\w+) &mdash;[\s\S]*?<\/div><\/div>/g)];
    T("/ has at least one call to action", groups.length > 0, `${groups.length} groups`);
    const bad = [];
    for (const g of groups) {
        const allowed = VERBS[g[1]] || [];
        for (const v of [...g[0].matchAll(/<span class="verb">([^<]*)<\/span>/g)]) {
            if (!allowed.includes(decode(v[1]))) bad.push(`${v[1]} @ ${g[1]}`);
        }
    }
    T("/ asks only what its rung has earned", bad.length === 0, bad.join("; ") || "ok");
    T("no group invites running something at the spec rung",
        !/<div class="tag">spec[\s\S]*?<span class="verb">(Use it|Use the deployed|Run the tests|Reproduce|Inspect)/.test(landing));
    T("every artifact rung on this surface has its own CTA group",
        [...new Set(surface.artifacts.map((a) => a.rung))].every((r) => groups.some((g) => g[1] === r)),
        [...new Set(surface.artifacts.map((a) => a.rung))].join(", "));
    /* A spec surface must not offer a signup, a trial or a purchase — SITES.md
       §0.7. The words are cheap to check and the defect is expensive. */
    const forbidden = ["Sign up", "Get started", "Start free", "Try it", "Book a demo", "Request access", "Buy ", "/mo"];
    const found = forbidden.filter((w) => visible.includes(w));
    T("a spec surface asks nobody to sign up, start or buy", found.length === 0, found.join(", ") || "none of the eight");
}

/* ---------- 8. the status block, and the review ledger ---------- */
for (const label of ["Status", "Last verified", "Source", "Limit", "Next rung"]) {
    T(`the status block states ${label}`, landing.includes(`<dt>${label}</dt>`));
}
T("the LIMIT names something the evidence does NOT establish",
    /does not establish|does not claim|has not/i.test(surface.status.limit));
const NEED = ["evidence", "reviewer", "date"];
const gates = Object.entries(surface.gates).filter(([k]) => k !== "_comment");
T("review ledger: every gate has a valid status", gates.every(([, g]) => ["pending", "approved"].includes(g.status)));
T("review ledger: no approval without its evidence",
    gates.every(([, g]) => g.status !== "approved" || NEED.every((f) => g[f])));
T("review ledger: the external rung is not self-awarded",
    surface.surface_rung !== "external" || surface.gates.independent_implementation.status === "approved");

/* ---------- 9. the published figures are the ones that were derived ---------- */
{
    const must = [
        `${specFacts.spec_lines} lines`, `${specFacts.sections} sections`,
        `${specFacts.contract_operations} operations`, `${specFacts.boxes_unticked} unticked`,
        `${specFacts.mcp_tools.length} tools`, `${specFacts.acceptance_criteria} criteria`,
    ];
    const absent = must.filter((s) => !visible.includes(s));
    T("every headline figure on the page is one the build derived", absent.length === 0,
        absent.length ? `MISSING: ${absent.join(", ")}` : `${must.length} figures`);
    T("the implementation count published is zero, and derived",
        specFacts.implementation_lines === 0 && visible.includes("0 lines"), `${specFacts.implementation_lines} lines of .ex/.exs`);
    const ops = specFacts.contract_operations;
    T("the contract operation count matches the contract files on disk",
        readdirSync("./records/contracts").filter((f) => f.endsWith(".contract.json"))
            .reduce((n, f) => n + Object.keys(J(`./records/contracts/${f}`).operations).length, 0) === ops, `${ops} operations`);
}

/* ---------- 10. every path this page tells a reader to load resolves ---------- */
{
    const hrefs = [...new Set([...markup.matchAll(/(?:href|src)="(\/[^"#?]*)"/g)].map((m) => m[1]))];
    const dead = hrefs.filter((h) => !existsSync("." + (h.endsWith("/") ? h + "index.html" : h)));
    T("every same-origin path the page links resolves in the tree", dead.length === 0,
        dead.length ? `DEAD: ${dead.join(", ")}` : `${hrefs.length} paths`);
    const anchors = [...new Set([...markup.matchAll(/href="#([\w-]+)"/g)].map((m) => m[1]))];
    const noTarget = anchors.filter((a) => !new RegExp(`id="${a}"`).test(markup));
    T("every in-page anchor has a target", noTarget.length === 0, noTarget.join(", ") || `${anchors.length} anchors`);
}

/* ---------- 11. density ---------- */
/* r15: String.length counts UTF-16 CODE UNITS, not bytes. This page carries
   —, §, ↑ and · by the hundred, so the two differ by 89 here — and SITES.md
   §0.1 makes a local-vs-served BYTE comparison the deploy check, which a
   character count would fail on any page containing one of them. */
T("the landing page stays small", Buffer.byteLength(landing) < 40000, `${Buffer.byteLength(landing).toLocaleString()} bytes`);

/* ==========================================================================
   12. SHELL.md §8.5 — THE IDENTIFYING ANIMATION ASSERTS NOTHING

   gpscoord.com shipped a canvas globe whose vehicles were created by
   `for (let i = 0; i < 12; i++)`, and printed beside it, for months:

       12   Active Pathfinders

   A decoration's internal constant was published as a live user metric. The
   checks below are that defect mechanised. WHEN ONE FIRES, THE ANIMATION
   CHANGES — never the page. Decoration yields.
   ========================================================================== */
{
    const marked = [...markup.matchAll(/<[a-z]+\b[^>]*\bdata-identity-animation\b[^>]*>/gi)];
    T("the landing page marks an element data-identity-animation", marked.length >= 1, `${marked.length} marked`);
    const firstSection = (markup.split("<section")[1] || "").split("</section>")[0];
    T("the identity animation is above the fold — inside the first section",
        firstSection.includes("data-identity-animation"));
    T("the h1 comes before the identity animation — the question comes first",
        markup.indexOf("<h1") > -1 && markup.indexOf("<h1") < markup.indexOf("data-identity-animation"));
    /* Travis, 2026-08-17: "there is no animation for these websites at the top
       above the fold." Presence is not placement. The panel must have a
       declared height so it occupies the first screenful rather than being a
       zero-height wash behind the text. */
    /* RESOLVED, not grepped. The first version scanned the whole stylesheet
       for ".idanim{…min-height", and passed with the base rule's height
       deleted because the min-width:900px rule still had one — so the panel
       collapsed to nothing on a phone and the gate said fine. The cascade
       resolver in §14 answers this properly, at both widths. */
    /* checked in §14, where the cascade resolver lives */
}

const ANIM_NUMS = new Set();
const ANIM_STRS = new Set();
for (const m of anim.matchAll(/(?<![\w.$])\d+(?:\.\d+)?/g)) {
    const v = Number(m[0]);
    if (Math.abs(v) >= 2) ANIM_NUMS.add(String(v));
}
for (const m of anim.matchAll(/"([^"\\\n]{3,})"|'([^'\\\n]{3,})'/g)) ANIM_STRS.add(m[1] ?? m[2]);
{
    const shown = new Set();
    for (const t of textNodes) {
        shown.add(t);
        if (/^-?[\d,]*\d(?:\.\d+)?$/.test(t) && t.includes(",")) shown.add(t.replace(/,/g, ""));
    }
    const leaked = [...shown].filter((t) => ANIM_NUMS.has(t) || ANIM_STRS.has(t));
    T("no text on the landing page is a constant read from the animation", leaked.length === 0,
        leaked.length ? `LEAKED: ${leaked.map((l) => JSON.stringify(l)).join(", ")} — change src/fences.js, not the page`
            : `${ANIM_NUMS.size + ANIM_STRS.size} constants vs ${textNodes.length} text nodes, disjoint`);
}
{
    const recordText = ["./records/surface.json", "./records/spec-facts.json",
        ...readdirSync("./records/contracts").map((f) => `./records/contracts/${f}`)].map(read).join("\n");
    const shared = [...ANIM_STRS].filter((s) => recordText.includes(s));
    T("the animation shares no string with a frozen record", shared.length === 0,
        shared.length ? `SHARED: ${shared.map((s) => JSON.stringify(s)).join(", ")}` : `${ANIM_STRS.size} strings, none in records`);
}
{
    const FORBIDDEN = ["innerHTML", "outerHTML", "textContent", "innerText", "insertAdjacentHTML",
        "document.write", "createElement", "createTextNode", "appendChild", "setAttribute",
        "getElementById", "getElementsBy", "localStorage", "sessionStorage", "XMLHttpRequest", "fetch("];
    const found = FORBIDDEN.filter((k) => anim.includes(k));
    T("the animation neither reads nor writes page content", found.length === 0, found.join(", ") || "no DOM content API used");
    const queries = [...anim.matchAll(/querySelector(?:All)?\(\s*([^)]*)\)/g)].map((m) => m[1]);
    T("the animation queries nothing but its own canvas",
        queries.length === 1 && queries[0].includes("data-identity-animation"), queries.join(" | ") || "none");
}
T("the animation honours prefers-reduced-motion", anim.includes("prefers-reduced-motion"));
T("the animation never uses IntersectionObserver", !anim.includes("IntersectionObserver"));
T("the animation stops when the tab is hidden", anim.includes("document.hidden"));
T("the animation caps its frame rate", /1000\s*\/\s*FPS/.test(anim));
T("the animation stays cheap enough for a phone", Buffer.byteLength(anim) < 9000, `${Buffer.byteLength(anim).toLocaleString()} bytes`);

/* ==========================================================================
   13. CONTRAST — every declared text token, on the surface it sits on
   --fg3 shipped at .34 across this shell, which is 2.78:1 against the band.
   WCAG 2.1 SC 1.4.3, computed rather than eyeballed.
   ========================================================================== */
const sheet = read("./src/shell.css");
const TOKENS = {};
for (const m of sheet.slice(sheet.indexOf("/* TOKENS-START"), sheet.indexOf("/* TOKENS-END"))
    .matchAll(/--([\w-]+)\s*:\s*([^;\n}]+)/g)) TOKENS[m[1]] = m[2].trim();
if (!TOKENS.ink) throw new Error("launch-gate found no token block in src/shell.css");

function colour(v) {
    const raw = (TOKENS[String(v).replace(/^--/, "")] || String(v)).trim();
    let m = /^#([0-9a-f]{6})$/i.exec(raw);
    if (m) return [parseInt(m[1].slice(0, 2), 16), parseInt(m[1].slice(2, 4), 16), parseInt(m[1].slice(4, 6), 16), 1];
    m = /^rgba?\(([^)]+)\)$/i.exec(raw);
    if (m) { const p = m[1].split(",").map((x) => Number(x.trim())); return [p[0], p[1], p[2], p.length > 3 ? p[3] : 1]; }
    throw new Error(`launch-gate cannot read the colour ${JSON.stringify(v)} -> ${raw}`);
}
const composite = (f, b) => [f[3] * f[0] + (1 - f[3]) * b[0], f[3] * f[1] + (1 - f[3]) * b[1], f[3] * f[2] + (1 - f[3]) * b[2], 1];
function solid(spec) {
    const layers = Array.isArray(spec) ? spec : [spec];
    let base = colour(layers[0]); base = [base[0], base[1], base[2], 1];
    for (let i = 1; i < layers.length; i++) base = composite(colour(layers[i]), base);
    return base;
}
const chan = (c) => { c /= 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); };
const lum = (c) => 0.2126 * chan(c[0]) + 0.7152 * chan(c[1]) + 0.0722 * chan(c[2]);
function contrast(fgSpec, bgSpec) {
    const bg = solid(bgSpec), fg = composite(colour(fgSpec), bg);
    const a = lum(fg), b = lum(bg);
    return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}
const CONTRAST_PAIRS = [
    ["--fg", "--ink", "body copy"], ["--fg", "--ink2", "card headings and the band's bold word"],
    ["--fg", "--ink3", "table headers' raised surface"],
    ["--fg2", "--ink", "lede and prose"], ["--fg2", "--ink2", "status values, the band's .covers span, rung chip text"],
    ["--fg2", "--ink3", "raised-surface secondary text"],
    ["--fg3", "--ink", "placeholder text in the form"], ["--fg3", "--ink2", "the .needs block and the em-dash separators"],
    ["--fg3", "--ink3", "raised-surface tertiary text"],
    ["--acc", "--ink", "links in prose"], ["--acc", "--ink2", "CTA verbs, eyebrows, the capability names"],
    ["--acc", ["--ink2", "--acc-soft"], "a CTA card while hovered"],
    ["--data", "--ink2", "every derived figure — the colour that means it has a witness"],
    ["--data", ["--ink2", "--data-soft"], "a live_local chip on its own tint"],
    ["--warn", "--ink2", "the LIMIT row, the claim tag, the ? rung"],
    ["--warn", ["--ink2", "rgba(245,196,81,.06)"], "the claim tag on its own tint"],
    ["--acc-ink", "--acc", "the label inside a primary button"],
    ["#9aa4b2", "--ink2", "the spec rung chip"], ["#7aa2f7", "--ink2", "the in_tree rung chip"],
    ["#4ade80", "--ink2", "the live_deployed rung chip"], ["#c4a1ff", "--ink2", "the external rung chip"],
];
let worst = Infinity, worstName = "";
for (const [fg, bg, where] of CONTRAST_PAIRS) {
    const r = contrast(fg, bg);
    const name = `${fg} on ${Array.isArray(bg) ? bg.join(" + ") : bg}`;
    if (r < worst) { worst = r; worstName = name; }
    T(`contrast ${name} — ${where}`, r >= 4.5, `${r.toFixed(2)}:1`);
}
T("the least legible declared pair clears the 4.5:1 floor", worst >= 4.5, `${worstName} at ${worst.toFixed(2)}:1`);

/* ==========================================================================
   14. THE CASCADE, RESOLVED OVER THE ARTIFACT. r7 and r8.

   A DECLARED TOKEN IS NOT A PAINTED COLOUR. `.top nav a` has specificity
   0,2,1 and `.btn` has 0,1,0, so an unqualified nav rule repaints a button
   inside the nav in --fg2 on --acc: the header call to action ships
   unreadable, and it did on all nine surfaces built before this one. Every
   contrast check above passed the whole time, because they read declared
   tokens and not the rule that actually wins on a real element.

   So this parses the emitted markup into elements with their ancestors, parses
   the emitted stylesheet into rules with specificity and source order,
   resolves `color` for every button the way a browser would — !important,
   then specificity, then source order, with media queries evaluated at a
   width — and refuses when a non-button rule decides a button's colour.
   ========================================================================== */
const VOID = new Set(["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"]);
function parseDom(html) {
    const body = html.slice(html.indexOf("<body>"));
    const stack = [{ tag: "body", classes: [], id: "", attrs: {}, children: 0, parent: null }];
    const all = [];
    for (const m of body.matchAll(/<!--[\s\S]*?-->|<(\/)?([a-zA-Z][\w-]*)\b([^>]*)>/g)) {
        if (m[0].startsWith("<!--")) continue;
        const [, close, tag, attrText] = m;
        const t = tag.toLowerCase();
        if (close) { if (stack.length > 1) stack.pop(); continue; }
        const attrs = {};
        for (const a of attrText.matchAll(/([\w:-]+)(?:="([^"]*)")?/g)) attrs[a[1].toLowerCase()] = a[2] ?? "";
        const parent = stack[stack.length - 1];
        parent.children++;
        const el = {
            tag: t, id: attrs.id || "", classes: (attrs.class || "").trim().split(/\s+/).filter(Boolean),
            attrs, parent, index: parent.children,
        };
        all.push(el);
        if (!VOID.has(t) && !/\/$/.test(attrText)) stack.push(el);
    }
    return all;
}
function parseCss(css) {
    const rules = [];
    let order = 0;
    function block(text, media) {
        const re = /([^{}]+)\{([^{}]*)\}/g;
        let m;
        while ((m = re.exec(text))) {
            const sels = m[1].split(",").map((s) => s.trim()).filter(Boolean);
            const decls = {};
            for (const d of m[2].split(";")) {
                const i = d.indexOf(":");
                if (i < 0) continue;
                const prop = d.slice(0, i).trim().toLowerCase();
                let val = d.slice(i + 1).trim();
                const imp = /!important$/.test(val);
                if (imp) val = val.replace(/!important$/, "").trim();
                decls[prop] = { value: val, important: imp };
            }
            for (const s of sels) rules.push({ sel: s, decls, media, order: order++ });
        }
    }
    /* Pull @media blocks out first, then treat the remainder as top level. */
    let rest = css;
    const at = /@media([^{]+)\{((?:[^{}]*\{[^{}]*\})*)\}/g;
    let m, kept = "";
    let last = 0;
    while ((m = at.exec(css))) {
        kept += css.slice(last, m.index);
        last = at.lastIndex;
        block(m[2], m[1].trim());
    }
    kept += css.slice(last);
    rest = kept;
    block(rest, null);
    rules.sort((a, b) => a.order - b.order);
    return rules;
}
const STATE_PSEUDO = /:(hover|active|focus|focus-visible|focus-within|visited|target|invalid|valid|disabled|checked|placeholder|-\w+-\w+)/g;
function specificity(sel) {
    let a = 0, b = 0, c = 0;
    const s = sel.replace(/::[\w-]+/g, () => { c++; return ""; });
    for (const _ of s.matchAll(/#[\w-]+/g)) a++;
    for (const _ of s.matchAll(/\.[\w-]+/g)) b++;
    for (const _ of s.matchAll(/\[[^\]]*\]/g)) b++;
    for (const _ of s.matchAll(/:(?!not\()[\w-]+/g)) b++;
    for (const _ of s.replace(/:not\(([^)]*)\)/g, "$1").matchAll(/(^|[\s>+~])([a-zA-Z][\w-]*)/g)) c++;
    return a * 10000 + b * 100 + c;
}
function matchCompound(el, comp) {
    if (!el) return false;
    let s = comp;
    let m;
    while ((m = /:not\(([^)]*)\)/.exec(s))) {
        if (matchCompound(el, m[1])) return false;
        s = s.slice(0, m.index) + s.slice(m.index + m[0].length);
    }
    for (const a of s.matchAll(/\[([\w:-]+)(?:([~|^$*]?=)"?([^\]"]*)"?)?\]/g)) {
        const v = el.attrs[a[1].toLowerCase()];
        if (v === undefined) return false;
        if (a[2] && v !== a[3]) return false;
    }
    s = s.replace(/\[[^\]]*\]/g, "");
    for (const p of s.matchAll(/:(first-child|last-child)/g)) {
        if (p[1] === "first-child" && el.index !== 1) return false;
    }
    s = s.replace(/::?[\w-]+(\([^)]*\))?/g, "");
    for (const cl of s.matchAll(/\.([\w-]+)/g)) if (!el.classes.includes(cl[1])) return false;
    for (const idm of s.matchAll(/#([\w-]+)/g)) if (el.id !== idm[1]) return false;
    const tag = /^([a-zA-Z][\w-]*)/.exec(s.replace(/^[.#]/, "x"));
    const bare = /^([a-zA-Z][\w-]*)/.exec(s);
    if (bare && bare[1] !== "x" && el.tag !== bare[1].toLowerCase()) return false;
    if (s.trim() === "*") return true;
    void tag;
    return true;
}
function matchSelector(el, sel) {
    const parts = sel.trim().split(/\s*([>+~])\s*|\s+/).filter((x) => x !== undefined && x !== "");
    let i = parts.length - 1;
    if (!matchCompound(el, parts[i])) return false;
    let cur = el.parent;
    i--;
    while (i >= 0) {
        let comb = " ";
        if ([">", "+", "~"].includes(parts[i])) { comb = parts[i]; i--; }
        const want = parts[i];
        if (comb === ">") {
            if (!matchCompound(cur, want)) return false;
            cur = cur ? cur.parent : null;
        } else {
            let up = cur, ok = false;
            while (up) { if (matchCompound(up, want)) { ok = true; up = up.parent; break; } up = up.parent; }
            if (!ok) return false;
            cur = up;
        }
        i--;
    }
    return true;
}
function mediaApplies(q, width) {
    if (!q) return true;
    if (/prefers-reduced-motion/.test(q)) return false;
    let ok = true;
    for (const m of q.matchAll(/\((min|max)-width:\s*(\d+)px\)/g)) {
        const n = Number(m[2]);
        ok = ok && (m[1] === "min" ? width >= n : width <= n);
    }
    return ok;
}
function resolve(el, prop, rules, width, state) {
    let best = null;
    for (const r of rules) {
        if (!(prop in r.decls)) continue;
        if (!mediaApplies(r.media, width)) continue;
        const needsState = (r.sel.match(STATE_PSEUDO) || []).map((x) => x.slice(1));
        if (needsState.some((p) => !state.includes(p))) continue;
        if (/::[\w-]+/.test(r.sel)) continue;
        if (!matchSelector(el, r.sel)) continue;
        const sp = specificity(r.sel);
        const imp = r.decls[prop].important;
        if (!best || imp > best.imp || (imp === best.imp && (sp > best.sp || (sp === best.sp && r.order > best.order)))) {
            best = { imp, sp, order: r.order, sel: r.sel, value: r.decls[prop].value };
        }
    }
    return best;
}
{
    const emitCss = read("./index.html").split("<style>")[1].split("</style>")[0];
    const rules = parseCss(emitCss);
    const dom = parseDom(landing);
    const btnRule = rules.find((r) => r.sel === ".btn" && r.decls.color);
    const btnDeclared = btnRule ? btnRule.decls.color.value : null;
    T("the stylesheet declares a colour for .btn", !!btnDeclared, btnDeclared || "none");
    const buttons = dom.filter((e) => e.classes.includes("btn") || e.tag === "button");
    T("the page has buttons to resolve", buttons.length > 0, `${buttons.length} buttons`);
    const wrong = [];
    for (const w of [390, 1280]) {
        for (const state of [[], ["hover"]]) {
            for (const b of buttons) {
                const r = resolve(b, "color", rules, w, state);
                const ghost = b.classes.includes("ghost");
                const wantedSel = b.tag === "button" ? ".say button" : (ghost ? ".btn.ghost" : ".btn");
                if (!r) { wrong.push(`${wantedSel} @${w}px — no rule paints it`); continue; }
                if (!/^\.btn|^\.say button/.test(r.sel)) {
                    wrong.push(`${wantedSel} @${w}px${state.length ? ":" + state[0] : ""} — decided by "${r.sel}" (${r.value}), not by its own rule`);
                }
            }
        }
    }
    T("every button's colour is decided by a button rule, at 390px and 1280px, hovered and not",
        wrong.length === 0, wrong.join("; ") || `${buttons.length} buttons × 2 widths × 2 states resolved`);
    /* And the value that wins must be the ink the token declares, not --fg2. */
    const inkWrong = [];
    for (const b of buttons.filter((e) => e.classes.includes("btn") && !e.classes.includes("ghost"))) {
        const r = resolve(b, "color", rules, 1280, []);
        if (!r || r.value !== "var(--acc-ink)") inkWrong.push(r ? r.value : "nothing");
    }
    T("a primary .btn resolves to the ink its own rule declares", inkWrong.length === 0,
        inkWrong.join(", ") || "var(--acc-ink) everywhere");

    /* Travis, 2026-08-17: "there is no animation for these websites at the top
       above the fold." Presence is not placement, and the panel only occupies
       the first screenful if something gives it height. RESOLVED rather than
       grepped: an earlier version scanned the stylesheet for ".idanim{…
       min-height" and passed with the base rule's height deleted, because the
       min-width:900px rule still had one — the panel collapsed to nothing on
       a phone and the gate approved it. */
    const panel = dom.find((e) => e.classes.includes("idanim"));
    T("the identity animation panel is in the markup", !!panel);
    const flat = [];
    for (const w of [390, 1280]) {
        const mh = panel && resolve(panel, "min-height", rules, w, []);
        const px = mh ? parseInt(mh.value, 10) : 0;
        if (!(px >= 150)) flat.push(`${w}px → ${mh ? mh.value : "no min-height"}`);
    }
    T("the animation panel resolves to a real height at 390px and 1280px", flat.length === 0,
        flat.join("; ") || "≥150px at both widths");
}

/* ==========================================================================
   15. EVERY INTERACTIVE ELEMENT CAN BE SEEN TO BE INTERACTIVE
   .logo had no :hover rule at all on the reference surface, so hovering the
   top-left changed nothing and there was no way to tell it was a link.
   ========================================================================== */
{
    const styles = [...landing.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/gi)].map((m) => m[1]).join("\n");
    const hoverSel = [...styles.matchAll(/([^{}]*?):hover/g)].map((m) => m[1]).join(" , ");
    const handles = new Set();
    for (const el of markup.matchAll(/<(a|button)\b([^>]*)>/gi)) {
        const cls = /class="([^"]*)"/.exec(el[2]);
        handles.add(cls ? "." + cls[1].trim().split(/\s+/)[0] : el[1].toLowerCase());
    }
    const naked = [...handles].filter((h) => h.startsWith(".")
        ? !new RegExp(`\\${h}(?![\\w-])`).test(hoverSel)
        : !new RegExp(`(^|[\\s>+~,(])${h}(?=[\\s.:>+~,)\\[]|$)`, "m").test(hoverSel));
    T("/ every interactive element has a visible :hover", naked.length === 0,
        naked.length ? `no hover for: ${naked.join(", ")}` : `${handles.size} kinds, all covered`);
    T("/ declares a focus-visible ring", /:focus-visible\s*\{/.test(styles));
    T("/ form fields show a hover state too", /\.say-f input:hover/.test(styles));
}

console.log(`\n${pass} passed, ${fail} failed (publication gate)`);
if (fail) process.exit(1);

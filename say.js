(function () {
var form = document.querySelector("form.say");
if (!form || !window.fetch || !window.FormData) return;
var msg = form.querySelector(".say-msg");
var btn = form.querySelector("button[type=submit]");
if (!msg || !btn) return;
function say(text, cls) {
msg.textContent = text;
msg.className = "say-msg" + (cls ? " " + cls : "");
}
form.addEventListener("submit", function (e) {
if (!form.checkValidity()) {
e.preventDefault();
var bad = form.querySelector(":invalid");
say(bad && bad.name === "email"
? "That email address will not parse."
: "Both fields are needed.", "bad");
if (bad) bad.focus();
return;
}
e.preventDefault();
btn.disabled = true;
say("sending…");
window.fetch(form.action, {
method: "POST",
body: new window.FormData(form),
headers: { Accept: "application/json" }
}).then(function (res) {
return res.json().then(
function (data) { return { ok: res.ok, status: res.status, data: data }; },
function () { return { ok: res.ok, status: res.status, data: null }; }
);
}).then(function (r) {
if (r.ok) {
form.reset();
say("Sent. A person reads these; give it a day or two.", "ok");
btn.disabled = false;
return;
}
var why = (r.data && (r.data.error || (r.data.errors && r.data.errors.map(
function (x) { return x.message; }).join("; ")))) || "HTTP " + r.status;
say("Not sent — " + why, "bad");
btn.disabled = false;
}).catch(function () {
say("Not sent — the request never completed. Check the connection, or anything blocking formspree.io.", "bad");
btn.disabled = false;
});
});
})();

// Agrege les parcours QueteRoute (issues [route]) en une route communautaire : QueteRoute/Route.lua
// Entree : EXPORT_TEXT (corps de l'issue) + CONTRIB (auteur GitHub). Donnees brutes : route-data.json
// Format d'export : R1;Perso-Royaume;Faction|A;qid;lvl;map;x;y;npc;titre|T;qid;lvl;map;x;y;npc|O;qid;i;f;lvl;map;x;y
const fs = require("fs");
const path = require("path");

const racine = path.join(__dirname, "..");
const dataPath = path.join(racine, "route-data.json");
const luaPath = path.join(racine, "QueteRoute", "Route.lua");
const texte = process.argv[2] || process.env.EXPORT_TEXT || "";
const contrib = (process.env.CONTRIB || "anonyme").replace(/[^\w.-]/g, "_");

const data = fs.existsSync(dataPath) ? JSON.parse(fs.readFileSync(dataPath, "utf8")) : { contributeurs: {} };

// ---- Extraction des parcours dans le texte (un parcours commence par "R1;")
let importes = 0, evenements = 0;
for (const bloc of texte.split(/R1;/).slice(1)) {
    // Chaque enregistrement tient sur une ligne : ce qui suit un retour a la ligne (fin du bloc de code de l'issue) est ignore
    const parts = bloc.split("|").map((s) => s.split("\n")[0].trim()).filter(Boolean);
    const [perso, faction] = parts[0].split(";");
    if (!perso) continue;
    const titre = (t) => (t || "").replace(/;\d+$/, "").replace(/`+$/, "").trim();
    const events = [];
    for (const p of parts.slice(1)) {
        const f = p.split(";");
        if (f[0] === "A" && f.length >= 8) events.push({ k: "A", q: +f[1], lvl: +f[2], map: +f[3], x: +f[4], y: +f[5], npc: f[6], n: titre(f.slice(7).join(";")) });
        else if (f[0] === "T" && f.length >= 7) events.push({ k: "T", q: +f[1], lvl: +f[2], map: +f[3], x: +f[4], y: +f[5], npc: f[6], n: titre(f.slice(7).join(";")) });
        else if (f[0] === "O" && f.length >= 8) events.push({ k: "O", q: +f[1], i: +f[2], f: +f[3], lvl: +f[4], map: +f[5], x: +f[6], y: +f[7] });
    }
    if (events.length === 0) continue;
    const cle = contrib + "/" + perso.replace(/[^\w.-]/g, "_");
    data.contributeurs[cle] = { faction: faction || "Neutral", events };   // remplace l'ancien parcours du meme perso
    importes++; evenements += events.length;
}
fs.writeFileSync(dataPath, JSON.stringify(data, null, 1), "utf8");

// ---- Agregation
const mediane = (arr) => { if (!arr.length) return undefined; const s = [...arr].sort((a, b) => a - b); const m = Math.floor(s.length / 2); return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2; };
const plusFrequent = (arr) => { const c = new Map(); for (const v of arr) if (v !== undefined && v !== "" && !Number.isNaN(v)) c.set(v, (c.get(v) || 0) + 1); let best; for (const [v, n] of c) if (!best || n > best[1]) best = [v, n]; return best && best[0]; };
const pointMedian = (evs) => {
    const valides = evs.filter((e) => e.map > 0 && e.x > 0 && e.y > 0);
    if (!valides.length) return undefined;
    const map = plusFrequent(valides.map((e) => e.map));
    const surMap = valides.filter((e) => e.map === map);
    return { map, x: +mediane(surMap.map((e) => e.x)).toFixed(3), y: +mediane(surMap.map((e) => e.y)).toFixed(3), pnj: plusFrequent(surMap.map((e) => e.npc)) };
};

// Regroupe les positions d'un objectif en "spots" (rayon RAYON en coordonnees de carte, ~1.2 % de la carte).
// Un objectif "objets disperses" donne plusieurs spots ; en jeu, la fleche les enchaine.
const RAYON = 0.012;
const spots = (evs) => {
    const valides = evs.filter((e) => e.map > 0 && e.x > 0 && e.y > 0);
    const clusters = [];
    for (const e of valides) {
        let c = clusters.find((c) => c.map === e.map && Math.hypot(c.x - e.x, c.y - e.y) <= RAYON);
        if (c) { c.x = (c.x * c.n + e.x) / (c.n + 1); c.y = (c.y * c.n + e.y) / (c.n + 1); c.n++; }
        else clusters.push({ map: e.map, x: e.x, y: e.y, n: 1 });
    }
    clusters.sort((a, b) => b.n - a.n);
    return clusters.map((c) => ({ map: c.map, x: +c.x.toFixed(3), y: +c.y.toFixed(3), n: c.n }));
};

const factions = {};
for (const { faction, events } of Object.values(data.contributeurs)) {
    const F = (factions[faction] = factions[faction] || {});
    const accepts = events.filter((e) => e.k === "A");
    accepts.forEach((e, idx) => {
        const Q = (F[e.q] = F[e.q] || { A: [], T: [], O: {}, rangs: [], titres: [] });
        Q.A.push(e); Q.rangs.push(accepts.length > 1 ? idx / (accepts.length - 1) : 0); if (e.n) Q.titres.push(e.n);
    });
    for (const e of events) {
        if (e.k === "T") { const Q = (F[e.q] = F[e.q] || { A: [], T: [], O: {}, rangs: [], titres: [] }); Q.T.push(e); if (e.n) Q.titres.push(e.n); }
        else if (e.k === "O") { const Q = (F[e.q] = F[e.q] || { A: [], T: [], O: {}, rangs: [], titres: [] }); (Q.O[e.i] = Q.O[e.i] || []).push(e); }
    }
}

// ---- Ecriture de Route.lua
const esc = (s) => '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
const luaPoint = (p) => {
    if (!p) return "nil";
    let s = `{ map = ${p.map}, x = ${p.x}, y = ${p.y}`;
    if (p.pnj) s += `, pnj = ${esc(p.pnj)}`;
    if (p.points && p.points.length > 1) s += `, points = { ${p.points.map((q) => `{ map = ${q.map}, x = ${q.x}, y = ${q.y}, n = ${q.n} }`).join(", ")} }`;
    return s + " }";
};
const lignes = [
    "-- Route communautaire, generee par tools/merge-route.js a partir des issues [route] sur GitHub. Ne pas editer a la main.",
    "-- ns.route[faction] = { ordre = { questID... }, quetes = { [questID] = { titre, niveau, contributeurs, prendre, rendre, objectifs } } }",
    "local _, ns = ...",
    "ns.route = {",
];
let totalQuetes = 0;
for (const faction of Object.keys(factions).sort()) {
    const F = factions[faction];
    const quetes = [];
    for (const [qid, Q] of Object.entries(F)) {
        const niveau = mediane(Q.A.map((e) => e.lvl)) ?? mediane(Q.T.map((e) => e.lvl)) ?? 0;
        const rang = mediane(Q.rangs) ?? 1;
        const objectifs = Object.keys(Q.O).sort((a, b) => a - b).map((i) => {
            const liste = spots(Q.O[i]);
            if (!liste.length) return [i, undefined];
            // Point principal = spot le plus frequente ; tous les spots (max 12) pour le parcours
            const p = { map: liste[0].map, x: liste[0].x, y: liste[0].y, points: liste.slice(0, 12) };
            return [i, p];
        }).filter(([, p]) => p);
        // Titres deja stockes avec un ";0" parasite (anciens exports) : nettoyes ici aussi
        const titres = Q.titres.map((t) => t.replace(/;\d+$/, "").replace(/\n[\s\S]*$/, "").replace(/`+$/, "").trim()).filter(Boolean);
        quetes.push({ qid: +qid, titre: plusFrequent(titres), niveau, rang, contributeurs: new Set(Q.A.map((e) => e.lvl + ":" + e.map)).size || Q.T.length,
            prendre: pointMedian(Q.A), rendre: pointMedian(Q.T), objectifs });
    }
    quetes.sort((a, b) => (a.niveau - b.niveau) || (a.rang - b.rang) || (a.qid - b.qid));
    totalQuetes += quetes.length;
    lignes.push(`    [${esc(faction)}] = {`);
    lignes.push(`        ordre = { ${quetes.map((q) => q.qid).join(", ")} },`);
    lignes.push("        quetes = {");
    for (const q of quetes) {
        const objs = q.objectifs.map(([i, p]) => `[${i}] = ${luaPoint(p)}`).join(", ");
        lignes.push(`            [${q.qid}] = { titre = ${esc(q.titre || "Quete " + q.qid)}, niveau = ${q.niveau}, contributeurs = ${q.contributeurs}, prendre = ${luaPoint(q.prendre)}, rendre = ${luaPoint(q.rendre)}, objectifs = { ${objs} } },`);
    }
    lignes.push("        },", "    },");
}
lignes.push("}", "");
fs.writeFileSync(luaPath, lignes.join("\n"), "utf8");

const resume = `${importes} parcours importe(s) (${evenements} evenements). Route : ${totalQuetes} quete(s) sur ${Object.keys(factions).length} faction(s), ${Object.keys(data.contributeurs).length} contributeur(s).`;
fs.writeFileSync(path.join(racine, "merge-summary.txt"), resume, "utf8");
console.log(resume);

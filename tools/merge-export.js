// Fusionne un ou plusieurs exports QueteCibles ("questID:Mob1;Mob2|questID:Mob3") dans Data.lua.
// Usage : node tools/merge-export.js  (lit l'export dans la variable d'environnement EXPORT_TEXT)
//         node tools/merge-export.js "texte d'export"
const fs = require("fs");
const path = require("path");

const dataPath = path.join(__dirname, "..", "Data.lua");
const texte = process.argv[2] || process.env.EXPORT_TEXT || "";

// ---- Lecture de Data.lua existant : [123] = { "A", "B" },
const base = new Map();
const existant = fs.existsSync(dataPath) ? fs.readFileSync(dataPath, "utf8") : "";
for (const m of existant.matchAll(/\[(\d+)\]\s*=\s*\{([^}]*)\}/g)) {
    const qid = Number(m[1]);
    const mobs = base.get(qid) || new Set();
    for (const s of m[2].matchAll(/"((?:[^"\\]|\\.)*)"/g)) mobs.add(s[1].replace(/\\"/g, '"'));
    base.set(qid, mobs);
}

// ---- Extraction des exports dans le texte (on tolere du texte autour, ex : corps d'une issue)
let ajoutes = 0, quetes = new Set();
const candidats = texte.match(/\d+\s*:[^|\n`]+(?:\|\s*\d+\s*:[^|\n`]+)*/g) || [];
for (const bloc of candidats) {
    for (const part of bloc.split("|")) {
        const m = part.match(/^\s*(\d+)\s*:\s*(.+?)\s*$/);
        if (!m) continue;
        const qid = Number(m[1]);
        const mobs = base.get(qid) || new Set();
        for (const nomBrut of m[2].split(";")) {
            const nom = nomBrut.trim();
            if (!nom || nom.length > 60) continue;
            if (!mobs.has(nom)) { mobs.add(nom); ajoutes++; quetes.add(qid); }
        }
        base.set(qid, mobs);
    }
}

// ---- Reecriture de Data.lua
const lignes = [
    "-- Base partagee, livree avec l'addon. Fusionnee dans la base apprise au chargement.",
    '-- Format : [questID] = { "Nom du mob", "@PNJ a qui parler", "!PNJ qui donne la quete", "?PNJ a qui la rendre" }',
    "-- Genere automatiquement par tools/merge-export.js a partir des issues [export].",
    "local _, ns = ...",
    "ns.seed = {",
];
const esc = (s) => '"' + s.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
for (const qid of [...base.keys()].sort((a, b) => a - b)) {
    const mobs = [...base.get(qid)].sort((a, b) => a.localeCompare(b));
    if (mobs.length) lignes.push(`    [${qid}] = { ${mobs.map(esc).join(", ")} },`);
}
lignes.push("}", "");
fs.writeFileSync(dataPath, lignes.join("\n"), "utf8");

let total = 0;
for (const mobs of base.values()) total += mobs.size;
const resume = `${ajoutes} lien(s) ajoute(s) sur ${quetes.size} quete(s). Base : ${base.size} quete(s), ${total} lien(s).`;
fs.writeFileSync(path.join(__dirname, "..", "merge-summary.txt"), resume, "utf8");
console.log(resume);

.pragma library

function normalize(value) { return String(value || "").normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase(); }
function metadata(entry) {
    return { entry: entry, id: entry.id, title: entry.name, subtitle: entry.genericName || entry.comment || "Application",
             icon: entry.icon, name: normalize(entry.name), generic: normalize(entry.genericName),
             details: normalize([entry.comment, entry.keywords.join(" "), entry.categories.join(" ")].join(" ")) };
}
function score(app, query) {
    let total = 0;
    for (const token of query.split(/\s+/)) {
        let score = 0;
        if (app.name === token) score = 1200;
        else if (app.name.startsWith(token)) score = 900;
        else if (app.name.split(/[\s.-]+/).some(word => word.startsWith(token))) score = 750;
        else if (app.name.includes(token)) score = 600;
        else if (app.generic.includes(token)) score = 300;
        else if (app.details.includes(token)) score = 100;
        if (!score) return 0;
        total += score;
    }
    return total;
}
function applications(cache, query, limit) {
    query = normalize(query).trim();
    if (!query) return [];
    return cache.map(app => ({ app: app, score: score(app, query) })).filter(result => result.score > 0)
        .sort((a, b) => b.score - a.score || a.app.title.localeCompare(b.app.title))
        .slice(0, limit).map(result => ({kind: "app", id: result.app.id, title: result.app.title, subtitle: result.app.subtitle, icon: result.app.icon, value: ""}));
}

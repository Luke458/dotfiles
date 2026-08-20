.pragma library

function scoreItem(item, searchText) {
    const search = String(searchText || "").toLowerCase().trim();
    if (search === "")
        return 0;

    const name = String(item.name || "").toLowerCase();
    const genericName = String(item.genericName || "").toLowerCase();
    const metadata = String(item.metadata || "").toLowerCase();

    if (name === search)
        return 100;
    if (name.startsWith(search))
        return 80;
    if (name.includes("/" + search) || name.includes(" " + search))
        return 60;
    if (genericName.startsWith(search))
        return 40;
    if (name.includes(search))
        return 20;
    if (genericName.includes(search) || metadata.includes(search))
        return 10;
    return -1;
}

function filter(items, searchText, limit) {
    const matches = [];
    const source = items || [];
    for (let i = 0; i < source.length; i++) {
        const score = scoreItem(source[i], searchText);
        if (score >= 0)
            matches.push({ score: score, item: source[i] });
    }

    matches.sort((a, b) => {
        if (a.score !== b.score)
            return b.score - a.score;
        return String(a.item.name || "").localeCompare(String(b.item.name || ""));
    });

    return matches.slice(0, Math.max(0, limit === undefined ? 100 : limit)).map(match => match.item);
}

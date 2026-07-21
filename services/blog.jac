"""Markdown blog engine.

Reads `content/posts/*.md` (and standalone pages like `content/about.md`),
parses simple `key: value` frontmatter, and renders markdown to HTML on the
server with Pygments syntax highlighting. The filesystem is the database.
"""
import os;
import markdown;
import from pathlib { Path }
import from datetime { datetime }

glob POSTS_DIR: str = os.path.join("content", "posts");
glob PAGES_DIR: str = "content";
glob WORDS_PER_MINUTE: int = 200;

obj PostMeta {
    has slug: str;
    has title: str;
    has date: str;
    has display_date: str;
    has tags: list[str];
    has summary: str;
    has reading_minutes: int;
}

obj Post {
    has meta: PostMeta;
    has html: str;
}

obj ParsedDoc {
    has fm: dict[str, str];
    has body: str;
}

def _parse_frontmatter(raw: str) -> ParsedDoc {
    if not raw.startswith("---") {
        return ParsedDoc(fm={}, body=raw);
    }
    lines = raw.split("\n");
    fm: dict[str, str] = {};
    body_start = 0;
    for i in range(1, len(lines)) {
        line = lines[i];
        if line.strip() == "---" {
            body_start = i + 1;
            break;
        }
        if ":" in line {
            key = line.split(":")[0].strip();
            fm[key] = line[line.index(":") + 1:].strip();
        }
    }
    return ParsedDoc(fm=fm, body="\n".join(lines[body_start:]));
}

def _display_date(iso: str) -> str {
    try {
        return datetime.strptime(iso, "%Y-%m-%d").strftime("%B %-d, %Y");
    } except Exception {
        return iso;
    }
}

def _md_to_html(text: str) -> str {
    # Pygments has no Jac lexer yet; Python is the closest highlighting fit.
    text = text.replace("```jac", "```python");
    return markdown.markdown(
        text,
        extensions=["fenced_code", "codehilite", "tables", "toc", "sane_lists"],
        extension_configs={
            "codehilite": {"css_class": "codehilite", "guess_lang": False}
        }
    ) as str;
}

def _load_doc(path: str, slug: str) -> Post | None {
    try {
        raw = Path(path).read_text(encoding="utf-8");
    } except Exception {
        return None;
    }
    doc = _parse_frontmatter(raw);
    date = doc.fm.get("date", "");
    tags_raw = doc.fm.get("tags", "");
    meta = PostMeta(
        slug=slug,
        title=doc.fm.get("title", slug),
        date=date,
        display_date=_display_date(date),
        tags=[t.strip() for t in tags_raw.split(",") if t.strip()],
        summary=doc.fm.get("summary", ""),
        reading_minutes=max(1, (len(doc.body.split()) + WORDS_PER_MINUTE - 1) // WORDS_PER_MINUTE)
    );
    return Post(meta=meta, html=_md_to_html(doc.body));
}

def _safe_slug(slug: str) -> bool {
    return bool(slug) and ("/" not in slug) and ("\\" not in slug) and (".." not in slug);
}

def:pub list_posts() -> list[PostMeta] {
    posts: list[PostMeta] = [];
    if not os.path.isdir(POSTS_DIR) {
        return posts;
    }
    for fname in sorted(os.listdir(POSTS_DIR)) {
        if not fname.endswith(".md") {
            continue;
        }
        p = _load_doc(os.path.join(POSTS_DIR, fname), fname[:-3]);
        if p is not None {
            posts.append(p.meta);
        }
    }
    return sorted(posts, key=_by_date, reverse=True);
}

def _by_date(m: PostMeta) -> str {
    return m.date;
}

def:pub get_post(slug: str) -> Post | None {
    if not _safe_slug(slug) {
        return None;
    }
    path = os.path.join(POSTS_DIR, slug + ".md");
    if not os.path.isfile(path) {
        return None;
    }
    return _load_doc(path, slug);
}

def:pub get_page(name: str) -> Post | None {
    if not _safe_slug(name) {
        return None;
    }
    path = os.path.join(PAGES_DIR, name + ".md");
    if not os.path.isfile(path) {
        return None;
    }
    return _load_doc(path, name);
}

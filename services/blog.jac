"""Markdown blog engine.

Reads `content/posts/*.md` (and standalone pages like `content/about.md`),
parses simple `key: value` frontmatter, and renders markdown to HTML on the
server with Pygments syntax highlighting. The filesystem is the database.

Two media forms are lifted out of the markdown before rendering:
- ```mermaid fences become `<pre class="mermaid">` placeholders that the
  client draws as theme-matched SVG (see components/MarkdownContent.jac).
- `@[youtube](id-or-url "caption")` directives, or a YouTube URL alone on
  a line, become responsive privacy-enhanced (youtube-nocookie) embeds.
"""
import os;
import re;
import markdown;
import from html { escape }
import from pathlib { Path }
import from datetime { datetime }

glob POSTS_DIR: str = os.path.join("content", "posts"),
     PAGES_DIR: str = "content",
     WORDS_PER_MINUTE: int = 200,
     YT_DIRECTIVE_RE: str = r'^@\[youtube\]\(\s*([^\s")]+)(?:\s+"([^"]*)")?\s*\)$',
     YT_URL_LINE_RE: str = r"^https?://(?:www\.)?(?:youtube\.com/\S+|youtu\.be/\S+)$",
     YT_ID_EXTRACT_RE: str = r"(?:youtube\.com/(?:watch\?(?:[^#\s]*&)?v=|embed/|shorts/|live/)|youtu\.be/)([A-Za-z0-9_-]{6,20})";

obj PostMeta {
    has slug: str,
        title: str,
        date: str,
        display_date: str,
        tags: list[str],
        summary: str,
        reading_minutes: int;
}

obj Post {
    has meta: PostMeta,
        html: str;
}

obj ParsedDoc {
    has fm: dict[str, str],
        body: str;
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

def _youtube_id(target: str) -> str {
    t = target.strip();
    if re.fullmatch(r"[A-Za-z0-9_-]{6,20}", t) {
        return t;
    }
    m = re.search(YT_ID_EXTRACT_RE, t);
    return m.group(1) if m else "";
}

def _youtube_embed(video_id: str, caption: str) -> str {
    title = escape(caption) if caption else "YouTube video";
    cap_html = f"<figcaption>{escape(caption)}</figcaption>" if caption else "";
    return (
        '<figure class="video-embed"><div class="video-frame">'
        + f'<iframe src="https://www.youtube-nocookie.com/embed/{video_id}" title="{title}" '
        + 'loading="lazy" allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" '
        + 'referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe></div>'
        + cap_html
        + "</figure>"
    );
}

def _fence_run(line: str, ch: str) -> int {
    n = 0;
    while n < len(line) and line[n] == ch {
        n += 1;
    }
    return n;
}

def _mermaid_placeholder(src: str) -> str {
    # Newlines are entity-encoded so the placeholder is a single line the
    # markdown block parser can never split; the browser's textContent
    # decodes them back before the client hands the source to mermaid.
    encoded = escape(src).replace("\n", "&#10;");
    return '<pre class="mermaid">' + encoded + "</pre>";
}

def _preprocess_media(text: str) -> str {
    lines = text.split("\n");
    out: list[str] = [];
    i = 0;
    fence_ch = "";
    fence_len = 0;
    while i < len(lines) {
        line = lines[i];
        stripped = line.strip();
        if fence_ch {
            out.append(line);
            if stripped
            and stripped[0] == fence_ch
            and _fence_run(stripped, fence_ch) >= fence_len {
                fence_ch = "";
                fence_len = 0;
            }
            i += 1;
            continue;
        }
        if stripped.startswith("```") or stripped.startswith("~~~") {
            open_len = _fence_run(stripped, stripped[0]);
            info = stripped[open_len:].strip().lower();
            if info == "mermaid" {
                src_lines: list[str] = [];
                i += 1;
                while i < len(lines) {
                    inner = lines[i].strip();
                    if inner
                    and inner[0] == stripped[0]
                    and _fence_run(inner, stripped[0]) >= open_len {
                        i += 1;
                        break;
                    }
                    src_lines.append(lines[i]);
                    i += 1;
                }
                src = "\n".join(src_lines).strip();
                if src {
                    out.append("");
                    out.append(_mermaid_placeholder(src));
                    out.append("");
                }
                continue;
            }
            fence_ch = stripped[0];
            fence_len = open_len;
            out.append(line);
            i += 1;
            continue;
        }
        m = re.match(YT_DIRECTIVE_RE, stripped);
        if m {
            vid = _youtube_id(m.group(1));
            if vid {
                out.append("");
                out.append(_youtube_embed(vid, m.group(2) or ""));
                out.append("");
                i += 1;
                continue;
            }
        }
        if re.match(YT_URL_LINE_RE, stripped) {
            vid = _youtube_id(stripped);
            if vid {
                out.append("");
                out.append(_youtube_embed(vid, ""));
                out.append("");
                i += 1;
                continue;
            }
        }
        out.append(line);
        i += 1;
    }
    return "\n".join(out);
}

def _md_to_html(text: str) -> str {
    text = _preprocess_media(text);
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
        tags=[
            t.strip()
            for t in tags_raw.split(",")
            if t.strip()
        ],
        summary=doc.fm.get("summary", ""),
        reading_minutes=max(
            1, (len(doc.body.split()) + WORDS_PER_MINUTE - 1) // WORDS_PER_MINUTE
        )
    );
    return Post(meta=meta, html=_md_to_html(doc.body));
}

def _safe_slug(slug: str) -> bool {
    return bool(slug)
    and ("/" not in slug)
    and ("\\" not in slug)
    and (".." not in slug);
}

def:pub list_posts -> list[PostMeta] {
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

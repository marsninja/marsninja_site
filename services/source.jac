"""Live source browser for the site itself.

Walks the project directory on every request (no cache, no snapshot — what
you see is what is serving you) and renders files with Pygments. `.jac` files
get a real Jac lexer, defined right here as a `class` archetype so Pygments'
RegexLexer metaclass can compile its `tokens` table.
"""
import os;
import from pathlib { Path }
import from pygments { highlight }
import from pygments.formatters { HtmlFormatter }
import from pygments.lexer { RegexLexer }
import from pygments.lexers { get_lexer_for_filename }
import from pygments.lexers.special { TextLexer }
import from pygments.token {
    Comment, Keyword, Name, Number, Operator, Punctuation, String, Whitespace
}

glob EXCLUDE_DIRS: set = {".git", ".jac", "node_modules", "__pycache__", "assets"};
glob ALLOW_EXT: set = {".jac", ".toml", ".css", ".md", ".py", ".json"};
glob ALLOW_FILES: set = {".gitignore"};

class JacLexer(RegexLexer) {
    static has name: str = "Jac";
    static has aliases: list = ["jac"];
    static has filenames: list = ["*.jac"];
    static has tokens: dict = {
        "root": [
            (r"#\*[\s\S]*?\*#", Comment.Multiline),
            (r"#.*?$", Comment.Single),
            (r'"""[\s\S]*?"""', String.Doc),
            (r"'''[\s\S]*?'''", String.Doc),
            (r'[fF]?"(\\.|[^"\\\n])*"', String.Double),
            (r"[fF]?'(\\.|[^'\\\n])*'", String.Single),
            (r"@\w+", Name.Decorator),
            (r":(pub|priv|protect)\b", Keyword.Pseudo),
            (r"\b(node|edge|walker|obj|class|enum|impl|sem|test)\b", Keyword.Declaration),
            (r"\b(cl|sv|na)\b(?=\s+(import|def|\{))", Keyword.Namespace),
            (r"\b(def|can|has|let|glob|with|entry|exit|import|from|include|as|"
             r"return|report|visit|spawn|ignore|disengage|skip|revisit|if|elif|"
             r"else|for|while|in|to|by|not|and|or|try|except|finally|raise|"
             r"assert|del|match|case|switch|async|await|lambda|yield|global|"
             r"nonlocal|break|continue|is|new|check)\b", Keyword),
            (r"\b(root|self|here|super|init|postinit)\b", Name.Builtin.Pseudo),
            (r"\b(True|False|None)\b", Keyword.Constant),
            (r"\b(str|int|float|bool|bytes|list|dict|set|tuple|any|type|"
             r"JsxElement|Callable|Ref|Generator)\b", Keyword.Type),
            (r"\b(print|len|range|enumerate|sorted|reversed|zip|max|min|abs|"
             r"sum|open|isinstance|jid|unsafe_html)\b", Name.Builtin),
            (r"\b\d+\.\d+\b", Number.Float),
            (r"\b\d+\b", Number.Integer),
            (r"(\+\+>|<\+\+|-->|<--|\|>|<\||:=|->|=>)", Operator.Word),
            (r"[-+*/%=<>!&|^~?@]+", Operator),
            (r"[{}()\[\],;.:]", Punctuation),
            (r"[A-Za-z_]\w*", Name),
            (r"\s+", Whitespace),
            (r".", Whitespace),
        ],
    };
}

obj SourceFile {
    has path: str;
    has dir: str;
    has name: str;
    has language: str;
    has size_bytes: int;
    has lines: int;
}

obj SourceView {
    has path: str;
    has language: str;
    has size_bytes: int;
    has lines: int;
    has raw: str;
    has html: str;
}

def _language_of(name: str) -> str {
    ext = os.path.splitext(name)[1].lower();
    table = {
        ".jac": "jac", ".toml": "toml", ".css": "css", ".md": "markdown",
        ".py": "python", ".json": "json"
    };
    return table.get(ext, "text");
}

def _walk_sources() -> list[SourceFile] {
    proj_root = os.getcwd();
    found: list[SourceFile] = [];
    for (cur, dirnames, filenames) in os.walk(proj_root) {
        kept = [d for d in sorted(dirnames) if not d.startswith(".") and d not in EXCLUDE_DIRS];
        dirnames.clear();
        dirnames.extend(kept);
        for fname in sorted(filenames) {
            ext = os.path.splitext(fname)[1].lower();
            if (ext not in ALLOW_EXT) and (fname not in ALLOW_FILES) {
                continue;
            }
            full = str(os.path.join(cur, fname));
            rel = str(os.path.relpath(full, proj_root));
            try {
                text = Path(full).read_text(encoding="utf-8");
            } except Exception {
                continue;
            }
            found.append(SourceFile(
                path=rel.replace(os.sep, "/"),
                dir=os.path.dirname(rel).replace(os.sep, "/"),
                name=fname,
                language=_language_of(fname),
                size_bytes=os.path.getsize(full),
                lines=text.count("\n") + 1
            ));
        }
    }
    return sorted(found, key=_tree_order);
}

def _tree_order(f: SourceFile) -> tuple {
    # Root files first (main.jac leading), then directories alphabetically.
    return (
        0 if f.dir == "" else 1,
        f.dir,
        0 if f.name == "main.jac" else 1,
        f.name
    );
}

def _pick_lexer(path: str, text: str) -> object {
    if path.endswith(".jac") {
        return JacLexer();
    }
    try {
        return get_lexer_for_filename(path, text);
    } except Exception {
        return TextLexer();
    }
}

def:pub source_tree() -> list[SourceFile] {
    return _walk_sources();
}

def:pub source_file(path: str) -> SourceView | None {
    allowed = {f.path: f for f in _walk_sources()};
    entry = allowed.get(path);
    if entry is None {
        return None;
    }
    try {
        text = Path(os.path.join(os.getcwd(), path)).read_text(encoding="utf-8");
    } except Exception {
        return None;
    }
    formatter = HtmlFormatter(cssclass="codehilite", linenos="table");
    html = highlight(text, _pick_lexer(path, text), formatter) as str;
    return SourceView(
        path=path,
        language=entry.language,
        size_bytes=entry.size_bytes,
        lines=entry.lines,
        raw=text,
        html=html
    );
}

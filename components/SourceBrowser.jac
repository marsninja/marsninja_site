sv import from ..services.source { source_tree, source_file, SourceFile, SourceView }
import from "@jac/runtime" { useLocation, useNavigate }
import from .ui.badge { Badge }
import from .ui.button { Button }
import from .ui.skeleton { Skeleton }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Copy01Icon,
    CopyCheckIcon,
    CodeIcon,
    ArrowRight01Icon,
    Folder01Icon
}

glob _LANG_DOT: dict[str, str] = {
         "jac": "var(--primary)",
         "toml": "var(--chart-2)",
         "css": "var(--chart-3)",
         "markdown": "var(--chart-4)",
         "python": "var(--chart-5)",
         "json": "var(--muted-foreground)",
         "text": "var(--muted-foreground)"
     };

def _fmt_size(n: int) -> str {
    if n >= 1024 {
        return f"{(n / 1024):.1f} KB";
    }
    return f"{n} B";
}

def _parent_dir(d: str) -> str {
    idx = d.rfind("/");
    return d[:idx] if idx >= 0 else "";
}

"""Every directory that appears in the tree, including intermediate ones."""
def _collect_dirs(files: list[SourceFile]) -> list[str] {
    found: list[str] = [];
    for f in files {
        if not f.dir {
            continue;
        }
        acc = "";
        for part in f.dir.split("/") {
            acc = part if acc == "" else acc + "/" + part;
            if acc not in found {
                found.append(acc);
            }
        }
    }
    return sorted(found);
}

def _file_row(f: SourceFile, depth: int) -> dict[str, any] {
    return {
        "kind": "file",
        "path": f.path,
        "name": f.name,
        "dir": f.dir,
        "language": f.language,
        "lines": f.lines,
        "depth": depth
    };
}

"""Depth-first rows: each directory, then its subtrees, then its own files."""
def _build_dir_rows(
    parent: str, depth: int, dirs: list[str], files: list[SourceFile], out: list[dict]
) {
    for d in dirs {
        if _parent_dir(d) != parent {
            continue;
        }
        out.append(
            {"kind": "dir", "path": d, "name": d.split("/")[-1], "depth": depth}
        );
        _build_dir_rows(d, depth + 1, dirs, files, out);
        for f in files {
            if f.dir == d {
                out.append(_file_row(f, depth + 1));
            }
        }
    }
}

"""True when any directory on the way down to `dirpath` is collapsed."""
def _any_collapsed(dirpath: str, collapsed: dict[str, bool]) -> bool {
    if not dirpath {
        return False;
    }
    acc = "";
    for part in dirpath.split("/") {
        acc = part if acc == "" else acc + "/" + part;
        if collapsed[acc] {
            return True;
        }
    }
    return False;
}

def:pub SourceBrowser -> JsxElement {
    has tree: list[SourceFile] = [],
        view: SourceView | None = None,
        loading_tree: bool = True,
        loading_file: bool = True,
        copied: bool = False,
        collapsed: dict[str, bool] = {};

    location = useLocation();
    nav = useNavigate();
    searchParams = new(URLSearchParams, location.search);  # jac:ignore[E1053]
    selected = str(searchParams.get("f") or "main.jac");  # jac:ignore[E1031]

    async can with entry {
        tree = await source_tree();
        loading_tree = False;
    }

    async can with [selected] entry {
        loading_file = True;
        copied = False;
        view = await source_file(selected);
        loading_file = False;
    }

    async def handle_copy {
        if view is not None {
            v = view;
            await navigator.clipboard.writeText(v.raw);  # jac:ignore[E1030]
            copied = True;
        }
    }

    def toggle_dir(d: str) {
        updated = {** collapsed};
        updated[d] = False if collapsed[d] else True;
        collapsed = updated;
    }

    dirs = _collect_dirs(tree);
    rows: list[dict] = [];
    for f in tree {
        if f.dir == "" {
            rows.append(_file_row(f, 0));
        }
    }
    _build_dir_rows("", 0, dirs, tree, rows);

    <div className="flex flex-col gap-8">
        <header className="flex flex-col gap-3">
            <h1
                className="flex items-center gap-3 text-3xl sm:text-4xl font-semibold tracking-tight"
            >
                <HugeiconsIcon
                    icon={CodeIcon}
                    strokeWidth={2}
                    className="size-8 text-primary"
                />
                Source
            </h1>
            <p className="text-muted-foreground max-w-2xl leading-relaxed">
                The code serving this page, read live from disk on every request — nothing staged, nothing hidden. Markdown in, Jac out.
            </p>
        </header>
        <div className="flex flex-col lg:flex-row gap-6 items-start">
            <aside
                className="w-full lg:w-64 shrink-0 lg:sticky lg:top-20 lg:max-h-[calc(100vh-7rem)] lg:overflow-y-auto rounded-xl border border-border bg-card"
            >
                {if loading_tree {
                    <div className="p-4 flex flex-col gap-3">
                        <Skeleton className="h-4 w-24"/>
                        <Skeleton className="h-4 w-40"/>
                        <Skeleton className="h-4 w-32"/>
                        <Skeleton className="h-4 w-36"/>
                    </div>
                } else {
                    <nav className="p-2 flex flex-col gap-0.5">
                        {for r in rows {
                            if r["kind"] == "dir"
                            and not _any_collapsed(
                                _parent_dir(r["path"] as str), collapsed
                            ) {
                                <button
                                    key={"dir:" + (r["path"] as str)}
                                    onClick={lambda { toggle_dir(r["path"] as str); }}
                                    className="w-full flex items-center gap-1.5 pr-2 py-1 rounded-md text-[13px] font-medium text-muted-foreground hover:text-foreground hover:bg-accent/50 transition-colors cursor-pointer"
                                    style={{
                                        "paddingLeft": str(12 * (r["depth"] as int) + 8)
                                        + "px"
                                    }}
                                >
                                    <HugeiconsIcon
                                        icon={ArrowRight01Icon}
                                        strokeWidth={2}
                                        className={"size-3.5 shrink-0 transition-transform "
                                        + (
                                            ""
                                                if collapsed[r["path"] as str]
                                                else "rotate-90"
                                        )}
                                    />
                                    <HugeiconsIcon
                                        icon={Folder01Icon}
                                        strokeWidth={2}
                                        className="size-3.5 shrink-0"
                                    />
                                    <span className="truncate">{r["name"]}</span>
                                </button>
                            } elif r["kind"] == "file"
                            and not _any_collapsed(r["dir"] as str, collapsed) {
                                <button
                                    key={r["path"]}
                                    onClick={lambda { nav(
                                        "/source?f="
                                        + encodeURIComponent(r["path"] as str)
                                    ); }}
                                    className={"w-full flex items-center gap-2 pr-3 py-1.5 rounded-md text-sm text-left transition-colors cursor-pointer "
                                    + (
                                        "bg-accent text-foreground font-medium"
                                            if r["path"] == selected
                                            else "text-muted-foreground hover:text-foreground hover:bg-accent/50"
                                    )}
                                    style={{
                                        "paddingLeft": str(
                                            12 * (r["depth"] as int) + 14
                                        )
                                        + "px"
                                    }}
                                >
                                    <span
                                        className="size-2 rounded-full shrink-0"
                                        style={{
                                            "background": _LANG_DOT.get(
                                                r["language"] as str,
                                                "var(--muted-foreground)"
                                            )
                                        }}
                                    />
                                    <span className="truncate">{r["name"]}</span>
                                    <span
                                        className="ml-auto text-[11px] font-mono text-muted-foreground/70"
                                    >
                                        {str(r["lines"] as int)}
                                    </span>
                                </button>
                            }
                        }}
                    </nav>
                } }
            </aside>
            <section
                className="min-w-0 flex-1 rounded-xl border border-border overflow-hidden bg-card"
            >
                <div
                    className="flex flex-wrap items-center gap-3 px-4 py-2.5 border-b border-border bg-muted/40"
                >
                    <p className="font-mono text-sm min-w-0 truncate">
                        {if "/" in selected {
                            <span className="text-muted-foreground">
                                {selected[:selected.rfind("/") + 1]}
                            </span>
                        }}
                        <span className="font-semibold">{selected.split("/")[-1]}</span>
                    </p>
                    <div className="ml-auto flex items-center gap-2">
                        {if view is not None {
                            <span className="text-xs font-mono text-muted-foreground">
                                {str(view.lines)
                                + " lines · "
                                + _fmt_size(view.size_bytes)}
                            </span>
                            <Badge variant="outline" className="font-mono">
                                {view.language}
                            </Badge>
                            <Button
                                variant="ghost"
                                size="icon"
                                onClick={handle_copy}
                                aria-label="Copy file contents"
                            >
                                <HugeiconsIcon
                                    icon={CopyCheckIcon if copied else Copy01Icon}
                                    strokeWidth={2}
                                    className={"size-4 "
                                    + ("text-primary" if copied else "")}
                                />
                            </Button>
                        }}
                    </div>
                </div>
                {if loading_file {
                    <div className="p-5 flex flex-col gap-2.5">
                        <Skeleton className="h-3.5 w-2/3"/>
                        <Skeleton className="h-3.5 w-1/2"/>
                        <Skeleton className="h-3.5 w-3/4"/>
                        <Skeleton className="h-3.5 w-2/5"/>
                        <Skeleton className="h-3.5 w-3/5"/>
                    </div>
                } elif view is None {
                    <div className="p-10 text-center text-muted-foreground">
                        File not found — pick one from the tree.
                    </div>
                } else {
                    <div className="source-view">{unsafe_html(view.html)}</div>
                }  }
            </section>
        </div>
    </div>
}

sv import from ..services.source { source_tree, source_file, SourceFile, SourceView }
import from "@jac/runtime" { useLocation, useNavigate }
import from .ui.badge { Badge }
import from .ui.button { Button }
import from .ui.skeleton { Skeleton }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Copy01Icon, CopyCheckIcon, CodeIcon }

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

def:pub SourceBrowser() -> JsxElement {
    has tree: list[SourceFile] = [];
    has view: SourceView | None = None;
    has loading_tree: bool = True;
    has loading_file: bool = True;
    has copied: bool = False;

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

    async def handle_copy -> None {
        if view is not None {
            v = view;
            await navigator.clipboard.writeText(v.raw);  # jac:ignore[E1030]
            copied = True;
        }
    }

    dirs: list[str] = [];
    for f in tree {
        if f.dir not in dirs {
            dirs.append(f.dir);
        }
    }

    return <div className="flex flex-col gap-8">
        <header className="flex flex-col gap-3">
            <h1 className="flex items-center gap-3 text-3xl sm:text-4xl font-semibold tracking-tight">
                <HugeiconsIcon icon={CodeIcon} strokeWidth={2} className="size-8 text-primary" />
                Source
            </h1>
            <p className="text-muted-foreground max-w-2xl leading-relaxed">
                The code serving this page, read live from disk on every request —
                nothing staged, nothing hidden. Markdown in, Jac out.
            </p>
        </header>

        <div className="flex flex-col lg:flex-row gap-6 items-start">
            <aside className="w-full lg:w-64 shrink-0 lg:sticky lg:top-20 lg:max-h-[calc(100vh-7rem)] lg:overflow-y-auto rounded-xl border border-border bg-card">
                {if loading_tree {
                    <div className="p-4 flex flex-col gap-3">
                        <Skeleton className="h-4 w-24" />
                        <Skeleton className="h-4 w-40" />
                        <Skeleton className="h-4 w-32" />
                        <Skeleton className="h-4 w-36" />
                    </div>
                } else {
                    <nav className="p-2">
                        {for d in dirs {
                            <div key={d or "(root)"} className="mb-1">
                                <p className="px-3 pt-3 pb-1 text-[11px] font-mono uppercase tracking-wider text-muted-foreground">
                                    {d or "project root"}
                                </p>
                                {for f in tree {
                                    if f.dir == d {
                                        <button
                                            key={f.path}
                                            onClick={lambda { nav("/source?f=" + encodeURIComponent(f.path)); }}
                                            className={
                                                "w-full flex items-center gap-2 px-3 py-1.5 rounded-md text-sm text-left transition-colors cursor-pointer "
                                                + ("bg-accent text-foreground font-medium" if f.path == selected
                                                   else "text-muted-foreground hover:text-foreground hover:bg-accent/50")
                                            }
                                        >
                                            <span
                                                className="size-2 rounded-full shrink-0"
                                                style={{"background": _LANG_DOT.get(f.language, "var(--muted-foreground)")}}
                                            />
                                            <span className="truncate">{f.name}</span>
                                            <span className="ml-auto text-[11px] font-mono text-muted-foreground/70">
                                                {str(f.lines)}
                                            </span>
                                        </button>
                                    }
                                }}
                            </div>
                        }}
                    </nav>
                }}
            </aside>

            <section className="min-w-0 flex-1 rounded-xl border border-border overflow-hidden bg-card">
                <div className="flex flex-wrap items-center gap-3 px-4 py-2.5 border-b border-border bg-muted/40">
                    <p className="font-mono text-sm min-w-0 truncate">
                        {if "/" in selected {
                            <span className="text-muted-foreground">{selected[:selected.rfind("/") + 1]}</span>
                        }}
                        <span className="font-semibold">{selected.split("/")[-1]}</span>
                    </p>
                    <div className="ml-auto flex items-center gap-2">
                        {if view is not None {
                            <span className="text-xs font-mono text-muted-foreground">
                                {str(view.lines) + " lines · " + _fmt_size(view.size_bytes)}
                            </span>
                            <Badge variant="outline" className="font-mono">{view.language}</Badge>
                            <Button variant="ghost" size="icon" onClick={handle_copy} aria-label="Copy file contents">
                                <HugeiconsIcon
                                    icon={CopyCheckIcon if copied else Copy01Icon}
                                    strokeWidth={2}
                                    className={"size-4 " + ("text-primary" if copied else "")}
                                />
                            </Button>
                        }}
                    </div>
                </div>
                {if loading_file {
                    <div className="p-5 flex flex-col gap-2.5">
                        <Skeleton className="h-3.5 w-2/3" />
                        <Skeleton className="h-3.5 w-1/2" />
                        <Skeleton className="h-3.5 w-3/4" />
                        <Skeleton className="h-3.5 w-2/5" />
                        <Skeleton className="h-3.5 w-3/5" />
                    </div>
                } elif view is None {
                    <div className="p-10 text-center text-muted-foreground">
                        File not found — pick one from the tree.
                    </div>
                } else {
                    <div className="source-view">{unsafe_html(view.html)}</div>
                }}
            </section>
        </div>
    </div>;
}

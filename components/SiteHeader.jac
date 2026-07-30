import from "@jac/runtime" { Link, useLocation }
import from .ui.button { buttonVariants }
import from .ThemeToggle { ThemeToggle }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { GithubIcon }

def:pub SiteHeader -> JsxElement {
    location = useLocation();
    path = location.pathname;

    base_link = "text-sm transition-colors hover:text-foreground ";
    posts_cls = base_link
    + (
        "text-foreground font-medium"
            if path == "/" or path.startswith("/posts")
            else "text-muted-foreground"
    );
    about_cls = base_link
    + ("text-foreground font-medium" if path == "/about" else "text-muted-foreground");
    source_cls = base_link
    + (
        "text-foreground font-medium"
            if path.startswith("/source")
            else "text-muted-foreground"
    );

    <header
        className="sticky top-0 z-40 border-b border-border/60 bg-background/80 backdrop-blur supports-[backdrop-filter]:bg-background/60"
    >
        <div
            className="max-w-3xl mx-auto px-4 sm:px-6 h-14 flex items-center justify-between"
        >
            <div className="flex items-center gap-8">
                <Link
                    to="/"
                    className="flex items-center gap-2 font-semibold tracking-tight"
                >
                    <img
                        src="/static/assets/ninjaavatar.png"
                        alt=""
                        className="size-6 rounded-full ring-1 ring-border"
                    />
                    marsninja
                </Link>
                <nav className="flex items-center gap-5">
                    <Link to="/" className={posts_cls}>Posts</Link>
                    <Link to="/about" className={about_cls}>About</Link>
                    <Link to="/source" className={source_cls}>Source</Link>
                </nav>
            </div>
            <div className="flex items-center gap-1">
                <a
                    href="https://github.com/marsninja"
                    target="_blank"
                    rel="noreferrer"
                    aria-label="GitHub"
                    className={buttonVariants().call(
                        None, {"variant": "ghost", "size": "icon"}
                    )}
                >
                    <HugeiconsIcon
                        icon={GithubIcon}
                        strokeWidth={2}
                        className="size-5"
                    />
                </a>
                <ThemeToggle/>
            </div>
        </div>
    </header>
}

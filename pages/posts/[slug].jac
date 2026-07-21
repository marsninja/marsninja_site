sv import from ...services.blog { get_post, Post }
import from "@jac/runtime" { Link, useParams }
import from ...components.ui.badge { Badge }
import from ...components.ui.separator { Separator }
import from ...components.ui.skeleton { Skeleton }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowLeft01Icon }

def:pub page() -> JsxElement {
    has post: Post | None = None;
    has loading: bool = True;

    params = useParams();
    slug = params["slug"];

    async can with [slug] entry {
        loading = True;
        if slug {
            post = await get_post(slug as str);
        }
        loading = False;
    }

    if loading {
        return <div className="py-12 flex flex-col gap-4">
            <Skeleton className="h-4 w-24" />
            <Skeleton className="h-10 w-3/4" />
            <Skeleton className="h-4 w-48" />
            <Skeleton className="h-40 w-full mt-6" />
        </div>;
    }

    if post is None {
        return <div className="py-24 text-center">
            <p className="text-sm font-mono text-muted-foreground">404</p>
            <h1 className="mt-2 text-3xl font-semibold">Post not found</h1>
            <p className="mt-3 text-muted-foreground">That post doesn't exist — it may have been renamed or removed.</p>
            <Link to="/" className="mt-6 inline-block text-primary hover:underline">← All posts</Link>
        </div>;
    }

    p = post;
    return <article className="py-12">
        <Link to="/" className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors">
            <HugeiconsIcon icon={ArrowLeft01Icon} strokeWidth={2} className="size-4" />
            All posts
        </Link>
        <h1 className="mt-6 text-3xl sm:text-4xl font-semibold tracking-tight leading-tight">
            {p.meta.title}
        </h1>
        <div className="mt-4 flex flex-wrap items-center gap-2 text-sm text-muted-foreground font-mono">
            <span>{p.meta.display_date}</span>
            <span>·</span>
            <span>{str(p.meta.reading_minutes) + " min read"}</span>
        </div>
        {if len(p.meta.tags) > 0 {
            <div className="mt-4 flex flex-wrap gap-1.5">
                {for t in p.meta.tags {
                    <Link key={t} to={"/?tag=" + t}>
                        <Badge variant="secondary" className="font-normal transition-colors hover:bg-primary/15">{t}</Badge>
                    </Link>
                }}
            </div>
        }}
        <Separator className="my-8" />
        <div className="markdown-body">{unsafe_html(p.html)}</div>
    </article>;
}

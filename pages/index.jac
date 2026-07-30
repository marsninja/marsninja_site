sv import from ..services.blog { list_posts, PostMeta }
import from "@jac/runtime" { useLocation, useNavigate }
import from ..components.PostCard { PostCard }
import from ..components.ui.input { Input }
import from ..components.ui.badge { Badge }
import from ..components.ui.skeleton { Skeleton }
import from ..components.ui.empty { Empty, EmptyHeader, EmptyTitle, EmptyDescription }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Search01Icon }

def:pub page -> JsxPage {
    has posts: list[PostMeta] = [],
        loading: bool = True,
        query: str = "";

    location = useLocation();
    nav = useNavigate();
    searchParams = new(URLSearchParams, location.search);  # jac:ignore[E1053]
    activeTag = str(searchParams.get("tag") or "");  # jac:ignore[E1031]

    async can with entry {
        posts = await list_posts();
        loading = False;
    }

    def handle_search(e: ChangeEvent) {
        query = e.target.value;
    }

    q = query.strip().lower();
    filtered: list[PostMeta] = [];
    for p in posts {
        tag_ok = (not activeTag) or (activeTag in p.tags);
        text_ok = (not q) or (q in p.title.lower()) or (q in p.summary.lower());
        if tag_ok and text_ok {
            filtered.append(p);
        }
    }

    all_tags: list[str] = [];
    for p in posts {
        for t in p.tags {
            if t not in all_tags {
                all_tags.append(t);
            }
        }
    }

    <div className="flex flex-col">
        <section className="pt-14 pb-10">
            <h1
                className="flex items-center gap-4 text-4xl sm:text-5xl font-semibold tracking-tight"
            >
                <img
                    src="/static/assets/ninjaavatar.png"
                    alt="marsninja avatar"
                    className="size-12 sm:size-14 rounded-full ring-2 ring-primary/40 shadow-md"
                />
                <span
                    className="bg-gradient-to-r from-primary to-foreground bg-clip-text text-transparent"
                >
                    marsninja
                </span>
            </h1>
            <p className="mt-4 text-lg text-muted-foreground max-w-xl leading-relaxed">
                Notes on programming languages, AI-native software, and the systems underneath — written in markdown, served by Jac.
            </p>
        </section>
        <section className="flex flex-col gap-4 pb-8">
            <div className="relative">
                <HugeiconsIcon
                    icon={Search01Icon}
                    strokeWidth={2}
                    className="size-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none"
                />
                <Input
                    value={query}
                    onChange={handle_search}
                    placeholder="Search posts…"
                    className="pl-9"
                />
            </div>
            {if len(all_tags) > 0 {
                <div className="flex flex-wrap items-center gap-1.5">
                    {for t in all_tags {
                        <button
                            key={t}
                            onClick={lambda { nav("/")
                                if t == activeTag
                                else nav("/?tag=" + t); }}
                            className="cursor-pointer"
                        >
                            <Badge
                                variant={"default" if t == activeTag else "outline"}
                                className="font-normal transition-colors hover:border-primary/60"
                            >
                                {t}
                            </Badge>
                        </button>
                    }}
                    {if activeTag {
                        <button
                            onClick={lambda { nav("/"); }}
                            className="text-xs text-muted-foreground hover:text-foreground cursor-pointer ml-1"
                        >
                            clear ✕
                        </button>
                    }}
                </div>
            }}
        </section>
        <section className="flex flex-col gap-4">
            {if loading {
                for i in range(3) {
                    <div
                        key={str(i)}
                        className="rounded-xl border border-border p-6 flex flex-col gap-3"
                    >
                        <Skeleton className="h-3 w-40"/>
                        <Skeleton className="h-6 w-3/4"/>
                        <Skeleton className="h-4 w-full"/>
                    </div>
                }
            } elif len(filtered) == 0 {
                <Empty>
                    <EmptyHeader>
                        <EmptyTitle>No posts found</EmptyTitle>
                        <EmptyDescription>
                            Nothing matches that filter. Try clearing the search or tag.
                        </EmptyDescription>
                    </EmptyHeader>
                </Empty>
            } else {
                for p in filtered {
                    <PostCard key={p.slug} meta={p}/>
                }
            }  }
        </section>
    </div>
}

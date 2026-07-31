import from ..services.blog { get_page, Post }
import from ..components.MarkdownContent { MarkdownContent }
import from ..components.ui.skeleton { Skeleton }
import from ..components.ui.separator { Separator }

def:pub page -> JsxPage {
    has doc: Post | None = None,
        loading: bool = True;

    async can with entry {
        doc = await get_page("about");
        loading = False;
    }

    if loading {
        return
            <div className="py-12 flex flex-col gap-4">
                <Skeleton className="h-10 w-48"/>
                <Skeleton className="h-40 w-full mt-6"/>
            </div>;
    }

    if doc is None {
        return
            <div className="py-24 text-center text-muted-foreground">
                About page is missing — add{" "}
                <code>content/about.md</code>
                .
            </div>;
    }

    d = doc;
    <article className="py-12">
        <h1 className="text-3xl sm:text-4xl font-semibold tracking-tight">
            {d.meta.title}
        </h1>
        <Separator className="my-8"/>
        <MarkdownContent html={d.html}/>
    </article>
}

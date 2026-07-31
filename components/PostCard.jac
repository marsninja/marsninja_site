import from ..services.blog { PostMeta }
import from "@jac/runtime" { Link }
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.badge { Badge }

def:pub PostCard(meta: PostMeta) -> JsxElement {
    <Link to={"/posts/" + meta.slug} className="block group">
        <Card
            className="transition-all duration-200 hover:border-primary/50 hover:shadow-md hover:-translate-y-0.5"
        >
            <CardHeader>
                <div
                    className="flex items-center gap-2 text-xs text-muted-foreground font-mono"
                >
                    <span>{meta.display_date}</span>
                    <span>·</span>
                    <span>{str(meta.reading_minutes) + " min read"}</span>
                </div>
                <CardTitle
                    className="text-xl leading-snug group-hover:text-primary transition-colors"
                >
                    {meta.title}
                </CardTitle>
                <CardDescription className="leading-relaxed">
                    {meta.summary}
                </CardDescription>
            </CardHeader>
            {if len(meta.tags) > 0 {
                <CardContent className="flex flex-wrap gap-1.5">
                    {for t in meta.tags {
                        <Badge key={t} variant="secondary" className="font-normal">
                            {t}
                        </Badge>
                    }}
                </CardContent>
            }}
        </Card>
    </Link>
}

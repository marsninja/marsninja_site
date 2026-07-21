---
title: Building This Blog in Jac
date: 2026-07-18
tags: jac, web, meta
summary: The architecture of this site — markdown files in, a Jac fullstack app out, with server-side rendering and a shadcn UI. Total backend: one file.
---

This site is a working example of a full-stack Jac app. The entire content
pipeline is: a directory of markdown files, one server module, and a handful of
client components. Here's how it fits together.

## The shape of the thing

```
marsninja_site/
├── content/
│   ├── posts/*.md        # the blog — frontmatter + markdown
│   └── about.md
├── services/blog.jac     # the whole backend
├── pages/                # file-based routes
│   ├── index.jac         # /
│   ├── posts/[slug].jac  # /posts/:slug
│   └── about.jac         # /about
└── components/           # shadcn-composed UI
```

There is no database. The filesystem *is* the database — `git log` is the
audit trail and `git push` is the publish button.

## The backend is one module

The server reads a post, splits the frontmatter, and renders markdown to HTML
with Pygments highlighting — all in ordinary Jac that leans on Python's
ecosystem directly:

```jac
import markdown;

def:pub get_post(slug: str) -> Post | None {
    path = os.path.join("content", "posts", slug + ".md");
    if not os.path.isfile(path) { return None; }
    return _load_doc(path, slug);
}
```

`def:pub` makes it an endpoint. The client calls it like a local function —
no fetch, no routes, no serializers:

```jac
async can with entry {
    post = await get_post(slug);
    loading = False;
}
```

The return type is the wire format. `Post` is a typed object on both sides of
the network, and `jac check` will flag the client if the server's signature
drifts. That's the whole API layer.

## Rendering markdown on the server

Client-side markdown rendering means shipping a parser to every visitor.
Instead, the server renders once per request with Python's `markdown` package:

| Concern | Where it happens | Cost to the browser |
|---|---|---|
| Markdown → HTML | server (Python `markdown`) | zero |
| Syntax highlighting | server (Pygments, CSS classes) | one small CSS file |
| Typography | plain CSS on semantic tokens | zero JS |

The client receives finished HTML and drops it into the page with Jac's
`unsafe_html()` builtin — the `unsafe_` prefix is deliberate friction, and it's
fine here because I wrote every byte of the content.

## The UI is shadcn, in Jac

The frontend composes jac-shadcn primitives — `Card`, `Badge`, `Input`,
`Skeleton` — with Tailwind semantic tokens, so light/dark theming is a CSS
variable swap rather than a component rewrite:

```jac
def:pub PostCard(meta: PostMeta) -> JsxElement {
    return <Card className="transition-colors hover:border-primary/40">
        <CardHeader>
            <CardTitle>{meta.title}</CardTitle>
            <CardDescription>{meta.summary}</CardDescription>
        </CardHeader>
    </Card>;
}
```

## What I'd tell you to steal

1. **Files over databases** for anything a human edits.
2. **Render markdown where the CPU is cheap** — once, on the server.
3. **Types across the wire** beat OpenAPI codegen you'll never run.

The full source is on [GitHub](https://github.com/marsninja/marsninja_site).

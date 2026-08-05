"""Server-rendered markdown, upgraded client-side.

Drops the blog service's HTML into the page, then draws any
`<pre class="mermaid">` placeholders as SVG with colors matched to the
site's blue shadcn theme. Diagrams are redrawn whenever the theme flips
(via lib/theme.jac); the original diagram source is kept in a data
attribute so a redraw never depends on the previous render.
"""
import from "react" { useRef }
import from "mermaid" { default as mermaid }
import from ..lib.theme { on_theme_change }

glob FONT_STACK: str = "'Geist Variable', ui-sans-serif, system-ui, sans-serif",
     _seq: dict[str, int] = {"n": 0};

def _theme_vars(dark: bool) -> dict[str, any] {
    if dark {
        return {
            "darkMode": True,
            "fontFamily": FONT_STACK,
            "primaryColor": "#172554",
            "primaryTextColor": "#dbeafe",
            "primaryBorderColor": "#3b82f6",
            "lineColor": "#64748b",
            "secondaryColor": "#1e293b",
            "tertiaryColor": "#0f172a",
            "background": "#0a0a0a",
            "mainBkg": "#172554",
            "nodeBorder": "#3b82f6",
            "clusterBkg": "#1e293b",
            "titleColor": "#e2e8f0",
            "edgeLabelBackground": "#1e293b",
            "textColor": "#cbd5e1",
            "cScale0": "#1e3a8a",
            "cScaleLabel0": "#dbeafe",
            "cScale1": "#1d4ed8",
            "cScaleLabel1": "#dbeafe",
            "cScale2": "#2563eb",
            "cScaleLabel2": "#ffffff",
            "cScale3": "#3b82f6",
            "cScaleLabel3": "#ffffff"
        };
    }
    return {
        "darkMode": False,
        "fontFamily": FONT_STACK,
        "primaryColor": "#dbeafe",
        "primaryTextColor": "#1e3a8a",
        "primaryBorderColor": "#2563eb",
        "lineColor": "#94a3b8",
        "secondaryColor": "#f1f5f9",
        "tertiaryColor": "#f8fafc",
        "background": "#ffffff",
        "mainBkg": "#dbeafe",
        "nodeBorder": "#2563eb",
        "clusterBkg": "#f1f5f9",
        "titleColor": "#0f172a",
        "edgeLabelBackground": "#f1f5f9",
        "textColor": "#334155",
        "cScale0": "#1d4ed8",
        "cScaleLabel0": "#ffffff",
        "cScale1": "#3b82f6",
        "cScaleLabel1": "#ffffff",
        "cScale2": "#60a5fa",
        "cScaleLabel2": "#0f172a",
        "cScale3": "#93c5fd",
        "cScaleLabel3": "#0f172a"
    };
}

async def _draw_all(container: any) {
    if (not container) or (not container.isConnected) {
        return;
    }
    blocks = container.querySelectorAll("pre.mermaid");
    if len(blocks) == 0 {
        return;
    }
    dark = bool(document.documentElement.classList.contains("dark"));
    mermaid.initialize(
        {  # jac:ignore[E1032]
            "startOnLoad": False,
            "theme": "base",
            "themeVariables": _theme_vars(dark),
            "fontFamily": FONT_STACK,
            "flowchart": {"curve": "basis"}
        }
    );
    for i in range(len(blocks)) {
        block = blocks[i];
        src = block.getAttribute("data-mmd-src");
        if not src {
            src = block.textContent;
            block.setAttribute("data-mmd-src", src);
        }
        _seq["n"] += 1;
        # Id must be unique across module copies, not just within this one:
        # the client build duplicates this module (and mermaid) into the main
        # bundle AND the route chunk, and both copies draw the same blocks. A
        # bare counter collides ("mmd1" vs "mmd1") and one copy's
        # removeExisting/removeTemp cleanup deletes the other's in-flight DOM.
        rid = "mmd" + str(_seq["n"]) + "r"
        + str(window.crypto.randomUUID()).split("-")[0];  # jac:ignore[E1030]
        try {
            rendered: any = await mermaid.render(rid, src);  # jac:ignore[E1032]
            block.innerHTML = rendered.svg;
            block.setAttribute("data-rendered", "ok");
        } except Exception as e {
            console.error("mermaid render failed:", e);
            block.textContent = src;
            block.setAttribute("data-rendered", "error");
        }
    }
}

def:pub MarkdownContent(html: str) -> JsxElement {
    containerRef: any = useRef(None);
    hookedRef: any = useRef(None);

    def redraw_on_theme(dark: bool) -> bool {
        el = containerRef.current;
        if (not el) or (not el.isConnected) {
            return False;
        }
        _draw_all(el);
        return True;
    }

    async can with [html] entry {
        if not hookedRef.current {
            hookedRef.current = True;
            on_theme_change(redraw_on_theme);
        }
        await _draw_all(containerRef.current);
    }

    <div ref={containerRef} className="markdown-body">{unsafe_html(html)}</div>
}

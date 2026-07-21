import from "@jac/runtime" { Outlet }
import from ..components.SiteHeader { SiteHeader }

def:pub layout() -> JsxElement {
    return <div className="min-h-screen bg-background text-foreground flex flex-col">
        <SiteHeader />
        <main className="flex-1 w-full max-w-3xl mx-auto px-4 sm:px-6">
            <Outlet />
        </main>
        <footer className="border-t border-border/60 mt-16">
            <div className="max-w-3xl mx-auto px-4 sm:px-6 py-8 flex items-center justify-between text-sm text-muted-foreground">
                <span>© 2026 marsninja</span>
                <span className="font-mono text-xs">markdown in · Jac out</span>
            </div>
        </footer>
    </div>;
}

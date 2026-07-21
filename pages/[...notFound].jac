import from "@jac/runtime" { Link }

def:pub page() -> JsxElement {
    return <div className="py-24 text-center">
        <p className="text-sm font-mono text-muted-foreground">404</p>
        <h1 className="mt-2 text-3xl font-semibold">Page not found</h1>
        <p className="mt-3 text-muted-foreground">The page you're looking for doesn't exist or has moved.</p>
        <Link to="/" className="mt-6 inline-block text-primary hover:underline">← Back home</Link>
    </div>;
}

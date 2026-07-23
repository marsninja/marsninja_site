"""Client-side theme change hub.

ThemeToggle calls `notify_theme_change` after flipping the `dark` class on
the document root. Components that render theme-dependent output (mermaid
diagrams) register a callback with `on_theme_change`. A callback returns
False when its DOM is gone, and the hub drops it — no explicit unsubscribe
needed from React effects.

Plain markerless module: these are accessless defs (shared logic), so the
compiler places them with their client callers — a `def:pub` here would
make them server endpoints instead.
"""

glob _listeners: list = [];

def on_theme_change(cb: any) {
    _listeners.append(cb);
}

def notify_theme_change(dark: bool) {
    stale: list = [];
    for cb in _listeners {
        if not cb(dark) {
            stale.append(cb);
        }
    }
    for cb in stale {
        _listeners.remove(cb);
    }
}

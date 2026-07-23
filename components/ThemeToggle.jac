import from .ui.button { Button }
import from ..lib.theme { notify_theme_change }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Moon02Icon, Sun01Icon }

def:pub ThemeToggle() -> JsxElement {
    has dark: bool = False;

    def apply_theme(d: bool) {
        if d {
            document.documentElement.classList.add("dark");
        } else {
            document.documentElement.classList.remove("dark");
        }
        notify_theme_change(d);
    }

    can with entry {
        stored = localStorage.getItem("theme");
        prefers = bool(window.matchMedia("(prefers-color-scheme: dark)").matches);  # jac:ignore[E1030]
        is_dark = (stored == "dark") if stored else prefers;
        apply_theme(is_dark);
        dark = is_dark;
    }

    def handle_toggle(e: MouseEvent) {
        next = not dark;
        dark = next;
        apply_theme(next);
        localStorage.setItem("theme", "dark" if next else "light");
    }

    return <Button variant="ghost" size="icon" onClick={handle_toggle} aria-label="Toggle theme">
        <HugeiconsIcon icon={Sun01Icon if dark else Moon02Icon} strokeWidth={2} className="size-5" />
    </Button>;
}

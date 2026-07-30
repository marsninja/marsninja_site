import from ..components.SourceBrowser { SourceBrowser }

def:pub page -> JsxPage {
    <div className="py-12">
        {#* Break out of the layout's max-w-3xl column — a source browser wants room. *#}
        <div className="relative left-1/2 -translate-x-1/2 w-[min(76rem,100vw-2rem)]">
            <SourceBrowser/>
        </div>
    </div>
}

import from services.blog { list_posts, get_post, get_page, Post, PostMeta }
import from services.source { source_tree, source_file, SourceFile, SourceView }

import ".styles.global.css";
import ".styles.markdown.css";
import ".styles.source.css";
import ".styles.overrides.css";

def:pub app(children: any) -> JsxElement {
    <>{children}</>
}

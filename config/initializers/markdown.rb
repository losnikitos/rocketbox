# .md.erb views render Markdown, not HTML, so ERB output isn't HTML-escaped.
ActionView::Template::Handlers::ERB.escape_ignore_list += [ "text/markdown" ]

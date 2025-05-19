# qutebrowser configuration file
# Documentation: https://qutebrowser.org/doc/help/settings.html

# Import the config object
config = config  # type: ignore
c = c  # type: ignore

# Set Kagi as the default search engine
c.url.searchengines = {
    "DEFAULT": "https://kagi.com/search?q={}",
    "g": "https://google.com/search?q={}",
    "ddg": "https://duckduckgo.com/?q={}",
    "yt": "https://youtube.com/results?search_query={}",
    "gh": "https://github.com/search?q={}",
}

# Start pages
c.url.start_pages = ["https://kagi.com"]

# Open new tabs with the default search engine
c.url.default_page = "https://kagi.com"

# Additional useful settings (commented out by default)
# c.tabs.position = 'top'
# c.tabs.show = 'always'
# c.tabs.padding = {'bottom': 5, 'left': 5, 'right': 5, 'top': 5}
# c.tabs.title.format = '{index}: {title}'
# c.content.default_encoding = 'utf-8'
# c.content.javascript.enabled = True
# c.content.autoplay = False

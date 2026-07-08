module ModelPoint

using Genie, Genie.Router, Genie.Renderer.Html
using HTTP: escapehtml
using CSV, DataFrames

# ============================================================
# Constants
# ============================================================

const PROJECT_DIR      = dirname(dirname(dirname(@__FILE__)))
const MP_DIR           = joinpath(PROJECT_DIR, "MP")
const MAX_DISPLAY_ROWS = 1000

# ============================================================
# Helpers
# ============================================================

# Escape HTML special characters to prevent XSS
he(s) = escapehtml(string(s))

# List all model point csv files in MP directory
function list_mp_files()::Vector{String}
    isdir(MP_DIR) || return String[]
    sort([f for f in readdir(MP_DIR) if endswith(lowercase(f), ".csv")])
end

# Total data rows in a csv file (excluding header), without loading it fully
function count_data_rows(path::String)::Int
    n = countlines(path)
    max(n - 1, 0)
end

# Load first MAX_DISPLAY_ROWS of a model point file
function load_mp_preview(path::String)::DataFrame
    CSV.read(path, DataFrame; limit=MAX_DISPLAY_ROWS, missingstring="")
end

# ============================================================
# HTML Builders — right panel and full page
# ============================================================

function mp_panel(sel_file::String)::String
    if isempty(sel_file)
        return "<div class='mp-placeholder'>Select a model point file from the left to view its contents. Files are viewed up to the first $(MAX_DISPLAY_ROWS) rows.</div>"
    end

    # Validate against actual file list (prevents path traversal)
    sel_file in list_mp_files() ||
        return "<div class='mp-placeholder'>File not found: $(he(sel_file))</div>"

    path = joinpath(MP_DIR, sel_file)

    df, total_rows, err = try
        (load_mp_preview(path), count_data_rows(path), "")
    catch e
        (DataFrame(), 0, sprint(showerror, e))
    end

    if !isempty(err)
        return """<div class='mp-panel-header'>
  <h2 class='mp-panel-title'>$(he(sel_file))</h2>
</div>
<div class='tlm-notice tlm-notice--error'>Could not read file: $(he(err))</div>"""
    end

    shown_rows = nrow(df)
    truncated  = total_rows > shown_rows

    meta = "$(total_rows) row$(total_rows == 1 ? "" : "s") &times; $(ncol(df)) columns &middot; read-only"

    truncated_html = truncated ?
        "<div class='mp-truncated'>Showing first $(shown_rows) of $(total_rows) rows &mdash; the full file is in MP/$(he(sel_file)).</div>" : ""

    header_cells = join(["<th class='mp-th'>$(he(c))</th>" for c in names(df)], "")

    body_rows = join([begin
        cells = join([begin
            v = df[r, c]
            "<td class='mp-td'>$(ismissing(v) ? "" : he(v))</td>"
        end for c in 1:ncol(df)], "")
        "<tr class='mp-tr'><td class='mp-td mp-td--idx'>$(r)</td>$(cells)</tr>"
    end for r in 1:shown_rows], "\n")

    """<div class='mp-panel-header'>
  <h2 class='mp-panel-title'>$(he(sel_file))</h2>
  <div class='mp-meta'>$(meta)</div>
</div>
$(truncated_html)
<div class='mp-table-wrap'>
  <table class='mp-table'>
    <thead><tr><th class='mp-th mp-th--idx'>#</th>$(header_cells)</tr></thead>
    <tbody>$(body_rows)</tbody>
  </table>
</div>"""
end

function render_page(; sel_file::String = "")

    mp_files = list_mp_files()

    mp_items = isempty(mp_files) ?
        "<li class='mp-nav-item'><span class='mp-nav-empty'>No files in MP/</span></li>" :
        join([begin
            active = f == sel_file ? " mp-nav-item--active" : ""
            "<li class='mp-nav-item$(active)'>" *
            "<a href='/model-point?file=$(he(f))' class='mp-nav-link'>$(he(f))</a></li>"
        end for f in mp_files], "\n")

    panel = mp_panel(sel_file)

    page = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>TradLifeModel - Model Point</title>
  <link rel="stylesheet" href="/css/base.css">
  <link rel="stylesheet" href="/css/model_point.css">
</head>
<body>

<header class="tlm-header">
  <a href="/" class="tlm-logo" style="text-decoration:none;color:inherit;">TradLifeModel</a>
  <div class="tlm-badge">MODEL POINT</div>
</header>

<div class="tlm-app">

  <nav class="tlm-sidenav">
    <div class="tlm-sidenav-label">Navigation</div>
    <a href="/table-setup">Table Setup</a>
    <a href="/product-setup">Product Setup</a>
    <a href="/model-point" class="active">Model Point</a>
    <a href="/run-settings">Run Settings</a>
    <a href="/general-settings">General Settings</a>
    <a href="/run-monitor">Run Monitor</a>
    <a href="/run-result">Run Result</a>
    <hr style="border:none;border-top:1px solid var(--tlm-border);margin:0.5rem 0">
    <div class="mp-nav-group">
      <div class="mp-nav-group-label">Model Point Files</div>
      <ul class="mp-nav-list">$(mp_items)</ul>
    </div>
  </nav>

  <main class="tlm-page-main">
    $(panel)
  </main>

</div>

</body>
</html>"""

    return html(page)
end

# ============================================================
# Routes
# ============================================================

function register_routes()

    route("/model-point", method=GET) do
        sel_file = string(get(Genie.Router.params(), :file, ""))
        render_page(; sel_file)
    end

end

end # module

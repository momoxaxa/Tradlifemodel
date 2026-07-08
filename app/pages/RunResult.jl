module RunResult

using Genie, Genie.Router, Genie.Renderer.Html
using HTTP: escapehtml
using CSV, DataFrames
using Dates

# ============================================================
# Constants
# ============================================================

const PROJECT_DIR      = dirname(dirname(dirname(@__FILE__)))
const OUTPUT_DIR       = joinpath(PROJECT_DIR, "Output")
const MAX_DISPLAY_ROWS = 1000

# ============================================================
# Helpers
# ============================================================

# Escape HTML special characters to prevent XSS
he(s) = escapehtml(string(s))

# List all run folders in Output directory
function list_runs()::Vector{String}
    isdir(OUTPUT_DIR) || return String[]
    sort([d for d in readdir(OUTPUT_DIR) if isdir(joinpath(OUTPUT_DIR, d))])
end

# List all result csv files for a given run
function list_run_files(run::String)::Vector{String}
    dir = joinpath(OUTPUT_DIR, run)
    isdir(dir) || return String[]
    sort([f for f in readdir(dir) if endswith(lowercase(f), ".csv")])
end

# Total data rows in a csv file (excluding header), without loading it fully
function count_data_rows(path::String)::Int
    n = countlines(path)
    max(n - 1, 0)
end

# Load first MAX_DISPLAY_ROWS of a result file
function load_result_preview(path::String)::DataFrame
    CSV.read(path, DataFrame; limit=MAX_DISPLAY_ROWS, missingstring="")
end

# ============================================================
# HTML Builders — right panel and full page
# ============================================================

# File list for a run (no file selected yet)
function file_list_html(run::String)::String
    files = list_run_files(run)
    isempty(files) &&
        return "<div class='rr-placeholder'>No result files found in this run folder.</div>"

    rows = join([begin
        path = joinpath(OUTPUT_DIR, run, f)
        modified = Dates.format(Dates.unix2datetime(mtime(path)), "yyyy-mm-dd HH:MM")
        """<tr class='rr-trow'>
          <td class='rr-tcell rr-tcell--name'>
            <a href='/run-result?run=$(he(run))&file=$(he(f))' class='rr-tlink'>$(he(f))</a>
          </td>
          <td class='rr-tcell'>$(modified) UTC</td>
        </tr>"""
    end for f in files], "\n")

    """<table class='rr-table'>
  <thead><tr>
    <th class='rr-th'>File</th>
    <th class='rr-th'>Modified</th>
  </tr></thead>
  <tbody>$(rows)</tbody>
</table>"""
end

# Data table view for a selected file
function file_view_html(run::String, file::String)::String
    path = joinpath(OUTPUT_DIR, run, file)

    df, total_rows, err = try
        (load_result_preview(path), count_data_rows(path), "")
    catch e
        (DataFrame(), 0, sprint(showerror, e))
    end

    !isempty(err) &&
        return "<div class='tlm-notice tlm-notice--error'>Could not read file: $(he(err))</div>"

    shown_rows = nrow(df)
    truncated  = total_rows > shown_rows

    meta = "$(total_rows) row$(total_rows == 1 ? "" : "s") &times; $(ncol(df)) columns &middot; read-only"

    truncated_html = truncated ?
        "<div class='rr-truncated'>Showing first $(shown_rows) of $(total_rows) rows &mdash; the full file is in Output/$(he(run))/$(he(file)).</div>" : ""

    header_cells = join(["<th class='rr-dth'>$(he(c))</th>" for c in names(df)], "")

    body_rows = join([begin
        cells = join([begin
            v = df[r, c]
            "<td class='rr-dtd'>$(ismissing(v) ? "" : he(v))</td>"
        end for c in 1:ncol(df)], "")
        "<tr class='rr-dtr'><td class='rr-dtd rr-dtd--idx'>$(r)</td>$(cells)</tr>"
    end for r in 1:shown_rows], "\n")

    """<div class='rr-backlink'>
  <a href='/run-result?run=$(he(run))'>&larr; Back to file list</a>
</div>
<div class='rr-meta'>$(meta)</div>
$(truncated_html)
<div class='rr-table-wrap'>
  <table class='rr-dtable'>
    <thead><tr><th class='rr-dth rr-dth--idx'>#</th>$(header_cells)</tr></thead>
    <tbody>$(body_rows)</tbody>
  </table>
</div>"""
end

function rr_panel(sel_run::String, sel_file::String)::String
    isempty(sel_run) &&
        return "<div class='rr-placeholder'>Select a run from the left to view its result files. Files are viewed up to the first $(MAX_DISPLAY_ROWS) rows.</div>"

    # Validate against actual folder/file listings (prevents path traversal)
    sel_run in list_runs() ||
        return "<div class='rr-placeholder'>Run not found: $(he(sel_run))</div>"

    title = isempty(sel_file) ? sel_run : "$(sel_run) &mdash; $(he(sel_file))"

    content = if isempty(sel_file)
        file_list_html(sel_run)
    elseif sel_file in list_run_files(sel_run)
        file_view_html(sel_run, sel_file)
    else
        "<div class='rr-placeholder'>File not found: $(he(sel_file))</div>"
    end

    """<div class='rr-panel-header'>
  <h2 class='rr-panel-title'>$(title)</h2>
</div>
$(content)"""
end

function render_page(; sel_run::String = "", sel_file::String = "")

    runs = list_runs()

    run_items = isempty(runs) ?
        "<li class='rr-nav-item'><span class='rr-nav-empty'>No runs in Output/</span></li>" :
        join([begin
            active = r == sel_run ? " rr-nav-item--active" : ""
            "<li class='rr-nav-item$(active)'>" *
            "<a href='/run-result?run=$(he(r))' class='rr-nav-link'>$(he(r))</a></li>"
        end for r in runs], "\n")

    panel = rr_panel(sel_run, sel_file)

    page = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>TradLifeModel - Run Result</title>
  <link rel="stylesheet" href="/css/base.css">
  <link rel="stylesheet" href="/css/run_result.css">
</head>
<body>

<header class="tlm-header">
  <a href="/" class="tlm-logo" style="text-decoration:none;color:inherit;">TradLifeModel</a>
  <div class="tlm-badge">RUN RESULT</div>
</header>

<div class="tlm-app">

  <nav class="tlm-sidenav">
    <div class="tlm-sidenav-label">Navigation</div>
    <a href="/table-setup">Table Setup</a>
    <a href="/product-setup">Product Setup</a>
    <a href="/model-point">Model Point</a>
    <a href="/run-settings">Run Settings</a>
    <a href="/general-settings">General Settings</a>
    <a href="/run-monitor">Run Monitor</a>
    <a href="/run-result" class="active">Run Result</a>
    <hr style="border:none;border-top:1px solid var(--tlm-border);margin:0.5rem 0">
    <div class="rr-nav-group">
      <div class="rr-nav-group-label">Runs</div>
      <ul class="rr-nav-list">$(run_items)</ul>
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

    route("/run-result", method=GET) do
        params   = Genie.Router.params()
        sel_run  = string(get(params, :run,  ""))
        sel_file = string(get(params, :file, ""))
        render_page(; sel_run, sel_file)
    end

end

end # module

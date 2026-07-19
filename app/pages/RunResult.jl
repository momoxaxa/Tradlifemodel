module RunResult

using Genie, Genie.Router, Genie.Renderer.Html
using Genie.Requests: postpayload
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

# List all invocation folders in Output, newest first.
# (Timestamped names yyyy-mm-dd_HHMMSS sort lexically = chronologically)
function list_invocations()::Vector{String}
    isdir(OUTPUT_DIR) || return String[]
    sort([d for d in readdir(OUTPUT_DIR) if isdir(joinpath(OUTPUT_DIR, d))], rev=true)
end

# List run folders inside an invocation
function list_runs(inv::String)::Vector{String}
    dir = joinpath(OUTPUT_DIR, inv)
    isdir(dir) || return String[]
    sort([d for d in readdir(dir) if isdir(joinpath(dir, d))])
end

# List all result csv files for a given invocation/run
function list_run_files(inv::String, run::String)::Vector{String}
    dir = joinpath(OUTPUT_DIR, inv, run)
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

# Run log content for an invocation (if present)
function run_log_html(inv::String)::String
    path = joinpath(OUTPUT_DIR, inv, "run_log.txt")
    isfile(path) || return ""
    """<div class='rr-meta'>run_log.txt</div>
<pre class='rr-log'>$(he(read(path, String)))</pre>"""
end

# Overview of one invocation: run log + run folders (or legacy direct files)
function invocation_view_html(inv::String)::String
    runs  = list_runs(inv)
    log   = run_log_html(inv)

    delete_html = """<div class='rr-actions' style='margin-bottom:0.75rem'>
  <form method='POST' action='/run-result' style='display:inline'
        onsubmit="return confirm('Permanently delete $(he(inv)) and all its results? This cannot be undone.');">
    <input type='hidden' name='action' value='delete'>
    <input type='hidden' name='inv' value='$(he(inv))'>
    <button type='submit' class='btn-danger'>Delete this model run</button>
  </form>
</div>"""

    if isempty(runs)
        return delete_html * log * "<div class='rr-placeholder'>No run folders found.</div>"
    end

    rows = join([begin
        """<tr class='rr-trow'>
          <td class='rr-tcell rr-tcell--name'>
            <a href='/run-result?inv=$(he(inv))&run=$(he(r))' class='rr-tlink'>$(he(r))</a>
          </td>
          <td class='rr-tcell'>$(length(list_run_files(inv, r))) file(s)</td>
        </tr>"""
    end for r in runs], "\n")

    delete_html * log * """<table class='rr-table'>
  <thead><tr>
    <th class='rr-th'>Run</th>
    <th class='rr-th'>Results</th>
  </tr></thead>
  <tbody>$(rows)</tbody>
</table>"""
end

# File table for one run folder
function file_table_html(inv::String, run::String, files::Vector{String})::String
    isempty(files) &&
        return "<div class='rr-placeholder'>No result files found in this folder.</div>"

    # mtime is a UNIX timestamp; unix2datetime gives UTC. Add the local offset
    # so the displayed time matches the user's clock.
    local_offset = Dates.now() - Dates.now(UTC)

    rows = join([begin
        path = joinpath(OUTPUT_DIR, inv, run, f)
        modified = Dates.format(Dates.unix2datetime(mtime(path)) + local_offset, "yyyy-mm-dd HH:MM")
        """<tr class='rr-trow'>
          <td class='rr-tcell rr-tcell--name'>
            <a href='/run-result?inv=$(he(inv))&run=$(he(run))&file=$(he(f))' class='rr-tlink'>$(he(f))</a>
          </td>
          <td class='rr-tcell'>$(modified)</td>
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
function file_view_html(inv::String, run::String, file::String)::String
    path = joinpath(OUTPUT_DIR, inv, run, file)

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

    backq = "&run=$(he(run))"
    truncated_html = truncated ?
        "<div class='rr-truncated'>Showing first $(shown_rows) of $(total_rows) rows &mdash; the full file is in Output/$(he(inv))/$(he(run))/$(he(file)).</div>" : ""

    header_cells = join(["<th class='rr-dth'>$(he(c))</th>" for c in names(df)], "")

    body_rows = join([begin
        cells = join([begin
            v = df[r, c]
            "<td class='rr-dtd'>$(ismissing(v) ? "" : he(v))</td>"
        end for c in 1:ncol(df)], "")
        "<tr class='rr-dtr'><td class='rr-dtd rr-dtd--idx'>$(r)</td>$(cells)</tr>"
    end for r in 1:shown_rows], "\n")

    """<div class='rr-backlink'>
  <a href='/run-result?inv=$(he(inv))$(backq)'>&larr; Back to file list</a>
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

function rr_panel(sel_inv::String, sel_run::String, sel_file::String)::String
    isempty(sel_inv) &&
        return "<div class='rr-placeholder'>Select a model run from the left (newest first) to view its results. Files are viewed up to the first $(MAX_DISPLAY_ROWS) rows.</div>"

    # Validate against actual folder/file listings (prevents path traversal)
    sel_inv in list_invocations() ||
        return "<div class='rr-placeholder'>Folder not found: $(he(sel_inv))</div>"

    if !isempty(sel_run) && !(sel_run in list_runs(sel_inv))
        return "<div class='rr-placeholder'>Run not found: $(he(sel_run))</div>"
    end

    # A file can only be reached through a run folder
    if !isempty(sel_file) && isempty(sel_run)
        return "<div class='rr-placeholder'>File not found: $(he(sel_file))</div>"
    end

    title = he(sel_inv) *
            (isempty(sel_run)  ? "" : " &mdash; $(he(sel_run))") *
            (isempty(sel_file) ? "" : " &mdash; $(he(sel_file))")

    content = if isempty(sel_run) && isempty(sel_file)
        invocation_view_html(sel_inv)
    elseif isempty(sel_file)
        file_table_html(sel_inv, sel_run, list_run_files(sel_inv, sel_run))
    else
        sel_file in list_run_files(sel_inv, sel_run) ?
            file_view_html(sel_inv, sel_run, sel_file) :
            "<div class='rr-placeholder'>File not found: $(he(sel_file))</div>"
    end

    """<div class='rr-panel-header'>
  <h2 class='rr-panel-title'>$(title)</h2>
</div>
$(content)"""
end

function render_page(; sel_inv::String = "", sel_run::String = "", sel_file::String = "",
                       notice::String = "", notice_type::String = "success")

    invs = list_invocations()

    notice_html = isempty(notice) ? "" :
        "<div class='tlm-notice tlm-notice--$(notice_type)'>$(he(notice))</div>"

    inv_items = isempty(invs) ?
        "<li class='rr-nav-item'><span class='rr-nav-empty'>No runs in Output/</span></li>" :
        join([begin
            active = i == sel_inv ? " rr-nav-item--active" : ""
            "<li class='rr-nav-item$(active)'>" *
            "<a href='/run-result?inv=$(he(i))' class='rr-nav-link'>$(he(i))</a></li>"
        end for i in invs], "\n")

    panel = rr_panel(sel_inv, sel_run, sel_file)

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
      <div class="rr-nav-group-label">Model runs (newest first)</div>
      <ul class="rr-nav-list">$(inv_items)</ul>
    </div>
  </nav>

  <main class="tlm-page-main">
    $(notice_html)
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
        sel_inv  = string(get(params, :inv,  ""))
        sel_run  = string(get(params, :run,  ""))
        sel_file = string(get(params, :file, ""))
        render_page(; sel_inv, sel_run, sel_file)
    end

    route("/run-result", method=POST) do
        action = string(postpayload(:action, ""))
        inv    = string(postpayload(:inv, ""))

        if action == "delete"
            # Validate against the actual folder listing (prevents path traversal),
            # then delete the whole invocation folder.
            if inv in list_invocations()
                try
                    rm(joinpath(OUTPUT_DIR, inv); recursive=true)
                    return render_page(; notice="Deleted $(inv).")
                catch e
                    return render_page(; sel_inv=inv,
                        notice="Could not delete $(inv): $(sprint(showerror, e))",
                        notice_type="error")
                end
            else
                return render_page(; notice="Folder not found: $(inv)", notice_type="error")
            end
        end

        render_page()
    end

end

end # module

module RunSettings

using Genie, Genie.Router, Genie.Renderer.Html
using HTTP: escapehtml
using JSON3
using Printf

# Paths
const INPUT_PATH    = joinpath(dirname(dirname(dirname(@__FILE__))), "Input")
const SETTINGS_FILE = joinpath(INPUT_PATH, "run_settings.json")
const NUM_RUNS      = 20

# Field definitions - type, prefix (for HTML name), label (for HTML label), key (for key in json file), default value
const FIELD_ROWS = [
    (:check,  "run_indicator",        "Run Indicator",   "Run Indicator",                       "No"),
    (:text,   "run_description",      "Description",     "Run Description",                     ""),
    (:group,  "",                     "Base Projection", "",                                     ""),
    (:number, "bp_mortality",         "Mortality",       "Base Projection - Mortality",         "100.0"),
    (:number, "bp_lapse",             "Lapse",           "Base Projection - Lapse",             "100.0"),
    (:number, "bp_expense",           "Expense",         "Base Projection - Expense",           "100.0"),
    (:number, "bp_discount_rate",     "Discount Rate",   "Base Projection - Discount Rate",     "0.0"),
    (:number, "bp_investment_return", "Inv. Return",     "Base Projection - Investment Return", "0.0"),
    (:group,  "",                     "Valuation",       "",                                     ""),
    (:number, "val_mortality",        "Mortality",       "Valuation - Mortality",                "100.0"),
    (:number, "val_lapse",            "Lapse",           "Valuation - Lapse",                    "100.0"),
    (:number, "val_expense",          "Expense",         "Valuation - Expense",                  "100.0"),
    (:number, "val_discount_rate",    "Discount Rate",   "Valuation - Discount Rate",            "0.0"),
    (:group,  "",                     "Capital Req.",    "",                                     ""),
    (:number, "cr_mortality",         "Mortality",       "Capital Requirement - Mortality",      "100.0"),
    (:number, "cr_lapse",             "Lapse",           "Capital Requirement - Lapse",          "100.0"),
    (:number, "cr_expense",           "Expense",         "Capital Requirement - Expense",        "100.0"),
    (:number, "cr_discount_rate",     "Discount Rate",   "Capital Requirement - Discount Rate",  "0.0"),
]
# Convert to HTML special characters for rendering page
he(s) = escapehtml(string(s))

# Read current settings from JSON to Dict for rendering page
function load_settings()::Vector{Dict}
    JSON3.read(SETTINGS_FILE, Vector{Dict})
end

# Convert POST params to Dict for saving to JSON and re-rendering page after submission
function form_to_settings(params::Dict)::Vector{Dict}
    params = Dict(string(k) => string(v) for (k,v) in params)
    runs = Vector{Dict}()
    for i in 0:(NUM_RUNS-1)
        run = Dict{String,Any}()
        run["Run Number"]    = "Run " * lpad(string(i+1), 2, '0')
        run["Run Indicator"] = haskey(params, "run_indicator_$(i)") ? "Yes" : "No"
        for (type, prefix, _, key, default) in FIELD_ROWS
            type in (:text, :number) || continue
            run[key] = type == :number ?
                parse(Float64, get(params, "$(prefix)_$(i)", default)) / 100.0 :
                strip(get(params, "$(prefix)_$(i)", default))
        end
        push!(runs, run)
    end
    runs
end

# ── Table HTML ─────────────────────────────────────────────────────────────────
function table_html(runs::Vector{Dict})::String
    run_headers = join([
        "<th class='rs-run-th'>Run $(lpad(string(i),2,'0'))</th>"
        for i in 1:NUM_RUNS], "")

    thead = """<thead><tr>
      <th class='rs-corner rs-sticky'></th>
      $(run_headers)
    </tr></thead>"""

    body_rows = String[]
    for (type, prefix, label, key, default) in FIELD_ROWS
        if type == :group
            push!(body_rows, """<tr class='rs-group-row'>
              <th class='rs-label rs-sticky rs-group-label'>$(label)</th>
              <td colspan='$(NUM_RUNS)' class='rs-group-fill'></td>
            </tr>""")

        elseif type == :check
            cells = join([begin
                checked = string(get(runs[i], key, default)) == "Yes" ? " checked" : ""
                "<td class='rs-cell rs-cell--check'><input type='checkbox' class='rs-check' name='$(prefix)_$(i-1)' value='Yes'$(checked)></td>"
            end for i in 1:NUM_RUNS], "")
            push!(body_rows, "<tr><th class='rs-label rs-sticky'>$(label)</th>$(cells)</tr>")

        elseif type == :text
            cells = join([
                "<td class='rs-cell'><textarea class='rs-input rs-input--text' name='$(prefix)_$(i-1)' rows='3'>$(he(get(runs[i], key, default)))</textarea></td>"
                for i in 1:NUM_RUNS], "")
            push!(body_rows, "<tr><th class='rs-label rs-sticky'>$(label)</th>$(cells)</tr>")

        elseif type == :number
            cells = join([begin
                raw_val = Float64(get(runs[i], key, parse(Float64, default)))
                val_str = @sprintf("%.2f", raw_val * 100)
                "<td class='rs-cell rs-cell--num'><input type='number' class='rs-input rs-input--num' name='$(prefix)_$(i-1)' value='$(val_str)' step='0.01'> %</td>"
            end for i in 1:NUM_RUNS], "")
            push!(body_rows, "<tr><th class='rs-label rs-sticky'>$(label)</th>$(cells)</tr>")
        end
    end

    "<table class='rs-grid'>$(thead)<tbody>$(join(body_rows,""))</tbody></table>"
end

# ── Render ─────────────────────────────────────────────────────────────────────
function render_page(runs::Vector{Dict};
                     notice::String="", notice_type::String="success")
    notice_html = isempty(notice) ? "" :
        "<div class='tlm-notice tlm-notice--$(notice_type)'>$(he(notice))</div>"

    html("""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>TradLifeModel — Run Settings</title>
  <link rel="stylesheet" href="/css/base.css">
  <link rel="stylesheet" href="/css/run_settings.css">
</head>
<body>
<header class="tlm-header">
  <div class="tlm-logo">TradLifeModel</div>
  <div class="tlm-badge">RUN SETTINGS</div>
</header>

<div class="tlm-app">

  <nav class="tlm-sidenav">
    <div class="tlm-sidenav-label">Navigation</div>
    <a href="/general-settings">General Settings</a>
    <a href="/table-setup">Table Setup</a>
    <a href="/product-setup">Product Setup</a>
    <a href="/run-settings" class="active">Run Settings</a>
  </nav>

  <main class="tlm-page-main">
    $(notice_html)
    <div class="tlm-card">
    <form action="/run-settings" method="post" id="runs-form">
        <div class="rs-wrapper">
        $(table_html(runs))
        </div>
        <div class="rs-actions">
            <button type="submit" class="btn-primary">&#x1F4BE; Save Settings</button>
          </div>
    </form>
    </div>
  </main>

</div>
</body>
</html>""")
end

# ── Routes ─────────────────────────────────────────────────────────────────────
function register_routes()

    route("/run-settings", method=GET) do
        render_page(load_settings())
    end

    route("/run-settings", method=POST) do
        params  = Genie.Router.params()
        runs = form_to_settings(params)
        tmp  = SETTINGS_FILE * ".tmp"
        try
            open(tmp, "w") do io
                JSON3.pretty(io,JSON3.write(runs))
            end
            mv(tmp, SETTINGS_FILE, force=true)
            render_page(runs;
                notice="Saved to $(SETTINGS_FILE)",
                notice_type="success")
        catch e
            @error "Save failed" exception=e
            isfile(tmp) && rm(tmp)
            render_page(load_settings();
                notice="Save failed: $e", notice_type="error")
        end
    end

end

end # module

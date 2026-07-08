module GeneralSettings

using Genie, Genie.Router, Genie.Renderer.Html
using HTTP: escapehtml
using JSON3
using Dates

# ============================================================
# Constants
# ============================================================

const INPUT_PATH    = joinpath(dirname(dirname(dirname(@__FILE__))), "Input")
const SETTINGS_FILE = joinpath(INPUT_PATH, "general_settings.json")
const PRODUCTS_DIR  = joinpath(INPUT_PATH, "Products")

# ============================================================
# Helpers — settings I/O, product list, form parsing
# ============================================================

# Escape HTML special characters to prevent XSS
he(s) = escapehtml(string(s))

# Read current settings from JSON
function load_settings()::Dict
    settings = JSON3.read(SETTINGS_FILE, Dict{String,Any})
    settings["Valuation Date"] = settings["Valuation Date"][1:7]
    return settings
end

# Read all existing products
function all_products()::Vector{String}
    sort([replace(f, ".json" => "") for f in readdir(PRODUCTS_DIR) if endswith(f, ".json")])
end

# Convert POST params to settings Dict
function form_to_settings(params::Dict)::Dict
    Dict(
        "Valuation Date"                        => string(get(params, :valuation_date, "2025-12")),
        "Capital Requirement Gross Up Factor"   => tryparse(Float64, get(params, :capreq_grossup, "")),
        "Multithreading"                        => string(get(params, :multithreading, "Yes")),
        "Products to run"                       => string.(get(params, Symbol("products_to_run[]"), []))
    )
end

# ============================================================
# HTML Builder
# ============================================================

function render_page(settings::Dict, products::Vector{String};
                     notice::String="", notice_type::String="success")

    notice_html = isempty(notice) ? "" :
        "<div class='tlm-notice tlm-notice--$(he(notice_type))'>$(he(notice))</div>"

    selected_products = Set(get(settings, "Products to run", String[]))

    products_checkbox = join(["""
      <label class='gs-checkbox-label'>
        <input type='checkbox' name='products_to_run[]' value='$(he(p))'
               class='gs-checkbox' $(p in selected_products ? "checked" : "")>
        <span class='gs-checkbox-text'>$(he(p))</span>
      </label>""" for p in products], "\n")

    html("""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>TradLifeModel — General Settings</title>
  <link rel="stylesheet" href="/css/base.css">
  <link rel="stylesheet" href="/css/general_settings.css">
</head>
<body>

<header class="tlm-header">
  <a href="/" class="tlm-logo" style="text-decoration:none;color:inherit;">TradLifeModel</a>
  <div class="tlm-badge">GENERAL SETTINGS</div>
</header>

<div class="tlm-app">

  <nav class="tlm-sidenav">
    <div class="tlm-sidenav-label">Navigation</div>
    <a href="/table-setup">Table Setup</a>
    <a href="/product-setup">Product Setup</a>
    <a href="/model-point">Model Point</a>
    <a href="/run-settings">Run Settings</a>
    <a href="/general-settings" class="active">General Settings</a>
    <a href="/run-monitor">Run Monitor</a>
    <a href="/run-result">Run Result</a>
  </nav>

  <main class="tlm-page-main">
    $(notice_html)
    <div class="tlm-card">
      <form action="/general-settings" method="post" class="gs-form">

        <div class="tlm-field">
          <label class="tlm-label" for="valuation_date">Valuation Date (End of Month)</label>
          <input type="month" id="valuation_date" name="valuation_date"
                 value="$(he(get(settings, "Valuation Date", "2025-12")))"
                 class="tlm-input" required>
        </div>

        <div class="tlm-field">
          <label class="tlm-label" for="capreq_grossup">Capital Requirement Gross Up Factor</label>
          <input type="number" id="capreq_grossup" name="capreq_grossup"
                 value="$(he(get(settings, "Capital Requirement Gross Up Factor", 2.0)))"
                 min="0" max="10" step="0.01" class="tlm-input tlm-input--short">
        </div>

        <div class="tlm-field">
          <label class="tlm-label" for="multithreading">Multithreading</label>
          <select id="multithreading" name="multithreading" class="tlm-input tlm-input--short">
            <option value="Yes" $(get(settings, "Multithreading", "Yes") == "Yes" ? "selected" : "")>Yes</option>
            <option value="No" $(get(settings, "Multithreading", "Yes") == "No" ? "selected" : "")>No</option>
          </select>
        </div>

        <div class="tlm-field">
          <label class="tlm-label">Products to Run</label>
          <div class="gs-checkbox-group">$(products_checkbox)</div>
        </div>

        <hr class="tlm-divider">

        <div class="tlm-actions">
          <button type="submit" class="btn-primary">&#x1F4BE; Save Settings</button>
        </div>

      </form>
    </div>
  </main>

</div>

</body>
</html>""")
end

# ============================================================
# Routes
# ============================================================

function register_routes()

    route("/general-settings", method=GET) do
        render_page(load_settings(), all_products())
    end

    route("/general-settings", method=POST) do
        params   = Genie.Router.params()
        settings = form_to_settings(params)
        products = all_products()

        # Convert valuation date to end of month
        valn_date     = settings["Valuation Date"]
        valn_date_eom = string(lastdayofmonth(Date(valn_date)))
        settings_eom  = copy(settings)
        settings_eom["Valuation Date"] = valn_date_eom

        tmp = SETTINGS_FILE * ".tmp"
        try
            open(tmp, "w") do io
                JSON3.pretty(io, settings_eom)
            end
            mv(tmp, SETTINGS_FILE, force=true)
            render_page(settings, products;
                notice="Saved to $(SETTINGS_FILE)", notice_type="success")
        catch e
            @error "Save failed" exception=e
            isfile(tmp) && rm(tmp)
            render_page(load_settings(), products;
                notice="Save failed: $e", notice_type="error")
        end
    end

end

end # module

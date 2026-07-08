module RunSettings

using Genie, Genie.Router, Genie.Renderer.Html
using HTTP: escapehtml
using JSON3

# ============================================================
# Constants — paths, table structure, column keys
# ============================================================

const INPUT_PATH    = joinpath(dirname(dirname(dirname(@__FILE__))), "Input")
const SETTINGS_FILE = joinpath(INPUT_PATH, "run_settings.json")
const NUM_RUNS      = 20
const TABLE_STRUCTURE = [
    (key="Run Number",                          title="Run Number",        width=70,  type="numeric", mask="",      readonly=true ),
    (key="Run Indicator",                       title="Run Indicator",     width=70,  type="checkbox", mask="",     readonly=false),
    (key="Run Description",                     title="Run Description",   width=200, type="text",     mask="",     readonly=false),
    (key="Base Projection - Mortality",         title="Mortality",         width=85,  type="numeric", mask="0.00%", readonly=false),
    (key="Base Projection - Lapse",             title="Lapse",             width=85,  type="numeric", mask="0.00%", readonly=false),
    (key="Base Projection - Expense",           title="Expense",           width=85,  type="numeric", mask="0.00%", readonly=false),
    (key="Base Projection - Discount Rate",     title="Discount Rate",     width=85,  type="numeric", mask="0.00%", readonly=false),
    (key="Base Projection - Investment Return", title="Investment Return", width=85,  type="numeric", mask="0.00%", readonly=false),
    (key="Valuation - Mortality",               title="Mortality",         width=85,  type="numeric", mask="0.00%", readonly=false),
    (key="Valuation - Lapse",                   title="Lapse",             width=85,  type="numeric", mask="0.00%", readonly=false),
    (key="Valuation - Expense",                 title="Expense",           width=85,  type="numeric", mask="0.00%", readonly=false),
    (key="Valuation - Discount Rate",           title="Discount Rate",     width=85,  type="numeric", mask="0.00%", readonly=false),
    (key="Capital Requirement - Mortality",     title="Mortality",         width=85,  type="numeric", mask="0.00%", readonly=false),
    (key="Capital Requirement - Lapse",         title="Lapse",             width=85,  type="numeric", mask="0.00%", readonly=false),
    (key="Capital Requirement - Expense",       title="Expense",           width=85,  type="numeric", mask="0.00%", readonly=false),
    (key="Capital Requirement - Discount Rate", title="Discount Rate",     width=85,  type="numeric", mask="0.00%", readonly=false),
]
const KEYS = [col.key for col in TABLE_STRUCTURE]

# ============================================================
# Helpers — default data, JSS data builder, column definitions
# ============================================================

# Escape HTML special characters to prevent XSS
he(s) = escapehtml(string(s))

# Default data when no saved file exists
function default_data()
    data = [[i, "NO", "Run $(lpad(i,2,'0'))", 0,0,0,0,0,0,0,0,0,0,0,0,0] for i in 1:NUM_RUNS]
    return JSON3.write(data)
end

# Load existing run settings
function jss_data()
    isfile(SETTINGS_FILE) || return default_data()
    runs = JSON3.read(read(SETTINGS_FILE, String))
    all_data = []
    for run in runs
        data = []
        for (i, k) in enumerate(KEYS)
            value = get(run, Symbol(k), nothing)
            if k == "Run Indicator"
                value = (value == "Yes" || value == true) ? true : false
            end
            push!(data, value)
        end
        push!(all_data, data)
    end
    return JSON3.write(all_data)
end

# Column definitions for jspreadsheet
function jss_columns()
    cols = []
    for c in TABLE_STRUCTURE
        col = Dict{String,Any}(
            "title" => c.title,
            "width" => c.width,
            "type"  => c.type
        )
        !isempty(c.mask) && (col["mask"]    = c.mask)
        c.readonly       && (col["readOnly"] = true)
        push!(cols, col)
    end
    return JSON3.write(cols)
end

# ============================================================
# HTML Builder
# ============================================================

function render_page(; notice::String="", notice_type::String="success")
    notice_html   = isempty(notice) ? "" :
        "<div class='tlm-notice tlm-notice--$(notice_type)'>$(he(notice))</div>"
    table_data    = jss_data()
    table_columns = jss_columns()

    html("""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>TradLifeModel — Run Settings</title>
  <link rel="stylesheet" href="/css/base.css">
  <link rel="stylesheet" href="/css/run_settings.css">
  <link rel="stylesheet" href="/css/jspreadsheet.min.css">
  <link rel="stylesheet" href="/css/jsuites.min.css">
  <script src="/js/jsuites.min.js"></script>
  <script src="/js/index.min.js"></script>
</head>
<body>

<header class="tlm-header">
  <a href="/" class="tlm-logo" style="text-decoration:none;color:inherit;">TradLifeModel</a>
  <div class="tlm-badge">RUN SETTINGS</div>
</header>

<div class="tlm-app">

  <nav class="tlm-sidenav">
    <div class="tlm-sidenav-label">Navigation</div>
    <a href="/table-setup">Table Setup</a>
    <a href="/product-setup">Product Setup</a>
    <a href="/model-point">Model Point</a>
    <a href="/run-settings" class="active">Run Settings</a>
    <a href="/general-settings">General Settings</a>
    <a href="/run-monitor">Run Monitor</a>
    <a href="/run-result">Run Result</a>
  </nav>

  <main class="tlm-page-main">
    $(notice_html)
    <div class="tlm-card">
      <form method="POST" action="/run-settings" id="runs-form">
        <input type="hidden" id="runs-data" name="runs_data">
        <div class="rs-wrapper">
          <div id="rs-spreadsheet"></div>
        </div>
        <div class="rs-actions">
          <button type="submit" class="btn-primary">&#x1F4BE; Save Settings</button>
        </div>
      </form>
    </div>
  </main>

</div>

<script>
let table = jspreadsheet(document.getElementById('rs-spreadsheet'), {
  data: $(table_data),
  columns: $(table_columns),
  nestedHeaders: [[
    { title: '',                    colspan: 3 },
    { title: 'Base Projection',     colspan: 5 },
    { title: 'Valuation',           colspan: 4 },
    { title: 'Capital Requirement', colspan: 4 }
  ]],
  wordWrap: true,
  tableOverflow: false,
  tableWidth: '1200px',
  freezeColumns: 3,

  // Block non-numeric characters while typing (columns 3 onwards)
  oncreateeditor: function(el, cell, x, y, input) {
    if (parseInt(x) >= 3) {
      input.addEventListener('input', function() {
        this.value = this.value.replace(/[^0-9.\\-]/g, '');
      });
    }
  },

  // Reject non-numeric values on cell commit (catches paste)
  onbeforechange: function(instance, cell, x, y, value) {
    if (parseInt(x) >= 3 && value !== '' && isNaN(value)) {
      return '';
    }
  }
});

const keys = $(JSON3.write(KEYS));

document.getElementById('runs-form').addEventListener('submit', function(e) {
  e.preventDefault();

  let runs = [];
  for (let r = 0; r < $(NUM_RUNS); r++) {
    let rowdata = table.getRowData(r);
    let run = {};

    for (let i = 0; i < keys.length; i++) {
      let value = rowdata[i];

      if (i === 1) {
        // checkbox → Yes/No
        value = (value === true || value === "true") ? "Yes" : "No";
      } else if (i >= 3) {
        // ensure numeric — jspreadsheet may return strings for unedited cells
        value = parseFloat(value);
      }

      run[keys[i]] = value;
    }

    runs.push(run);
  }

  document.getElementById('runs-data').value = JSON.stringify(runs);
  e.target.submit();
});
</script>

</body>
</html>""")
end

# ============================================================
# Routes
# ============================================================

function register_routes()

    route("/run-settings", method=GET) do
        render_page()
    end

    route("/run-settings", method=POST) do
        runs = JSON3.read(Genie.Requests.postpayload(:runs_data, "[]"))
        tmp  = SETTINGS_FILE * ".tmp"
        try
            open(tmp, "w") do io
                JSON3.pretty(io, runs)
            end
            mv(tmp, SETTINGS_FILE, force=true)
            render_page(;
                notice="Saved to $(SETTINGS_FILE)",
                notice_type="success")
        catch e
            @error "Save failed" exception=e
            isfile(tmp) && rm(tmp)
            render_page(;
                notice="Save failed: $e",
                notice_type="error")
        end
    end

end

end # module

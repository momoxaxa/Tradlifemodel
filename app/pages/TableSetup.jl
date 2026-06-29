module TableSetup

using Genie, Genie.Router, Genie.Renderer.Html, Genie.Renderer.Json
using HTTP: escapehtml
using JSON3
using CSV, DataFrames
using MortalityTables

# ============================================================
# Constants
# ============================================================

const INPUT_PATH           = joinpath(dirname(dirname(dirname(@__FILE__))), "Input")
const TABLES_DIR           = joinpath(INPUT_PATH, "Tables")
const LISTINGS_PATH        = joinpath(INPUT_PATH, "table_listings.json")
const TABLE_TYPE_DEFN_PATH = joinpath(INPUT_PATH, "table_type_defn.json")

const SECTIONS = [
    ("Product Features", [
        ("Premium",           "premium"),
        ("Death Benefit",     "death_ben"),
        ("Surrender Benefit", "surr_ben"),
        ("Commission",        "commission"),
    ]),
    ("Assumptions", [
        ("Mortality", "mortality"),
        ("Lapse",     "lapse"),
        ("Expense",   "expense"),
        ("Disc Rate", "disc_rate"),
        ("Prem Tax",  "prem_tax"),
        ("Tax",       "tax"),
    ]),
]

# ============================================================
# Helpers — JSON, HTML escaping, lookups, CSV I/O
# ============================================================

# Load json file into Dict
function load_json(path::String)::Dict{String,Any}
    JSON3.read(path, Dict{String,Any})
end

# Escape HTML special characters to prevent XSS
he(s) = escapehtml(string(s))

# Get the definition metadata for a given table type within a category
function get_table_type_meta(cat::String, ttype::String)::Dict{String,Any}
    config    = load_json(TABLE_TYPE_DEFN_PATH)
    cat_defns = get(config, cat, Dict{String,Any}())
    get(cat_defns, ttype, Dict{String,Any}())
end

# Get information for a given table name (e.g. "PREM01") from table_listings.json
function get_table_info(listings::Dict{String,Any}, name::AbstractString)::Dict{String,Any}
    v = get(listings, name, Dict{String,Any}())
    v isa Dict{String,Any} ? v : Dict{String,Any}()
end

# Get all existing table names for a given category key (e.g. "premium")
function tables_for_cat(listings::Dict{String,Any}, cat::String)::Vector{String}
    sort([string(k) for (k,v) in listings
          if string(get(v, "Table Category", "")) == cat])
end

# Get all existing table types for a given category key (e.g. "premium")
function types_for_cat(cat::String)::Vector{String}
    config = load_json(TABLE_TYPE_DEFN_PATH)
    haskey(config, cat) ? collect(keys(config[cat])) : String[]
end

# Safely convert v to Float64, with missing/nothing converted to NaN by default
sf(v, d=NaN) = (ismissing(v) || v === nothing) ? d :
               something(tryparse(Float64, string(v)), d)

# Safely convert v to Int, with missing/nothing converted to NaN by default
si(v, d=NaN) = (ismissing(v) || v === nothing) ? d :
               something(tryparse(Int, string(v)), d)

# Load a table csv file into DataFrame
function load_table_csv(filename::String)::Union{DataFrame,Nothing}
    path = joinpath(TABLES_DIR, filename)
    isfile(path) || return nothing
    CSV.read(path, DataFrame; missingstring="")
end

# Save table string data to a csv file
function save_table_to_csv(filename::String, csvdata::String)
    path = joinpath(TABLES_DIR, filename)
    tmp  = path * ".tmp"
    open(tmp, "w") do io
        write(io, csvdata)
    end
    mv(tmp, path, force=true)
end

# Look up SOA Table Name by ID
function lookup_soa_table_name(id::Integer)::Union{String,Nothing}
    try
        MortalityTables.table(Int(id)).metadata.name
    catch
        nothing
    end
end

# Update table_listings.json with a new (or existing) table entry
function upsert_table_to_listing(tname::String, cat::String, ttype::String, filename::String)
    listings = load_json(LISTINGS_PATH)
    listings[tname] = Dict{String,Any}(
        "Table Category" => cat,
        "Table Filename" => filename,
        "Table Type"     => ttype,
        "Table Details"  => "",
    )
    tmp = LISTINGS_PATH * ".tmp"
    open(tmp, "w") do io
        JSON3.pretty(io, listings)
    end
    mv(tmp, LISTINGS_PATH, force=true)
end

# Delete a table entry from table_listings.json
function delete_table_from_listing(tname::String)
    listings = load_json(LISTINGS_PATH)
    delete!(listings, tname)
    tmp = LISTINGS_PATH * ".tmp"
    open(tmp, "w") do io
        JSON3.pretty(io, listings)
    end
    mv(tmp, LISTINGS_PATH, force=true)
end

# Convert a vector to a JS array string (e.g. ['a','b','c'])
function js_str_array(arr::Vector)::String
    "[" * join(["'$(he(s))'" for s in arr], ",") * "]"
end

# ============================================================
# JSS Data Builders — convert Julia data to jspreadsheet JSON
# ============================================================

# Float matrix (e.g. [[1,0.05,0.1], [2,0.03,0.08]])
function create_jss_data(rows::Vector, mat::Matrix{Float64})::String
    data = []
    for r in 1:size(mat, 1)
        row = Vector{Any}(undef, size(mat, 2) + 1)
        row[1] = rows[r]
        for c in 1:size(mat, 2)
            row[c + 1] = isnan(mat[r, c]) ? nothing : mat[r, c]
        end
        push!(data, row)
    end
    return JSON3.write(data)
end

# String matrix (e.g. [['a','b'], ['c','d']])
function create_jss_data(rows::Vector, mat::Matrix{String})::String
    data = []
    for r in 1:size(mat, 1)
        row = Vector{Any}(undef, size(mat, 2) + 1)
        row[1] = rows[r]
        for c in 1:size(mat, 2)
            row[c + 1] = mat[r, c] == "NaN" ? nothing : mat[r, c]
        end
        push!(data, row)
    end
    return JSON3.write(data)
end

# No column matrix — row index only (e.g. [['a'], ['b']])
function create_jss_data(rows::Vector, mat::Nothing)::String
    return JSON3.write([[r] for r in rows])
end

# ============================================================
# Grid Builders — one per table layout type
# ============================================================

# Grid builder — scalar
function grid_scalar(meta::Dict{String,Any}, filename::String)::String
    row_name = string(get(meta, "row_name", "Row"))
    col_name = get(meta, "col_names", String[])[1]
    rows     = get(meta, "row_values", String[])
    mat      = fill(NaN, 1, 1)

    df = load_table_csv(filename)
    if df !== nothing
        mat[1, 1] = sf(df[1, 2], NaN)
    end

    jss_data = create_jss_data(rows, mat)
    """<div id='jss-grid'></div>
<script>
(function(){
  var tbl = jspreadsheet(document.getElementById('jss-grid'), {
    data: $(jss_data),
    columns: [
      { title: '$(he(row_name))', width: 90,  type: 'text',    readOnly: true },
      { title: '$(he(col_name))', width: 160, type: 'numeric' }
    ],
    allowRenameColumn: false,
    tableOverflow: true, tableHeight: '55vh',
    columnSorting: false,
    allowInsertRow: false, allowDeleteRow: false,
    allowInsertColumn: false, allowDeleteColumn: false,
    oncreateeditor: function(el, cell, x, y, input) {
      if (parseInt(x) >= 1) {
        input.addEventListener('input', function() {
          this.value = this.value.replace(/[^0-9.\\-]/g, '');
        });
      }
    },
    onbeforechange: function(instance, cell, x, y, value) {
      if (parseInt(x) >= 1 && value !== '' && isNaN(value)) {
        return '';
      }
    }
  });
  window._grid = {
    jss: tbl,
    type: 'scalar',
    rowName: '$(he(row_name))',
    colNames: ['$(he(col_name))']
  };
})();
</script>"""
end

# Grid builder — vector
function grid_vector(meta::Dict{String,Any}, filename::String)::String
    n_row    = si(get(meta, "n_row", 120), 120)
    row_name = string(get(meta, "row_name", "Row"))
    col_name = string(get(meta, "col_names", String[])[1])
    rows     = row_name == "Age" ? [i for i in 0:n_row-1] : [i for i in 1:n_row]
    mat      = fill(NaN, n_row, 1)

    df = load_table_csv(filename)
    if df !== nothing
        for r in 1:min(nrow(df), n_row)
            mat[r, 1] = sf(df[r, 2], NaN)
        end
    end

    jss_data = create_jss_data(rows, mat)
    """<div id='jss-grid'></div>
<script>
(function(){
  var tbl = jspreadsheet(document.getElementById('jss-grid'), {
    data: $(jss_data),
    columns: [
      { title: '$(he(row_name))', width: 90,  type: 'text',    readOnly: true },
      { title: '$(he(col_name))', width: 160, type: 'numeric' }
    ],
    allowRenameColumn: false,
    tableOverflow: true, tableHeight: '55vh',
    columnSorting: false,
    allowInsertRow: false, allowDeleteRow: false,
    allowInsertColumn: false, allowDeleteColumn: false,
    oncreateeditor: function(el, cell, x, y, input) {
      if (parseInt(x) >= 1) {
        input.addEventListener('input', function() {
          this.value = this.value.replace(/[^0-9.\\-]/g, '');
        });
      }
    },
    onbeforechange: function(instance, cell, x, y, value) {
      if (parseInt(x) >= 1 && value !== '' && isNaN(value)) {
        return '';
      }
    }
  });
  window._grid = {
    jss: tbl,
    type: 'vector',
    rowName: '$(he(row_name))',
    colNames: ['$(he(col_name))']
  };
})();
</script>"""
end

# Grid builder — matrix
function grid_matrix(meta::Dict{String,Any}, filename::String)::String
    n_row     = si(get(meta, "n_row", 120), 120)
    n_col     = si(get(meta, "n_col", 120), 120)
    row_name  = string(get(meta, "row_name", "Row"))
    col_group = string(get(meta, "col_group", "Col"))
    rows      = row_name == "Age" ? [i for i in 0:n_row-1] : [i for i in 1:n_row]
    col_names = [j for j in 1:n_col]
    mat       = fill(NaN, n_row, n_col)

    df = load_table_csv(filename)
    if df !== nothing
        for r in 1:min(nrow(df), n_row), c in 1:min(ncol(df)-1, n_col)
            mat[r, c] = sf(df[r, c+1], NaN)
        end
    end

    jss_data      = create_jss_data(rows, mat)
    data_col_hdrs = join(["{ title: '$(he(col_names[j]))', width: 65, type: 'numeric' }"
                          for j in 1:n_col], ", ")
    col_names_js  = js_str_array(col_names)

    """<div id='jss-grid'></div>
<script>
(function(){
  var tbl = jspreadsheet(document.getElementById('jss-grid'), {
    data: $(jss_data),
    columns: [
      { title: '$(he(row_name))', width: 80, type: 'text', readOnly: true },
      $(data_col_hdrs)
    ],
    nestedHeaders: [[
      { title: '',                 colspan: 1 },
      { title: '$(he(col_group))', colspan: $(n_col) }
    ]],
    allowRenameColumn: false,
    tableOverflow: true, tableHeight: '55vh',
    columnSorting: false,
    allowInsertRow: false, allowDeleteRow: false,
    allowInsertColumn: false, allowDeleteColumn: false,
    oncreateeditor: function(el, cell, x, y, input) {
      if (parseInt(x) >= 1) {
        input.addEventListener('input', function() {
          this.value = this.value.replace(/[^0-9.\\-]/g, '');
        });
      }
    },
    onbeforechange: function(instance, cell, x, y, value) {
      if (parseInt(x) >= 1 && value !== '' && isNaN(value)) {
        return '';
      }
    }
  });
  window._grid = {
    jss: tbl,
    type: 'matrix',
    rowName: '$(he(row_name))',
    colNames: $(col_names_js),
    colGroup: '$(he(col_group))'
  };
})();
</script>"""
end

# Grid builder — fixed_col
function grid_fixed_col(meta::Dict{String,Any}, filename::String)::String
    n_row     = si(get(meta, "n_row", 120), 120)
    row_name  = string(get(meta, "row_name", "Row"))
    col_names = string.(get(meta, "col_names", String[]))
    n_cols    = length(col_names)
    is_cal    = row_name == "Cal Year"

    rows = if is_cal
        String[]
    elseif row_name == "Age"
        [i for i in 0:n_row-1]
    else
        [i for i in 1:n_row]
    end

    mat = fill(NaN, n_row, n_cols)

    df = load_table_csv(filename)
    if df !== nothing
        for r in 1:min(nrow(df), n_row), c in 1:min(ncol(df)-1, n_cols)
            mat[r, c] = sf(df[r, c+1], NaN)
        end
    end

    if is_cal
        if df !== nothing
            for r in 1:min(nrow(df), n_row)
                push!(rows, string(df[r, 1]))
            end
        end
        start = length(rows) > 0 ? si(rows[end], 2024) + 1 : 2024
        while length(rows) < n_row
            push!(rows, string(start))
            start += 1
        end
    end

    jss_data      = create_jss_data(rows, mat)
    data_col_hdrs = join(["{ title: '$(he(col_names[j]))', width: 120, type: 'numeric' }"
                          for j in 1:n_cols], ", ")
    col_names_js  = js_str_array(col_names)

    start_year_html = is_cal ? """
<div class='tlm-field--row' style='margin-bottom:0.75rem'>
  <div class='tlm-field-group'>
    <label class='tlm-label'>Start Year</label>
    <input type='number' id='cal-start-year' class='tlm-input' style='max-width:120px'
           value='$(length(rows) > 0 ? he(rows[1]) : "2024")'
           onchange='onCalYearChange()'>
  </div>
</div>""" : ""

    """$(start_year_html)<div id='jss-grid'></div>
<script>
(function(){
  var tbl = jspreadsheet(document.getElementById('jss-grid'), {
    data: $(jss_data),
    columns: [
      { title: '$(he(row_name))', width: 90, type: 'text', readOnly: true },
      $(data_col_hdrs)
    ],
    allowRenameColumn: false,
    tableOverflow: true, tableHeight: '55vh',
    columnSorting: false,
    allowInsertRow: false, allowDeleteRow: false,
    allowInsertColumn: false, allowDeleteColumn: false,
    oncreateeditor: function(el, cell, x, y, input) {
      if (parseInt(x) >= 1) {
        input.addEventListener('input', function() {
          this.value = this.value.replace(/[^0-9.\\-]/g, '');
        });
      }
    },
    onbeforechange: function(instance, cell, x, y, value) {
      if (parseInt(x) >= 1 && value !== '' && isNaN(value)) {
        return '';
      }
    }
  });
  window._grid = {
    jss: tbl,
    type: 'fixed_col',
    rowName: '$(he(row_name))',
    colNames: $(col_names_js),
    isCalYear: $(is_cal ? "true" : "false")
  };
})();
</script>"""
end

# Grid builder — select_ultimate
function grid_select_ultimate(meta::Dict{String,Any}, filename::String,
                              max_issue_age::Int, select_duration::Int,
                              sel_table::String="")::String
    row_name = string(get(meta, "row_name", "Issue Age"))

    df = load_table_csv(filename)
    if df !== nothing
        max_issue_age   = si(df[end, 1], max_issue_age)
        select_duration = si(names(df)[end-2], select_duration)
    end

    n_rows = max_issue_age + 1
    n_cols = select_duration + 2   # Dur 1..N + Ultimate + Attained Age
    rows   = [i for i in 0:max_issue_age]
    mat    = fill(NaN, n_rows, n_cols)

    # Pre-populate Attained Age column
    for r in 1:n_rows
        mat[r, n_cols] = (r - 1) + select_duration
    end

    if df !== nothing
        for r in 1:n_rows, c in 1:n_cols
            mat[r, c] = sf(df[r, c+1], NaN)
        end
    end

    jss_data       = create_jss_data(rows, mat)
    dur_cols       = join(["{ title: '$(j)', width: 65, type: 'numeric' }"
                           for j in 1:select_duration], ", ")
    col_names_list = vcat([string(j) for j in 1:select_duration], ["Ultimate", "Attained Age"])
    col_names_js   = js_str_array(col_names_list)
    is_new         = isempty(sel_table)

    su_input_html = """
<div class='tlm-field--row' style='margin-bottom:0.75rem'>
  <div class='tlm-field-group'>
    <label class='tlm-label'>Max Age</label>
    <input type='number' id='su-max-age' class='tlm-input'
           style='max-width:100px; $(is_new ? "" : "opacity:0.6;")'
           min='1' max='119' value='$(he(string(max_issue_age)))'
           $(is_new ? "" : "readonly")>
  </div>
  <div class='tlm-field-group'>
    <label class='tlm-label'>Select Duration</label>
    <input type='number' id='su-max-duration' class='tlm-input'
           style='max-width:100px; $(is_new ? "" : "opacity:0.6;")'
           min='1' max='50' value='$(he(string(select_duration)))'
           $(is_new ? "" : "readonly")>
  </div>
  $(is_new ? """
  <div class='tlm-field-group' style='align-self:flex-end'>
    <button class='btn-primary' onclick='applySuInput()'>Apply</button>
  </div>""" : "")
</div>"""

    """$(su_input_html)<div id='jss-grid'></div>
<script>
(function(){
  var tbl = jspreadsheet(document.getElementById('jss-grid'), {
    data: $(jss_data),
    columns: [
      { title: '$(he(row_name))', width: 85, type: 'text',    readOnly: true },
      $(dur_cols),
      { title: 'Ultimate',        width: 85, type: 'numeric' },
      { title: 'Attained Age',    width: 95, type: 'text',    readOnly: true }
    ],
    nestedHeaders: [[
      { title: '',         colspan: 1 },
      { title: 'Duration', colspan: $(select_duration) },
      { title: '',         colspan: 2 }
    ]],
    allowRenameColumn: false,
    tableOverflow: true, tableHeight: '55vh',
    columnSorting: false,
    allowInsertRow: false, allowDeleteRow: false,
    allowInsertColumn: false, allowDeleteColumn: false,
    oncreateeditor: function(el, cell, x, y, input) {
      if (parseInt(x) >= 1) {
        input.addEventListener('input', function() {
          this.value = this.value.replace(/[^0-9.\\-]/g, '');
        });
      }
    },
    onbeforechange: function(instance, cell, x, y, value) {
      if (parseInt(x) >= 1 && value !== '' && isNaN(value)) {
        return '';
      }
    }
  });
  window._grid = {
    jss: tbl,
    type: 'select_ultimate',
    rowName: '$(he(row_name))',
    colNames: $(col_names_js),
    maxIssueAge: $(max_issue_age),
    maxDuration: $(select_duration)
  };
})();
</script>"""
end

# Grid builder — mapping
function grid_mapping(meta::Dict{String,Any}, filename::String,
                      listings::Dict{String,Any})::String
    row_name     = string(get(meta, "row_name", ""))
    rows         = string.(get(meta, "row_values", String[]))
    col_names    = string.(get(meta, "col_names",    String[]))
    col_types    = string.(get(meta, "col_types",    String[]))
    filter_types = string.(get(meta, "filter_types", String[]))
    n_rows       = length(rows)
    n_cols       = length(col_names)
    mat          = fill("", n_rows, n_cols)

    df = load_table_csv(filename)
    if df !== nothing
        for r in 1:n_rows, c in 1:n_cols
            mat[r, c] = string(df[r, c+1])
        end
    end

    jss_data    = create_jss_data(rows, mat)
    dropdown_ci = findfirst(==("dropdown"), col_types)
    auto_ci     = findfirst(==("auto"),     col_types)
    # col_types is 1-indexed; JS col 0 is the row label, so index N → JS col N
    dropdown_js = dropdown_ci !== nothing ? dropdown_ci : -1
    auto_js     = auto_ci     !== nothing ? auto_ci     : -1

    filtered_tables = sort([string(k) for (k,v) in listings
                            if string(get(v, "Table Type", "")) in filter_types])

    type_by_table = Dict{String,String}()
    for (tname, tinfo) in listings
        ttype = string(get(tinfo, "Table Type", ""))
        if ttype in filter_types
            type_by_table[string(tname)] = ttype
        end
    end

    filtered_tables_js = js_str_array(filtered_tables)
    type_by_table_js   = "{" * join(["'$(he(k))': '$(he(v))'"
                                     for (k,v) in type_by_table], ", ") * "}"
    col_names_js       = js_str_array(col_names)
    col_types_js       = js_str_array(col_types)

    col_cfgs = ["{ title: '$(he(row_name))', width: 220, type: 'text', readOnly: true }"]
    for (cname, ctype) in zip(col_names, col_types)
        if ctype == "dropdown"
            push!(col_cfgs, "{ title: '$(he(cname))', width: 220, type: 'dropdown', source: $(filtered_tables_js), autocomplete: true }")
        elseif ctype == "auto"
            push!(col_cfgs, "{ title: '$(he(cname))', width: 220, type: 'text', readOnly: true }")
        end
    end

    """<div id='jss-grid'></div>
<script>
(function(){
  var _typeByTable = $(type_by_table_js);
  var tbl = jspreadsheet(document.getElementById('jss-grid'), {
    data: $(jss_data),
    columns: [ $(join(col_cfgs, ", ")) ],
    allowRenameColumn: false,
    tableOverflow: true, tableHeight: 'auto',
    columnSorting: false,
    allowInsertRow: false, allowDeleteRow: false,
    allowInsertColumn: false, allowDeleteColumn: false,
    oneditionend: function(el, cell, x, y, value, saved) {
      if (x === $(dropdown_js) && saved) {
        var actual = tbl.getValueFromCoords($(dropdown_js), y);
        var ttype  = _typeByTable[actual] || '';
        tbl.setValueFromCoords($(auto_js), y, ttype, true);
      }
    }
  });
  window._grid = {
    jss: tbl,
    type: 'mapping',
    rowName: '$(he(row_name))',
    colNames: $(col_names_js),
    colTypes: $(col_types_js),
    nRows: $(n_rows)
  };
})();
</script>"""
end

# Grid builder — mapping_ID
function grid_mapping_ID(meta::Dict{String,Any}, filename::String)::String
    row_name  = string(get(meta, "row_name", ""))
    rows      = string.(get(meta, "row_values", String[]))
    col_names = string.(get(meta, "col_names",  String[]))
    col_types = string.(get(meta, "col_types",  String[]))
    n_rows    = length(rows)
    n_cols    = length(col_names)
    mat       = fill("", n_rows, n_cols)

    df = load_table_csv(filename)
    if df !== nothing
        for r in 1:n_rows, c in 1:n_cols
            mat[r, c] = string(df[r, c+1])
        end
    end

    jss_data     = create_jss_data(rows, mat)
    col_names_js = js_str_array(col_names)
    col_types_js = js_str_array(col_types)
    id_ci        = findfirst(==("numeric"), col_types)
    auto_ci      = findfirst(==("auto"),    col_types)
    id_js        = id_ci   !== nothing ? id_ci   : -1
    auto_js      = auto_ci !== nothing ? auto_ci : -1

    col_cfgs = ["{ title: '$(he(row_name))', width: 220, type: 'text', readOnly: true }"]
    for (cname, ctype) in zip(col_names, col_types)
        if ctype == "numeric"
            push!(col_cfgs, "{ title: '$(he(cname))', width: 220, type: 'numeric' }")
        elseif ctype == "auto"
            push!(col_cfgs, "{ title: '$(he(cname))', width: 420, type: 'text', readOnly: true }")
        end
    end

    """<div id='jss-grid'></div>
<div style='margin-top:8px'>
  <button id='btn-lookup'>Look up table names</button>
  <span id='lookup-status' style='margin-left:10px'></span>
</div>
<script>
(function(){
  var ID_COL = $(id_js), NAME_COL = $(auto_js), N_ROWS = $(n_rows);

  var tbl = jspreadsheet(document.getElementById('jss-grid'), {
    data: $(jss_data),
    columns: [ $(join(col_cfgs, ", ")) ],
    allowRenameColumn: false,
    tableOverflow: true, tableHeight: 'auto',
    columnSorting: false,
    allowInsertRow: false, allowDeleteRow: false,
    allowInsertColumn: false, allowDeleteColumn: false,
    onchange: function(el, cell, x, y, value) {
      if (parseInt(x) === ID_COL) {
        window._grid.valid = false;
        tbl.setValueFromCoords(NAME_COL, y, '', true);
        setStatus('IDs changed — look up names before saving.', 'orange');
      }
    },
    oncreateeditor: function(el, cell, x, y, input) {
      if (parseInt(x) === ID_COL) {
        input.addEventListener('input', function() {
          this.value = this.value.replace(/[^0-9]/g, '');
        });
      }
    },
    onbeforechange: function(instance, cell, x, y, value) {
      if (parseInt(x) === ID_COL && value !== '' && isNaN(value)) {
        return '';
      }
    }
  });

  function setStatus(msg, color) {
    var s = document.getElementById('lookup-status');
    s.textContent = msg;
    s.style.color = color;
  }

  document.getElementById('btn-lookup').onclick = function() {
    var ids = [];
    for (var r = 0; r < N_ROWS; r++) ids.push(tbl.getValueFromCoords(ID_COL, r));
    fetch('/api/mort_lookup?ids=' + encodeURIComponent(ids.join(',')))
      .then(function(resp) { return resp.json(); })
      .then(function(names) {
        var allOk = true;
        ids.forEach(function(id, r) {
          var name = names[String(id)] || '';
          tbl.setValueFromCoords(NAME_COL, r, name, true);
          if (!name) allOk = false;
        });
        window._grid.valid = allOk;
        setStatus(
          allOk ? 'All IDs matched.' : 'Unmatched ID(s) — fix highlighted rows.',
          allOk ? 'green' : 'red'
        );
      })
      .catch(function(err) {
        console.error('Lookup handler error:', err);
        setStatus('Lookup failed: ' + err.message, 'red');
      });
  };

  window._grid = {
    jss: tbl,
    type: 'mapping_ID',
    rowName: '$(he(row_name))',
    colNames: $(col_names_js),
    colTypes: $(col_types_js),
    nRows: $(n_rows),
    valid: false
  };
})();
</script>"""
end

# Grid builder — user_defined
function grid_user_defined(meta::Dict{String,Any}, filename::String)::String
    n_row     = si(get(meta, "n_row", 120), 120)
    row_name  = string(get(meta, "row_name", "Year"))
    user_cols = String[]
    n_col     = 0
    rows      = [string(i) for i in 1:n_row]
    mat       = nothing

    df = load_table_csv(filename)
    if df !== nothing
        user_cols = [string(names(df)[c]) for c in 2:ncol(df)]
        n_col     = length(user_cols)
        mat       = fill(NaN, n_row, n_col)
        for r in 1:n_row, c in 1:n_col
            mat[r, c] = sf(df[r, c+1])
        end
    end

    jss_data    = create_jss_data(rows, mat)
    col_section = n_col > 0 ? ",\n      $(join(["{ title: '$(he(user_cols[j]))', width: 120, type: 'numeric' }" for j in 1:n_col], ", "))" : ""
    col_names_js = js_str_array(user_cols)

    """<div id='jss-grid-instruction' class='ts-placeholder'>
  <strong>Add a column:</strong> right-click a column header and choose to insert before or after it.<br>
  <strong>Rename a column:</strong> right-click the header and select rename.<br>
  <strong>Delete column(s):</strong> right-click the header (hold Shift to select multiple), then choose delete.
</div>
<div id='jss-grid'></div>
<script>
(function(){
  var tbl = jspreadsheet(document.getElementById('jss-grid'), {
    data: $(jss_data),
    columns: [
      { title: '$(he(row_name))', width: 70, type: 'text', readOnly: true }$(col_section)
    ],
    allowRenameColumn: true,
    tableOverflow: true, tableHeight: '55vh',
    columnSorting: false,
    allowInsertRow: false, allowDeleteRow: false,
    allowInsertColumn: true, allowDeleteColumn: true,
    oncreateeditor: function(el, cell, x, y, input) {
      if (parseInt(x) >= 1) {
        input.addEventListener('input', function() {
          this.value = this.value.replace(/[^0-9.\\-]/g, '');
        });
      }
    },
    onbeforechange: function(instance, cell, x, y, value) {
      if (parseInt(x) >= 1 && value !== '' && isNaN(value)) {
        return '';
      }
    },
    onbeforeinsertcolumn: function(el, colIndex, numOfColumns, insertBefore) {
      if (parseInt(colIndex) === 0 && insertBefore) {
        alert('Columns cannot be added before the row index column.');
        return false;
      }
    },
    onbeforedeletecolumn: function(el, colIndex, numOfColumns) {
      if (parseInt(colIndex) === 0) {
        alert('The row index column cannot be deleted.');
        return false;
      }
    },
    onchangeheader: function(el, colIndex, oldValue, newValue) {
      if (parseInt(colIndex) === 0 && newValue !== "Year") {
        alert('The row index header cannot be changed.');
        tbl.setHeader(0, "Year");
      }
    }
  });
  window._grid = {
    jss: tbl,
    type: 'user_defined',
    rowName: '$(he(row_name))',
    colNames: $(col_names_js)
  };
})();
</script>"""
end

# Grid dispatcher — routes table type string to the right builder
function grid_for_type(ttype::String, filename::String, cat::String;
                       max_issue_age::Int=119, select_duration::Int=120,
                       sel_table::String="",
                       listings::Dict{String,Any}=Dict{String,Any}())::String
    meta = get_table_type_meta(cat, ttype)
    dims = string(get(meta, "dims", ""))

    if dims == "scalar"
        return grid_scalar(meta, filename)
    elseif dims == "vector"
        return grid_vector(meta, filename)
    elseif dims == "matrix"
        return grid_matrix(meta, filename)
    elseif dims == "fixed_col"
        return grid_fixed_col(meta, filename)
    elseif dims == "select_ultimate"
        return grid_select_ultimate(meta, filename, max_issue_age, select_duration, sel_table)
    elseif dims == "mapping"
        return grid_mapping(meta, filename, listings)
    elseif dims == "mapping_ID"
        return grid_mapping_ID(meta, filename)
    elseif dims == "user_defined"
        return grid_user_defined(meta, filename)
    else
        return "<div class='ts-placeholder'>Unknown table type: $(he(ttype))</div>"
    end
end

# ============================================================
# JS — buildCsv (raw string, no Julia interpolation)
# ============================================================

const BUILD_CSV_JS = raw"""
function buildCsv() {
  if (!window._grid)     { alert('No grid loaded.'); return null; }
  if (!window._grid.jss) { alert('Grid not initialised.'); return null; }
  var gt   = window._grid.type;
  var data = window._grid.jss.getData();

  if (gt === 'scalar') {
    var csv = window._grid.rowName + ',' + window._grid.colNames[0] + '\n';
    csv += data[0].join(',') + '\n';
    return csv;
  }

  if (gt === 'vector') {
    var csv = window._grid.rowName + ',' + window._grid.colNames[0] + '\n';
    for (var r = 0; r < data.length; r++) {
      csv += data[r].join(',') + '\n';
    }
    return csv;
  }

  if (gt === 'matrix') {
    var csv = window._grid.rowName + '/' + window._grid.colGroup + ',' + window._grid.colNames.join(',') + '\n';
    for (var r = 0; r < data.length; r++) {
      csv += data[r].join(',') + '\n';
    }
    return csv;
  }

  if (gt === 'fixed_col') {
    var csv = window._grid.rowName + ',' + window._grid.colNames.join(',') + '\n';
    for (var r = 0; r < data.length; r++) {
      csv += data[r].join(',') + '\n';
    }
    return csv;
  }

  if (gt === 'select_ultimate') {
    var csv = window._grid.rowName + ',' + window._grid.colNames.join(',') + '\n';
    for (var r = 0; r < data.length; r++) {
      csv += data[r].join(',') + '\n';
    }
    return csv;
  }

  if (gt === 'mapping') {
    var csv = window._grid.rowName + ',' + window._grid.colNames.join(',') + '\n';
    for (var r = 0; r < data.length; r++) {
      csv += data[r].join(',') + '\n';
    }
    return csv;
  }

  if (gt === 'mapping_ID') {
    if (!window._grid.valid) {
      alert('Look up table names first — every ID must match a SOA table.');
      return null;
    }
    var csv = window._grid.rowName + ',' + window._grid.colNames.join(',') + '\n';
    //add " " to Table name column as it may contain ","
    var data1 = data.map(row => {
      row[2] = '"' + String(row[2]) + '"'; 
      return row;
    })
    for (var r = 0; r < data1.length; r++) {
      csv += data1[r].join(',') + '\n';
    }
    return csv;
  }

  if (gt === 'user_defined') {
    var hdrs = window._grid.jss.getHeaders ? window._grid.jss.getHeaders().split(',') : window._grid.colNames;
    var csv  = window._grid.rowName + ',' + hdrs.slice(1).join(',') + '\n';
    for (var r = 0; r < data.length; r++) {
      var rowIdx = data[r][0];
      if (rowIdx === '') continue;
     csv += rowIdx + ',' + data[r].slice(1).join(',') + '\n';
    }
    return csv;
  }

  return null;
}
"""

# ============================================================
# HTML Builders — right panel and full page
# ============================================================

function section_panel(;
        cat::String         = "",
        cat_label::String   = "",
        active_tab::String  = "list",
        sel_table::String   = "",
        sel_type::String    = "",
        grid_html::String   = "",
        listings::Dict{String,Any},
        notice::String      = "",
        notice_type::String = "success")::String

    notice_html = isempty(notice) ? "" :
        "<div class=\"tlm-notice tlm-notice--$(he(notice_type))\">$(he(notice))</div>"

    if isempty(cat)
        return "<div class='ts-placeholder'>Select a category from the left.</div>"
    end

    # List Tables tab
    tbls = tables_for_cat(listings, cat)
    table_rows = if isempty(tbls)
        "<tr><td colspan='3' class='ts-empty'>No tables found for this category.</td></tr>"
    else
        join([begin
            lst    = get_table_info(listings, t)
            ttype  = he(get(lst, "Table Type", ""))
            tfile  = he(get(lst, "Table Filename", ""))
            active = t == sel_table ? " ts-trow--active" : ""
            """<tr class='ts-trow$(active)'>
              <td class='ts-tcell ts-tcell--name'>
                <a href='#' class='ts-tlink'
                   onclick='loadTable(\"$(he(t))\"); return false;'>$(he(t))</a>
              </td>
              <td class='ts-tcell'>$(ttype)</td>
              <td class='ts-tcell ts-tcell--file'>$(tfile)</td>
            </tr>"""
        end for t in tbls], "\n")
    end

    list_content = """
<table class='ts-table'>
  <thead><tr>
    <th class='ts-th'>Table</th>
    <th class='ts-th'>Type</th>
    <th class='ts-th'>File</th>
  </tr></thead>
  <tbody>$(table_rows)</tbody>
</table>"""

    # Editor tab
    valid_types = types_for_cat(cat)
    type_opts   = "<option value=''>-- Select type --</option>" *
        join(["<option value='$(he(t))' $(t==sel_type ? "selected" : "")>$(he(t))</option>"
              for t in valid_types], "")

    tname_field_html = if isempty(sel_table)
        """<div class='tlm-field-group'>
          <label class='tlm-label'>Table Name</label>
          <input type='text' id='tbl-name' class='tlm-input'
                 style='max-width:180px' value=''
                 placeholder='Enter table name'>
        </div>"""
    else
        "<input type='hidden' id='tbl-name' value='$(he(sel_table))'>"
    end

    type_field_html = if !isempty(sel_table)
        """<div class='tlm-field-group'>
          <label class='tlm-label'>Table Type</label>
          <div class='gs-hint' style='font-family:var(--tlm-mono);font-size:0.82rem;
               color:var(--tlm-text);padding:0.38rem 0'>$(he(sel_type))</div>
          <input type='hidden' id='tbl-type' value='$(he(sel_type))'>
        </div>"""
    else
        """<div class='tlm-field-group'>
          <label class='tlm-label'>Table Type</label>
          <select id='tbl-type' class='tlm-input' style='max-width:360px'
                  onchange='onTypeChange()'>$(type_opts)</select>
        </div>"""
    end

    grid_inner = isempty(grid_html) ?
        "<div class='ts-placeholder'>Select a table type above to load the grid.</div>" :
        grid_html

    editor_content = """
<div class='ts-edit-form'>
  <div class='ts-edit-row'>
    $(tname_field_html)
    $(type_field_html)
  </div>
  $(notice_html)
  <div id='tbl-grid'>$(grid_inner)</div>
  <div class='ts-tbl-actions' id='tbl-actions'
       style='$(isempty(grid_html) ? "display:none" : "")'>
    <button class='btn-primary' onclick='saveTable()'>&#x1F4BE; Save</button>
    $(isempty(sel_table) ? "" :
      "<button class='btn-ghost' onclick='saveAsTable()'>&#x1F4BE; Save As</button>")
    $(isempty(sel_table) ? "" :
      "<button class='btn-danger' onclick='deleteTable(\"$(he(sel_table))\")'>&#x1F5D1; Delete</button>")
  </div>
</div>"""

    list_active   = active_tab == "list"   ? "ts-tab--active" : ""
    editor_active = active_tab == "editor" ? "ts-tab--active" : ""

    editor_tab_html = if active_tab != "editor"
        ""
    else
        tab_label = isempty(sel_table) ? "New Table" : he(sel_table)
        "<button id='tab-btn-editor' class='ts-tab $(editor_active)' " *
        "onclick='switchTab(\"editor\")'>$(tab_label)</button>"
    end

    """<div class='ts-panel-header'>
  <h2 class='ts-panel-title'>$(he(cat_label))</h2>
</div>
<div class='ts-tabs'>
  <button id='tab-btn-list' class='ts-tab $(list_active)'
          onclick='switchTab(\"list\")'>List Tables</button>
  $(editor_tab_html)
  <button class='ts-tab ts-tab--add' onclick='newTable()'>+ Add New</button>
</div>
<div id='tab-list' class='ts-tab-content' style='$(active_tab=="list" ? "" : "display:none")'>
  $(list_content)
</div>
<div id='tab-editor' class='ts-tab-content' style='$(active_tab=="editor" ? "" : "display:none")'>
  $(editor_content)
</div>"""
end

function render_page(;
        cat::String         = "",
        cat_label::String   = "",
        active_tab::String  = "list",
        sel_table::String   = "",
        sel_type::String    = "",
        grid_html::String   = "",
        listings::Dict{String,Any},
        notice::String      = "",
        notice_type::String = "success")

    panel = section_panel(; cat, cat_label, active_tab, sel_table, sel_type,
                          grid_html, listings, notice, notice_type)

    sidebar_html = join([begin
        group_label, items = grp
        items_html = join([begin
            lbl, key = item
            active = key == cat ? " ts-nav-item--active" : ""
            "<li class='ts-nav-item$(active)'>" *
            "<a href='#' class='ts-nav-link' " *
            "onclick='selectCat(\"$(he(key))\",\"$(he(lbl))\"); return false;'>$(he(lbl))</a></li>"
        end for item in items], "\n")
        """<div class='ts-nav-group'>
  <div class='ts-nav-group-label'>$(he(group_label))</div>
  <ul class='ts-nav-list'>$(items_html)</ul>
</div>"""
    end for grp in SECTIONS], "\n")

    page = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>TradLifeModel - Table Setup</title>
  <link rel="stylesheet" href="/css/base.css">
  <link rel="stylesheet" href="/css/table_setup.css">
  <link rel="stylesheet" href="/css/jspreadsheet.min.css">
  <link rel="stylesheet" href="/css/jsuites.min.css">
  <script src="/js/jsuites.min.js"></script>
  <script src="/js/index.min.js"></script>
</head>
<body>

<header class="tlm-header">
  <a href="/" class="tlm-logo" style="text-decoration:none;color:inherit;">TradLifeModel</a>
  <div class="tlm-badge">TABLE SETUP</div>
</header>

<div class="tlm-app">

  <nav class="tlm-sidenav">
    <div class="tlm-sidenav-label">Navigation</div>
    <a href="/table-setup" class="active">Table Setup</a>
    <a href="/product-setup">Product Setup</a>
    <a href="/run-settings">Run Settings</a>
    <a href="/general-settings">General Settings</a>
    <a href="/run-monitor">Run Monitor</a>
    <hr style="border:none;border-top:1px solid var(--tlm-border);margin:0.5rem 0">
    $(sidebar_html)
  </nav>

  <main class="tlm-page-main" id="ts-main">
    $(panel)
  </main>

</div>

<form id="ts-form" method="POST" action="/table-setup" style="display:none">
  <input type="hidden" id="f-action"        name="tlm_action">
  <input type="hidden" id="f-cat"           name="cat">
  <input type="hidden" id="f-cat-label"     name="cat_label">
  <input type="hidden" id="f-tname"         name="tname">
  <input type="hidden" id="f-ttype"         name="ttype">
  <input type="hidden" id="f-csvdata"       name="csvdata">
  <input type="hidden" id="f-sel-table"     name="sel_table">
  <input type="hidden" id="f-max-issue-age" name="max_issue_age">
  <input type="hidden" id="f-max-duration"  name="select_duration">
</form>

<script>
var _currentCat      = "$(he(cat))";
var _currentCatLabel = "$(he(cat_label))";
var _currentSelTable = "$(he(sel_table))";
var _currentSelType  = "$(he(sel_type))";
var _existingTables  = $(JSON3.write(sort(collect(keys(listings)))));

function postForm(action, tname, ttype, csvdata, maxAge, maxDur) {
  document.getElementById('f-action').value        = action;
  document.getElementById('f-cat').value           = _currentCat;
  document.getElementById('f-cat-label').value     = _currentCatLabel;
  document.getElementById('f-tname').value         = tname;
  document.getElementById('f-ttype').value         = ttype;
  document.getElementById('f-csvdata').value       = csvdata;
  document.getElementById('f-sel-table').value     = _currentSelTable;
  document.getElementById('f-max-issue-age').value = maxAge;
  document.getElementById('f-max-duration').value  = maxDur;
  document.getElementById('ts-form').submit();
}

function selectCat(cat, catLabel) {
  _currentCat      = cat;
  _currentCatLabel = catLabel;
  postForm('select_cat', '', '', '', '', '');
}

function loadTable(tname) {
  postForm('load', tname, '', '', '', '');
}

function switchTab(tab) {
  document.getElementById('tab-list').style.display   = tab === 'list'   ? '' : 'none';
  document.getElementById('tab-editor').style.display = tab === 'editor' ? '' : 'none';
  document.getElementById('tab-btn-list').classList[tab === 'list' ? 'add' : 'remove']('ts-tab--active');
  var editorBtn = document.getElementById('tab-btn-editor');
  if (editorBtn) editorBtn.classList[tab === 'editor' ? 'add' : 'remove']('ts-tab--active');
}

function newTable() {
  if (!_currentCat) { alert('Please select a category first.'); return; }
  postForm('new', '', '', '', '', '');
}

function onTypeChange() {
  var ttype = document.getElementById('tbl-type').value;
  if (!ttype) return;
  postForm('type_change', '', ttype, '', '', '');
}

function applySuInput() {
  if (_currentSelTable) return;
  var maxAge = document.getElementById('su-max-age').value;
  var maxDur = document.getElementById('su-max-duration').value;
  if (!maxAge || !maxDur) { alert('Please enter both Max Issue Age and Max Duration.'); return; }
  postForm('apply_su', '', _currentSelType, '', maxAge, maxDur);
}

function onCalYearChange() {
  if (!window._grid || !window._grid.jss) return;
  var start = parseInt(document.getElementById('cal-start-year').value) || 2024;
  var data  = window._grid.jss.getData();
  for (var r = 0; r < data.length; r++)
    window._grid.jss.setValueFromCoords(0, r, String(start + r), true);
}

function saveTable() {
  var tname = document.getElementById('tbl-name').value.trim().toUpperCase();
  document.getElementById('tbl-name').value = tname;
  var ttype = document.getElementById('tbl-type').value;
  if (!tname) { alert('Please enter a table name.'); return; }
  if (!ttype) { alert('Please select a table type.'); return; }
  if (!_currentSelTable && _existingTables.map(function(t) { return t.toUpperCase(); }).indexOf(tname) !== -1) {
    alert("Table '" + tname + "' already exists. Please choose a different name.");
    return;
  }
  var csv = buildCsv();
  if (csv === null) return;
  document.getElementById('f-action').value        = 'save';
  document.getElementById('f-cat').value           = _currentCat;
  document.getElementById('f-cat-label').value     = _currentCatLabel;
  document.getElementById('f-tname').value         = tname;
  document.getElementById('f-ttype').value         = ttype;
  document.getElementById('f-csvdata').value       = csv;
  document.getElementById('f-sel-table').value     = _currentSelTable;
  document.getElementById('f-max-issue-age').value = (window._grid && window._grid.maxIssueAge != null) ? window._grid.maxIssueAge : '';
  document.getElementById('f-max-duration').value  = (window._grid && window._grid.maxDuration  != null) ? window._grid.maxDuration  : '';
  document.getElementById('ts-form').submit();
}

function saveAsTable() {
  var newName = prompt('Save as new table name:');
  if (!newName || !newName.trim()) return;
  newName = newName.trim().toUpperCase();
  var existingUpper = _existingTables.map(function(t) { return t.toUpperCase(); });
  while (existingUpper.indexOf(newName) !== -1) {
    newName = prompt("Table '" + newName + "' already exists. Please choose a different name:");
    if (!newName || !newName.trim()) return;
    newName = newName.trim().toUpperCase();
  }
  var csv = buildCsv();
  if (csv === null) return;
  document.getElementById('f-action').value        = 'save';
  document.getElementById('f-cat').value           = _currentCat;
  document.getElementById('f-cat-label').value     = _currentCatLabel;
  document.getElementById('f-tname').value         = newName;
  document.getElementById('f-ttype').value         = _currentSelType;
  document.getElementById('f-csvdata').value       = csv;
  document.getElementById('f-sel-table').value     = '';
  document.getElementById('f-max-issue-age').value = (window._grid && window._grid.maxIssueAge != null) ? window._grid.maxIssueAge : '';
  document.getElementById('f-max-duration').value  = (window._grid && window._grid.maxDuration  != null) ? window._grid.maxDuration  : '';
  document.getElementById('ts-form').submit();
}

function deleteTable(tname) {
  if (!confirm('Delete table ' + tname + '? This cannot be undone.')) return;
  postForm('delete', tname, '', '', '', '');
}

$(BUILD_CSV_JS)
</script>

</body>
</html>"""

    return html(page)
end

# ============================================================
# Routes
# ============================================================

function register_routes()

    route("/table-setup", method=GET) do
        render_page(; listings=load_json(LISTINGS_PATH))
    end

    route("/table-setup", method=POST) do
        params    = Genie.Router.params()
        listings  = load_json(LISTINGS_PATH)
        action    = string(get(params, :tlm_action, ""))
        cat       = string(get(params, :cat, ""))
        cat_label = string(get(params, :cat_label, ""))
        @info "POST /table-setup" action=action cat=cat

        if action == "select_cat"
            return render_page(; cat, cat_label, active_tab="list", listings)

        elseif action == "load"
            tname = string(get(params, :tname, ""))
            lst   = get_table_info(listings, tname)
            ttype = string(get(lst, "Table Type", ""))
            fname = string(get(lst, "Table Filename", tname * ".csv"))
            grid  = isempty(ttype) ? "" :
                    grid_for_type(ttype, fname, cat; sel_table=tname, listings)
            return render_page(; cat, cat_label, active_tab="editor",
                sel_table=tname, sel_type=ttype, grid_html=grid, listings)

        elseif action == "new"
            return render_page(; cat, cat_label, active_tab="editor", listings)

        elseif action == "type_change"
            ttype = string(get(params, :ttype, ""))
            grid  = isempty(ttype) ? "" :
                    grid_for_type(ttype, "", cat; sel_table="", listings)
            return render_page(; cat, cat_label, active_tab="editor",
                sel_type=ttype, grid_html=grid, listings)

        elseif action == "apply_su"
            ttype           = string(get(params, :ttype, ""))
            max_issue_age   = si(get(params, :max_issue_age,   "119"), 119)
            select_duration = si(get(params, :select_duration, "120"), 120)
            grid = grid_for_type(ttype, "", cat; max_issue_age, select_duration,
                                 sel_table="", listings)
            return render_page(; cat, cat_label, active_tab="editor",
                sel_type=ttype, grid_html=grid, listings)

        elseif action == "save"
            tname           = string(strip(get(params, :tname, "")))
            ttype           = string(get(params, :ttype, ""))
            csvdata         = string(get(params, :csvdata, ""))
            max_issue_age   = si(get(params, :max_issue_age,   "119"), 119)
            select_duration = si(get(params, :select_duration, "120"), 120)

            isempty(tname) && return render_page(; cat, cat_label,
                active_tab="editor", listings,
                notice="Please enter a table name.", notice_type="error")
            isempty(csvdata) && return render_page(; cat, cat_label,
                active_tab="editor", listings,
                notice="No data received — please try again.", notice_type="error")

            lst      = get_table_info(listings, tname)
            filename = isempty(lst) ? tname * ".csv" :
                       string(get(lst, "Table Filename", tname * ".csv"))

            try
                save_table_to_csv(filename, csvdata)
                upsert_table_to_listing(tname, cat, ttype, filename)
            catch err
                return render_page(; cat, cat_label, active_tab="editor",
                    sel_table=tname, sel_type=ttype, listings,
                    notice="Save failed: $err", notice_type="error")
            end

            listings = load_json(LISTINGS_PATH)
            lst2     = get_table_info(listings, tname)
            fname    = isempty(lst2) ? filename :
                       string(get(lst2, "Table Filename", filename))
            grid     = grid_for_type(ttype, fname, cat;
                           max_issue_age, select_duration, sel_table=tname, listings)
            return render_page(; cat, cat_label, active_tab="editor",
                sel_table=tname, sel_type=ttype, grid_html=grid, listings,
                notice="Saved to $(joinpath(TABLES_DIR, filename))",
                notice_type="success")

        elseif action == "delete"
            tname = string(get(params, :tname, ""))
            lst   = get_table_info(listings, tname)
            fname = string(get(lst, "Table Filename", tname * ".csv"))
            path  = joinpath(TABLES_DIR, fname)
            isfile(path) && rm(path)
            delete_table_from_listing(tname)
            return render_page(; cat, cat_label, active_tab="list",
                listings=load_json(LISTINGS_PATH),
                notice="Deleted $tname", notice_type="success")
        end

        render_page(; listings)
    end

    route("/api/mort_lookup", method=GET) do
        params = string(get(Genie.Router.params(), :ids, ""))
        out    = Dict{String,String}()
        for s in split(params, ",")
            id = tryparse(Int, strip(s))
            id === nothing && continue
            out[string(id)] = something(lookup_soa_table_name(id), "")
        end
        json(out)
    end

end

end # module

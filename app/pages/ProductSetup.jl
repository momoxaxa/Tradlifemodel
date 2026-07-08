module ProductSetup

using Genie, Genie.Router, Genie.Renderer.Html
using HTTP: escapehtml
using JSON3

# ============================================================
# Constants — paths, sections definition, field-category map
# ============================================================

const INPUT_PATH    = joinpath(dirname(dirname(dirname(@__FILE__))), "Input")
const PRODUCTS_DIR  = joinpath(INPUT_PATH, "Products")
const LISTINGS_PATH = joinpath(INPUT_PATH, "table_listings.json")

# Each section (e.g. Product Feature): (json_key, display_label, rows)
# Each row (e.g. premium): (field_key, display_label, has_pad, has_table_col, has_udf)
const SECTIONS = [
    ("Product Feature", "Product Features", [
        ("premium",    "Premium",           false, false, true),
        ("death_ben",  "Death Benefit",     false, false, true),
        ("surr_ben",   "Surrender Benefit", false, false, true),
        ("commission", "Commission",        false, false, true),
    ]),
    ("Base Projection", "Base Projection", [
        ("mortality",   "Mortality",   false, false, false),
        ("lapse",       "Lapse",       false, false, false),
        ("expense",     "Expense",     false, false, false),
        ("disc_rate",   "Disc Rate",   false, true,  false),
        ("invt_return", "Invt Return", false, true,  false),
        ("prem_tax",    "Prem Tax",    false, false, false),
        ("tax",         "Tax",         false, false, false),
    ]),
    ("Valuation", "Valuation", [
        ("mortality", "Mortality", true,  false, false),
        ("lapse",     "Lapse",     true,  false, false),
        ("expense",   "Expense",   true,  false, false),
        ("disc_rate", "Disc Rate", true,  true,  false),
        ("prem_tax",  "Prem Tax",  false, false, false),
    ]),
    ("Capital Requirement", "Capital Requirement", [
        ("mortality", "Mortality", true,  false, false),
        ("lapse",     "Lapse",     true,  false, false),
        ("expense",   "Expense",   true,  false, false),
        ("disc_rate", "Disc Rate", true,  true,  false),
        ("prem_tax",  "Prem Tax",  false, false, false),
    ]),
]

# Category for each field
const FIELD_CAT = Dict(
    "premium"     => "premium",
    "death_ben"   => "death_ben",
    "surr_ben"    => "surr_ben",
    "commission"  => "commission",
    "mortality"   => "mortality",
    "lapse"       => "lapse",
    "expense"     => "expense",
    "disc_rate"   => "disc_rate",
    "invt_return" => "disc_rate",
    "prem_tax"    => "prem_tax",
    "tax"         => "tax",
)

# ============================================================
# Helpers — JSON I/O, product list, table lookups
# ============================================================

# Load JSON file into Dict
function load_json(path::String)::Dict{String,Any}
    JSON3.read(read(path, String), Dict{String,Any})
end

# Escape HTML special characters to prevent XSS
he(s) = escapehtml(string(s))

# Load listing of all existing tables
function load_listings()::Dict{String,Any}
    load_json(LISTINGS_PATH)
end

# List all tables for a category
function tables_for_cat(listings::Dict{String,Any}, cat::String)::Vector{String}
    sort([string(k) for (k,v) in listings
          if string(get(v, "Table Category", "")) == cat])
end

# Get table type for a selected table
function table_type_for(listings::Dict{String,Any}, tname::String)::String
    haskey(listings, tname) || return ""
    string(get(listings[tname], "Table Type", ""))
end

# List all existing products
function list_products()::Vector{String}
    sort([replace(f, ".json" => "") for f in readdir(PRODUCTS_DIR) if endswith(f, ".json")])
end

# Load selected product to Dict
function load_product(name::String)::Dict{String,Any}
    load_json(joinpath(PRODUCTS_DIR, name * ".json"))
end

# Save product to JSON
function save_product(name::String, data::Dict{String,Any})
    path = joinpath(PRODUCTS_DIR, name * ".json")
    tmp  = path * ".tmp"
    open(tmp, "w") do io
        JSON3.pretty(io, data)
    end
    mv(tmp, path, force=true)
end

# Delete selected product
function delete_product(name::String)
    path = joinpath(PRODUCTS_DIR, name * ".json")
    isfile(path) && rm(path)
end

# ============================================================
# HTML Builders — dropdowns, section rows, type map JS
# ============================================================

# Table dropdown for a field
function table_dropdown(id::String, listings::Dict{String,Any},
                        cat::String, selected::String)::String
    tbls = tables_for_cat(listings, cat)
    opts = "<option value=''>-- None --</option>" *
           join(["<option value='$(he(t))' $(t==selected ? "selected" : "")>$(he(t))</option>"
                 for t in tbls], "")
    "<select id='$(he(id))' name='$(he(id))' class='ps-select' " *
    "onchange=\"updateType('$(he(id))')\">" * opts * "</select>"
end

# Table column dropdown for disc_rate and invt_return fields
function table_col_dropdown(id::String, val::String)::String
    opts = "<option value=''>-- None --</option>" *
           join(["<option value='$(he(t))' $(t==val ? "selected" : "")>$(he(t))</option>"
                 for t in ["investment_return", "disc_rate", "valn_int_rate"]], "")
    "<select id='$(he(id))' name='$(he(id))' class='ps-select'>" * opts * "</select>"
end

# Section HTML (e.g. Product Feature) with fields (e.g. Premium)
function section_html(sec_key::String, sec_label::String,
                      rows::Vector, prod_data::Dict{String,Any},
                      listings::Dict{String,Any})::String
    sec_data = get(prod_data, sec_key, Dict{String,Any}())

    rows_html = join([begin
        fkey, flabel, has_pad, has_table_col, has_udf = row
        fdata = get(sec_data, fkey, Dict{String,Any}())

        sel_table = string(get(fdata, "Table",        ""))
        mult_val  = string(get(fdata, "Mult",          1))
        pad_val   = string(get(fdata, "PAD",           0))
        tcol_val  = string(get(fdata, "Table Column", ""))
        udf_val   = string(get(fdata, "UDF",          ""))
        ttype_val = string(get(fdata, "Table Type",   ""))

        cat      = get(FIELD_CAT, fkey, "")
        table_id = "$(sec_key)__$(fkey)__table"
        type_id  = "$(sec_key)__$(fkey)__type"
        mult_id  = "$(sec_key)__$(fkey)__mult"
        pad_id   = "$(sec_key)__$(fkey)__pad"
        tcol_id  = "$(sec_key)__$(fkey)__tablecol"
        udf_id   = "$(sec_key)__$(fkey)__udf"

        table_html = table_dropdown(table_id, listings, cat, sel_table)
        type_html  = "<span class='ps-type-display' id='$(he(type_id))'>$(he(ttype_val))</span>"
        mult_html  = "<input type='number' id='$(he(mult_id))' name='$(he(mult_id))' " *
                     "class='ps-input ps-input--sm' step='any' value='$(he(mult_val))' placeholder='Mult'>"
        pad_html   = has_pad ?
                     "<input type='number' id='$(he(pad_id))' name='$(he(pad_id))' " *
                     "class='ps-input ps-input--sm' step='any' value='$(he(pad_val))' placeholder='PAD'>" : ""
        tcol_html  = has_table_col ? table_col_dropdown(tcol_id, tcol_val) : ""
        udf_html   = has_udf ?
                     "<input type='text' id='$(he(udf_id))' name='$(he(udf_id))' " *
                     "class='ps-input ps-input--md' value='$(he(udf_val))' placeholder='UDF'>" : ""

        """<tr class='ps-row'>
          <td class='ps-cell ps-cell--label'>$(he(flabel))</td>
          <td class='ps-cell'>$(table_html)</td>
          <td class='ps-cell ps-cell--type'>$(type_html)</td>
          <td class='ps-cell'>$(mult_html)</td>
          $(has_pad       ? "<td class='ps-cell'>$(pad_html)</td>"  : "<td class='ps-cell'></td>")
          $(has_table_col ? "<td class='ps-cell'>$(tcol_html)</td>" : "<td class='ps-cell'></td>")
          $(has_udf       ? "<td class='ps-cell'>$(udf_html)</td>"  : "<td class='ps-cell'></td>")
        </tr>"""
    end for row in rows], "\n")

    # Column headers vary by section
    theader_PAD, theader_TCOL, theader_UDF =
        if sec_key == "Product Feature"
            ("", "", "UDF")
        elseif sec_key == "Base Projection"
            ("", "Table Column", "")
        else
            ("PAD", "Table Column", "")
        end

    """<div class='ps-section'>
  <div class='ps-section-header' onclick='toggleSection(this)'>
    <span class='ps-section-arrow'>&#x25BC;</span>
    <span class='ps-section-title'>$(he(sec_label))</span>
  </div>
  <div class='ps-section-body'>
    <table class='ps-table'>
      <thead><tr>
        <th class='ps-th ps-th--label'>Assumption</th>
        <th class='ps-th'>Table</th>
        <th class='ps-th ps-th--type'>Table Type</th>
        <th class='ps-th ps-th--sm'>Mult</th>
        <th class='ps-th ps-th--sm'>$(theader_PAD)</th>
        <th class='ps-th'>$(theader_TCOL)</th>
        <th class='ps-th'>$(theader_UDF)</th>
      </tr></thead>
      <tbody>$(rows_html)</tbody>
    </table>
  </div>
</div>"""
end

# Table type lookup JS object (e.g. {"MORT01": "Attained Age", "EXP01": "Policy Year"})
function build_type_map_js(listings::Dict{String,Any})::String
    entries = join(["\"$(he(string(t)))\": \"$(he(table_type_for(listings, string(t))))\""
                    for t in keys(listings)], ",\n")
    "var _typeMap = {$entries};"
end

# ============================================================
# HTML Builder — render page
# ============================================================

function render_page(;
        sel_product::String         = "",
        prod_data::Dict{String,Any} = Dict{String,Any}(),
        listings::Dict{String,Any},
        notice::String              = "",
        notice_type::String         = "success",
        show_form::Bool             = false)

    products    = list_products()
    notice_html = isempty(notice) ? "" :
        "<div class=\"tlm-notice tlm-notice--$(he(notice_type))\">$(he(notice))</div>"

    # Left panel product list
    prod_items = join([begin
        active = p == sel_product ? " ps-prod--active" : ""
        "<li class='ps-prod-item$(active)'>" *
        "<a href='#' class='ps-prod-link' " *
        "onclick='loadProduct(\"$(he(p))\");return false;'>$(he(p))</a></li>"
    end for p in products], "\n")

    # Right panel — form or placeholder
    panel = if !show_form && isempty(sel_product) && isempty(prod_data)
        "$(notice_html)<div class='ps-placeholder'>Select a product from the left, or click + Add New.</div>"
    else
        is_new  = isempty(sel_product)
        pname   = is_new ? "" : sel_product
        ro_attr = is_new ? "" : "readonly style='opacity:0.6'"

        sections_html = join([section_html(sec_key, sec_label, rows, prod_data, listings)
                              for (sec_key, sec_label, rows) in SECTIONS], "\n")

        """<div class='ps-form-header'>
  <div class='ps-name-wrap'>
    <label class='tlm-label'>Product Name</label>
    <input type='text' id='prod-name' class='tlm-input' style='max-width:200px'
           value='$(he(pname))' placeholder='e.g. Prod01' $(ro_attr)>
  </div>
  <div class='ps-form-actions'>
    <button class='btn-primary' onclick='saveProduct()'>&#x1F4BE; Save</button>
    $(is_new ? "" :
      "<button class='btn-ghost' onclick='saveAsProduct()'>&#x1F4BE; Save As</button>")
    $(is_new ? "" :
      "<button class='btn-danger' onclick='deleteProduct(\"$(he(sel_product))\")'>&#x1F5D1; Delete</button>")
  </div>
</div>
$(notice_html)
<div class='ps-sections'>
  $(sections_html)
</div>"""
    end

    type_map_js = build_type_map_js(listings)

    page = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>TradLifeModel - Product Setup</title>
  <link rel="stylesheet" href="/css/base.css">
  <link rel="stylesheet" href="/css/product_setup.css">
</head>
<body>

<header class="tlm-header">
  <a href="/" class="tlm-logo" style="text-decoration:none;color:inherit;">TradLifeModel</a>
  <div class="tlm-badge">PRODUCT SETUP</div>
</header>

<div class="tlm-app">

  <nav class="tlm-sidenav">
    <div class="tlm-sidenav-label">Navigation</div>
    <a href="/table-setup">Table Setup</a>
    <a href="/product-setup" class="active">Product Setup</a>
    <a href="/model-point">Model Point</a>
    <a href="/run-settings">Run Settings</a>
    <a href="/general-settings">General Settings</a>
    <a href="/run-monitor">Run Monitor</a>
    <a href="/run-result">Run Result</a>
    <hr style="border:none;border-top:1px solid var(--tlm-border);margin:0.5rem 0">
    <div class="tlm-sidenav-label">Products</div>
    <button class='ps-add-btn' onclick='newProduct()'>+ Add New</button>
    <ul class='ps-prod-list'>$(prod_items)</ul>
  </nav>

  <main class="tlm-page-main">
    $(panel)
  </main>

</div>

<!-- Hidden POST form -->
<form id='ps-form' method='POST' action='/product-setup' style='display:none'>
  <input type='hidden' id='f-action'   name='tlm_action'>
  <input type='hidden' id='f-prodname' name='prod_name'>
  <input type='hidden' id='f-payload'  name='payload'>
</form>

<script>
$(type_map_js)

var _existingProducts = $(JSON3.write(list_products()));

function updateType(dropId) {
  var sel    = document.getElementById(dropId);
  var typeId = dropId.replace('__table', '__type');
  var typeEl = document.getElementById(typeId);
  if (typeEl && sel) { typeEl.textContent = _typeMap[sel.value] || ''; }
}

function toggleSection(hdr) {
  var body  = hdr.nextElementSibling;
  var arrow = hdr.querySelector('.ps-section-arrow');
  var open  = body.style.display !== 'none';
  body.style.display = open ? 'none' : '';
  arrow.innerHTML    = open ? '&#x25BA;' : '&#x25BC;';
}

function loadProduct(name)    { post('load',   name, ''); }
function newProduct()         { post('new',    '',   ''); }
function deleteProduct(name) {
  if (!confirm('Delete product ' + name + '? This cannot be undone.')) return;
  post('delete', name, '');
}

function collectProductData() {
  var data     = {};
  var sections = $(JSON3.write([sec_key for (sec_key,_,_) in SECTIONS]));
  sections.forEach(function(secKey) {
    data[secKey] = {};
    var prefix = secKey + '__';
    document.querySelectorAll('[id^="' + prefix + '"]').forEach(function(el) {
      if (el.tagName !== 'INPUT' && el.tagName !== 'SELECT') return;
      var parts = el.id.split('__');
      if (parts.length < 3) return;
      var fieldKey  = parts[1];
      var fieldType = parts[2];
      if (!data[secKey][fieldKey]) data[secKey][fieldKey] = {};
      var val = el.tagName === 'SELECT' ? el.value : el.value.trim();
      if (fieldType === 'table') {
        data[secKey][fieldKey]['Table'] = val;
        var typeEl = document.getElementById(secKey + '__' + fieldKey + '__type');
        data[secKey][fieldKey]['Table Type'] = typeEl ? typeEl.textContent : '';
      } else if (fieldType === 'mult') {
        data[secKey][fieldKey]['Mult'] = val === '' ? '' : parseFloat(val);
      } else if (fieldType === 'pad') {
        data[secKey][fieldKey]['PAD'] = val === '' ? '' : parseFloat(val);
      } else if (fieldType === 'tablecol') {
        data[secKey][fieldKey]['Table Column'] = val;
      } else if (fieldType === 'udf') {
        data[secKey][fieldKey]['UDF'] = val;
      }
    });
  });
  return data;
}

function saveProduct() {
  var name = document.getElementById('prod-name').value.trim().toUpperCase();
  document.getElementById('prod-name').value = name;
  if (!name) { alert('Please enter a product name.'); return; }
  // For new products, disallow existing names (case-insensitive)
  if (!"$(he(sel_product))" && _existingProducts.map(function(p) { return p.toUpperCase(); }).indexOf(name) !== -1) {
    alert("Product '" + name + "' already exists. Please choose a different name.");
    return;
  }
  post('save', name, JSON.stringify(collectProductData()));
}

function saveAsProduct() {
  var newName = prompt('Save as new product name:');
  if (!newName || !newName.trim()) return;
  newName = newName.trim().toUpperCase();
  var existingUpper = _existingProducts.map(function(p) { return p.toUpperCase(); });
  // Keep prompting until a unique name is given
  while (existingUpper.indexOf(newName) !== -1) {
    newName = prompt("Product '" + newName + "' already exists. Please choose a different name:");
    if (!newName || !newName.trim()) return;
    newName = newName.trim().toUpperCase();
  }
  post('save', newName, JSON.stringify(collectProductData()));
}

function post(action, prodName, payload) {
  document.getElementById('f-action').value   = action;
  document.getElementById('f-prodname').value = prodName;
  document.getElementById('f-payload').value  = payload;
  document.getElementById('ps-form').submit();
}
</script>

</body>
</html>"""

    return html(page)
end

# ============================================================
# Routes
# ============================================================

function register_routes()

    route("/product-setup", method=GET) do
        render_page(; listings=load_listings())
    end

    route("/product-setup", method=POST) do
        params   = Genie.Router.params()
        listings = load_listings()
        action   = get(params, :tlm_action, "")

        if action == "load"
            name = get(params, :prod_name, "")
            data = load_product(name)
            return render_page(; sel_product=name, prod_data=data, listings)

        elseif action == "new"
            return render_page(; show_form=true, listings)

        elseif action == "save"
            name    = string(strip(get(params, :prod_name, "")))
            payload = get(params, :payload, "")

            isempty(name) && return render_page(;
                show_form=true, listings,
                notice="Please enter a product name.", notice_type="error")

            isempty(payload) && return render_page(;
                sel_product=name, listings,
                notice="No data received.", notice_type="error")

            try
                data = JSON3.read(payload, Dict{String,Any})
                save_product(name, data)
                return render_page(; sel_product=name, prod_data=data, listings,
                    notice="Saved to $(joinpath(PRODUCTS_DIR, name*".json"))",
                    notice_type="success")
            catch err
                @error "Save failed" err=err
                return render_page(; sel_product=name, listings,
                    notice="Save failed: $err", notice_type="error")
            end

        elseif action == "delete"
            name = get(params, :prod_name, "")
            try
                delete_product(name)
                return render_page(; listings,
                    notice="Deleted $(joinpath(PRODUCTS_DIR, name*".json"))",
                    notice_type="success")
            catch err
                @error "Delete failed" err=err
                return render_page(; sel_product=name, listings,
                    notice="Delete failed: $err", notice_type="error")
            end
        end

        render_page(; listings)
    end

end

end # module

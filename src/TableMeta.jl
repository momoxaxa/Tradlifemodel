#=
table_filepath(tables_dir::AbstractString, name::AbstractString)
read_table_meta(filepath::AbstractString)::Dict{String,Any} - called by TableSetup.jl
table_meta_header(meta::AbstractDict)::String
write_table_csv(filepath::AbstractString, meta::AbstractDict, csvdata::AbstractString) - called by TableSetup.jl
scan_table_listings(tables_dir::AbstractString; valid_defn=nothing)::Dict{String,Any} - called by Settings.jl, TableSetup.jl, ProductSetup.jl
=#

# TableMeta.jl — self-describing table CSVs
#
# Each table CSV in Input/Tables carries its own metadata as leading comment
# lines, e.g.:
#
#   #Table Type: Attained Age
#   #Table Category: mortality
#   #Table Details: Attained Age Unisex Mortality Table
#   Age,Unisex
#   0,0.003107
#   ...
#
# The Tables folder itself is the registry: the table name is the filename
# without .csv, and the filepath is derived — never stored (see table_filepath).
#
# Data readers must skip the header, e.g. CSV.read(path, DataFrame; comment="#").
# This file is include()'d by both the model (Settings.jl) and the web app
# (TableSetup.jl / ProductSetup.jl).
# Reader and writer live together so the header format has one definition:
# whatever write_table_csv emits, read_table_meta must parse.

const TABLE_META_KEYS = ("Table Type", "Table Category", "Table Details")

# Table file path
table_filepath(tables_dir::AbstractString, name::AbstractString) = joinpath(tables_dir, name * ".csv")

# Parse leading '#Key: Value' lines from a table CSV. Stops at first non-# line.
function read_table_meta(filepath::AbstractString)::Dict{String,Any}
    meta = Dict{String,Any}()
    open(filepath, "r") do io
        for line in eachline(io)
            startswith(line, "#") || break
            m = match(r"^#\s*([^:]+):\s*(.*)$", line)
            m === nothing && continue
            meta[strip(m.captures[1])] = strip(m.captures[2])
        end
    end
    return meta
end

# Render metadata as the comment header block
function table_meta_header(meta::AbstractDict)::String
    join(["#$k: $(get(meta, k, ""))" for k in TABLE_META_KEYS], "\n") * "\n"
end

# Write a table CSV: metadata header followed by the csv data.
function write_table_csv(filepath::AbstractString, meta::AbstractDict, csvdata::AbstractString)
    tmp = filepath * ".tmp"
    open(tmp, "w") do io
        write(io, table_meta_header(meta))
        write(io, csvdata)
    end
    mv(tmp, filepath, force=true)
end

# Scan a Tables directory and build the listing:
# Dict(table_name => Dict("Table Type"=>..., "Table Category"=>..., "Table Details"=>...))
#
# A CSV is EXCLUDED from the listing (with a warning) when:
#   - it has no / empty #Table Type or #Table Category header lines, or
#   - valid_defn is supplied and its Category is not defined, or its Type is
#     not defined within that Category (pair check).
# valid_defn is the parsed table_type_defn.json: Dict(category => Dict(type => ...)).
# Excluded tables are invisible to both the app and the model; CSVs edited
# outside the UI must exactly match the values used in Table Setup.
function scan_table_listings(tables_dir::AbstractString; valid_defn=nothing)::Dict{String,Any}
    listings = Dict{String,Any}()
    isdir(tables_dir) || return listings
    for file in readdir(tables_dir)
        endswith(lowercase(file), ".csv") || continue
        name = replace(file, r"\.csv$"i => "")
        meta = read_table_meta(joinpath(tables_dir, file))
        ttype = string(get(meta, "Table Type", ""))
        tcat  = string(get(meta, "Table Category", ""))
        if isempty(ttype) || isempty(tcat)
            @warn "Table CSV is missing #Table Type or #Table Category metadata; EXCLUDED from table listing." file
            continue
        end
        if valid_defn !== nothing
            if !haskey(valid_defn, tcat)
                @warn "Table CSV EXCLUDED: unknown Table Category '$tcat'." file
                continue
            elseif !haskey(valid_defn[tcat], ttype)
                @warn "Table CSV EXCLUDED: Table Type '$ttype' is not defined for category '$tcat'." file
                continue
            end
        end
        listings[name] = meta
    end
    return listings
end

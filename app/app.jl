# app.jl

using Genie

include("pages/ProductSetup.jl")
# include("pages/TableSetup.jl")
include("pages/GeneralSettings.jl")
include("pages/RunSettings.jl")

using .ProductSetup
# using .TableSetup
using .GeneralSettings
using .RunSettings

ProductSetup.register_routes()
# TableSetup.register_routes()
GeneralSettings.register_routes()
RunSettings.register_routes()

# Redirect root to general settings
route("/") do
    return Genie.Renderer.redirect("/general-settings")
end

Genie.Server.up(8888, "0.0.0.0", async=false)

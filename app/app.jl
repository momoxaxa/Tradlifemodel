# app.jl

using Genie, Genie.Renderer.Html

include("pages/Index.jl")
include("pages/TableSetup.jl")
include("pages/ProductSetup.jl")
include("pages/ModelPoint.jl")
include("pages/RunSettings.jl")
include("pages/GeneralSettings.jl")
include("pages/RunMonitor.jl")
include("pages/RunResult.jl")

using .Index
using .TableSetup
using .ProductSetup
using .ModelPoint
using .RunSettings
using .GeneralSettings
using .RunMonitor
using .RunResult

Index.register_routes()
TableSetup.register_routes()
ProductSetup.register_routes()
ModelPoint.register_routes()
RunSettings.register_routes()
GeneralSettings.register_routes()
RunMonitor.register_routes()
RunResult.register_routes()

Genie.Server.up(8888, "0.0.0.0", async=false)

module RunMonitor

using Genie, Genie.Router, Genie.Renderer.Html, Genie.Renderer.Json

# ============================================================
# Constants & State — paths, log file, job tracker
# ============================================================

current_job = nothing

const GENIE_APP    = dirname(dirname(@__FILE__))
const PROJECT_DIR  = dirname(GENIE_APP)
const MODEL_SCRIPT = joinpath(PROJECT_DIR, "src", "tradlifemodel.jl")
const LOG_FILE     = joinpath(GENIE_APP, "run-monitor.log")

# Initialise log file
isfile(LOG_FILE) && rm(LOG_FILE)

# ============================================================
# HTML Builder
# ============================================================

function render_page()
    html("""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>TradLifeModel — Run Monitor</title>
  <link rel="stylesheet" href="/css/base.css">
  <link rel="stylesheet" href="/css/run_monitor.css">
</head>
<body>

<header class="tlm-header">
  <a href="/" class="tlm-logo" style="text-decoration:none;color:inherit;">TradLifeModel</a>
  <div class="tlm-badge">RUN MONITOR</div>
</header>

<div class="tlm-app">

  <nav class="tlm-sidenav">
    <div class="tlm-sidenav-label">Navigation</div>
    <a href="/table-setup">Table Setup</a>
    <a href="/product-setup">Product Setup</a>
    <a href="/run-settings">Run Settings</a>
    <a href="/general-settings">General Settings</a>
    <a href="/run-monitor" class="active">Run Monitor</a>
  </nav>

  <main class="tlm-page-main">
    <div class="tlm-card">
      <div class="rm-panel">
        <div class="tlm-actions">
          <button id="btn-run-model" class="btn-primary">Run Model</button>
        </div>
        <div id="job-status" class="rm-status">No status yet</div>
        <pre id="job-log" class="rm-log"></pre>
      </div>
    </div>
  </main>

</div>

<script>
var pollTimer = null;

// Fetch and display the latest log content
function fetchLog() {
  fetch('/run-monitor/log')
    .then(function(resp) { return resp.json(); })
    .then(function(data) {
      var logEl = document.getElementById('job-log');
      logEl.textContent = data.log;
      logEl.scrollTop   = logEl.scrollHeight;
    })
    .catch(function() {});
}

// Apply CSS class to status element based on current status
function applyStatusClass(status) {
  var el = document.getElementById('job-status');
  el.className = 'rm-status' +
    (status === 'running'   ? ' rm-status--running'   :
     status === 'completed' ? ' rm-status--completed' :
     status === 'failed'    ? ' rm-status--failed'    : '');
}

// Poll job status and update UI accordingly
function fetchStatus() {
  fetch('/run-monitor/job-status')
    .then(function(resp) { return resp.json(); })
    .then(function(data) {
      var msg = data.status + (data.message ? ': ' + data.message : '');
      document.getElementById('job-status').textContent = msg;
      applyStatusClass(data.status);
      document.getElementById('btn-run-model').disabled = (data.status === 'running');
      fetchLog();
      if (data.status === 'running') {
        pollTimer = setTimeout(fetchStatus, 1000);
      } else if (pollTimer) {
        clearTimeout(pollTimer);
        pollTimer = null;
      }
    })
    .catch(function() {
      document.getElementById('job-status').textContent = 'Error fetching status';
    });
}

// Start model run on button click
document.getElementById('btn-run-model').onclick = function() {
  document.getElementById('btn-run-model').disabled = true;
  fetch('/run-monitor', { method: 'POST' })
    .then(function(resp) { return resp.json(); })
    .then(function(data) {
      document.getElementById('job-status').textContent = data.status;
      fetchStatus();
    })
    .catch(function() {
      document.getElementById('job-status').textContent = 'Error starting run';
      document.getElementById('btn-run-model').disabled = false;
    });
};

// On page load, fetch current status (handles browser reload during a run)
fetchStatus();
</script>

</body>
</html>""")
end

# ============================================================
# Routes — page, run trigger, log polling, job status
# ============================================================

function register_routes()

    route("/run-monitor", method=GET) do
        render_page()
    end

    route("/run-monitor", method=POST) do
        global current_job
        current_job = Threads.@spawn begin
            open(LOG_FILE, "w") do io
                try
                    run(pipeline(`julia --project=$PROJECT_DIR $MODEL_SCRIPT`,
                                 stdout=io, stderr=io))
                catch e
                    @error "Model run failed" exception=(e, catch_backtrace())
                    println(io, "\n--- Model run failed ---")
                    println(io, sprint(showerror, e, catch_backtrace()))
                    rethrow(e)
                end
            end
        end
        return json(Dict("status" => "started"))
    end

    route("/run-monitor/log", method=GET) do
        text = isfile(LOG_FILE) ? read(LOG_FILE, String) : ""
        return json(Dict("log" => text))
    end

    route("/run-monitor/job-status", method=GET) do
        global current_job
        if current_job === nothing
            return json(Dict("status" => "idle", "message" => "No job has been started yet."))
        elseif !istaskdone(current_job)
            return json(Dict("status" => "running"))
        elseif istaskfailed(current_job)
            return json(Dict("status" => "failed"))
        else
            return json(Dict("status" => "completed"))
        end
    end

end

end # module

module Index

using Genie, Genie.Router, Genie.Renderer.Html

function render_page()
    html("""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>TradLifeModel</title>
  <link rel="stylesheet" href="/css/base.css">
  <link rel="stylesheet" href="/css/index.css">
</head>
<body>

<header class="tlm-header">
  <div class="tlm-logo">TradLifeModel</div>
</header>

<div class="index-wrap">
  <div class="index-card">
    <div class="index-title">Actuarial Modelling Tool for Traditional Life Insurance Products</div>
    <ol class="index-steps">
      <li>
        <span class="index-step-num">1</span>
        <div><a href="/table-setup">Table Setup</a>
          <span>— load product features and assumption tables (premium, mortality, etc.)</span></div>
      </li>
      <li>
        <span class="index-step-num">2</span>
        <div><a href="/product-setup">Product Setup</a>
          <span>— configure product feature and assumptions</span></div>
      </li>
      <li>
        <span class="index-step-num">3</span>
        <div><a href="/model-point">Model Point</a>
          <span>— view model point files for each product</span></div>
      </li>
      <li>
        <span class="index-step-num">4</span>
        <div><a href="/run-settings">Run Settings</a>
          <span>— define runs and assumption multipliers</span></div>
      </li>
      <li>
        <span class="index-step-num">5</span>
        <div><a href="/general-settings">General Settings</a>
          <span>— set valuation date, projection year, multithreading, etc</span></div>
      </li>
      <li>
        <span class="index-step-num">6</span>
        <div><a href="/run-monitor">Run Monitor</a>
          <span>— start the model and monitor progress</span></div>
      </li>
      <li>
        <span class="index-step-num">7</span>
        <div><a href="/run-result">Run Result</a>
          <span>— view result files for each run</span></div>
      </li>
    </ol>
    <a href="/table-setup" class="btn-primary" style="display:inline-block;text-decoration:none">
      Get Started
    </a>
  </div>
</div>

</body>
</html>""")
end

function register_routes()
    route("/") do
        render_page()
    end
end

end # module

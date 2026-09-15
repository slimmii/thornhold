// Injected only by the LAN server for ?diagnostics=1; nothing goes off this host.
(() => {
  let count = 0;
  function report(kind, value) {
    if (++count > 100) return;
    const message = JSON.stringify({ seconds: +(performance.now() / 1000).toFixed(2), kind, value: String(value).slice(0, 5000) });
    navigator.sendBeacon('/__startup_diagnostics', new Blob([message], {type: 'text/plain'}));
  }
  for (const name of ['log', 'warn', 'error']) {
    const original = console[name].bind(console);
    console[name] = (...args) => {
      report(name, args.map(String).join(' '));
      original(...args);
    };
  }
  window.addEventListener('error', e => report('uncaught', e.message || 'Resource failed: ' + e.target?.src), true);
  window.addEventListener('unhandledrejection', e => report('rejection', e.reason));
  document.getElementById('canvas').addEventListener('webglcontextlost', () => report('graphics', 'WebGL context lost'));
  const observer = new PerformanceObserver(list => {
    for (const entry of list.getEntries()) {
      if (/index\.(wasm|pck|js)$/.test(new URL(entry.name).pathname)) {
        report('download', `${new URL(entry.name).pathname}: ${entry.duration.toFixed(0)} ms, ${entry.decodedBodySize} bytes`);
      }
    }
  });
  observer.observe({type: 'resource', buffered: true});
  report('browser', navigator.userAgent + '; secure=' + isSecureContext);
  let ticks = 0;
  const timer = setInterval(() => {
    report('heartbeat', document.getElementById('status') ? 'Godot loader still visible' : 'Godot loader removed');
    if (++ticks >= 12) clearInterval(timer);
  }, 5000);
})();

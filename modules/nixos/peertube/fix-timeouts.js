// Node.js --require preload: bump headersTimeout to match requestTimeout.
//
// PeerTube sets server.requestTimeout from its config (e.g. 2 hours) but never adjusts
// headersTimeout, which defaults to 60s. A slow upload, such as a large transcoded file from a
// remote runner, can hit that timeout before its headers finish arriving and draw a spurious 408.
(() => {
  'use strict';

  const http = require('http');
  const originalListen = http.Server.prototype.listen;

  http.Server.prototype.listen = function (...args) {
    if (this.requestTimeout > 0 && this.headersTimeout < this.requestTimeout) {
      this.headersTimeout = this.requestTimeout + 60000;
    }
    return originalListen.apply(this, args);
  };
})();

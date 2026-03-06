// Node.js --require preload: bump headersTimeout to match requestTimeout.
//
// PeerTube sets server.requestTimeout from its config (e.g. 2 hours) but
// never adjusts headersTimeout, which defaults to 60s. For slow uploads
// (large transcoded files from remote runners), the 60s headersTimeout
// can fire before headers finish arriving, producing spurious 408s.
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

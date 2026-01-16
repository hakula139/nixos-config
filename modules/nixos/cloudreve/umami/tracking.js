// Cloudreve returns signed download URLs via /api/v4/file/url. We intercept that response and label
// each returned URL with a logical path so the Cloudflare Worker can log accurate per-file metrics.
(() => {
  'use strict';

  // Cloudflare Worker host for B2 downloads - will be substituted by Nix
  const WORKER_HOST = '__WORKER_HOST__';
  // Cloudreve API endpoint for signed download URLs
  const FILE_URL_API = '/api/v4/file/url';

  const getPathname = (url) => {
    try {
      return new URL(url, window.location.href).pathname;
    } catch (error) {
      console.warn('Failed to get pathname from URL:', url, error);
      return null;
    }
  };

  // Convert Cloudreve's custom URI (e.g. cloudreve://token@share/<encoded_path>) into a clean path
  // like "/My Folder/File.ext" used for attribution.
  const extractLogicalPath = (uri) => {
    try {
      const url = new URL(uri);
      const path = decodeURIComponent(url.pathname);
      return path.startsWith('/') ? path : `/${path}`;
    } catch (error) {
      console.warn('Failed to extract logical path from URI:', uri, error);
      return null;
    }
  };

  // Only append logical_path when the download URL points to our Worker host.
  const appendLogicalPath = (downloadUrl, logicalPath) => {
    if (!downloadUrl || !logicalPath) {
      return downloadUrl;
    }

    try {
      const url = new URL(downloadUrl);
      if (url.hostname !== WORKER_HOST) {
        return downloadUrl;
      }

      url.searchParams.set('logical_path', logicalPath);
      return url.toString();
    } catch (error) {
      console.warn(
        'Failed to append logical path to download URL:',
        downloadUrl,
        logicalPath,
        error,
      );
      return null;
    }
  };

  // Hook XMLHttpRequest to intercept Cloudreve's /api/v4/file/url requests.
  const OriginalXHR = window.XMLHttpRequest;
  const originalOpen = OriginalXHR.prototype.open;
  const originalSend = OriginalXHR.prototype.send;

  OriginalXHR.prototype.open = function (_method, url) {
    this._cloudreve_url = url;
    return originalOpen.apply(this, arguments);
  };

  OriginalXHR.prototype.send = function (body) {
    const isFileUrlApi = getPathname(this._cloudreve_url) === FILE_URL_API;

    if (isFileUrlApi && typeof body === 'string') {
      try {
        const parsed = JSON.parse(body);
        if (Array.isArray(parsed?.uris)) {
          this._cloudreve_uris = parsed.uris;
        }
      } catch (error) {
        console.warn('Failed to parse JSON body for file URL API:', body, error);
      }
    }

    if (isFileUrlApi && this._cloudreve_uris) {
      this.addEventListener('load', () => {
        try {
          const json =
            typeof this.response === 'object' && this.response !== null
              ? this.response
              : JSON.parse(this.responseText);

          if (!Array.isArray(json?.data?.urls)) {
            console.warn('Invalid response for file URL API:', json);
            return;
          }

          // Patch each download URL in the response with its corresponding logical path.
          let changed = false;
          json.data.urls.forEach((item, index) => {
            if (!item?.url || !this._cloudreve_uris[index]) {
              console.warn('Invalid item for file URL API:', item, this._cloudreve_uris[index]);
              return;
            }

            const logicalPath = extractLogicalPath(this._cloudreve_uris[index]);
            if (!logicalPath) {
              console.warn('Failed to extract logical path from URI:', this._cloudreve_uris[index]);
              return;
            }

            const newUrl = appendLogicalPath(item.url, logicalPath);
            if (newUrl !== item.url) {
              console.debug('Patched URL:', item.url, '->', newUrl);
              item.url = newUrl;
              changed = true;
            }
          });

          // Return a patched response by overriding the response / responseText getters.
          if (changed) {
            Object.defineProperty(this, 'response', {
              configurable: true,
              get: () => json,
            });

            const patchedText = JSON.stringify(json);
            Object.defineProperty(this, 'responseText', {
              configurable: true,
              get: () => patchedText,
            });
          }
        } catch (error) {
          console.warn('Failed to patch response for file URL API:', error);
        }
      });
    }

    return originalSend.apply(this, arguments);
  };
})();

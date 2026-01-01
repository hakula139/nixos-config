// Cloudreve returns signed download URLs via /api/v4/file/url. We intercept that response and label
// each returned URL with a logical path so the Cloudflare Worker can log accurate per-file metrics.
(() => {
  'use strict';

  const WORKER_HOST = '__WORKER_HOST__'; // Cloudflare Worker host for B2 downloads
  const FILE_URL_API = '/api/v4/file/url'; // Cloudreve API endpoint for signed download URLs

  // Convert Cloudreve's custom URI (e.g. cloudreve://token@share/<encoded_path>) into a clean path
  // like "/My Folder/File.ext" used for attribution.
  const extractLogicalPath = (uri) => {
    try {
      const url = new URL(uri);
      const path = decodeURIComponent(url.pathname);
      return path.startsWith('/') ? path : `/${path}`;
    } catch {
      console.warn('Failed to extract logical path from URI:', uri);
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

      const separator = downloadUrl.includes('?') ? '&' : '?';
      return `${downloadUrl}${separator}logical_path=${encodeURIComponent(logicalPath)}`;
    } catch {
      console.warn('Failed to append logical path to download URL:', downloadUrl);
      return downloadUrl;
    }
  };

  const originalFetch = window.fetch;
  // Hook fetch to patch the JSON response from /api/v4/file/url before Cloudreve consumes it.
  window.fetch = function (input, init) {
    const requestUrl =
      typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
    const pathname = new URL(requestUrl, window.location.href).pathname;
    const isFileUrlApi = pathname === FILE_URL_API;

    let requestBody = null;
    if (isFileUrlApi && init?.body) {
      try {
        requestBody = JSON.parse(init.body);
      } catch {
        console.warn('Failed to parse request body:', init.body);
      }
    }

    return originalFetch.apply(this, arguments).then(async (response) => {
      if (!requestBody?.uris) {
        return response;
      }

      const { uris } = requestBody;

      try {
        const data = await response.clone().json();
        if (!Array.isArray(data?.data)) {
          return response;
        }

        data.data.forEach((item, index) => {
          if (!item.url) {
            return;
          }

          const logicalPath = uris[index] ? extractLogicalPath(uris[index]) : null;
          if (!logicalPath) {
            return;
          }

          item.url = appendLogicalPath(item.url, logicalPath);
        });

        return new Response(JSON.stringify(data), {
          status: response.status,
          statusText: response.statusText,
          headers: response.headers,
        });
      } catch {
        console.warn('Failed to append logical path to download URLs');
        return response;
      }
    });
  };
})();

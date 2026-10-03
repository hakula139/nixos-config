(function () {
  'use strict';

  angular.module('ariaNg').config([
    '$provide',
    'ariaNgDefaultOptions',
    function ($provide, defaults) {
      var settings = {
        theme: 'system',
        rpcHost: window.location.hostname,
        rpcPort: window.location.port,
        rpcInterface: 'jsonrpc',
        protocol: 'http',
        httpMethod: 'POST',
        rpcRequestHeaders: '',
        secret: '',
      };

      angular.extend(defaults, settings);

      $provide.decorator('ariaNgStorageService', [
        '$delegate',
        'ariaNgConstants',
        function (storage, constants) {
          var get = storage.get;
          var initialized = false;

          storage.get = function (key) {
            var value = get.call(storage, key);

            if (key === constants.optionStorageKey && !initialized) {
              initialized = true;

              if (value) {
                value = angular.extend({}, value, settings);
                storage.set(key, value);
              }
            }

            return value;
          };

          return storage;
        },
      ]);
    },
  ]);
})();

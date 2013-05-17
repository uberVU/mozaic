;(function() {

	var config = {
		paths: App.main_modules,
		text: {
			// ==========================================================//
			//   Cross Origin Requests trouble for Handlebars templates  //
			// ========================================================= //
			//
			// DON'T MODIFY THIS UNLESS YOU REALLY REALLY KNOW WHAT YOU'RE DOING.
			//
			// http://stackoverflow.com/questions/10607370/require-js-text-plugin-adds-js-to-the-file-name
			// https://groups.google.com/group/requirejs/browse_thread/thread/bc0608ef5f8943e7
			useXhr: function (url, protocol, hostname, port) {
				return true;
			}
		},
		// Need a large timeout for IE + phantom.js
		waitSeconds: 300
	}

	require.config(config);
})();

require(['cs'], function() {
	require([App.general.ENTRY_POINT]);
});
/**
 * @license cs 0.4.3 Copyright (c) 2010-2011, The Dojo Foundation All Rights Reserved.
 * Available via the MIT or new BSD license.
 * see: http://github.com/jrburke/require-cs for details
 */

/*jslint */
/*global define, window, XMLHttpRequest, importScripts, Packages, java,
  ActiveXObject, process, require */

define(['coffee-script'], function (CoffeeScript) {
    'use strict';
    var fs, getXhr,
        progIds = ['Msxml2.XMLHTTP', 'Microsoft.XMLHTTP', 'Msxml2.XMLHTTP.4.0'],
        fetchText = function () {
            throw new Error('Environment unsupported.');
        },
        buildMap = {};

    if (typeof process !== "undefined" &&
               process.versions &&
               !!process.versions.node) {
        //Using special require.nodeRequire, something added by r.js.
        fs = require.nodeRequire('fs');
        fetchText = function (path, callback) {
            callback(fs.readFileSync(path, 'utf8'));
        };
    } else if ((typeof window !== "undefined" && window.navigator && window.document) || typeof importScripts !== "undefined") {
        // Browser action
        getXhr = function () {
            //Would love to dump the ActiveX crap in here. Need IE 6 to die first.
            var xhr, i, progId;
            if (typeof XMLHttpRequest !== "undefined") {
                return new XMLHttpRequest();
            } else {
                for (i = 0; i < 3; i += 1) {
                    progId = progIds[i];
                    try {
                        xhr = new ActiveXObject(progId);
                    } catch (e) {}

                    if (xhr) {
                        progIds = [progId];  // so faster next time
                        break;
                    }
                }
            }

            if (!xhr) {
                throw new Error("getXhr(): XMLHttpRequest not available");
            }

            return xhr;
        };

        fetchText = function (url, callback) {
            var xhr = getXhr();
            xhr.open('GET', url, true);
            xhr.onreadystatechange = function (evt) {
                //Do not explicitly handle errors, those should be
                //visible via console output in the browser.
                if (xhr.readyState === 4) {
                    callback(xhr.responseText);
                }
            };
            xhr.send(null);
        };
        // end browser.js adapters
    } else if (typeof Packages !== 'undefined') {
        //Why Java, why is this so awkward?
        fetchText = function (path, callback) {
            var stringBuffer, line,
                encoding = "utf-8",
                file = new java.io.File(path),
                lineSeparator = java.lang.System.getProperty("line.separator"),
                input = new java.io.BufferedReader(new java.io.InputStreamReader(new java.io.FileInputStream(file), encoding)),
                content = '';
            try {
                stringBuffer = new java.lang.StringBuffer();
                line = input.readLine();

                // Byte Order Mark (BOM) - The Unicode Standard, version 3.0, page 324
                // http://www.unicode.org/faq/utf_bom.html

                // Note that when we use utf-8, the BOM should appear as "EF BB BF", but it doesn't due to this bug in the JDK:
                // http://bugs.sun.com/bugdatabase/view_bug.do?bug_id=4508058
                if (line && line.length() && line.charAt(0) === 0xfeff) {
                    // Eat the BOM, since we've already found the encoding on this file,
                    // and we plan to concatenating this buffer with others; the BOM should
                    // only appear at the top of a file.
                    line = line.substring(1);
                }

                stringBuffer.append(line);

                while ((line = input.readLine()) !== null) {
                    stringBuffer.append(lineSeparator);
                    stringBuffer.append(line);
                }
                //Make sure we return a JavaScript string and not a Java string.
                content = String(stringBuffer.toString()); //String
            } finally {
                input.close();
            }
            callback(content);
        };
    }

    return {
        fetchText: fetchText,

        get: function () {
            return CoffeeScript;
        },

        write: function (pluginName, name, write) {
            if (buildMap.hasOwnProperty(name)) {
                var text = buildMap[name];
                write.asModule(pluginName + "!" + name, text);
            }
        },

        version: '0.4.3',

        load: function (name, parentRequire, load, config) {
            var path = parentRequire.toUrl(name + '.coffee');
            fetchText(path, function (text) {
                if (path.indexOf('./') !== -1) {
                    path = path.slice(1);
                }
                var compiled;

                //Do CoffeeScript transform.
                try {
                    compiled = CoffeeScript.compile(text, {
                        sourceMap: true,
                        inline: true,
                        sourceFiles: [path],
                        generatedFile: path.replace('.coffee', '.js')
                    });
                } catch (err) {
                    err.message = "In " + path + ", " + err.message;
                    throw err;
                }

                /*
                  Source map looks like:
                  {
                    "version": 3,
                    "file": "some/file.js",
                    "sourceRoot": "",
                    "sources": ["some/file.coffee"],
                    "names": [],
                    "mappings": "(as expected)",
                    "sourcesContent": ["(original source string)"]
                  }

                  Then we set the eval to:

                    (javascript source)
                    //@ sourceMappingURL=data:application/json;base64,(sourceMap)
                    //@ sourceURL=some/file.js

                  Thus the attempt is to use "some/file.js" as the file the "eval" script comes from,
                  while source mapping that back to the original coffeescript.
                */

                //Add in the source map
                if (window.btoa) {
                    try {
                        var sourceMap = btoa(compiled.v3SourceMap);
                    } catch (e) {
                        // silence base64 errors
                    }
                }
                text = compiled.js + '\n//@ sourceURL=' + path.replace('.coffee', '.js');

                if (sourceMap) {
                    text += '\n//@ sourceMappingURL=data:application/json;base64,' + btoa(compiled.v3SourceMap);
                }

                //Hold on to the transformed text if a build.
                if (config.isBuild) {
                    buildMap[name] = text;
                }

                load.fromText(name, text);

                //Give result to load. Need to wait until the module
                //is fully parse, which will happen after this
                //execution.
                parentRequire([name], function (value) {
                    load(value);
                });
            });
        }
    };
});

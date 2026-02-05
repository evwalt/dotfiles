// ==UserScript==
// @name         New Userscript
// @namespace    http://tampermonkey.net/
// @version      2026-02-05
// @description  try to take over the world!
// @author       You
// @match        https://*/*
// @icon         data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==
// @grant        none
// ==/UserScript==

(function() {
    'use strict';
    // Your code here...
    // ==UserScript==
// @name         Disable ChatGPT Esc
// @match        https://chatgpt.com*
// @grant        none
// ==/UserScript==

window.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        e.stopPropagation();
    }
}, true);
})();
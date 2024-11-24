/**
 * Useful Links
 *
 */
// https://github.com/brookhong/Surfingkeys/wiki

/**
 * Modified Keybindings
 */
api.unmap(';dh');
api.unmap(';t');
api.map('gH', 'H');
api.unmap('H');
api.map('H', 'S');
api.map('L', 'D');

/**
 * Examples
 */
// an example to create a new mapping `ctrl-y`
api.mapkey('<Ctrl-y>', 'Show me the money', function () {
    Front.showPopup(
        'a well-known phrase uttered by characters in the 1996 film Jerry Maguire (Escape to close).'
    );
});
// an example to replace `T` with `gt`, click `Default mappings` to see how `T` works.
// api.map('gt', 'T');
// an example to remove mapkey `Ctrl-i`
// api.unmap('<Ctrl-i>');

/**
 * Theme
 */
settings.theme = `
.sk_theme {
    font-family: Input Sans Condensed, Charcoal, sans-serif;
    font-size: 10pt;
    background: #24272e;
    color: #abb2bf;
}
.sk_theme tbody {
    color: #fff;
}
.sk_theme input {
    color: #d0d0d0;
}
.sk_theme .url {
    color: #61afef;
}
.sk_theme .annotation {
    color: #56b6c2;
}
.sk_theme .omnibar_highlight {
    color: #528bff;
}
.sk_theme .omnibar_timestamp {
    color: #e5c07b;
}
.sk_theme .omnibar_visitcount {
    color: #98c379;
}
.sk_theme #sk_omnibarSearchResult ul li:nth-child(odd) {
    background: #303030;
}
.sk_theme #sk_omnibarSearchResult ul li.focused {
    background: #3e4452;
}
#sk_status, #sk_find {
    font-size: 20pt;
}
:root {
    --theme-ace-bg:#282828ab; /*Note the fourth channel, this adds transparency*/
    --theme-ace-bg-accent:#3c3836;
    --theme-ace-fg:#ebdbb2;
    --theme-ace-fg-accent:#7c6f64;
    --theme-ace-cursor:#928374;
    --theme-ace-select:#458588;
}
#sk_editor {
    height: 50% !important; /*Remove this to restore the default editor size*/
    background: var(--theme-ace-bg) !important;
}
.ace-chrome .ace_print-margin, .ace_gutter, .ace_gutter-cell, .ace_dialog{
    background: var(--theme-ace-bg-accent) !important;
}
.ace_dialog-bottom{
    border-top: 1px solid var(--theme-ace-bg) !important;
}
.ace-chrome{
    color: var(--theme-ace-fg) !important;
}
.ace_gutter, .ace_dialog {
    color: var(--theme-ace-fg-accent) !important;
}
.ace_cursor{
    color: var(--theme-ace-cursor) !important;
}
.normal-mode .ace_cursor{
    background-color: var(--theme-ace-cursor) !important;
    border: var(--theme-ace-cursor) !important;
}
.ace_marker-layer .ace_selection {
    background: var(--theme-ace-select) !important;
}`;
// click `Save` button to make above settings to take effect.</Ctrl-i></Ctrl-y>

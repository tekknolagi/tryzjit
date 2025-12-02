import Yace from "./vendor/yace/yace.js";
import tab from "./vendor/yace/plugins/tab.js";
import history from "./vendor/yace/plugins/history.js";
import cutLine from "./vendor/yace/plugins/cutLine.js";
import preserveIndent from "./vendor/yace/plugins/preserveIndent.js";

import hljs from "./vendor/highlight/core.min.js";
import ruby from "./vendor/highlight/ruby.min.js";

hljs.registerLanguage("ruby", ruby);

function highlighter(value) {
    return hljs.highlight(value, { language: "ruby" }).value;
}

const plugins = [
  history(), // suuport ctrl+z ctrl+shift+z when use plugins. should be first
  tab(), // indent with two space
  cutLine(), // cmd + x for cutting line
  preserveIndent() // preserve last line indent
];

const editor = new Yace("#editor", {
    value: "# try editing...\n\ndef sum(a, b)\n    a + b\nend\n\nsum(1,2)\nsum(3,4)",
    styles: {
        fontSize: "18px",
    },
    highlighter,
    plugins,
    lineNumbers: true,
});

editor.textarea.spellcheck = false;

// Function to send code to backend
async function executeCode() {
    const code = editor.value;

    try {
        const response = await fetch('/execute', {
            method: 'POST',
            headers: {
                'Content-Type': 'text/plain',
            },
            body: code
        });

        const result = await response.json();

        console.log('Execution result:', result);

        if (result === null) {
          alert("nooo");
        }

        // Send the iongraph JSON to the iframe
        const iframe = document.querySelector('.right-panel iframe');
        if (iframe && iframe.contentWindow && result.msg) {
            try {
                const ionjson = JSON.parse(result.msg);
                iframe.contentWindow.postMessage({
                    type: 'iongraph-data',
                    data: ionjson
                }, '*');
            } catch (parseError) {
                console.error('Error parsing iongraph JSON:', parseError);
            }
        }

        return result;
    } catch (error) {
        console.error('Error executing code:', error);
        return null;
    }
}

window.addEventListener('DOMContentLoaded', () => {
    document.getElementById('execute-btn').addEventListener('click', executeCode);

    const divider = document.getElementById('divider');
    const leftPanel = document.getElementById('left-panel');
    const container = document.querySelector('.container');

    let isDragging = false;

    divider.addEventListener('mousedown', (e) => {
        if (e.button !== 0) return; // left mouse only
        isDragging = true;
        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none';
        e.preventDefault();
    });

    document.addEventListener('mousemove', (e) => {
        if (!isDragging) return;

        const containerRect = container.getBoundingClientRect();
        const newWidth = e.clientX - containerRect.left;

        const minWidth = 200;
        const maxWidth = containerRect.width - 200;

        const clampedWidth = Math.max(minWidth, Math.min(newWidth, maxWidth));

        leftPanel.style.flex = '0 0 auto';
        leftPanel.style.width = clampedWidth + 'px';
    });

    function stopDragging() {
        if (!isDragging) return;
        isDragging = false;
        document.body.style.cursor = '';
        document.body.style.userSelect = '';
    }

    document.addEventListener('mouseup', stopDragging);
    document.addEventListener('mouseleave', stopDragging);
});

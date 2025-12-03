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

        if (result.error) {
            alert(`Error: ${result.error}`);
            return null;
        }

        const iongraphRoot = document.getElementById('iongraph-root');
        if (iongraphRoot && result.functions && result.functions.length > 0) {
            iongraphRoot.innerHTML = '';

            iongraph.renderStandaloneUI(iongraphRoot, result);
        } else if (!result.functions || result.functions.length === 0) {
            alert("No functions compiled to iongraph");
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

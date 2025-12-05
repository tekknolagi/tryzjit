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
  history(), // support ctrl+z ctrl+shift+z
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

        const iongraphRoot = document.getElementById('iongraph-root');

        if (result.error) {
            if (result.diagnostics) {
                iongraphRoot.innerHTML = `
                    <div style="padding: 20px; color: #721c24; background-color: #f8d7da; border: 1px solid #f5c6cb; border-radius: 4px; margin: 20px; font-family: monospace; white-space: pre-wrap; overflow: auto; height: calc(100% - 40px);">
                        <strong>Compilation Error:</strong>\n\n${result.diagnostics}
                    </div>
                `;
            } else {
                alert(`Error: ${result.error}`);
            }
            return null;
        }

        if (iongraphRoot && result.functions && result.functions.length > 0) {
            // Force a complete re-mount by creating a new container
            iongraphRoot.innerHTML = '';
            const newContainer = document.createElement('div');
            newContainer.style.width = '100%';
            newContainer.style.height = '100%';
            newContainer.style.position = 'absolute';
            iongraphRoot.appendChild(newContainer);

            iongraph.renderStandaloneUI(newContainer, result);
        } else if (!result.functions || result.functions.length === 0) {
            iongraphRoot.innerHTML = `
                <div style="padding: 20px; color: #856404; background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px; margin: 20px;">
                    <strong>No functions compiled to iongraph</strong><br><br>
                    The code executed successfully but didn't generate any JIT compilations. Try adding a function that gets called multiple times.
                </div>
            `;
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

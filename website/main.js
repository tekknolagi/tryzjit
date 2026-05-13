import Yace from "./vendor/yace.min.js";
import tab from "./vendor/tab.js";

const DEBOUNCE_TIMEOUT_MS = 500;
const STORAGE_KEY = "iongraph-saved-code";
const DEFAULT_TEXT = `def one
  1
end

def two
  2
end

def test
  one + two
end

30.times do
  test
end
`;

function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
}

function loadCode() {
  const urlParams = new URLSearchParams(window.location.search);
  const codeFromUrl = urlParams.get("code");

  if (codeFromUrl) {
    try {
      return atob(codeFromUrl);
    } catch (e) {
      console.error("Failed to decode base64 code from URL:", e);
    }
  }

  const saved = localStorage.getItem(STORAGE_KEY);
  return saved !== null ? saved : DEFAULT_TEXT;
}

function saveShareUrl(code) {
  const url = new URL(window.location.origin + window.location.pathname);
  url.searchParams.set("code", btoa(code));
  document.getElementById("share-url").value = url.toString();
}

function highlighter(value) {
  return hljs.highlight(value, { language: "ruby" }).value;
}

const editor = new Yace("#editor-yace", {
  value: loadCode(),
  styles: { fontSize: "18px" },
  highlighter,
  plugins: [tab()],
  lineNumbers: true,
});

editor.textarea.spellcheck = false;

editor.textarea.addEventListener("keydown", (e) => e.stopPropagation());

saveShareUrl(editor.value);

editor.textarea.addEventListener("input", debounce(() => {
  localStorage.setItem(STORAGE_KEY, editor.value);
  saveShareUrl(editor.value);
}, DEBOUNCE_TIMEOUT_MS));

function renderError(iongraphRoot, error) {
  iongraphRoot.innerHTML = `
    <div class="compile-fail">
      <strong>Compilation Error:</strong>\n\n${error}
    </div>
  `;
}

function renderNoFunctions(iongraphRoot) {
  iongraphRoot.innerHTML = `
    <div class="no-functions">
      <strong>No functions compiled to iongraph</strong><br><br>
      Try adding a function that gets called at least twice.
    </div>
  `;
}

async function executeCode() {
  const code = editor.value;

  try {
    const response = await fetch("/execute", {
      method: "POST",
      headers: { "Content-Type": "text/plain" },
      body: code,
    });

    const result = await response.json();
    const iongraphRoot = document.getElementById("iongraph-root");

    if (result.error) {
      renderError(iongraphRoot, result.error);
      return null;
    }

    if (result.functions && result.functions.length > 0) {
      ui.setIonJSON(result);
    } else {
      renderNoFunctions(iongraphRoot);
    }

    return result;
  } catch (error) {
    console.error("Error executing code:", error);
    return null;
  }
}

function setupResizableGutter() {
  const gutter = document.getElementById("gutter");
  const leftPanel = document.getElementById("left-panel");
  const container = document.querySelector(".container");

  let isDragging = false;
  let lastEventType = null;

  const getClientX = (e) => e.touches ? e.touches[0].clientX : e.clientX;

  const startDrag = (e) => {
    if (e.type === "mousedown" && lastEventType === "touchstart") return;
    if (e.button !== undefined && e.button !== 0) return;

    lastEventType = e.type;
    isDragging = true;
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
    e.preventDefault();
  };

  const drag = (e) => {
    if (!isDragging) return;
    if (e.type === "mousemove" && lastEventType === "touchstart") return;

    const containerRect = container.getBoundingClientRect();
    const newWidth = getClientX(e) - containerRect.left;
    const minWidth = 200;
    const maxWidth = containerRect.width - 200;
    const clampedWidth = Math.max(minWidth, Math.min(newWidth, maxWidth));

    leftPanel.style.flex = "0 0 auto";
    leftPanel.style.width = `${clampedWidth}px`;
    e.preventDefault();
  };

  const stopDragging = (e) => {
    if (!isDragging) return;
    if (e.type === "mouseup" && lastEventType === "touchstart") return;

    isDragging = false;
    document.body.style.cursor = "";
    document.body.style.userSelect = "";
  };

  gutter.addEventListener("mousedown", startDrag);
  document.addEventListener("mousemove", drag);
  document.addEventListener("mouseup", stopDragging);
  document.addEventListener("mouseleave", stopDragging);

  gutter.addEventListener("touchstart", startDrag, { passive: false });
  document.addEventListener("touchmove", drag, { passive: false });
  document.addEventListener("touchend", stopDragging);
  document.addEventListener("touchcancel", stopDragging);
}

window.addEventListener("DOMContentLoaded", () => {
  document.getElementById("execute-btn").addEventListener("click", executeCode);
  setupResizableGutter();

  const shareUrl = document.getElementById("share-url");
  shareUrl.addEventListener("click", () => shareUrl.select());
});

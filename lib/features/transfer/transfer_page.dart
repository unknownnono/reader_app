/// PC 브라우저에 보여 주는 올리기 화면.
/// 파일이나 폴더를 끌어다 놓으면 하나씩 차례로 보내고, 다 보내면 서재에 넣으라고 알린다.
const transferPageHtml = r'''<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ebook·comics viewer로 보내기</title>
<style>
  :root { color-scheme: light dark; }
  body { font-family: -apple-system, "Segoe UI", "Malgun Gothic", sans-serif; margin: 0; padding: 32px 16px; }
  main { max-width: 640px; margin: 0 auto; }
  h1 { font-size: 22px; margin: 0 0 4px; }
  p { color: #888; margin: 0 0 20px; }
  #drop { border: 2px dashed #999; border-radius: 16px; padding: 48px 16px; text-align: center; }
  #drop.over { border-color: #0a84ff; background: rgba(10, 132, 255, .08); }
  button { font: inherit; padding: 8px 16px; margin: 12px 4px 0; border-radius: 8px; border: 1px solid #999; background: transparent; color: inherit; cursor: pointer; }
  #status { margin: 20px 0 8px; font-weight: 600; }
  progress { width: 100%; height: 8px; }
  ul { list-style: none; padding: 0; margin: 12px 0 0; max-height: 40vh; overflow: auto; font-size: 13px; }
  li { padding: 3px 0; display: flex; justify-content: space-between; gap: 12px; }
  li span:first-child { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .fail { color: #ff453a; }
</style>
</head>
<body>
<main>
  <h1>ebook·comics viewer로 보내기</h1>
  <p>txt, epub, zip, cbz 파일이나 만화 그림이 든 폴더를 보낼 수 있습니다. 보내는 동안 폰의 이 화면을 닫지 마세요.</p>
  <div id="drop">
    여기에 파일이나 폴더를 끌어다 놓으세요
    <div>
      <button id="pickFiles">파일 고르기</button>
      <button id="pickFolder">폴더 고르기</button>
    </div>
  </div>
  <input id="files" type="file" multiple hidden>
  <input id="folder" type="file" webkitdirectory hidden>
  <div id="status"></div>
  <progress id="bar" value="0" max="1" hidden></progress>
  <ul id="list"></ul>
</main>
<script>
const drop = document.getElementById('drop');
const statusLine = document.getElementById('status');
const bar = document.getElementById('bar');
const list = document.getElementById('list');
let busy = false;

function addRow(name) {
  const row = document.createElement('li');
  const label = document.createElement('span');
  const state = document.createElement('span');
  label.textContent = name;
  state.textContent = '대기';
  row.append(label, state);
  list.prepend(row);
  return state;
}

// items: [{ file, path }]
async function send(items) {
  if (busy || items.length === 0) return;
  busy = true;
  bar.hidden = false;
  bar.max = items.length;
  bar.value = 0;
  let failed = 0;
  for (const [index, item] of items.entries()) {
    statusLine.textContent = `보내는 중 ${index + 1} / ${items.length}`;
    const state = addRow(item.path);
    try {
      const response = await fetch('/upload?path=' + encodeURIComponent(item.path), { method: 'POST', body: item.file });
      if (!response.ok) throw new Error(await response.text());
      state.textContent = '완료';
    } catch (error) {
      failed++;
      state.textContent = '실패';
      state.className = 'fail';
    }
    bar.value = index + 1;
  }
  try {
    const result = await (await fetch('/done', { method: 'POST' })).json();
    statusLine.textContent = `서재에 ${result.imported}권을 추가했습니다.` + (failed ? ` (실패 ${failed}개)` : '');
  } catch (error) {
    statusLine.textContent = '보내기는 끝났지만 폰의 응답이 없습니다. 폰 화면을 확인하세요.';
  }
  busy = false;
}

function fromInput(input) {
  return [...input.files].map(file => ({ file, path: file.webkitRelativePath || file.name }));
}

// 끌어다 놓은 폴더는 안쪽까지 훑어서 폴더 구조를 그대로 보낸다.
async function walk(entry, prefix, out) {
  if (entry.isFile) {
    const file = await new Promise((resolve, reject) => entry.file(resolve, reject));
    out.push({ file, path: prefix + entry.name });
  } else if (entry.isDirectory) {
    const reader = entry.createReader();
    for (;;) {
      const batch = await new Promise((resolve, reject) => reader.readEntries(resolve, reject));
      if (batch.length === 0) break;
      for (const child of batch) await walk(child, prefix + entry.name + '/', out);
    }
  }
}

document.getElementById('pickFiles').onclick = () => document.getElementById('files').click();
document.getElementById('pickFolder').onclick = () => document.getElementById('folder').click();
document.getElementById('files').onchange = event => send(fromInput(event.target));
document.getElementById('folder').onchange = event => send(fromInput(event.target));
drop.ondragover = event => { event.preventDefault(); drop.classList.add('over'); };
drop.ondragleave = () => drop.classList.remove('over');
drop.ondrop = async event => {
  event.preventDefault();
  drop.classList.remove('over');
  const entries = [...event.dataTransfer.items].map(item => item.webkitGetAsEntry()).filter(Boolean);
  const items = [];
  for (const entry of entries) await walk(entry, '', items);
  items.sort((a, b) => a.path.localeCompare(b.path, undefined, { numeric: true }));
  send(items);
};
</script>
</body>
</html>
''';

import os
import re
import json
import time
import signal
import threading
import subprocess
from flask import Flask, render_template, request, Response, jsonify

app = Flask(__name__)

PIPELINE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

_state = {
    'status':  'idle',
    'pid':     None,
    'command': '',
    'returncode': None,
}
_log_lines = []
_log_lock  = threading.Lock()
_process   = None

ANSI_RE = re.compile(r'\x1b\[[0-9;]*[mABCDEFGHJKSTfhilmnprsu]')


def strip_ansi(text: str) -> str:
    return ANSI_RE.sub('', text)


def build_command(data: dict) -> list:
    cmd = ['nextflow', 'run', 'main.nf']

    if data.get('profile'):
        cmd += ['-profile', data['profile']]

    cmd += ['-c', 'config/nextflow.config']

    if data.get('resume'):
        cmd.append('-resume')

    if data.get('sra_list'):
        cmd += ['--sra_list', data['sra_list']]
    elif data.get('reads'):
        cmd += ['--reads', data['reads']]

    if data.get('outdir'):
        cmd += ['--outdir', data['outdir']]

    if data.get('platform'):
        cmd += ['--platform', data['platform']]

    if data.get('serovar'):
        cmd += ['--serovar', data['serovar']]

    if data.get('genome_size'):
        cmd += ['--genome_size', data['genome_size']]

    for key in ('max_cpu', 'max_memory', 'max_time'):
        if data.get(key):
            cmd += [f'--{key}', str(data[key])]

    for key in ('ref_genome', 'kraken2_db', 'clair3_model',
                'bakta_db', 'plasmidfinder_db', 'snpeff_db',
                'barcode_dir', 'sample_sheet', 'illumina_reads'):
        if data.get(key):
            cmd += [f'--{key}', data[key]]

    return cmd


@app.route('/')
def index():
    return render_template('index.html', pipeline_dir=PIPELINE_DIR)


@app.route('/run', methods=['POST'])
def run_pipeline():
    global _process, _state, _log_lines

    if _state['status'] == 'running':
        return jsonify({'error': 'Pipeline is already running.'}), 400

    data = request.get_json()
    cmd  = build_command(data)

    with _log_lock:
        _log_lines = []

    _state.update({
        'status': 'running',
        'pid': None,
        'command': ' '.join(cmd),
        'returncode': None,
    })

    def _run():
        global _process, _state
        env = {**os.environ, 'NXF_ANSI_LOG': 'false', 'NXF_COLOR': '0'}
        try:
            _process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                cwd=PIPELINE_DIR,
                env=env,
            )
            _state['pid'] = _process.pid

            for raw in _process.stdout:
                line = strip_ansi(raw).rstrip('\n')
                if line:
                    with _log_lock:
                        _log_lines.append(line)

            _process.wait()
            rc = _process.returncode
            _state['returncode'] = rc
            _state['status'] = 'completed' if rc == 0 else 'failed'

        except Exception as exc:
            with _log_lock:
                _log_lines.append(f'[ERROR] {exc}')
            _state['status'] = 'failed'

    threading.Thread(target=_run, daemon=True).start()
    return jsonify({'status': 'started', 'command': ' '.join(cmd)})


@app.route('/stop', methods=['POST'])
def stop_pipeline():
    global _process, _state
    if _process and _process.poll() is None:
        try:
            _process.send_signal(signal.SIGTERM)
        except ProcessLookupError:
            pass
        _state['status'] = 'stopped'
        return jsonify({'status': 'stopped'})
    return jsonify({'status': 'not_running'})


@app.route('/status')
def get_status():
    with _log_lock:
        count = len(_log_lines)
    return jsonify({**_state, 'line_count': count})


@app.route('/logs')
def stream_logs():
    from_line = int(request.args.get('from', 0))

    def generate():
        pos = from_line
        while True:
            with _log_lock:
                batch = _log_lines[pos:]
                pos_new = pos + len(batch)
                is_done = (
                    _state['status'] in ('completed', 'failed', 'stopped')
                    and pos_new >= len(_log_lines)
                )

            for line in batch:
                yield f"data: {json.dumps({'line': line})}\n\n"

            pos = pos_new

            if is_done:
                yield f"data: {json.dumps({'done': True, 'status': _state['status']})}\n\n"
                break

            time.sleep(0.2)

    return Response(
        generate(),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'X-Accel-Buffering': 'no',
        },
    )


@app.route('/browse')
def browse():
    req_path = request.args.get('path', os.path.expanduser('~'))
    mode     = request.args.get('mode', 'dir')   # 'dir' | 'file'
    ext_arg  = request.args.get('ext', '')        # comma-separated extensions
    show_hidden = request.args.get('hidden', 'false') == 'true'

    exts = [e.strip() for e in ext_arg.split(',') if e.strip()] if ext_arg else []

    path = os.path.abspath(req_path)
    if not os.path.isdir(path):
        path = os.path.dirname(path)
    if not os.path.exists(path):
        path = os.path.expanduser('~')

    try:
        raw = os.listdir(path)
    except PermissionError:
        return jsonify({'error': 'Permission denied', 'current': path,
                        'parent': os.path.dirname(path), 'dirs': [], 'files': []}), 403

    dirs, files = [], []
    for name in sorted(raw, key=lambda s: s.lower()):
        if not show_hidden and name.startswith('.'):
            continue
        full = os.path.join(path, name)
        if os.path.isdir(full):
            dirs.append(name)
        elif mode == 'file':
            if not exts or any(name.endswith(e) for e in exts):
                files.append(name)

    parent = os.path.dirname(path) if path != os.path.sep else None

    return jsonify({
        'current': path,
        'parent':  parent,
        'dirs':    dirs,
        'files':   files,
    })


if __name__ == '__main__':
    import webbrowser
    print(f'\n  GelidonyAMR Web UI → http://127.0.0.1:5050\n')
    webbrowser.open('http://127.0.0.1:5050')
    app.run(host='0.0.0.0', port=5050, debug=False, threaded=True)

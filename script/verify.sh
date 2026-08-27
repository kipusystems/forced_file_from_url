#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "$ROOT/bin/forced_file_from_url" ]] || FAIL "bin/forced_file_from_url is not executable"

if ! git -C "$ROOT" diff --exit-code -- lib/forced_file_from_url.rb; then
  FAIL "lib/forced_file_from_url.rb must be unchanged"
fi

small="$ROOT/spec/fixtures/payloads/small.txt"
big="$ROOT/spec/fixtures/payloads/big.bin"
golden="$ROOT/spec/fixtures/text_success.txt"

small_size=$(stat -c%s "$small")
big_size=$(stat -c%s "$big")
[[ "$small_size" -eq 100 ]] || FAIL "small.txt is ${small_size} bytes, want 100"
[[ "$big_size" -eq 20000 ]] || FAIL "big.bin is ${big_size} bytes, want 20000"

port_file=$(mktemp)
work=$(mktemp -d)
got="$work/got"
mkdir -p "$got"

server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$work" "$port_file"
}
trap cleanup EXIT

ruby -e '
require "webrick"
root = ARGV[0]
port_file = ARGV[1]
server = WEBrick::HTTPServer.new(
  Port: 0,
  DocumentRoot: root,
  AccessLog: [],
  Logger: WEBrick::Log.new(File::NULL)
)
File.write(port_file, server.config[:Port].to_s)
trap("TERM") { server.shutdown }
trap("INT") { server.shutdown }
server.start
' "$ROOT/spec/fixtures/payloads" "$port_file" &
server_pid=$!

port=""
for _ in $(seq 1 50); do
  if [[ -s "$port_file" ]]; then
    port=$(cat "$port_file")
    break
  fi
  sleep 0.1
done
[[ -n "$port" ]] || FAIL "WEBrick did not publish a port"
kill -0 "$server_pid" 2>/dev/null || FAIL "WEBrick exited before serving"

base="http://127.0.0.1:${port}"
cli=(ruby -I"$ROOT/lib" "$ROOT/bin/forced_file_from_url")

run_cli() {
  local expected=$1 out=$2 err=$3
  shift 3
  set +e
  "$@" >"$out" 2>"$err"
  local st=$?
  set -e
  if [[ "$st" -ne "$expected" ]]; then
    echo "expected exit $expected got $st" >&2
    echo "cmd: $*" >&2
    echo "stdout:" >&2
    cat "$out" >&2 || true
    echo "stderr:" >&2
    cat "$err" >&2 || true
    exit 1
  fi
}

cd "$work"

run_cli 0 "$got/text_small" "$got/text_small.err" "${cli[@]}" -o out.bin "${base}/small.txt"
cmp "$got/text_small" "$golden" || FAIL "text -o small stdout != spec/fixtures/text_success.txt (got $(cat "$got/text_small" | od -An -tx1))"
[[ ! -s "$got/text_small.err" ]] || FAIL "text -o small wrote stderr: $(cat "$got/text_small.err")"
[[ "$(stat -c%s out.bin)" -eq 100 ]] || FAIL "out.bin after small is $(stat -c%s out.bin) bytes"
echo "PASS text -o out.bin small.txt"

run_cli 0 "$got/text_big" "$got/text_big.err" "${cli[@]}" -o out.bin "${base}/big.bin"
cmp "$got/text_big" "$golden" || FAIL "text -o big stdout != spec/fixtures/text_success.txt (got $(cat "$got/text_big" | od -An -tx1))"
[[ ! -s "$got/text_big.err" ]] || FAIL "text -o big wrote stderr: $(cat "$got/text_big.err")"
[[ "$(stat -c%s out.bin)" -eq 20000 ]] || FAIL "out.bin after big is $(stat -c%s out.bin) bytes"
echo "PASS text -o out.bin big.bin"

run_cli 0 "$got/json_ok" "$got/json_ok.err" "${cli[@]}" --json -o out.bin "${base}/big.bin"
[[ ! -s "$got/json_ok.err" ]] || FAIL "json success wrote stderr: $(cat "$got/json_ok.err")"
ruby -rjson -e '
path, dest = ARGV
got = JSON.parse(File.read(path))
abort("json success is not a Hash: #{got.inspect}") unless got.is_a?(Hash)
abort("ok != true: #{got.inspect}") unless got["ok"] == true
abort("path != out.bin: #{got.inspect}") unless got["path"] == "out.bin"
size = File.size(dest)
abort("bytes #{got["bytes"].inspect} != #{size}") unless got["bytes"] == size
abort("origin must be absent: #{got.inspect}") if got.key?("origin")
' "$got/json_ok" out.bin
echo "PASS json -o out.bin"

run_cli 1 "$got/text_404" "$got/text_404.err" "${cli[@]}" -o out.bin "${base}/nope"
cmp "$got/text_404" /dev/null || FAIL "text 404 stdout not empty: $(od -An -tx1 "$got/text_404")"
[[ -s "$got/text_404.err" ]] || FAIL "text 404 stderr was empty"
echo "PASS text 404"

run_cli 1 "$got/json_404" "$got/json_404.err" "${cli[@]}" --json -o out.bin "${base}/nope"
[[ ! -s "$got/json_404.err" ]] || FAIL "json 404 wrote stderr: $(cat "$got/json_404.err")"
ruby -rjson -e '
got = JSON.parse(File.read(ARGV[0]))
abort("json 404 is not a Hash: #{got.inspect}") unless got.is_a?(Hash)
abort("ok != false: #{got.inspect}") unless got["ok"] == false
error = got["error"]
abort("error missing: #{got.inspect}") unless error.is_a?(Hash)
abort("error.kind missing: #{got.inspect}") if error["kind"].nil? || error["kind"].to_s.empty?
abort("error.message missing: #{got.inspect}") if error["message"].nil? || error["message"].to_s.empty?
' "$got/json_404"
echo "PASS json 404"

run_cli 0 "$got/scratch" "$got/scratch.err" "${cli[@]}" "${base}/big.bin"
[[ ! -s "$got/scratch.err" ]] || FAIL "scratch wrote stderr: $(cat "$got/scratch.err")"
[[ "$(tail -c 1 "$got/scratch" | od -An -tx1 | tr -d ' \n')" == "0a" ]] || FAIL "scratch stdout missing trailing LF: $(od -An -tx1 "$got/scratch")"
scratch_path=$(cat "$got/scratch")
[[ -n "$scratch_path" ]] || FAIL "scratch printed an empty path"
[[ -f "$scratch_path" ]] || FAIL "scratch path does not exist after exit: $scratch_path"
scratch_size=$(stat -c%s "$scratch_path")
[[ "$scratch_size" -eq 20000 ]] || FAIL "scratch file is ${scratch_size} bytes, want 20000 ($scratch_path)"
rm -f "$scratch_path"
echo "PASS scratch big.bin survives process exit"

echo "ok"

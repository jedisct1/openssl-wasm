import { readFileSync } from "node:fs";

const module = new WebAssembly.Module(readFileSync(process.argv[2]));
let memory;

class Exit {
  constructor(code) {
    this.code = code;
  }
}

const wasi_snapshot_preview1 = {
  random_get(ptr, len) {
    // getRandomValues() is limited to 64 KiB per call
    for (let off = 0; off < len; off += 65536) {
      crypto.getRandomValues(new Uint8Array(memory.buffer, ptr + off, Math.min(65536, len - off)));
    }
    return 0;
  },
  clock_time_get(id, precision, out) {
    const ns = id === 0
      ? BigInt(Date.now()) * 1000000n
      : process.hrtime.bigint();
    new DataView(memory.buffer).setBigUint64(out, ns, true);
    return 0;
  },
  fd_write(fd, iovs, count, written) {
    const view = new DataView(memory.buffer);
    let total = 0;
    for (let i = 0; i < count; i++) {
      const ptr = view.getUint32(iovs + i * 8, true);
      const len = view.getUint32(iovs + i * 8 + 4, true);
      process.stdout.write(new Uint8Array(memory.buffer, ptr, len));
      total += len;
    }
    view.setUint32(written, total, true);
    return 0;
  },
  proc_exit(code) {
    throw new Exit(code);
  },
};

const instance = new WebAssembly.Instance(module, { wasi_snapshot_preview1 });
memory = instance.exports.memory;
try {
  instance.exports._start();
} catch (e) {
  if (!(e instanceof Exit)) throw e;
  process.exitCode = e.code;
}

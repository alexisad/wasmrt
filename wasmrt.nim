import macros
import wasmrt/minify

macro exportwasm*(p: untyped): untyped =
    expectKind(p, nnkProcDef)
    result = p
    result.addPragma(newIdentNode("exportc"))
    when defined(cpp):
        result.addPragma(newColonExpr(newIdentNode("codegenDecl"), newLit("extern \"C\" __attribute__ ((visibility (\"default\"))) $# $#$#")))
    else:
        result.addPragma(newColonExpr(newIdentNode("codegenDecl"), newLit("__attribute__ ((visibility (\"default\"))) $# $#$#")))
    #echo "result-exportwasm"
    #echo result.repr

proc stripSinkFromArgType(t: NimNode): NimNode =
  result = t
  if result.kind == nnkBracketExpr and result.len == 2 and result[0].kind == nnkSym and $result[0] == "sink":
    result = result[1]

iterator arguments(formalParams: NimNode): tuple[idx: int, name, typ, default: NimNode] =
  formalParams.expectKind(nnkFormalParams)
  var iParam = 0
  for i in 1 ..< formalParams.len:
    let pp = formalParams[i]
    for j in 0 .. pp.len - 3:
      yield (iParam, pp[j], copyNimTree(stripSinkFromArgType(pp[^2])), pp[^1])
      inc iParam

macro importwasm*(body: string, p: untyped): untyped =
    expectKind(p, nnkProcDef)
    result = p

    var argString = ""
    for a in arguments(p.params):
        if a.idx != 0: argString &= ","
        argString &= $a.name

    result.addPragma(newIdentNode("importc"))
    result.addPragma(newColonExpr(newIdentNode("codegenDecl"), newLit("$# $#$# __asm__(\"" & escapeJs("\"" & argString & "\";" & body.strVal.minifyJs, "$$") & "\")")))
    #echo "result-importwasm"
    #echo result.repr

const initCode = """;
var W = WebAssembly, f = W.Module.imports(m), fE = W.Module.exports(m), o = {}, g = typeof window == 'undefined' ? global : window, q, b, xb;
/*for (i in fE) {
    var n = fE[i].name;
    //if(n == 'fib') fE.fib();
    //console.log("exportName:", fE[i]);
}*/

for (i in f) {
    var a = '', n = f[i].name;
    //console.log("importName:", n);
    if (n[0] == '"')
        o[n] = new Function(n.substring(1, n.indexOf('"', 1)), n);
    else
        console.warn("Undefined external symbol: ", n),
        o[n] = new Function('', 'throw new Error("Undefined symbol called:  ' + n + '")');
}

g._nimc = [];

g._nimmu = () => b = new Uint8Array(q.buffer);
//g._nimmu2 = () => xb = new Uint32Array(q.buffer);

g._getB = () => b;

g._nimsj = a => {
    //for(var i=0; )
    console.log("bmem:", b[a]);
    var s = '';
    while (b[a]) s += String.fromCharCode(b[a++]);
    return s;
    //String.fromCharCode.apply(null, new Uint8Array(b[a]));
};

g._nims = (a, l) => {
    var s = '';
    while (l--) s += String.fromCharCode(b[a++]);
    return s
};

g._str2ab = str => {
  /*var buf = new ArrayBuffer(str.length);
  var bufView = new Int8Array(buf);*/
  for (var i=0, strLen=str.length; i < strLen; i++) {
    b[i] = str.charCodeAt(i);
  }
};

//console.log("oEnv:", o);

W.instantiate(m, {env: o/*, memory: new W.Memory({
            initial: 256,
            maximum: 256
        }), DYNAMICTOP_PTR: 4096*/
    }).then(m => {
    //console.log("instantiate:", m.exports.memory.grow(1000));
    //console.log("instantiate:", m.exports.memory.grow(1000));
    g._nimm = m;
    q = m.exports.memory;
    _nimmu();
    //_nimmu2();
    m.exports['-']();
    /*if(m.exports['fib']){
      g.nimFuncs = g.nimFuncs || {};
      g.nimFuncs.fib = m.exports.fib;
      //var r = JSON.parse(g._nimsj( m.exports.fib() ));
      //console.log("fib:", r);
    }*/
    
})
""".minifyJs().escapeJs()

{.emit: """
#define NIM_WASM_EXPORT N_LIB_EXPORT __attribute__((visibility ("default")))

extern unsigned char __heap_base;
unsigned int bump_pointer = &__heap_base;

int stdout = 0;
int stderr = 1;

NIM_WASM_EXPORT void nimWasmMain() __asm__("-");
void nimWasmMain() {
    void NimMain();
    NimMain();
}

NIM_WASM_EXPORT const char __nimWasmInit __asm__(""" & '"' & initCode & """") = 0;


N_LIB_EXPORT void* malloc(int n) {
  unsigned int r = bump_pointer;
  bump_pointer += n;
  return (void *)r;
}



N_LIB_EXPORT void* memcpy(void* a, void* b, size_t s) {
    char* aa = (char*)a;
    char* bb = (char*)b;
    while(s) {
        --s;
        *aa = *bb;
        ++aa;
        ++bb;
    }
    return a;
}

N_LIB_EXPORT void* memset(void* a, int b, size_t s) {
    char* aa = (char*)a;
    while(s) {
        --s;
        *aa = b;
        ++aa;
    }
    return a;
}

N_LIB_EXPORT size_t strlen(const char* a) {
    const char* b = a;
    while (*b++);
    return b - a - 1;
}

""".}

proc isNodejsAux(): bool {.importwasm:"return typeof process != 'undefined'".}

proc nodejsWriteToStream(s: int, b: pointer, l: int) {.importwasm:"(s?process.stderr:process.stdout).write(_nims(b, l))".}

proc consoleWarn(a: cstring) {.importwasm: "console.warn(_nimsj(a))".}

proc consoleAppend(b: pointer, l: int) {.importwasm: "_nimc.push(_nims(b, l))".}
proc consoleFlush(s: int) {.importwasm: "(s?console.error:console.log)(_nimc.join('')); _nimc = []".}

proc fwrite(p: pointer, sz, nmemb: csize_t, stream: pointer): csize_t {.exportc.} =
  if cast[int](stream) in {0, 1}:
    # stdout
    let fzs = int(sz * nmemb)
    if isNodejsAux():
      nodejsWriteToStream(cast[int](stream), p, fzs)
    else:
      consoleAppend(p, fzs)
  else:
    consoleWarn("Attempted to write to wrong stream")

proc flockfile(f: pointer) {.exportc.} = discard
proc funlockfile(f: pointer) {.exportc.} = discard

proc exit(code: cint) {.exportc.} =
  consoleWarn "exit called, ignoring"

proc fflush(stream: pointer): cint {.exportc.} =
  if cast[int](stream) in {0, 1} and not isNodejsAux():
    consoleFlush(cast[int](stream))

proc fputc(c: cint, stream: pointer): cint {.exportc.} =
  if cast[int](stream) == 0:
    var buf = cast[uint8](c)
    if isNodejsAux():
      nodejsWriteToStream(cast[int](stream), addr buf, 1)
  else:
    consoleWarn "fputc called, ignoring"

proc munmap(a: pointer, len: csize_t): cint {.exportc.} =
  consoleWarn "munmap called, ignoring"


const wasmPageSize = 64 * 1024
proc wasmMemorySize(i: int32): int32 {.importc: "__builtin_wasm_memory_size", nodecl.}
proc wasmMemoryGrow(b: int32): int32 {.inline.} =
  when true:
    proc int_wasm_memory_grow(m, b: int32) {.importc: "__builtin_wasm_memory_grow", nodecl.}
    int_wasm_memory_grow(0, b)
  else:
    proc int_wasm_memory_grow(b: int32) {.importc: "__builtin_wasm_grow_memory", nodecl.}
    int_wasm_memory_grow(b)

proc wasmThrow(b: int32, p: pointer) {.importc: "__builtin_wasm_throw", nodecl.}
proc wasmGetException(b: int32): pointer {.importc: "__builtin_wasm_catch", nodecl.}

proc jsMemIncreased() {.importwasm: "_nimmu()".}

var memStart, totalMemory: uint

proc wasmAlloc(block_size: uint): pointer {.inline.} =
  if totalMemory == 0:
    totalMemory = cast[uint](wasmMemorySize(0)) * wasmPageSize
    memStart = totalMemory

  result = cast[pointer](memStart)

  let availableMemory = totalMemory - memStart
  memStart += block_size
  # inc(memStart, block_size)

  if availableMemory < block_size:
    let wasmPagesToAllocate = block_size div wasmPageSize + 1
    let oldPages = wasmMemoryGrow(int32(wasmPagesToAllocate))
    if oldPages < 0:
      return nil

    totalMemory += wasmPagesToAllocate * wasmPageSize
    jsMemIncreased()

proc mmap(a: pointer, len: csize_t, prot, flags, fildes: cint, off: int): pointer {.exportc.} =
  if a != nil:
    consoleWarn("mmap called with wrong arguments")
  wasmAlloc(len)

when not defined(gcDestructors):
  GC_disable()

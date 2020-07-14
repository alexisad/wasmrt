process.on('unhandledRejection', error => {
  console.log('Unhandled promise rejection', error);
  process.exit(1)
});

function runNimWasm(w){
  for(i of WebAssembly.Module.exports(w)){
    n=i.name;
    //console.log("n:", n);
    
    if(n[0]==';'){
      
      var fWsm = new Function('m',n);
      var rF = fWsm(w);
      //console.log("rF:", rF);
      break
    }

    //var r = JSON.parse(  g._nimsj( m.exports.fib() ));
    
  }
  //var g = typeof window == 'undefined' ? global : window;
  setTimeout(()=>{
    //console.log("_str2ab:", _str2ab("Hello Alex"));
    //_str2ab("123Helöo Alex")
    var b = _getB();
    //console.log("b:", b.length);
    function copy2mem(s){
      var pbf = new Uint8Array(s)
      for(var i=0,l=pbf.length; i<l; i++){
        b[i] = pbf[i];
      }
      
    }

    const jsArray = "5099587551564398592!2271779133,126631,2088632";
    // Allocate memory for jsArray.length 8-bit integers
    // and return get starting address.
    const cArrayPointer = _nimm.exports.malloc(jsArray.length*8 + 20*8);
    //console.log("cArrayPointer+:", cArrayPointer);
    const cArray = new Float64Array(
      _nimm.exports.memory.buffer,
      cArrayPointer,
      jsArray.length + 20
    );

    
    for (var i=0,strLen=jsArray.length; i < strLen; i++) {
      cArray[i] = jsArray.charCodeAt(i);
    }


    //copy2mem( require("fs").readFileSync("hdlm_lane_topol.pbf") );
    /*(_getB())[0] = 49;
    (_getB())[1] = 50;
    var b = _getB();
    for(var i=0,l=b.length; i<10; i++){
      if(b[i] != 0){
        console.log("_getB():", String.fromCharCode(b[i]));
      }
    }*/
    var r = _nimm.exports.fib(cArrayPointer, jsArray.length, 20);
    console.log("r:", _nimsj(r), cArray);
  }, 0);

  //WebAssembly.Module.exports.fib();
  //console.log("exports:", WebAssembly.Module.exports);
}
var wsmMorton;

WebAssembly.compile(require("fs").readFileSync(process.argv[2])).then(runNimWasm)

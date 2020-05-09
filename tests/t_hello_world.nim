import ../wasmrt
import httpclient

var client = newHttpClient()
echo client.getContent("http://google.com")

proc consoleLog(a: cstring) {.importwasm: "console.log(_nimsj(a))".}
var s = "Hello World"
consoleLog(s & "!!!11")
var a = 5
echo "hi", a

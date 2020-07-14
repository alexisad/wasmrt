import ../wasmrt
#import math
#import strutils
#import parseutils
#from math import floor#, pow, log10
#import algorithm

#import nimpb/nimpb
#import ../lane_topology_pb

proc consoleLog(a: cstring) {.importwasm: "console.log(_nimsj(a))".}
proc consoleLog2(a: int) {.importwasm: "console.log(a)".}
#proc jsonParse(a: cstring): cstring {.importwasm: "JSON.parse(_nimsj(a)).name".}



proc deinterleave_one_32(interleaved: int64): int64 =
    var interleaved = interleaved.and 0x5555555555555555
    interleaved = ( interleaved.or (interleaved.shr 1) ).and 0x3333333333333333
    interleaved = ( interleaved.or (interleaved.shr 2) ).and 0x0F0F0F0F0F0F0F0F
    interleaved = ( interleaved.or (interleaved.shr 4) ).and 0x00FF00FF00FF00FF
    interleaved = ( interleaved.or (interleaved.shr 8) ).and 0x0000FFFF0000FFFF
    interleaved = ( interleaved.or (interleaved.shr 16) ).and 0x00000000FFFFFFFF
    interleaved


proc deinterleave32(interleaved: int64): tuple[first, second: int64] =
    let first = deinterleave_one_32( interleaved.shr  1 )
    let second = deinterleave_one_32( interleaved )
    (first, second)

proc getLatLon(encodedMortonOffset: int64, previousMortonCode: int64): tuple[lat: float64, lon: float64, next_morton: int64] =
    let next_morton_code = encoded_morton_offset.xor  previous_morton_code
    var (lat, lon) = deinterleave32 next_morton_code
    lat = lat.or ( lat.and  ( 0x40000000 ) ).shl 1
    let latF = cast[int32](lat).toBiggestFloat * 180.toBiggestFloat / 0x80000000.toBiggestFloat
    let lonF = cast[int32](lon).toBiggestFloat * 180.toBiggestFloat / 0x80000000.toBiggestFloat
    (latF, lonF, next_morton_code)

when false:
    proc strToInt(x: ptr UncheckedArray[int32], cDel: int, start = 0, lenH: int): int64 {.inline.} =
        for i in start..lenH:
            if x[i] == cDel:
                break
            result += (x[i] - 48) * 10
        result = result div 10

proc strToInt(x: ptr UncheckedArray[float64], cDel: int, start = 0, lenH: int): tuple[n: int64, nextP: int] =
    var
        res: uint64
        nextP: int
    for i in start..lenH:
        res += (x[i].int - 48).uint64
        if i == lenH or x[i + 1].int == cDel:
            nextP = i + 2
            break
        res = res * 10.uint64
    (res.int64, nextP)



proc intToStr2(n: int64): string {.inline.} =
    var
        k = n
        negative = false
    if k < 0:
        negative = true
        k *= -1
    var res: string
    while (k > 0):
        let t = k mod 10
        k = k /% 10
        res.add chr(t.or 0x30)
    for i in countdown(res.high, 0):
        result.add res[i]
    if negative:
        result = "-" & result


proc intToStr(n: int64): string {.inline.} =
    var
        #k = n
        negative = n < 0
    if n < 0:
        negative = true
    var k =
        if n < 0:
            (n * -1)
        else:
            n
    var res: string
    while (k > 0):
        let t = k mod 10
        let x = k.float64
        let xy = 10.float64
        let xk = (x / xy).int64
        consoleLog( ("xk:" & $xk).cstring)
        k = xk
        #res.add chr(t.or 0x30)
        #return ""
    #if negative:
        #result.add '-'
    #for i in countdown(res.high, 0):
        #result.add res[i]
    result = "123456"

#Number on countu
proc n_tu(number, count: int): int = 
    result = 1;
    var cnt = count
    while(cnt > 0):
        result *= number
        dec cnt 




#/*** Convert float to string ***/
proc float2string(f: float): string =

    #long long int length, length2, i, number, position, sign;
    var
        length, length2: int #Size of decimal part, Size of tenth
        number: float
        number2 = f
        nF = f
        sign = '0'

    if (f < 0):
        sign = '-';
        number2 *= -1
    number = number2

    #/* Calculate length2 tenth part */
    #echo "!!!:", number2.int.float - number
    #consoleLog("gggggggggggggggg".cstring)
    while (number2 - number.int.float) != 0.0 and not ((number2 - number.int.float) < 0.0):
        consoleLog("gggggggggggggggg".cstring)
        number2 = f * (n_tu(10, length2 + 1)).float
        number = number2
        inc length2
    #/* Calculate length decimal part */
    length = if f > 1: 0 else: 1
    while nF > 1:
        nF = nF / 10
        inc length

    var position = length
    length = length + 1 + length2
    number = number2
    if (sign == '-'):
        inc length
        inc position

    for i in countdown(length, 0):
        if i == length:
            discard
        elif i == position:
            result = '.' & result;
        elif sign == '-' and i == 0:
            result = '-' & result;
        else:
            result = "(number.int mod 10)" & '0' & result;
            number = number / 10;


proc flt2str(f: float): string =
    result = $(f.int)
    #result = 


var mortoncode_diffs = newSeqOfCap[int64](50)

proc fib*(pb: var UncheckedArray[float64], lenIn, lenOut: int): cstring {.exportwasm.} =
    #let d = cast[cstring](pb)
    #var d = ""
    #let d = pb[0]
    var cCum = ""
    #pb[5] = -188.1234567890123456789
    var cCenterMorton = ""
    
    var centerMorton: int64
    var res = newSeq[int]()
    #result = cast[ptr UncheckedArray[int32]](alloc(1*sizeof(int32)))
    
    #let x = "5099587551564398592".parseBiggestInt
    var nextP: int
    (centerMorton, nextP) = strToInt(pb.addr, ord '!', lenH = lenIn-1)
    var coordDiff: int64
    var icnt = 0
    while nextP < lenIn:
        #echo "---------------------!!!"
        (coordDiff, nextP) = strToInt(pb.addr, ord ',', start = nextP, lenH = lenIn-1)
        #pb[icnt] = coordDiff.float64
        mortoncode_diffs.add coordDiff
        #inc icnt
    when false:
        let mDel = ord '!'
        for i in 0..lenIn-1:
            if pb[i].int == mDel:
                #discard "5099587551564398592".parseBiggestInt centerMorton
                centerMorton = centerMorton div 10
                break
            centerMorton += (pb[i] - 48) * 10
        if centerMortonX != centerMorton:
            d = "!!!Error!!!"
    
    #var r = pb.toOpenArray(0, 3)
    #echo "pb[0]:", ($d).split(";")
    var previous_morton_code = centerMorton#5099587551564398592
    #var mortoncode_diffs = [2271779133,126631,2088632]
    #pb[5] = 77.int32
    
    var xLat, xLon: string
    when true:
        for i,coordDiff in mortoncode_diffs:
            let (lat, lon, next_morton) = getLatLon(coordDiff, previous_morton_code)
            #let xLat = lat.float2string
            #xLat = intToStr (lat * 1_000_000_000_000_000.float64).int64
            #xLon = intToStr (lon * 1_000_000_000_000_000.float64).int64
            #consoleLog("-------------------?")
            pb[i*2] = lat
            pb[i*2 + 1] = lon
            #pb[5] = 77.int32
            #echo "lat, lon"
            #consoleLog(cast[cstring](lat))
            #cCum &= $lat & "lon"#& $lon & $next_morton
            previous_morton_code = next_morton
    
    mortoncode_diffs.setLen(0)
    #cCum.cstring
    #ord('1')
    #result = cast[cstringArray](lat.uint16)
    #xLat.cstring
    #d.cstring
    #pb[lenIn + 20] = centerMorton.float64





when false:
    proc fib*(pb: UncheckedArray[uint8]): cstring {.exportwasm.} =
        #var pb = "x"
        let yxc = "10"
        #consoleLog("p")
        #echo "pb:", pb[0], pb[1], pb[2], pb[3], pb[4]
        #let ccc = cast[string](pb)
        #echo "ccc:", ccc
        #let ccc =  (pb.unsafeAddr)[]
        #echo "pb:", pb[10]
        result = cstring("""{ "name2":"""" & "$pb" & """John", "age":30, "city":"New York"}""")

var s = "Hello Wörld"
#consoleLog(s)
var a = 5
#echo "hi", a

#var booo = jsonParse("""{ "name":"John", "age":30, "city":"New York"}""")
#echo "booo:", ($booo).len
#consoleLog2(777)
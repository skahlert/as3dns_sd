package cmodule.as3dns_sd {
// Start of file scope inline assembly
import flash.utils.*
import flash.display.*
import flash.text.*
import flash.events.*
import flash.net.*
import flash.system.*










public var gdomainClass:Class;
public var gshell:Boolean = false;

public function establishEnv():void
{
  try
  {
    var ns:Namespace = new Namespace("avmplus");
  
    gdomainClass = ns::["Domain"];
    gshell = true;
  }
  catch(e:*) {}
  if(!gdomainClass)
  {
    var ns:Namespace = new Namespace("flash.system");
  
    gdomainClass = ns::["ApplicationDomain"];
  }
}

establishEnv();

public var glogLvl:int = Alchemy::LogLevel;

public function log(lvl:int, msg:String):void
{
  if(lvl < glogLvl)
    trace(msg);
}

class LEByteArray extends ByteArray
{
  public function LEByteArray()
  {
    super.endian = "littleEndian";
  }

  public override function set endian(e:String):void
  {
    throw("LEByteArray endian set attempted");
  }
}

class GLEByteArrayProvider
{
  public static function get():ByteArray
  {
    var result:ByteArray;

    try
    {
      result = gdomainClass.currentDomain.domainMemory;
    }
    catch(e:*) {}

    if(!result)
    {
      result = new LEByteArray;
      try
      {
        result.length = gdomainClass.MIN_DOMAIN_MEMORY_LENGTH;
        gdomainClass.currentDomain.domainMemory = result;
      }
      catch(e:*)
      {
        log(3, "Not using domain memory");
      }
    }
    return result;
  }
}

public class MemUser
{
  public final function _mr32(addr:int):int { gstate.ds.position = addr; return gstate.ds.readInt(); }
  public final function _mru16(addr:int):int { gstate.ds.position = addr; return gstate.ds.readUnsignedShort(); }
  public final function _mrs16(addr:int):int { gstate.ds.position = addr; return gstate.ds.readShort(); }
  public final function _mru8(addr:int):int { gstate.ds.position = addr; return gstate.ds.readUnsignedByte(); }
  public final function _mrs8(addr:int):int { gstate.ds.position = addr; return gstate.ds.readByte(); }
  public final function _mrf(addr:int):Number { gstate.ds.position = addr; return gstate.ds.readFloat(); }
  public final function _mrd(addr:int):Number { gstate.ds.position = addr; return gstate.ds.readDouble(); }
  public final function _mw32(addr:int, val:int):void { gstate.ds.position = addr; gstate.ds.writeInt(val); }
  public final function _mw16(addr:int, val:int):void { gstate.ds.position = addr; gstate.ds.writeShort(val); }
  public final function _mw8(addr:int, val:int):void { gstate.ds.position = addr; gstate.ds.writeByte(val); }
  public final function _mwf(addr:int, val:Number):void { gstate.ds.position = addr; gstate.ds.writeFloat(val); }
  public final function _mwd(addr:int, val:Number):void { gstate.ds.position = addr; gstate.ds.writeDouble(val); }
}

public const gstackSize:int = 1024 * 1024;

public class MState extends MemUser
{
 
  public const ds:ByteArray = (gstate == null || gstate.ds == null) ? GLEByteArrayProvider.get() : gstate.ds;

 
Alchemy::NoVector {
  public const funcs:Array = (gstate == null) ? [null] : gstate.funcs;
}
Alchemy::Vector {
  public var funcs:Vector.<Object> = (gstate == null) ? new Vector.<Object>(1) : gstate.funcs;
}

 
  public const syms:Object = (gstate == null) ? {} : gstate.syms;
 
  public var system:CSystem = (gstate == null) ? null : gstate.system;

 
  public var esp:int;
  public var ebp:int;
  public var eax:int;
  public var edx:int;
  public var st0:Number;
  public var cf:uint;

 
  public var gworker:Machine;

  public function MState(machine:Machine)
  {
    if(machine)
    {
      gworker = machine;
      gworker.mstate = this;
    }
   
    if(gstate == null)
    {
      ds.length += gstackSize;
      esp = ds.length;
    }
  }

  public function push(v:int):void
  {
    esp -= 4;
    _mw32(esp, v);
  }
  
  public function pop():int
  {
    var v:int = _mr32(esp);
  
    esp += 4;
    return v;
  }

  public function copyTo(state:MState):void
  {
    state.esp = esp;
    state.ebp = ebp;
    state.eax = eax;
    state.edx = edx;
    state.st0 = st0;
    state.cf = cf;
    state.gworker = gworker;
  }
}

public var gpreStaticInits:Array;

public function regPreStaticInit(f:Function):void
{
  if(!gpreStaticInits)
    gpreStaticInits = [];

  gpreStaticInits.push(f);
}

public function modPreStaticInit():void
{
  if(gpreStaticInits)
    for(var i:int = 0; i < gpreStaticInits.length; i++)
      gpreStaticInits[i]();
}

public var gpostStaticInits:Array;

public function regPostStaticInit(f:Function):void
{
  if(!gpostStaticInits)
    gpostStaticInits = [];

  gpostStaticInits.push(f);
}

public function modPostStaticInit():void
{
  if(gpostStaticInits)
    for(var i:int = 0; i < gpostStaticInits.length; i++)
      gpostStaticInits[i]();
}

public function regFunc(fsm:Function):int
{
  return gstate.funcs.push(fsm) - 1;
}

public function unregFunc(n:int):void
{
 
  if(n+1 == gstate.funcs.length)
    gstate.funcs.pop();
}

public function importSym(s:String):int
{
  var res:int = gstate.syms[s];

  if(!res)
  {
    log(3, "Undefined sym: " + s);
   
   
    return exportSym(s, regFunc(function() {
      throw("Undefined sym: " + s);
    }));
  }
  return res;
}

public function exportSym(s:String, a:int):int
{
  gstate.syms[s] = a;
  return a;
}

public class StaticInitter
{
  var ptr:int = 0;
 
  public function alloc(size:int, align:int):int
  {
    if(!align)
      align = 1;
   
    ptr = ptr ? ptr : gstate.ds.length ? gstate.ds.length : 1024;
   
    ptr = (ptr + align - 1) & ~(align - 1);
   
    var result:int = ptr;
   
    ptr += size;
   
    gstate.ds.length = ptr;
    return result;
  }
 
  public function start(sym:int):void
  {
    ptr = sym;
  }

  private function ST8int(ptr:int, v:int):void
  {
    gstate.gworker.mstate._mw8(ptr, v);
  }

  private function ST16int(ptr:int, v:int):void
  {
    gstate.gworker.mstate._mw16(ptr, v);
  }

  private function ST32int(ptr:int, v:int):void
  {
    gstate.gworker.mstate._mw32(ptr, v);
  }

  public function set i8(v:uint):void
  {
    ST8int(ptr, v);
    ptr += 1;
  }
 
  public function set i16(v:uint):void
  {
    ST16int(ptr, v);
    ptr += 2;
  }
 
  public function set i32(v:uint):void
  {
    ST32int(ptr, v);
    ptr += 4;
  }
 
  public function set ascii(v:String):void
  {
    var len:int = v.length;
 
    for(var i:int = 0; i < len; i++)
      this.i8 = v.charCodeAt(i);
  }
 
  public function set asciz(v:String):void
  {
    this.ascii = v;
    this.i8 = 0;
  }
 
  public function set zero(n:int):void
  {
    while(n--)
      this.i8 = 0;
  }
}

class AlchemyLibInit
{
  public var rv:int;

  function AlchemyLibInit(_rv:int)
  {
    rv = _rv;
  }
};

class AlchemyExit
{
  public var rv:int;

  function AlchemyExit(_rv:int)
  {
    rv = _rv;
  }
};

class AlchemyYield
{
  public var ms:int;

  function AlchemyYield(_ms:int = 0)
  {
    ms = _ms;
  }
};

class AlchemyDispatch
{
};

class AlchemyBlock
{
};

class AlchemyBreakpoint
{
  public var bp:Object;

  function AlchemyBreakpoint(_bp:Object)
  {
    bp = _bp;
  }
};

class IO
{
  public function close():int { return -1; }

  public function read(buf:int, nbytes:int):int { return 0; }
  public function write(buf:int, nbytes:int):int { return 0; }
  public function set position(offs:int):void { }
  public function get position():int { return -1; }
  public function set size(n:int):void { }
  public function get size():int { return 0; }
}

class ByteArrayIO extends IO
{
  public var byteArray:ByteArray;

  public override function read(buf:int, nbytes:int):int
  {
    if(!byteArray)
      throw(new AlchemyBlock);

    var n:int = Math.min(nbytes, byteArray.bytesAvailable);

    if(n)
      byteArray.readBytes(gstate.ds, buf, n);
    return n;
  }

  public override function write(buf:int, nbytes:int):int
  {
    if(!byteArray)
      throw(new AlchemyBlock);

    if(nbytes)
      byteArray.writeBytes(gstate.ds, buf, nbytes);
    return nbytes;
  }

  public override function set position(offs:int):void
  {
    if(!byteArray)
      throw(new AlchemyBlock);

    byteArray.position = offs;
  }

  public override function get position():int
  {
    if(!byteArray)
      throw(new AlchemyBlock);

    return byteArray.position;
  }

  public override function set size(n:int):void
  {
    if(!byteArray)
      throw(new AlchemyBlock);

    byteArray.length = n;
  }

  public override function get size():int
  {
    if(!byteArray)
      throw(new AlchemyBlock);

    return byteArray.length;
  }
}

Alchemy::Shell
class ShellIO extends IO
{
  private var m_buf:String = "";
  private var m_trace:Boolean;
  private var m_closed:Boolean;

  public function ShellIO(_trace:Boolean = false)
  {
    m_trace = _trace;
  }

  public override function read(buf:int, nbytes:int):int
  {
    if(!m_buf)
    {
      var ns:Namespace = new Namespace("avmshell");
      var sys:Object = ns::["System"];

      m_buf = sys.readLine() + "\n";
      if(m_buf == "\x04\n")
        m_closed = true;
    }

    if(m_closed)
      return 0;

    var r:int = 0;

    while(m_buf && nbytes--)
    {
      r++;
      gstate._mw8(buf++, m_buf.charCodeAt(0));
      m_buf = m_buf.substr(1);
    }
    return r;
  }

  public override function write(buf:int, nbytes:int):int
  {
    var c:int = nbytes;
    var s:String = "";
    while(c--)
    {
      s += String.fromCharCode(gstate._mru8(buf));
      buf++;
    }
    if(m_trace)
      trace(s);
    else
    {
      var ns:Namespace = new Namespace("avmshell");
      var sys:Object = ns::["System"];

      sys.write(s);
    }
    return nbytes;
  }
}

Alchemy::NoShell {

class TextFieldI extends IO
{
  private var m_tf:TextField;
  private var m_start:int = -1;
  private var m_buf:String = "";
  private var m_closed:Boolean = false;

  public function TextFieldI(tf:TextField)
  {
    m_tf = tf;
    m_tf.addEventListener(KeyboardEvent.KEY_DOWN, function(event:KeyboardEvent)
    {
     
      if(String.fromCharCode(event.charCode).toLowerCase() == "d"
          && event.ctrlKey)
        m_closed = true;
     
      if(String.fromCharCode(event.charCode).toLowerCase() == "t"
          && event.ctrlKey)
        setTimeout(function():void {
          m_start = -1;
          m_tf.text = "";
        },1);
    });
   
   
   
   
   
    m_tf.addEventListener(TextEvent.TEXT_INPUT, function(event:TextEvent)
    {
      var len:int = m_tf.length;
      var selStart:int = m_tf.selectionBeginIndex;
      if(m_start < 0 || m_start > selStart)
        m_start = selStart;
      event.preventDefault();
      m_tf.replaceSelectedText(event.text);
      var selEnd:int = m_tf.selectionEndIndex;
      var fmt:TextFormat = m_tf.getTextFormat(selStart, selEnd);
      fmt.bold = false;
      m_tf.setTextFormat(fmt, selStart, selEnd);
      if(event.text.indexOf("\n") >= 0)
      {
        var ptext:String = m_tf.text;
        var nonBold:String = "";
        var len:int = m_tf.length;
        for(var i:int = m_start; i < len; i++)
        {
          var fmt:TextFormat = m_tf.getTextFormat(i, i+1);
          var bold:Boolean = fmt.bold;

          if(bold != null && !bold.valueOf())
            nonBold += ptext.charAt(i);
        }
        nonBold = nonBold.replace(/\r/g, "\n");
        var nl:int = nonBold.lastIndexOf("\n");
        var sel:int = len - (nonBold.length - nl - 1);
        m_tf.setSelection(sel, sel);
        nonBold = nonBold.substr(0, nl + 1);
        if(!m_closed)
          m_buf += nonBold;
        m_start = sel;
      }
    });
  }

  public override function read(buf:int, nbytes:int):int
  {
    if(!m_buf)
    {
      if(m_closed)
        return 0;
     
      throw new AlchemyBlock;
    }

    var r:int = 0;

    while(m_buf && nbytes--)
    {
      r++;
      gstate._mw8(buf++, m_buf.charCodeAt(0));
      m_buf = m_buf.substr(1);
    }
    return r;
  }

}

class TextFieldO extends IO
{
  private var m_tf:TextField;
  private var m_trace:Boolean;

  public function TextFieldO(tf:TextField, shouldTrace:Boolean = false)
  {
    m_tf = tf;
    m_trace = shouldTrace;
  }

  public override function write(buf:int, nbytes:int):int
  {
    var c:int = nbytes;
    var s:String = "";
    while(c--)
    {
      s += String.fromCharCode(gstate._mru8(buf));
      buf++;
    }
    if(m_trace)
      trace(s);
    var start:int = m_tf.length;
    m_tf.replaceText(start, start, s);
    var end:int = m_tf.length;
    var fmt:TextFormat = m_tf.getTextFormat(start, end);
    fmt.bold = true;
    m_tf.setTextFormat(fmt, start, end);
    m_tf.setSelection(end, end);
    return nbytes;
  }
}

}

public interface CSystem
{
 
  function setup(f:Function):void;

 
  function getargv():Array;
  function getenv():Object;
  function exit(val:int):void;

 
  function fsize(fd:int):int;
  function psize(p:int):int;
  function access(path:int, mode:int):int;
  function open(path:int, flags:int, mode:int):int;
  function ioctl(fd:int, req:int, va:int):int;
  function close(fd:int):int;
  function write(fd:int, buf:int, nbytes:int):int;
  function read(fd:int, buf:int, nbytes:int):int;
  function lseek(fd:int, offset:int, whence:int):int;
  function tell(fd:int):int;
} 


function shellExit(res:int):void
{
  Alchemy::NoShell {

  var ns:Namespace = new Namespace("flash.desktop");
  var nativeApp:Object;

  try
  {
    var nativeAppClass:Object = ns::["NativeApplication"];

    nativeApp = nativeAppClass.nativeApplication;
  }
  catch(e:*)
  {
    log(3, "No nativeApplication: " + e);
  }
  if(nativeApp)
  {
    nativeApp.exit(res);
    return;
  }

  }

  Alchemy::Shell {

  var ns:Namespace = new Namespace("avmshell");
  var sys:Object = ns::["System"];

  sys.exit(res);

  return;

  }

  throw new AlchemyExit(res);
}



var gfiles:Object = {};



Alchemy::NoShell
public class CSystemBridge implements CSystem
{
  private var sock:Socket;

  public function CSystemBridge(host:String, port:int)
  {
    sock = new Socket();
    sock.endian = "littleEndian";

    sock.addEventListener(flash.events.Event.CONNECT, sockConnect);
    sock.addEventListener(flash.events.ProgressEvent.SOCKET_DATA, sockData);
    sock.addEventListener(flash.events.IOErrorEvent.IO_ERROR, sockError);

    sock.connect(host, port);
  }

  private function sockConnect(e:Event):void
  {
log(2, "bridge connected");
  }

  private function sockError(e:IOErrorEvent):void
  {
log(2, "bridge error");
  }

 
  private var curPackBuf:ByteArray = new LEByteArray();
  private var curPackId:int;
  private var curPackLen:int;

  private function sockData(e:ProgressEvent):void
  {
    while(sock.bytesAvailable)
    {
      if(!curPackLen)
      {
        if(sock.bytesAvailable >= 8)
        {
          curPackId = sock.readInt();
          curPackLen = sock.readInt();
log(3, "bridge packet id: " + curPackId + " len: " + curPackLen);
          curPackBuf.length = curPackLen;
          curPackBuf.position = 0;
        }
        else break;
      }
      else
      {
        var len:int = sock.bytesAvailable;
  
        if(len > curPackLen)
          len = curPackLen;
        curPackLen -= len;
        while(len--)
          curPackBuf.writeByte(sock.readByte());
        if(!curPackLen)
          handlePacket();
      }
    }
  }

 
  private var handlers:Object = {};

  private function handlePacket():void
  {
    curPackBuf.position = 0;
    handlers[curPackId](curPackBuf);
    if(curPackId)
      delete handlers[curPackId];
  }

  private var sentPackId:int = 1;

  private function sendRequest(buf:ByteArray, handler:Function):void
  {
    if(handler)
      handlers[sentPackId] = handler;
    sock.writeInt(sentPackId);
    sock.writeInt(buf.length);
    sock.writeBytes(buf, 0);
    sock.flush();
    sentPackId++;
  }

 
  private var requests:Object = {};

  private function asyncReq(create:Function, handle:Function):*
  {
   
    var rid:String = String(gstate.esp);
    var req:Object = requests[rid];

    if(req)
    {
      if(req.pending)
        throw(new AlchemyBlock());
      else
      {
        delete requests[rid];
        return req.result;
      }
    }
    else
    {
      req = { pending: true };
      requests[rid] = req;

      var pack:ByteArray = new LEByteArray();

      create(pack);
      sendRequest(pack, function(buf:ByteArray):void {
        req.result = handle(buf);
        req.pending = false;
      });
      if(req.pending)
        throw(new AlchemyBlock());
    }
  }

 
  static const FSIZE:int = 1;
  static const PSIZE:int = 2;
  static const ACCESS:int = 3;
  static const OPEN:int = 4;
  static const CLOSE:int = 5;
  static const WRITE:int = 6;
  static const READ:int = 7;
  static const LSEEK:int = 8;
  static const TELL:int = 9;
  static const EXIT:int = 10;
  static const SETUP:int = 11;

  var argv:Array;
  var env:Object;

  public function setup(f:Function):void
  {
    var pack:ByteArray = new LEByteArray();

   
    pack.writeInt(SETUP);
    sendRequest(pack, function(buf:ByteArray):void {
     
     
      var argc:int = buf.readInt();

      argv = [];
      while(argc--)
        argv.push(buf.readUTF());

      var envc:int = buf.readInt();

      env = {};
      while(envc--)
      {
        var res:Array = (/([^\=]*)\=(.*)/).exec(buf.readUTF());

        if(res && res.length == 3)
          env[res[1]] = res[2];
      }
      f();
    });
  }

  public function getargv():Array
  {
    return argv;
  }

  public function getenv():Object
  {
    return env;
  }

  public function exit(val:int):void
  {
    var req:ByteArray = new LEByteArray();

    req.writeInt(EXIT);
    req.writeInt(val);
    sendRequest(req, null);
    shellExit(val);
  }

  public function fsize(fd:int):int
  {
    return asyncReq(
      function(req:ByteArray):void {
        req.writeInt(FSIZE);
        req.writeInt(fd);
      },
      function(resp:ByteArray):int {
        return resp.readInt();
      }
    );
  }

  public function psize(p:int):int
  {
    return asyncReq(
      function(req:ByteArray):void {
        req.writeInt(PSIZE);
        req.writeUTFBytes(gstate.gworker.stringFromPtr(p));
      },
      function(resp:ByteArray):int {
        return resp.readInt();
      }
    );
  }

  public function access(path:int, mode:int):int
  {
    return asyncReq(
      function(req:ByteArray):void {
        req.writeInt(ACCESS);
        req.writeInt(mode);
        req.writeUTFBytes(gstate.gworker.stringFromPtr(path));
      },
      function(resp:ByteArray):int {
        return resp.readInt();
      }
    );
  }

  public function ioctl(fd:int, req:int, va:int):int
  {
    return -1;
  }

  public function open(path:int, flags:int, mode:int):int
  {
    return asyncReq(
      function(req:ByteArray):void {
        req.writeInt(OPEN);
        req.writeInt(flags);
        req.writeInt(mode);
        req.writeUTFBytes(gstate.gworker.stringFromPtr(path));
      },
      function(resp:ByteArray):int {
        return resp.readInt();
      }
    );
  }

  public function close(fd:int):int
  {
    return asyncReq(
      function(req:ByteArray):void {
        req.writeInt(CLOSE);
        req.writeInt(fd);
      },
      function(resp:ByteArray):int {
        return resp.readInt();
      }
    );
  }

  public function write(fd:int, buf:int, nbytes:int):int
  {
    return asyncReq(
      function(req:ByteArray):void {
        req.writeInt(WRITE);
        req.writeInt(fd);
        if(nbytes > 4096)
          nbytes = 4096;
        req.writeBytes(gstate.ds, buf, nbytes);
      },
      function(resp:ByteArray):int {
        return resp.readInt();
      }
    );
  }

  public function read(fd:int, buf:int, nbytes:int):int
  {
    return asyncReq(
      function(req:ByteArray):void {
        req.writeInt(READ);
        req.writeInt(fd);
        req.writeInt(nbytes);
      },
      function(resp:ByteArray):int {
        var result:int = resp.readInt();
        var s:String = "";

        gstate.ds.position = buf; 
        while(resp.bytesAvailable)
        {
          var ch:int = resp.readByte();

          s += String.fromCharCode(ch);
          gstate.ds.writeByte(ch);
        }
log(4, "read from: " + fd + " : [" + s + "]");
        return result;
      }
    )
  }

  public function lseek(fd:int, offset:int, whence:int):int
  {
    return asyncReq(
      function(req:ByteArray):void {
        req.writeInt(LSEEK);
        req.writeInt(fd);
        req.writeInt(offset);
        req.writeInt(whence);
      },
      function(resp:ByteArray):int {
        return resp.readInt();
      }
    );
  }

  public function tell(fd:int):int
  {
    return asyncReq(
      function(req:ByteArray):void {
        req.writeInt(TELL);
        req.writeInt(fd);
      },
      function(resp:ByteArray):int {
        return resp.readInt();
      }
    );
  }

}



public class CSystemLocal implements CSystem
{
 
  private const fds:Array = [];
  private const statCache:Object = {};
  private var forceSync:Boolean;

  public function CSystemLocal(_forceSync:Boolean = false)
  {
    forceSync = _forceSync;

    Alchemy::Shell {

    fds[0] = new ShellIO();
    fds[1] = new ShellIO();
    fds[2] = new ShellIO(true);

    }

    Alchemy::NoShell {

    gtextField = new TextField();
    gtextField.width = gsprite ? gsprite.stage.stageWidth : 800;
    gtextField.height = gsprite ? gsprite.stage.stageHeight : 600;
    gtextField.multiline = true;
    gtextField.defaultTextFormat = new TextFormat("Courier New");
    gtextField.type = TextFieldType.INPUT;
    gtextField.doubleClickEnabled = true;

    fds[0] = new TextFieldI(gtextField);
    fds[1] = new TextFieldO(gtextField, gsprite == null);
    fds[2] = new TextFieldO(gtextField, true);

    if(gsprite && gtextField)
      gsprite.addChild(gtextField);
    else
      log(3, "local system w/o gsprite");
    }
  }

  public function setup(f:Function):void
  {
    f();
  }

  public function getargv():Array
  {
    return gargs;
  }

  public function getenv():Object
  {
    return genv;
  }

  public function exit(val:int):void
  {
    log(3, "exit: " + val);
    shellExit(val);
  }

 
  private function fetch(path:String):Object
  {
    var res:Object = statCache[path];

    if(!res)
    {
      var gf:ByteArray = gfiles[path];

      if(gf)
      {
        res = { pending:false, size:gf.length, data:gf };
        statCache[path] = res;

        return res;
      }
    }

    Alchemy::Shell {

      var ns:Namespace = new Namespace("avmshell");
      var file:Object = ns::["File"];

      if(!file.exists(path))
      {
        log(3, "Doesn't exist: " + path);
        return { size: -1, pending: false };
      }
      
      var ns1:Namespace = new Namespace("avmplus");
      var bac:Object = ns1::["ByteArray"];
      var bytes:ByteArray = new ByteArray;
      bytes.writeBytes(bac.readFile(path));

      bytes.position = 0;

      return { size: bytes.length, data: bytes, pending: false };

    }

    if(forceSync)
      return res || { size: -1, pending: false };

    Alchemy::NoShell {

    if(!res)
    {
      var request:URLRequest = new URLRequest(path);
      var loader:URLLoader = new URLLoader();
  
      loader.dataFormat = URLLoaderDataFormat.BINARY;
      loader.addEventListener(Event.COMPLETE, function(e:Event):void
      {
        statCache[path].data = loader.data;
        statCache[path].size = loader.data.length;
        statCache[path].pending = false;
      });
      loader.addEventListener(IOErrorEvent.IO_ERROR, function(e:Event):void
      {
        statCache[path].size = -1;
        statCache[path].pending = false;
      });

      statCache[path] = res = { pending: true };

      loader.load(request);
    }

    }

    return res;
  }

  public function access(path:int, mode:int):int
  {
    var spath:String = gstate.gworker.stringFromPtr(path);

    if(mode & ~4/*R_OK*/)
    {
log(3, "failed access(" + spath + ") mode(" + mode + ")");
      return -1;
    }

    var stat:Object = fetch(spath);

    if(stat.pending)
      throw(new AlchemyBlock);

log(3, "access(" + spath + "): " + (stat.size >= 0));

    if(stat.size < 0)
      return -1;

    return 0;
  }

  public function ioctl(fd:int, req:int, va:int):int
  {
    return -1;
  }

  public function open(path:int, flags:int, mode:int):int
  {
    var spath:String = gstate.gworker.stringFromPtr(path);

    if(flags != 0)
    {
log(3, "failed open(" + spath + ") flags(" + flags + ")");
      return -1;
    }

    var stat:Object = fetch(spath);

    if(stat.pending)
      throw(new AlchemyBlock);

    if(stat.size < 0)
    {
log(3, "failed open(" + spath + ") doesn't exist");
      return -1;
    }

    var n:int = 0;

    while(fds[n])
      n++;

    var io:ByteArrayIO = new ByteArrayIO();

    io.byteArray = new ByteArray();
    io.byteArray.writeBytes(stat.data);
    io.byteArray.position = 0;

    fds[n] = io;

log(4, "open(" + spath + "): " + io.size);
    return n;
  }

  public function close(fd:int):int
  {
    var r:int = fds[fd].close();
    fds[fd] = null;
    return r;
  }

  public function write(fd:int, buf:int, nbytes:int):int
  {
    return fds[fd].write(buf, nbytes);
  }

  public function read(fd:int, buf:int, nbytes:int):int
  {
    return fds[fd].read(buf, nbytes);
  }

  public function lseek(fd:int, offset:int, whence:int):int
  {
    var io:IO = fds[fd];

    if(whence == 0)
      io.position = offset;
    else if(whence == 1)
      io.position += offset;
    else if(whence == 2)
      io.position = io.size + offset;
    return io.position;
  }

  public function tell(fd:int):int
  {
    return fds[fd].position;
  }

  public function fsize(fd:int):int
  {
    return fds[fd].size;
  }

  public function psize(p:int):int
  {
    var path:String = gstate.gworker.stringFromPtr(p);
    var stat:Object = fetch(path);

    if(stat.pending)
      throw(new AlchemyBlock);

if(stat.size < 0)
  log(3, "psize(" + path + ") failed");
else
  log(3, "psize(" + path + "): " + stat.size);
    return stat.size;
  }
}


public const gstaticInitter:StaticInitter = new StaticInitter();

public function __addc(a:uint, b:uint):uint
{
  var s:uint = a + b;
  gstate.cf = uint(s < a);
  return s;
}

public function __subc(a:uint, b:uint):uint
{
  var s:uint = a - b;
  gstate.cf = uint(s > a);
  return s;
}

public function __adde(a:uint, b:uint):uint
{
  var s:uint = a + b + gstate.cf;
  gstate.cf = uint(s < a);
  return s;
}

public function __sube(a:uint, b:uint):uint
{
  var s:uint = a - b - gstate.cf;
  gstate.cf = uint(s > a);
  return s;
}


public function memcpy
  (dst:int, src:int, size:int):int
{
  if(size)
  {
    gstate.ds.position = dst;
    gstate.ds.writeBytes(gstate.ds, src, size);
  }
  return dst;
}

public function memmove
  (dst:int, src:int, size:int):int
{
 
 
  if(src > dst || (src + size) < dst)
    memcpy(dst, src, size);
  else
  {
    var cur:int = dst + size;
    src += size;
    while(size--)
      gstate.ds[--cur] = gstate.ds[--src];
  }
  return dst;
}

public function memset
  (dst:int, v:int, size:int):int
{
  var w:int = v | (v << 8) | (v << 16) | (v << 24);

 
  gstate.ds.position = dst;
  while(size >= 4)
  {
    gstate.ds.writeUnsignedInt(w);
    size -= 4;
  }
  while(size--)
    gstate.ds.writeByte(v);
  return dst;
}

public function _brk(addr:int):int
{
  var newLen:int = addr;

  gstate.ds.length = newLen;
  return 0;
}

public function _sbrk(incr:int):int
{
  var prior:int = gstate.ds.length;
  var newLen:int = prior + incr;

  gstate.ds.length = newLen;
  return prior;
}

const inf:Number = Number.POSITIVE_INFINITY;
const nan:Number = Number.NaN;

public function isinf(a:Number):int
{
  return int(a === Number.POSITIVE_INFINITY ||
  a === Number.NEGATIVE_INFINITY);
}
 
public function isnan(a:Number):int
{
   return int(a === Number.NaN);
}

public class Machine extends MemUser
{
 
 
  public static const dbgFileNames:Array = [];

 
 
  public static const dbgFuncs:Array = [];

 
 
  public static const dbgFuncNames:Array = [];

 
 
 
  public static const dbgLabels:Array = [];

 
 
 
  public static const dbgLocs:Array = [];

 
 
  public static const dbgScopes:Array = [];

 
 
  public static const dbgGlobals:Array = [];

 
  public static const dbgBreakpoints:Object = {};
 
  public static var dbgFrameBreakLow:int = 0;
  public static var dbgFrameBreakHigh:int = -1;

  public var state:int = 0;
  public var caller:Machine = gstate ? gstate.gworker : null;
  public var mstate:MState = caller ? caller.mstate : null;

  public function work():void
    { throw new AlchemyYield; }

  Alchemy::SetjmpAbuse
  public var freezeCache:int;
  Alchemy::SetjmpAbuse
  public static const intRegCount:int = 0;
  Alchemy::SetjmpAbuse
  public static const NumberRegCount:int = 0;

 
  public function get dbgFuncId():int { return -1; }
  public function get dbgFuncName():String { return dbgFuncNames[dbgFuncId]; }

 
  public var dbgLabel:int = 0;
  public var dbgLineNo:int = 0;
  public var dbgFileId:int = 0;
  public function get dbgFileName():String { return dbgFileNames[dbgFileId]; }
  public function get dbgLoc():Object
    { return { fileId: dbgFileId, lineNo: dbgLineNo }; }

 
  public function debugTraceMem(start:int, end:int):void
  {
    trace("");
    trace("*****");
    while(start <= end)
    {
      trace("* " + start + " : " + mstate._mr32(start));
      start += 4;
    }
    trace("");
  }

 
 
  public static function debugTraverseScope(scope:Object, label:int, f:Function):void
  {
    if(scope && label >= scope.startLabelId && label < scope.endLabelId)
    {
      f(scope);

      var scopes:Array = scope.scopes;

      for(var n:int = 0; n < scopes.length; n++)
        debugTraverseScope(scopes[n], label, f);
    }
  }

  public function debugTraverseCurrentScope(f:Function):void
  {
    debugTraverseScope(dbgScopes[dbgFuncId], dbgLabel, f);
  }

 
  public function debugLoc(fileId:int, lineNo:int):void
  {
   
   
    if(dbgFileId == fileId && dbgLineNo == lineNo)
      return;

    dbgFileId = fileId;
    dbgLineNo = lineNo;

    var locStr:String = fileId + ":" + lineNo;
    var bp:Object = dbgBreakpoints[locStr];

    if(bp && bp.enabled)
    {
      if(bp.temp)
        delete dbgBreakpoints[locStr];
      debugBreak(bp);
    }
    else if(dbgFrameBreakHigh >= dbgFrameBreakLow)
    {
      var curDepth:int = dbgDepth;

      if(curDepth >= dbgFrameBreakLow && curDepth <= dbgFrameBreakHigh)
        debugBreak(null);
    }
  }

  public function debugBreak(bp:Object):void
  {
    throw new AlchemyBreakpoint(bp);
  }
 
  public function debugLabel(label:int):void
  {
    dbgLabel = label;
  }

 
  public function get dbgDepth():int
  {
    var cur:Machine = this;
    var result:int;

    while(cur)
    {
      result++;
      cur = cur.caller;
    }
    return result;
  }

  public function get dbgTrace():String
  {
    return this.dbgFuncName + "(" + (this as Object).constructor + ") - " + this.dbgFileName + " : " + this.dbgLineNo + "(" + this.state + ")";
  }

  public static var sMS:uint;

  public function getSecsSetMS():uint
  {
    var time:Number = (new Date()).time;

    Machine.sMS = time % 1000;
    return time / 1000;
  }

 
  public function stringToPtr(addr:int, max:int, str:String):int
  {
    var w:int = str.length;

    if(max >= 0 && max < w)
      w = max;
    for(var i:int = 0; i < w; i++)
      mstate._mw8(addr++, str.charCodeAt(i));
    return w;
  }

  public function stringFromPtr(addr:int):String
  {
    var result:String = "";

    while(true)
    {
      var c:int = mstate._mru8(addr++);

      if(!c)
        break;
      result += String.fromCharCode(c);
    }
    return result;
  }

  public function backtrace():void
  {
    var cur:Machine = this;

    trace("");
    trace("*** backtrace");
    var framePtr:int = mstate.ebp;
    while(cur)
    {
      trace(cur.dbgTrace);

      cur.debugTraverseCurrentScope(
          function(scope:Object):void {
        trace("{{{");
        var vars:Array = scope.vars;
        for(var n:int = 0; n < vars.length; n += 2)
        {
         
          var descAddr:int = vars[n + 0];
         
          var nameAddr:int = mstate._mr32(descAddr + 8);
          var name:String = stringFromPtr(nameAddr);

          var frameOffset:int = vars[n + 1];

          trace("--- " + name + " (" + (frameOffset + framePtr) + ")");
        }
      });
      framePtr = mstate._mr32(framePtr);
      cur = cur.caller;
    }
    trace("");
  }

}





Alchemy::NoShell {

public var gtextField:TextField;
public var gsprite:Sprite;

}

Alchemy::Shell {

public var gsprite:Object;

}

public var grunner:Object;


public var genv:Object = {
  LANG: "en_US.UTF-8",
  TERM: "ansi"
};
public var gargs:Array = [
  "a.out"
];

public const gstate:MState


= new MState(new Machine);
const mstate:MState = gstate;





public const gsetjmpMachine2ESPMap:Dictionary = new Dictionary(true);

Alchemy::SetjmpAbuse
{

public const gsetjmpAbuseMap:Object = {};

public const gsetjmpFrozenMachineSet:Dictionary = new Dictionary(true);


public var gsetjmpFreezeIRCs:Object = {};
public var gsetjmpAbuseAlloc:Function;
public var gsetjmpAbuseFree:Function;
}

public const i__setjmp = exportSym("__setjmp", regFunc(FSM__setjmp.start));
public const i_setjmp = exportSym("_setjmp", i__setjmp);


function findMachineForESP(esp:int):Machine
{
  for (var mach:Object in gsetjmpMachine2ESPMap)
  {
    if(gsetjmpMachine2ESPMap[mach] == esp)
      return Machine(mach);
  }
  return null;
}

public class FSM__setjmp extends Machine
{
  public static function start():void
  {
    gstate.gworker = new FSM__setjmp;
    throw new AlchemyDispatch;
  }

  public override function work():void
  {
    mstate.pop();

    var buf:int = _mr32(mstate.esp);

    _mw32(buf + 0, 667788);
    _mw32(buf + 4, caller.state);
    _mw32(buf + 8, mstate.esp);
    _mw32(buf + 12, mstate.ebp);
    _mw32(buf + 16, 887766);

log(4, "setjmp: " + buf);
    var mach:Machine = findMachineForESP(mstate.esp);

    if(mach)
      delete gsetjmpMachine2ESPMap[mach];

    gsetjmpMachine2ESPMap[caller] = mstate.esp;

    Alchemy::SetjmpAbuse
    {
      var abuse:* = gsetjmpAbuseMap[buf];

      if(abuse)
        abuse.setjmp(buf);
    }

    mstate.gworker = caller;
    mstate.eax = 0;
  }
}

public const i__longjmp = exportSym("__longjmp", regFunc(FSM__longjmp.start));
public const i_longjmp = exportSym("_longjmp", i__longjmp);

public class FSM__longjmp extends Machine
{
  public static function start():void
  {
    gstate.gworker = new FSM__longjmp;
    throw new AlchemyDispatch;
  }

  public override function work():void
  {
    mstate.pop();
    var buf:int = _mr32(mstate.esp);
    var ret:int = _mr32(mstate.esp + 4);

log(4, "longjmp: " + buf);

    var istate:int = _mr32(buf + 4);
    var nesp:int = _mr32(buf + 8);
    var nebp:int = _mr32(buf + 12);
log(3, "longjmp -- buf: " + buf + " state: " + istate + " esp: " + nesp +
  " ebp: " + nebp);
    if(!buf || !nesp || !nebp)
      throw("longjmp -- bad jmp_buf");

    var mach:Machine = findMachineForESP(nesp);

    Alchemy::SetjmpAbuse
    {
      var abuse:* = gsetjmpAbuseMap[buf];

      if(abuse)
        mach = abuse.longjmp(buf, mach);
    }

    if(!mach)
    {
      debugTraceMem(buf - 24, buf + 24);
/*      for(var k:String in gsetjmpESP2MachineMap)
        log(3, k + " -> " + gsetjmpESP2MachineMap[k].dbgFuncName);
*/
      throw("longjmp -- bad esp");
    }

   
    delete gsetjmpMachine2ESPMap[mach];

    mstate.gworker = mach;
    mach.state = istate;
    mstate.esp = nesp;
    mstate.ebp = nebp;
    mstate.eax = ret;

    throw new AlchemyDispatch;
  }

}

public interface Debuggee
{
  function suspend():void;
  function resume():void;
  function get isRunning():Boolean;

  function cancelDebug():void;
}

Alchemy::NoShell
public class GDBMIDebugger
{
Alchemy::NoDebugger {
  public function GDBMIDEbugger(dbge:Debuggee) {}
}
Alchemy::Debugger {
  var sock:Socket;
  var debuggee:Debuggee;

  public function GDBMIDebugger(dbge:Debuggee)
  {
    sock = new Socket();
    debuggee = dbge;

    sock.addEventListener(flash.events.Event.CONNECT, sockConnect);
    sock.addEventListener(flash.events.ProgressEvent.SOCKET_DATA, sockData);
    sock.addEventListener(flash.events.IOErrorEvent.IO_ERROR, sockError);
    sock.addEventListener(flash.events.SecurityErrorEvent.SECURITY_ERROR,
      sockError);

    debuggee.suspend();
    try
    {
      sock.connect("localhost", 5678);
    }
    catch(e:*)
    {
      sockError(e);
    }
  }

  private function sockConnect(e:Event):void
  {
    log(2, "debugger connect");
    prompt();
  }

  private function sockError(e:*):void
  {
    log(2, "debugger socket error: " + e.toString());
    if(!debuggee.isRunning)
      debuggee.resume();
    debuggee.cancelDebug();
  }

  private var buffer:String = "";

  private function sockData(e:ProgressEvent):void
  {
    while(sock.bytesAvailable)
    {
      var ch:int = sock.readUnsignedByte();

      if(ch == 3)
      {
        if(debuggee.isRunning)
        {
          debuggee.suspend();
          broken(null);
        }
      }
      else
        buffer += String.fromCharCode(ch);
    }

    var cmds:Array = buffer.split(/\n/);

    for(var i:int = 0; i < cmds.length - 1; i++)
      command(cmds[i]);
    buffer = cmds[cmds.length - 1];
  }

  private function toMI(obj:*, outer:Boolean = true):String
  {
    if(typeof obj == "object")
    {
      var arr:Array = obj as Array;
      var first:Boolean = true;

      if(arr)
      {
        var result:String = outer ? "" : "[";

        for(var i:int = 0; i < arr.length; i++)
        {
          if(first)
            first = false;
          else
            result += ",";
          result += toMI(arr[i], false);
        }
        return outer ? result : (result + "]");
      }
      else
      {
        var result:String = "";
        var nkeys:int = 0;
        var keys:Array = (obj && obj.__order) ? obj.__order : null;

        if(!keys)
        {
          keys = [];
          for(var key:String in obj)
            keys.push(key);
        }
        for(var ki:int = 0; ki < keys.length; ki++)
        {
          if(first)
            first = false;
          else
            result += ",";
          var key:String = keys[ki];
          result += key + "=" + toMI(obj[key], false);
          nkeys++;
        }
        return (outer || nkeys == 1) ? result : ("{" + result + "}");
      }
    }
    else
      return toCString(obj.toString());
  }

  private function toCString(str:String):String
  {
     
      return "\"" + str.replace("\\", "\\\\")
        .replace("\"", "\\\"").replace("\r", "\\r").replace("\n", "\\n")
        + "\"";
  }

  private function respond(str:String, resp:String = "",
      rest:Object = null):void
  {
    var whole:String = str;

    if(resp)
    {
      whole += resp;
      if(rest)
        whole += "," + toMI(rest);
    }
    sock.writeUTFBytes(whole + "\n");
    sock.flush();
    log(2, "DBG> " + whole);
  }

  private var promptStr:String = "(gdb) ";

  private function prompt():void
  {
    respond(promptStr);
  }

  private function console(str:String):void
  {
    respond("~" + toCString(str));
  }

  private function done(id:String, rest:Object = null):void
  {
    respond(id, "^done", rest);
  }

  private function running(id:String, rest:Object = null):void
  {
    respond(id, "^running", rest);
  }

  private function stopped(id:String, rest:Object = null):void
  {
    respond(id, "*stopped", rest);
  }

  private function error(id:String, msg:String):void
  {
    respond(id, "^error", { msg: msg } );
  }

 
  private function findSymNum(sym:String):int
  {
    var symNames:Array = Machine.dbgFuncNames;

    for(var i:int = 1; i < symNames.length; i++)
      if(sym == symNames[i])
        return i;
    return 0;
  }

 
  private function findSymLoc(sym:String):Object
  {
    var num:int = findSymNum(sym);

    if(num)
    {
      var locs:Array = Machine.dbgLocs;

      for(var i:int = 0; i < locs.length; i += 4)
        if(locs[i + 2] == num)
          return { fileId: locs[i + 0], lineNo: locs[i + 1] };
    }
    return null;
  }

/* DEAD?
 
  private function findNextLoc(loc:Object):Object
  {
    var locs:Array = Machine.dbgLocs;

    for(var i:int = 0; i < locs.length - 4; i += 4)
      if(locs[i + 0] == loc.fileId && locs[i + 1] == loc.lineNo &&
          locs[i + 2] == locs[i + 6])
        return { fileId: locs[i + 4], lineNo: locs[i + 5] };
    return null;
  }
*/

  private var breakpointNum:int = 1;

  private function breakInsert(cmdId:String, paramStr:String):void
  {
    var params:Array = paramStr.split(/\s+/);
    var temp:Boolean = false;
    var sym:String = "";

    for(var i:int = 0; i < params.length; i++)
    {
     
      if(params[i] == "-t")
        temp = true;
      else
        sym = params[i];
    }

   
    var loc:Object = findSymLoc(sym);

    if(loc)
    {
      var bp:Object = { temp: temp, number: breakpointNum++, enabled: true };
      var locStr = loc.fileId + ":" + loc.lineNo;

      log(2, "debug break insert: " + locStr);
      Machine.dbgBreakpoints[locStr] = bp;
      done(cmdId, { bkpt:
        { number: bp.number, enabled: bp.enabled ? "y" : "n" }});
    }
    else
      error(cmdId, "Can't find: " + sym);
  }

  private function info(id:String, paramString:String):void
  {
    if(paramString == "sharedlibrary")
    {
      console("From        To          Syms Read    Shared Object Library\n");
      done(id);
    }
    else if(paramString == "threads")
    {
      console("* 1 thread 1\n");
      done(id);
    }
    else
      error(id, "No info for: " + paramString);
  }

 
  static const maxStack:int = 10000;

 
  private var selectedFrameNum:int = 0;

 
  private function getFrame(n:int):int
  {
    var ptr:int = gstate.ebp;

    for(var i:int = 0; i < n; i++)
      ptr = gstate.gworker._mr32(ptr);
    return ptr;
  }

 
 
  private function getFrameR(n:int):int
  {
    return getFrame(gstate.gworker.dbgDepth - n);
  }

 
  private function get selectedFrame():int
  {
    return getFrame(selectedFrameNum);
  }

 
  private function getMachine(n:int):Machine
  {
    var curMach:Machine = gstate.gworker;

    for(var i:int = 0; i < n; i++)
      curMach = curMach.caller;
    return curMach;
  }

 
 
  private function getMachineR(n:int):Machine
  {
    return getMachine(gstate.gworker.dbgDepth - n);
  }

 
  private function get selectedMachine():Machine
  {
    return getMachine(selectedFrameNum);
  }

  public function stackListLocals(id:String, paramString:String):void
  {
    var params:Array = paramString.split(/\s+/);
   
    var showValues:int = (params && params.length > 0) ? params[0] : 0;
    var curMach:Machine = selectedMachine;

    var locals:Array = [];

    curMach.debugTraverseCurrentScope(function(scope:Object):void {
        var vars:Array = scope.vars;
        for(var n:int = 0; n < vars.length; n += 2)
        {
         
          var descAddr:int = vars[n + 0];
         
          var nameAddr:int = curMach._mr32(descAddr + 8);
          var name:String = curMach.stringFromPtr(nameAddr);

          locals.push({ name: name });
        }
    });
    done(id, { locals: locals });
  }

  public function stackListArguments(id:String, paramString:String):void
  {
    var params:Array = paramString.split(/\s+/);
   
    var showValues:int = (params && params.length > 0) ? params[0] : 0;
    var lowFrame:int = (params && params.length > 1) ? params[1] : 0;
    var highFrame:int = (params && params.length > 2) ? params[2] : maxStack;
    var curFrame:int = lowFrame;
    var curMach:Machine = getMachine(lowFrame);

    var frames:Array = [];

    while(curMach && curFrame <= highFrame)
    {
     
      var frame:Object = {
        level: curFrame,
        args: []
      };
      frames.push({ frame: frame });
      curFrame++;
      curMach = curMach.caller;
    } 
    done(id, { "stack-args": frames });
  }

  public function stackListFrames(id:String, paramString:String):void
  {
    var params:Array = paramString.split(/\s+/);
    var lowFrame:int = (params && params.length > 0) ? params[0] : 0;
    var highFrame:int = (params && params.length > 1) ? params[1] : maxStack;
    var curFrame:int = lowFrame;
    var curMach:Machine = getMachine(lowFrame);

    var frames:Array = [];

    while(curMach && curFrame <= highFrame)
    {
     
      var frame:Object = {
        level: curFrame,
        addr: "0xffffffff",
        func: curMach.dbgFuncName,
        file: curMach.dbgFileName,
        line: curMach.dbgLineNo
      };
      frames.push({ frame: frame });
      curFrame++;
      curMach = curMach.caller;
    } 
    done(id, { stack: frames });
  }

  private function execStep(id:String, how:String):void
  {
    if(debuggee.isRunning)
      error(id, "Already running");
    else
    {
      var depth:int = gstate.gworker.dbgDepth;

      switch(how)
      {
      default:
      case "in":
        Machine.dbgFrameBreakLow = 0;
        Machine.dbgFrameBreakHigh = maxStack;
        break;
      case "over":
        Machine.dbgFrameBreakLow = 0;
        Machine.dbgFrameBreakHigh = depth;
        break;
      case "out":
        Machine.dbgFrameBreakLow = 0;
        Machine.dbgFrameBreakHigh = depth - 1;
        break;
      }
        
      debuggee.resume();
      running(id);
    }
  }

  private var vars:Object = {};

  private function varCreate(id:String, paramString:String):void
  {
   
    var params:Array = paramString.split(/\s+/);

   
    if(!params || params.length != 3 || params[0] != "-" || params[1] != "*")
      error(id, "Invalid var-create params: " + paramString);
    else
    {
      var vname:String = params[2];
      var curMach:Machine = selectedMachine;
     
      var rframe:int = curMach.dbgDepth
      var varDesc:Object;

      if(vname.charAt(0) == "$")
        varDesc = { name: vname }
      else
        curMach.debugTraverseCurrentScope(function(scope:Object):void{
          var vars:Array = scope.vars;
          for(var n:int = 0; n < vars.length; n += 2)
          {
           
            var descAddr:int = vars[n + 0];
           
            var nameAddr:int = curMach._mr32(descAddr + 8);
            var name:String = curMach.stringFromPtr(nameAddr);
  
            if(name == vname)
            {
              varDesc =
                { name: name, frameOffset: vars[n + 1], rframe: rframe };
            }
          }
      });

      if(varDesc)
      {
        var i:int = 0;
        var name:String;

        while(vars[(name = ("var" + i))])
          i++;

        vars[name] = varDesc;
       
        done(id, { name: name, numchild: 0, type: "int" });
      }
      else
        error(id, "var-create can't find: " + params[2]);
    }
  }

  private function varDelete(id:String, paramString:String):void
  {
    if(vars[paramString])
    {
      delete vars[paramString];
      done(id);
    }
    else
      error(id, "var-delete not tracking: " + paramString);
  }

  private function varUpdate(id:String, paramString:String):void
  {
    if(vars[paramString])
    {
      var varDesc:Object = vars[paramString];

     
     
      done(id, { changelist: [ {
        name: paramString,
        in_scope: true,
        type_changed: false,
        __order: ["name", "in_scope", "type_changed"]
      } ] });
    }
    else
      error(id, "var-update not tracking: " + paramString);
  }

  private function varEvaluateExpression(id:String, paramString:String):void
  {
    if(vars[paramString])
    {
      var varDesc:Object = vars[paramString];
      var value:String;

      if(varDesc.name.charAt(0) == "$")
      {
        var reg:String = varDesc.name.substr(1);
        var curMach:Machine = selectedMachine

        value = gstate.hasOwnProperty(reg) ? gstate[reg] :
          curMach.hasOwnProperty(reg) ? curMach[reg] : "-1";
      }
      else
        value = String(
          gstate.gworker._mr32(getFrameR(varDesc.rframe) + varDesc.frameOffset))
     
      done(id, {
        value: value
      });
    }
    else
      error(id, "var-evaluate-expression not tracking: " + paramString);
  }

  static const regNames:Array = [
    "state",
    "eax", "edx", "ebp", "esp", "st0", "cf",
    "i0", "i1", "i2", "i3", "i4", "i5", "i6", "i7",
    "i8", "i9", "i10", "i11", "i12", "i13", "i14", "i15",
    "i16", "i17", "i18", "i19", "i20", "i21", "i22", "i23",
    "i24", "i25", "i26", "i27", "i28", "i29", "i30", "i31"/*,
    "f0", "f1", "f2", "f3", "f4", "f5", "f6", "f7",
    "f8", "f9", "f10", "f11", "f12", "f13", "f14", "f15",
    "f16", "f17", "f18", "f19", "f20", "f21", "f22", "f23",
    "f24", "f25", "f26", "f27", "f28", "f29", "f30", "f31"
*/
  ];

  public function command(cmd:String):void
  {
    log(2, "DBG< " + cmd);
    var parse1:Array = /^(\d*)[- ](\S+)\s*(.*)/.exec(cmd);

    if(!parse1)
      error("", "Couldn't parse command");
    else
    {
      var cmdId:String = parse1[1];
      var cmdName:String = parse1[2];
      var paramString:String = parse1[3];

      switch(cmdName)
      {
     
      case "environment-cd":
      case "environment-directory":
      case "gdb-set":
       
        done(cmdId);
        break;
      case "gdb-exit":
        done(cmdId);
        sock.close();
        return;
      case "gdb-show":
        if(paramString == "prompt")
          done(cmdId, { value: promptStr });
        else
          error(cmdId, "Can't show: " + paramString);
        break;
      case "data-list-register-names":
        done(cmdId, { "register-names": regNames });
        break;
      case "data-list-changed-registers":
        done(cmdId, { "changed-registers": regNames.map(
          function(i:*, n:int, a:Array):int { return n; }
        )});
        break;
      case "info":
        info(cmdId, paramString);
        break;
      case "stack-select-frame":
       
        selectedFrameNum = int(paramString);
        done(cmdId);
        break;
      case "stack-info-depth":
        done(cmdId, { depth: gstate.gworker.dbgDepth });
        break;
      case "stack-list-frames":
        stackListFrames(cmdId, paramString);
        break;
      case "stack-list-arguments":
        stackListArguments(cmdId, paramString);
        break;
      case "stack-list-locals":
        stackListLocals(cmdId, paramString);
        break;
      case "exec-continue":
      case "exec-run":
        if(debuggee.isRunning)
          error(cmdId, "Already running");
        else
        {
          debuggee.resume();
          running(cmdId);
        }
        break;
      case "exec-next":
        execStep(cmdId, "over");
        break;
      case "exec-step":
        execStep(cmdId, "in");
        break;
      case "exec-finish":
        execStep(cmdId, "out");
        break;
      case "break-insert":
        breakInsert(cmdId, paramString);
        break;
      case "var-create":
        varCreate(cmdId, paramString);
        break;
      case "var-delete":
        varDelete(cmdId, paramString);
        break;
      case "var-update":
        varUpdate(cmdId, paramString);
        break;
      case "var-evaluate-expression":
        varEvaluateExpression(cmdId, paramString);
        break;
      default:
        error(cmdId, "Undefined MI command: " + cmdName);
        break;
      }
    }
    prompt();
  }

  public function signal(sig:Object):void
  {
   
    broken(null);
  }

  public function broken(bp:Object):void
  {
    log(2, "debugger broken");
    selectedFrameNum = 0;
    Machine.dbgFrameBreakLow = 0;
    Machine.dbgFrameBreakHigh = -1;
    stopped("");
    prompt();
  }
}
}


public class CRunner implements Debuggee
{
  Alchemy::NoShell
  var debugger:GDBMIDebugger;

  Alchemy::Shell
  var debugger:Object;

  Alchemy::NoShell
  var timer:Timer;

  var suspended:int = 0;
  var forceSyncSystem:Boolean;

  public function CRunner(_forceSyncSystem:Boolean = false)
  {
    if(grunner)
      log(1, "More than one CRunner!");
    grunner = this;
    forceSyncSystem = _forceSyncSystem;
  }

  public function cancelDebug():void
  {
    debugger = null;
  }

  public function get isRunning():Boolean
  {
    return suspended <= 0;
  }

  public function suspend():void
  {
    suspended++;

    Alchemy::NoShell {

    if(timer && timer.running)
      timer.stop();

    }
  }

  public function resume():void
  {
    if(!--suspended)
      startWork();
  }

  private function startWork():void
  {
    Alchemy::NoShell {

    if(!timer.running)
    {
      timer.delay = 1;
      timer.start();
    }

    }
  }

  Alchemy::Debugger
  private function startDebugger():void
  {
    Alchemy::NoShell {

    debugger = new GDBMIDebugger(this);

    }

    Alchemy::Shell {

      throw("No debug support in shell...");

    }
  }

  public function work():void
  {
    if(!isRunning)
      return;

    try
    {
      var startTime:Number = (new Date).time;

      while(true)
      {
        var checkInterval:int = 1000;
      

        while(checkInterval > 0)
        {
          try
          {
            while(checkInterval-- > 0)
              gstate.gworker.work();
          } catch(e:AlchemyDispatch) {}
        }
        if(((new Date).time - startTime) >= 1000 * 10)
          throw(new AlchemyYield);
      }
    }
    catch(e:AlchemyExit)
    {
      Alchemy::NoShell {

      timer.stop();

      }

      gstate.system.exit(e.rv);
    }
    catch(e:AlchemyYield)
    {
      Alchemy::NoShell {

      var ms:int = e.ms;

      timer.delay = (ms > 0 ? ms : 1);

      }
    }
    catch(e:AlchemyBlock)
    {
      Alchemy::NoShell {

     
      timer.delay = 10;

      }
    }
    catch(e:AlchemyBreakpoint)
    {
      Alchemy::Debugger
      {
        if(debugger)
        {
          suspend();
          debugger.broken(e.bp);
        }
        else
          throw(e);
      }
      Alchemy::NoDebugger
      {
        throw(e);
      }
    }
/*
    catch(e:AlchemyLibInit)
      { throw(e); }
    catch(e:*)
    {
      log(1, e);
      if(debugger && gstate && gstate.gworker)
      {
        suspend();
        debugger.signal(e);
      }
      else
      {
        if(gstate && gstate.gworker)
        {
          try {
            gstate.gworker.backtrace();
          } catch(e:*) {}
        }
        gstate.system.exit(-1);
        throw(e);
      }
    }
*/
  }

  public function rawAllocString(str:String):int
  {
    var result:int = gstate.ds.length;

    gstate.ds.length += str.length + 1;
    gstate.ds.position = result;
    for(var i:int = 0; i < str.length; i++)
      gstate.ds.writeByte(str.charCodeAt(i));
    gstate.ds.writeByte(0);
    return result;
  }

  public function rawAllocIntArray(arr:Array):int
  {
    var result:int = gstate.ds.length;

    gstate.ds.length += (arr.length + 1) * 4;
    gstate.ds.position = result;
    for(var i:int = 0; i < arr.length; i++)
      gstate.ds.writeInt(arr[i]);
    return result;
  }

  public function rawAllocStringArray(arr:Array):Array
  {
    var ptrs:Array = [];

    for(var i:int = 0; i < arr.length; i++)
      ptrs.push(rawAllocString(arr[i]));
    return ptrs;
  }

  public function createEnv(obj:Object):Array
  {
    var kvps:Array = [];

    for(var key:String in obj)
      kvps.push(key + "=" + obj[key]);

    return rawAllocStringArray(kvps).concat(0);
  }

  public function createArgv(arr:Array):Array
  {
    return rawAllocStringArray(arr).concat(0);
  }

  public function startSystem():void
  {
    Alchemy::NoShell {

    if(!forceSyncSystem)
    {
      var request:URLRequest = new URLRequest(".swfbridge");
      var loader:URLLoader = new URLLoader();
  
      loader.dataFormat = URLLoaderDataFormat.TEXT;
      loader.addEventListener(Event.COMPLETE, function(e:Event):void
      {
        var xml:XML = new XML(loader.data);
  
        if(xml && xml.name() == "bridge" && xml.host && xml.port)
          startSystemBridge(xml.host, xml.port);
        else
          startSystemLocal();
      });
      loader.addEventListener(IOErrorEvent.IO_ERROR, function(e:Event):void
      {
        startSystemLocal();
      });
      loader.load(request);
      return;
    }

    }

    startSystemLocal(true);
  }

 
  Alchemy::NoShell
  public function startSystemBridge(host:String, port:int):void
  {
log(3, "bridge: " + host + " port: " + port);
    gstate.system = new CSystemBridge(host, port);
    gstate.system.setup(startInit);
  }

 
 
  public function startSystemLocal(forceSync:Boolean = false):void
  {
log(3, "local system");
    gstate.system = new CSystemLocal(forceSync);
    gstate.system.setup(startInit);
  }

  public function startInit():void
  {
    log(2, "Static init...");
   
    modStaticInit();

    var args:Array = gstate.system.getargv();
    var env:Object = gstate.system.getenv();
    var argv:Array = createArgv(args);
    var envp:Array = createEnv(env);
    var startArgs:Array = [args.length].concat(argv, envp);
    var ap:int = rawAllocIntArray(startArgs);

   
    gstate.ds.length = (gstate.ds.length + 4095) & ~4095;

    gstate.push(ap);
    gstate.push(0);

    log(2, "Starting work...");

    Alchemy::NoShell {

    timer = new Timer(1);
    timer.addEventListener(flash.events.TimerEvent.TIMER, 
      function(event:TimerEvent):void { work() });

    }

    try
    {
      FSM__start.start();
    }
    catch(e:AlchemyExit)
    {
      gstate.system.exit(e.rv);
      return;
    }
    catch(e:AlchemyYield) {}
    catch(e:AlchemyDispatch) {}
    catch(e:AlchemyBlock) {}

    Alchemy::NoShell {
    Alchemy::Debugger {
    if(!forceSyncSystem)
    {
      startDebugger();
      return;
    }

    }
    }

    startWork();
  }
}



interface ICAllocator
{
  function alloc(size:int):int;
  function free(ptr:int):void;
}


class CHeapAllocator implements ICAllocator
{
  private var pmalloc:Function;
  private var pfree:Function;
  
  public function alloc(n:int):int
  {
    if(pmalloc == null)
      pmalloc = (new CProcTypemap(CTypemap.PtrType,
        [CTypemap.IntType])).fromC([_malloc]);
    var result:int = pmalloc(n);
    return result;
  }
  
  public function free(ptr:int):void
  {
    if(pfree == null)
      pfree = (new CProcTypemap(CTypemap.VoidType,
        [CTypemap.PtrType])).fromC([_free]);
    pfree(ptr);
  }
}




class CTypemap
{
  public static var BufferType:CBufferTypemap;
  public static var SizedStrType:CSizedStrUTF8Typemap;
  public static var AS3ValType:CAS3ValTypemap;

  public static var VoidType:CVoidTypemap;
  public static var PtrType:CPtrTypemap;
  public static var IntType:CIntTypemap;
  public static var DoubleType:CDoubleTypemap;
  public static var StrType:CStrUTF8Typemap;

  public static var IntRefType:CRefTypemap;
  public static var DoubleRefType:CRefTypemap;
  public static var StrRefType:CRefTypemap;
  
  public static function getTypeByName(name:String):CTypemap
  {
    return CTypemap[name];
  }

  public static function getTypesByNameArray(names:Array):Array
  {
    var result:Array = [];
    if(names)
      for each(var name:* in names)
        result.push(CTypemap.getTypeByName(name));
    return result;
  }

  public static function getTypesByNames(names:String):Array
  {
    return CTypemap.getTypesByNameArray(names.split(/\s*,\s*/));
  }

 
 
 
 
  public function get ptrLevel():int { return 0; }

 
 
  public function get typeSize():int { return 4; }
  
 
 
  public function getValueSize(v:*):int { return typeSize; }
  
 
  public function fromC(v:Array):* { return undefined; }
  
 
 
 
  public function createC(v:*, ptr:int = 0):Array { return null; }

 
  public function destroyC(v:Array):void { }
  
 
  public function fromReturnRegs(regs:Object):*
  {
    var a:Array = [regs.eax];
    var result:* = fromC(a);

    destroyC(a);
    return result;
  }

 
  public function toReturnRegs(regs:Object, v:*, ptr:int = 0):void
    { regs.eax = createC(v, ptr)[0]; }
  
 
  public function readValue(ptr:int):*
  {
   
    var a:Array = [];
    mstate.ds.position = ptr;
    for(var n:int = 0; n < typeSize; n++)
      a.push(mstate.ds.readInt());
    return fromC(a);
  }
  
 
  public function writeValue(ptr:int, v:*):void
  {
   
    var a:Array = createC(v);
    mstate.ds.position = ptr;
    for(var n:int = 0; n < a.length; n++)
      mstate.ds.writeInt(a[n]);
  }
}


class CVoidTypemap extends CTypemap
{
  public override function get typeSize():int { return 0; }

  public override function fromReturnRegs(regs:Object):* { return undefined; }
  public override function toReturnRegs(regs:Object, v:*, ptr:int = 0):void { }
}



class CAllocedValueTypemap extends CTypemap
{
  private var allocator:ICAllocator;
  
  public function CAllocedValueTypemap(_allocator:ICAllocator)
  {
    allocator = _allocator;
  }
  
  public override function fromC(v:Array):* { return readValue(v[0]); }

  public override function createC(v:*, ptr:int = 0):Array
  {
    if(!ptr)
      ptr = alloc(v);
    writeValue(ptr, v);
    return [ptr];
  }
  
  public override function destroyC(v:Array):void
  {
    free(v[0]);  
  }
  
  protected function alloc(v:*):int { return allocator.alloc(getValueSize(v)); }
  protected function free(ptr:int):void { return allocator.free(ptr); }
}


class CStrUTF8Typemap extends CAllocedValueTypemap
{
  public function CStrUTF8Typemap(allocator:ICAllocator = null)
  {
    if(!allocator)
      allocator =  new CHeapAllocator;
    super(allocator);  
  }
  
  public override function get ptrLevel():int { return 1; }

 
  protected function ByteArrayForString(s:String):ByteArray
  {
    var result:ByteArray = new ByteArray;

    result.writeUTFBytes(s);
    result.writeByte(0);
    result.position = 0;
    
    return result;
  }
  
  public override function getValueSize(v:*):int
  {
    return ByteArrayForString(String(v)).length;
  }
  
  public override function readValue(ptr:int):*
  {
    mstate.ds.position = ptr;

    var len:int = 0;
    
    while(mstate.ds.readByte() != 0)
      len++;
    mstate.ds.position = ptr;
    return mstate.ds.readUTFBytes(len);
  }
  
  public override function writeValue(ptr:int, v:*):void
  {
    ByteArrayForString(String(v)).readBytes(mstate.ds, ptr);
  }
}


class CIntTypemap extends CTypemap
{
  public override function fromC(v:Array):* { return int(v[0]); }
  public override function createC(v:*, ptr:int = 0):Array { return [int(v)]; }
}


class CPtrTypemap extends CTypemap
{
  public override function fromC(v:Array):* { return int(v[0]); }
  public override function createC(v:*, ptr:int = 0):Array { return [int(v)]; }
}



class CRefTypemap extends CTypemap
{
  private var subtype:CTypemap;

  public function CRefTypemap(_subtype:CTypemap)
  {
    subtype = _subtype;
  }

  public override function fromC(v:Array):*
  {
    var p:int = v[0];

    for(var n:int = 0; n < subtype.ptrLevel; n++)
    {
      mstate.ds.position = p;
      p = mstate.ds.readInt();
    }
    return subtype.readValue(p);
  }

  public override function createC(v:*, ptr:int = 0):Array { return null; }
}


class CSizedStrUTF8Typemap extends CTypemap
{
  public override function get typeSize():int { return 8; }
  
  public override function fromC(v:Array):*
  {
    mstate.ds.position = v[0];
    return mstate.ds.readUTFBytes(v[1]);
  }
}


class CDoubleTypemap extends CTypemap
{
  private var scratch:ByteArray;
  
  public function CDoubleTypemap()
  {
    scratch = new ByteArray;
    scratch.length = 8;
    scratch.endian = "littleEndian";  
  }
  
  public override function get typeSize():int { return 8; }
  
  public override function fromC(v:Array):*
  {
    scratch.position = 0;
    scratch.writeInt(v[0]);
    scratch.writeInt(v[1]);
    scratch.position = 0;
    return scratch.readDouble();
  }
  
  public override function createC(v:*, ptr:int = 0):Array
  {
    scratch.position = 0;
    scratch.writeDouble(v);
    scratch.position = 0;
    return [ scratch.readInt(), scratch.readInt() ];
  }
  
  public override function fromReturnRegs(regs:Object):* { return regs.st0; }
  public override function toReturnRegs(regs:Object, v:*, ptr:int = 0):void { regs.st0 = v; }
}

class RCValue
{
  public var value:*;
  public var id:int;
  public var rc:int = 1;

  public function RCValue(_value:*, _id:int) { value = _value; id = _id; }
}


class ValueTracker
{
 
  private var val2rcv:Dictionary = new Dictionary;
 
  private var id2key:Object = {};
  private var snum:int = 1;

  public function acquireId(id:int):int
  {
    if(id)
    {
      var key:Object = id2key[id];

      val2rcv[key].rc++;
    }
    return id;
  }

  public function acquire(val:*):int
  {
    if(typeof(val) == "undefined")
      return 0;

    var ov:Object = Object(val);

   
   
    if(ov instanceof QName)
      ov = "*VT*QName*/" + ov.toString();

    var v:* = val2rcv[ov];
    var id:int;

    if(typeof(v) == "undefined")
    {
      while(!snum || typeof(id2key[snum]) != "undefined")
        snum++;
      id = snum;
      val2rcv[ov] = new RCValue(val, id);
      id2key[id] = ov;
    }
    else
    {
      id = v.id;
      val2rcv[ov].rc++;
    }
    return id;
  }

  public function get(id:int):*
  {
    if(id)
    {
      var key:Object = id2key[id];
      var rcv:RCValue = val2rcv[key];

      return rcv.value;
    }
    return undefined;
  }

  public function release(id:int):*
  {
    if(id)
    {
      var key:Object = id2key[id];
      var rcv:RCValue = val2rcv[key];

      if(rcv)
      {
        if(!--rcv.rc)
        {
          delete id2key[id];
          delete val2rcv[key];
        }
        return rcv.value;
      }
      else
        log(1, "ValueTracker extra release!: " + id);
    }
    return undefined;
  }
}


class CAS3ValTypemap extends CTypemap
{
  private var values:ValueTracker = new ValueTracker;

  public function get valueTracker():ValueTracker
  {
    return values;
  }

  public override function fromC(v:Array):*
  {
    return values.get(v[0]);
  }
  
  public override function createC(v:*, ptr:int = 0):Array
  {
    return [values.acquire(v)];
  }
  
  public override function destroyC(v:Array):void
  {
    values.release(v[0]);
  }
}


class NotifyMachine extends Machine
{
  private var proc:Function;

  public function NotifyMachine(_proc:Function)
  {
    proc = _proc;
   
   
    mstate.push(0);
    mstate.push(mstate.ebp);
    mstate.ebp = mstate.esp;
  }
  
  public override function work():void
  {
    var noClean:Boolean;

    try
    {
      noClean = proc() ? true : false;
    }
    catch(e:*) { log(1, "NotifyMachine: " + e); }
    if(!noClean)
    {
      mstate.gworker = caller;
      mstate.ebp = mstate.pop();
      mstate.pop();
    }
  }
}

class CProcTypemap extends CTypemap
{
  private var retTypemap:CTypemap;
  private var argTypemaps:Array;
  private var varargs:Boolean;
  private var async:Boolean;
  
  public function CProcTypemap(_retTypemap:CTypemap, _argTypemaps:Array, _varargs:Boolean = false, _async:Boolean = false)
  {
    retTypemap = _retTypemap;
    argTypemaps = _argTypemaps;
    varargs = _varargs;
    async = _async;
  }
  
  private function push(arg:*):void
  {
    if(arg is Array)
      for(var i:int = arg.length - 1; i >= 0; i--)
        mstate.push(arg[i]);
    else
        mstate.push(arg);
  }
  
  public override function fromC(v:Array):*
  {
    return function(...args):*
    {
      var sp:int = mstate.esp;
      var cargs:Array = [];
      var n:int;
      var asyncHandler:Function;
      var oldWorker:Machine = mstate.gworker;
      
      function cleanup():void
      {
        for(n = cargs.length - 1; n >= 0; n--)
          argTypemaps[n].destroyC(cargs[n]);
  
        mstate.esp = sp;
        mstate.gworker = oldWorker;
      };
            
      if(async)
      {
       
        asyncHandler = args.shift();
       
        mstate.gworker = new NotifyMachine(function():Boolean
        {
          var result:* = retTypemap.fromReturnRegs(mstate);
          cleanup();
          try
          {
            asyncHandler(result);
          } catch(e:*) { log(1, "asyncHandler: " + e.toString()); }
          return true;
        });
      }

      for(n = args.length - 1; n >= 0; n--)
      {
        var arg:* = args[n];
        
        if(n >= argTypemaps.length)
          push(arg);
        else
        {
          var carg:Array = argTypemaps[n].createC(arg);
          
          cargs[n] = carg;
          push(carg);
        }
      }
      mstate.push(0);

      if(!asyncHandler)
      {
        try
        {
          try
          {
           
            mstate.funcs[int(v[0])]();
          }
          catch(e:AlchemyYield) {}
          catch(e:AlchemyDispatch) {}

         
          while(mstate.gworker !== oldWorker)
          {
            try
            {
              while(mstate.gworker !== oldWorker)
                mstate.gworker.work();
            }
            catch(e:AlchemyYield) {}
            catch(e:AlchemyDispatch) {}
          }
  
          return retTypemap.fromReturnRegs(mstate);        
        }
        finally
        {
          cleanup();
        }
      }
      else
      {
        try
        {
         
          mstate.funcs[int(v[0])]();
        }
        catch(e:AlchemyYield) {}
        catch(e:AlchemyDispatch) {}
        catch(e:AlchemyBlock) {}
        catch(e:*)
        {
          cleanup();
          throw(e);
        }
      }
    }
  }
  
  public override function createC(v:*, ptr:int = 0):Array
  {
    var id:int = regFunc(function():void
    {
      var args:Array = [];

      mstate.pop();
      
      var sp:int = mstate.esp;

     
      for(var n:int = 0; n < argTypemaps.length ; n++)
      {
        var tm:CTypemap = argTypemaps[n];
        var aa:Array = [];
        var ts:int = tm.typeSize;
      
       
        mstate.ds.position = sp;
       
        sp += ts;
       
        for(; ts; ts -= 4)
          aa.push(mstate.ds.readInt());
       
        args.push(tm.fromC(aa));
      }
     
     
      if(varargs)
        args.push(sp);

      try
      {
       
       
       
       
        retTypemap.toReturnRegs(mstate, v.apply(null, args));
      }
      catch(e:*)
      {
       
       
       
       
        mstate.eax = 0;
        mstate.edx = 0;
        mstate.st0 = 0;
        log(2, "v.apply: " + e.toString());
      }
    });
    return [id];
  }
  
  public override function destroyC(v:Array):void
  {
    unregFunc(int(v[0]));
  }
}


class CBuffer
{
  private static var ptr2Buffer:Object = {};

  public static function free(ptr:int):void
  {
    ptr2Buffer[ptr].free();
  }

  private var allocator:ICAllocator;
  private var ptrVal:int;
  private var sizeVal:int;
  private var valCache:*;

  public function get ptr():int { return ptrVal; }
  public function get size():int { return sizeVal; }

  public function get value():*
  {
    return ptrVal ? computeValue() : valCache;
  }

  public function set value(v:*):void
  {
    if(ptrVal)
      setValue(v);
    else
      valCache = v;
  }

  protected function computeValue():* { return undefined; }
  protected function setValue(v:*):void { }

  public function CBuffer(_size:int, _alloc:ICAllocator = null)
  {
    if(!_alloc)
      _alloc = new CHeapAllocator;
    allocator = _alloc;
    sizeVal = _size;
    alloc();
  }

  private function alloc():void
  {
    if(!ptrVal)
    {
      ptrVal = allocator.alloc(sizeVal);
      ptr2Buffer[ptrVal] = this;
    }
  }

  public function reset():void
  {
    if(!ptrVal)
    {
      alloc();
      setValue(valCache);
    }
  }

  public function free():void
  {
    if(ptrVal)
    {
      valCache = computeValue();
      allocator.free(ptrVal);
      delete ptr2Buffer[ptrVal];
      ptrVal = 0;
    }
  }
}


class CBufferTypemap extends CTypemap
{
  public override function createC(v:*, ptr:int = 0):Array
  {
    var buffer:CBuffer = v;

   
   
    buffer.reset();
    return [buffer.ptr];
  }

  public override function destroyC(v:Array):void
  {
    CBuffer.free(v[0]);
  }
}

class CStrUTF8Buffer extends CBuffer
{
  private var nullTerm:Boolean;

  protected override function computeValue():*
  {
    var len:int = 0;
    var max:int = this.size;

    mstate.ds.position = this.ptr;
    while(max-- && mstate.ds.readByte() != 0)
      len++;
    mstate.ds.position = this.ptr;
    return mstate.ds.readUTFBytes(len);
  }

  protected override function setValue(v:*):void
  {
    var ba:ByteArray = new ByteArray;
   
    var max:int = nullTerm ? this.size - 1 : this.size;

    ba.writeUTFBytes(v);
   
    if(ba.length > max)
      ba.length = max;
   
    if(ba.length < this.size)
      ba.writeByte(0);
   
    ba.position = 0;
    ba.readBytes(mstate.ds, this.ptr);
  }

  public function CStrUTF8Buffer(_size:int, _nullTerm:Boolean = true,
    alloc:ICAllocator = null)
  {
    super(_size, alloc);
    nullTerm = _nullTerm;
  }
}

CTypemap.BufferType = new CBufferTypemap;
CTypemap.SizedStrType = new CSizedStrUTF8Typemap;
CTypemap.AS3ValType = new CAS3ValTypemap;
CTypemap.VoidType = new CVoidTypemap;
CTypemap.PtrType = new CPtrTypemap;
CTypemap.IntType = new CIntTypemap;
CTypemap.DoubleType = new CDoubleTypemap;
CTypemap.StrType = new CStrUTF8Typemap;
CTypemap.IntRefType = new CRefTypemap(CTypemap.IntType);
CTypemap.DoubleRefType = new CRefTypemap(CTypemap.DoubleType);
CTypemap.StrRefType = new CRefTypemap(CTypemap.StrType);

const i_AS3_Acquire:int = exportSym("_AS3_Acquire",
  (new CProcTypemap(CTypemap.VoidType, [CTypemap.PtrType]))
  .createC(CTypemap.AS3ValType.valueTracker.acquireId)[0]
);

const i_AS3_Release:int = exportSym("_AS3_Release",
  (new CProcTypemap(CTypemap.VoidType, [CTypemap.PtrType]))
  .createC(CTypemap.AS3ValType.valueTracker.release)[0]
);

function AS3_NSGet(ns:*, prop:*):*
{
  var tns:String = typeof(ns);

  if(tns == "undefined" || !(ns instanceof Namespace))
  {
    if(tns == "string")
      ns = new Namespace(ns);
    else
      ns = new Namespace;
  }
  return ns::[prop];
}

const i_AS3_NSGet:int = exportSym("_AS3_NSGet",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.AS3ValType, CTypemap.AS3ValType]))
  .createC(AS3_NSGet)[0]
);

const i_AS3_NSGetS:int = exportSym("_AS3_NSGetS",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.AS3ValType, CTypemap.StrType]))
  .createC(AS3_NSGet)[0]
);

function AS3_TypeOf(v:*):String
{
  return typeof(v);
}

const i_AS3_TypeOf:int = exportSym("_AS3_TypeOf",
  (new CProcTypemap(CTypemap.StrType,
  [CTypemap.AS3ValType]))
  .createC(AS3_TypeOf)[0]
);

function AS3_NOP(v:*):*
{
  return v;
}

const i_AS3_String:int = exportSym("_AS3_String",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.StrType]))
  .createC(AS3_NOP)[0]
);

const i_AS3_StringN:int = exportSym("_AS3_StringN",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.SizedStrType]))
  .createC(AS3_NOP)[0]
);

const i_AS3_Int:int = exportSym("_AS3_Int",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.IntType]))
  .createC(AS3_NOP)[0]
);

const i_AS3_Ptr:int = exportSym("_AS3_Ptr",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.PtrType]))
  .createC(AS3_NOP)[0]
);

const i_AS3_Number:int = exportSym("_AS3_Number",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.DoubleType]))
  .createC(AS3_NOP)[0]
);

const i_AS3_True:int = exportSym("_AS3_True",
  (new CProcTypemap(CTypemap.AS3ValType,
  []))
  .createC(function():Boolean { return true; })[0]
);

const i_AS3_False:int = exportSym("_AS3_False",
  (new CProcTypemap(CTypemap.AS3ValType,
  []))
  .createC(function():Boolean { return false; })[0]
);

const i_AS3_Null:int = exportSym("_AS3_Null",
  (new CProcTypemap(CTypemap.AS3ValType,
  []))
  .createC(function():* { return null; })[0]
);

const i_AS3_Undefined:int = exportSym("_AS3_Undefined",
  (new CProcTypemap(CTypemap.AS3ValType,
  []))
  .createC(function():* { return undefined; })[0]
);

const i_AS3_StringValue:int = exportSym("_AS3_StringValue",
  (new CProcTypemap(CTypemap.StrType,
  [CTypemap.AS3ValType]))
  .createC(AS3_NOP)[0]
);

const i_AS3_IntValue:int = exportSym("_AS3_IntValue",
  (new CProcTypemap(CTypemap.IntType,
  [CTypemap.AS3ValType]))
  .createC(AS3_NOP)[0]
);

const i_AS3_PtrValue:int = exportSym("_AS3_PtrValue",
  (new CProcTypemap(CTypemap.PtrType,
  [CTypemap.AS3ValType]))
  .createC(AS3_NOP)[0]
);

const i_AS3_NumberValue:int = exportSym("_AS3_NumberValue",
  (new CProcTypemap(CTypemap.DoubleType,
  [CTypemap.AS3ValType]))
  .createC(AS3_NOP)[0]
);

function AS3_Get(obj:*, prop:*):*
{
  return obj[prop];
}

const i_AS3_Get:int = exportSym("_AS3_Get",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.AS3ValType, CTypemap.AS3ValType]))
  .createC(AS3_Get)[0]
);

const i_AS3_GetS:int = exportSym("_AS3_GetS",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.AS3ValType, CTypemap.StrType]))
  .createC(AS3_Get)[0]
);

function AS3_Set(obj:*, prop:*, val:*):void
{
  obj[prop] = val
}

const i_AS3_Set:int = exportSym("_AS3_Set",
  (new CProcTypemap(CTypemap.VoidType,
  [CTypemap.AS3ValType, CTypemap.AS3ValType, CTypemap.AS3ValType]))
  .createC(AS3_Set)[0]
);

const i_AS3_SetS:int = exportSym("_AS3_SetS",
  (new CProcTypemap(CTypemap.VoidType,
  [CTypemap.AS3ValType, CTypemap.StrType, CTypemap.AS3ValType]))
  .createC(AS3_Set)[0]
);

function AS3_Array(tt:String, sp:int):*
{
  var result:Array = [];

  if(!tt || !tt.length)
    return result;

  var a:Array = CTypemap.getTypesByNames(tt);

  for(var n:int = 0; n < a.length; n++)
  {
    var tm:CTypemap = a[n];
    var ts:int = tm.typeSize;
    var aa:Array = [];

    mstate.ds.position = sp;
    sp += ts;
    for(; ts; ts -= 4)
      aa.push(mstate.ds.readInt());
    result.push(tm.fromC(aa));
  }
  return result;
}

const i_AS3_Array:int = exportSym("_AS3_Array",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.StrType], true /*varargs*/))
  .createC(AS3_Array)[0]
);

function AS3_Object(tt:String, sp:int):*
{
  var result:Object = {};

  if(!tt || !tt.length)
    return result;

  var a:Array = tt.split(/\s*[,\:]\s*/);

  for(var n:int = 0; n < a.length; n+=2)
  {
    var name:String = a[n];
    var tm:CTypemap = CTypemap.getTypeByName(a[n+1]);
    var ts:int = tm.typeSize;
    var aa:Array = [];

    mstate.ds.position = sp;
    sp += ts;
    for(; ts; ts -= 4)
      aa.push(mstate.ds.readInt());
    result[name] = tm.fromC(aa);
  }
  return result;
}

const i_AS3_Object:int = exportSym("_AS3_Object",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.StrType], true /*varargs*/))
  .createC(AS3_Object)[0]
);

function AS3_Call(func:*, thiz:Object, params:Array):*
{
  return func.apply(thiz, params);
}

const i_AS3_Call:int = exportSym("_AS3_Call",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.AS3ValType, CTypemap.AS3ValType, CTypemap.AS3ValType]))
  .createC(AS3_Call)[0]
);

function AS3_CallS(func:String, thiz:Object, params:Array):*
{
  return thiz[func].apply(thiz, params);
}

const i_AS3_CallS:int = exportSym("_AS3_CallS",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.StrType, CTypemap.AS3ValType, CTypemap.AS3ValType]))
  .createC(AS3_CallS)[0]
);

function AS3_CallT(func:*, thiz:Object, tt:String, sp:int):*
{
  return func.apply(thiz, AS3_Array(tt, sp));
}

const i_AS3_CallT:int = exportSym("_AS3_CallT",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.AS3ValType, CTypemap.AS3ValType, CTypemap.StrType], true))
  .createC(AS3_CallT)[0]
);

function AS3_CallTS(func:String, thiz:Object, tt:String, sp:int):*
{
  return thiz[func].apply(thiz, AS3_Array(tt, sp));
}

const i_AS3_CallTS:int = exportSym("_AS3_CallTS",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.StrType, CTypemap.AS3ValType, CTypemap.StrType], true))
  .createC(AS3_CallTS)[0]
);

function AS3_Shim(func:Function, thiz:Object, rt:String, tt:String,
  varargs:Boolean):int
{
  var retType:CTypemap = CTypemap.getTypeByName(rt);
  var argTypes:Array = CTypemap.getTypesByNames(tt);
  var tm:CTypemap = new CProcTypemap(retType, argTypes, varargs);

  var id:int = tm.createC(function(...rest):*
  {
    return func.apply(thiz, rest);
  })[0];
  return id;
}

const i_AS3_Shim:int = exportSym("_AS3_Shim",
  (new CProcTypemap(CTypemap.PtrType,
  [CTypemap.AS3ValType, CTypemap.AS3ValType, CTypemap.StrType, CTypemap.StrType,
   CTypemap.IntType]))
  .createC(AS3_Shim)[0]
);

function AS3_New(constr:*, params:Array):*
{
  switch(params.length)
  {
  case 0:
    return new constr;
  case 1:
    return new constr(params[0]);
  case 2:
    return new constr(params[0], params[1]);
  case 3:
    return new constr(params[0], params[1], params[2]);
  case 4:
    return new constr(params[0], params[1], params[2], params[3]);
  case 5:
    return new constr(params[0], params[1], params[2], params[3], params[4]);
  }

  log(1, "New with too many params! (" + params.length + ")");
  return undefined;
}

const i_AS3_New:int = exportSym("_AS3_New",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.AS3ValType, CTypemap.AS3ValType]))
  .createC(AS3_New)[0]
);

function AS3_Function(data:int, func:Function):Function
{
  return function(...args):*
  {
    return func(data, args);
  }
}

const i_AS3_Function:int = exportSym("_AS3_Function",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.PtrType, 
    new CProcTypemap(CTypemap.AS3ValType,
    [CTypemap.PtrType, CTypemap.AS3ValType])
  ]))
  .createC(AS3_Function)[0]
);

function AS3_FunctionAsync(data:int, func:Function):Function
{
  return function(...args):*
  {
    var asyncHandler:Function = args.shift();

    return func(asyncHandler, data, args);
  }
}

const i_AS3_FunctionAsync:int = exportSym("_AS3_FunctionAsync",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.PtrType, 
    new CProcTypemap(CTypemap.AS3ValType,
    [CTypemap.PtrType, CTypemap.AS3ValType], false /*varargs*/, true /*async*/)
  ]))
  .createC(AS3_FunctionAsync)[0]
);

function AS3_FunctionT(data:int, func:int, rt:String, tt:String,
  varargs:Boolean):Function
{
  var tm:CTypemap = new CProcTypemap(CTypemap.getTypeByName(rt),
    CTypemap.getTypesByNames(tt), varargs);

  return AS3_Function(data, tm.fromC([func]));
}

const i_AS3_FunctionT:int = exportSym("_AS3_FunctionT",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.PtrType, CTypemap.PtrType, CTypemap.StrType, CTypemap.StrType,
   CTypemap.IntType
  ]))
  .createC(AS3_FunctionT)[0]
);

function AS3_FunctionAsyncT(data:int, func:int, rt:String, tt:String,
  varargs:Boolean):Function
{
  var tm:CTypemap = new CProcTypemap(CTypemap.getTypeByName(rt),
    CTypemap.getTypesByNames(tt), varargs, true);

  return AS3_FunctionAsync(data, tm.fromC([func]));
}

const i_AS3_FunctionAsyncT:int = exportSym("_AS3_FunctionAsyncT",
  (new CProcTypemap(CTypemap.AS3ValType,
  [CTypemap.PtrType, CTypemap.PtrType, CTypemap.StrType, CTypemap.StrType,
   CTypemap.IntType
  ]))
  .createC(AS3_FunctionAsyncT)[0]
);

function AS3_InstanceOf(val:*, type:Class):Boolean
{
  return val instanceof type;
}

const i_AS3_InstanceOf:int = exportSym("_AS3_InstanceOf",
  (new CProcTypemap(CTypemap.IntType,
  [CTypemap.AS3ValType, CTypemap.AS3ValType]))
  .createC(AS3_InstanceOf)[0]
);

function AS3_Stage():Object
{
  return gsprite ? gsprite.stage : null;
}

const i_AS3_Stage:int = exportSym("_AS3_Stage",
  (new CProcTypemap(CTypemap.AS3ValType, []))
  .createC(AS3_Stage)[0]
);



function AS3_ArrayValue(array:Array, tt:String, sp:int):void
{
  if(!tt || !tt.length)
    return;

  var a:Array = tt.split(/\s*,\s*/);

 
 
  for(var n:int = 0; n < a.length && n < array.length; n++)
  {
    var tm:CTypemap = CTypemap.getTypeByName(a[n]);

    mstate.ds.position = sp;

    var addr:int = mstate.ds.readInt();

    sp += 4;

    var aa:Array = tm.createC(array[n]);

    mstate.ds.position = addr;
    for(var i:int = 0; i < aa.length; i++)
      mstate.ds.writeInt(aa[i]);
  }
}

const i_AS3_ArrayValue:int = exportSym("_AS3_ArrayValue",
  (new CProcTypemap(CTypemap.VoidType,
  [CTypemap.AS3ValType, CTypemap.StrType], true /*varargs*/))
  .createC(AS3_ArrayValue)[0]
);

function AS3_ObjectValue(object:Object, tt:String, sp:int):void
{
  if(!tt || !tt.length)
    return;

  var a:Array = tt.split(/\s*[,\:]\s*/);

  for(var n:int = 0; n < a.length; n+=2)
  {
    var name:String = a[n];
    var tm:CTypemap = CTypemap.getTypeByName(a[n+1]);

    mstate.ds.position = sp;

    var addr:int = mstate.ds.readInt();

    sp += 4;

    var aa:Array = tm.createC(object[name]);

    mstate.ds.position = addr;
    for(var i:int = 0; i < aa.length; i++)
      mstate.ds.writeInt(aa[i]);
  }
}

const i_AS3_ObjectValue:int = exportSym("_AS3_ObjectValue",
  (new CProcTypemap(CTypemap.VoidType,
  [CTypemap.AS3ValType, CTypemap.StrType], true /*varargs*/))
  .createC(AS3_ObjectValue)[0]
);

Alchemy::NoShell {

public namespace flash_delegate =
  "http://www.adobe.com/2008/actionscript/flash/delegate";


public dynamic class DynamicProxy extends Proxy
{
  flash_proxy override function callProperty(name:*, ...rest):*
  {
    return this.flash_delegate::callProperty(name, rest);
  }

  flash_proxy override function deleteProperty(name:*):Boolean
  {
    return this.flash_delegate::deleteProperty(name);
  }

  flash_proxy override function getDescendants(name:*):*
  {
    return this.flash_delegate::getDescendants(name);
  }

  flash_proxy override function getProperty(name:*):*
  {
    return this.flash_delegate::getProperty(name);
  }

  flash_proxy override function hasProperty(name:*):Boolean
  {
    return this.flash_delegate::hasProperty(name);
  }

  flash_proxy override function isAttribute(name:*):Boolean
  {
    return this.flash_delegate::isAttribute(name);
  }

  flash_proxy override function nextName(index:int):String
  {
    return this.flash_delegate::nextName(index);
  }

  flash_proxy override function nextNameIndex(index:int):int
  {
    return this.flash_delegate::nextNameIndex(index);
  }

  flash_proxy override function nextValue(index:int):*
  {
    return this.flash_delegate::nextValue(index);
  }

  flash_proxy override function setProperty(name:*, value:*):void
  {
    this.flash_delegate::setProperty(name, value);
  }

  flash_delegate var callProperty:Function;
  flash_delegate var deleteProperty:Function;
  flash_delegate var getDescendants:Function;
  flash_delegate var getProperty:Function;
  flash_delegate var hasProperty:Function;
  flash_delegate var isAttribute:Function;
  flash_delegate var nextName:Function;
  flash_delegate var nextNameIndex:Function;
  flash_delegate var nextValue:Function;
  flash_delegate var setProperty:Function;
}

function AS3_Proxy():*
{
  return new DynamicProxy();
}

}

Alchemy::Shell {

function AS3_Proxy():*
{
  return null;
}

}

const i_AS3_Proxy:int = exportSym("_AS3_Proxy",
  (new CProcTypemap(CTypemap.AS3ValType,
  [], false /*varargs*/))
  .createC(AS3_Proxy)[0]
);

function AS3_Ram():ByteArray
{
  return gstate.ds;
}

const i_AS3_Ram:int = exportSym("_AS3_Ram",
  (new CProcTypemap(CTypemap.AS3ValType,
  [], false /*varargs*/))
  .createC(AS3_Ram)[0]
);

function AS3_ByteArray_readBytes(ptr:int, ba:ByteArray, len:int):int
{
  if(len > 0)
  {
    if ( ba.bytesAvailable < len )
      len = ba.bytesAvailable
    ba.readBytes(gstate.ds, ptr, len);
    return len;
  }
  return 0;
}

const i_AS3_ByteArray_readBytes:int = exportSym("_AS3_ByteArray_readBytes",
  (new CProcTypemap(CTypemap.IntType,
  [CTypemap.IntType, CTypemap.AS3ValType, CTypemap.IntType],
  false /*varargs*/))
  .createC(AS3_ByteArray_readBytes)[0]
);

function AS3_ByteArray_writeBytes(ba:ByteArray, ptr:int, len:int):int
{
log(5, "--- wrteBytes: ba length = " + ba.length + " / " + len);
  if(len > 0)
  {
    ba.writeBytes(gstate.ds, ptr, len);
    return len;
  }
  return 0;
}

const i_AS3_ByteArray_writeBytes:int = exportSym("_AS3_ByteArray_writeBytes",
  (new CProcTypemap(CTypemap.IntType,
  [CTypemap.AS3ValType, CTypemap.IntType, CTypemap.IntType],
  false /*varargs*/))
  .createC(AS3_ByteArray_writeBytes)[0]
);

function AS3_ByteArray_seek(ba:ByteArray, offs:int, whence:int):int
{
  if(whence == 0)
    ba.position = offs;
  else if(whence == 1)
    ba.position += offs;
  else if(whence == 2)
    ba.position = ba.length + offs;
  else
    return -1;
  return ba.position;
}

const i_AS3_ByteArray_seek:int = exportSym("_AS3_ByteArray_seek",
  (new CProcTypemap(CTypemap.IntType,
  [CTypemap.AS3ValType, CTypemap.IntType, CTypemap.IntType],
  false /*varargs*/))
  .createC(AS3_ByteArray_seek)[0]
);

const i_AS3_Trace:int = exportSym("_AS3_Trace",
  (new CProcTypemap(CTypemap.VoidType,
  [CTypemap.AS3ValType],
  false /*varargs*/))
  .createC(trace)[0]
);

Alchemy::SetjmpAbuse
{

/* freeze/thaw support for generic machines and stacks of machines...

** a frozen machine is comprised of:
** [int] reference count
** [int] CTypemap.AS3ValType.valueTracker id for the machine's class
** [int[]] integral registers
** [double[]] double registers

** a frozen stack is a NULL-terminate array of pointers to frozen machines

*/

function acquireFreeze(ptr:int):void
{
log(4, "acquireFreeze(" + ptr + ")");
  mstate.ds.position = ptr;
  var rc:int = mstate.ds.readInt();
  mstate.ds.position = ptr;
  mstate.ds.writeInt(rc+1);
}

function releaseFreeze(ptr:int, free:Function):void
{
log(4, "releaseFreeze(" + ptr + ")");
  mstate.ds.position = ptr;
  var rc:int = mstate.ds.readInt();
  if(rc == 1)
  {
log(4, "releaseFreeze free");
    mstate.ds.position = ptr + 4;

    var classId:int = mstate.ds.readInt();

    free(ptr);
    CTypemap.AS3ValType.valueTracker.release(classId);
  }
  else
  {
    mstate.ds.position = ptr;
    mstate.ds.writeInt(rc-1);
  }
}

function sweepFreezes(free:Function):void
{

  var newFreezeSet:Object = {};
  var oldFreezeSet:Object = gsetjmpFreezeIRCs;

  for (var mach:Object in gsetjmpFrozenMachineSet)
  {
    var ptr:int = mach.freezeCache;

    if(ptr)
    {
      newFreezeSet[ptr] = oldFreezeSet[ptr];
      delete oldFreezeSet[ptr];
    }
  }
  for(var aptr:* in oldFreezeSet)
  {
    var count:int = oldFreezeSet[aptr];

    while(count--)
      releaseFreeze(aptr, free);
  }
  gsetjmpFreezeIRCs = newFreezeSet;
}

function freezeMachine(mach:Machine, alloc:Function):int
{
  try
  {
   
    var cache:int = mach.freezeCache;

    if(cache)
    {
      acquireFreeze(cache);

      return cache;
    }

   
    var clazz:Object = Object(mach).constructor;
    var size:int = 12 + clazz.intRegCount * 4 + clazz.NumberRegCount * 8;
    var ptr:int = alloc(size);

log(4, "freezeMachine 1: " + clazz);

    gsetjmpFreezeIRCs[ptr] += 1;
    gsetjmpFrozenMachineSet[mach] = 1;
   
   
    mach.freezeCache = ptr;
    mstate.ds.position = ptr;
    mstate.ds.writeInt(1);
    mstate.ds.writeInt(
      CTypemap.AS3ValType.valueTracker.acquire(clazz));
    mstate.ds.writeInt(mach.state);

   
    var i:int;

    for(i = clazz.intRegCount - 1; i >= 0; i--)
      mstate.ds.writeInt(mach["i" + i]);
    for(i = clazz.NumberRegCount - 1; i >= 0; i--)
      mstate.ds.writeDouble(mach["f" + i]);

log(4, "freezeMachine 2: " + clazz);

    return ptr;
  } catch(e:*) {}
  return 0;
}

function thawMachine(ptr:int):Machine
{
log(4, "thawMachine start (" + ptr + ")");
  mstate.ds.position = ptr + 4;

  var classId:int = mstate.ds.readInt();
log(4, "thawMachine cid: " + classId);
  var clazz:* = CTypemap.AS3ValType.valueTracker.get(classId);
  var mach:Machine = Machine(new clazz());
  
log(4, "thawMachine " + clazz);

  mach.state = mstate.ds.readInt();

log(4, "thawMachine state: " + mach.state);

 
  var i:int;

  for(i = clazz.intRegCount - 1; i >= 0; i--)
    mach["i" + i] = mstate.ds.readInt();
  for(i = clazz.NumberRegCount - 1; i >= 0; i--)
    mach["f" + i] = mstate.ds.readDouble();
log(4, "thawMachine regs");
  acquireFreeze(ptr);
  gsetjmpFreezeIRCs[ptr] += 1;
  gsetjmpFrozenMachineSet[mach] = 1;
  mach.freezeCache = ptr;
  return mach;
}

function freeStack(ptr:int, free:Function):void
{
  mstate.ds.position = ptr;

  var frame:int;

  while((frame = mstate.ds.readInt()) != 0)
  {
    releaseFreeze(frame, free);
    ptr += 4;
    mstate.ds.position = ptr;
  }
  free(ptr);
}

function freezeStack(alloc:Function):int
{
  var frames:Array = [];
  var mach:Machine = mstate.gworker.caller;
  var frame:int;

log(4, "freezeStack");

  while((frame = freezeMachine(mach, alloc)) != 0)
  {
log(4, "freezeStack: " + frame);
    acquireFreeze(frame);
    frames.push(frame);
    mach = mach.caller;
  }

  var ptr:int = alloc(4 + frames.length * 4);

  mstate.ds.position = ptr;
  for(var i:int = 0; i < frames.length; i++)
    mstate.ds.writeInt(frames[i]);
  mstate.ds.writeInt(0);
log(4, "freezeStack= " + ptr);
  return ptr;
}

function thawStack(ptr:int, curMach:Machine):Machine
{
  var mach:Machine = null;
  var firstMach:Machine = null;

  mstate.ds.position = ptr;

  var frame:int;

log(4, "thawStack(" + ptr + ")");
  while((frame = mstate.ds.readInt()) != 0)
  {
   
    var curMachOk:Boolean = (curMach && frame == curMach.freezeCache);
    var newMach:Machine;

    if(curMachOk)
      newMach = curMach;
    else
      newMach = thawMachine(frame);

log(4, "thawMachine(" + frame + ")");
    newMach.mstate = mstate;
    if(mach)
      mach.caller = newMach;
    if(!firstMach)
      firstMach = newMach;
   
/*    if(curMachOk)
      return firstMach;*/
    mach = newMach;
    ptr += 4;
    mstate.ds.position = ptr;
    if(curMach)
      curMach = curMach.caller;
  }
  if(mach)
    mach.caller = null;
  return firstMach;
}

}

function AS3_Reg_jmp_buf_AbuseHelpers(alloc:Function, free:Function):void
{
  Alchemy::SetjmpAbuse
  {
    gsetjmpAbuseAlloc = alloc;
    gsetjmpAbuseFree = free;
  }
}

function AS3_RegAbused_jmp_buf(ptr:int):void
{
log(4, "regAbused: " + ptr);
  Alchemy::SetjmpAbuse
  {
   
    gsetjmpAbuseMap[ptr] = {
      alloc: gsetjmpAbuseAlloc,
      free: gsetjmpAbuseFree,
     
      setjmp: function(ptr:int):void
      {
        var abuseObj:Object = gsetjmpAbuseMap[ptr];

        abuseObj.stack = freezeStack(abuseObj.alloc);
        sweepFreezes(abuseObj.free);
      },
     
      longjmp: function(ptr:int, mach:Machine):Machine
      {
        var abuseObj:Object = gsetjmpAbuseMap[ptr];

        return thawStack(abuseObj.stack, mach);
      },
      cleanup: function(ptr:int):void
      {
        var abuseObj:Object = gsetjmpAbuseMap[ptr];

        freeStack(abuseObj.stack, abuseObj.free);
      }
    };
    return;
  }
  log(1, "Can't RegAbused -- abuse support disabled");
}

function AS3_UnregAbused_jmp_buf(ptr:int):void
{
log(4, "unregAbused: " + ptr);
  Alchemy::SetjmpAbuse
  {
    gsetjmpAbuseMap[ptr].cleanup(ptr);
    delete gsetjmpAbuseMap[ptr];
    return;
  }
  log(1, "Can't UnregAbused -- abuse support disabled");
}

const i_AS3_Reg_jmp_buf_AbuseHelpers:int =
exportSym("_AS3_Reg_jmp_buf_AbuseHelpers",
  (new CProcTypemap(CTypemap.VoidType, [
    (new CProcTypemap(CTypemap.PtrType, [CTypemap.IntType])),
    (new CProcTypemap(CTypemap.VoidType, [CTypemap.PtrType]))
  ],
  false /*varargs*/))
  .createC(AS3_Reg_jmp_buf_AbuseHelpers)[0]
);


const i_AS3_RegAbused_jmp_buf:int = exportSym("_AS3_RegAbused_jmp_buf",
  (new CProcTypemap(CTypemap.VoidType,
  [CTypemap.PtrType],
  false /*varargs*/))
  .createC(AS3_RegAbused_jmp_buf)[0]
);

const i_AS3_UnregAbused_jmp_buf:int = exportSym("_AS3_UnregAbused_jmp_buf",
  (new CProcTypemap(CTypemap.VoidType,
  [CTypemap.PtrType],
  false /*varargs*/))
  .createC(AS3_UnregAbused_jmp_buf)[0]
);


Alchemy::NoShell
public class ConSprite extends Sprite
{
  private var runner:CRunner = new CRunner;

  public function ConSprite()
  {
    if(gsprite)
      log(1, "More than one sprite!");

    gsprite = this;

    runner.startSystem();
  }
}


Alchemy::NoShell
public class CLibDummySprite extends Sprite
{
}


Alchemy::Shell
public class ShellCon
{
  private var runner:CRunner = new CRunner;

  public function ShellCon()
  {
    runner.startSystem();
  }

  public function work():void
  {
    runner.work();
  }
}

Alchemy::NoShell
public class CLibInit
{
  public function supplyFile(path:String, data:ByteArray):void
  {
    gfiles[path] = data;
  }

  public function putEnv(key:String, value:String):void
  {
    genv[key] = value;
  }

  public function setSprite(sprite:Sprite):void
  {
    gsprite = sprite;
  }

  public function init():*
  {
    var runner:CRunner = new CRunner(true);
    var result:*;
    var saveState:MState = new MState(null);

   
    mstate.copyTo(saveState);

    var regged:Boolean;

    try
    {
     
      runner.startSystem();
      while(true)
      {
        try
        {
          while(true)
            runner.work();
        }
        catch(e:AlchemyDispatch) {}
        catch(e:AlchemyYield) {}
      }
    }
    catch(e:AlchemyLibInit)
    {
      log(3, "Caught AlchemyLibInit " + e.rv);
      regged = true;
      result = CTypemap.AS3ValType.valueTracker.release(e.rv);
    }
    finally
    {
     
      saveState.copyTo(mstate);
     
      if(!regged)
        log(1, "Lib didn't register");
    }
    return result;
  }
}

Alchemy::Shell {

public function modEnd():void
{
  var ns:Namespace = new Namespace("avmshell");
  var sys:Object = ns::["System"];

  gargs = gargs.concat(sys.argv);

  var shellCon:ShellCon = new ShellCon();



  while(true)
  {


    shellCon.work();
  }
}

}

Alchemy::NoShell {

public function modEnd():void
{
}

}


Alchemy::NoShell {

public var gvglbmd:BitmapData;
public var gvglbm:Bitmap;
public var gvglpixels:int;

} // Alchemy::NoShell

public function vgl_lock():void
{
  // nop
}

public function vgl_unlock():void
{
  Alchemy::NoShell {

  // blit!
  if(gvglbmd && gvglpixels)
  {
    gstate.ds.position = gvglpixels;
    gvglbmd.setPixels(gvglbmd.rect, gstate.ds);
  }

  } // Alchemy::NoShell
}

public function vgl_end(dummy:int):int
{
  Alchemy::NoShell {

  var pixels:int = gvglpixels;
  gvglpixels = 0;
  return pixels;

  } // Alchemy::NoShell
  return 0;
}

public var vglKeys:Array = [];
public var vglKeyFirst:Boolean = true;
public var vglKeyUEL:*;
// mode...
// 1: VGL_RAWKEYS
// 2: VGL_CODEKEYS
// 3: VGL_XLATEKEYS
public var vglKeyMode:int;

public function vgl_keyinit(mode:int):int
{
  trace("vgl_keymode: " + mode);
  vglKeyMode = mode;
  return 0;
}

public function vgl_keych():int
{
  if(vglKeys.length)
    return vglKeys.shift();
  return 0;
}

public function vgl_init(width:int, height:int, pixels:int):int
{
  Alchemy::NoShell {

  var stage:Stage = gsprite.stage;

trace("vgl_init: " + width + " / " + height + " : " + pixels);
  if(vglKeyFirst)
  {
    // windows VK_ (keyCode) => scan code
    var vk2scan:Array = [
      0, 0, 0, 70, 0, 0, 0, 0, 14, 15, 0, 0, 76, 28, 0, 0, 
      42, 29, 56, 0, 58, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 
      57, 73, 81, 79, 71, 75, 72, 77, 80, 0, 0, 0, 84, 82, 83, 99, 
      11, 2, 3, 4, 5, 6, 7, 8, 9, 10, 0, 0, 0, 0, 0, 0, 
      0, 30, 48, 46, 32, 18, 33, 34, 35, 23, 36, 37, 38, 50, 49, 24, 
      25, 16, 19, 31, 20, 22, 47, 17, 45, 21, 44, 91, 92, 93, 0, 95, 
      82, 79, 80, 81, 75, 76, 77, 71, 72, 73, 55, 78, 0, 74, 83, 53, 
      59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 87, 88, 100, 101, 102, 103, 
      104, 105, 106, 107, 108, 109, 110, 118, 0, 0, 0, 0, 0, 0, 0, 0, 
      69, 70, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
      42, 54, 29, 29, 56, 56, 106, 105, 103, 104, 101, 102, 50, 32, 46, 48, 
      25, 16, 36, 34, 108, 109, 107, 33, 0, 0, 39, 13, 51, 12, 52, 53, 
      41, 115, 126, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 26, 43, 27, 40, 0, 
      0, 0, 86, 0, 0, 0, 0, 0, 0, 113, 92, 123, 0, 111, 90, 0, 
      0, 91, 0, 95, 0, 94, 0, 0, 0, 93, 0, 98, 0, 0, 0, 0
    ];
    stage.addEventListener(KeyboardEvent.KEY_DOWN,
      function(event:KeyboardEvent)
      {
        var sc:int = (vglKeyMode == 2) ?
          vk2scan[event.keyCode & 0x7f] : event.charCode;

        vglKeys.push(sc);
      });
    stage.addEventListener(KeyboardEvent.KEY_UP,
      function(event:KeyboardEvent)
      {
        var sc:int = (vglKeyMode == 2) ?
          vk2scan[event.keyCode & 0x7f] : event.charCode;
  
        if(vglKeyMode == 2)
        {
          vglKeys.push(sc | 0x80);
        }
      });
    vglKeys.push(69); // push NUMLOCK so SDL thinks we're using the keypad...
    stage.focus = stage;
    vglKeyFirst = false;
  }
  gvglpixels = pixels;
  gvglbmd = new BitmapData(Math.abs(width), Math.abs(height), false);
  if(!gvglbm)
  {
    gvglbm = new Bitmap();
    gsprite.addChild(gvglbm);
  }
  gvglbm.bitmapData = gvglbmd;
  gvglbm.scaleX = gsprite.stage.stageWidth / width;
  gvglbm.scaleY = gsprite.stage.stageHeight / height;
trace("vgl_init done");

  } // Alchemy::NoShell

  return 0;
}

public var vglMouseFirst:Boolean = true;
public var vglMouseButtons:int;

function vgl_mouse_x():int
{
  Alchemy::NoShell {

  var stage:Stage = gsprite.stage;

  return stage.mouseX;

  } // Alchemy::NoShell

  return 0;
}

function vgl_mouse_y():int
{
  Alchemy::NoShell {

  var stage:Stage = gsprite.stage;

  return stage.mouseY;

  } // Alchemy::NoShell

  return 0;
}

function vgl_mouse_buttons():int
{
  Alchemy::NoShell {

  if(vglMouseFirst)
  {
    var stage:Stage = gsprite.stage;

    stage.addEventListener(MouseEvent.MOUSE_DOWN,
      function(event:MouseEvent)
      {
        vglMouseButtons = 1;
      });
    stage.addEventListener(MouseEvent.MOUSE_UP,
      function(event:MouseEvent)
      {
        vglMouseButtons = 0;
      });
    vglMouseFirst = false;
  }

  } // Alchemy::NoShell

  return vglMouseButtons;
}



// End of file scope inline assembly


// Sync
public const __fini:int = regFunc(FSM__fini.start)

public final class FSM__fini extends Machine {

	public static function start():void {
		var i0:int, i1:int


		__asm(label, lbl("__fini_entry"))
	__asm(lbl("__fini__XprivateX__BB1_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  (__2E_str)
		i1 =  (4)
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___error:int = regFunc(FSM___error.start)

public final class FSM___error extends Machine {

	public static function start():void {
		var i0:int


		__asm(label, lbl("___error_entry"))
	__asm(lbl("___error__XprivateX__BB2_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  (_val_2E_1440)
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Async
public const _ioctl:int = regFunc(FSM_ioctl.start)

public final class FSM_ioctl extends Machine {

	public static function start():void {
			var result:FSM_ioctl = new FSM_ioctl
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int

	public static const intRegCount:int = 4

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("_ioctl_entry"))
		__asm(push(state), switchjump(
			"_ioctl_errState",
			"_ioctl_state0",
			"_ioctl_state1",
			"_ioctl_state2"))
	__asm(lbl("_ioctl_state0"))
	__asm(lbl("_ioctl__XprivateX__BB3_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 4
		i0 =  (mstate.ebp + 12)
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		__asm(push(i0), push((mstate.ebp+-4)), op(0x3c))
		i0 =  ((mstate.ebp+-4))
		__asm(push(i1!=0), iftrue, target("_ioctl__XprivateX__BB3_2_F"))
	__asm(lbl("_ioctl__XprivateX__BB3_1_F"))
		i1 =  (___sF)
		mstate.esp -= 12
		i0 =  (__2E_str7403)
		i2 =  (1076655123)
		i1 =  (i1 + 176)
		__asm(push(i1), push(mstate.esp), op(0x3c))
		__asm(push(i0), push((mstate.esp+4)), op(0x3c))
		__asm(push(i2), push((mstate.esp+8)), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM_fprintf.start()
		return
	__asm(lbl("_ioctl_state1"))
		mstate.esp += 12
		i1 =  (-1)
		mstate.eax = i1
		__asm(jump, target("_ioctl__XprivateX__BB3_3_F"))
	__asm(lbl("_ioctl__XprivateX__BB3_2_F"))
		i2 =  (1076655123)
		i3 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i0 = i1
		i1 = i2
		i2 = i3
				state = 2
	__asm(lbl("_ioctl_state2"))
//InlineAsmStart
	i0 =  mstate.system.ioctl(i0, i1, i2);//!!ASYNC

	//InlineAsmEnd
		mstate.eax = i0
	__asm(lbl("_ioctl__XprivateX__BB3_3_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("_ioctl_errState"))
		throw("Invalid state in _ioctl")
	}
}



// Async
public const _fstat:int = regFunc(FSM_fstat.start)

public final class FSM_fstat extends Machine {

	public static function start():void {
			var result:FSM_fstat = new FSM_fstat
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int

	public static const intRegCount:int = 5

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("_fstat_entry"))
		__asm(push(state), switchjump(
			"_fstat_errState",
			"_fstat_state0",
			"_fstat_state1",
			"_fstat_state2"))
	__asm(lbl("_fstat_state0"))
	__asm(lbl("_fstat__XprivateX__BB4_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 4096
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		__asm(push(i0<2), iftrue, target("_fstat__XprivateX__BB4_4_F"))
	__asm(lbl("_fstat__XprivateX__BB4_1_F"))
				state = 1
	__asm(lbl("_fstat_state1"))
//InlineAsmStart
	i0 =  mstate.system.fsize(i0);//!!ASYNC

	//InlineAsmEnd
		__asm(push(i0>-1), iftrue, target("_fstat__XprivateX__BB4_3_F"))
	__asm(lbl("_fstat__XprivateX__BB4_2_F"))
		i0 =  (__2E_str96)
		mstate.esp -= 20
		i1 =  (__2E_str251)
		i2 =  (59)
		i3 =  (2)
		i4 =  ((mstate.ebp+-4096))
		__asm(push(i4), push(mstate.esp), op(0x3c))
		__asm(push(i0), push((mstate.esp+4)), op(0x3c))
		__asm(push(i3), push((mstate.esp+8)), op(0x3c))
		__asm(push(i1), push((mstate.esp+12)), op(0x3c))
		__asm(push(i2), push((mstate.esp+16)), op(0x3c))
		state = 2
		mstate.esp -= 4;FSM_sprintf.start()
		return
	__asm(lbl("_fstat_state2"))
		mstate.esp += 20
		i1 =  (3)
		i0 = i4
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		__asm(push(i3), push(_val_2E_1440), op(0x3c))
		i0 =  (-1)
		__asm(jump, target("_fstat__XprivateX__BB4_5_F"))
	__asm(lbl("_fstat__XprivateX__BB4_3_F"))
		i2 =  (0)
		i3 = i1
		i4 =  (96)
		memset(i3, i2, i4)
		i3 =  (i0 >> 31)
		__asm(push(i0), push((i1+48)), op(0x3c))
		__asm(push(i3), push((i1+52)), op(0x3c))
		mstate.eax = i2
		__asm(jump, target("_fstat__XprivateX__BB4_6_F"))
	__asm(lbl("_fstat__XprivateX__BB4_4_F"))
		i0 =  (0)
	__asm(lbl("_fstat__XprivateX__BB4_5_F"))
		mstate.eax = i0
	__asm(lbl("_fstat__XprivateX__BB4_6_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("_fstat_errState"))
		throw("Invalid state in _fstat")
	}
}



// Sync
public const __exit:int = regFunc(FSM__exit.start)

public final class FSM__exit extends Machine {

	public static function start():void {
		var i0:int


		__asm(label, lbl("__exit_entry"))
	__asm(lbl("__exit__XprivateX__BB5_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		//InlineAsmStart
	throw new AlchemyExit(i0)
	//InlineAsmEnd
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Async
public const _sprintf:int = regFunc(FSM_sprintf.start)

public final class FSM_sprintf extends Machine {

	public static function start():void {
			var result:FSM_sprintf = new FSM_sprintf
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int

	public static const intRegCount:int = 4

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("_sprintf_entry"))
		__asm(push(state), switchjump(
			"_sprintf_errState",
			"_sprintf_state0",
			"_sprintf_state1"))
	__asm(lbl("_sprintf_state0"))
	__asm(lbl("_sprintf__XprivateX__BB6_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 260
		i0 =  (-1)
		__asm(push(i0), push((mstate.ebp+-242)), op(0x3b))
		i0 =  (520)
		__asm(push(i0), push((mstate.ebp+-244)), op(0x3b))
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		__asm(push(i0), push((mstate.ebp+-256)), op(0x3c))
		__asm(push(i0), push((mstate.ebp+-240)), op(0x3c))
		i0 =  (2147483647)
		__asm(push(i0), push((mstate.ebp+-248)), op(0x3c))
		i1 =  ((mstate.ebp+-160))
		__asm(push(i0), push((mstate.ebp+-236)), op(0x3c))
		__asm(push(i1), push((mstate.ebp+-200)), op(0x3c))
		i0 =  (0)
		__asm(push(i0), push((mstate.ebp+-160)), op(0x3c))
		__asm(push(i0), push((mstate.ebp+-156)), op(0x3c))
		__asm(push(i0), push((mstate.ebp+-152)), op(0x3c))
		__asm(push(i0), push((mstate.ebp+-148)), op(0x3c))
		__asm(push(i0), push((mstate.ebp+-144)), op(0x3c))
		i1 =  (i1 + 20)
		i2 =  (128)
		memset(i1, i0, i2)
		i1 =  (mstate.ebp + 16)
		__asm(push(i1), push((mstate.ebp+-260)), op(0x3c))
		mstate.esp -= 12
		i2 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i3 =  ((mstate.ebp+-256))
		__asm(push(i3), push(mstate.esp), op(0x3c))
		__asm(push(i2), push((mstate.esp+4)), op(0x3c))
		__asm(push(i1), push((mstate.esp+8)), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM___vfprintf.start()
		return
	__asm(lbl("_sprintf_state1"))
		i1 = mstate.eax
		mstate.esp += 12
		i1 =  ((__xasm<int>(push((mstate.ebp+-256)), op(0x37))))
		__asm(push(i0), push(i1), op(0x3a))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("_sprintf_errState"))
		throw("Invalid state in _sprintf")
	}
}



// Async
public const __start:int = regFunc(FSM__start.start)

public final class FSM__start extends Machine {

	public static function start():void {
			var result:FSM__start = new FSM__start
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int

	public static const intRegCount:int = 6

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("__start_entry"))
		__asm(push(state), switchjump(
			"__start_errState",
			"__start_state0",
			"__start_state1",
			"__start_state2",
			"__start_state3",
			"__start_state4",
			"__start_state5",
			"__start_state6",
			"__start_state7",
			"__start_state8",
			"__start_state9",
			"__start_state10",
			"__start_state11",
			"__start_state12"))
	__asm(lbl("__start_state0"))
	__asm(lbl("__start__XprivateX__BB7_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push(i0), op(0x37))))
		i2 =  (i1 << 2)
		i2 =  (i2 + i0)
		i2 =  (i2 + 8)
		__asm(push(i2), push(_environ), op(0x3c))
		__asm(push(i1<1), iftrue, target("__start__XprivateX__BB7_6_F"))
	__asm(lbl("__start__XprivateX__BB7_1_F"))
		i0 =  ((__xasm<int>(push((i0+4)), op(0x37))))
		i1 = i0
		__asm(push(i0==0), iftrue, target("__start__XprivateX__BB7_6_F"))
	__asm(lbl("__start__XprivateX__BB7_2_F"))
		i1 =  ((__xasm<int>(push(i1), op(0x35))))
		__asm(push(i1==0), iftrue, target("__start__XprivateX__BB7_6_F"))
	__asm(lbl("__start__XprivateX__BB7_3_F"))
		i0 =  (i0 + 1)
	__asm(jump, target("__start__XprivateX__BB7_4_F"), lbl("__start__XprivateX__BB7_4_B"), label, lbl("__start__XprivateX__BB7_4_F")); 
		i1 =  ((__xasm<int>(push(i0), op(0x35))))
		i0 =  (i0 + 1)
		__asm(push(i1==0), iftrue, target("__start__XprivateX__BB7_6_F"))
	__asm(lbl("__start__XprivateX__BB7_5_F"))
		__asm(jump, target("__start__XprivateX__BB7_4_B"))
	__asm(lbl("__start__XprivateX__BB7_6_F"))
		i2 =  (0)
		mstate.esp -= 4
		__asm(push(i2), push(mstate.esp), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM_atexit.start()
		return
	__asm(lbl("__start_state1"))
		mstate.esp += 4
		mstate.esp -= 4
		i0 =  (__fini)
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 2
		mstate.esp -= 4;FSM_atexit.start()
		return
	__asm(lbl("__start_state2"))
		mstate.esp += 4
		i0 =  (__2E_str1)
		i1 =  (4)
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		state = 3
		mstate.esp -= 4;(mstate.funcs[_AS3_False])()
		return
	__asm(lbl("__start_state3"))
		i0 = mstate.eax
		mstate.esp -= 8
		i1 =  (_InitLibrary)
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 4
		mstate.esp -= 4;(mstate.funcs[_AS3_Function])()
		return
	__asm(lbl("__start_state4"))
		i1 = mstate.eax
		mstate.esp += 8
		mstate.esp -= 8
		i3 =  (_HaltOperation)
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i3), push((mstate.esp+4)), op(0x3c))
		state = 5
		mstate.esp -= 4;(mstate.funcs[_AS3_Function])()
		return
	__asm(lbl("__start_state5"))
		i3 = mstate.eax
		mstate.esp += 8
		mstate.esp -= 8
		i4 =  (_BlockForData)
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i4), push((mstate.esp+4)), op(0x3c))
		state = 6
		mstate.esp -= 4;(mstate.funcs[_AS3_Function])()
		return
	__asm(lbl("__start_state6"))
		i4 = mstate.eax
		mstate.esp += 8
		mstate.esp -= 20
		i5 =  (__2E_str3102)
		__asm(push(i5), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		__asm(push(i0), push((mstate.esp+8)), op(0x3c))
		__asm(push(i3), push((mstate.esp+12)), op(0x3c))
		__asm(push(i4), push((mstate.esp+16)), op(0x3c))
		state = 7
		mstate.esp -= 4;(mstate.funcs[_AS3_Object])()
		return
	__asm(lbl("__start_state7"))
		i4 = mstate.eax
		mstate.esp += 20
		mstate.esp -= 4
		__asm(push(i1), push(mstate.esp), op(0x3c))
		state = 8
		mstate.esp -= 4;(mstate.funcs[_AS3_Release])()
		return
	__asm(lbl("__start_state8"))
		mstate.esp += 4
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 9
		mstate.esp -= 4;(mstate.funcs[_AS3_Release])()
		return
	__asm(lbl("__start_state9"))
		mstate.esp += 4
		mstate.esp -= 4
		__asm(push(i3), push(mstate.esp), op(0x3c))
		state = 10
		mstate.esp -= 4;(mstate.funcs[_AS3_Release])()
		return
	__asm(lbl("__start_state10"))
		mstate.esp += 4
		i0 =  (1)
		i1 = i4
				state = 11
	__asm(lbl("__start_state11"))
//InlineAsmStart
	if(i0) throw (i0 = 0, new AlchemyLibInit(i1));//!!ASYNC
	//InlineAsmEnd
		mstate.esp -= 4
		__asm(push(i2), push(mstate.esp), op(0x3c))
		state = 12
		mstate.esp -= 4;FSM_exit.start()
		return
	__asm(lbl("__start_state12"))
		mstate.esp += 4
	__asm(lbl("__start_errState"))
		throw("Invalid state in __start")
	}
}



// Async
public const _atexit:int = regFunc(FSM_atexit.start)

public final class FSM_atexit extends Machine {

	public static function start():void {
			var result:FSM_atexit = new FSM_atexit
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int

	public static const intRegCount:int = 5

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("_atexit_entry"))
		__asm(push(state), switchjump(
			"_atexit_errState",
			"_atexit_state0",
			"_atexit_state1",
			"_atexit_state2"))
	__asm(lbl("_atexit_state0"))
	__asm(lbl("_atexit__XprivateX__BB8_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push(___atexit), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		__asm(push(i0==0), iftrue, target("_atexit__XprivateX__BB8_11_F"))
	__asm(lbl("_atexit__XprivateX__BB8_1_F"))
		i2 = i0
		__asm(jump, target("_atexit__XprivateX__BB8_8_F"))
	__asm(lbl("_atexit__XprivateX__BB8_2_B"), label)
		__asm(jump, target("_atexit__XprivateX__BB8_3_F"))
	__asm(jump, target("_atexit__XprivateX__BB8_3_F"), lbl("_atexit__XprivateX__BB8_3_B"), label, lbl("_atexit__XprivateX__BB8_3_F")); 
		i2 =  (520)
		mstate.esp -= 8
		i3 =  (0)
		__asm(push(i3), push(mstate.esp), op(0x3c))
		__asm(push(i2), push((mstate.esp+4)), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("_atexit_state1"))
		i2 = mstate.eax
		mstate.esp += 8
		__asm(push(i2==0), iftrue, target("_atexit__XprivateX__BB8_13_F"))
	__asm(lbl("_atexit__XprivateX__BB8_4_F"))
		i3 =  ((__xasm<int>(push(___atexit), op(0x37))))
		__asm(push(i0==i3), iftrue, target("_atexit__XprivateX__BB8_7_F"))
	__asm(lbl("_atexit__XprivateX__BB8_5_F"))
		i0 =  (0)
		mstate.esp -= 8
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i0), push((mstate.esp+4)), op(0x3c))
		state = 2
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("_atexit_state2"))
		i0 = mstate.eax
		mstate.esp += 8
		i0 =  ((__xasm<int>(push(___atexit), op(0x37))))
		i2 =  ((__xasm<int>(push((i0+4)), op(0x37))))
		__asm(push(i2>31), iftrue, target("_atexit__XprivateX__BB8_2_B"))
	__asm(lbl("_atexit__XprivateX__BB8_6_F"))
		__asm(jump, target("_atexit__XprivateX__BB8_12_F"))
	__asm(lbl("_atexit__XprivateX__BB8_7_F"))
		i0 =  (0)
		__asm(push(i0), push((i2+4)), op(0x3c))
		__asm(push(i3), push(i2), op(0x3c))
		__asm(push(i2), push(___atexit), op(0x3c))
		i0 = i2
		i2 = i0
	__asm(lbl("_atexit__XprivateX__BB8_8_F"))
		i3 =  ((__xasm<int>(push((i0+4)), op(0x37))))
		__asm(push(i3>31), iftrue, target("_atexit__XprivateX__BB8_10_F"))
	__asm(lbl("_atexit__XprivateX__BB8_9_F"))
		__asm(jump, target("_atexit__XprivateX__BB8_12_F"))
	__asm(lbl("_atexit__XprivateX__BB8_10_F"))
		i0 = i2
		__asm(jump, target("_atexit__XprivateX__BB8_3_B"))
	__asm(lbl("_atexit__XprivateX__BB8_11_F"))
		i0 =  (___atexit0_2E_3021)
		__asm(push(i0), push(___atexit), op(0x3c))
		__asm(jump, target("_atexit__XprivateX__BB8_12_F"))
	__asm(lbl("_atexit__XprivateX__BB8_12_F"))
		i2 =  (1)
		i3 =  ((__xasm<int>(push((i0+4)), op(0x37))))
		i4 =  (i3 << 4)
		i4 =  (i0 + i4)
		__asm(push(i2), push((i4+8)), op(0x3c))
		__asm(push(i1), push((i4+12)), op(0x3c))
		i1 =  (0)
		__asm(push(i1), push((i4+16)), op(0x3c))
		__asm(push(i1), push((i4+20)), op(0x3c))
		i1 =  (i3 + 1)
		__asm(push(i1), push((i0+4)), op(0x3c))
	__asm(lbl("_atexit__XprivateX__BB8_13_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("_atexit_errState"))
		throw("Invalid state in _atexit")
	}
}



// Async
public const _exit:int = regFunc(FSM_exit.start)

public final class FSM_exit extends Machine {

	public static function start():void {
			var result:FSM_exit = new FSM_exit
		gstate.gworker = result
	}

	public var i0:int, i1:int

	public static const intRegCount:int = 2

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("_exit_entry"))
		__asm(push(state), switchjump(
			"_exit_errState",
			"_exit_state0",
			"_exit_state1",
			"_exit_state2"))
	__asm(lbl("_exit_state0"))
	__asm(lbl("_exit__XprivateX__BB9_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push(___cleanup_2E_b), op(0x35))))
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i0 =  (i0 ^ 1)
		i0 =  (i0 & 1)
		__asm(push(i0!=0), iftrue, target("_exit__XprivateX__BB9_2_F"))
	__asm(lbl("_exit__XprivateX__BB9_1_F"))
		state = 1
		mstate.esp -= 4;FSM__cleanup.start()
		return
	__asm(lbl("_exit_state1"))
	__asm(lbl("_exit__XprivateX__BB9_2_F"))
		mstate.esp -= 4
		__asm(push(i1), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM__exit.start()
	__asm(lbl("_exit_state2"))
		mstate.esp += 4
	__asm(lbl("_exit_errState"))
		throw("Invalid state in _exit")
	}
}



// Sync
public const _dorounding:int = regFunc(FSM_dorounding.start)

public final class FSM_dorounding extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int


		__asm(label, lbl("_dorounding_entry"))
	__asm(lbl("_dorounding__XprivateX__BB10_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i2 =  (i0 + i1)
		i2 =  ((__xasm<int>(push(i2), op(0x35))))
		i3 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i4 =  (i2 << 24)
		i5 = i0
		i4 =  (i4 >> 24)
		__asm(push(i4>8), iftrue, target("_dorounding__XprivateX__BB10_3_F"))
	__asm(lbl("_dorounding__XprivateX__BB10_1_F"))
		i2 =  (i2 & 255)
		__asm(push(i2!=8), iftrue, target("_dorounding__XprivateX__BB10_11_F"))
	__asm(lbl("_dorounding__XprivateX__BB10_2_F"))
		i2 =  (i1 + i0)
		i2 =  ((__xasm<int>(push((i2+-1)), op(0x35))))
		i2 =  (i2 & 1)
		__asm(push(i2==0), iftrue, target("_dorounding__XprivateX__BB10_11_F"))
	__asm(lbl("_dorounding__XprivateX__BB10_3_F"))
		i2 =  (i1 + -1)
		i4 =  (i0 + i2)
		i6 =  ((__xasm<int>(push(i4), op(0x35))))
		__asm(push(i6==15), iftrue, target("_dorounding__XprivateX__BB10_5_F"))
	__asm(lbl("_dorounding__XprivateX__BB10_4_F"))
		i0 = i4
		__asm(jump, target("_dorounding__XprivateX__BB10_9_F"))
	__asm(lbl("_dorounding__XprivateX__BB10_5_F"))
		i4 =  (0)
		i1 =  (i5 + i1)
		i1 =  (i1 + -1)
	__asm(jump, target("_dorounding__XprivateX__BB10_6_F"), lbl("_dorounding__XprivateX__BB10_6_B"), label, lbl("_dorounding__XprivateX__BB10_6_F")); 
		i5 = i1
		__asm(push(i2==i4), iftrue, target("_dorounding__XprivateX__BB10_10_F"))
	__asm(lbl("_dorounding__XprivateX__BB10_7_F"))
		i6 =  ((__xasm<int>(push(i5), op(0x35))))
		i7 =  (i4 ^ -1)
		i6 =  (i6 + 1)
		i7 =  (i2 + i7)
		__asm(push(i6), push(i5), op(0x3a))
		i5 =  (i0 + i7)
		i6 =  ((__xasm<int>(push(i5), op(0x35))))
		i1 =  (i1 + -1)
		i4 =  (i4 + 1)
		__asm(push(i6==15), iftrue, target("_dorounding__XprivateX__BB10_12_F"))
	__asm(lbl("_dorounding__XprivateX__BB10_8_F"))
		i0 = i5
		__asm(jump, target("_dorounding__XprivateX__BB10_9_F"))
	__asm(lbl("_dorounding__XprivateX__BB10_9_F"))
		i3 = i0
		i5 =  ((__xasm<int>(push(i3), op(0x35))))
		i5 =  (i5 + 1)
		__asm(push(i5), push(i3), op(0x3a))
		__asm(jump, target("_dorounding__XprivateX__BB10_11_F"))
	__asm(lbl("_dorounding__XprivateX__BB10_10_F"))
		i0 =  (1)
		__asm(push(i0), push(i5), op(0x3a))
		i0 =  ((__xasm<int>(push(i3), op(0x37))))
		i0 =  (i0 + 4)
		__asm(push(i0), push(i3), op(0x3c))
	__asm(lbl("_dorounding__XprivateX__BB10_11_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	__asm(lbl("_dorounding__XprivateX__BB10_12_F"))
		__asm(jump, target("_dorounding__XprivateX__BB10_6_B"))
	}
}



// Async
public const _abort1:int = regFunc(FSM_abort1.start)

public final class FSM_abort1 extends Machine {

	public static function start():void {
			var result:FSM_abort1 = new FSM_abort1
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
	public var i8:int, i9:int, i10:int, i11:int

	public static const intRegCount:int = 12

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("_abort1_entry"))
		__asm(push(state), switchjump(
			"_abort1_errState",
			"_abort1_state0",
			"_abort1_state1",
			"_abort1_state2",
			"_abort1_state3",
			"_abort1_state4",
			"_abort1_state5",
			"_abort1_state6",
			"_abort1_state7"))
	__asm(lbl("_abort1_state0"))
	__asm(lbl("_abort1__XprivateX__BB11_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 20480
		i0 =  ((__xasm<int>(push(___cleanup_2E_b), op(0x35))))
		i0 =  (i0 ^ 1)
		i0 =  (i0 & 1)
		__asm(push(i0!=0), iftrue, target("_abort1__XprivateX__BB11_2_F"))
	__asm(lbl("_abort1__XprivateX__BB11_1_F"))
		state = 1
		mstate.esp -= 4;FSM__cleanup.start()
		return
	__asm(lbl("_abort1_state1"))
	__asm(lbl("_abort1__XprivateX__BB11_2_F"))
		i2 =  (__2E_str340)
		i3 =  (4)
		i0 = i2
		i1 = i3
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		mstate.esp -= 20
		i4 =  (__2E_str96)
		i5 =  (__2E_str138)
		i6 =  (34)
		i7 =  (78)
		i0 =  ((mstate.ebp+-20480))
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i4), push((mstate.esp+4)), op(0x3c))
		__asm(push(i7), push((mstate.esp+8)), op(0x3c))
		__asm(push(i5), push((mstate.esp+12)), op(0x3c))
		__asm(push(i6), push((mstate.esp+16)), op(0x3c))
		state = 2
		mstate.esp -= 4;FSM_sprintf.start()
		return
	__asm(lbl("_abort1_state2"))
		mstate.esp += 20
		i8 =  (3)
		i1 = i8
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		__asm(push(i7), push(_val_2E_1440), op(0x3c))
		i9 =  (__2E_str977)
		i10 =  (__2E_str37)
		i0 = i9
		i1 = i3
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		i0 = i10
		i1 = i3
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		mstate.esp -= 20
		i11 =  (50)
		i0 =  ((mstate.ebp+-16384))
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i4), push((mstate.esp+4)), op(0x3c))
		__asm(push(i7), push((mstate.esp+8)), op(0x3c))
		__asm(push(i5), push((mstate.esp+12)), op(0x3c))
		__asm(push(i11), push((mstate.esp+16)), op(0x3c))
		state = 3
		mstate.esp -= 4;FSM_sprintf.start()
		return
	__asm(lbl("_abort1_state3"))
		mstate.esp += 20
		i1 = i8
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		__asm(push(i7), push(_val_2E_1440), op(0x3c))
		i0 =  (__2E_str643)
		i1 = i3
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		mstate.esp -= 20
		i0 =  (10)
		i1 =  ((mstate.ebp+-12288))
		__asm(push(i1), push(mstate.esp), op(0x3c))
		__asm(push(i4), push((mstate.esp+4)), op(0x3c))
		__asm(push(i7), push((mstate.esp+8)), op(0x3c))
		__asm(push(i5), push((mstate.esp+12)), op(0x3c))
		__asm(push(i0), push((mstate.esp+16)), op(0x3c))
		state = 4
		mstate.esp -= 4;FSM_sprintf.start()
		return
	__asm(lbl("_abort1_state4"))
		mstate.esp += 20
		i0 = i1
		i1 = i8
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		__asm(push(i7), push(_val_2E_1440), op(0x3c))
		i0 = i2
		i1 = i3
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		mstate.esp -= 20
		i0 =  ((mstate.ebp+-8192))
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i4), push((mstate.esp+4)), op(0x3c))
		__asm(push(i7), push((mstate.esp+8)), op(0x3c))
		__asm(push(i5), push((mstate.esp+12)), op(0x3c))
		__asm(push(i6), push((mstate.esp+16)), op(0x3c))
		state = 5
		mstate.esp -= 4;FSM_sprintf.start()
		return
	__asm(lbl("_abort1_state5"))
		mstate.esp += 20
		i1 = i8
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		__asm(push(i7), push(_val_2E_1440), op(0x3c))
		i0 = i9
		i1 = i3
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		i0 = i10
		i1 = i3
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		mstate.esp -= 20
		i0 =  ((mstate.ebp+-4096))
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i4), push((mstate.esp+4)), op(0x3c))
		__asm(push(i7), push((mstate.esp+8)), op(0x3c))
		__asm(push(i5), push((mstate.esp+12)), op(0x3c))
		__asm(push(i11), push((mstate.esp+16)), op(0x3c))
		state = 6
		mstate.esp -= 4;FSM_sprintf.start()
		return
	__asm(lbl("_abort1_state6"))
		mstate.esp += 20
		i1 = i8
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		__asm(push(i7), push(_val_2E_1440), op(0x3c))
		mstate.esp -= 4
		i0 =  (1)
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 7
		mstate.esp -= 4;FSM_exit.start()
		return
	__asm(lbl("_abort1_state7"))
		mstate.esp += 4
	__asm(lbl("_abort1_errState"))
		throw("Invalid state in _abort1")
	}
}



// Async
public const ___gdtoa:int = regFunc(FSM___gdtoa.start)

public final class FSM___gdtoa extends Machine {

	public static function start():void {
			var result:FSM___gdtoa = new FSM___gdtoa
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
	public var i8:int, i9:int, i10:int, i11:int, i12:int, i13:int, i14:int, i15:int
	public var i16:int, i17:int, i18:int, i19:int, i20:int, i21:int, i22:int, i23:int
	public var i24:int, i25:int, i26:int, i27:int, i28:int, i29:int, i30:int, i31:int
	public static const intRegCount:int = 32
	public var f0:Number, f1:Number, f2:Number, f3:Number

	public static const NumberRegCount:int = 4
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___gdtoa_entry"))
		__asm(push(state), switchjump(
			"___gdtoa_errState",
			"___gdtoa_state0",
			"___gdtoa_state1",
			"___gdtoa_state2",
			"___gdtoa_state3",
			"___gdtoa_state4",
			"___gdtoa_state5",
			"___gdtoa_state6",
			"___gdtoa_state7",
			"___gdtoa_state8",
			"___gdtoa_state9",
			"___gdtoa_state10",
			"___gdtoa_state11",
			"___gdtoa_state12",
			"___gdtoa_state13",
			"___gdtoa_state14",
			"___gdtoa_state15",
			"___gdtoa_state16",
			"___gdtoa_state17",
			"___gdtoa_state18",
			"___gdtoa_state19",
			"___gdtoa_state20",
			"___gdtoa_state21",
			"___gdtoa_state22",
			"___gdtoa_state23",
			"___gdtoa_state24",
			"___gdtoa_state25",
			"___gdtoa_state26",
			"___gdtoa_state27",
			"___gdtoa_state28",
			"___gdtoa_state29",
			"___gdtoa_state30",
			"___gdtoa_state31",
			"___gdtoa_state32",
			"___gdtoa_state33",
			"___gdtoa_state34",
			"___gdtoa_state35",
			"___gdtoa_state36"))
	__asm(lbl("___gdtoa_state0"))
	__asm(lbl("___gdtoa__XprivateX__BB12_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 208
		i0 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i1 =  ((__xasm<int>(push(i0), op(0x37))))
		i2 =  (i1 & -49)
		i3 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i4 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		__asm(push(i2), push(i0), op(0x3c))
		i1 =  (i1 & 7)
		i2 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i5 =  ((__xasm<int>(push((mstate.ebp+24)), op(0x37))))
		i6 =  ((__xasm<int>(push((mstate.ebp+28)), op(0x37))))
		i7 =  ((__xasm<int>(push((mstate.ebp+32)), op(0x37))))
		i8 = i4
		__asm(push(i1>2), iftrue, target("___gdtoa__XprivateX__BB12_6_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_1_F"))
		__asm(push(i1==0), iftrue, target("___gdtoa__XprivateX__BB12_80_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_2_F"))
		i1 =  (i1 + -1)
		__asm(push(uint(i1)<uint(2)), iftrue, target("___gdtoa__XprivateX__BB12_3_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_464_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_3_F"))
		i1 =  (32)
		i9 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_4_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_4_F"), lbl("___gdtoa__XprivateX__BB12_4_B"), label, lbl("___gdtoa__XprivateX__BB12_4_F")); 
		i9 =  (i9 + 1)
		i1 =  (i1 << 1)
		__asm(push(i1>63), iftrue, target("___gdtoa__XprivateX__BB12_30_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_5_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_5_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_4_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_6_F"))
		__asm(push(i1==3), iftrue, target("___gdtoa__XprivateX__BB12_10_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_7_F"))
		__asm(push(i1==4), iftrue, target("___gdtoa__XprivateX__BB12_8_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_464_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_8_F"))
		i0 =  (-32768)
		__asm(push(i0), push(i6), op(0x3c))
		i0 =  ((__xasm<int>(push(_freelist), op(0x37))))
		__asm(push(i0==0), iftrue, target("___gdtoa__XprivateX__BB12_22_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_9_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_9_F"))
		i1 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i1), push(_freelist), op(0x3c))
		__asm(jump, target("___gdtoa__XprivateX__BB12_25_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_10_F"))
		i0 =  (-32768)
		__asm(push(i0), push(i6), op(0x3c))
		i0 =  ((__xasm<int>(push(_freelist), op(0x37))))
		__asm(push(i0==0), iftrue, target("___gdtoa__XprivateX__BB12_12_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_11_F"))
		i1 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i1), push(_freelist), op(0x3c))
		__asm(jump, target("___gdtoa__XprivateX__BB12_15_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_12_F"))
		i0 =  (_private_mem)
		i1 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i0 =  (i1 - i0)
		i0 =  (i0 >> 3)
		i0 =  (i0 + 3)
		__asm(push(uint(i0)>uint(288)), iftrue, target("___gdtoa__XprivateX__BB12_14_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_13_F"))
		i0 =  (0)
		i2 =  (i1 + 24)
		__asm(push(i2), push(_pmem_next), op(0x3c))
		__asm(push(i0), push((i1+4)), op(0x3c))
		i0 =  (1)
		__asm(push(i0), push((i1+8)), op(0x3c))
		i0 = i1
		__asm(jump, target("___gdtoa__XprivateX__BB12_15_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_14_F"))
		i0 =  (24)
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___gdtoa_state1"))
		i0 = mstate.eax
		mstate.esp += 4
		i1 =  (0)
		__asm(push(i1), push((i0+4)), op(0x3c))
		i1 =  (1)
		__asm(push(i1), push((i0+8)), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_15_F"))
		i1 =  (0)
		__asm(push(i1), push((i0+16)), op(0x3c))
		__asm(push(i1), push((i0+12)), op(0x3c))
		__asm(push(i1), push(i0), op(0x3c))
		i2 =  (73)
		__asm(push(i2), push((i0+4)), op(0x3a))
		i0 =  (i0 + 4)
		i2 =  (__2E_str159)
		i3 = i0
	__asm(jump, target("___gdtoa__XprivateX__BB12_16_F"), lbl("___gdtoa__XprivateX__BB12_16_B"), label, lbl("___gdtoa__XprivateX__BB12_16_F")); 
		i4 =  (i2 + i1)
		i4 =  ((__xasm<int>(push((i4+1)), op(0x35))))
		i5 =  (i0 + i1)
		__asm(push(i4), push((i5+1)), op(0x3a))
		i1 =  (i1 + 1)
		__asm(push(i4==0), iftrue, target("___gdtoa__XprivateX__BB12_18_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_17_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_16_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_18_F"))
		__asm(push(i7==0), iftrue, target("___gdtoa__XprivateX__BB12_21_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_19_F"), lbl("___gdtoa__XprivateX__BB12_19_B"), label, lbl("___gdtoa__XprivateX__BB12_19_F")); 
		i0 =  (i0 + i1)
		__asm(push(i0), push(i7), op(0x3c))
		__asm(jump, target("___gdtoa__XprivateX__BB12_20_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_20_F"), lbl("___gdtoa__XprivateX__BB12_20_B"), label, lbl("___gdtoa__XprivateX__BB12_20_F")); 
		__asm(jump, target("___gdtoa__XprivateX__BB12_21_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_21_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_21_F"))
		mstate.eax = i3
		__asm(jump, target("___gdtoa__XprivateX__BB12_463_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_22_F"))
		i0 =  (_private_mem)
		i1 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i0 =  (i1 - i0)
		i0 =  (i0 >> 3)
		i0 =  (i0 + 3)
		__asm(push(uint(i0)>uint(288)), iftrue, target("___gdtoa__XprivateX__BB12_24_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_23_F"))
		i0 =  (0)
		i2 =  (i1 + 24)
		__asm(push(i2), push(_pmem_next), op(0x3c))
		__asm(push(i0), push((i1+4)), op(0x3c))
		i0 =  (1)
		__asm(push(i0), push((i1+8)), op(0x3c))
		i0 = i1
		__asm(jump, target("___gdtoa__XprivateX__BB12_25_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_24_F"))
		i0 =  (24)
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 2
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___gdtoa_state2"))
		i0 = mstate.eax
		mstate.esp += 4
		i1 =  (0)
		__asm(push(i1), push((i0+4)), op(0x3c))
		i1 =  (1)
		__asm(push(i1), push((i0+8)), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_25_F"))
		i1 =  (0)
		__asm(push(i1), push((i0+16)), op(0x3c))
		__asm(push(i1), push((i0+12)), op(0x3c))
		__asm(push(i1), push(i0), op(0x3c))
		i2 =  (78)
		__asm(push(i2), push((i0+4)), op(0x3a))
		i0 =  (i0 + 4)
		i2 =  (__2E_str260)
		i3 = i0
	__asm(jump, target("___gdtoa__XprivateX__BB12_26_F"), lbl("___gdtoa__XprivateX__BB12_26_B"), label, lbl("___gdtoa__XprivateX__BB12_26_F")); 
		i4 =  (i2 + i1)
		i4 =  ((__xasm<int>(push((i4+1)), op(0x35))))
		i5 =  (i0 + i1)
		__asm(push(i4), push((i5+1)), op(0x3a))
		i1 =  (i1 + 1)
		__asm(push(i4==0), iftrue, target("___gdtoa__XprivateX__BB12_28_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_27_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_26_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_28_F"))
		__asm(push(i7==0), iftrue, target("___gdtoa__XprivateX__BB12_20_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_29_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_19_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_30_F"))
		i1 =  (0)
		mstate.esp -= 4
		__asm(push(i9), push(mstate.esp), op(0x3c))
		state = 3
		mstate.esp -= 4;FSM___Balloc_D2A.start()
		return
	__asm(lbl("___gdtoa_state3"))
		i9 = mstate.eax
		mstate.esp += 4
		i10 =  (i9 + 20)
		i11 = i9
		i12 = i1
	__asm(jump, target("___gdtoa__XprivateX__BB12_31_F"), lbl("___gdtoa__XprivateX__BB12_31_B"), label, lbl("___gdtoa__XprivateX__BB12_31_F")); 
		i13 =  (i8 + i12)
		i13 =  ((__xasm<int>(push(i13), op(0x37))))
		i14 =  (i9 + i12)
		__asm(push(i13), push((i14+20)), op(0x3c))
		i12 =  (i12 + 4)
		i1 =  (i1 + 1)
		__asm(push(i1>1), iftrue, target("___gdtoa__XprivateX__BB12_33_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_32_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_31_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_33_F"))
		i1 =  (i1 << 2)
		i8 =  (i11 + 20)
		i1 =  (i8 + i1)
		i1 =  (i1 - i10)
		i1 =  (i1 >> 2)
		i12 =  (i1 + -1)
		i13 =  (i12 << 2)
		i8 =  (i8 + i13)
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		__asm(push(i8==0), iftrue, target("___gdtoa__XprivateX__BB12_35_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_34_F"))
		i8 = i12
		__asm(jump, target("___gdtoa__XprivateX__BB12_43_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_35_F"))
		i8 =  (i1 << 2)
		i8 =  (i9 + i8)
		i8 =  (i8 + 12)
	__asm(jump, target("___gdtoa__XprivateX__BB12_36_F"), lbl("___gdtoa__XprivateX__BB12_36_B"), label, lbl("___gdtoa__XprivateX__BB12_36_F")); 
		i12 = i8
		__asm(push(i1!=1), iftrue, target("___gdtoa__XprivateX__BB12_40_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_37_F"))
		i1 =  (0)
		__asm(push(i1), push((i11+16)), op(0x3c))
		mstate.esp -= 4
		__asm(push(i11), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM___trailz_D2A.start()
	__asm(lbl("___gdtoa_state4"))
		i1 = mstate.eax
		mstate.esp += 4
		__asm(push(i1==0), iftrue, target("___gdtoa__XprivateX__BB12_39_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_38_F"))
		i8 =  (0)
		i12 = i1
		__asm(jump, target("___gdtoa__XprivateX__BB12_48_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_39_F"))
		i1 =  (0)
		i8 = i3
		__asm(jump, target("___gdtoa__XprivateX__BB12_68_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_40_F"))
		i12 =  ((__xasm<int>(push(i12), op(0x37))))
		i8 =  (i8 + -4)
		i1 =  (i1 + -1)
		__asm(push(i12!=0), iftrue, target("___gdtoa__XprivateX__BB12_42_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_41_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_36_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_42_F"))
		i8 =  (i1 + -1)
	__asm(lbl("___gdtoa__XprivateX__BB12_43_F"))
		i12 =  (i8 << 2)
		__asm(push(i1), push((i11+16)), op(0x3c))
		i1 =  (i11 + i12)
		i1 =  ((__xasm<int>(push((i1+20)), op(0x37))))
		i12 =  ((uint(i1)<uint(65536)) ? 16 : 0)
		i1 =  (i1 << i12)
		i13 =  ((uint(i1)<uint(16777216)) ? 8 : 0)
		i1 =  (i1 << i13)
		i14 =  ((uint(i1)<uint(268435456)) ? 4 : 0)
		i12 =  (i13 | i12)
		i1 =  (i1 << i14)
		i13 =  ((uint(i1)<uint(1073741824)) ? 2 : 0)
		i12 =  (i12 | i14)
		i12 =  (i12 | i13)
		i1 =  (i1 << i13)
		__asm(push(i1>-1), iftrue, target("___gdtoa__XprivateX__BB12_45_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_44_F"))
		i1 = i12
		__asm(jump, target("___gdtoa__XprivateX__BB12_46_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_45_F"))
		i1 =  (i1 & 1073741824)
		i12 =  (i12 + 1)
		i1 =  ((i1==0) ? 32 : i12)
	__asm(lbl("___gdtoa__XprivateX__BB12_46_F"))
		mstate.esp -= 4
		__asm(push(i11), push(mstate.esp), op(0x3c))
		i8 =  (i8 << 5)
		mstate.esp -= 4;FSM___trailz_D2A.start()
	__asm(lbl("___gdtoa_state5"))
		i13 = mstate.eax
		i8 =  (i8 + 32)
		mstate.esp += 4
		i8 =  (i8 - i1)
		__asm(push(i13==0), iftrue, target("___gdtoa__XprivateX__BB12_465_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_47_F"))
		i12 = i13
		i1 = i13
		__asm(jump, target("___gdtoa__XprivateX__BB12_48_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_48_F"))
		i13 =  ((__xasm<int>(push((i11+16)), op(0x37))))
		i14 =  (i11 + 16)
		i15 =  (i1 >> 5)
		i16 =  (i11 + 20)
		__asm(push(i13>i15), iftrue, target("___gdtoa__XprivateX__BB12_50_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_49_F"), lbl("___gdtoa__XprivateX__BB12_49_B"), label, lbl("___gdtoa__XprivateX__BB12_49_F")); 
		i1 = i16
		__asm(jump, target("___gdtoa__XprivateX__BB12_65_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_50_F"))
		i1 =  (i1 & 31)
		__asm(push(i1!=0), iftrue, target("___gdtoa__XprivateX__BB12_55_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_51_F"))
		__asm(push(i15>=i13), iftrue, target("___gdtoa__XprivateX__BB12_49_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_52_F"))
		i1 =  (0)
		i17 =  (i15 << 2)
		i9 =  (i9 + 20)
		__asm(jump, target("___gdtoa__XprivateX__BB12_53_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_53_F"), lbl("___gdtoa__XprivateX__BB12_53_B"), label, lbl("___gdtoa__XprivateX__BB12_53_F")); 
		i18 =  (i17 + i9)
		i18 =  ((__xasm<int>(push(i18), op(0x37))))
		__asm(push(i18), push(i9), op(0x3c))
		i9 =  (i9 + 4)
		i1 =  (i1 + 1)
		i18 =  (i15 + i1)
		__asm(push(i18>=i13), iftrue, target("___gdtoa__XprivateX__BB12_64_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_54_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_54_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_53_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_55_F"))
		i17 =  (i15 << 2)
		i17 =  (i11 + i17)
		i17 =  ((__xasm<int>(push((i17+20)), op(0x37))))
		i17 =  (i17 >>> i1)
		i18 =  (32 - i1)
		i19 =  (i15 + 1)
		__asm(push(i19<i13), iftrue, target("___gdtoa__XprivateX__BB12_57_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_56_F"))
		i1 = i16
		i9 = i17
		__asm(jump, target("___gdtoa__XprivateX__BB12_61_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_57_F"))
		i19 =  (0)
		i20 =  (i15 << 2)
		i15 =  (i15 + 1)
	__asm(jump, target("___gdtoa__XprivateX__BB12_58_F"), lbl("___gdtoa__XprivateX__BB12_58_B"), label, lbl("___gdtoa__XprivateX__BB12_58_F")); 
		i21 =  (i20 + i9)
		i22 =  ((__xasm<int>(push((i21+24)), op(0x37))))
		i22 =  (i22 << i18)
		i17 =  (i22 | i17)
		__asm(push(i17), push((i9+20)), op(0x3c))
		i17 =  ((__xasm<int>(push((i21+24)), op(0x37))))
		i9 =  (i9 + 4)
		i19 =  (i19 + 1)
		i17 =  (i17 >>> i1)
		i21 =  (i15 + i19)
		__asm(push(i21>=i13), iftrue, target("___gdtoa__XprivateX__BB12_60_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_59_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_58_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_60_F"))
		i1 =  (i19 << 2)
		i1 =  (i11 + i1)
		i1 =  (i1 + 20)
		i9 = i17
	__asm(lbl("___gdtoa__XprivateX__BB12_61_F"))
		__asm(push(i9), push(i1), op(0x3c))
		__asm(push(i9!=0), iftrue, target("___gdtoa__XprivateX__BB12_63_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_62_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_65_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_63_F"))
		i1 =  (i1 + 4)
		__asm(jump, target("___gdtoa__XprivateX__BB12_65_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_64_F"))
		i1 =  (i1 << 2)
		i1 =  (i11 + i1)
		i1 =  (i1 + 20)
	__asm(lbl("___gdtoa__XprivateX__BB12_65_F"))
		i1 =  (i1 - i10)
		i9 =  (i1 >> 2)
		__asm(push(i9), push(i14), op(0x3c))
		__asm(push(uint(i1)>uint(3)), iftrue, target("___gdtoa__XprivateX__BB12_67_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_66_F"))
		i1 =  (0)
		__asm(push(i1), push(i16), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_67_F"))
		i1 =  (i8 - i12)
		i8 =  (i12 + i3)
	__asm(jump, target("___gdtoa__XprivateX__BB12_68_F"), lbl("___gdtoa__XprivateX__BB12_68_B"), label, lbl("___gdtoa__XprivateX__BB12_68_F")); 
		i9 =  ((__xasm<int>(push((i11+16)), op(0x37))))
		__asm(push(i9!=0), iftrue, target("___gdtoa__XprivateX__BB12_87_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_69_F"))
		__asm(push(i11==0), iftrue, target("___gdtoa__XprivateX__BB12_71_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_70_F"))
		i0 =  (_freelist)
		i1 =  ((__xasm<int>(push((i11+4)), op(0x37))))
		i1 =  (i1 << 2)
		i0 =  (i0 + i1)
		i1 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i1), push(i11), op(0x3c))
		__asm(push(i11), push(i0), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_71_F"))
		i0 =  (1)
		__asm(push(i0), push(i6), op(0x3c))
		i0 =  ((__xasm<int>(push(_freelist), op(0x37))))
		__asm(push(i0==0), iftrue, target("___gdtoa__XprivateX__BB12_73_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_72_F"))
		i1 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i1), push(_freelist), op(0x3c))
		__asm(jump, target("___gdtoa__XprivateX__BB12_76_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_73_F"))
		i0 =  (_private_mem)
		i1 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i0 =  (i1 - i0)
		i0 =  (i0 >> 3)
		i0 =  (i0 + 3)
		__asm(push(uint(i0)>uint(288)), iftrue, target("___gdtoa__XprivateX__BB12_75_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_74_F"))
		i0 =  (0)
		i2 =  (i1 + 24)
		__asm(push(i2), push(_pmem_next), op(0x3c))
		__asm(push(i0), push((i1+4)), op(0x3c))
		i0 =  (1)
		__asm(push(i0), push((i1+8)), op(0x3c))
		i0 = i1
		__asm(jump, target("___gdtoa__XprivateX__BB12_76_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_75_F"))
		i0 =  (24)
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 6
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___gdtoa_state6"))
		i0 = mstate.eax
		mstate.esp += 4
		i1 =  (0)
		__asm(push(i1), push((i0+4)), op(0x3c))
		i1 =  (1)
		__asm(push(i1), push((i0+8)), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_76_F"))
		i1 =  (0)
		__asm(push(i1), push((i0+16)), op(0x3c))
		__asm(push(i1), push((i0+12)), op(0x3c))
		__asm(push(i1), push(i0), op(0x3c))
		i2 =  (48)
		__asm(push(i2), push((i0+4)), op(0x3a))
		__asm(push(i1), push((i0+5)), op(0x3a))
		i1 =  (i0 + 5)
		i0 =  (i0 + 4)
		__asm(push(i7==0), iftrue, target("___gdtoa__XprivateX__BB12_79_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_77_F"), lbl("___gdtoa__XprivateX__BB12_77_B"), label, lbl("___gdtoa__XprivateX__BB12_77_F")); 
		__asm(push(i1), push(i7), op(0x3c))
		__asm(jump, target("___gdtoa__XprivateX__BB12_78_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_78_F"), lbl("___gdtoa__XprivateX__BB12_78_B"), label, lbl("___gdtoa__XprivateX__BB12_78_F")); 
		__asm(jump, target("___gdtoa__XprivateX__BB12_79_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_79_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_79_F"), lbl("___gdtoa__XprivateX__BB12_79_B"), label, lbl("___gdtoa__XprivateX__BB12_79_F")); 
		mstate.eax = i0
		__asm(jump, target("___gdtoa__XprivateX__BB12_463_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_80_F"))
		i0 =  (1)
		__asm(push(i0), push(i6), op(0x3c))
		i0 =  ((__xasm<int>(push(_freelist), op(0x37))))
		__asm(push(i0==0), iftrue, target("___gdtoa__XprivateX__BB12_82_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_81_F"))
		i1 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i1), push(_freelist), op(0x3c))
		__asm(jump, target("___gdtoa__XprivateX__BB12_85_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_82_F"))
		i0 =  (_private_mem)
		i1 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i0 =  (i1 - i0)
		i0 =  (i0 >> 3)
		i0 =  (i0 + 3)
		__asm(push(uint(i0)>uint(288)), iftrue, target("___gdtoa__XprivateX__BB12_84_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_83_F"))
		i0 =  (0)
		i2 =  (i1 + 24)
		__asm(push(i2), push(_pmem_next), op(0x3c))
		__asm(push(i0), push((i1+4)), op(0x3c))
		i0 =  (1)
		__asm(push(i0), push((i1+8)), op(0x3c))
		i0 = i1
		__asm(jump, target("___gdtoa__XprivateX__BB12_85_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_84_F"))
		i0 =  (24)
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 7
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___gdtoa_state7"))
		i0 = mstate.eax
		mstate.esp += 4
		i1 =  (0)
		__asm(push(i1), push((i0+4)), op(0x3c))
		i1 =  (1)
		__asm(push(i1), push((i0+8)), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_85_F"))
		i1 =  (0)
		__asm(push(i1), push((i0+16)), op(0x3c))
		__asm(push(i1), push((i0+12)), op(0x3c))
		__asm(push(i1), push(i0), op(0x3c))
		i2 =  (48)
		__asm(push(i2), push((i0+4)), op(0x3a))
		__asm(push(i1), push((i0+5)), op(0x3a))
		i1 =  (i0 + 5)
		i0 =  (i0 + 4)
		__asm(push(i7==0), iftrue, target("___gdtoa__XprivateX__BB12_78_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_86_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_77_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_87_F"))
		i10 =  (i9 + -1)
		i12 =  (i10 << 2)
		i13 =  (i11 + 20)
		i12 =  (i13 + i12)
		i14 =  ((__xasm<int>(push(i12), op(0x37))))
		i15 =  ((uint(i14)<uint(65536)) ? 16 : 0)
		i16 =  (i14 << i15)
		i17 =  ((uint(i16)<uint(16777216)) ? 8 : 0)
		i16 =  (i16 << i17)
		i18 =  ((uint(i16)<uint(268435456)) ? 4 : 0)
		i15 =  (i17 | i15)
		i16 =  (i16 << i18)
		i17 =  ((uint(i16)<uint(1073741824)) ? 2 : 0)
		i15 =  (i15 | i18)
		i15 =  (i15 | i17)
		i16 =  (i16 << i17)
		__asm(push(i16>-1), iftrue, target("___gdtoa__XprivateX__BB12_89_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_88_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_90_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_89_F"))
		i16 =  (i16 & 1073741824)
		i15 =  (i15 + 1)
		i15 =  ((i16==0) ? 32 : i15)
	__asm(lbl("___gdtoa__XprivateX__BB12_90_F"))
		__asm(push(i15>10), iftrue, target("___gdtoa__XprivateX__BB12_94_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_91_F"))
		i12 =  (i15 + 21)
		i13 =  (11 - i15)
		i12 =  (i14 << i12)
		i14 =  (i14 >>> i13)
		__asm(push(i10>0), iftrue, target("___gdtoa__XprivateX__BB12_93_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_92_F"))
		i13 = i14
		__asm(jump, target("___gdtoa__XprivateX__BB12_103_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_93_F"))
		i9 =  (i9 << 2)
		i9 =  (i9 + i11)
		i9 =  ((__xasm<int>(push((i9+12)), op(0x37))))
		i13 =  (i9 >>> i13)
		i12 =  (i13 | i12)
		i13 = i14
		__asm(jump, target("___gdtoa__XprivateX__BB12_103_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_94_F"))
		__asm(push(i10>0), iftrue, target("___gdtoa__XprivateX__BB12_96_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_95_F"))
		i9 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_97_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_96_F"))
		i12 =  (i9 << 2)
		i12 =  (i12 + i11)
		i9 =  ((__xasm<int>(push((i12+12)), op(0x37))))
		i12 =  (i12 + 12)
	__asm(lbl("___gdtoa__XprivateX__BB12_97_F"))
		i10 =  (i15 + -11)
		__asm(push(i15!=11), iftrue, target("___gdtoa__XprivateX__BB12_99_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_98_F"))
		i13 = i14
		i12 = i9
		__asm(jump, target("___gdtoa__XprivateX__BB12_103_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_99_F"))
		i15 =  (43 - i15)
		i16 =  (i9 >>> i15)
		i14 =  (i14 << i10)
		i14 =  (i16 | i14)
		__asm(push(uint(i12)>uint(i13)), iftrue, target("___gdtoa__XprivateX__BB12_101_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_100_F"))
		i12 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_102_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_101_F"))
		i12 =  ((__xasm<int>(push((i12+-4)), op(0x37))))
	__asm(lbl("___gdtoa__XprivateX__BB12_102_F"))
		i12 =  (i12 >>> i15)
		i13 =  (i9 << i10)
		i12 =  (i12 | i13)
		i13 = i14
	__asm(lbl("___gdtoa__XprivateX__BB12_103_F"))
		i9 = i13
		i10 = i12
		i9 =  (i9 | 1072693248)
		i9 =  (i9 & 1073741823)
		__asm(push(i10), push((mstate.ebp+-8)), op(0x3c))
		__asm(push(i9), push((mstate.ebp+-4)), op(0x3c))
		i12 =  (i1 + i8)
		i12 =  (i12 + -1)
		f0 =  ((__xasm<Number>(push((mstate.ebp+-8)), op(0x39))))
		f0 =  (f0 + -1.5)
		i13 =  (i12 >> 31)
		i14 =  (i12 + i13)
		f1 =  (Number(i12))
		f0 =  (f0 * 0.28953)
		i13 =  (i14 ^ i13)
		f1 =  (f1 * 0.30103)
		f0 =  (f0 + 0.176091)
		i13 =  (i13 + -1077)
		f0 =  (f0 + f1)
		__asm(push(i13>0), iftrue, target("___gdtoa__XprivateX__BB12_105_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_104_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_106_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_105_F"))
		f1 =  (Number(i13))
		f1 =  (f1 * 7e-17)
		f0 =  (f1 + f0)
	__asm(lbl("___gdtoa__XprivateX__BB12_106_F"))
		f1 =  (0)
		i13 =  (int(f0))
		__asm(push(f0<f1), iftrue, target("___gdtoa__XprivateX__BB12_108_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_107_F"), lbl("___gdtoa__XprivateX__BB12_107_B"), label, lbl("___gdtoa__XprivateX__BB12_107_F")); 
		__asm(jump, target("___gdtoa__XprivateX__BB12_110_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_108_F"))
		f1 =  (Number(i13))
		__asm(push(f1==f0), iftrue, target("___gdtoa__XprivateX__BB12_107_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_109_F"))
		i13 =  (i13 + -1)
	__asm(lbl("___gdtoa__XprivateX__BB12_110_F"))
		i14 =  (i8 + i1)
		i14 =  (i14 << 20)
		i9 =  (i14 + i9)
		i9 =  (i9 + -1048576)
		__asm(push(uint(i13)<uint(23)), iftrue, target("___gdtoa__XprivateX__BB12_112_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_111_F"))
		i14 =  (1)
		__asm(jump, target("___gdtoa__XprivateX__BB12_115_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_112_F"))
		i14 =  (___tens_D2A)
		i15 =  (i13 << 3)
		__asm(push(i10), push((mstate.ebp+-16)), op(0x3c))
		__asm(push(i9), push((mstate.ebp+-12)), op(0x3c))
		i14 =  (i14 + i15)
		f0 =  ((__xasm<Number>(push((mstate.ebp+-16)), op(0x39))))
		f1 =  ((__xasm<Number>(push(i14), op(0x39))))
		__asm(push(f0<f1), iftrue, target("___gdtoa__XprivateX__BB12_114_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_113_F"))
		i14 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_115_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_114_F"))
		i14 =  (0)
		i13 =  (i13 + -1)
	__asm(lbl("___gdtoa__XprivateX__BB12_115_F"))
		i15 =  (i1 - i12)
		i16 =  (i15 + -1)
		i15 =  (1 - i15)
		i17 =  ((i16>-1) ? i16 : 0)
		i15 =  ((i16>-1) ? 0 : i15)
		__asm(push(i13<0), iftrue, target("___gdtoa__XprivateX__BB12_117_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_116_F"))
		i16 =  (0)
		i17 =  (i17 + i13)
		i18 = i13
		__asm(jump, target("___gdtoa__XprivateX__BB12_118_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_117_F"))
		i16 =  (0)
		i19 =  (0 - i13)
		i15 =  (i15 - i13)
		i18 = i16
		i16 = i19
	__asm(lbl("___gdtoa__XprivateX__BB12_118_F"))
		i2 =  ((uint(i2)>uint(9)) ? 0 : i2)
		i19 =  (i2 + -4)
		i19 =  ((i2<6) ? i2 : i19)
		i2 =  ((i2<6) ? 1 : 0)
		i20 =  ((i5<1) ? 1 : i5)
		__asm(push(i19>2), iftrue, target("___gdtoa__XprivateX__BB12_122_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_119_F"))
		__asm(push(uint(i19)<uint(2)), iftrue, target("___gdtoa__XprivateX__BB12_126_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_120_F"))
		__asm(push(i19==2), iftrue, target("___gdtoa__XprivateX__BB12_127_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_121_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_121_F"), lbl("___gdtoa__XprivateX__BB12_121_B"), label, lbl("___gdtoa__XprivateX__BB12_121_F")); 
		//IMPLICIT_DEF i20 = 
		i21 =  (1)
		i22 = i20
		i23 = i20
		__asm(jump, target("___gdtoa__XprivateX__BB12_133_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_122_F"))
		__asm(push(i19==3), iftrue, target("___gdtoa__XprivateX__BB12_129_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_123_F"))
		__asm(push(i19==4), iftrue, target("___gdtoa__XprivateX__BB12_128_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_124_F"))
		__asm(push(i19!=5), iftrue, target("___gdtoa__XprivateX__BB12_121_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_125_F"))
		i12 =  (1)
		__asm(jump, target("___gdtoa__XprivateX__BB12_130_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_126_F"))
		i5 =  (0)
		i20 =  (-1)
		i21 =  (1)
		i12 =  (22)
		i22 = i20
		i23 = i20
		__asm(jump, target("___gdtoa__XprivateX__BB12_133_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_127_F"))
		i5 =  (0)
		i12 = i20
		i21 = i5
		i22 = i20
		i23 = i20
		i5 = i20
		__asm(jump, target("___gdtoa__XprivateX__BB12_133_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_128_F"))
		i5 =  (1)
		i12 = i20
		i21 = i5
		i22 = i20
		i23 = i20
		i5 = i20
		__asm(jump, target("___gdtoa__XprivateX__BB12_133_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_129_F"))
		i12 =  (0)
	__asm(lbl("___gdtoa__XprivateX__BB12_130_F"))
		i21 = i12
		i22 =  (i13 + i5)
		i23 =  (i22 + 1)
		__asm(push(i23<1), iftrue, target("___gdtoa__XprivateX__BB12_132_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_131_F"))
		i12 = i23
		__asm(jump, target("___gdtoa__XprivateX__BB12_133_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_132_F"))
		i12 =  (1)
	__asm(lbl("___gdtoa__XprivateX__BB12_133_F"))
		i20 = i21
		i21 = i22
		i22 = i23
		__asm(push(i5), push((mstate.ebp+-207)), op(0x3c))
		__asm(push(uint(i12)<uint(20)), iftrue, target("___gdtoa__XprivateX__BB12_466_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_134_F"))
		i5 =  (4)
		i23 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_135_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_135_F"), lbl("___gdtoa__XprivateX__BB12_135_B"), label, lbl("___gdtoa__XprivateX__BB12_135_F")); 
		i5 =  (i5 << 1)
		i23 =  (i23 + 1)
		i24 =  (i5 + 16)
		__asm(push(uint(i24)>uint(i12)), iftrue, target("___gdtoa__XprivateX__BB12_137_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_136_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_135_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_137_F"))
		i5 = i23
	__asm(jump, target("___gdtoa__XprivateX__BB12_138_F"), lbl("___gdtoa__XprivateX__BB12_138_B"), label, lbl("___gdtoa__XprivateX__BB12_138_F")); 
		mstate.esp -= 4
		__asm(push(i5), push(mstate.esp), op(0x3c))
		state = 8
		mstate.esp -= 4;FSM___Balloc_D2A.start()
		return
	__asm(lbl("___gdtoa_state8"))
		i12 = mstate.eax
		mstate.esp += 4
		__asm(push(i5), push(i12), op(0x3c))
		i5 =  (i12 + 4)
		i2 =  (i2 ^ 1)
		i12 =  ((i13!=0) ? 1 : 0)
		i2 =  (i12 | i2)
		i12 = i5
		i2 =  (i2 & 1)
		__asm(push(i2!=0), iftrue, target("___gdtoa__XprivateX__BB12_204_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_139_F"))
		__asm(push(uint(i22)>uint(14)), iftrue, target("___gdtoa__XprivateX__BB12_204_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_140_F"))
		__asm(push(i13<1), iftrue, target("___gdtoa__XprivateX__BB12_152_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_141_F"))
		i2 =  (___tens_D2A)
		i23 =  (i13 & 15)
		i23 =  (i23 << 3)
		i2 =  (i2 + i23)
		f0 =  ((__xasm<Number>(push(i2), op(0x39))))
		i2 =  (i13 >> 4)
		i23 =  (i2 & 16)
		__asm(push(i23!=0), iftrue, target("___gdtoa__XprivateX__BB12_143_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_142_F"))
		i23 =  (2)
		i24 =  (0)
		i25 = i10
		i26 = i9
		__asm(jump, target("___gdtoa__XprivateX__BB12_149_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_143_F"))
		__asm(push(i10), push((mstate.ebp+-24)), op(0x3c))
		__asm(push(i9), push((mstate.ebp+-20)), op(0x3c))
		f1 =  ((__xasm<Number>(push((mstate.ebp+-24)), op(0x39))))
		f1 =  (f1 / 1e+256)
		__asm(push(f1), push((mstate.ebp+-32)), op(0x3e))
		i23 =  ((__xasm<int>(push((mstate.ebp+-32)), op(0x37))))
		i24 =  ((__xasm<int>(push((mstate.ebp+-28)), op(0x37))))
		i2 =  (i2 & 15)
		__asm(push(i2==0), iftrue, target("___gdtoa__XprivateX__BB12_467_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_144_F"))
		i25 =  (3)
		i26 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_145_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_145_F"), lbl("___gdtoa__XprivateX__BB12_145_B"), label, lbl("___gdtoa__XprivateX__BB12_145_F")); 
		i27 = i24
		i24 = i25
		i25 =  (i2 & 1)
		__asm(push(i25!=0), iftrue, target("___gdtoa__XprivateX__BB12_147_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_146_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_148_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_147_F"))
		i25 =  (___bigtens_D2A)
		i28 =  (i26 << 3)
		i25 =  (i25 + i28)
		f1 =  ((__xasm<Number>(push(i25), op(0x39))))
		f0 =  (f1 * f0)
		i24 =  (i24 + 1)
	__asm(lbl("___gdtoa__XprivateX__BB12_148_F"))
		i28 = i24
		i24 =  (i26 + 1)
		i2 =  (i2 >> 1)
		i25 = i23
		i26 = i27
		i23 = i28
	__asm(lbl("___gdtoa__XprivateX__BB12_149_F"))
		i27 = i26
		i28 = i23
		__asm(push(i2==0), iftrue, target("___gdtoa__XprivateX__BB12_151_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_150_F"))
		i26 = i24
		i23 = i25
		i24 = i27
		i25 = i28
		__asm(jump, target("___gdtoa__XprivateX__BB12_145_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_151_F"))
		i23 = i25
		i24 = i27
		i2 = i28
		__asm(jump, target("___gdtoa__XprivateX__BB12_162_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_152_F"))
		i2 =  (0 - i13)
		__asm(push(i13!=0), iftrue, target("___gdtoa__XprivateX__BB12_154_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_153_F"))
		f0 =  (1)
		i2 =  (2)
		i23 = i10
		i24 = i9
		__asm(jump, target("___gdtoa__XprivateX__BB12_162_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_154_F"))
		i23 =  (___tens_D2A)
		i24 =  (i2 & 15)
		i24 =  (i24 << 3)
		__asm(push(i10), push((mstate.ebp+-40)), op(0x3c))
		__asm(push(i9), push((mstate.ebp+-36)), op(0x3c))
		i23 =  (i23 + i24)
		f0 =  ((__xasm<Number>(push(i23), op(0x39))))
		f1 =  ((__xasm<Number>(push((mstate.ebp+-40)), op(0x39))))
		f0 =  (f1 * f0)
		__asm(push(f0), push((mstate.ebp+-48)), op(0x3e))
		i23 =  ((__xasm<int>(push((mstate.ebp+-48)), op(0x37))))
		i24 =  ((__xasm<int>(push((mstate.ebp+-44)), op(0x37))))
		i25 =  (i2 >> 4)
		__asm(push(uint(i2)<uint(16)), iftrue, target("___gdtoa__XprivateX__BB12_468_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_155_F"))
		i2 =  (___bigtens_D2A)
		i26 =  (2)
		__asm(jump, target("___gdtoa__XprivateX__BB12_156_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_156_F"), lbl("___gdtoa__XprivateX__BB12_156_B"), label, lbl("___gdtoa__XprivateX__BB12_156_F")); 
		i27 = i2
		i28 =  (i25 & 1)
		__asm(push(i28!=0), iftrue, target("___gdtoa__XprivateX__BB12_158_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_157_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_159_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_158_F"))
		__asm(push(i23), push((mstate.ebp+-56)), op(0x3c))
		__asm(push(i24), push((mstate.ebp+-52)), op(0x3c))
		f0 =  ((__xasm<Number>(push(i27), op(0x39))))
		f1 =  ((__xasm<Number>(push((mstate.ebp+-56)), op(0x39))))
		f0 =  (f1 * f0)
		__asm(push(f0), push((mstate.ebp+-64)), op(0x3e))
		i23 =  ((__xasm<int>(push((mstate.ebp+-64)), op(0x37))))
		i24 =  ((__xasm<int>(push((mstate.ebp+-60)), op(0x37))))
		i26 =  (i26 + 1)
	__asm(lbl("___gdtoa__XprivateX__BB12_159_F"))
		i2 =  (i2 + 8)
		i27 =  (i25 >> 1)
		__asm(push(uint(i25)<uint(2)), iftrue, target("___gdtoa__XprivateX__BB12_161_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_160_F"))
		i25 = i27
		__asm(jump, target("___gdtoa__XprivateX__BB12_156_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_161_F"))
		f0 =  (1)
		i2 = i26
	__asm(jump, target("___gdtoa__XprivateX__BB12_162_F"), lbl("___gdtoa__XprivateX__BB12_162_B"), label, lbl("___gdtoa__XprivateX__BB12_162_F")); 
		__asm(push(i14!=0), iftrue, target("___gdtoa__XprivateX__BB12_164_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_163_F"), lbl("___gdtoa__XprivateX__BB12_163_B"), label, lbl("___gdtoa__XprivateX__BB12_163_F")); 
		i25 = i13
		i26 = i22
		__asm(jump, target("___gdtoa__XprivateX__BB12_168_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_164_F"))
		f1 =  (1)
		__asm(push(i23), push((mstate.ebp+-72)), op(0x3c))
		__asm(push(i24), push((mstate.ebp+-68)), op(0x3c))
		f2 =  ((__xasm<Number>(push((mstate.ebp+-72)), op(0x39))))
		__asm(push(f2>=f1), iftrue, target("___gdtoa__XprivateX__BB12_163_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_165_F"))
		__asm(push(i22<1), iftrue, target("___gdtoa__XprivateX__BB12_163_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_166_F"))
		__asm(push(i21<1), iftrue, target("___gdtoa__XprivateX__BB12_204_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_167_F"))
		f1 =  (f2 * 10)
		__asm(push(f1), push((mstate.ebp+-80)), op(0x3e))
		i23 =  ((__xasm<int>(push((mstate.ebp+-80)), op(0x37))))
		i24 =  ((__xasm<int>(push((mstate.ebp+-76)), op(0x37))))
		i2 =  (i2 + 1)
		i25 =  (i13 + -1)
		i26 = i21
	__asm(lbl("___gdtoa__XprivateX__BB12_168_F"))
		__asm(push(i23), push((mstate.ebp+-88)), op(0x3c))
		__asm(push(i24), push((mstate.ebp+-84)), op(0x3c))
		f1 =  ((__xasm<Number>(push((mstate.ebp+-88)), op(0x39))))
		f2 =  (Number(i2))
		f2 =  (f2 * f1)
		f2 =  (f2 + 7)
		__asm(push(f2), push((mstate.ebp+-96)), op(0x3e))
		i2 =  ((__xasm<int>(push((mstate.ebp+-92)), op(0x37))))
		i27 =  ((__xasm<int>(push((mstate.ebp+-96)), op(0x37))))
		i2 =  (i2 + -54525952)
		__asm(push(i26!=0), iftrue, target("___gdtoa__XprivateX__BB12_174_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_169_F"))
		__asm(push(i27), push((mstate.ebp+-104)), op(0x3c))
		__asm(push(i2), push((mstate.ebp+-100)), op(0x3c))
		f0 =  ((__xasm<Number>(push((mstate.ebp+-104)), op(0x39))))
		f1 =  (f1 + -5)
		__asm(push(f1<=f0), iftrue, target("___gdtoa__XprivateX__BB12_172_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_170_F"))
		i1 =  (0)
		i2 = i11
		i3 = i1
		i4 = i25
		__asm(jump, target("___gdtoa__XprivateX__BB12_171_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_171_F"), lbl("___gdtoa__XprivateX__BB12_171_B"), label, lbl("___gdtoa__XprivateX__BB12_171_F")); 
		i11 =  (49)
		__asm(push(i11), push(i5), op(0x3a))
		i11 =  (32)
		i13 =  (0)
		i4 =  (i4 + 1)
		i23 =  (i5 + 1)
		__asm(jump, target("___gdtoa__XprivateX__BB12_444_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_172_F"))
		f0 =  -f0
		__asm(push(f1>=f0), iftrue, target("___gdtoa__XprivateX__BB12_204_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_173_F"), lbl("___gdtoa__XprivateX__BB12_173_B"), label, lbl("___gdtoa__XprivateX__BB12_173_F")); 
		i1 =  (0)
		i2 = i11
		i3 = i1
		__asm(jump, target("___gdtoa__XprivateX__BB12_337_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_174_F"))
		__asm(push(i20==0), iftrue, target("___gdtoa__XprivateX__BB12_186_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_175_F"))
		i28 =  (___tens_D2A)
		i29 =  (i26 << 3)
		__asm(push(i27), push((mstate.ebp+-112)), op(0x3c))
		__asm(push(i2), push((mstate.ebp+-108)), op(0x3c))
		i2 =  (i29 + i28)
		f1 =  ((__xasm<Number>(push((i2+-8)), op(0x39))))
		f2 =  (f0 * 0.5)
		f3 =  ((__xasm<Number>(push((mstate.ebp+-112)), op(0x39))))
		f1 =  (f2 / f1)
		i2 =  (0)
		f1 =  (f1 - f3)
	__asm(jump, target("___gdtoa__XprivateX__BB12_176_F"), lbl("___gdtoa__XprivateX__BB12_176_B"), label, lbl("___gdtoa__XprivateX__BB12_176_F")); 
		__asm(push(i23), push((mstate.ebp+-120)), op(0x3c))
		__asm(push(i24), push((mstate.ebp+-116)), op(0x3c))
		f2 =  ((__xasm<Number>(push((mstate.ebp+-120)), op(0x39))))
		f3 =  (f2 / f0)
		i23 =  (int(f3))
		f3 =  (Number(i23))
		f3 =  (f3 * f0)
		i23 =  (i23 + 48)
		i24 =  (i12 + i2)
		__asm(push(i23), push(i24), op(0x3a))
		i23 =  (i2 + 1)
		f2 =  (f2 - f3)
		i24 = i23
		__asm(push(f2>=f1), iftrue, target("___gdtoa__XprivateX__BB12_183_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_177_F"))
		f1 =  (0)
		i2 =  (i5 + i24)
		__asm(push(f2!=f1), iftrue, target("___gdtoa__XprivateX__BB12_179_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_178_F"))
		i1 =  (0)
		i3 = i11
		i23 = i25
		__asm(jump, target("___gdtoa__XprivateX__BB12_455_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_179_F"))
		__asm(push(i11==0), iftrue, target("___gdtoa__XprivateX__BB12_181_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_180_F"))
		i1 =  (_freelist)
		i3 =  ((__xasm<int>(push((i11+4)), op(0x37))))
		i3 =  (i3 << 2)
		i1 =  (i1 + i3)
		i3 =  ((__xasm<int>(push(i1), op(0x37))))
		__asm(push(i3), push(i11), op(0x3c))
		__asm(push(i11), push(i1), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_181_F"))
		i1 =  (0)
		__asm(push(i1), push(i2), op(0x3a))
		i1 =  (i25 + 1)
		__asm(push(i1), push(i6), op(0x3c))
		__asm(push(i7==0), iftrue, target("___gdtoa__XprivateX__BB12_460_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_182_F"))
		i1 =  (16)
		__asm(jump, target("___gdtoa__XprivateX__BB12_459_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_183_F"))
		f3 =  (f0 - f2)
		__asm(push(f3<f1), iftrue, target("___gdtoa__XprivateX__BB12_219_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_184_F"))
		__asm(push(i23>=i26), iftrue, target("___gdtoa__XprivateX__BB12_204_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_185_F"))
		f2 =  (f2 * 10)
		__asm(push(f2), push((mstate.ebp+-128)), op(0x3e))
		i23 =  ((__xasm<int>(push((mstate.ebp+-128)), op(0x37))))
		i24 =  ((__xasm<int>(push((mstate.ebp+-124)), op(0x37))))
		i2 =  (i2 + 1)
		f1 =  (f1 * 10)
		__asm(jump, target("___gdtoa__XprivateX__BB12_176_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_186_F"))
		i28 =  (___tens_D2A)
		i29 =  (i26 << 3)
		__asm(push(i27), push((mstate.ebp+-136)), op(0x3c))
		__asm(push(i2), push((mstate.ebp+-132)), op(0x3c))
		i2 =  (i29 + i28)
		f1 =  (f1 / f0)
		f2 =  ((__xasm<Number>(push((mstate.ebp+-136)), op(0x39))))
		f3 =  ((__xasm<Number>(push((i2+-8)), op(0x39))))
		i2 =  (int(f1))
		f1 =  (f2 * f3)
		__asm(push(i2==0), iftrue, target("___gdtoa__XprivateX__BB12_188_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_187_F"))
		i27 =  (1)
		i28 = i5
		__asm(jump, target("___gdtoa__XprivateX__BB12_190_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_188_F"))
		i27 =  (1)
		i28 = i5
		__asm(jump, target("___gdtoa__XprivateX__BB12_191_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_189_B"), label)
		i27 =  (i27 + i23)
		i28 =  (i28 + i23)
		i23 = i2
		i2 = i29
	__asm(lbl("___gdtoa__XprivateX__BB12_190_F"))
		__asm(push(i23), push((mstate.ebp+-144)), op(0x3c))
		__asm(push(i24), push((mstate.ebp+-140)), op(0x3c))
		f2 =  (Number(i2))
		f3 =  ((__xasm<Number>(push((mstate.ebp+-144)), op(0x39))))
		f2 =  (f2 * f0)
		f2 =  (f3 - f2)
		__asm(push(f2), push((mstate.ebp+-152)), op(0x3e))
		i23 =  ((__xasm<int>(push((mstate.ebp+-152)), op(0x37))))
		i24 =  ((__xasm<int>(push((mstate.ebp+-148)), op(0x37))))
	__asm(lbl("___gdtoa__XprivateX__BB12_191_F"))
		i29 =  (0)
		i30 = i28
		i31 = i29
		i29 = i2
		i2 = i23
		i23 = i24
	__asm(jump, target("___gdtoa__XprivateX__BB12_192_F"), lbl("___gdtoa__XprivateX__BB12_192_B"), label, lbl("___gdtoa__XprivateX__BB12_192_F")); 
		i24 = i29
		i24 =  (i24 + 48)
		i29 =  (i30 + i31)
		__asm(push(i24), push(i29), op(0x3a))
		i24 =  (i31 + 1)
		i29 =  (i27 + i31)
		__asm(push(i29!=i26), iftrue, target("___gdtoa__XprivateX__BB12_202_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_193_F"))
		__asm(push(i2), push((mstate.ebp+-160)), op(0x3c))
		__asm(push(i23), push((mstate.ebp+-156)), op(0x3c))
		f2 =  ((__xasm<Number>(push((mstate.ebp+-160)), op(0x39))))
		f0 =  (f0 * 0.5)
		i2 =  (i28 + i24)
		f3 =  (f1 + f0)
		__asm(push(f2<=f3), iftrue, target("___gdtoa__XprivateX__BB12_195_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_194_F"))
		i1 = i25
		__asm(jump, target("___gdtoa__XprivateX__BB12_220_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_195_F"))
		f0 =  (f0 - f1)
		__asm(push(f2>=f0), iftrue, target("___gdtoa__XprivateX__BB12_204_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_196_F"))
		i2 =  (0)
	__asm(jump, target("___gdtoa__XprivateX__BB12_197_F"), lbl("___gdtoa__XprivateX__BB12_197_B"), label, lbl("___gdtoa__XprivateX__BB12_197_F")); 
		i1 =  (i2 ^ -1)
		i1 =  (i24 + i1)
		i1 =  (i28 + i1)
		i1 =  ((__xasm<int>(push(i1), op(0x35))))
		i2 =  (i2 + 1)
		__asm(push(i1!=48), iftrue, target("___gdtoa__XprivateX__BB12_199_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_198_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_197_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_199_F"))
		f0 =  (0)
		i2 =  (i2 + -1)
		i2 =  (i24 - i2)
		i2 =  (i28 + i2)
		__asm(push(f2!=f0), iftrue, target("___gdtoa__XprivateX__BB12_201_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_200_F"))
		i1 =  (0)
		i3 = i11
		i23 = i25
		__asm(jump, target("___gdtoa__XprivateX__BB12_455_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_201_F"))
		i1 =  (16)
		i3 = i11
		i23 = i25
		__asm(jump, target("___gdtoa__XprivateX__BB12_455_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_202_F"))
		__asm(push(i2), push((mstate.ebp+-168)), op(0x3c))
		__asm(push(i23), push((mstate.ebp+-164)), op(0x3c))
		f2 =  ((__xasm<Number>(push((mstate.ebp+-168)), op(0x39))))
		f2 =  (f2 * 10)
		__asm(push(f2), push((mstate.ebp+-176)), op(0x3e))
		f2 =  (f2 / f0)
		i2 =  ((__xasm<int>(push((mstate.ebp+-176)), op(0x37))))
		i24 =  ((__xasm<int>(push((mstate.ebp+-172)), op(0x37))))
		i23 =  (i31 + 1)
		i29 =  (int(f2))
		__asm(push(i29!=0), iftrue, target("___gdtoa__XprivateX__BB12_189_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_203_F"))
		i31 = i23
		i23 = i24
		__asm(jump, target("___gdtoa__XprivateX__BB12_192_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_204_F"))
		__asm(push(i13>14), iftrue, target("___gdtoa__XprivateX__BB12_230_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_205_F"))
		__asm(push(i8<0), iftrue, target("___gdtoa__XprivateX__BB12_230_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_206_F"))
		i1 =  (___tens_D2A)
		i2 =  (i13 << 3)
		i1 =  (i1 + i2)
		f0 =  ((__xasm<Number>(push(i1), op(0x39))))
		i1 =  ((__xasm<int>(push((mstate.ebp+-207)), op(0x37))))
		__asm(push(i1>-1), iftrue, target("___gdtoa__XprivateX__BB12_208_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_207_F"))
		__asm(push(i22<1), iftrue, target("___gdtoa__XprivateX__BB12_213_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_208_F"))
		i1 =  (0)
		i2 = i10
		i3 = i9
		__asm(jump, target("___gdtoa__XprivateX__BB12_209_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_209_F"), lbl("___gdtoa__XprivateX__BB12_209_B"), label, lbl("___gdtoa__XprivateX__BB12_209_F")); 
		f1 =  (0)
		__asm(push(i2), push((mstate.ebp+-192)), op(0x3c))
		__asm(push(i3), push((mstate.ebp+-188)), op(0x3c))
		f2 =  ((__xasm<Number>(push((mstate.ebp+-192)), op(0x39))))
		f3 =  (f2 / f0)
		i2 =  (int(f3))
		f3 =  (Number(i2))
		f3 =  (f3 * f0)
		i3 =  (i2 + 48)
		i4 =  (i12 + i1)
		__asm(push(i3), push(i4), op(0x3a))
		i3 =  (i1 + 1)
		f2 =  (f2 - f3)
		i4 = i3
		__asm(push(f2==f1), iftrue, target("___gdtoa__XprivateX__BB12_454_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_210_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_210_F"))
		__asm(push(i3!=i22), iftrue, target("___gdtoa__XprivateX__BB12_229_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_211_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_211_F"))
		f2 =  (f2 + f2)
		i1 =  (i5 + i4)
		__asm(push(f2<=f0), iftrue, target("___gdtoa__XprivateX__BB12_216_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_212_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_212_F"), lbl("___gdtoa__XprivateX__BB12_212_B"), label, lbl("___gdtoa__XprivateX__BB12_212_F")); 
		i2 = i1
		i1 = i13
		__asm(jump, target("___gdtoa__XprivateX__BB12_220_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_213_F"))
		__asm(push(i22<0), iftrue, target("___gdtoa__XprivateX__BB12_173_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_214_F"))
		__asm(push(i10), push((mstate.ebp+-184)), op(0x3c))
		__asm(push(i9), push((mstate.ebp+-180)), op(0x3c))
		f1 =  ((__xasm<Number>(push((mstate.ebp+-184)), op(0x39))))
		f0 =  (f0 * 5)
		__asm(push(f1<=f0), iftrue, target("___gdtoa__XprivateX__BB12_173_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_215_F"))
		i1 =  (0)
		i2 = i11
		i3 = i1
		i4 = i13
		__asm(jump, target("___gdtoa__XprivateX__BB12_171_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_216_F"))
		__asm(push(f2==f0), iftrue, target("___gdtoa__XprivateX__BB12_218_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_217_F"), lbl("___gdtoa__XprivateX__BB12_217_B"), label, lbl("___gdtoa__XprivateX__BB12_217_F")); 
		i4 =  (16)
		i3 = i11
		i2 = i1
		i23 = i13
		i1 = i4
		__asm(jump, target("___gdtoa__XprivateX__BB12_455_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_218_F"))
		i2 =  (i2 & 1)
		__asm(push(i2==0), iftrue, target("___gdtoa__XprivateX__BB12_217_B"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_212_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_219_F"))
		i1 =  (i5 + i24)
		i2 = i1
		i1 = i25
	__asm(lbl("___gdtoa__XprivateX__BB12_220_F"))
		i3 =  ((__xasm<int>(push((i2+-1)), op(0x35))))
		i4 =  (i2 + -1)
		i8 = i2
		__asm(push(i3==57), iftrue, target("___gdtoa__XprivateX__BB12_222_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_221_F"))
		i3 = i4
		__asm(jump, target("___gdtoa__XprivateX__BB12_228_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_222_F"))
		i3 =  (0)
		i4 = i8
		i8 = i2
	__asm(jump, target("___gdtoa__XprivateX__BB12_223_F"), lbl("___gdtoa__XprivateX__BB12_223_B"), label, lbl("___gdtoa__XprivateX__BB12_223_F")); 
		i12 =  (i3 ^ -1)
		i12 =  (i2 + i12)
		__asm(push(i12!=i5), iftrue, target("___gdtoa__XprivateX__BB12_225_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_224_F"))
		i2 =  (48)
		__asm(push(i2), push(i12), op(0x3a))
		i1 =  (i1 + 1)
		i2 = i8
		i3 = i12
		__asm(jump, target("___gdtoa__XprivateX__BB12_228_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_225_F"))
		i8 =  ((__xasm<int>(push((i4+-2)), op(0x35))))
		i4 =  (i4 + -1)
		i3 =  (i3 + 1)
		__asm(push(i8!=57), iftrue, target("___gdtoa__XprivateX__BB12_227_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_226_F"))
		i8 = i12
		__asm(jump, target("___gdtoa__XprivateX__BB12_223_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_227_F"))
		i3 =  (i4 + -1)
		i2 = i12
	__asm(lbl("___gdtoa__XprivateX__BB12_228_F"))
		i4 =  (32)
		i8 =  ((__xasm<int>(push(i3), op(0x35))))
		i8 =  (i8 + 1)
		__asm(push(i8), push(i3), op(0x3a))
		i3 = i11
		i23 = i1
		i1 = i4
		__asm(jump, target("___gdtoa__XprivateX__BB12_455_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_229_F"))
		f1 =  (f2 * 10)
		__asm(push(f1), push((mstate.ebp+-200)), op(0x3e))
		i2 =  ((__xasm<int>(push((mstate.ebp+-200)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+-196)), op(0x37))))
		i1 =  (i1 + 1)
		__asm(jump, target("___gdtoa__XprivateX__BB12_209_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_230_F"))
		__asm(push(i20!=0), iftrue, target("___gdtoa__XprivateX__BB12_232_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_231_F"))
		i2 =  (0)
		i8 = i17
		i17 = i18
		i18 = i16
		i23 = i15
		__asm(jump, target("___gdtoa__XprivateX__BB12_258_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_232_F"))
		__asm(push(i19>1), iftrue, target("___gdtoa__XprivateX__BB12_244_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_233_F"))
		i2 =  (65 - i1)
		i23 =  (64 - i1)
		i23 =  (i8 - i23)
		__asm(push(i23<-16445), iftrue, target("___gdtoa__XprivateX__BB12_235_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_234_F"))
		i8 = i18
		i18 = i16
		i23 = i15
		__asm(jump, target("___gdtoa__XprivateX__BB12_252_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_235_F"))
		i2 =  (i8 + 16446)
		i23 =  ((__xasm<int>(push((_freelist+4)), op(0x37))))
		i8 =  (i2 + i17)
		i2 =  (i2 + i15)
		__asm(push(i23==0), iftrue, target("___gdtoa__XprivateX__BB12_237_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_236_F"))
		i17 =  ((__xasm<int>(push(i23), op(0x37))))
		__asm(push(i17), push((_freelist+4)), op(0x3c))
		__asm(jump, target("___gdtoa__XprivateX__BB12_240_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_237_F"))
		i23 =  (_private_mem)
		i17 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i23 =  (i17 - i23)
		i23 =  (i23 >> 3)
		i23 =  (i23 + 4)
		__asm(push(uint(i23)>uint(288)), iftrue, target("___gdtoa__XprivateX__BB12_239_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_238_F"))
		i23 =  (1)
		i9 =  (i17 + 32)
		__asm(push(i9), push(_pmem_next), op(0x3c))
		__asm(push(i23), push((i17+4)), op(0x3c))
		i23 =  (2)
		__asm(push(i23), push((i17+8)), op(0x3c))
		i23 = i17
		__asm(jump, target("___gdtoa__XprivateX__BB12_240_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_239_F"))
		i23 =  (32)
		mstate.esp -= 4
		__asm(push(i23), push(mstate.esp), op(0x3c))
		state = 9
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___gdtoa_state9"))
		i23 = mstate.eax
		mstate.esp += 4
		i17 =  (1)
		__asm(push(i17), push((i23+4)), op(0x3c))
		i17 =  (2)
		__asm(push(i17), push((i23+8)), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_240_F"))
		i17 =  (0)
		__asm(push(i17), push((i23+12)), op(0x3c))
		i17 =  (1)
		__asm(push(i17), push((i23+20)), op(0x3c))
		__asm(push(i17), push((i23+16)), op(0x3c))
		__asm(push(i8<1), iftrue, target("___gdtoa__XprivateX__BB12_242_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_241_F"))
		__asm(push(i15>0), iftrue, target("___gdtoa__XprivateX__BB12_243_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_242_F"))
		i17 = i16
		__asm(jump, target("___gdtoa__XprivateX__BB12_263_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_243_F"))
		i17 = i16
		__asm(jump, target("___gdtoa__XprivateX__BB12_262_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_244_F"))
		i9 =  (i22 + -1)
		__asm(push(i16<i9), iftrue, target("___gdtoa__XprivateX__BB12_248_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_245_F"))
		i23 =  (i16 - i9)
		__asm(push(i22<0), iftrue, target("___gdtoa__XprivateX__BB12_247_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_246_F"))
		i2 = i22
		i8 = i18
		i18 = i23
		i23 = i15
		__asm(jump, target("___gdtoa__XprivateX__BB12_252_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_247_F"))
		i2 = i18
		i18 = i23
		__asm(jump, target("___gdtoa__XprivateX__BB12_251_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_248_F"))
		i2 =  (i9 - i16)
		i16 =  (i2 + i18)
		__asm(push(i22<0), iftrue, target("___gdtoa__XprivateX__BB12_250_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_249_F"))
		i18 =  (0)
		i2 = i22
		i8 = i16
		i23 = i15
		i16 = i9
		__asm(jump, target("___gdtoa__XprivateX__BB12_252_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_250_F"))
		i18 =  (0)
		i2 = i16
		i16 = i9
	__asm(lbl("___gdtoa__XprivateX__BB12_251_F"))
		i23 = i2
		i2 =  (0)
		i9 =  (i15 - i22)
		i8 = i23
		i23 = i9
	__asm(lbl("___gdtoa__XprivateX__BB12_252_F"))
		i9 = i8
		i8 =  ((__xasm<int>(push((_freelist+4)), op(0x37))))
		i17 =  (i2 + i17)
		i15 =  (i2 + i15)
		__asm(push(i8==0), iftrue, target("___gdtoa__XprivateX__BB12_254_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_253_F"))
		i2 =  ((__xasm<int>(push(i8), op(0x37))))
		__asm(push(i2), push((_freelist+4)), op(0x3c))
		i2 = i8
		__asm(jump, target("___gdtoa__XprivateX__BB12_257_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_254_F"))
		i2 =  (_private_mem)
		i8 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i2 =  (i8 - i2)
		i2 =  (i2 >> 3)
		i2 =  (i2 + 4)
		__asm(push(uint(i2)>uint(288)), iftrue, target("___gdtoa__XprivateX__BB12_256_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_255_F"))
		i2 =  (1)
		i10 =  (i8 + 32)
		__asm(push(i10), push(_pmem_next), op(0x3c))
		__asm(push(i2), push((i8+4)), op(0x3c))
		i2 =  (2)
		__asm(push(i2), push((i8+8)), op(0x3c))
		i2 = i8
		__asm(jump, target("___gdtoa__XprivateX__BB12_257_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_256_F"))
		i2 =  (32)
		mstate.esp -= 4
		__asm(push(i2), push(mstate.esp), op(0x3c))
		state = 10
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___gdtoa_state10"))
		i2 = mstate.eax
		mstate.esp += 4
		i8 =  (1)
		__asm(push(i8), push((i2+4)), op(0x3c))
		i8 =  (2)
		__asm(push(i8), push((i2+8)), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_257_F"))
		i8 =  (0)
		__asm(push(i8), push((i2+12)), op(0x3c))
		i8 =  (1)
		__asm(push(i8), push((i2+20)), op(0x3c))
		__asm(push(i8), push((i2+16)), op(0x3c))
		i8 = i17
		i17 = i9
	__asm(lbl("___gdtoa__XprivateX__BB12_258_F"))
		i9 = i18
		i10 = i23
		i24 = i15
		__asm(push(i10<1), iftrue, target("___gdtoa__XprivateX__BB12_260_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_259_F"))
		__asm(push(i8>0), iftrue, target("___gdtoa__XprivateX__BB12_261_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_260_F"))
		i18 = i17
		i17 = i9
		i23 = i2
		i15 = i10
		i2 = i24
		__asm(jump, target("___gdtoa__XprivateX__BB12_263_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_261_F"))
		i18 = i17
		i17 = i9
		i15 = i10
		i23 = i2
		i2 = i24
	__asm(lbl("___gdtoa__XprivateX__BB12_262_F"))
		i9 =  ((i8<=i15) ? i8 : i15)
		i8 =  (i8 - i9)
		i15 =  (i15 - i9)
		i2 =  (i2 - i9)
	__asm(lbl("___gdtoa__XprivateX__BB12_263_F"))
		i9 = i18
		i10 = i17
		__asm(push(i16>0), iftrue, target("___gdtoa__XprivateX__BB12_265_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_264_F"))
		i10 = i11
		__asm(jump, target("___gdtoa__XprivateX__BB12_282_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_265_F"))
		__asm(push(i20==0), iftrue, target("___gdtoa__XprivateX__BB12_281_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_266_F"))
		__asm(push(i10>0), iftrue, target("___gdtoa__XprivateX__BB12_268_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_267_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_271_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_268_F"))
		mstate.esp -= 8
		__asm(push(i23), push(mstate.esp), op(0x3c))
		__asm(push(i10), push((mstate.esp+4)), op(0x3c))
		state = 11
		mstate.esp -= 4;FSM___pow5mult_D2A.start()
		return
	__asm(lbl("___gdtoa_state11"))
		i23 = mstate.eax
		mstate.esp += 8
		mstate.esp -= 8
		__asm(push(i23), push(mstate.esp), op(0x3c))
		__asm(push(i11), push((mstate.esp+4)), op(0x3c))
		state = 12
		mstate.esp -= 4;FSM___mult_D2A.start()
		return
	__asm(lbl("___gdtoa_state12"))
		i17 = mstate.eax
		mstate.esp += 8
		__asm(push(i11!=0), iftrue, target("___gdtoa__XprivateX__BB12_270_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_269_F"))
		i11 = i17
		__asm(jump, target("___gdtoa__XprivateX__BB12_271_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_270_F"))
		i18 =  (_freelist)
		i24 =  ((__xasm<int>(push((i11+4)), op(0x37))))
		i24 =  (i24 << 2)
		i18 =  (i18 + i24)
		i24 =  ((__xasm<int>(push(i18), op(0x37))))
		__asm(push(i24), push(i11), op(0x3c))
		__asm(push(i11), push(i18), op(0x3c))
		i11 = i17
	__asm(lbl("___gdtoa__XprivateX__BB12_271_F"))
		__asm(push(i16!=i10), iftrue, target("___gdtoa__XprivateX__BB12_273_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_272_F"))
		i10 = i11
		__asm(jump, target("___gdtoa__XprivateX__BB12_282_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_273_F"))
		mstate.esp -= 8
		i10 =  (i16 - i10)
		__asm(push(i11), push(mstate.esp), op(0x3c))
		__asm(push(i10), push((mstate.esp+4)), op(0x3c))
		state = 13
		mstate.esp -= 4;FSM___pow5mult_D2A.start()
		return
	__asm(lbl("___gdtoa_state13"))
		i10 = mstate.eax
		mstate.esp += 8
		i11 =  ((__xasm<int>(push((_freelist+4)), op(0x37))))
		__asm(push(i11==0), iftrue, target("___gdtoa__XprivateX__BB12_275_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_274_F"))
		i16 =  ((__xasm<int>(push(i11), op(0x37))))
		__asm(push(i16), push((_freelist+4)), op(0x3c))
		__asm(jump, target("___gdtoa__XprivateX__BB12_278_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_275_F"))
		i11 =  (_private_mem)
		i16 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i11 =  (i16 - i11)
		i11 =  (i11 >> 3)
		i11 =  (i11 + 4)
		__asm(push(uint(i11)>uint(288)), iftrue, target("___gdtoa__XprivateX__BB12_277_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_276_F"))
		i11 =  (1)
		i17 =  (i16 + 32)
		__asm(push(i17), push(_pmem_next), op(0x3c))
		__asm(push(i11), push((i16+4)), op(0x3c))
		i11 =  (2)
		__asm(push(i11), push((i16+8)), op(0x3c))
		i11 = i16
		__asm(jump, target("___gdtoa__XprivateX__BB12_278_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_277_F"))
		i11 =  (32)
		mstate.esp -= 4
		__asm(push(i11), push(mstate.esp), op(0x3c))
		state = 14
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___gdtoa_state14"))
		i11 = mstate.eax
		mstate.esp += 4
		i16 =  (1)
		__asm(push(i16), push((i11+4)), op(0x3c))
		i16 =  (2)
		__asm(push(i16), push((i11+8)), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_278_F"))
		i16 =  (0)
		__asm(push(i16), push((i11+12)), op(0x3c))
		i16 =  (1)
		__asm(push(i16), push((i11+20)), op(0x3c))
		__asm(push(i16), push((i11+16)), op(0x3c))
		__asm(push(i9>0), iftrue, target("___gdtoa__XprivateX__BB12_280_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_279_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_291_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_280_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_290_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_281_F"))
		mstate.esp -= 8
		__asm(push(i11), push(mstate.esp), op(0x3c))
		__asm(push(i16), push((mstate.esp+4)), op(0x3c))
		state = 15
		mstate.esp -= 4;FSM___pow5mult_D2A.start()
		return
	__asm(lbl("___gdtoa_state15"))
		i10 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___gdtoa__XprivateX__BB12_282_F"))
		i11 = i10
		i10 =  ((__xasm<int>(push((_freelist+4)), op(0x37))))
		__asm(push(i10==0), iftrue, target("___gdtoa__XprivateX__BB12_284_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_283_F"))
		i16 =  ((__xasm<int>(push(i10), op(0x37))))
		__asm(push(i16), push((_freelist+4)), op(0x3c))
		__asm(jump, target("___gdtoa__XprivateX__BB12_287_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_284_F"))
		i10 =  (_private_mem)
		i16 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i10 =  (i16 - i10)
		i10 =  (i10 >> 3)
		i10 =  (i10 + 4)
		__asm(push(uint(i10)>uint(288)), iftrue, target("___gdtoa__XprivateX__BB12_286_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_285_F"))
		i10 =  (1)
		i17 =  (i16 + 32)
		__asm(push(i17), push(_pmem_next), op(0x3c))
		__asm(push(i10), push((i16+4)), op(0x3c))
		i10 =  (2)
		__asm(push(i10), push((i16+8)), op(0x3c))
		i10 = i16
		__asm(jump, target("___gdtoa__XprivateX__BB12_287_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_286_F"))
		i10 =  (32)
		mstate.esp -= 4
		__asm(push(i10), push(mstate.esp), op(0x3c))
		state = 16
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___gdtoa_state16"))
		i10 = mstate.eax
		mstate.esp += 4
		i16 =  (1)
		__asm(push(i16), push((i10+4)), op(0x3c))
		i16 =  (2)
		__asm(push(i16), push((i10+8)), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_287_F"))
		i16 = i10
		i10 =  (0)
		__asm(push(i10), push((i16+12)), op(0x3c))
		i10 =  (1)
		__asm(push(i10), push((i16+20)), op(0x3c))
		__asm(push(i10), push((i16+16)), op(0x3c))
		__asm(push(i9>0), iftrue, target("___gdtoa__XprivateX__BB12_289_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_288_F"))
		i10 = i11
		i11 = i16
		__asm(jump, target("___gdtoa__XprivateX__BB12_291_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_289_F"))
		i10 = i11
		i11 = i16
	__asm(lbl("___gdtoa__XprivateX__BB12_290_F"))
		mstate.esp -= 8
		__asm(push(i11), push(mstate.esp), op(0x3c))
		__asm(push(i9), push((mstate.esp+4)), op(0x3c))
		state = 17
		mstate.esp -= 4;FSM___pow5mult_D2A.start()
		return
	__asm(lbl("___gdtoa_state17"))
		i11 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___gdtoa__XprivateX__BB12_291_F"))
		i16 =  ((i19<2) ? 1 : 0)
		i1 =  ((i1==1) ? 1 : 0)
		i1 =  (i1 & i16)
		i3 =  ((i3>-16444) ? 1 : 0)
		i1 =  (i1 & i3)
		i3 =  (i1 & 1)
		i2 =  (i2 + i3)
		i3 =  (i8 + i3)
		__asm(push(i9!=0), iftrue, target("___gdtoa__XprivateX__BB12_293_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_292_F"))
		i8 =  (1)
		__asm(jump, target("___gdtoa__XprivateX__BB12_297_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_293_F"))
		i8 =  ((__xasm<int>(push((i11+16)), op(0x37))))
		i8 =  (i8 << 2)
		i8 =  (i8 + i11)
		i8 =  ((__xasm<int>(push((i8+16)), op(0x37))))
		i9 =  ((uint(i8)<uint(65536)) ? 16 : 0)
		i8 =  (i8 << i9)
		i16 =  ((uint(i8)<uint(16777216)) ? 8 : 0)
		i8 =  (i8 << i16)
		i17 =  ((uint(i8)<uint(268435456)) ? 4 : 0)
		i9 =  (i16 | i9)
		i8 =  (i8 << i17)
		i16 =  ((uint(i8)<uint(1073741824)) ? 2 : 0)
		i9 =  (i9 | i17)
		i9 =  (i9 | i16)
		i8 =  (i8 << i16)
		__asm(push(i8>-1), iftrue, target("___gdtoa__XprivateX__BB12_295_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_294_F"))
		i8 = i9
		__asm(jump, target("___gdtoa__XprivateX__BB12_296_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_295_F"))
		i8 =  (i8 & 1073741824)
		i9 =  (i9 + 1)
		i8 =  ((i8==0) ? 32 : i9)
	__asm(lbl("___gdtoa__XprivateX__BB12_296_F"))
		i8 =  (32 - i8)
	__asm(lbl("___gdtoa__XprivateX__BB12_297_F"))
		i8 =  (i8 + i3)
		i8 =  (i8 & 31)
		i9 =  (32 - i8)
		i8 =  ((i8==0) ? i8 : i9)
		__asm(push(i8<5), iftrue, target("___gdtoa__XprivateX__BB12_302_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_298_F"))
		i8 =  (i8 + -4)
		i3 =  (i8 + i3)
		i15 =  (i8 + i15)
		i2 =  (i8 + i2)
		__asm(push(i2>0), iftrue, target("___gdtoa__XprivateX__BB12_300_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_299_F"))
		i2 = i3
		i3 = i15
		i15 = i10
		__asm(jump, target("___gdtoa__XprivateX__BB12_307_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_300_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_301_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_301_F"), lbl("___gdtoa__XprivateX__BB12_301_B"), label, lbl("___gdtoa__XprivateX__BB12_301_F")); 
		mstate.esp -= 8
		__asm(push(i10), push(mstate.esp), op(0x3c))
		__asm(push(i2), push((mstate.esp+4)), op(0x3c))
		state = 18
		mstate.esp -= 4;FSM___lshift_D2A.start()
		return
	__asm(lbl("___gdtoa_state18"))
		i8 = mstate.eax
		mstate.esp += 8
		i2 = i3
		i3 = i15
		i15 = i8
		__asm(jump, target("___gdtoa__XprivateX__BB12_307_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_302_F"))
		__asm(push(i8<4), iftrue, target("___gdtoa__XprivateX__BB12_304_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_303_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_305_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_304_F"))
		i8 =  (i8 + 28)
		i3 =  (i8 + i3)
		i15 =  (i8 + i15)
		i2 =  (i8 + i2)
	__asm(lbl("___gdtoa__XprivateX__BB12_305_F"))
		__asm(push(i2>0), iftrue, target("___gdtoa__XprivateX__BB12_301_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_306_F"))
		i2 = i3
		i3 = i15
		i15 = i10
		__asm(jump, target("___gdtoa__XprivateX__BB12_307_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_307_F"))
		i8 = i15
		__asm(push(i2>0), iftrue, target("___gdtoa__XprivateX__BB12_309_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_308_F"))
		i2 = i11
		__asm(jump, target("___gdtoa__XprivateX__BB12_310_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_309_F"))
		mstate.esp -= 8
		__asm(push(i11), push(mstate.esp), op(0x3c))
		__asm(push(i2), push((mstate.esp+4)), op(0x3c))
		state = 19
		mstate.esp -= 4;FSM___lshift_D2A.start()
		return
	__asm(lbl("___gdtoa_state19"))
		i2 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___gdtoa__XprivateX__BB12_310_F"))
		i11 = i2
		__asm(push(i14!=0), iftrue, target("___gdtoa__XprivateX__BB12_312_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_311_F"), lbl("___gdtoa__XprivateX__BB12_311_B"), label, lbl("___gdtoa__XprivateX__BB12_311_F")); 
		i2 = i8
		i8 = i13
		i13 = i22
		__asm(jump, target("___gdtoa__XprivateX__BB12_323_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_312_F"))
		i2 =  ((__xasm<int>(push((i8+16)), op(0x37))))
		i9 =  ((__xasm<int>(push((i11+16)), op(0x37))))
		i10 =  (i2 - i9)
		__asm(push(i2==i9), iftrue, target("___gdtoa__XprivateX__BB12_314_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_313_F"))
		i2 = i10
		__asm(jump, target("___gdtoa__XprivateX__BB12_319_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_314_F"))
		i2 =  (0)
	__asm(jump, target("___gdtoa__XprivateX__BB12_315_F"), lbl("___gdtoa__XprivateX__BB12_315_B"), label, lbl("___gdtoa__XprivateX__BB12_315_F")); 
		i10 =  (i2 ^ -1)
		i10 =  (i9 + i10)
		i14 =  (i10 << 2)
		i15 =  (i8 + i14)
		i14 =  (i11 + i14)
		i15 =  ((__xasm<int>(push((i15+20)), op(0x37))))
		i14 =  ((__xasm<int>(push((i14+20)), op(0x37))))
		__asm(push(i15==i14), iftrue, target("___gdtoa__XprivateX__BB12_317_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_316_F"))
		i2 =  ((uint(i15)<uint(i14)) ? -1 : 1)
		__asm(jump, target("___gdtoa__XprivateX__BB12_319_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_317_F"))
		i2 =  (i2 + 1)
		__asm(push(i10>0), iftrue, target("___gdtoa__XprivateX__BB12_469_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_318_F"))
		i2 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_319_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_319_F"))
		__asm(push(i2>-1), iftrue, target("___gdtoa__XprivateX__BB12_311_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_320_F"))
		i2 =  (10)
		mstate.esp -= 8
		__asm(push(i8), push(mstate.esp), op(0x3c))
		__asm(push(i2), push((mstate.esp+4)), op(0x3c))
		state = 20
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___gdtoa_state20"))
		i2 = mstate.eax
		mstate.esp += 8
		i13 =  (i13 + -1)
		__asm(push(i20!=0), iftrue, target("___gdtoa__XprivateX__BB12_322_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_321_F"))
		i8 = i13
		i13 = i21
		__asm(jump, target("___gdtoa__XprivateX__BB12_323_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_322_F"))
		i8 =  (10)
		mstate.esp -= 8
		__asm(push(i23), push(mstate.esp), op(0x3c))
		__asm(push(i8), push((mstate.esp+4)), op(0x3c))
		state = 21
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___gdtoa_state21"))
		i23 = mstate.eax
		mstate.esp += 8
		i8 = i13
		i13 = i21
	__asm(lbl("___gdtoa__XprivateX__BB12_323_F"))
		__asm(push(i13>0), iftrue, target("___gdtoa__XprivateX__BB12_342_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_324_F"))
		__asm(push(i19<3), iftrue, target("___gdtoa__XprivateX__BB12_342_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_325_F"))
		__asm(push(i13>-1), iftrue, target("___gdtoa__XprivateX__BB12_327_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_326_F"))
		i3 = i23
		i1 = i11
		__asm(jump, target("___gdtoa__XprivateX__BB12_337_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_327_F"))
		i1 =  (5)
		mstate.esp -= 8
		__asm(push(i11), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 22
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___gdtoa_state22"))
		i1 = mstate.eax
		mstate.esp += 8
		i3 =  ((__xasm<int>(push((i2+16)), op(0x37))))
		i4 =  ((__xasm<int>(push((i1+16)), op(0x37))))
		i11 =  (i3 - i4)
		__asm(push(i3==i4), iftrue, target("___gdtoa__XprivateX__BB12_329_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_328_F"))
		i3 = i11
		__asm(jump, target("___gdtoa__XprivateX__BB12_334_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_329_F"))
		i3 =  (0)
	__asm(jump, target("___gdtoa__XprivateX__BB12_330_F"), lbl("___gdtoa__XprivateX__BB12_330_B"), label, lbl("___gdtoa__XprivateX__BB12_330_F")); 
		i11 =  (i3 ^ -1)
		i11 =  (i4 + i11)
		i13 =  (i11 << 2)
		i12 =  (i2 + i13)
		i13 =  (i1 + i13)
		i12 =  ((__xasm<int>(push((i12+20)), op(0x37))))
		i13 =  ((__xasm<int>(push((i13+20)), op(0x37))))
		__asm(push(i12==i13), iftrue, target("___gdtoa__XprivateX__BB12_332_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_331_F"))
		i3 =  ((uint(i12)<uint(i13)) ? -1 : 1)
		__asm(jump, target("___gdtoa__XprivateX__BB12_334_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_332_F"))
		i3 =  (i3 + 1)
		__asm(push(i11>0), iftrue, target("___gdtoa__XprivateX__BB12_470_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_333_F"))
		i3 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_334_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_334_F"))
		__asm(push(i3<1), iftrue, target("___gdtoa__XprivateX__BB12_336_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_335_F"))
		i3 = i23
		i4 = i8
		__asm(jump, target("___gdtoa__XprivateX__BB12_171_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_336_F"))
		i3 = i23
	__asm(lbl("___gdtoa__XprivateX__BB12_337_F"))
		i4 =  ((__xasm<int>(push((mstate.ebp+-207)), op(0x37))))
		i4 =  (i4 ^ -1)
		__asm(push(i1==0), iftrue, target("___gdtoa__XprivateX__BB12_339_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_338_F"))
		i11 =  (_freelist)
		i13 =  ((__xasm<int>(push((i1+4)), op(0x37))))
		i13 =  (i13 << 2)
		i11 =  (i11 + i13)
		i13 =  ((__xasm<int>(push(i11), op(0x37))))
		__asm(push(i13), push(i1), op(0x3c))
		__asm(push(i1), push(i11), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_339_F"))
		__asm(push(i3==0), iftrue, target("___gdtoa__XprivateX__BB12_341_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_340_F"))
		i1 =  (16)
		i11 =  (0)
		i13 = i5
		__asm(jump, target("___gdtoa__XprivateX__BB12_448_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_341_F"))
		i1 =  (16)
		i3 = i2
		i2 = i5
		i23 = i4
		__asm(jump, target("___gdtoa__XprivateX__BB12_455_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_342_F"))
		__asm(push(i20!=0), iftrue, target("___gdtoa__XprivateX__BB12_345_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_343_F"))
		mstate.esp -= 8
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i11), push((mstate.esp+4)), op(0x3c))
		mstate.esp -= 4;FSM___quorem_D2A.start()
	__asm(lbl("___gdtoa_state23"))
		i1 = mstate.eax
		mstate.esp += 8
		i1 =  (i1 + 48)
		__asm(push(i1), push(i5), op(0x3a))
		i3 =  (i5 + 1)
		__asm(push(i13>1), iftrue, target("___gdtoa__XprivateX__BB12_416_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_344_F"))
		i4 =  (0)
		i13 = i23
		__asm(jump, target("___gdtoa__XprivateX__BB12_421_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_345_F"))
		__asm(push(i3>0), iftrue, target("___gdtoa__XprivateX__BB12_347_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_346_F"))
		i3 = i23
		__asm(jump, target("___gdtoa__XprivateX__BB12_348_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_347_F"))
		mstate.esp -= 8
		__asm(push(i23), push(mstate.esp), op(0x3c))
		__asm(push(i3), push((mstate.esp+4)), op(0x3c))
		state = 24
		mstate.esp -= 4;FSM___lshift_D2A.start()
		return
	__asm(lbl("___gdtoa_state24"))
		i3 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___gdtoa__XprivateX__BB12_348_F"))
		i1 =  (i1 & 1)
		__asm(push(i1!=0), iftrue, target("___gdtoa__XprivateX__BB12_350_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_349_F"))
		i1 = i3
		__asm(jump, target("___gdtoa__XprivateX__BB12_351_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_350_F"))
		i1 =  (1)
		i23 =  ((__xasm<int>(push((i3+4)), op(0x37))))
		mstate.esp -= 4
		__asm(push(i23), push(mstate.esp), op(0x3c))
		state = 25
		mstate.esp -= 4;FSM___Balloc_D2A.start()
		return
	__asm(lbl("___gdtoa_state25"))
		i23 = mstate.eax
		mstate.esp += 4
		i9 =  ((__xasm<int>(push((i3+16)), op(0x37))))
		i10 =  (i23 + 12)
		i9 =  (i9 << 2)
		i14 =  (i3 + 12)
		i9 =  (i9 + 8)
		memcpy(i10, i14, i9)
		mstate.esp -= 8
		__asm(push(i23), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 26
		mstate.esp -= 4;FSM___lshift_D2A.start()
		return
	__asm(lbl("___gdtoa_state26"))
		i1 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___gdtoa__XprivateX__BB12_351_F"))
		i23 =  (0)
	__asm(jump, target("___gdtoa__XprivateX__BB12_352_F"), lbl("___gdtoa__XprivateX__BB12_352_B"), label, lbl("___gdtoa__XprivateX__BB12_352_F")); 
		i9 = i3
		i10 = i1
		mstate.esp -= 8
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i11), push((mstate.esp+4)), op(0x3c))
		mstate.esp -= 4;FSM___quorem_D2A.start()
	__asm(lbl("___gdtoa_state27"))
		i1 = mstate.eax
		mstate.esp += 8
		i3 =  ((__xasm<int>(push((i2+16)), op(0x37))))
		i14 =  ((__xasm<int>(push((i9+16)), op(0x37))))
		i15 =  (i3 - i14)
		i16 =  (i2 + 16)
		i17 =  (i1 + 48)
		i18 =  (i12 + i23)
		i20 =  (i23 + 1)
		__asm(push(i3==i14), iftrue, target("___gdtoa__XprivateX__BB12_354_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_353_F"))
		i3 = i15
		__asm(jump, target("___gdtoa__XprivateX__BB12_359_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_354_F"))
		i3 =  (0)
	__asm(jump, target("___gdtoa__XprivateX__BB12_355_F"), lbl("___gdtoa__XprivateX__BB12_355_B"), label, lbl("___gdtoa__XprivateX__BB12_355_F")); 
		i15 =  (i3 ^ -1)
		i15 =  (i14 + i15)
		i21 =  (i15 << 2)
		i22 =  (i2 + i21)
		i21 =  (i9 + i21)
		i22 =  ((__xasm<int>(push((i22+20)), op(0x37))))
		i21 =  ((__xasm<int>(push((i21+20)), op(0x37))))
		__asm(push(i22==i21), iftrue, target("___gdtoa__XprivateX__BB12_357_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_356_F"))
		i3 =  ((uint(i22)<uint(i21)) ? -1 : 1)
		__asm(jump, target("___gdtoa__XprivateX__BB12_359_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_357_F"))
		i3 =  (i3 + 1)
		__asm(push(i15>0), iftrue, target("___gdtoa__XprivateX__BB12_471_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_358_F"))
		i3 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_359_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_359_F"))
		mstate.esp -= 8
		__asm(push(i11), push(mstate.esp), op(0x3c))
		__asm(push(i10), push((mstate.esp+4)), op(0x3c))
		state = 28
		mstate.esp -= 4;FSM___diff_D2A.start()
		return
	__asm(lbl("___gdtoa_state28"))
		i14 = mstate.eax
		mstate.esp += 8
		i15 =  ((__xasm<int>(push((i14+12)), op(0x37))))
		__asm(push(i15==0), iftrue, target("___gdtoa__XprivateX__BB12_361_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_360_F"))
		i15 =  (1)
		__asm(jump, target("___gdtoa__XprivateX__BB12_368_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_361_F"))
		i15 =  ((__xasm<int>(push(i16), op(0x37))))
		i21 =  ((__xasm<int>(push((i14+16)), op(0x37))))
		i22 =  (i15 - i21)
		__asm(push(i15==i21), iftrue, target("___gdtoa__XprivateX__BB12_363_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_362_F"))
		i15 = i22
		__asm(jump, target("___gdtoa__XprivateX__BB12_368_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_363_F"))
		i15 =  (0)
	__asm(jump, target("___gdtoa__XprivateX__BB12_364_F"), lbl("___gdtoa__XprivateX__BB12_364_B"), label, lbl("___gdtoa__XprivateX__BB12_364_F")); 
		i22 =  (i15 ^ -1)
		i22 =  (i21 + i22)
		i24 =  (i22 << 2)
		i25 =  (i2 + i24)
		i24 =  (i14 + i24)
		i25 =  ((__xasm<int>(push((i25+20)), op(0x37))))
		i24 =  ((__xasm<int>(push((i24+20)), op(0x37))))
		__asm(push(i25==i24), iftrue, target("___gdtoa__XprivateX__BB12_366_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_365_F"))
		i15 =  ((uint(i25)<uint(i24)) ? -1 : 1)
		__asm(jump, target("___gdtoa__XprivateX__BB12_368_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_366_F"))
		i15 =  (i15 + 1)
		__asm(push(i22>0), iftrue, target("___gdtoa__XprivateX__BB12_472_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_367_F"))
		i15 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_368_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_368_F"))
		__asm(push(i14==0), iftrue, target("___gdtoa__XprivateX__BB12_370_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_369_F"))
		i21 =  (_freelist)
		i22 =  ((__xasm<int>(push((i14+4)), op(0x37))))
		i22 =  (i22 << 2)
		i21 =  (i21 + i22)
		i22 =  ((__xasm<int>(push(i21), op(0x37))))
		__asm(push(i22), push(i14), op(0x3c))
		__asm(push(i14), push(i21), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_370_F"))
		__asm(push(i15!=0), iftrue, target("___gdtoa__XprivateX__BB12_381_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_371_F"))
		__asm(push(i19!=0), iftrue, target("___gdtoa__XprivateX__BB12_381_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_372_F"))
		i14 =  ((__xasm<int>(push(i4), op(0x37))))
		i14 =  (i14 & 1)
		__asm(push(i14!=0), iftrue, target("___gdtoa__XprivateX__BB12_381_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_373_F"))
		__asm(push(i17!=57), iftrue, target("___gdtoa__XprivateX__BB12_375_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_374_F"), lbl("___gdtoa__XprivateX__BB12_374_B"), label, lbl("___gdtoa__XprivateX__BB12_374_F")); 
		__asm(jump, target("___gdtoa__XprivateX__BB12_408_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_375_F"))
		__asm(push(i3>0), iftrue, target("___gdtoa__XprivateX__BB12_379_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_376_F"))
		i1 =  ((__xasm<int>(push(i16), op(0x37))))
		__asm(push(i1>1), iftrue, target("___gdtoa__XprivateX__BB12_378_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_377_F"))
		i1 =  ((__xasm<int>(push((i2+20)), op(0x37))))
		__asm(push(i1==0), iftrue, target("___gdtoa__XprivateX__BB12_380_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_378_F"))
		i12 =  (16)
		i1 =  (i23 + i5)
		__asm(push(i17), push(i18), op(0x3a))
		i4 =  (i1 + 1)
		i13 = i9
		i3 = i10
		i1 = i11
		i23 = i4
		i4 = i8
		i11 = i12
		__asm(jump, target("___gdtoa__XprivateX__BB12_444_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_379_F"))
		i12 =  (32)
		i3 =  (i23 + i5)
		i1 =  (i1 + 49)
		__asm(push(i1), push(i18), op(0x3a))
		i4 =  (i3 + 1)
		i13 = i9
		i3 = i10
		i1 = i11
		i23 = i4
		i4 = i8
		i11 = i12
		__asm(jump, target("___gdtoa__XprivateX__BB12_444_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_380_F"))
		i12 =  (0)
		i1 =  (i23 + i5)
		__asm(push(i17), push(i18), op(0x3a))
		i4 =  (i1 + 1)
		i13 = i9
		i3 = i10
		i1 = i11
		i23 = i4
		i4 = i8
		i11 = i12
		__asm(jump, target("___gdtoa__XprivateX__BB12_444_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_381_F"))
		__asm(push(i3<0), iftrue, target("___gdtoa__XprivateX__BB12_385_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_382_F"))
		__asm(push(i3!=0), iftrue, target("___gdtoa__XprivateX__BB12_404_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_383_F"))
		__asm(push(i19!=0), iftrue, target("___gdtoa__XprivateX__BB12_404_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_384_F"))
		i3 =  ((__xasm<int>(push(i4), op(0x37))))
		i3 =  (i3 & 1)
		__asm(push(i3!=0), iftrue, target("___gdtoa__XprivateX__BB12_404_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_385_F"))
		__asm(push(i15>0), iftrue, target("___gdtoa__XprivateX__BB12_387_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_386_F"))
		i1 =  (0)
		i3 = i17
		__asm(jump, target("___gdtoa__XprivateX__BB12_400_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_387_F"))
		i3 =  (1)
		mstate.esp -= 8
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i3), push((mstate.esp+4)), op(0x3c))
		state = 29
		mstate.esp -= 4;FSM___lshift_D2A.start()
		return
	__asm(lbl("___gdtoa_state29"))
		i2 = mstate.eax
		mstate.esp += 8
		i3 =  ((__xasm<int>(push((i2+16)), op(0x37))))
		i4 =  ((__xasm<int>(push((i11+16)), op(0x37))))
		i13 =  (i3 - i4)
		__asm(push(i3==i4), iftrue, target("___gdtoa__XprivateX__BB12_389_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_388_F"))
		i3 = i13
		__asm(jump, target("___gdtoa__XprivateX__BB12_394_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_389_F"))
		i3 =  (0)
	__asm(jump, target("___gdtoa__XprivateX__BB12_390_F"), lbl("___gdtoa__XprivateX__BB12_390_B"), label, lbl("___gdtoa__XprivateX__BB12_390_F")); 
		i13 =  (i3 ^ -1)
		i13 =  (i4 + i13)
		i15 =  (i13 << 2)
		i19 =  (i2 + i15)
		i15 =  (i11 + i15)
		i19 =  ((__xasm<int>(push((i19+20)), op(0x37))))
		i15 =  ((__xasm<int>(push((i15+20)), op(0x37))))
		__asm(push(i19==i15), iftrue, target("___gdtoa__XprivateX__BB12_392_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_391_F"))
		i3 =  ((uint(i19)<uint(i15)) ? -1 : 1)
		__asm(jump, target("___gdtoa__XprivateX__BB12_394_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_392_F"))
		i3 =  (i3 + 1)
		__asm(push(i13>0), iftrue, target("___gdtoa__XprivateX__BB12_473_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_393_F"))
		i3 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_394_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_394_F"))
		__asm(push(i3>0), iftrue, target("___gdtoa__XprivateX__BB12_398_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_395_F"))
		__asm(push(i3==0), iftrue, target("___gdtoa__XprivateX__BB12_397_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_396_F"), lbl("___gdtoa__XprivateX__BB12_396_B"), label, lbl("___gdtoa__XprivateX__BB12_396_F")); 
		i1 =  (32)
		i3 = i17
		__asm(jump, target("___gdtoa__XprivateX__BB12_400_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_397_F"))
		i3 =  (i17 & 1)
		__asm(push(i3==0), iftrue, target("___gdtoa__XprivateX__BB12_396_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_398_F"))
		i3 =  (i1 + 49)
		__asm(push(i3==58), iftrue, target("___gdtoa__XprivateX__BB12_407_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_399_F"))
		i1 =  (32)
		__asm(jump, target("___gdtoa__XprivateX__BB12_400_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_400_F"))
		i12 = i1
		i1 = i3
		i3 =  ((__xasm<int>(push((i2+16)), op(0x37))))
		__asm(push(i3>1), iftrue, target("___gdtoa__XprivateX__BB12_402_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_401_F"))
		i3 =  ((__xasm<int>(push((i2+20)), op(0x37))))
		__asm(push(i3==0), iftrue, target("___gdtoa__XprivateX__BB12_403_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_402_F"))
		i12 =  (16)
		i3 =  (i23 + i5)
		__asm(push(i1), push(i18), op(0x3a))
		i4 =  (i3 + 1)
		i13 = i9
		i3 = i10
		i1 = i11
		i23 = i4
		i4 = i8
		i11 = i12
		__asm(jump, target("___gdtoa__XprivateX__BB12_444_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_403_F"))
		i3 =  (i23 + i5)
		__asm(push(i1), push(i18), op(0x3a))
		i4 =  (i3 + 1)
		i13 = i9
		i3 = i10
		i1 = i11
		i23 = i4
		i4 = i8
		i11 = i12
		__asm(jump, target("___gdtoa__XprivateX__BB12_444_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_404_F"))
		__asm(push(i15<1), iftrue, target("___gdtoa__XprivateX__BB12_411_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_405_F"))
		__asm(push(i17==57), iftrue, target("___gdtoa__XprivateX__BB12_374_B"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_406_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_406_F"))
		i12 =  (32)
		i1 =  (i23 + i5)
		i3 =  (i17 + 1)
		__asm(push(i3), push(i18), op(0x3a))
		i4 =  (i1 + 1)
		i13 = i9
		i3 = i10
		i1 = i11
		i23 = i4
		i4 = i8
		i11 = i12
		__asm(jump, target("___gdtoa__XprivateX__BB12_444_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_407_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_408_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_408_F"))
		i1 =  (57)
		i3 =  (i23 + i5)
		__asm(push(i1), push(i18), op(0x3a))
		i1 =  (i3 + 1)
		i3 =  (i12 + i23)
		i4 = i9
		i13 = i10
		__asm(jump, target("___gdtoa__XprivateX__BB12_409_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_409_F"), lbl("___gdtoa__XprivateX__BB12_409_B"), label, lbl("___gdtoa__XprivateX__BB12_409_F")); 
		i23 = i13
		i9 = i1
		__asm(push(i3==i5), iftrue, target("___gdtoa__XprivateX__BB12_437_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_410_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_410_F"))
		i1 = i4
		i4 = i23
		__asm(jump, target("___gdtoa__XprivateX__BB12_430_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_411_F"))
		__asm(push(i17), push(i18), op(0x3a))
		i1 =  (i23 + 1)
		__asm(push(i20==i13), iftrue, target("___gdtoa__XprivateX__BB12_420_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_412_F"))
		i1 =  (10)
		mstate.esp -= 8
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 30
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___gdtoa_state30"))
		i2 = mstate.eax
		mstate.esp += 8
		__asm(push(i9!=i10), iftrue, target("___gdtoa__XprivateX__BB12_414_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_413_F"))
		i1 =  (10)
		mstate.esp -= 8
		__asm(push(i10), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 31
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___gdtoa_state31"))
		i1 = mstate.eax
		mstate.esp += 8
		i3 = i1
		__asm(jump, target("___gdtoa__XprivateX__BB12_415_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_414_F"))
		i1 =  (10)
		mstate.esp -= 8
		__asm(push(i9), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 32
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___gdtoa_state32"))
		i3 = mstate.eax
		mstate.esp += 8
		mstate.esp -= 8
		__asm(push(i10), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 33
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___gdtoa_state33"))
		i1 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___gdtoa__XprivateX__BB12_415_F"))
		i23 =  (i23 + 1)
		__asm(jump, target("___gdtoa__XprivateX__BB12_352_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_416_F"))
		i1 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_417_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_417_F"), lbl("___gdtoa__XprivateX__BB12_417_B"), label, lbl("___gdtoa__XprivateX__BB12_417_F")); 
		i3 =  (10)
		mstate.esp -= 8
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i3), push((mstate.esp+4)), op(0x3c))
		state = 34
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___gdtoa_state34"))
		i2 = mstate.eax
		mstate.esp += 8
		mstate.esp -= 8
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i11), push((mstate.esp+4)), op(0x3c))
		mstate.esp -= 4;FSM___quorem_D2A.start()
	__asm(lbl("___gdtoa_state35"))
		i3 = mstate.eax
		mstate.esp += 8
		i3 =  (i3 + 48)
		i4 =  (i12 + i1)
		__asm(push(i3), push((i4+1)), op(0x3a))
		i4 =  (i1 + 1)
		i1 =  (i1 + 2)
		__asm(push(i1>=i13), iftrue, target("___gdtoa__XprivateX__BB12_419_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_418_F"))
		i1 = i4
		__asm(jump, target("___gdtoa__XprivateX__BB12_417_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_419_F"))
		i9 =  (0)
		i1 =  (i4 << 0)
		i1 =  (i1 + i5)
		i4 =  (i1 + 1)
		i1 = i3
		i3 = i4
		i13 = i23
		i4 = i9
		__asm(jump, target("___gdtoa__XprivateX__BB12_421_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_420_F"))
		i3 =  (i5 + i1)
		i1 = i17
		i13 = i10
		i4 = i9
	__asm(lbl("___gdtoa__XprivateX__BB12_421_F"))
		i23 = i13
		i13 =  (1)
		mstate.esp -= 8
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i13), push((mstate.esp+4)), op(0x3c))
		state = 36
		mstate.esp -= 4;FSM___lshift_D2A.start()
		return
	__asm(lbl("___gdtoa_state36"))
		i2 = mstate.eax
		mstate.esp += 8
		i13 =  ((__xasm<int>(push((i2+16)), op(0x37))))
		i9 =  ((__xasm<int>(push((i11+16)), op(0x37))))
		i10 =  (i13 - i9)
		__asm(push(i13==i9), iftrue, target("___gdtoa__XprivateX__BB12_423_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_422_F"))
		i13 = i10
		__asm(jump, target("___gdtoa__XprivateX__BB12_428_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_423_F"))
		i13 =  (0)
	__asm(jump, target("___gdtoa__XprivateX__BB12_424_F"), lbl("___gdtoa__XprivateX__BB12_424_B"), label, lbl("___gdtoa__XprivateX__BB12_424_F")); 
		i10 =  (i13 ^ -1)
		i10 =  (i9 + i10)
		i12 =  (i10 << 2)
		i14 =  (i2 + i12)
		i12 =  (i11 + i12)
		i14 =  ((__xasm<int>(push((i14+20)), op(0x37))))
		i12 =  ((__xasm<int>(push((i12+20)), op(0x37))))
		__asm(push(i14==i12), iftrue, target("___gdtoa__XprivateX__BB12_426_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_425_F"))
		i13 =  ((uint(i14)<uint(i12)) ? -1 : 1)
		__asm(jump, target("___gdtoa__XprivateX__BB12_428_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_426_F"))
		i13 =  (i13 + 1)
		__asm(push(i10>0), iftrue, target("___gdtoa__XprivateX__BB12_474_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_427_F"))
		i13 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_428_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_428_F"))
		__asm(push(i13<1), iftrue, target("___gdtoa__XprivateX__BB12_432_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_429_F"), lbl("___gdtoa__XprivateX__BB12_429_B"), label, lbl("___gdtoa__XprivateX__BB12_429_F")); 
		i1 = i4
		i4 = i23
		__asm(jump, target("___gdtoa__XprivateX__BB12_430_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_430_F"))
		i23 = i4
		i9 = i3
		i3 =  ((__xasm<int>(push((i9+-1)), op(0x35))))
		i10 =  (i9 + -1)
		__asm(push(i3!=57), iftrue, target("___gdtoa__XprivateX__BB12_438_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_431_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_431_F"))
		i4 = i1
		i13 = i23
		i1 = i9
		i3 = i10
		__asm(jump, target("___gdtoa__XprivateX__BB12_409_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_432_F"))
		__asm(push(i13!=0), iftrue, target("___gdtoa__XprivateX__BB12_434_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_433_F"))
		i1 =  (i1 & 1)
		__asm(push(i1==0), iftrue, target("___gdtoa__XprivateX__BB12_434_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_429_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_434_F"))
		i1 =  ((__xasm<int>(push((i2+16)), op(0x37))))
		__asm(push(i1>1), iftrue, target("___gdtoa__XprivateX__BB12_439_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_435_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_435_F"))
		i1 =  ((__xasm<int>(push((i2+20)), op(0x37))))
		__asm(push(i1!=0), iftrue, target("___gdtoa__XprivateX__BB12_439_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_436_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_436_F"))
		i1 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_440_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_437_F"))
		i1 =  (49)
		__asm(push(i1), push(i3), op(0x3a))
		i10 =  (32)
		i8 =  (i8 + 1)
		i13 = i4
		i3 = i23
		i1 = i11
		i23 = i9
		i4 = i8
		i11 = i10
		__asm(jump, target("___gdtoa__XprivateX__BB12_444_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_438_F"))
		i12 =  (32)
		i3 =  (i3 + 1)
		__asm(push(i3), push(i10), op(0x3a))
		i13 = i1
		i3 = i23
		i1 = i11
		i23 = i9
		i4 = i8
		i11 = i12
		__asm(jump, target("___gdtoa__XprivateX__BB12_444_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_439_F"))
		i1 =  (16)
	__asm(lbl("___gdtoa__XprivateX__BB12_440_F"))
		i9 = i1
		i1 =  (0)
	__asm(jump, target("___gdtoa__XprivateX__BB12_441_F"), lbl("___gdtoa__XprivateX__BB12_441_B"), label, lbl("___gdtoa__XprivateX__BB12_441_F")); 
		i13 =  (i1 ^ -1)
		i13 =  (i3 + i13)
		i13 =  ((__xasm<int>(push(i13), op(0x35))))
		i1 =  (i1 + 1)
		__asm(push(i13!=48), iftrue, target("___gdtoa__XprivateX__BB12_443_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_442_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_441_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_443_F"))
		i1 =  (i1 + -1)
		i10 =  (i3 - i1)
		i13 = i4
		i3 = i23
		i1 = i11
		i23 = i10
		i4 = i8
		i11 = i9
	__asm(lbl("___gdtoa__XprivateX__BB12_444_F"))
		i8 = i11
		__asm(push(i1==0), iftrue, target("___gdtoa__XprivateX__BB12_446_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_445_F"))
		i11 =  (_freelist)
		i9 =  ((__xasm<int>(push((i1+4)), op(0x37))))
		i9 =  (i9 << 2)
		i11 =  (i11 + i9)
		i9 =  ((__xasm<int>(push(i11), op(0x37))))
		__asm(push(i9), push(i1), op(0x3c))
		__asm(push(i1), push(i11), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_446_F"))
		__asm(push(i3==0), iftrue, target("___gdtoa__XprivateX__BB12_475_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_447_F"))
		i11 = i13
		i13 = i23
		i1 = i8
		__asm(jump, target("___gdtoa__XprivateX__BB12_448_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_448_F"))
		__asm(push(i11==i3), iftrue, target("___gdtoa__XprivateX__BB12_451_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_449_F"))
		__asm(push(i11==0), iftrue, target("___gdtoa__XprivateX__BB12_451_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_450_F"))
		i23 =  (_freelist)
		i8 =  ((__xasm<int>(push((i11+4)), op(0x37))))
		i8 =  (i8 << 2)
		i23 =  (i23 + i8)
		i8 =  ((__xasm<int>(push(i23), op(0x37))))
		__asm(push(i8), push(i11), op(0x3c))
		__asm(push(i11), push(i23), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_451_F"))
		__asm(push(i3!=0), iftrue, target("___gdtoa__XprivateX__BB12_453_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_452_F"))
		i3 = i2
		i2 = i13
		i23 = i4
		__asm(jump, target("___gdtoa__XprivateX__BB12_455_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_453_F"))
		i11 =  (_freelist)
		i23 =  ((__xasm<int>(push((i3+4)), op(0x37))))
		i23 =  (i23 << 2)
		i11 =  (i11 + i23)
		i23 =  ((__xasm<int>(push(i11), op(0x37))))
		__asm(push(i23), push(i3), op(0x3c))
		__asm(push(i3), push(i11), op(0x3c))
		i3 = i2
		i2 = i13
		i23 = i4
		__asm(jump, target("___gdtoa__XprivateX__BB12_455_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_454_F"))
		i1 =  (0)
		i2 =  (i5 + i4)
		i3 = i11
		i23 = i13
	__asm(jump, target("___gdtoa__XprivateX__BB12_455_F"), lbl("___gdtoa__XprivateX__BB12_455_B"), label, lbl("___gdtoa__XprivateX__BB12_455_F")); 
		i4 = i23
		__asm(push(i3==0), iftrue, target("___gdtoa__XprivateX__BB12_457_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_456_F"))
		i8 =  (_freelist)
		i9 =  ((__xasm<int>(push((i3+4)), op(0x37))))
		i9 =  (i9 << 2)
		i8 =  (i8 + i9)
		i9 =  ((__xasm<int>(push(i8), op(0x37))))
		__asm(push(i9), push(i3), op(0x3c))
		__asm(push(i3), push(i8), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_457_F"))
		i3 =  (0)
		__asm(push(i3), push(i2), op(0x3a))
		i3 =  (i4 + 1)
		__asm(push(i3), push(i6), op(0x3c))
		__asm(push(i7==0), iftrue, target("___gdtoa__XprivateX__BB12_476_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_458_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_459_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_459_F"))
		__asm(push(i2), push(i7), op(0x3c))
		i2 =  ((__xasm<int>(push(i0), op(0x37))))
		i2 =  (i2 | i1)
		__asm(push(i2), push(i0), op(0x3c))
		__asm(jump, target("___gdtoa__XprivateX__BB12_462_F"))
	__asm(lbl("___gdtoa__XprivateX__BB12_460_F"))
		i2 =  (16)
		__asm(jump, target("___gdtoa__XprivateX__BB12_461_F"))
	__asm(jump, target("___gdtoa__XprivateX__BB12_461_F"), lbl("___gdtoa__XprivateX__BB12_461_B"), label, lbl("___gdtoa__XprivateX__BB12_461_F")); 
		i1 = i2
		i2 =  ((__xasm<int>(push(i0), op(0x37))))
		i1 =  (i2 | i1)
		__asm(push(i1), push(i0), op(0x3c))
	__asm(lbl("___gdtoa__XprivateX__BB12_462_F"))
		mstate.eax = i5
	__asm(lbl("___gdtoa__XprivateX__BB12_463_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___gdtoa__XprivateX__BB12_464_F"))
		i0 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_79_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_465_F"))
		i1 = i8
		i8 = i3
		__asm(jump, target("___gdtoa__XprivateX__BB12_68_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_466_F"))
		i5 =  (0)
		__asm(jump, target("___gdtoa__XprivateX__BB12_138_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_467_F"))
		i2 =  (3)
		__asm(jump, target("___gdtoa__XprivateX__BB12_162_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_468_F"))
		f0 =  (1)
		i2 =  (2)
		__asm(jump, target("___gdtoa__XprivateX__BB12_162_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_469_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_315_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_470_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_330_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_471_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_355_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_472_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_364_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_473_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_390_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_474_F"))
		__asm(jump, target("___gdtoa__XprivateX__BB12_424_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_475_F"))
		i3 = i2
		i2 = i23
		i23 = i4
		i1 = i8
		__asm(jump, target("___gdtoa__XprivateX__BB12_455_B"))
	__asm(lbl("___gdtoa__XprivateX__BB12_476_F"))
		i2 = i1
		__asm(jump, target("___gdtoa__XprivateX__BB12_461_B"))
	__asm(lbl("___gdtoa_errState"))
		throw("Invalid state in ___gdtoa")
	}
}



// Sync
public const ___quorem_D2A:int = regFunc(FSM___quorem_D2A.start)

public final class FSM___quorem_D2A extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
		var i8:int, i9:int, i10:int, i11:int, i12:int, i13:int, i14:int, i15:int
		var i16:int, i17:int, i18:int, i19:int, i20:int, i21:int, i22:int, i23:int


		__asm(label, lbl("___quorem_D2A_entry"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i2 =  ((__xasm<int>(push((i1+16)), op(0x37))))
		i3 =  ((__xasm<int>(push((i0+16)), op(0x37))))
		i4 =  (i0 + 16)
		i5 =  (i1 + 16)
		i6 = i1
		i7 = i0
		__asm(push(i3>=i2), iftrue, target("___quorem_D2A__XprivateX__BB13_3_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_1_F"))
		i0 =  (0)
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_2_F"))
	__asm(jump, target("___quorem_D2A__XprivateX__BB13_2_F"), lbl("___quorem_D2A__XprivateX__BB13_2_B"), label, lbl("___quorem_D2A__XprivateX__BB13_2_F")); 
		mstate.eax = i0
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_37_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_3_F"))
		i8 =  (i2 + -1)
		i9 =  (i8 << 2)
		i10 =  (i1 + i9)
		i10 =  ((__xasm<int>(push((i10+20)), op(0x37))))
		i9 =  (i0 + i9)
		i11 =  ((__xasm<int>(push((i9+20)), op(0x37))))
		i10 =  (i10 + 1)
		i9 =  (i9 + 20)
		i10 =  (uint(i11) / uint(i10))
		__asm(push(i10!=0), iftrue, target("___quorem_D2A__XprivateX__BB13_5_F"))
	__asm(jump, target("___quorem_D2A__XprivateX__BB13_4_F"), lbl("___quorem_D2A__XprivateX__BB13_4_B"), label, lbl("___quorem_D2A__XprivateX__BB13_4_F")); 
		i2 = i3
		i3 = i8
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_18_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_5_F"))
		i11 =  (20)
		i12 =  (0)
		i13 = i12
		i14 = i12
		i15 = i12
		i16 = i10
		i17 = i14
		i18 = i13
	__asm(jump, target("___quorem_D2A__XprivateX__BB13_6_F"), lbl("___quorem_D2A__XprivateX__BB13_6_B"), label, lbl("___quorem_D2A__XprivateX__BB13_6_F")); 
		i19 =  (0)
		i20 =  (i6 + i11)
		mstate.esp -= 16
		i20 =  ((__xasm<int>(push(i20), op(0x37))))
		__asm(push(i20), push(mstate.esp), op(0x3c))
		__asm(push(i19), push((mstate.esp+4)), op(0x3c))
		__asm(push(i16), push((mstate.esp+8)), op(0x3c))
		__asm(push(i12), push((mstate.esp+12)), op(0x3c))
		mstate.esp -= 4;(mstate.funcs[___muldi3])()
	__asm(lbl("___quorem_D2A_state1"))
		i20 = mstate.eax
		i21 = mstate.edx
		i22 =  (i7 + i11)
		i23 =  ((__xasm<int>(push(i22), op(0x37))))
		i14 =  __addc(i20, i14)
		i13 =  __adde(i21, i13)
		i14 =  __subc(i23, i14)
		i20 =  __sube(i19, i19)
		i14 =  __subc(i14, i17)
		i17 =  __sube(i20, i18)
		__asm(push(i14), push(i22), op(0x3c))
		i14 =  (i17 & 1)
		i11 =  (i11 + 4)
		i15 =  (i15 + 1)
		mstate.esp += 16
		i18 = i19
		__asm(push(i15>i8), iftrue, target("___quorem_D2A__XprivateX__BB13_8_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_7_F"))
		i17 = i14
		i14 = i13
		i13 = i19
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_6_B"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_8_F"))
		i9 =  ((__xasm<int>(push(i9), op(0x37))))
		__asm(push(i9!=0), iftrue, target("___quorem_D2A__XprivateX__BB13_4_B"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_9_F"))
		i3 =  (i2 + -2)
		__asm(push(i3>0), iftrue, target("___quorem_D2A__XprivateX__BB13_11_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_10_F"))
		i2 = i8
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_17_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_11_F"))
		i9 =  (0)
		i11 =  (i2 << 2)
		i11 =  (i7 + i11)
		i11 =  (i11 + 12)
		i2 =  (i2 + -1)
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_15_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_12_B"), label)
		i9 =  (i12 + -4)
		i12 =  (i11 + -1)
		i13 =  (i2 + 1)
		i2 =  (i2 ^ -1)
		i2 =  (i3 + i2)
		__asm(push(i2>0), iftrue, target("___quorem_D2A__XprivateX__BB13_14_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_13_F"))
		i2 = i12
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_17_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_14_F"))
		i11 = i9
		i2 = i12
		i9 = i13
	__asm(lbl("___quorem_D2A__XprivateX__BB13_15_F"))
		i12 = i11
		i11 = i2
		i2 = i9
		i9 =  ((__xasm<int>(push(i12), op(0x37))))
		__asm(push(i9==0), iftrue, target("___quorem_D2A__XprivateX__BB13_12_B"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_16_F"))
		i2 = i11
	__asm(lbl("___quorem_D2A__XprivateX__BB13_17_F"))
		i3 = i2
		__asm(push(i3), push(i4), op(0x3c))
		i2 = i3
	__asm(lbl("___quorem_D2A__XprivateX__BB13_18_F"))
		i5 =  ((__xasm<int>(push(i5), op(0x37))))
		i9 =  (i2 - i5)
		__asm(push(i2==i5), iftrue, target("___quorem_D2A__XprivateX__BB13_20_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_19_F"))
		i1 = i9
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_25_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_20_F"))
		i2 =  (0)
	__asm(jump, target("___quorem_D2A__XprivateX__BB13_21_F"), lbl("___quorem_D2A__XprivateX__BB13_21_B"), label, lbl("___quorem_D2A__XprivateX__BB13_21_F")); 
		i9 =  (i2 ^ -1)
		i9 =  (i5 + i9)
		i11 =  (i9 << 2)
		i12 =  (i0 + i11)
		i11 =  (i1 + i11)
		i12 =  ((__xasm<int>(push((i12+20)), op(0x37))))
		i11 =  ((__xasm<int>(push((i11+20)), op(0x37))))
		__asm(push(i12==i11), iftrue, target("___quorem_D2A__XprivateX__BB13_23_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_22_F"))
		i1 =  ((uint(i12)<uint(i11)) ? -1 : 1)
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_25_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_23_F"))
		i2 =  (i2 + 1)
		__asm(push(i9>0), iftrue, target("___quorem_D2A__XprivateX__BB13_38_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_24_F"))
		i1 =  (0)
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_25_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_25_F"))
		__asm(push(i1>-1), iftrue, target("___quorem_D2A__XprivateX__BB13_27_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_26_F"))
		i0 = i10
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_2_B"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_27_F"))
		i1 =  (0)
		i2 =  (20)
		i5 =  (i10 + 1)
		i9 = i1
		i10 = i1
		i11 = i10
		i12 = i9
	__asm(jump, target("___quorem_D2A__XprivateX__BB13_28_F"), lbl("___quorem_D2A__XprivateX__BB13_28_B"), label, lbl("___quorem_D2A__XprivateX__BB13_28_F")); 
		i13 =  (0)
		i14 =  (i6 + i2)
		i14 =  ((__xasm<int>(push(i14), op(0x37))))
		i15 =  (i7 + i2)
		i16 =  ((__xasm<int>(push(i15), op(0x37))))
		i10 =  __addc(i14, i10)
		i9 =  __adde(i9, i13)
		i10 =  __subc(i16, i10)
		i14 =  __sube(i13, i13)
		i10 =  __subc(i10, i11)
		i11 =  __sube(i14, i12)
		__asm(push(i10), push(i15), op(0x3c))
		i10 =  (i11 & 1)
		i2 =  (i2 + 4)
		i1 =  (i1 + 1)
		i12 = i13
		__asm(push(i1>i8), iftrue, target("___quorem_D2A__XprivateX__BB13_30_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_29_F"))
		i11 = i10
		i10 = i9
		i9 = i13
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_28_B"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_30_F"))
		i1 =  (i3 << 2)
		i1 =  (i0 + i1)
		i1 =  ((__xasm<int>(push((i1+20)), op(0x37))))
		__asm(push(i1==0), iftrue, target("___quorem_D2A__XprivateX__BB13_32_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_31_F"))
		i0 = i5
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_2_B"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_32_F"))
		i1 =  (0)
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_34_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_33_B"), label)
		i1 =  (i1 + 1)
	__asm(lbl("___quorem_D2A__XprivateX__BB13_34_F"))
		i2 =  (i1 ^ -1)
		i2 =  (i3 + i2)
		__asm(push(i2<1), iftrue, target("___quorem_D2A__XprivateX__BB13_36_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_35_F"))
		i2 =  (i2 << 2)
		i2 =  (i0 + i2)
		i2 =  ((__xasm<int>(push((i2+20)), op(0x37))))
		__asm(push(i2==0), iftrue, target("___quorem_D2A__XprivateX__BB13_33_B"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_36_F"))
		i0 =  (i3 - i1)
		__asm(push(i0), push(i4), op(0x3c))
		mstate.eax = i5
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_37_F"))
	__asm(lbl("___quorem_D2A__XprivateX__BB13_37_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	__asm(lbl("___quorem_D2A__XprivateX__BB13_38_F"))
		__asm(jump, target("___quorem_D2A__XprivateX__BB13_21_B"))
	}
}



// Async
public const ___Balloc_D2A:int = regFunc(FSM___Balloc_D2A.start)

public final class FSM___Balloc_D2A extends Machine {

	public static function start():void {
			var result:FSM___Balloc_D2A = new FSM___Balloc_D2A
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int

	public static const intRegCount:int = 6

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___Balloc_D2A_entry"))
		__asm(push(state), switchjump(
			"___Balloc_D2A_errState",
			"___Balloc_D2A_state0",
			"___Balloc_D2A_state1"))
	__asm(lbl("___Balloc_D2A_state0"))
	__asm(lbl("___Balloc_D2A__XprivateX__BB14_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  (_freelist)
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i2 =  (i1 << 2)
		i0 =  (i0 + i2)
		i2 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i2==0), iftrue, target("___Balloc_D2A__XprivateX__BB14_2_F"))
	__asm(lbl("___Balloc_D2A__XprivateX__BB14_1_F"))
		i1 =  ((__xasm<int>(push(i2), op(0x37))))
		__asm(push(i1), push(i0), op(0x3c))
		i1 = i2
		__asm(jump, target("___Balloc_D2A__XprivateX__BB14_5_F"))
	__asm(lbl("___Balloc_D2A__XprivateX__BB14_2_F"))
		i0 =  (1)
		i0 =  (i0 << i1)
		i2 =  (i0 << 2)
		i3 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i2 =  (i2 + 27)
		i4 =  (_private_mem)
		i4 =  (i3 - i4)
		i5 =  (i2 >>> 3)
		i4 =  (i4 >> 3)
		i4 =  (i4 + i5)
		__asm(push(uint(i4)>uint(288)), iftrue, target("___Balloc_D2A__XprivateX__BB14_4_F"))
	__asm(lbl("___Balloc_D2A__XprivateX__BB14_3_F"))
		i2 =  (i5 << 3)
		i2 =  (i3 + i2)
		__asm(push(i2), push(_pmem_next), op(0x3c))
		__asm(push(i1), push((i3+4)), op(0x3c))
		__asm(push(i0), push((i3+8)), op(0x3c))
		i1 = i3
		__asm(jump, target("___Balloc_D2A__XprivateX__BB14_5_F"))
	__asm(lbl("___Balloc_D2A__XprivateX__BB14_4_F"))
		i3 =  (0)
		mstate.esp -= 8
		i2 =  (i2 & -8)
		__asm(push(i3), push(mstate.esp), op(0x3c))
		__asm(push(i2), push((mstate.esp+4)), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___Balloc_D2A_state1"))
		i2 = mstate.eax
		mstate.esp += 8
		__asm(push(i1), push((i2+4)), op(0x3c))
		__asm(push(i0), push((i2+8)), op(0x3c))
		i1 = i2
	__asm(lbl("___Balloc_D2A__XprivateX__BB14_5_F"))
		i0 = i1
		i1 =  (0)
		__asm(push(i1), push((i0+16)), op(0x3c))
		__asm(push(i1), push((i0+12)), op(0x3c))
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___Balloc_D2A_errState"))
		throw("Invalid state in ___Balloc_D2A")
	}
}



// Async
public const ___pow5mult_D2A:int = regFunc(FSM___pow5mult_D2A.start)

public final class FSM___pow5mult_D2A extends Machine {

	public static function start():void {
			var result:FSM___pow5mult_D2A = new FSM___pow5mult_D2A
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int

	public static const intRegCount:int = 6

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___pow5mult_D2A_entry"))
		__asm(push(state), switchjump(
			"___pow5mult_D2A_errState",
			"___pow5mult_D2A_state0",
			"___pow5mult_D2A_state1",
			"___pow5mult_D2A_state2",
			"___pow5mult_D2A_state3",
			"___pow5mult_D2A_state4"))
	__asm(lbl("___pow5mult_D2A_state0"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i2 =  (i0 & 3)
		__asm(push(i2!=0), iftrue, target("___pow5mult_D2A__XprivateX__BB15_2_F"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_1_F"))
		__asm(jump, target("___pow5mult_D2A__XprivateX__BB15_3_F"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_2_F"))
		i3 =  (_p05_2E_3773)
		i2 =  (i2 << 2)
		i2 =  (i2 + i3)
		i2 =  ((__xasm<int>(push((i2+-4)), op(0x37))))
		mstate.esp -= 8
		__asm(push(i1), push(mstate.esp), op(0x3c))
		__asm(push(i2), push((mstate.esp+4)), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___pow5mult_D2A_state1"))
		i1 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_3_F"))
		i2 =  (i0 >> 2)
		__asm(push(uint(i0)>uint(3)), iftrue, target("___pow5mult_D2A__XprivateX__BB15_6_F"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_4_F"))
		__asm(jump, target("___pow5mult_D2A__XprivateX__BB15_5_F"))
	__asm(jump, target("___pow5mult_D2A__XprivateX__BB15_5_F"), lbl("___pow5mult_D2A__XprivateX__BB15_5_B"), label, lbl("___pow5mult_D2A__XprivateX__BB15_5_F")); 
		i0 = i1
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_6_F"))
		i0 =  ((__xasm<int>(push(_p5s), op(0x37))))
		__asm(push(i0==0), iftrue, target("___pow5mult_D2A__XprivateX__BB15_8_F"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_7_F"))
		__asm(jump, target("___pow5mult_D2A__XprivateX__BB15_14_F"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_8_F"))
		i0 =  ((__xasm<int>(push((_freelist+4)), op(0x37))))
		__asm(push(i0==0), iftrue, target("___pow5mult_D2A__XprivateX__BB15_10_F"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_9_F"))
		i3 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i3), push((_freelist+4)), op(0x3c))
		__asm(jump, target("___pow5mult_D2A__XprivateX__BB15_13_F"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_10_F"))
		i0 =  (_private_mem)
		i3 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i0 =  (i3 - i0)
		i0 =  (i0 >> 3)
		i0 =  (i0 + 4)
		__asm(push(uint(i0)>uint(288)), iftrue, target("___pow5mult_D2A__XprivateX__BB15_12_F"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_11_F"))
		i0 =  (1)
		i4 =  (i3 + 32)
		__asm(push(i4), push(_pmem_next), op(0x3c))
		__asm(push(i0), push((i3+4)), op(0x3c))
		i0 =  (2)
		__asm(push(i0), push((i3+8)), op(0x3c))
		i0 = i3
		__asm(jump, target("___pow5mult_D2A__XprivateX__BB15_13_F"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_12_F"))
		i0 =  (32)
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 2
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___pow5mult_D2A_state2"))
		i0 = mstate.eax
		mstate.esp += 4
		i3 =  (1)
		__asm(push(i3), push((i0+4)), op(0x3c))
		i3 =  (2)
		__asm(push(i3), push((i0+8)), op(0x3c))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_13_F"))
		i3 =  (0)
		__asm(push(i3), push((i0+12)), op(0x3c))
		i4 =  (625)
		__asm(push(i4), push((i0+20)), op(0x3c))
		i4 =  (1)
		__asm(push(i4), push((i0+16)), op(0x3c))
		__asm(push(i0), push(_p5s), op(0x3c))
		__asm(push(i3), push(i0), op(0x3c))
	__asm(jump, target("___pow5mult_D2A__XprivateX__BB15_14_F"), lbl("___pow5mult_D2A__XprivateX__BB15_14_B"), label, lbl("___pow5mult_D2A__XprivateX__BB15_14_F")); 
		i3 =  (i2 & 1)
		__asm(push(i3!=0), iftrue, target("___pow5mult_D2A__XprivateX__BB15_16_F"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_15_F"))
		__asm(jump, target("___pow5mult_D2A__XprivateX__BB15_19_F"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_16_F"))
		mstate.esp -= 8
		__asm(push(i1), push(mstate.esp), op(0x3c))
		__asm(push(i0), push((mstate.esp+4)), op(0x3c))
		state = 3
		mstate.esp -= 4;FSM___mult_D2A.start()
		return
	__asm(lbl("___pow5mult_D2A_state3"))
		i3 = mstate.eax
		mstate.esp += 8
		__asm(push(i1!=0), iftrue, target("___pow5mult_D2A__XprivateX__BB15_18_F"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_17_F"))
		i1 = i3
		__asm(jump, target("___pow5mult_D2A__XprivateX__BB15_19_F"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_18_F"))
		i4 =  (_freelist)
		i5 =  ((__xasm<int>(push((i1+4)), op(0x37))))
		i5 =  (i5 << 2)
		i4 =  (i4 + i5)
		i5 =  ((__xasm<int>(push(i4), op(0x37))))
		__asm(push(i5), push(i1), op(0x3c))
		__asm(push(i1), push(i4), op(0x3c))
		i1 = i3
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_19_F"))
		i3 =  (i2 >> 1)
		__asm(push(uint(i2)>uint(1)), iftrue, target("___pow5mult_D2A__XprivateX__BB15_21_F"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_20_F"))
		__asm(jump, target("___pow5mult_D2A__XprivateX__BB15_5_B"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_21_F"))
		i2 =  ((__xasm<int>(push(i0), op(0x37))))
		i4 = i0
		__asm(push(i2==0), iftrue, target("___pow5mult_D2A__XprivateX__BB15_23_F"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_22_F"))
		i0 = i2
		i2 = i3
		__asm(jump, target("___pow5mult_D2A__XprivateX__BB15_14_B"))
	__asm(lbl("___pow5mult_D2A__XprivateX__BB15_23_F"))
		i2 =  (0)
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i0), push((mstate.esp+4)), op(0x3c))
		state = 4
		mstate.esp -= 4;FSM___mult_D2A.start()
		return
	__asm(lbl("___pow5mult_D2A_state4"))
		i0 = mstate.eax
		mstate.esp += 8
		__asm(push(i0), push(i4), op(0x3c))
		__asm(push(i2), push(i0), op(0x3c))
		i2 = i3
		__asm(jump, target("___pow5mult_D2A__XprivateX__BB15_14_B"))
	__asm(lbl("___pow5mult_D2A_errState"))
		throw("Invalid state in ___pow5mult_D2A")
	}
}



// Async
public const ___mult_D2A:int = regFunc(FSM___mult_D2A.start)

public final class FSM___mult_D2A extends Machine {

	public static function start():void {
			var result:FSM___mult_D2A = new FSM___mult_D2A
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
	public var i8:int, i9:int, i10:int, i11:int, i12:int, i13:int, i14:int, i15:int
	public var i16:int, i17:int, i18:int, i19:int, i20:int

	public static const intRegCount:int = 21

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___mult_D2A_entry"))
		__asm(push(state), switchjump(
			"___mult_D2A_errState",
			"___mult_D2A_state0",
			"___mult_D2A_state1",
			"___mult_D2A_state2"))
	__asm(lbl("___mult_D2A_state0"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i2 =  ((__xasm<int>(push((i0+16)), op(0x37))))
		i3 =  ((__xasm<int>(push((i1+16)), op(0x37))))
		i4 =  ((i2<i3) ? i0 : i1)
		i0 =  ((i2<i3) ? i1 : i0)
		i1 =  ((__xasm<int>(push((i0+16)), op(0x37))))
		i2 =  ((__xasm<int>(push((i4+16)), op(0x37))))
		i3 =  ((__xasm<int>(push((i0+8)), op(0x37))))
		i5 =  (i2 + i1)
		i6 =  ((__xasm<int>(push((i0+4)), op(0x37))))
		i3 =  ((i3<i5) ? 1 : 0)
		i3 =  (i3 & 1)
		mstate.esp -= 4
		i3 =  (i3 + i6)
		__asm(push(i3), push(mstate.esp), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM___Balloc_D2A.start()
		return
	__asm(lbl("___mult_D2A_state1"))
		i3 = mstate.eax
		mstate.esp += 4
		i6 = i3
		__asm(push(i5<1), iftrue, target("___mult_D2A__XprivateX__BB16_4_F"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_1_F"))
		i7 =  (0)
		i8 =  (i6 + 20)
	__asm(jump, target("___mult_D2A__XprivateX__BB16_2_F"), lbl("___mult_D2A__XprivateX__BB16_2_B"), label, lbl("___mult_D2A__XprivateX__BB16_2_F")); 
		i9 =  (0)
		__asm(push(i9), push(i8), op(0x3c))
		i8 =  (i8 + 4)
		i7 =  (i7 + 1)
		__asm(push(i7>=i5), iftrue, target("___mult_D2A__XprivateX__BB16_4_F"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_3_F"))
		__asm(jump, target("___mult_D2A__XprivateX__BB16_2_B"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_4_F"))
		__asm(push(i2<1), iftrue, target("___mult_D2A__XprivateX__BB16_13_F"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_5_F"))
		i7 =  (0)
		i8 = i7
	__asm(jump, target("___mult_D2A__XprivateX__BB16_6_F"), lbl("___mult_D2A__XprivateX__BB16_6_B"), label, lbl("___mult_D2A__XprivateX__BB16_6_F")); 
		i9 =  (i4 + i8)
		i9 =  ((__xasm<int>(push((i9+20)), op(0x37))))
		__asm(push(i9==0), iftrue, target("___mult_D2A__XprivateX__BB16_11_F"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_7_F"))
		i10 =  (20)
		i11 =  (0)
		i12 =  (i6 + i8)
		i13 = i11
		i14 = i11
		i15 = i11
	__asm(jump, target("___mult_D2A__XprivateX__BB16_8_F"), lbl("___mult_D2A__XprivateX__BB16_8_B"), label, lbl("___mult_D2A__XprivateX__BB16_8_F")); 
		i16 =  (0)
		i17 =  (i0 + i10)
		mstate.esp -= 16
		i17 =  ((__xasm<int>(push(i17), op(0x37))))
		__asm(push(i17), push(mstate.esp), op(0x3c))
		__asm(push(i16), push((mstate.esp+4)), op(0x3c))
		__asm(push(i9), push((mstate.esp+8)), op(0x3c))
		__asm(push(i11), push((mstate.esp+12)), op(0x3c))
		i17 =  (i12 + i10)
		i18 =  ((__xasm<int>(push(i17), op(0x37))))
		mstate.esp -= 4;(mstate.funcs[___muldi3])()
	__asm(lbl("___mult_D2A_state2"))
		i19 = mstate.eax
		i20 = mstate.edx
		i14 =  __addc(i18, i14)
		i13 =  __adde(i13, i16)
		i14 =  __addc(i14, i19)
		i13 =  __adde(i13, i20)
		__asm(push(i14), push(i17), op(0x3c))
		i10 =  (i10 + 4)
		i14 =  (i15 + 1)
		mstate.esp += 16
		__asm(push(i14>=i1), iftrue, target("___mult_D2A__XprivateX__BB16_10_F"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_9_F"))
		i15 = i14
		i14 = i13
		i13 = i16
		__asm(jump, target("___mult_D2A__XprivateX__BB16_8_B"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_10_F"))
		i9 =  (i7 + i14)
		i9 =  (i9 << 2)
		i9 =  (i3 + i9)
		__asm(push(i13), push((i9+20)), op(0x3c))
	__asm(lbl("___mult_D2A__XprivateX__BB16_11_F"))
		i8 =  (i8 + 4)
		i7 =  (i7 + 1)
		__asm(push(i7>=i2), iftrue, target("___mult_D2A__XprivateX__BB16_13_F"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_12_F"))
		__asm(jump, target("___mult_D2A__XprivateX__BB16_6_B"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_13_F"))
		__asm(push(i5>0), iftrue, target("___mult_D2A__XprivateX__BB16_18_F"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_14_F"))
		i1 = i5
		__asm(jump, target("___mult_D2A__XprivateX__BB16_21_F"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_15_B"), label)
		i0 =  (i2 + -1)
		i2 =  (i1 + 1)
		__asm(push(i0<1), iftrue, target("___mult_D2A__XprivateX__BB16_17_F"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_16_F"))
		i1 = i0
		i0 = i2
		__asm(jump, target("___mult_D2A__XprivateX__BB16_19_F"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_17_F"))
		i1 = i0
		__asm(jump, target("___mult_D2A__XprivateX__BB16_21_F"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_18_F"))
		i0 =  (0)
		i1 =  (i2 + i1)
		__asm(jump, target("___mult_D2A__XprivateX__BB16_19_F"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_19_F"))
		i2 = i1
		i1 = i0
		i0 =  (i1 ^ -1)
		i0 =  (i5 + i0)
		i0 =  (i0 << 2)
		i0 =  (i3 + i0)
		i0 =  ((__xasm<int>(push((i0+20)), op(0x37))))
		__asm(push(i0==0), iftrue, target("___mult_D2A__XprivateX__BB16_15_B"))
	__asm(lbl("___mult_D2A__XprivateX__BB16_20_F"))
		i1 = i2
	__asm(lbl("___mult_D2A__XprivateX__BB16_21_F"))
		i0 = i1
		__asm(push(i0), push((i3+16)), op(0x3c))
		mstate.eax = i3
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___mult_D2A_errState"))
		throw("Invalid state in ___mult_D2A")
	}
}



// Async
public const ___lshift_D2A:int = regFunc(FSM___lshift_D2A.start)

public final class FSM___lshift_D2A extends Machine {

	public static function start():void {
			var result:FSM___lshift_D2A = new FSM___lshift_D2A
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
	public var i8:int, i9:int, i10:int, i11:int, i12:int, i13:int, i14:int, i15:int

	public static const intRegCount:int = 16

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___lshift_D2A_entry"))
		__asm(push(state), switchjump(
			"___lshift_D2A_errState",
			"___lshift_D2A_state0",
			"___lshift_D2A_state1"))
	__asm(lbl("___lshift_D2A_state0"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i2 =  ((__xasm<int>(push((i0+16)), op(0x37))))
		i3 =  (i1 >> 5)
		i2 =  (i2 + i3)
		i4 =  ((__xasm<int>(push((i0+4)), op(0x37))))
		i5 =  ((__xasm<int>(push((i0+8)), op(0x37))))
		i6 =  (i2 + 1)
		i7 =  (i0 + 16)
		i8 =  (i0 + 4)
		i9 = i0
		__asm(push(i6>i5), iftrue, target("___lshift_D2A__XprivateX__BB17_2_F"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_1_F"))
		__asm(jump, target("___lshift_D2A__XprivateX__BB17_6_F"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_2_F"))
		i10 =  (-1)
	__asm(jump, target("___lshift_D2A__XprivateX__BB17_3_F"), lbl("___lshift_D2A__XprivateX__BB17_3_B"), label, lbl("___lshift_D2A__XprivateX__BB17_3_F")); 
		i10 =  (i10 + 1)
		i5 =  (i5 << 1)
		__asm(push(i6<=i5), iftrue, target("___lshift_D2A__XprivateX__BB17_5_F"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_4_F"))
		__asm(jump, target("___lshift_D2A__XprivateX__BB17_3_B"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_5_F"))
		i4 =  (i10 + i4)
		i4 =  (i4 + 1)
	__asm(lbl("___lshift_D2A__XprivateX__BB17_6_F"))
		mstate.esp -= 4
		__asm(push(i4), push(mstate.esp), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM___Balloc_D2A.start()
		return
	__asm(lbl("___lshift_D2A_state1"))
		i4 = mstate.eax
		mstate.esp += 4
		i5 =  (i4 + 20)
		i10 = i4
		__asm(push(i3>0), iftrue, target("___lshift_D2A__XprivateX__BB17_8_F"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_7_F"))
		i3 = i5
		__asm(jump, target("___lshift_D2A__XprivateX__BB17_12_F"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_8_F"))
		i5 =  (0)
		i4 =  (i4 + 20)
	__asm(jump, target("___lshift_D2A__XprivateX__BB17_9_F"), lbl("___lshift_D2A__XprivateX__BB17_9_B"), label, lbl("___lshift_D2A__XprivateX__BB17_9_F")); 
		i11 =  (0)
		__asm(push(i11), push(i4), op(0x3c))
		i4 =  (i4 + 4)
		i5 =  (i5 + 1)
		__asm(push(i5==i3), iftrue, target("___lshift_D2A__XprivateX__BB17_11_F"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_10_F"))
		__asm(jump, target("___lshift_D2A__XprivateX__BB17_9_B"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_11_F"))
		i3 =  (i5 << 2)
		i3 =  (i10 + i3)
		i3 =  (i3 + 20)
	__asm(lbl("___lshift_D2A__XprivateX__BB17_12_F"))
		i4 =  ((__xasm<int>(push(i7), op(0x37))))
		i1 =  (i1 & 31)
		i5 = i3
		__asm(push(i1!=0), iftrue, target("___lshift_D2A__XprivateX__BB17_16_F"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_13_F"))
		i1 =  (0)
		i3 = i1
		__asm(jump, target("___lshift_D2A__XprivateX__BB17_14_F"))
	__asm(jump, target("___lshift_D2A__XprivateX__BB17_14_F"), lbl("___lshift_D2A__XprivateX__BB17_14_B"), label, lbl("___lshift_D2A__XprivateX__BB17_14_F")); 
		i6 =  (i9 + i3)
		i6 =  ((__xasm<int>(push((i6+20)), op(0x37))))
		i7 =  (i5 + i3)
		__asm(push(i6), push(i7), op(0x3c))
		i3 =  (i3 + 4)
		i1 =  (i1 + 1)
		__asm(push(i1>=i4), iftrue, target("___lshift_D2A__XprivateX__BB17_24_F"))
		__asm(jump, target("___lshift_D2A__XprivateX__BB17_15_F"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_15_F"))
		__asm(jump, target("___lshift_D2A__XprivateX__BB17_14_B"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_16_F"))
		i7 =  (0)
		i11 =  (32 - i1)
		i12 = i7
		i13 = i7
	__asm(jump, target("___lshift_D2A__XprivateX__BB17_17_F"), lbl("___lshift_D2A__XprivateX__BB17_17_B"), label, lbl("___lshift_D2A__XprivateX__BB17_17_F")); 
		i14 =  (i9 + i12)
		i15 =  ((__xasm<int>(push((i14+20)), op(0x37))))
		i15 =  (i15 << i1)
		i7 =  (i15 | i7)
		i15 =  (i5 + i12)
		__asm(push(i7), push(i15), op(0x3c))
		i7 =  ((__xasm<int>(push((i14+20)), op(0x37))))
		i12 =  (i12 + 4)
		i13 =  (i13 + 1)
		i7 =  (i7 >>> i11)
		__asm(push(i13>=i4), iftrue, target("___lshift_D2A__XprivateX__BB17_19_F"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_18_F"))
		__asm(jump, target("___lshift_D2A__XprivateX__BB17_17_B"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_19_F"))
		i1 =  (i13 << 2)
		i1 =  (i3 + i1)
		__asm(push(i7), push(i1), op(0x3c))
		__asm(push(i7==0), iftrue, target("___lshift_D2A__XprivateX__BB17_24_F"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_20_F"))
		__asm(push(i6), push((i10+16)), op(0x3c))
		__asm(push(i0==0), iftrue, target("___lshift_D2A__XprivateX__BB17_22_F"))
	__asm(jump, target("___lshift_D2A__XprivateX__BB17_21_F"), lbl("___lshift_D2A__XprivateX__BB17_21_B"), label, lbl("___lshift_D2A__XprivateX__BB17_21_F")); 
		i1 =  (_freelist)
		i2 =  ((__xasm<int>(push(i8), op(0x37))))
		i2 =  (i2 << 2)
		i1 =  (i1 + i2)
		i2 =  ((__xasm<int>(push(i1), op(0x37))))
		__asm(push(i2), push(i0), op(0x3c))
		__asm(push(i0), push(i1), op(0x3c))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_22_F"))
		__asm(jump, target("___lshift_D2A__XprivateX__BB17_23_F"))
	__asm(jump, target("___lshift_D2A__XprivateX__BB17_23_F"), lbl("___lshift_D2A__XprivateX__BB17_23_B"), label, lbl("___lshift_D2A__XprivateX__BB17_23_F")); 
		mstate.eax = i10
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___lshift_D2A__XprivateX__BB17_24_F"))
		__asm(push(i2), push((i10+16)), op(0x3c))
		__asm(push(i0==0), iftrue, target("___lshift_D2A__XprivateX__BB17_23_B"))
	__asm(lbl("___lshift_D2A__XprivateX__BB17_25_F"))
		__asm(jump, target("___lshift_D2A__XprivateX__BB17_21_B"))
	__asm(lbl("___lshift_D2A_errState"))
		throw("Invalid state in ___lshift_D2A")
	}
}



// Async
public const ___multadd_D2A:int = regFunc(FSM___multadd_D2A.start)

public final class FSM___multadd_D2A extends Machine {

	public static function start():void {
			var result:FSM___multadd_D2A = new FSM___multadd_D2A
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
	public var i8:int, i9:int, i10:int, i11:int

	public static const intRegCount:int = 12

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___multadd_D2A_entry"))
		__asm(push(state), switchjump(
			"___multadd_D2A_errState",
			"___multadd_D2A_state0",
			"___multadd_D2A_state1",
			"___multadd_D2A_state2"))
	__asm(lbl("___multadd_D2A_state0"))
	__asm(lbl("___multadd_D2A__XprivateX__BB18_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  (0)
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i3 =  ((__xasm<int>(push((i1+16)), op(0x37))))
		i4 =  (i2 >> 31)
		i5 =  (i1 + 20)
		i6 =  (i1 + 16)
		i7 = i0
		i8 = i0
	__asm(jump, target("___multadd_D2A__XprivateX__BB18_1_F"), lbl("___multadd_D2A__XprivateX__BB18_1_B"), label, lbl("___multadd_D2A__XprivateX__BB18_1_F")); 
		i9 =  (0)
		mstate.esp -= 16
		i10 =  ((__xasm<int>(push(i5), op(0x37))))
		__asm(push(i10), push(mstate.esp), op(0x3c))
		__asm(push(i9), push((mstate.esp+4)), op(0x3c))
		__asm(push(i2), push((mstate.esp+8)), op(0x3c))
		__asm(push(i4), push((mstate.esp+12)), op(0x3c))
		mstate.esp -= 4;(mstate.funcs[___muldi3])()
	__asm(lbl("___multadd_D2A_state1"))
		i10 = mstate.eax
		i11 = mstate.edx
		i7 =  __addc(i10, i7)
		i0 =  __adde(i11, i0)
		__asm(push(i7), push(i5), op(0x3c))
		i5 =  (i5 + 4)
		i7 =  (i8 + 1)
		mstate.esp += 16
		i8 = i0
		__asm(push(i7>=i3), iftrue, target("___multadd_D2A__XprivateX__BB18_3_F"))
	__asm(lbl("___multadd_D2A__XprivateX__BB18_2_F"))
		i8 = i7
		i7 = i0
		i0 = i9
		__asm(jump, target("___multadd_D2A__XprivateX__BB18_1_B"))
	__asm(lbl("___multadd_D2A__XprivateX__BB18_3_F"))
		i2 =  ((i8==0) ? 1 : 0)
		__asm(push(i2!=0), iftrue, target("___multadd_D2A__XprivateX__BB18_10_F"))
	__asm(lbl("___multadd_D2A__XprivateX__BB18_4_F"))
		i2 =  ((__xasm<int>(push((i1+8)), op(0x37))))
		__asm(push(i2<=i3), iftrue, target("___multadd_D2A__XprivateX__BB18_6_F"))
	__asm(lbl("___multadd_D2A__XprivateX__BB18_5_F"))
		__asm(jump, target("___multadd_D2A__XprivateX__BB18_9_F"))
	__asm(lbl("___multadd_D2A__XprivateX__BB18_6_F"))
		i2 =  ((__xasm<int>(push((i1+4)), op(0x37))))
		mstate.esp -= 4
		i2 =  (i2 + 1)
		__asm(push(i2), push(mstate.esp), op(0x3c))
		state = 2
		mstate.esp -= 4;FSM___Balloc_D2A.start()
		return
	__asm(lbl("___multadd_D2A_state2"))
		i2 = mstate.eax
		mstate.esp += 4
		i4 =  ((__xasm<int>(push(i6), op(0x37))))
		i5 =  (i2 + 12)
		i4 =  (i4 << 2)
		i6 =  (i1 + 12)
		i4 =  (i4 + 8)
		memcpy(i5, i6, i4)
		i4 =  (i1 + 4)
		__asm(push(i1!=0), iftrue, target("___multadd_D2A__XprivateX__BB18_8_F"))
	__asm(lbl("___multadd_D2A__XprivateX__BB18_7_F"))
		i1 = i2
		__asm(jump, target("___multadd_D2A__XprivateX__BB18_9_F"))
	__asm(lbl("___multadd_D2A__XprivateX__BB18_8_F"))
		i5 =  (_freelist)
		i4 =  ((__xasm<int>(push(i4), op(0x37))))
		i4 =  (i4 << 2)
		i4 =  (i5 + i4)
		i5 =  ((__xasm<int>(push(i4), op(0x37))))
		__asm(push(i5), push(i1), op(0x3c))
		__asm(push(i1), push(i4), op(0x3c))
		i1 = i2
	__asm(lbl("___multadd_D2A__XprivateX__BB18_9_F"))
		i2 =  (i3 << 2)
		i2 =  (i1 + i2)
		__asm(push(i0), push((i2+20)), op(0x3c))
		i0 =  (i3 + 1)
		__asm(push(i0), push((i1+16)), op(0x3c))
	__asm(lbl("___multadd_D2A__XprivateX__BB18_10_F"))
		mstate.eax = i1
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___multadd_D2A_errState"))
		throw("Invalid state in ___multadd_D2A")
	}
}



// Async
public const ___diff_D2A:int = regFunc(FSM___diff_D2A.start)

public final class FSM___diff_D2A extends Machine {

	public static function start():void {
			var result:FSM___diff_D2A = new FSM___diff_D2A
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
	public var i8:int, i9:int, i10:int, i11:int, i12:int, i13:int

	public static const intRegCount:int = 14

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___diff_D2A_entry"))
		__asm(push(state), switchjump(
			"___diff_D2A_errState",
			"___diff_D2A_state0",
			"___diff_D2A_state1",
			"___diff_D2A_state2"))
	__asm(lbl("___diff_D2A_state0"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i2 =  ((__xasm<int>(push((i0+16)), op(0x37))))
		i3 =  ((__xasm<int>(push((i1+16)), op(0x37))))
		i4 =  (i2 - i3)
		__asm(push(i2==i3), iftrue, target("___diff_D2A__XprivateX__BB19_2_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_1_F"))
		i3 = i4
		__asm(jump, target("___diff_D2A__XprivateX__BB19_7_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_2_F"))
		i2 =  (0)
	__asm(jump, target("___diff_D2A__XprivateX__BB19_3_F"), lbl("___diff_D2A__XprivateX__BB19_3_B"), label, lbl("___diff_D2A__XprivateX__BB19_3_F")); 
		i4 =  (i2 ^ -1)
		i4 =  (i3 + i4)
		i5 =  (i4 << 2)
		i6 =  (i0 + i5)
		i5 =  (i1 + i5)
		i6 =  ((__xasm<int>(push((i6+20)), op(0x37))))
		i5 =  ((__xasm<int>(push((i5+20)), op(0x37))))
		__asm(push(i6==i5), iftrue, target("___diff_D2A__XprivateX__BB19_5_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_4_F"))
		i2 =  ((uint(i6)<uint(i5)) ? -1 : 1)
		i3 = i2
		__asm(jump, target("___diff_D2A__XprivateX__BB19_7_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_5_F"))
		i2 =  (i2 + 1)
		__asm(push(i4>0), iftrue, target("___diff_D2A__XprivateX__BB19_31_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_6_F"))
		i2 =  (0)
		i3 = i2
		__asm(jump, target("___diff_D2A__XprivateX__BB19_7_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_7_F"))
		i2 = i3
		__asm(push(i2!=0), iftrue, target("___diff_D2A__XprivateX__BB19_14_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_8_F"))
		i0 =  ((__xasm<int>(push(_freelist), op(0x37))))
		__asm(push(i0==0), iftrue, target("___diff_D2A__XprivateX__BB19_10_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_9_F"))
		i1 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i1), push(_freelist), op(0x3c))
		__asm(jump, target("___diff_D2A__XprivateX__BB19_13_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_10_F"))
		i0 =  (_private_mem)
		i1 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i0 =  (i1 - i0)
		i0 =  (i0 >> 3)
		i0 =  (i0 + 3)
		__asm(push(uint(i0)>uint(288)), iftrue, target("___diff_D2A__XprivateX__BB19_12_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_11_F"))
		i0 =  (0)
		i2 =  (i1 + 24)
		__asm(push(i2), push(_pmem_next), op(0x3c))
		__asm(push(i0), push((i1+4)), op(0x3c))
		i0 =  (1)
		__asm(push(i0), push((i1+8)), op(0x3c))
		i0 = i1
		__asm(jump, target("___diff_D2A__XprivateX__BB19_13_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_12_F"))
		i0 =  (24)
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___diff_D2A_state1"))
		i0 = mstate.eax
		mstate.esp += 4
		i1 =  (0)
		__asm(push(i1), push((i0+4)), op(0x3c))
		i1 =  (1)
		__asm(push(i1), push((i0+8)), op(0x3c))
	__asm(lbl("___diff_D2A__XprivateX__BB19_13_F"))
		i1 =  (0)
		__asm(push(i1), push((i0+12)), op(0x3c))
		i2 =  (1)
		__asm(push(i2), push((i0+16)), op(0x3c))
		__asm(push(i1), push((i0+20)), op(0x3c))
		mstate.eax = i0
		__asm(jump, target("___diff_D2A__XprivateX__BB19_30_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_14_F"))
		i3 =  (20)
		i4 =  ((i2<0) ? i1 : i0)
		i5 =  ((__xasm<int>(push((i4+4)), op(0x37))))
		mstate.esp -= 4
		__asm(push(i5), push(mstate.esp), op(0x3c))
		state = 2
		mstate.esp -= 4;FSM___Balloc_D2A.start()
		return
	__asm(lbl("___diff_D2A_state2"))
		i5 = mstate.eax
		mstate.esp += 4
		i6 =  (i2 >>> 31)
		__asm(push(i6), push((i5+12)), op(0x3c))
		i0 =  ((i2<0) ? i0 : i1)
		i1 =  ((__xasm<int>(push((i4+16)), op(0x37))))
		i2 =  ((__xasm<int>(push((i0+16)), op(0x37))))
		i6 =  (0)
		i7 = i6
		i8 = i6
		i9 = i5
		i10 = i4
	__asm(jump, target("___diff_D2A__XprivateX__BB19_15_F"), lbl("___diff_D2A__XprivateX__BB19_15_B"), label, lbl("___diff_D2A__XprivateX__BB19_15_F")); 
		i11 =  (0)
		i12 =  (i4 + i3)
		i13 =  (i0 + i3)
		i12 =  ((__xasm<int>(push(i12), op(0x37))))
		i13 =  ((__xasm<int>(push(i13), op(0x37))))
		i12 =  __subc(i12, i13)
		i13 =  __sube(i11, i11)
		i6 =  __subc(i12, i6)
		i7 =  __sube(i13, i7)
		i12 =  (i9 + i3)
		__asm(push(i6), push(i12), op(0x3c))
		i6 =  (i7 & 1)
		i3 =  (i3 + 4)
		i7 =  (i8 + 1)
		__asm(push(i7>=i2), iftrue, target("___diff_D2A__XprivateX__BB19_20_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_16_F"))
		i8 = i7
		i7 = i11
		__asm(jump, target("___diff_D2A__XprivateX__BB19_15_B"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_17_B"), label)
		i0 =  (0)
		__asm(jump, target("___diff_D2A__XprivateX__BB19_18_F"))
	__asm(jump, target("___diff_D2A__XprivateX__BB19_18_F"), lbl("___diff_D2A__XprivateX__BB19_18_B"), label, lbl("___diff_D2A__XprivateX__BB19_18_F")); 
		i2 =  (0)
		i3 =  (i7 + i0)
		i3 =  (i3 << 2)
		i4 =  (i10 + i3)
		i4 =  ((__xasm<int>(push((i4+20)), op(0x37))))
		i6 =  __subc(i4, i6)
		i11 =  __sube(i2, i11)
		i3 =  (i5 + i3)
		i0 =  (i0 + 1)
		__asm(push(i6), push((i3+20)), op(0x3c))
		i6 =  (i11 & 1)
		i11 =  (i7 + i0)
		__asm(push(i11>=i1), iftrue, target("___diff_D2A__XprivateX__BB19_25_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_19_F"))
		i11 = i2
		__asm(jump, target("___diff_D2A__XprivateX__BB19_18_B"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_20_F"))
		i0 =  (i7 << 2)
		i0 =  (i5 + i0)
		i0 =  (i0 + 20)
		__asm(push(i7<i1), iftrue, target("___diff_D2A__XprivateX__BB19_17_B"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_21_F"))
		i11 = i0
		__asm(jump, target("___diff_D2A__XprivateX__BB19_26_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_22_B"), label)
		i2 =  (-1)
		i11 =  (i11 + -8)
		i0 = i11
		i11 = i2
		__asm(jump, target("___diff_D2A__XprivateX__BB19_23_F"))
	__asm(jump, target("___diff_D2A__XprivateX__BB19_23_F"), lbl("___diff_D2A__XprivateX__BB19_23_B"), label, lbl("___diff_D2A__XprivateX__BB19_23_F")); 
		i2 =  ((__xasm<int>(push(i0), op(0x37))))
		i0 =  (i0 + -4)
		i11 =  (i11 + 1)
		__asm(push(i2!=0), iftrue, target("___diff_D2A__XprivateX__BB19_28_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_24_F"))
		__asm(jump, target("___diff_D2A__XprivateX__BB19_23_B"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_25_F"))
		i11 =  (i11 << 2)
		i11 =  (i5 + i11)
		i11 =  (i11 + 20)
	__asm(lbl("___diff_D2A__XprivateX__BB19_26_F"))
		i0 =  ((__xasm<int>(push((i11+-4)), op(0x37))))
		__asm(push(i0==0), iftrue, target("___diff_D2A__XprivateX__BB19_22_B"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_27_F"))
		i11 = i1
		__asm(jump, target("___diff_D2A__XprivateX__BB19_29_F"))
	__asm(lbl("___diff_D2A__XprivateX__BB19_28_F"))
		i11 =  (i1 - i11)
		i11 =  (i11 + -1)
	__asm(lbl("___diff_D2A__XprivateX__BB19_29_F"))
		i0 = i11
		__asm(push(i0), push((i5+16)), op(0x3c))
		mstate.eax = i5
	__asm(lbl("___diff_D2A__XprivateX__BB19_30_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___diff_D2A__XprivateX__BB19_31_F"))
		__asm(jump, target("___diff_D2A__XprivateX__BB19_3_B"))
	__asm(lbl("___diff_D2A_errState"))
		throw("Invalid state in ___diff_D2A")
	}
}



// Sync
public const ___lo0bits_D2A:int = regFunc(FSM___lo0bits_D2A.start)

public final class FSM___lo0bits_D2A extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int


		__asm(label, lbl("___lo0bits_D2A_entry"))
	__asm(lbl("___lo0bits_D2A__XprivateX__BB20_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push(i0), op(0x37))))
		i2 =  (i1 & 7)
		__asm(push(i2==0), iftrue, target("___lo0bits_D2A__XprivateX__BB20_5_F"))
	__asm(lbl("___lo0bits_D2A__XprivateX__BB20_1_F"))
		i2 =  (i1 & 1)
		__asm(push(i2==0), iftrue, target("___lo0bits_D2A__XprivateX__BB20_3_F"))
	__asm(lbl("___lo0bits_D2A__XprivateX__BB20_2_F"))
		i0 =  (0)
		__asm(jump, target("___lo0bits_D2A__XprivateX__BB20_12_F"))
	__asm(lbl("___lo0bits_D2A__XprivateX__BB20_3_F"))
		i2 =  (i1 & 2)
		__asm(push(i2==0), iftrue, target("___lo0bits_D2A__XprivateX__BB20_9_F"))
	__asm(lbl("___lo0bits_D2A__XprivateX__BB20_4_F"))
		i2 =  (1)
		i1 =  (i1 >>> 1)
		__asm(jump, target("___lo0bits_D2A__XprivateX__BB20_10_F"))
	__asm(lbl("___lo0bits_D2A__XprivateX__BB20_5_F"))
		i2 =  (i1 & 65535)
		i2 =  ((i2==0) ? 16 : 0)
		i1 =  (i1 >>> i2)
		i3 =  (i1 & 255)
		i3 =  ((i3==0) ? 8 : 0)
		i1 =  (i1 >>> i3)
		i4 =  (i1 & 15)
		i4 =  ((i4==0) ? 4 : 0)
		i1 =  (i1 >>> i4)
		i2 =  (i3 | i2)
		i3 =  (i1 & 3)
		i3 =  ((i3==0) ? 2 : 0)
		i2 =  (i2 | i4)
		i1 =  (i1 >>> i3)
		i2 =  (i2 | i3)
		i3 =  (i1 & 1)
		__asm(push(i3==0), iftrue, target("___lo0bits_D2A__XprivateX__BB20_7_F"))
	__asm(lbl("___lo0bits_D2A__XprivateX__BB20_6_F"))
		__asm(jump, target("___lo0bits_D2A__XprivateX__BB20_10_F"))
	__asm(lbl("___lo0bits_D2A__XprivateX__BB20_7_F"))
		i3 =  (i1 >>> 1)
		i2 =  (i2 + 1)
		__asm(push(uint(i1)<uint(2)), iftrue, target("___lo0bits_D2A__XprivateX__BB20_11_F"))
	__asm(lbl("___lo0bits_D2A__XprivateX__BB20_8_F"))
		i1 = i3
		__asm(jump, target("___lo0bits_D2A__XprivateX__BB20_10_F"))
	__asm(lbl("___lo0bits_D2A__XprivateX__BB20_9_F"))
		i2 =  (2)
		i1 =  (i1 >>> 2)
		__asm(jump, target("___lo0bits_D2A__XprivateX__BB20_10_F"))
	__asm(lbl("___lo0bits_D2A__XprivateX__BB20_10_F"))
		__asm(push(i1), push(i0), op(0x3c))
		mstate.eax = i2
		__asm(jump, target("___lo0bits_D2A__XprivateX__BB20_13_F"))
	__asm(lbl("___lo0bits_D2A__XprivateX__BB20_11_F"))
		i0 =  (32)
		__asm(jump, target("___lo0bits_D2A__XprivateX__BB20_12_F"))
	__asm(lbl("___lo0bits_D2A__XprivateX__BB20_12_F"))
		mstate.eax = i0
	__asm(lbl("___lo0bits_D2A__XprivateX__BB20_13_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___trailz_D2A:int = regFunc(FSM___trailz_D2A.start)

public final class FSM___trailz_D2A extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int


		__asm(label, lbl("___trailz_D2A_entry"))
	__asm(lbl("___trailz_D2A__XprivateX__BB21_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 4
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((i0+16)), op(0x37))))
		i2 =  (i0 + 20)
		i3 =  (i1 << 2)
		i3 =  (i2 + i3)
		__asm(push(i1>0), iftrue, target("___trailz_D2A__XprivateX__BB21_2_F"))
	__asm(lbl("___trailz_D2A__XprivateX__BB21_1_F"))
		i0 =  (0)
		i1 = i2
		__asm(jump, target("___trailz_D2A__XprivateX__BB21_7_F"))
	__asm(lbl("___trailz_D2A__XprivateX__BB21_2_F"))
		i2 =  (0)
		i0 =  (i0 + 20)
		i4 = i2
		__asm(jump, target("___trailz_D2A__XprivateX__BB21_3_F"))
	__asm(jump, target("___trailz_D2A__XprivateX__BB21_3_F"), lbl("___trailz_D2A__XprivateX__BB21_3_B"), label, lbl("___trailz_D2A__XprivateX__BB21_3_F")); 
		i5 =  ((__xasm<int>(push(i0), op(0x37))))
		i6 = i0
		__asm(push(i5==0), iftrue, target("___trailz_D2A__XprivateX__BB21_4_F"))
		__asm(jump, target("___trailz_D2A__XprivateX__BB21_6_F"))
	__asm(lbl("___trailz_D2A__XprivateX__BB21_4_F"))
		i4 =  (i4 + 32)
		i0 =  (i0 + 4)
		i2 =  (i2 + 1)
		i5 = i0
		__asm(push(i2<i1), iftrue, target("___trailz_D2A__XprivateX__BB21_3_B"))
	__asm(lbl("___trailz_D2A__XprivateX__BB21_5_F"))
		i0 = i4
		i1 = i5
		__asm(jump, target("___trailz_D2A__XprivateX__BB21_7_F"))
	__asm(lbl("___trailz_D2A__XprivateX__BB21_6_F"))
		i0 = i4
		i1 = i6
	__asm(lbl("___trailz_D2A__XprivateX__BB21_7_F"))
		__asm(push(uint(i1)>=uint(i3)), iftrue, target("___trailz_D2A__XprivateX__BB21_9_F"))
	__asm(lbl("___trailz_D2A__XprivateX__BB21_8_F"))
		i2 =  ((mstate.ebp+-4))
		i1 =  ((__xasm<int>(push(i1), op(0x37))))
		__asm(push(i1), push((mstate.ebp+-4)), op(0x3c))
		mstate.esp -= 4
		__asm(push(i2), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM___lo0bits_D2A.start()
	__asm(lbl("___trailz_D2A_state1"))
		i1 = mstate.eax
		mstate.esp += 4
		i0 =  (i1 + i0)
	__asm(lbl("___trailz_D2A__XprivateX__BB21_9_F"))
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Async
public const _fprintf:int = regFunc(FSM_fprintf.start)

public final class FSM_fprintf extends Machine {

	public static function start():void {
			var result:FSM_fprintf = new FSM_fprintf
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int

	public static const intRegCount:int = 3

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("_fprintf_entry"))
		__asm(push(state), switchjump(
			"_fprintf_errState",
			"_fprintf_state0",
			"_fprintf_state1"))
	__asm(lbl("_fprintf_state0"))
	__asm(lbl("_fprintf__XprivateX__BB22_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 4
		i0 =  (mstate.ebp + 16)
		__asm(push(i0), push((mstate.ebp+-4)), op(0x3c))
		mstate.esp -= 12
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		__asm(push(i1), push(mstate.esp), op(0x3c))
		__asm(push(i2), push((mstate.esp+4)), op(0x3c))
		__asm(push(i0), push((mstate.esp+8)), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM___vfprintf.start()
		return
	__asm(lbl("_fprintf_state1"))
		i0 = mstate.eax
		mstate.esp += 12
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("_fprintf_errState"))
		throw("Invalid state in _fprintf")
	}
}



// Sync
public const _getenv:int = regFunc(FSM_getenv.start)

public final class FSM_getenv extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
		var i8:int


		__asm(label, lbl("_getenv_entry"))
	__asm(lbl("_getenv__XprivateX__BB23_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		__asm(push(i0!=0), iftrue, target("_getenv__XprivateX__BB23_3_F"))
	__asm(jump, target("_getenv__XprivateX__BB23_1_F"), lbl("_getenv__XprivateX__BB23_1_B"), label, lbl("_getenv__XprivateX__BB23_1_F")); 
		i0 =  (0)
		__asm(jump, target("_getenv__XprivateX__BB23_2_F"))
	__asm(jump, target("_getenv__XprivateX__BB23_2_F"), lbl("_getenv__XprivateX__BB23_2_B"), label, lbl("_getenv__XprivateX__BB23_2_F")); 
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	__asm(lbl("_getenv__XprivateX__BB23_3_F"))
		i1 =  ((__xasm<int>(push(_environ), op(0x37))))
		i2 = i1
		__asm(push(i1==0), iftrue, target("_getenv__XprivateX__BB23_1_B"))
	__asm(lbl("_getenv__XprivateX__BB23_4_F"))
		i3 = i0
		__asm(jump, target("_getenv__XprivateX__BB23_6_F"))
	__asm(lbl("_getenv__XprivateX__BB23_5_B"), label)
		i3 =  (i3 + 1)
	__asm(lbl("_getenv__XprivateX__BB23_6_F"))
		i4 =  ((__xasm<int>(push(i3), op(0x35))))
		i5 = i3
		__asm(push(i4==0), iftrue, target("_getenv__XprivateX__BB23_8_F"))
	__asm(lbl("_getenv__XprivateX__BB23_7_F"))
		i4 =  (i4 & 255)
		__asm(push(i4!=61), iftrue, target("_getenv__XprivateX__BB23_5_B"))
	__asm(lbl("_getenv__XprivateX__BB23_8_F"))
		i2 =  ((__xasm<int>(push(i2), op(0x37))))
		__asm(push(i2==0), iftrue, target("_getenv__XprivateX__BB23_1_B"))
	__asm(lbl("_getenv__XprivateX__BB23_9_F"))
		i1 =  (i1 + 4)
		i3 =  (i5 - i0)
	__asm(jump, target("_getenv__XprivateX__BB23_10_F"), lbl("_getenv__XprivateX__BB23_10_B"), label, lbl("_getenv__XprivateX__BB23_10_F")); 
		i4 =  (0)
		i5 = i1
		__asm(jump, target("_getenv__XprivateX__BB23_13_F"))
	__asm(lbl("_getenv__XprivateX__BB23_11_B"), label)
		i4 =  ((__xasm<int>(push(i4), op(0x35))))
		i8 =  (i7 + 1)
		i6 =  (i6 & 255)
		__asm(push(i6!=i4), iftrue, target("_getenv__XprivateX__BB23_21_F"))
	__asm(lbl("_getenv__XprivateX__BB23_12_F"))
		i4 = i8
		__asm(jump, target("_getenv__XprivateX__BB23_13_F"))
	__asm(lbl("_getenv__XprivateX__BB23_13_F"))
		i7 = i4
		i4 =  (i0 + i7)
		i6 =  (i2 + i7)
		__asm(push(i3==i7), iftrue, target("_getenv__XprivateX__BB23_22_F"))
	__asm(lbl("_getenv__XprivateX__BB23_14_F"))
		i6 =  ((__xasm<int>(push(i6), op(0x35))))
		__asm(push(i6==0), iftrue, target("_getenv__XprivateX__BB23_15_F"))
		__asm(jump, target("_getenv__XprivateX__BB23_11_B"))
	__asm(lbl("_getenv__XprivateX__BB23_15_F"))
		i2 =  (i2 + i7)
	__asm(jump, target("_getenv__XprivateX__BB23_16_F"), lbl("_getenv__XprivateX__BB23_16_B"), label, lbl("_getenv__XprivateX__BB23_16_F")); 
		__asm(push(i3!=i7), iftrue, target("_getenv__XprivateX__BB23_19_F"))
	__asm(lbl("_getenv__XprivateX__BB23_17_F"))
		i4 =  ((__xasm<int>(push(i2), op(0x35))))
		i2 =  (i2 + 1)
		__asm(push(i4!=61), iftrue, target("_getenv__XprivateX__BB23_19_F"))
	__asm(lbl("_getenv__XprivateX__BB23_18_F"))
		i0 = i2
		__asm(jump, target("_getenv__XprivateX__BB23_2_B"))
	__asm(lbl("_getenv__XprivateX__BB23_19_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i1 =  (i1 + 4)
		__asm(push(i2==0), iftrue, target("_getenv__XprivateX__BB23_1_B"))
	__asm(lbl("_getenv__XprivateX__BB23_20_F"))
		__asm(jump, target("_getenv__XprivateX__BB23_10_B"))
	__asm(lbl("_getenv__XprivateX__BB23_21_F"))
		i2 =  (i2 + i8)
		__asm(jump, target("_getenv__XprivateX__BB23_16_B"))
	__asm(lbl("_getenv__XprivateX__BB23_22_F"))
		i2 =  (i2 + i7)
		__asm(jump, target("_getenv__XprivateX__BB23_16_B"))
	}
}



// Sync
public const _bcopy:int = regFunc(FSM_bcopy.start)

public final class FSM_bcopy extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
		var i8:int, i9:int


		__asm(label, lbl("_bcopy_entry"))
	__asm(lbl("_bcopy__XprivateX__BB24_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i3 = i0
		i4 = i1
		__asm(push(i2==0), iftrue, target("_bcopy__XprivateX__BB24_39_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_1_F"))
		__asm(push(i1==i0), iftrue, target("_bcopy__XprivateX__BB24_39_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_2_F"))
		__asm(push(uint(i1)>=uint(i0)), iftrue, target("_bcopy__XprivateX__BB24_23_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_3_F"))
		i5 =  (i4 | i3)
		i5 =  (i5 & 3)
		__asm(push(i5!=0), iftrue, target("_bcopy__XprivateX__BB24_5_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_4_F"))
		__asm(jump, target("_bcopy__XprivateX__BB24_13_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_5_F"))
		i5 =  (i4 ^ i3)
		i5 =  (i5 & 3)
		__asm(push(i5!=0), iftrue, target("_bcopy__XprivateX__BB24_7_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_6_F"))
		__asm(push(uint(i2)>uint(3)), iftrue, target("_bcopy__XprivateX__BB24_8_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_7_F"))
		i5 = i2
		__asm(jump, target("_bcopy__XprivateX__BB24_9_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_8_F"))
		i5 =  (i3 & 3)
		i5 =  (4 - i5)
	__asm(lbl("_bcopy__XprivateX__BB24_9_F"))
		i6 =  (0)
		i2 =  (i2 - i5)
	__asm(jump, target("_bcopy__XprivateX__BB24_10_F"), lbl("_bcopy__XprivateX__BB24_10_B"), label, lbl("_bcopy__XprivateX__BB24_10_F")); 
		i7 =  (i3 + i6)
		i7 =  ((__xasm<int>(push(i7), op(0x35))))
		i8 =  (i4 + i6)
		__asm(push(i7), push(i8), op(0x3a))
		i6 =  (i6 + 1)
		__asm(push(i6==i5), iftrue, target("_bcopy__XprivateX__BB24_12_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_11_F"))
		__asm(jump, target("_bcopy__XprivateX__BB24_10_B"))
	__asm(lbl("_bcopy__XprivateX__BB24_12_F"))
		i0 =  (i0 + i6)
		i1 =  (i1 + i6)
	__asm(lbl("_bcopy__XprivateX__BB24_13_F"))
		i3 =  (i2 >>> 2)
		i4 = i0
		i5 = i1
		__asm(push(uint(i2)>uint(3)), iftrue, target("_bcopy__XprivateX__BB24_15_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_14_F"))
		__asm(jump, target("_bcopy__XprivateX__BB24_19_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_15_F"))
		i6 =  (0)
		i7 = i6
	__asm(jump, target("_bcopy__XprivateX__BB24_16_F"), lbl("_bcopy__XprivateX__BB24_16_B"), label, lbl("_bcopy__XprivateX__BB24_16_F")); 
		i8 =  (i4 + i7)
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		i9 =  (i5 + i7)
		__asm(push(i8), push(i9), op(0x3c))
		i7 =  (i7 + 4)
		i6 =  (i6 + 1)
		__asm(push(i6==i3), iftrue, target("_bcopy__XprivateX__BB24_18_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_17_F"))
		__asm(jump, target("_bcopy__XprivateX__BB24_16_B"))
	__asm(lbl("_bcopy__XprivateX__BB24_18_F"))
		i1 =  (i1 + i7)
		i0 =  (i0 + i7)
	__asm(lbl("_bcopy__XprivateX__BB24_19_F"))
		i2 =  (i2 & 3)
		__asm(push(i2==0), iftrue, target("_bcopy__XprivateX__BB24_39_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_20_F"))
		i3 =  (0)
	__asm(jump, target("_bcopy__XprivateX__BB24_21_F"), lbl("_bcopy__XprivateX__BB24_21_B"), label, lbl("_bcopy__XprivateX__BB24_21_F")); 
		i4 =  (i0 + i3)
		i4 =  ((__xasm<int>(push(i4), op(0x35))))
		i5 =  (i1 + i3)
		__asm(push(i4), push(i5), op(0x3a))
		i3 =  (i3 + 1)
		__asm(push(i3==i2), iftrue, target("_bcopy__XprivateX__BB24_39_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_22_F"))
		__asm(jump, target("_bcopy__XprivateX__BB24_21_B"))
	__asm(lbl("_bcopy__XprivateX__BB24_23_F"))
		i3 =  (i1 + i2)
		i4 =  (i0 + i2)
		i5 =  (i4 | i3)
		i6 = i3
		i7 = i4
		i5 =  (i5 & 3)
		__asm(push(i5!=0), iftrue, target("_bcopy__XprivateX__BB24_25_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_24_F"))
		i0 = i2
		i1 = i7
		i2 = i6
		__asm(jump, target("_bcopy__XprivateX__BB24_29_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_25_F"))
		i5 =  (0)
		i3 =  (i4 ^ i3)
		i3 =  (i3 & 3)
		i3 =  ((i3!=0) ? 1 : 0)
		i6 =  ((uint(i2)<uint(5)) ? 1 : 0)
		i3 =  (i3 | i6)
		i3 =  (i3 & 1)
		i4 =  (i4 & 3)
		i3 =  ((i3!=0) ? i2 : i4)
		i4 =  (i2 - i3)
	__asm(jump, target("_bcopy__XprivateX__BB24_26_F"), lbl("_bcopy__XprivateX__BB24_26_B"), label, lbl("_bcopy__XprivateX__BB24_26_F")); 
		i6 =  (i5 ^ -1)
		i6 =  (i6 + i2)
		i7 =  (i0 + i6)
		i8 =  ((__xasm<int>(push(i7), op(0x35))))
		i6 =  (i1 + i6)
		__asm(push(i8), push(i6), op(0x3a))
		i5 =  (i5 + 1)
		__asm(push(i5==i3), iftrue, target("_bcopy__XprivateX__BB24_28_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_27_F"))
		__asm(jump, target("_bcopy__XprivateX__BB24_26_B"))
	__asm(lbl("_bcopy__XprivateX__BB24_28_F"))
		i0 = i4
		i1 = i7
		i2 = i6
	__asm(lbl("_bcopy__XprivateX__BB24_29_F"))
		i3 =  (i0 >>> 2)
		i4 = i2
		i5 = i1
		__asm(push(uint(i0)>uint(3)), iftrue, target("_bcopy__XprivateX__BB24_31_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_30_F"))
		i3 = i1
		i4 = i2
		__asm(jump, target("_bcopy__XprivateX__BB24_35_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_31_F"))
		i1 =  (0)
		i2 = i1
	__asm(jump, target("_bcopy__XprivateX__BB24_32_F"), lbl("_bcopy__XprivateX__BB24_32_B"), label, lbl("_bcopy__XprivateX__BB24_32_F")); 
		i6 =  (i5 + i2)
		i6 =  ((__xasm<int>(push((i6+-4)), op(0x37))))
		i7 =  (i4 + i2)
		__asm(push(i6), push((i7+-4)), op(0x3c))
		i2 =  (i2 + -4)
		i1 =  (i1 + 1)
		__asm(push(i1==i3), iftrue, target("_bcopy__XprivateX__BB24_34_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_33_F"))
		__asm(jump, target("_bcopy__XprivateX__BB24_32_B"))
	__asm(lbl("_bcopy__XprivateX__BB24_34_F"))
		i4 =  (i4 + i2)
		i3 =  (i5 + i2)
	__asm(lbl("_bcopy__XprivateX__BB24_35_F"))
		i1 = i3
		i2 = i4
		i0 =  (i0 & 3)
		__asm(push(i0==0), iftrue, target("_bcopy__XprivateX__BB24_39_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_36_F"))
		i3 =  (0)
	__asm(jump, target("_bcopy__XprivateX__BB24_37_F"), lbl("_bcopy__XprivateX__BB24_37_B"), label, lbl("_bcopy__XprivateX__BB24_37_F")); 
		i4 =  (i3 ^ -1)
		i5 =  (i1 + i4)
		i5 =  ((__xasm<int>(push(i5), op(0x35))))
		i4 =  (i2 + i4)
		__asm(push(i5), push(i4), op(0x3a))
		i3 =  (i3 + 1)
		__asm(push(i3==i0), iftrue, target("_bcopy__XprivateX__BB24_39_F"))
	__asm(lbl("_bcopy__XprivateX__BB24_38_F"))
		__asm(jump, target("_bcopy__XprivateX__BB24_37_B"))
	__asm(lbl("_bcopy__XprivateX__BB24_39_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Async
public const _free:int = regFunc(FSM_free.start)

public final class FSM_free extends Machine {

	public static function start():void {
			var result:FSM_free = new FSM_free
		gstate.gworker = result
	}

	public var i0:int, i1:int

	public static const intRegCount:int = 2

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("_free_entry"))
		__asm(push(state), switchjump(
			"_free_errState",
			"_free_state0",
			"_free_state1"))
	__asm(lbl("_free_state0"))
	__asm(lbl("_free__XprivateX__BB25_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  (0)
		mstate.esp -= 8
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		__asm(push(i1), push(mstate.esp), op(0x3c))
		__asm(push(i0), push((mstate.esp+4)), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("_free_state1"))
		i0 = mstate.eax
		mstate.esp += 8
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("_free_errState"))
		throw("Invalid state in _free")
	}
}



// Sync
public const __UTF8_wcrtomb:int = regFunc(FSM__UTF8_wcrtomb.start)

public final class FSM__UTF8_wcrtomb extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int


		__asm(label, lbl("__UTF8_wcrtomb_entry"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i0 =  ((__xasm<int>(push((i0+4)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i3 = i1
		__asm(push(i0==0), iftrue, target("__UTF8_wcrtomb__XprivateX__BB26_2_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_1_F"))
		i1 =  (22)
		__asm(push(i1), push(_val_2E_1440), op(0x3c))
		i1 =  (-1)
		mstate.eax = i1
		__asm(jump, target("__UTF8_wcrtomb__XprivateX__BB26_23_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_2_F"))
		__asm(push(i1==0), iftrue, target("__UTF8_wcrtomb__XprivateX__BB26_21_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_3_F"))
		__asm(push(uint(i2)>uint(127)), iftrue, target("__UTF8_wcrtomb__XprivateX__BB26_5_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_4_F"))
		i3 =  (1)
		__asm(push(i2), push(i1), op(0x3a))
		mstate.eax = i3
		__asm(jump, target("__UTF8_wcrtomb__XprivateX__BB26_23_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_5_F"))
		__asm(push(uint(i2)>uint(2047)), iftrue, target("__UTF8_wcrtomb__XprivateX__BB26_7_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_6_F"))
		i0 =  (192)
		i4 =  (2)
		__asm(jump, target("__UTF8_wcrtomb__XprivateX__BB26_15_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_7_F"))
		__asm(push(uint(i2)>uint(65535)), iftrue, target("__UTF8_wcrtomb__XprivateX__BB26_9_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_8_F"))
		i0 =  (224)
		i4 =  (3)
		__asm(jump, target("__UTF8_wcrtomb__XprivateX__BB26_15_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_9_F"))
		__asm(push(uint(i2)>uint(2097151)), iftrue, target("__UTF8_wcrtomb__XprivateX__BB26_11_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_10_F"))
		i0 =  (240)
		i4 =  (4)
		__asm(jump, target("__UTF8_wcrtomb__XprivateX__BB26_15_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_11_F"))
		__asm(push(uint(i2)>uint(67108863)), iftrue, target("__UTF8_wcrtomb__XprivateX__BB26_13_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_12_F"))
		i0 =  (248)
		i4 =  (5)
		__asm(jump, target("__UTF8_wcrtomb__XprivateX__BB26_15_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_13_F"))
		__asm(push(i2<0), iftrue, target("__UTF8_wcrtomb__XprivateX__BB26_24_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_14_F"))
		i0 =  (252)
		i4 =  (6)
		__asm(jump, target("__UTF8_wcrtomb__XprivateX__BB26_15_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_15_F"))
		i5 = i2
		i6 =  (i4 + -1)
		__asm(push(i6>0), iftrue, target("__UTF8_wcrtomb__XprivateX__BB26_17_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_16_F"))
		i2 = i5
		__asm(jump, target("__UTF8_wcrtomb__XprivateX__BB26_20_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_17_F"))
		i6 =  (i4 + -1)
	__asm(jump, target("__UTF8_wcrtomb__XprivateX__BB26_18_F"), lbl("__UTF8_wcrtomb__XprivateX__BB26_18_B"), label, lbl("__UTF8_wcrtomb__XprivateX__BB26_18_F")); 
		i5 =  (i5 | -128)
		i5 =  (i5 & -65)
		i7 =  (i3 + i6)
		__asm(push(i5), push(i7), op(0x3a))
		i5 =  (i2 >> 6)
		i2 =  (i6 + -1)
		i7 = i5
		__asm(push(i2>0), iftrue, target("__UTF8_wcrtomb__XprivateX__BB26_25_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_19_F"))
		i2 = i5
		__asm(jump, target("__UTF8_wcrtomb__XprivateX__BB26_20_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_20_F"))
		i0 =  (i2 | i0)
		__asm(push(i0), push(i1), op(0x3a))
		mstate.eax = i4
		__asm(jump, target("__UTF8_wcrtomb__XprivateX__BB26_23_F"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_21_F"))
		i0 =  (1)
	__asm(jump, target("__UTF8_wcrtomb__XprivateX__BB26_22_F"), lbl("__UTF8_wcrtomb__XprivateX__BB26_22_B"), label, lbl("__UTF8_wcrtomb__XprivateX__BB26_22_F")); 
		mstate.eax = i0
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_23_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_24_F"))
		i0 =  (86)
		__asm(push(i0), push(_val_2E_1440), op(0x3c))
		i0 =  (-1)
		__asm(jump, target("__UTF8_wcrtomb__XprivateX__BB26_22_B"))
	__asm(lbl("__UTF8_wcrtomb__XprivateX__BB26_25_F"))
		i6 = i2
		i2 = i7
		__asm(jump, target("__UTF8_wcrtomb__XprivateX__BB26_18_B"))
	}
}



// Sync
public const ___adddi3:int = regFunc(FSM___adddi3.start)

public final class FSM___adddi3 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int


		__asm(label, lbl("___adddi3_entry"))
	__asm(lbl("___adddi3__XprivateX__BB27_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  (i0 + i1)
		i0 =  ((uint(i1)<uint(i0)) ? 1 : 0)
		i2 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i2 =  (i2 + i3)
		i0 =  (i0 & 1)
		i0 =  (i0 + i2)
		mstate.edx = i0
		mstate.eax = i1
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___anddi3:int = regFunc(FSM___anddi3.start)

public final class FSM___anddi3 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int


		__asm(label, lbl("___anddi3_entry"))
	__asm(lbl("___anddi3__XprivateX__BB28_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i2 =  (i2 & i3)
		i0 =  (i0 & i1)
		mstate.edx = i2
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___ashldi3:int = regFunc(FSM___ashldi3.start)

public final class FSM___ashldi3 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int


		__asm(label, lbl("___ashldi3_entry"))
	__asm(lbl("___ashldi3__XprivateX__BB29_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i4 =  ((uint(i0)<uint(32)) ? 1 : 0)
		i5 =  ((i1==0) ? 1 : 0)
		i4 =  ((i5!=0) ? i4 : 0)
		__asm(push(i4!=0), iftrue, target("___ashldi3__XprivateX__BB29_4_F"))
	__asm(lbl("___ashldi3__XprivateX__BB29_1_F"))
		i3 =  ((uint(i0)<uint(64)) ? 1 : 0)
		i1 =  ((i1==0) ? 1 : 0)
		i1 =  ((i1!=0) ? i3 : 0)
		__asm(push(i1!=0), iftrue, target("___ashldi3__XprivateX__BB29_3_F"))
	__asm(lbl("___ashldi3__XprivateX__BB29_2_F"))
		i0 =  (0)
		i1 = i0
		__asm(jump, target("___ashldi3__XprivateX__BB29_7_F"))
	__asm(lbl("___ashldi3__XprivateX__BB29_3_F"))
		i1 =  (0)
		i0 =  (i0 + -32)
		i0 =  (i2 << i0)
		mstate.edx = i0
		mstate.eax = i1
		__asm(jump, target("___ashldi3__XprivateX__BB29_8_F"))
	__asm(lbl("___ashldi3__XprivateX__BB29_4_F"))
		i1 =  (i0 | i1)
		__asm(push(i1!=0), iftrue, target("___ashldi3__XprivateX__BB29_6_F"))
	__asm(lbl("___ashldi3__XprivateX__BB29_5_F"))
		i0 = i2
		i1 = i3
		__asm(jump, target("___ashldi3__XprivateX__BB29_7_F"))
	__asm(lbl("___ashldi3__XprivateX__BB29_6_F"))
		i1 =  (32 - i0)
		i1 =  (i2 >>> i1)
		i3 =  (i3 << i0)
		i0 =  (i2 << i0)
		i1 =  (i1 | i3)
	__asm(lbl("___ashldi3__XprivateX__BB29_7_F"))
		mstate.edx = i1
		mstate.eax = i0
	__asm(lbl("___ashldi3__XprivateX__BB29_8_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___ashrdi3:int = regFunc(FSM___ashrdi3.start)

public final class FSM___ashrdi3 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
		var i8:int


		__asm(label, lbl("___ashrdi3_entry"))
	__asm(lbl("___ashrdi3__XprivateX__BB30_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i4 =  ((uint(i0)<uint(32)) ? 1 : 0)
		i5 =  ((i1==0) ? 1 : 0)
		i4 =  ((i5!=0) ? i4 : 0)
		__asm(push(i4!=0), iftrue, target("___ashrdi3__XprivateX__BB30_4_F"))
	__asm(lbl("___ashrdi3__XprivateX__BB30_1_F"))
		i2 =  (0)
		i4 =  (i3 >> 31)
		i5 =  ((i1!=0) ? 1 : 0)
		i6 =  ((uint(i0)>uint(63)) ? 1 : 0)
		i1 =  ((i1==0) ? 1 : 0)
		i7 = i2
		i8 = i4
		i1 =  ((i1!=0) ? i6 : i5)
		__asm(push(i1!=0), iftrue, target("___ashrdi3__XprivateX__BB30_3_F"))
	__asm(lbl("___ashrdi3__XprivateX__BB30_2_F"))
		i2 =  (i0 + -32)
		i2 =  (i3 >> i2)
		i2 =  (i2 | i7)
		mstate.edx = i4
		__asm(jump, target("___ashrdi3__XprivateX__BB30_7_F"))
	__asm(lbl("___ashrdi3__XprivateX__BB30_3_F"))
		i0 =  (i4 | i2)
		i1 =  (i7 | i8)
		mstate.edx = i0
		mstate.eax = i1
		__asm(jump, target("___ashrdi3__XprivateX__BB30_8_F"))
	__asm(lbl("___ashrdi3__XprivateX__BB30_4_F"))
		i1 =  (i0 | i1)
		__asm(push(i1==0), iftrue, target("___ashrdi3__XprivateX__BB30_6_F"))
	__asm(lbl("___ashrdi3__XprivateX__BB30_5_F"))
		i1 =  (32 - i0)
		i1 =  (i3 << i1)
		i2 =  (i2 >>> i0)
		i3 =  (i3 >> i0)
		i2 =  (i1 | i2)
	__asm(lbl("___ashrdi3__XprivateX__BB30_6_F"))
		mstate.edx = i3
	__asm(lbl("___ashrdi3__XprivateX__BB30_7_F"))
		mstate.eax = i2
	__asm(lbl("___ashrdi3__XprivateX__BB30_8_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___cmpdi2:int = regFunc(FSM___cmpdi2.start)

public final class FSM___cmpdi2 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int


		__asm(label, lbl("___cmpdi2_entry"))
	__asm(lbl("___cmpdi2__XprivateX__BB31_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i4 = i1
		i4 = i0
		__asm(push(i0>=i1), iftrue, target("___cmpdi2__XprivateX__BB31_2_F"))
	__asm(jump, target("___cmpdi2__XprivateX__BB31_1_F"), lbl("___cmpdi2__XprivateX__BB31_1_B"), label, lbl("___cmpdi2__XprivateX__BB31_1_F")); 
		i0 =  (0)
		__asm(jump, target("___cmpdi2__XprivateX__BB31_6_F"))
	__asm(lbl("___cmpdi2__XprivateX__BB31_2_F"))
		__asm(push(i0<=i1), iftrue, target("___cmpdi2__XprivateX__BB31_4_F"))
	__asm(lbl("___cmpdi2__XprivateX__BB31_3_F"))
		i0 =  (2)
		__asm(jump, target("___cmpdi2__XprivateX__BB31_6_F"))
	__asm(lbl("___cmpdi2__XprivateX__BB31_4_F"))
		i0 = i3
		i1 = i2
		__asm(push(uint(i2)<uint(i3)), iftrue, target("___cmpdi2__XprivateX__BB31_1_B"))
	__asm(lbl("___cmpdi2__XprivateX__BB31_5_F"))
		i0 =  ((uint(i1)>uint(i0)) ? 2 : 1)
	__asm(lbl("___cmpdi2__XprivateX__BB31_6_F"))
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___divdi3:int = regFunc(FSM___divdi3.start)

public final class FSM___divdi3 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
		var i8:int


		__asm(label, lbl("___divdi3_entry"))
	__asm(lbl("___divdi3__XprivateX__BB32_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  (0)
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i4 =  (i1 >> 31)
		i5 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i6 =  (i2 >> 31)
		i3 =  __addc(i3, i4)
		i7 =  __adde(i1, i4)
		i5 =  __addc(i5, i6)
		i8 =  __adde(i2, i6)
		mstate.esp -= 20
		i8 =  (i8 ^ i6)
		i5 =  (i5 ^ i6)
		i6 =  (i7 ^ i4)
		i3 =  (i3 ^ i4)
		__asm(push(i3), push(mstate.esp), op(0x3c))
		__asm(push(i6), push((mstate.esp+4)), op(0x3c))
		__asm(push(i5), push((mstate.esp+8)), op(0x3c))
		__asm(push(i8), push((mstate.esp+12)), op(0x3c))
		__asm(push(i0), push((mstate.esp+16)), op(0x3c))
		mstate.esp -= 4;FSM___qdivrem.start()
	__asm(lbl("___divdi3_state1"))
		i0 = mstate.eax
		i3 = mstate.edx
		mstate.esp += 20
		i1 =  (i1 >>> 31)
		i2 =  (i2 >>> 31)
		__asm(push(i1==i2), iftrue, target("___divdi3__XprivateX__BB32_2_F"))
	__asm(lbl("___divdi3__XprivateX__BB32_1_F"))
		i1 =  (0)
		i0 =  __subc(i1, i0)
		i3 =  __sube(i1, i3)
	__asm(lbl("___divdi3__XprivateX__BB32_2_F"))
		mstate.edx = i3
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___qdivrem:int = regFunc(FSM___qdivrem.start)

public final class FSM___qdivrem extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
		var i8:int, i9:int, i10:int, i11:int, i12:int, i13:int, i14:int, i15:int
		var i16:int, i17:int, i18:int, i19:int, i20:int, i21:int, i22:int, i23:int
		var i24:int, i25:int, i26:int

		__asm(label, lbl("___qdivrem_entry"))
	__asm(lbl("___qdivrem__XprivateX__BB33_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 48
		i0 =  ((mstate.ebp+-48))
		i1 =  ((__xasm<int>(push((mstate.ebp+24)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i4 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i5 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i6 =  ((mstate.ebp+-32))
		i7 =  ((mstate.ebp+-16))
		i8 =  (i4 | i5)
		__asm(push(i8!=0), iftrue, target("___qdivrem__XprivateX__BB33_4_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_1_F"))
		__asm(push(i1!=0), iftrue, target("___qdivrem__XprivateX__BB33_3_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_2_F"))
		i0 =  (0)
		i0 =  (uint(1) / uint(i0))
		i1 = i0
		__asm(jump, target("___qdivrem__XprivateX__BB33_83_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_3_F"))
		i0 =  (0)
		__asm(push(i2), push(i1), op(0x3c))
		__asm(push(i3), push((i1+4)), op(0x3c))
		i0 =  (uint(1) / uint(i0))
		__asm(jump, target("___qdivrem__XprivateX__BB33_8_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_4_F"))
		i8 =  ((uint(i3)>=uint(i5)) ? 1 : 0)
		i9 =  ((uint(i2)>=uint(i4)) ? 1 : 0)
		i10 =  ((i3==i5) ? 1 : 0)
		i8 =  ((i10!=0) ? i9 : i8)
		__asm(push(i8!=0), iftrue, target("___qdivrem__XprivateX__BB33_9_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_5_F"))
		__asm(push(i1!=0), iftrue, target("___qdivrem__XprivateX__BB33_7_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_6_F"))
		i0 =  (0)
		i1 = i0
		__asm(jump, target("___qdivrem__XprivateX__BB33_83_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_7_F"))
		i0 =  (0)
		__asm(push(i2), push(i1), op(0x3c))
		__asm(push(i3), push((i1+4)), op(0x3c))
	__asm(lbl("___qdivrem__XprivateX__BB33_8_F"))
		mstate.edx = i0
		__asm(jump, target("___qdivrem__XprivateX__BB33_84_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_9_F"))
		i8 =  (0)
		__asm(push(i8), push((mstate.ebp+-48)), op(0x3b))
		i8 =  (i3 >>> 16)
		__asm(push(i8), push((mstate.ebp+-46)), op(0x3b))
		__asm(push(i3), push((mstate.ebp+-44)), op(0x3b))
		i9 =  (i2 >>> 16)
		__asm(push(i9), push((mstate.ebp+-42)), op(0x3b))
		__asm(push(i2), push((mstate.ebp+-40)), op(0x3b))
		i10 =  (i5 >>> 16)
		__asm(push(i10), push((mstate.ebp+-30)), op(0x3b))
		__asm(push(i5), push((mstate.ebp+-28)), op(0x3b))
		i5 =  (i4 >>> 16)
		i11 =  ((mstate.ebp+-48))
		__asm(push(i5), push((mstate.ebp+-26)), op(0x3b))
		__asm(push(i4), push((mstate.ebp+-24)), op(0x3b))
		i4 =  (i11 + 8)
		i5 =  (i11 + 6)
		i12 =  (i11 + 4)
		i13 =  (i11 + 2)
		i14 =  ((mstate.ebp+-32))
		i15 = i8
		__asm(push(i10==0), iftrue, target("___qdivrem__XprivateX__BB33_11_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_10_F"))
		i2 =  (4)
		i3 = i14
		__asm(jump, target("___qdivrem__XprivateX__BB33_19_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_11_F"))
		i10 =  (0)
		i6 =  (i6 + 4)
		i14 = i10
	__asm(jump, target("___qdivrem__XprivateX__BB33_12_F"), lbl("___qdivrem__XprivateX__BB33_12_B"), label, lbl("___qdivrem__XprivateX__BB33_12_F")); 
		i16 = i6
		i17 =  (i14 + 3)
		__asm(push(i17!=1), iftrue, target("___qdivrem__XprivateX__BB33_16_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_13_F"))
		i0 =  ((mstate.ebp+-32))
		i6 =  (i10 << 1)
		i0 =  (i6 + i0)
		i0 =  ((__xasm<int>(push((i0+4)), op(0x36))))
		i6 =  (uint(i8) % uint(i0))
		i3 =  (i3 & 65535)
		i6 =  (i6 << 16)
		i3 =  (i3 | i6)
		i6 =  (uint(i3) % uint(i0))
		i6 =  (i6 << 16)
		i6 =  (i9 | i6)
		i10 =  (uint(i6) % uint(i0))
		i2 =  (i2 & 65535)
		i10 =  (i10 << 16)
		i2 =  (i2 | i10)
		i10 =  (uint(i2) / uint(i0))
		i6 =  (uint(i6) / uint(i0))
		i3 =  (uint(i3) / uint(i0))
		i14 =  (uint(i8) / uint(i0))
		__asm(push(i1==0), iftrue, target("___qdivrem__XprivateX__BB33_15_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_14_F"))
		i4 =  (0)
		i0 =  (uint(i2) % uint(i0))
		__asm(push(i0), push(i1), op(0x3c))
		__asm(push(i4), push((i1+4)), op(0x3c))
	__asm(lbl("___qdivrem__XprivateX__BB33_15_F"))
		i0 =  (i10 & 65535)
		i1 =  (i6 << 16)
		i2 =  (i3 & 65535)
		i3 =  (i14 << 16)
		i0 =  (i0 | i1)
		i1 =  (i2 | i3)
		__asm(jump, target("___qdivrem__XprivateX__BB33_83_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_16_F"))
		i16 =  ((__xasm<int>(push(i16), op(0x36))))
		i6 =  (i6 + 2)
		i14 =  (i14 + -1)
		i10 =  (i10 + 1)
		__asm(push(i16!=0), iftrue, target("___qdivrem__XprivateX__BB33_18_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_17_F"))
		__asm(jump, target("___qdivrem__XprivateX__BB33_12_B"))
	__asm(lbl("___qdivrem__XprivateX__BB33_18_F"))
		i2 =  ((mstate.ebp+-32))
		i3 =  (i10 << 1)
		i6 =  (i14 + 4)
		i3 =  (i2 + i3)
		i2 = i6
	__asm(lbl("___qdivrem__XprivateX__BB33_19_F"))
		i6 =  (4 - i2)
		i8 = i3
		i9 =  (i15 & 65535)
		__asm(push(i9==0), iftrue, target("___qdivrem__XprivateX__BB33_21_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_20_F"))
		i0 = i6
		i6 = i11
		__asm(jump, target("___qdivrem__XprivateX__BB33_25_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_21_F"))
		i9 =  (0)
		i0 =  (i0 + 4)
	__asm(jump, target("___qdivrem__XprivateX__BB33_22_F"), lbl("___qdivrem__XprivateX__BB33_22_B"), label, lbl("___qdivrem__XprivateX__BB33_22_F")); 
		i10 =  ((__xasm<int>(push(i0), op(0x36))))
		i0 =  (i0 + 2)
		i9 =  (i9 + 1)
		__asm(push(i10!=0), iftrue, target("___qdivrem__XprivateX__BB33_24_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_23_F"))
		__asm(jump, target("___qdivrem__XprivateX__BB33_22_B"))
	__asm(lbl("___qdivrem__XprivateX__BB33_24_F"))
		i0 =  ((mstate.ebp+-48))
		i10 =  (i9 + -1)
		i9 =  (i9 << 1)
		i6 =  (i6 - i10)
		i9 =  (i0 + i9)
		i0 =  (i6 + -1)
		i6 = i9
	__asm(lbl("___qdivrem__XprivateX__BB33_25_F"))
		i9 =  (3 - i0)
		i10 = i6
		__asm(push(i9<0), iftrue, target("___qdivrem__XprivateX__BB33_29_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_26_F"))
		i9 =  (i0 << 1)
		i9 =  (i7 - i9)
		i11 =  (3 - i0)
		i9 =  (i9 + 6)
	__asm(jump, target("___qdivrem__XprivateX__BB33_27_F"), lbl("___qdivrem__XprivateX__BB33_27_B"), label, lbl("___qdivrem__XprivateX__BB33_27_F")); 
		i14 =  (0)
		__asm(push(i14), push(i9), op(0x3b))
		i9 =  (i9 + -2)
		i11 =  (i11 + -1)
		__asm(push(i11<0), iftrue, target("___qdivrem__XprivateX__BB33_29_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_28_F"))
		__asm(jump, target("___qdivrem__XprivateX__BB33_27_B"))
	__asm(lbl("___qdivrem__XprivateX__BB33_29_F"))
		i9 =  ((__xasm<int>(push((i3+2)), op(0x36))))
		i11 =  (i3 + 2)
		i14 =  (i9 << 16)
		i14 =  (i14 >> 16)
		__asm(push(i14>-1), iftrue, target("___qdivrem__XprivateX__BB33_31_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_30_F"))
		i9 =  (0)
		__asm(jump, target("___qdivrem__XprivateX__BB33_34_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_31_F"))
		i14 =  (0)
	__asm(jump, target("___qdivrem__XprivateX__BB33_32_F"), lbl("___qdivrem__XprivateX__BB33_32_B"), label, lbl("___qdivrem__XprivateX__BB33_32_F")); 
		i14 =  (i14 + 1)
		i9 =  (i9 << 1)
		__asm(push(uint(i9)<uint(32768)), iftrue, target("___qdivrem__XprivateX__BB33_85_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_33_F"))
		i9 = i14
		__asm(jump, target("___qdivrem__XprivateX__BB33_34_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_34_F"))
		__asm(push(i9<1), iftrue, target("___qdivrem__XprivateX__BB33_47_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_35_F"))
		i14 =  ((__xasm<int>(push(i6), op(0x36))))
		i14 =  (i14 << i9)
		i15 =  (i0 + i2)
		__asm(push(i15>0), iftrue, target("___qdivrem__XprivateX__BB33_39_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_36_F"))
		i15 =  (0)
		__asm(jump, target("___qdivrem__XprivateX__BB33_37_F"))
	__asm(jump, target("___qdivrem__XprivateX__BB33_37_F"), lbl("___qdivrem__XprivateX__BB33_37_B"), label, lbl("___qdivrem__XprivateX__BB33_37_F")); 
		i15 =  (i15 << 1)
		i15 =  (i6 + i15)
		__asm(push(i14), push(i15), op(0x3b))
		i14 =  ((__xasm<int>(push(i11), op(0x36))))
		i14 =  (i14 << i9)
		i15 =  (i2 + -1)
		__asm(push(i15>0), iftrue, target("___qdivrem__XprivateX__BB33_42_F"))
		__asm(jump, target("___qdivrem__XprivateX__BB33_38_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_38_F"))
		i15 =  (1)
		__asm(jump, target("___qdivrem__XprivateX__BB33_46_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_39_F"))
		i16 =  (0)
		i17 =  (16 - i9)
		i18 = i10
	__asm(jump, target("___qdivrem__XprivateX__BB33_40_F"), lbl("___qdivrem__XprivateX__BB33_40_B"), label, lbl("___qdivrem__XprivateX__BB33_40_F")); 
		i19 =  ((__xasm<int>(push((i18+2)), op(0x36))))
		i19 =  (i19 >>> i17)
		i14 =  (i19 | i14)
		__asm(push(i14), push(i18), op(0x3b))
		i14 =  ((__xasm<int>(push((i18+2)), op(0x36))))
		i16 =  (i16 + 1)
		i14 =  (i14 << i9)
		i18 =  (i18 + 2)
		__asm(push(i16==i15), iftrue, target("___qdivrem__XprivateX__BB33_37_B"))
	__asm(lbl("___qdivrem__XprivateX__BB33_41_F"))
		__asm(jump, target("___qdivrem__XprivateX__BB33_40_B"))
	__asm(lbl("___qdivrem__XprivateX__BB33_42_F"))
		i16 =  (0)
		i17 =  (16 - i9)
		i18 = i8
	__asm(jump, target("___qdivrem__XprivateX__BB33_43_F"), lbl("___qdivrem__XprivateX__BB33_43_B"), label, lbl("___qdivrem__XprivateX__BB33_43_F")); 
		i19 =  ((__xasm<int>(push((i18+4)), op(0x36))))
		i19 =  (i19 >>> i17)
		i14 =  (i19 | i14)
		__asm(push(i14), push((i18+2)), op(0x3b))
		i14 =  ((__xasm<int>(push((i18+4)), op(0x36))))
		i16 =  (i16 + 1)
		i14 =  (i14 << i9)
		i18 =  (i18 + 2)
		__asm(push(i16==i15), iftrue, target("___qdivrem__XprivateX__BB33_45_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_44_F"))
		__asm(jump, target("___qdivrem__XprivateX__BB33_43_B"))
	__asm(lbl("___qdivrem__XprivateX__BB33_45_F"))
		i15 = i2
	__asm(lbl("___qdivrem__XprivateX__BB33_46_F"))
		i15 =  (i15 << 1)
		i15 =  (i3 + i15)
		__asm(push(i14), push(i15), op(0x3b))
	__asm(lbl("___qdivrem__XprivateX__BB33_47_F"))
		i14 =  (0)
		i11 =  ((__xasm<int>(push(i11), op(0x36))))
		i3 =  ((__xasm<int>(push((i3+4)), op(0x36))))
		i15 =  (i0 << 1)
		i7 =  (i7 - i15)
		i15 = i11
		i16 = i14
	__asm(jump, target("___qdivrem__XprivateX__BB33_48_F"), lbl("___qdivrem__XprivateX__BB33_48_B"), label, lbl("___qdivrem__XprivateX__BB33_48_F")); 
		i17 =  (i10 + i16)
		i18 =  ((__xasm<int>(push(i17), op(0x36))))
		i19 =  ((__xasm<int>(push((i17+2)), op(0x36))))
		i20 =  ((__xasm<int>(push((i17+4)), op(0x36))))
		i21 =  (i11 & 65535)
		__asm(push(i18!=i21), iftrue, target("___qdivrem__XprivateX__BB33_52_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_49_F"))
		i18 =  (i19 & 65535)
		i18 =  (i18 + i15)
		__asm(push(uint(i18)>uint(65535)), iftrue, target("___qdivrem__XprivateX__BB33_51_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_50_F"))
		i19 =  (65535)
		__asm(jump, target("___qdivrem__XprivateX__BB33_53_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_51_F"))
		i18 =  (65535)
		__asm(jump, target("___qdivrem__XprivateX__BB33_57_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_52_F"))
		i19 =  (i19 & 65535)
		i18 =  (i18 << 16)
		i18 =  (i18 | i19)
		i19 =  (uint(i18) % uint(i15))
		i21 =  (uint(i18) / uint(i15))
		i18 = i19
		i19 = i21
	__asm(lbl("___qdivrem__XprivateX__BB33_53_F"))
		i21 =  (i11 & 65535)
		i22 =  (i3 & 65535)
		i20 =  (i20 & 65535)
		i23 =  (i18 << 16)
		i24 =  (i21 << 16)
		i25 =  (i19 * i22)
		__asm(jump, target("___qdivrem__XprivateX__BB33_56_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_54_B"), label)
		i25 =  (i25 - i22)
		i19 =  (i21 + i26)
		i23 =  (i24 + i23)
		i26 =  (i18 + -1)
		__asm(push(uint(i19)>uint(65535)), iftrue, target("___qdivrem__XprivateX__BB33_86_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_55_F"))
		i18 = i19
		i19 = i26
		__asm(jump, target("___qdivrem__XprivateX__BB33_56_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_56_F"))
		i26 = i18
		i18 = i19
		i19 =  (i23 | i20)
		__asm(push(uint(i25)>uint(i19)), iftrue, target("___qdivrem__XprivateX__BB33_54_B"))
	__asm(jump, target("___qdivrem__XprivateX__BB33_57_F"), lbl("___qdivrem__XprivateX__BB33_57_B"), label, lbl("___qdivrem__XprivateX__BB33_57_F")); 
		__asm(push(i2>0), iftrue, target("___qdivrem__XprivateX__BB33_59_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_58_F"))
		i19 =  (0)
		__asm(jump, target("___qdivrem__XprivateX__BB33_62_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_59_F"))
		i19 =  (0)
		i20 =  (i2 << 1)
		i21 =  (i10 + i16)
		i22 = i2
	__asm(jump, target("___qdivrem__XprivateX__BB33_60_F"), lbl("___qdivrem__XprivateX__BB33_60_B"), label, lbl("___qdivrem__XprivateX__BB33_60_F")); 
		i23 =  (i8 + i20)
		i23 =  ((__xasm<int>(push(i23), op(0x36))))
		i24 =  (i21 + i20)
		i25 =  ((__xasm<int>(push(i24), op(0x36))))
		i23 =  (i23 * i18)
		i23 =  (i25 - i23)
		i19 =  (i23 - i19)
		i23 =  (i19 >>> 16)
		i23 =  (65536 - i23)
		__asm(push(i19), push(i24), op(0x3b))
		i19 =  (i20 + -2)
		i22 =  (i22 + -1)
		i23 =  (i23 & 65535)
		__asm(push(i22>0), iftrue, target("___qdivrem__XprivateX__BB33_87_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_61_F"))
		i19 = i23
		__asm(jump, target("___qdivrem__XprivateX__BB33_62_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_62_F"))
		i20 =  ((__xasm<int>(push(i17), op(0x36))))
		i19 =  (i20 - i19)
		__asm(push(i19), push(i17), op(0x3b))
		__asm(push(uint(i19)>uint(65535)), iftrue, target("___qdivrem__XprivateX__BB33_66_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_63_F"))
		i17 = i18
		__asm(jump, target("___qdivrem__XprivateX__BB33_64_F"))
	__asm(jump, target("___qdivrem__XprivateX__BB33_64_F"), lbl("___qdivrem__XprivateX__BB33_64_B"), label, lbl("___qdivrem__XprivateX__BB33_64_F")); 
		i18 =  (i7 + i16)
		__asm(push(i17), push((i18+8)), op(0x3b))
		i16 =  (i16 + 2)
		i14 =  (i14 + 1)
		__asm(push(i14>i0), iftrue, target("___qdivrem__XprivateX__BB33_72_F"))
		__asm(jump, target("___qdivrem__XprivateX__BB33_65_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_65_F"))
		__asm(jump, target("___qdivrem__XprivateX__BB33_48_B"))
	__asm(lbl("___qdivrem__XprivateX__BB33_66_F"))
		i18 =  (i18 + -1)
		__asm(push(i2>0), iftrue, target("___qdivrem__XprivateX__BB33_69_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_67_F"))
		i19 =  (0)
		__asm(jump, target("___qdivrem__XprivateX__BB33_68_F"))
	__asm(jump, target("___qdivrem__XprivateX__BB33_68_F"), lbl("___qdivrem__XprivateX__BB33_68_B"), label, lbl("___qdivrem__XprivateX__BB33_68_F")); 
		i20 =  ((__xasm<int>(push(i17), op(0x36))))
		i19 =  (i20 + i19)
		__asm(push(i19), push(i17), op(0x3b))
		i17 = i18
		__asm(jump, target("___qdivrem__XprivateX__BB33_64_B"))
	__asm(lbl("___qdivrem__XprivateX__BB33_69_F"))
		i19 =  (0)
		i20 =  (i2 << 1)
		i21 =  (i10 + i16)
		i22 = i2
	__asm(jump, target("___qdivrem__XprivateX__BB33_70_F"), lbl("___qdivrem__XprivateX__BB33_70_B"), label, lbl("___qdivrem__XprivateX__BB33_70_F")); 
		i23 =  (i21 + i20)
		i24 =  ((__xasm<int>(push(i23), op(0x36))))
		i25 =  (i8 + i20)
		i25 =  ((__xasm<int>(push(i25), op(0x36))))
		i19 =  (i24 + i19)
		i19 =  (i19 + i25)
		__asm(push(i19), push(i23), op(0x3b))
		i20 =  (i20 + -2)
		i22 =  (i22 + -1)
		i19 =  (i19 >>> 16)
		__asm(push(i22<1), iftrue, target("___qdivrem__XprivateX__BB33_68_B"))
	__asm(lbl("___qdivrem__XprivateX__BB33_71_F"))
		__asm(jump, target("___qdivrem__XprivateX__BB33_70_B"))
	__asm(lbl("___qdivrem__XprivateX__BB33_72_F"))
		__asm(push(i1==0), iftrue, target("___qdivrem__XprivateX__BB33_82_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_73_F"))
		__asm(push(i9==0), iftrue, target("___qdivrem__XprivateX__BB33_81_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_74_F"))
		i3 =  (i2 + i0)
		i7 =  (i3 << 1)
		i6 =  (i6 + i7)
		__asm(push(i3>i0), iftrue, target("___qdivrem__XprivateX__BB33_76_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_75_F"))
		i0 = i6
		__asm(jump, target("___qdivrem__XprivateX__BB33_80_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_76_F"))
		i3 =  (i2 + i0)
		i7 =  (i3 + -1)
		i7 =  (i7 << 1)
		i8 =  (i3 << 1)
		i11 =  (16 - i9)
	__asm(jump, target("___qdivrem__XprivateX__BB33_77_F"), lbl("___qdivrem__XprivateX__BB33_77_B"), label, lbl("___qdivrem__XprivateX__BB33_77_F")); 
		i14 =  (i8 + i10)
		i6 =  ((__xasm<int>(push(i6), op(0x36))))
		i15 =  ((__xasm<int>(push((i14+-2)), op(0x36))))
		i15 =  (i15 << i11)
		i6 =  (i6 >>> i9)
		i6 =  (i15 | i6)
		__asm(push(i6), push(i14), op(0x3b))
		i6 =  (i7 + i10)
		i10 =  (i10 + -2)
		i3 =  (i3 + -1)
		__asm(push(i3<=i0), iftrue, target("___qdivrem__XprivateX__BB33_79_F"))
	__asm(lbl("___qdivrem__XprivateX__BB33_78_F"))
		__asm(jump, target("___qdivrem__XprivateX__BB33_77_B"))
	__asm(lbl("___qdivrem__XprivateX__BB33_79_F"))
		i0 =  (i2 + i0)
		i0 =  (i0 << 1)
		i0 =  (i0 + i10)
	__asm(lbl("___qdivrem__XprivateX__BB33_80_F"))
		i2 =  (0)
		__asm(push(i2), push(i0), op(0x3b))
	__asm(lbl("___qdivrem__XprivateX__BB33_81_F"))
		i0 =  ((__xasm<int>(push(i13), op(0x36))))
		i2 =  ((__xasm<int>(push(i5), op(0x36))))
		i3 =  ((__xasm<int>(push(i12), op(0x36))))
		i4 =  ((__xasm<int>(push(i4), op(0x36))))
		i2 =  (i2 << 16)
		i0 =  (i0 << 16)
		i2 =  (i2 | i4)
		i0 =  (i0 | i3)
		__asm(push(i2), push(i1), op(0x3c))
		__asm(push(i0), push((i1+4)), op(0x3c))
	__asm(lbl("___qdivrem__XprivateX__BB33_82_F"))
		i0 =  ((__xasm<int>(push((mstate.ebp+-10)), op(0x36))))
		i1 =  ((__xasm<int>(push((mstate.ebp+-14)), op(0x36))))
		i2 =  ((__xasm<int>(push((mstate.ebp+-8)), op(0x36))))
		i3 =  ((__xasm<int>(push((mstate.ebp+-12)), op(0x36))))
		i0 =  (i0 << 16)
		i1 =  (i1 << 16)
		i0 =  (i0 | i2)
		i1 =  (i1 | i3)
	__asm(lbl("___qdivrem__XprivateX__BB33_83_F"))
		mstate.edx = i1
	__asm(lbl("___qdivrem__XprivateX__BB33_84_F"))
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	__asm(lbl("___qdivrem__XprivateX__BB33_85_F"))
		__asm(jump, target("___qdivrem__XprivateX__BB33_32_B"))
	__asm(lbl("___qdivrem__XprivateX__BB33_86_F"))
		i18 = i26
		__asm(jump, target("___qdivrem__XprivateX__BB33_57_B"))
	__asm(lbl("___qdivrem__XprivateX__BB33_87_F"))
		i20 = i19
		i19 = i23
		__asm(jump, target("___qdivrem__XprivateX__BB33_60_B"))
	}
}



// Sync
public const ___fixdfdi:int = regFunc(FSM___fixdfdi.start)

public final class FSM___fixdfdi extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int

		var f0:Number, f1:Number

		__asm(label, lbl("___fixdfdi_entry"))
	__asm(lbl("___fixdfdi__XprivateX__BB34_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		f0 =  (0)
		f1 =  ((__xasm<Number>(push((mstate.ebp+8)), op(0x39))))
		__asm(push(f1>=f0), iftrue, target("___fixdfdi__XprivateX__BB34_3_F"))
	__asm(lbl("___fixdfdi__XprivateX__BB34_1_F"))
		f0 =  (-9.22337e+18)
		__asm(push(f1>f0), iftrue, target("___fixdfdi__XprivateX__BB34_6_F"))
	__asm(lbl("___fixdfdi__XprivateX__BB34_2_F"))
		i0 =  (-2147483648)
		i1 =  (0)
		__asm(jump, target("___fixdfdi__XprivateX__BB34_7_F"))
	__asm(lbl("___fixdfdi__XprivateX__BB34_3_F"))
		f0 =  (9.22337e+18)
		__asm(push(f1<f0), iftrue, target("___fixdfdi__XprivateX__BB34_5_F"))
	__asm(lbl("___fixdfdi__XprivateX__BB34_4_F"))
		i0 =  (2147483647)
		i1 =  (-1)
		__asm(jump, target("___fixdfdi__XprivateX__BB34_7_F"))
	__asm(lbl("___fixdfdi__XprivateX__BB34_5_F"))
		mstate.esp -= 8
		__asm(push(f1), push(mstate.esp), op(0x3e))
		mstate.esp -= 4;(mstate.funcs[___fixunsdfdi])()
	__asm(lbl("___fixdfdi_state1"))
		i0 = mstate.eax
		i1 = mstate.edx
		mstate.esp += 8
		mstate.edx = i1
		mstate.eax = i0
		__asm(jump, target("___fixdfdi__XprivateX__BB34_8_F"))
	__asm(lbl("___fixdfdi__XprivateX__BB34_6_F"))
		i0 =  (0)
		mstate.esp -= 8
		f1 =  -f1
		__asm(push(f1), push(mstate.esp), op(0x3e))
		mstate.esp -= 4;(mstate.funcs[___fixunsdfdi])()
	__asm(lbl("___fixdfdi_state2"))
		i1 = mstate.eax
		i2 = mstate.edx
		mstate.esp += 8
		i1 =  __subc(i0, i1)
		i0 =  __sube(i0, i2)
		__asm(jump, target("___fixdfdi__XprivateX__BB34_7_F"))
	__asm(lbl("___fixdfdi__XprivateX__BB34_7_F"))
		mstate.edx = i0
		mstate.eax = i1
	__asm(lbl("___fixdfdi__XprivateX__BB34_8_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___fixsfdi:int = regFunc(FSM___fixsfdi.start)

public final class FSM___fixsfdi extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int

		var f0:Number, f1:Number, f2:Number

		__asm(label, lbl("___fixsfdi_entry"))
	__asm(lbl("___fixsfdi__XprivateX__BB35_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		f0 =  (0)
		f1 =  ((__xasm<Number>(push((mstate.ebp+8)), op(0x38))))
		f0 =  f0/*fround*/
		f0 =  f0/*fextend*/
		f2 =  f1/*fextend*/
		__asm(push(f2>=f0), iftrue, target("___fixsfdi__XprivateX__BB35_3_F"))
	__asm(lbl("___fixsfdi__XprivateX__BB35_1_F"))
		f0 =  (-9.22337e+18)
		f0 =  f0/*fround*/
		f0 =  f0/*fextend*/
		f2 =  f1/*fextend*/
		__asm(push(f2>f0), iftrue, target("___fixsfdi__XprivateX__BB35_6_F"))
	__asm(lbl("___fixsfdi__XprivateX__BB35_2_F"))
		i0 =  (-2147483648)
		i1 =  (0)
		__asm(jump, target("___fixsfdi__XprivateX__BB35_7_F"))
	__asm(lbl("___fixsfdi__XprivateX__BB35_3_F"))
		f0 =  (9.22337e+18)
		f0 =  f0/*fround*/
		f0 =  f0/*fextend*/
		f2 =  f1/*fextend*/
		__asm(push(f2<f0), iftrue, target("___fixsfdi__XprivateX__BB35_5_F"))
	__asm(lbl("___fixsfdi__XprivateX__BB35_4_F"))
		i0 =  (2147483647)
		i1 =  (-1)
		__asm(jump, target("___fixsfdi__XprivateX__BB35_7_F"))
	__asm(lbl("___fixsfdi__XprivateX__BB35_5_F"))
		mstate.esp -= 4
		__asm(push(f1), push(mstate.esp), op(0x3d))
		mstate.esp -= 4;(mstate.funcs[___fixunssfdi])()
	__asm(lbl("___fixsfdi_state1"))
		i0 = mstate.eax
		i1 = mstate.edx
		mstate.esp += 4
		mstate.edx = i1
		mstate.eax = i0
		__asm(jump, target("___fixsfdi__XprivateX__BB35_8_F"))
	__asm(lbl("___fixsfdi__XprivateX__BB35_6_F"))
		i0 =  (0)
		f0 =  f1/*fextend*/
		f0 =  -f0
		mstate.esp -= 4
		f1 =  f0/*fround*/
		__asm(push(f1), push(mstate.esp), op(0x3d))
		mstate.esp -= 4;(mstate.funcs[___fixunssfdi])()
	__asm(lbl("___fixsfdi_state2"))
		i1 = mstate.eax
		i2 = mstate.edx
		mstate.esp += 4
		i1 =  __subc(i0, i1)
		i0 =  __sube(i0, i2)
		__asm(jump, target("___fixsfdi__XprivateX__BB35_7_F"))
	__asm(lbl("___fixsfdi__XprivateX__BB35_7_F"))
		mstate.edx = i0
		mstate.eax = i1
	__asm(lbl("___fixsfdi__XprivateX__BB35_8_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___fixunsdfdi:int = regFunc(FSM___fixunsdfdi.start)

public final class FSM___fixunsdfdi extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int

		var f0:Number, f1:Number, f2:Number, f3:Number, f4:Number

		__asm(label, lbl("___fixunsdfdi_entry"))
	__asm(lbl("___fixunsdfdi__XprivateX__BB36_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		f0 =  (1.84467e+19)
		f1 =  ((__xasm<Number>(push((mstate.ebp+8)), op(0x39))))
		__asm(push(f1>=f0), iftrue, target("___fixunsdfdi__XprivateX__BB36_3_F"))
	__asm(lbl("___fixunsdfdi__XprivateX__BB36_1_F"))
		f0 =  (0)
		__asm(push(f1<f0), iftrue, target("___fixunsdfdi__XprivateX__BB36_3_F"))
	__asm(lbl("___fixunsdfdi__XprivateX__BB36_2_F"))
		i0 =  (0)
		f0 =  (f1 + -2.14748e+09)
		f0 =  (f0 * 2.32831e-10)
		mstate.esp -= 8
		i1 =  (uint(f0))
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		mstate.esp -= 4;(mstate.funcs[___floatdidf])()
	__asm(lbl("___fixunsdfdi_state1"))
		f0 = mstate.st0
		f0 =  (f1 - f0)
		f1 =  (0)
		f2 =  (f0 + 4.29497e+09)
		f2 =  ((f0<f1) ? f2 : f0)
		i2 =  (i1 + -1)
		f3 =  (4.29497e+09)
		f4 =  (f2 - 4.29497e+09)
		f4 =  ((f2>f3) ? f4 : f2)
		i1 =  ((f0>=f1) ? i1 : i2)
		i0 =  ((f0>=f1) ? 0 : i0)
		i2 =  (i1 + 1)
		i0 =  ((f2<=f3) ? i0 : i0)
		i3 =  (uint(f4))
		mstate.esp += 8
		i0 =  (i0 | i3)
		i1 =  ((f2<=f3) ? i1 : i2)
		mstate.edx = i1
		__asm(jump, target("___fixunsdfdi__XprivateX__BB36_4_F"))
	__asm(lbl("___fixunsdfdi__XprivateX__BB36_3_F"))
		i0 =  (-1)
		mstate.edx = i0
	__asm(lbl("___fixunsdfdi__XprivateX__BB36_4_F"))
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___fixunssfdi:int = regFunc(FSM___fixunssfdi.start)

public final class FSM___fixunssfdi extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int

		var f0:Number, f1:Number, f2:Number, f3:Number, f4:Number

		__asm(label, lbl("___fixunssfdi_entry"))
	__asm(lbl("___fixunssfdi__XprivateX__BB37_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		f0 =  (1.84467e+19)
		f1 =  ((__xasm<Number>(push((mstate.ebp+8)), op(0x38))))
		f0 =  f0/*fround*/
		f0 =  f0/*fextend*/
		f2 =  f1/*fextend*/
		__asm(push(f2>=f0), iftrue, target("___fixunssfdi__XprivateX__BB37_3_F"))
	__asm(lbl("___fixunssfdi__XprivateX__BB37_1_F"))
		f0 =  (0)
		f0 =  f0/*fround*/
		f0 =  f0/*fextend*/
		f2 =  f1/*fextend*/
		__asm(push(f2<f0), iftrue, target("___fixunssfdi__XprivateX__BB37_3_F"))
	__asm(lbl("___fixunssfdi__XprivateX__BB37_2_F"))
		i0 =  (0)
		f0 =  f1/*fextend*/
		f1 =  (f0 + -2.14748e+09)
		f1 =  (f1 * 2.32831e-10)
		mstate.esp -= 8
		i1 =  (uint(f1))
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		mstate.esp -= 4;(mstate.funcs[___floatdidf])()
	__asm(lbl("___fixunssfdi_state1"))
		f1 = mstate.st0
		f0 =  (f0 - f1)
		f1 =  (0)
		f2 =  (f0 + 4.29497e+09)
		f2 =  ((f0<f1) ? f2 : f0)
		i2 =  (i1 + -1)
		f3 =  (4.29497e+09)
		f4 =  (f2 - 4.29497e+09)
		f4 =  ((f2>f3) ? f4 : f2)
		i1 =  ((f0>=f1) ? i1 : i2)
		i0 =  ((f0>=f1) ? 0 : i0)
		i2 =  (i1 + 1)
		i0 =  ((f2<=f3) ? i0 : i0)
		i3 =  (uint(f4))
		mstate.esp += 8
		i0 =  (i0 | i3)
		i1 =  ((f2<=f3) ? i1 : i2)
		mstate.edx = i1
		__asm(jump, target("___fixunssfdi__XprivateX__BB37_4_F"))
	__asm(lbl("___fixunssfdi__XprivateX__BB37_3_F"))
		i0 =  (-1)
		mstate.edx = i0
	__asm(lbl("___fixunssfdi__XprivateX__BB37_4_F"))
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___floatdidf:int = regFunc(FSM___floatdidf.start)

public final class FSM___floatdidf extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int

		var f0:Number, f1:Number

		__asm(label, lbl("___floatdidf_entry"))
	__asm(lbl("___floatdidf__XprivateX__BB38_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i2 =  (i0 >> 31)
		i1 =  __addc(i1, i2)
		i3 =  __adde(i0, i2)
		i3 =  (i3 ^ i2)
		i1 =  (i1 ^ i2)
		f0 =  (Number(uint(i3)))
		f1 =  (Number(uint(i1)))
		f0 =  (f0 * 4.29497e+09)
		f0 =  (f1 + f0)
		__asm(push(i0>-1), iftrue, target("___floatdidf__XprivateX__BB38_2_F"))
	__asm(lbl("___floatdidf__XprivateX__BB38_1_F"))
		f0 =  -f0
	__asm(lbl("___floatdidf__XprivateX__BB38_2_F"))
		mstate.st0 = f0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___floatdisf:int = regFunc(FSM___floatdisf.start)

public final class FSM___floatdisf extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int

		var f0:Number, f1:Number

		__asm(label, lbl("___floatdisf_entry"))
	__asm(lbl("___floatdisf__XprivateX__BB39_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i2 =  (i0 >> 31)
		i1 =  __addc(i1, i2)
		i3 =  __adde(i0, i2)
		i3 =  (i3 ^ i2)
		f0 =  (Number(uint(i3)))
		i1 =  (i1 ^ i2)
		f0 =  (f0 * 4.29497e+09)
		f1 =  (Number(uint(i1)))
		f0 =  f0/*fround*/
		f0 =  f0/*fextend*/
		f1 =  f1/*fextend*/
		f0 =  (f1 + f0)
		f0 =  f0/*fround*/
		__asm(push(i0>-1), iftrue, target("___floatdisf__XprivateX__BB39_2_F"))
	__asm(lbl("___floatdisf__XprivateX__BB39_1_F"))
		f0 =  f0/*fextend*/
		f0 =  -f0
		f0 =  f0/*fround*/
	__asm(lbl("___floatdisf__XprivateX__BB39_2_F"))
		mstate.st0 = f0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___floatunsdidf:int = regFunc(FSM___floatunsdidf.start)

public final class FSM___floatunsdidf extends Machine {

	public static function start():void {
		var i0:int, i1:int

		var f0:Number, f1:Number

		__asm(label, lbl("___floatunsdidf_entry"))
	__asm(lbl("___floatunsdidf__XprivateX__BB40_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		f0 =  (Number(uint(i0)))
		f1 =  (Number(uint(i1)))
		f0 =  (f0 * 4.29497e+09)
		f0 =  (f1 + f0)
		mstate.st0 = f0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___iordi3:int = regFunc(FSM___iordi3.start)

public final class FSM___iordi3 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int


		__asm(label, lbl("___iordi3_entry"))
	__asm(lbl("___iordi3__XprivateX__BB41_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i2 =  (i2 | i3)
		i0 =  (i0 | i1)
		mstate.edx = i2
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___lshldi3:int = regFunc(FSM___lshldi3.start)

public final class FSM___lshldi3 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int


		__asm(label, lbl("___lshldi3_entry"))
	__asm(lbl("___lshldi3__XprivateX__BB42_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i4 =  ((uint(i0)<uint(32)) ? 1 : 0)
		i5 =  ((i1==0) ? 1 : 0)
		i4 =  ((i5!=0) ? i4 : 0)
		__asm(push(i4!=0), iftrue, target("___lshldi3__XprivateX__BB42_4_F"))
	__asm(lbl("___lshldi3__XprivateX__BB42_1_F"))
		i3 =  ((uint(i0)<uint(64)) ? 1 : 0)
		i1 =  ((i1==0) ? 1 : 0)
		i1 =  ((i1!=0) ? i3 : 0)
		__asm(push(i1!=0), iftrue, target("___lshldi3__XprivateX__BB42_3_F"))
	__asm(lbl("___lshldi3__XprivateX__BB42_2_F"))
		i0 =  (0)
		i1 = i0
		__asm(jump, target("___lshldi3__XprivateX__BB42_7_F"))
	__asm(lbl("___lshldi3__XprivateX__BB42_3_F"))
		i1 =  (0)
		i0 =  (i0 + -32)
		i0 =  (i2 << i0)
		mstate.edx = i0
		mstate.eax = i1
		__asm(jump, target("___lshldi3__XprivateX__BB42_8_F"))
	__asm(lbl("___lshldi3__XprivateX__BB42_4_F"))
		i1 =  (i0 | i1)
		__asm(push(i1!=0), iftrue, target("___lshldi3__XprivateX__BB42_6_F"))
	__asm(lbl("___lshldi3__XprivateX__BB42_5_F"))
		i0 = i2
		i1 = i3
		__asm(jump, target("___lshldi3__XprivateX__BB42_7_F"))
	__asm(lbl("___lshldi3__XprivateX__BB42_6_F"))
		i1 =  (32 - i0)
		i1 =  (i2 >>> i1)
		i3 =  (i3 << i0)
		i0 =  (i2 << i0)
		i1 =  (i1 | i3)
	__asm(lbl("___lshldi3__XprivateX__BB42_7_F"))
		mstate.edx = i1
		mstate.eax = i0
	__asm(lbl("___lshldi3__XprivateX__BB42_8_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___lshrdi3:int = regFunc(FSM___lshrdi3.start)

public final class FSM___lshrdi3 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int


		__asm(label, lbl("___lshrdi3_entry"))
	__asm(lbl("___lshrdi3__XprivateX__BB43_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i4 =  ((uint(i0)<uint(32)) ? 1 : 0)
		i5 =  ((i1==0) ? 1 : 0)
		i4 =  ((i5!=0) ? i4 : 0)
		__asm(push(i4!=0), iftrue, target("___lshrdi3__XprivateX__BB43_3_F"))
	__asm(lbl("___lshrdi3__XprivateX__BB43_1_F"))
		i2 =  ((uint(i0)<uint(64)) ? 1 : 0)
		i1 =  ((i1==0) ? 1 : 0)
		i1 =  ((i1!=0) ? i2 : 0)
		__asm(push(i1!=0), iftrue, target("___lshrdi3__XprivateX__BB43_6_F"))
	__asm(lbl("___lshrdi3__XprivateX__BB43_2_F"))
		i0 =  (0)
		i1 = i0
		__asm(jump, target("___lshrdi3__XprivateX__BB43_7_F"))
	__asm(lbl("___lshrdi3__XprivateX__BB43_3_F"))
		i1 =  (i0 | i1)
		__asm(push(i1!=0), iftrue, target("___lshrdi3__XprivateX__BB43_5_F"))
	__asm(lbl("___lshrdi3__XprivateX__BB43_4_F"))
		i0 = i2
		i1 = i3
		__asm(jump, target("___lshrdi3__XprivateX__BB43_7_F"))
	__asm(lbl("___lshrdi3__XprivateX__BB43_5_F"))
		i1 =  (32 - i0)
		i1 =  (i3 << i1)
		i2 =  (i2 >>> i0)
		i0 =  (i3 >>> i0)
		i1 =  (i1 | i2)
		mstate.edx = i0
		mstate.eax = i1
		__asm(jump, target("___lshrdi3__XprivateX__BB43_8_F"))
	__asm(lbl("___lshrdi3__XprivateX__BB43_6_F"))
		i1 =  (0)
		i0 =  (i0 + -32)
		i0 =  (i3 >>> i0)
		__asm(jump, target("___lshrdi3__XprivateX__BB43_7_F"))
	__asm(lbl("___lshrdi3__XprivateX__BB43_7_F"))
		mstate.edx = i1
		mstate.eax = i0
	__asm(lbl("___lshrdi3__XprivateX__BB43_8_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___moddi3:int = regFunc(FSM___moddi3.start)

public final class FSM___moddi3 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int


		__asm(label, lbl("___moddi3_entry"))
	__asm(lbl("___moddi3__XprivateX__BB44_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 8
		i0 =  ((mstate.ebp+-8))
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i4 =  (i1 >> 31)
		i5 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i6 =  (i2 >> 31)
		i3 =  __addc(i3, i4)
		i7 =  __adde(i1, i4)
		i5 =  __addc(i5, i6)
		i2 =  __adde(i2, i6)
		mstate.esp -= 20
		i2 =  (i2 ^ i6)
		i5 =  (i5 ^ i6)
		i6 =  (i7 ^ i4)
		i3 =  (i3 ^ i4)
		__asm(push(i3), push(mstate.esp), op(0x3c))
		__asm(push(i6), push((mstate.esp+4)), op(0x3c))
		__asm(push(i5), push((mstate.esp+8)), op(0x3c))
		__asm(push(i2), push((mstate.esp+12)), op(0x3c))
		__asm(push(i0), push((mstate.esp+16)), op(0x3c))
		mstate.esp -= 4;FSM___qdivrem.start()
	__asm(lbl("___moddi3_state1"))
		i0 = mstate.eax
		i0 = mstate.edx
		mstate.esp += 20
		i0 =  ((__xasm<int>(push((mstate.ebp+-8)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i1>-1), iftrue, target("___moddi3__XprivateX__BB44_2_F"))
	__asm(lbl("___moddi3__XprivateX__BB44_1_F"))
		i1 =  (0)
		i0 =  __subc(i1, i0)
		i2 =  __sube(i1, i2)
	__asm(lbl("___moddi3__XprivateX__BB44_2_F"))
		mstate.edx = i2
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___lmulq:int = regFunc(FSM___lmulq.start)

public final class FSM___lmulq extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
		var i8:int, i9:int


		__asm(label, lbl("___lmulq_entry"))
	__asm(lbl("___lmulq__XprivateX__BB45_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i2 =  (i1 & 65535)
		i3 =  (i0 & 65535)
		i4 =  (i2 * i3)
		i5 =  (i1 >>> 16)
		i6 =  (i0 >>> 16)
		__asm(push(uint(i1)>uint(65535)), iftrue, target("___lmulq__XprivateX__BB45_4_F"))
	__asm(lbl("___lmulq__XprivateX__BB45_1_F"))
		__asm(push(uint(i0)>uint(65535)), iftrue, target("___lmulq__XprivateX__BB45_4_F"))
	__asm(lbl("___lmulq__XprivateX__BB45_2_F"))
		i2 =  (0)
		mstate.edx = i2
		mstate.eax = i4
	__asm(jump, target("___lmulq__XprivateX__BB45_3_F"), lbl("___lmulq__XprivateX__BB45_3_B"), label, lbl("___lmulq__XprivateX__BB45_3_F")); 
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	__asm(lbl("___lmulq__XprivateX__BB45_4_F"))
		i0 =  ((uint(i6)<uint(i3)) ? i3 : i6)
		i1 =  ((uint(i6)<uint(i3)) ? i6 : i3)
		i7 =  ((uint(i2)<uint(i5)) ? i5 : i2)
		i8 =  ((uint(i2)<uint(i5)) ? i2 : i5)
		i9 =  (i5 * i6)
		i7 =  (i7 - i8)
		i0 =  (i0 - i1)
		i1 =  (i9 >>> 16)
		i0 =  (i7 * i0)
		i3 =  ((uint(i6)<uint(i3)) ? 1 : 0)
		i2 =  ((uint(i2)<uint(i5)) ? 1 : 0)
		i2 =  (i2 ^ i3)
		i3 =  (i0 << 16)
		i5 =  (i9 << 16)
		i1 =  (i1 + i9)
		i2 =  (i2 ^ 1)
		i2 =  (i2 & 1)
		__asm(push(i2!=0), iftrue, target("___lmulq__XprivateX__BB45_6_F"))
	__asm(lbl("___lmulq__XprivateX__BB45_5_F"))
		i3 =  (i5 - i3)
		i5 =  ((uint(i3)>uint(i5)) ? 1 : 0)
		i0 =  (i0 >>> 16)
		i5 =  (i5 & 1)
		i0 =  (i1 - i0)
		i0 =  (i0 - i5)
		i1 = i3
		__asm(jump, target("___lmulq__XprivateX__BB45_7_F"))
	__asm(lbl("___lmulq__XprivateX__BB45_6_F"))
		i2 =  (i3 + i5)
		i3 =  ((uint(i2)<uint(i5)) ? 1 : 0)
		i0 =  (i0 >>> 16)
		i3 =  (i3 & 1)
		i0 =  (i0 + i1)
		i0 =  (i0 + i3)
		i1 = i2
	__asm(lbl("___lmulq__XprivateX__BB45_7_F"))
		i2 =  (i4 << 16)
		i2 =  (i1 + i2)
		i1 =  ((uint(i2)<uint(i1)) ? 1 : 0)
		i2 =  (i2 + i4)
		i3 =  (i4 >>> 16)
		i4 =  ((uint(i2)<uint(i4)) ? 1 : 0)
		i1 =  (i1 & 1)
		i0 =  (i0 + i3)
		i3 =  (i4 & 1)
		i0 =  (i0 + i1)
		i0 =  (i0 + i3)
		mstate.edx = i0
		mstate.eax = i2
		__asm(jump, target("___lmulq__XprivateX__BB45_3_B"))
	}
}



// Sync
public const ___muldi3:int = regFunc(FSM___muldi3.start)

public final class FSM___muldi3 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
		var i8:int, i9:int, i10:int, i11:int


		__asm(label, lbl("___muldi3_entry"))
	__asm(lbl("___muldi3__XprivateX__BB46_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  (0)
		i0 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i3 =  (i0 >> 31)
		i4 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i5 =  (i1 >> 31)
		i2 =  __addc(i2, i3)
		i6 =  __adde(i0, i3)
		i4 =  __addc(i4, i5)
		i7 =  __adde(i1, i5)
		i0 =  (i0 >>> 31)
		i6 =  (i6 ^ i3)
		i2 =  (i2 ^ i3)
		i1 =  (i1 >>> 31)
		i3 =  (i7 ^ i5)
		i4 =  (i4 ^ i5)
		i5 = i6
		i7 = i6
		__asm(push(i6!=0), iftrue, target("___muldi3__XprivateX__BB46_4_F"))
	__asm(lbl("___muldi3__XprivateX__BB46_1_F"))
		__asm(push(i3!=0), iftrue, target("___muldi3__XprivateX__BB46_4_F"))
	__asm(lbl("___muldi3__XprivateX__BB46_2_F"))
		mstate.esp -= 8
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i4), push((mstate.esp+4)), op(0x3c))
		mstate.esp -= 4;FSM___lmulq.start()
	__asm(lbl("___muldi3_state1"))
		i2 = mstate.eax
		i3 = mstate.edx
		mstate.esp += 8
		__asm(push(i0==i1), iftrue, target("___muldi3__XprivateX__BB46_7_F"))
	__asm(lbl("___muldi3__XprivateX__BB46_3_F"))
		__asm(jump, target("___muldi3__XprivateX__BB46_6_F"))
	__asm(lbl("___muldi3__XprivateX__BB46_4_F"))
		i6 =  ((uint(i4)<uint(i3)) ? i4 : i3)
		i8 =  ((uint(i4)<uint(i3)) ? i3 : i4)
		i9 =  ((uint(i5)<uint(i2)) ? i7 : i2)
		i7 =  ((uint(i5)<uint(i2)) ? i2 : i7)
		i10 =  ((uint(i4)<uint(i3)) ? 1 : 0)
		i11 =  ((uint(i5)<uint(i2)) ? 1 : 0)
		i6 =  (i8 - i6)
		i7 =  (i7 - i9)
		mstate.esp -= 8
		i8 =  (i10 ^ i11)
		i6 =  (i6 * i7)
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i4), push((mstate.esp+4)), op(0x3c))
		i2 =  (i8 & 1)
		i4 =  (0 - i6)
		i2 =  ((i2!=0) ? i4 : i6)
		i3 =  (i3 * i5)
		mstate.esp -= 4;FSM___lmulq.start()
	__asm(lbl("___muldi3_state2"))
		i4 = mstate.eax
		i5 = mstate.edx
		i2 =  (i2 + i3)
		i2 =  (i2 + i4)
		mstate.esp += 8
		i3 =  (i2 + i5)
		__asm(push(i0==i1), iftrue, target("___muldi3__XprivateX__BB46_10_F"))
	__asm(lbl("___muldi3__XprivateX__BB46_5_F"))
		i2 = i4
		__asm(jump, target("___muldi3__XprivateX__BB46_6_F"))
	__asm(lbl("___muldi3__XprivateX__BB46_6_F"))
		i0 =  (0)
		i2 =  __subc(i0, i2)
		i3 =  __sube(i0, i3)
		mstate.edx = i3
		mstate.eax = i2
		__asm(jump, target("___muldi3__XprivateX__BB46_9_F"))
	__asm(lbl("___muldi3__XprivateX__BB46_7_F"))
		__asm(jump, target("___muldi3__XprivateX__BB46_8_F"))
	__asm(jump, target("___muldi3__XprivateX__BB46_8_F"), lbl("___muldi3__XprivateX__BB46_8_B"), label, lbl("___muldi3__XprivateX__BB46_8_F")); 
		i0 = i2
		i1 = i3
		mstate.edx = i1
		mstate.eax = i0
	__asm(lbl("___muldi3__XprivateX__BB46_9_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	__asm(lbl("___muldi3__XprivateX__BB46_10_F"))
		i2 = i4
		__asm(jump, target("___muldi3__XprivateX__BB46_8_B"))
	}
}



// Sync
public const ___negdi2:int = regFunc(FSM___negdi2.start)

public final class FSM___negdi2 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int


		__asm(label, lbl("___negdi2_entry"))
	__asm(lbl("___negdi2__XprivateX__BB47_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  (0)
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i3 =  ((i1!=0) ? 1 : 0)
		i2 =  __subc(i0, i2)
		i3 =  (i3 & 1)
		i0 =  __subc(i0, i1)
		i1 =  __subc(i2, i3)
		mstate.edx = i1
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___one_cmpldi2:int = regFunc(FSM___one_cmpldi2.start)

public final class FSM___one_cmpldi2 extends Machine {

	public static function start():void {
		var i0:int, i1:int


		__asm(label, lbl("___one_cmpldi2_entry"))
	__asm(lbl("___one_cmpldi2__XprivateX__BB48_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i1 =  (i1 ^ -1)
		i0 =  (i0 ^ -1)
		mstate.edx = i1
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___subdi3:int = regFunc(FSM___subdi3.start)

public final class FSM___subdi3 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int


		__asm(label, lbl("___subdi3_entry"))
	__asm(lbl("___subdi3__XprivateX__BB49_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i1 =  (i0 - i1)
		i0 =  ((uint(i1)>uint(i0)) ? 1 : 0)
		i2 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i2 =  __subc(i2, i3)
		i0 =  (i0 & 1)
		i0 =  __subc(i2, i0)
		mstate.edx = i0
		mstate.eax = i1
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___ucmpdi2:int = regFunc(FSM___ucmpdi2.start)

public final class FSM___ucmpdi2 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int


		__asm(label, lbl("___ucmpdi2_entry"))
	__asm(lbl("___ucmpdi2__XprivateX__BB50_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i4 = i1
		i4 = i0
		__asm(push(uint(i0)>=uint(i1)), iftrue, target("___ucmpdi2__XprivateX__BB50_2_F"))
	__asm(jump, target("___ucmpdi2__XprivateX__BB50_1_F"), lbl("___ucmpdi2__XprivateX__BB50_1_B"), label, lbl("___ucmpdi2__XprivateX__BB50_1_F")); 
		i0 =  (0)
		__asm(jump, target("___ucmpdi2__XprivateX__BB50_6_F"))
	__asm(lbl("___ucmpdi2__XprivateX__BB50_2_F"))
		__asm(push(uint(i0)<=uint(i1)), iftrue, target("___ucmpdi2__XprivateX__BB50_4_F"))
	__asm(lbl("___ucmpdi2__XprivateX__BB50_3_F"))
		i0 =  (2)
		__asm(jump, target("___ucmpdi2__XprivateX__BB50_6_F"))
	__asm(lbl("___ucmpdi2__XprivateX__BB50_4_F"))
		i0 = i3
		i1 = i2
		__asm(push(uint(i2)<uint(i3)), iftrue, target("___ucmpdi2__XprivateX__BB50_1_B"))
	__asm(lbl("___ucmpdi2__XprivateX__BB50_5_F"))
		i0 =  ((uint(i1)>uint(i0)) ? 2 : 1)
	__asm(lbl("___ucmpdi2__XprivateX__BB50_6_F"))
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___udivdi3:int = regFunc(FSM___udivdi3.start)

public final class FSM___udivdi3 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int


		__asm(label, lbl("___udivdi3_entry"))
	__asm(lbl("___udivdi3__XprivateX__BB51_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  (0)
		mstate.esp -= 20
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i4 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		__asm(push(i1), push(mstate.esp), op(0x3c))
		__asm(push(i2), push((mstate.esp+4)), op(0x3c))
		__asm(push(i3), push((mstate.esp+8)), op(0x3c))
		__asm(push(i4), push((mstate.esp+12)), op(0x3c))
		__asm(push(i0), push((mstate.esp+16)), op(0x3c))
		mstate.esp -= 4;FSM___qdivrem.start()
	__asm(lbl("___udivdi3_state1"))
		i0 = mstate.eax
		i1 = mstate.edx
		mstate.esp += 20
		mstate.edx = i1
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___umoddi3:int = regFunc(FSM___umoddi3.start)

public final class FSM___umoddi3 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int


		__asm(label, lbl("___umoddi3_entry"))
	__asm(lbl("___umoddi3__XprivateX__BB52_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 8
		i0 =  ((mstate.ebp+-8))
		mstate.esp -= 20
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i4 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		__asm(push(i1), push(mstate.esp), op(0x3c))
		__asm(push(i2), push((mstate.esp+4)), op(0x3c))
		__asm(push(i3), push((mstate.esp+8)), op(0x3c))
		__asm(push(i4), push((mstate.esp+12)), op(0x3c))
		__asm(push(i0), push((mstate.esp+16)), op(0x3c))
		mstate.esp -= 4;FSM___qdivrem.start()
	__asm(lbl("___umoddi3_state1"))
		i0 = mstate.eax
		i0 = mstate.edx
		mstate.esp += 20
		i0 =  ((__xasm<int>(push((mstate.ebp+-8)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		mstate.edx = i1
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const ___xordi3:int = regFunc(FSM___xordi3.start)

public final class FSM___xordi3 extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int


		__asm(label, lbl("___xordi3_entry"))
	__asm(lbl("___xordi3__XprivateX__BB53_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i2 =  (i2 ^ i3)
		i0 =  (i0 ^ i1)
		mstate.edx = i2
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Async
public const ___vfprintf:int = regFunc(FSM___vfprintf.start)

public final class FSM___vfprintf extends Machine {

	public static function start():void {
			var result:FSM___vfprintf = new FSM___vfprintf
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
	public var i8:int, i9:int, i10:int, i11:int, i12:int, i13:int, i14:int, i15:int
	public var i16:int, i17:int, i18:int, i19:int, i20:int, i21:int, i22:int, i23:int
	public var i24:int, i25:int, i26:int, i27:int, i28:int, i29:int, i30:int, i31:int
	public static const intRegCount:int = 32
	public var f0:Number, f1:Number, f2:Number, f3:Number, f4:Number

	public static const NumberRegCount:int = 5
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___vfprintf_entry"))
		__asm(push(state), switchjump(
			"___vfprintf_errState",
			"___vfprintf_state0",
			"___vfprintf_state1",
			"___vfprintf_state2",
			"___vfprintf_state3",
			"___vfprintf_state4",
			"___vfprintf_state5",
			"___vfprintf_state6",
			"___vfprintf_state7",
			"___vfprintf_state8",
			"___vfprintf_state9",
			"___vfprintf_state10",
			"___vfprintf_state11",
			"___vfprintf_state12",
			"___vfprintf_state13",
			"___vfprintf_state14",
			"___vfprintf_state15",
			"___vfprintf_state16",
			"___vfprintf_state17",
			"___vfprintf_state18",
			"___vfprintf_state19",
			"___vfprintf_state20",
			"___vfprintf_state21",
			"___vfprintf_state22",
			"___vfprintf_state23",
			"___vfprintf_state24",
			"___vfprintf_state25",
			"___vfprintf_state26",
			"___vfprintf_state27",
			"___vfprintf_state28",
			"___vfprintf_state29",
			"___vfprintf_state30",
			"___vfprintf_state31",
			"___vfprintf_state32",
			"___vfprintf_state33",
			"___vfprintf_state34",
			"___vfprintf_state35",
			"___vfprintf_state36",
			"___vfprintf_state37",
			"___vfprintf_state38",
			"___vfprintf_state39",
			"___vfprintf_state40",
			"___vfprintf_state41",
			"___vfprintf_state42",
			"___vfprintf_state43",
			"___vfprintf_state44",
			"___vfprintf_state45",
			"___vfprintf_state46",
			"___vfprintf_state47",
			"___vfprintf_state48",
			"___vfprintf_state49",
			"___vfprintf_state50",
			"___vfprintf_state51",
			"___vfprintf_state52",
			"___vfprintf_state53",
			"___vfprintf_state54",
			"___vfprintf_state55",
			"___vfprintf_state56",
			"___vfprintf_state57",
			"___vfprintf_state58",
			"___vfprintf_state59",
			"___vfprintf_state60",
			"___vfprintf_state61",
			"___vfprintf_state62",
			"___vfprintf_state63",
			"___vfprintf_state64",
			"___vfprintf_state65",
			"___vfprintf_state66",
			"___vfprintf_state67",
			"___vfprintf_state68",
			"___vfprintf_state69",
			"___vfprintf_state70",
			"___vfprintf_state71",
			"___vfprintf_state72",
			"___vfprintf_state73",
			"___vfprintf_state74",
			"___vfprintf_state75",
			"___vfprintf_state76",
			"___vfprintf_state77",
			"___vfprintf_state78",
			"___vfprintf_state79",
			"___vfprintf_state80",
			"___vfprintf_state81",
			"___vfprintf_state82",
			"___vfprintf_state83",
			"___vfprintf_state84",
			"___vfprintf_state85",
			"___vfprintf_state86",
			"___vfprintf_state87",
			"___vfprintf_state88",
			"___vfprintf_state89",
			"___vfprintf_state90",
			"___vfprintf_state91",
			"___vfprintf_state92",
			"___vfprintf_state93",
			"___vfprintf_state94",
			"___vfprintf_state95",
			"___vfprintf_state96",
			"___vfprintf_state97",
			"___vfprintf_state98",
			"___vfprintf_state99",
			"___vfprintf_state100",
			"___vfprintf_state101",
			"___vfprintf_state102",
			"___vfprintf_state103",
			"___vfprintf_state104",
			"___vfprintf_state105",
			"___vfprintf_state106",
			"___vfprintf_state107",
			"___vfprintf_state108",
			"___vfprintf_state109",
			"___vfprintf_state110",
			"___vfprintf_state111",
			"___vfprintf_state112",
			"___vfprintf_state113",
			"___vfprintf_state114",
			"___vfprintf_state115",
			"___vfprintf_state116"))
	__asm(lbl("___vfprintf_state0"))
	__asm(lbl("___vfprintf__XprivateX__BB54_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 2604
		i0 =  (0)
		__asm(push(i0), push((mstate.ebp+-1761)), op(0x3a))
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		__asm(push(i1), push((mstate.ebp+-2241)), op(0x3c))
		i1 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i2 =  ((__xasm<int>(push(___mlocale_changed_2E_b), op(0x35))))
		i3 =  ((mstate.ebp+-1344))
		i4 =  ((mstate.ebp+-208))
		__asm(push(i4), push((mstate.ebp+-2214)), op(0x3c))
		i4 =  ((mstate.ebp+-1752))
		__asm(push(i4), push((mstate.ebp+-2223)), op(0x3c))
		i4 =  ((mstate.ebp+-1664))
		__asm(push(i4), push((mstate.ebp+-2043)), op(0x3c))
		i4 =  ((mstate.ebp+-224))
		__asm(push(i4), push((mstate.ebp+-2061)), op(0x3c))
		__asm(push(i2!=0), iftrue, target("___vfprintf__XprivateX__BB54_2_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1_F"))
		i2 =  (1)
		__asm(push(i2), push(___mlocale_changed_2E_b), op(0x3a))
	__asm(lbl("___vfprintf__XprivateX__BB54_2_F"))
		i2 =  ((__xasm<int>(push(___nlocale_changed_2E_b), op(0x35))))
		__asm(push(i2!=0), iftrue, target("___vfprintf__XprivateX__BB54_4_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_3_F"))
		i2 =  (1)
		__asm(push(i2), push(_ret_2E_1494_2E_0_2E_b), op(0x3a))
		__asm(push(i2), push(_ret_2E_1494_2E_2_2E_b), op(0x3a))
		__asm(push(i2), push(___nlocale_changed_2E_b), op(0x3a))
	__asm(lbl("___vfprintf__XprivateX__BB54_4_F"))
		i2 =  (__2E_str20159)
		i4 =  ((__xasm<int>(push(_ret_2E_1494_2E_0_2E_b), op(0x35))))
		i5 =  ((__xasm<int>(push((i0+12)), op(0x36))))
		i2 =  ((i4!=0) ? i2 : 0)
		__asm(push(i2), push((mstate.ebp+-2079)), op(0x3c))
		i2 =  (i0 + 12)
		__asm(push(i2), push((mstate.ebp+-1980)), op(0x3c))
		i2 =  (i5 & 8)
		__asm(push(i2==0), iftrue, target("___vfprintf__XprivateX__BB54_7_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_5_F"))
		i2 =  ((__xasm<int>(push((i0+16)), op(0x37))))
		__asm(push(i2!=0), iftrue, target("___vfprintf__XprivateX__BB54_9_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_6_F"))
		i2 =  (i5 & 512)
		__asm(push(i2!=0), iftrue, target("___vfprintf__XprivateX__BB54_9_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_7_F"))
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM___swsetup.start()
		return
	__asm(lbl("___vfprintf_state1"))
		i2 = mstate.eax
		mstate.esp += 4
		__asm(push(i2==0), iftrue, target("___vfprintf__XprivateX__BB54_9_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_8_F"))
		i0 =  (-1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1507_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_9_F"))
		i2 =  ((__xasm<int>(push((mstate.ebp+-1980)), op(0x37))))
		i2 =  ((__xasm<int>(push(i2), op(0x36))))
		i4 =  (i2 & 26)
		__asm(push(i4!=10), iftrue, target("___vfprintf__XprivateX__BB54_18_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_10_F"))
		i4 =  ((__xasm<int>(push((i0+14)), op(0x36))))
		i5 =  (i4 << 16)
		i5 =  (i5 >> 16)
		__asm(push(i5<0), iftrue, target("___vfprintf__XprivateX__BB54_18_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_11_F"))
		i5 =  (1024)
		i2 =  (i2 & -3)
		__asm(push(i2), push((mstate.ebp+-308)), op(0x3b))
		__asm(push(i4), push((mstate.ebp+-306)), op(0x3b))
		i2 =  ((__xasm<int>(push((i0+28)), op(0x37))))
		__asm(push(i2), push((mstate.ebp+-292)), op(0x3c))
		i2 =  ((__xasm<int>(push((i0+44)), op(0x37))))
		__asm(push(i2), push((mstate.ebp+-276)), op(0x3c))
		i0 =  ((__xasm<int>(push((i0+56)), op(0x37))))
		__asm(push(i0), push((mstate.ebp+-264)), op(0x3c))
		__asm(push(i3), push((mstate.ebp+-320)), op(0x3c))
		__asm(push(i3), push((mstate.ebp+-304)), op(0x3c))
		__asm(push(i5), push((mstate.ebp+-312)), op(0x3c))
		__asm(push(i5), push((mstate.ebp+-300)), op(0x3c))
		i0 =  (0)
		__asm(push(i0), push((mstate.ebp+-296)), op(0x3c))
		i0 =  ((mstate.ebp+-320))
		mstate.esp -= 12
		__asm(push(i0), push(mstate.esp), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2241)), op(0x37))))
		__asm(push(i2), push((mstate.esp+4)), op(0x3c))
		__asm(push(i1), push((mstate.esp+8)), op(0x3c))
		state = 2
		mstate.esp -= 4;FSM___vfprintf.start()
		return
	__asm(lbl("___vfprintf_state2"))
		i1 = mstate.eax
		mstate.esp += 12
		i0 =  (i0 + 12)
		__asm(push(i1>-1), iftrue, target("___vfprintf__XprivateX__BB54_13_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_12_F"), lbl("___vfprintf__XprivateX__BB54_12_B"), label, lbl("___vfprintf__XprivateX__BB54_12_F")); 
		__asm(jump, target("___vfprintf__XprivateX__BB54_15_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_13_F"))
		i2 =  ((mstate.ebp+-320))
		mstate.esp -= 4
		__asm(push(i2), push(mstate.esp), op(0x3c))
		state = 3
		mstate.esp -= 4;FSM___fflush.start()
		return
	__asm(lbl("___vfprintf_state3"))
		i2 = mstate.eax
		mstate.esp += 4
		__asm(push(i2==0), iftrue, target("___vfprintf__XprivateX__BB54_12_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_14_F"))
		i1 =  (-1)
	__asm(lbl("___vfprintf__XprivateX__BB54_15_F"))
		i0 =  ((__xasm<int>(push(i0), op(0x36))))
		i0 =  (i0 & 64)
		__asm(push(i0!=0), iftrue, target("___vfprintf__XprivateX__BB54_17_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_16_F"))
		i0 = i1
		__asm(jump, target("___vfprintf__XprivateX__BB54_1507_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_17_F"))
		i0 =  ((__xasm<int>(push((mstate.ebp+-1980)), op(0x37))))
		i0 =  ((__xasm<int>(push(i0), op(0x36))))
		i0 =  (i0 | 64)
		i2 =  ((__xasm<int>(push((mstate.ebp+-1980)), op(0x37))))
		__asm(push(i0), push(i2), op(0x3b))
		mstate.eax = i1
		__asm(jump, target("___vfprintf__XprivateX__BB54_1508_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_18_F"))
		i2 =  (0)
		__asm(push(i2), push((mstate.ebp+-1556)), op(0x3c))
		__asm(push(i1), push((mstate.ebp+-1768)), op(0x3c))
		__asm(push(i1), push((mstate.ebp+-1476)), op(0x3c))
		i3 =  ((mstate.ebp+-1728))
		__asm(push(i3), push((mstate.ebp+-1744)), op(0x3c))
		__asm(push(i2), push((mstate.ebp+-1736)), op(0x3c))
		i4 =  ((mstate.ebp+-1744))
		__asm(push(i2), push((mstate.ebp+-1740)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2241)), op(0x37))))
		i2 =  ((__xasm<int>(push(i2), op(0x35))))
		i5 =  (i4 + 4)
		i4 =  (i4 + 8)
		i6 =  ((mstate.ebp+-1476))
		__asm(push(i2==0), iftrue, target("___vfprintf__XprivateX__BB54_20_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_19_F"))
		i6 =  (i2 & 255)
		__asm(push(i6!=37), iftrue, target("___vfprintf__XprivateX__BB54_21_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_20_F"))
		i6 =  (1)
		//IMPLICIT_DEF i7 = 
		i8 =  (0)
		i9 = i8
		i10 = i7
		i11 = i7
		i12 = i7
		i13 = i7
		i14 = i8
		i15 = i7
		i16 = i7
		i17 = i7
		i18 = i8
		i19 = i7
		i20 = i7
		i21 = i7
		i22 =  ((__xasm<int>(push((mstate.ebp+-2241)), op(0x37))))
		i23 = i3
		i24 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_31_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_21_F"))
		i2 =  (1)
		//IMPLICIT_DEF i6 = 
		i7 =  (0)
		i8 = i6
		i9 = i6
		i10 = i6
		i11 = i6
		i12 = i7
		i13 =  ((__xasm<int>(push((mstate.ebp+-2241)), op(0x37))))
		i14 = i3
		__asm(push(i14), push((mstate.ebp+-2277)), op(0x3c))
		i14 = i13
		i15 = i6
		i16 = i12
		i17 = i6
		i18 = i6
		i19 = i6
		i20 = i12
		i21 = i6
		i22 = i6
		__asm(jump, target("___vfprintf__XprivateX__BB54_27_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_22_B"), label)
		i6 =  (0)
		__asm(push(i6), push(i5), op(0x3c))
		i10 = i3
		i6 = i26
		i14 = i1
		i16 = i13
		i24 = i17
		i13 = i18
		i18 = i19
		i17 = i7
		i12 = i2
		i7 =  ((__xasm<int>(push((mstate.ebp+-2547)), op(0x37))))
		i20 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2556)), op(0x37))))
		i19 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2565)), op(0x37))))
		i8 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2583)), op(0x37))))
		i22 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2574)), op(0x37))))
		i2 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2592)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+-2601)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_23_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_23_F"), lbl("___vfprintf__XprivateX__BB54_23_B"), label, lbl("___vfprintf__XprivateX__BB54_23_F")); 
		i25 = i14
		i26 = i16
		i27 = i13
		i28 = i18
		i29 = i17
		i17 = i20
		i18 = i19
		i19 = i22
		i16 = i23
		i20 = i7
		i7 =  ((__xasm<int>(push(i15), op(0x35))))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_25_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_24_F"))
		i13 =  (i7 & 255)
		__asm(push(i13!=37), iftrue, target("___vfprintf__XprivateX__BB54_26_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_25_F"))
		i9 =  (i9 + i11)
		i11 = i25
		i13 = i26
		i14 = i24
		i15 = i27
		i22 = i28
		i24 = i29
		i23 = i9
		__asm(jump, target("___vfprintf__XprivateX__BB54_32_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_26_F"))
		i9 =  (i9 + i11)
		i13 = i9
		i7 = i10
		__asm(push(i7), push((mstate.ebp+-2277)), op(0x3c))
		i7 = i6
		i14 = i9
		i15 = i20
		i11 = i19
		i10 = i18
		i9 = i8
		i18 = i12
		i19 = i29
		i20 = i21
		i21 = i28
		i22 = i27
		i6 = i24
		i8 = i26
		i12 = i25
	__asm(lbl("___vfprintf__XprivateX__BB54_27_F"))
		i24 = i13
		i13 =  ((__xasm<int>(push((mstate.ebp+-2277)), op(0x37))))
		i23 = i13
		i25 = i7
		i7 = i14
		i26 = i15
		i27 = i16
		i28 = i11
		i11 = i17
		i29 = i18
		i18 = i20
		i17 = i21
		i16 = i22
	__asm(jump, target("___vfprintf__XprivateX__BB54_28_F"), lbl("___vfprintf__XprivateX__BB54_28_B"), label, lbl("___vfprintf__XprivateX__BB54_28_F")); 
		i30 =  ((__xasm<int>(push((i7+1)), op(0x35))))
		i22 =  (i7 + 1)
		i7 = i22
		__asm(push(i30==0), iftrue, target("___vfprintf__XprivateX__BB54_30_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_29_F"))
		i13 =  (i30 & 255)
		__asm(push(i13!=37), iftrue, target("___vfprintf__XprivateX__BB54_1509_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_30_F"))
		i14 = i12
		i13 = i8
		i15 = i6
		i20 = i29
		i21 = i11
		i12 = i10
		i11 = i9
		i10 = i28
		i6 = i2
		i8 = i27
		i7 = i26
		i2 = i30
		i9 = i25
		__asm(jump, target("___vfprintf__XprivateX__BB54_31_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_31_F"))
		i25 = i21
		i26 = i12
		i27 = i11
		i28 = i8
		i29 = i22
		i30 = i2
		i31 = i23
		i2 = i24
		__asm(push(i2), push((mstate.ebp+-2286)), op(0x3c))
		i2 =  ((mstate.ebp+-1752))
		__asm(push(i2), push((mstate.ebp+-2178)), op(0x3c))
		i2 =  ((mstate.ebp+-1664))
		__asm(push(i2), push((mstate.ebp+-2205)), op(0x3c))
		i2 =  ((mstate.ebp+-32))
		__asm(push(i2), push((mstate.ebp+-2034)), op(0x3c))
		i2 =  ((mstate.ebp+-48))
		__asm(push(i2), push((mstate.ebp+-2268)), op(0x3c))
		i2 =  ((mstate.ebp+-16))
		__asm(push(i2), push((mstate.ebp+-2160)), op(0x3c))
		i2 =  ((mstate.ebp+-192))
		__asm(push(i2), push((mstate.ebp+-2106)), op(0x3c))
		i2 =  ((mstate.ebp+-1558))
		__asm(push(i2), push((mstate.ebp+-2115)), op(0x3c))
		i2 =  ((mstate.ebp+-64))
		__asm(push(i2), push((mstate.ebp+-2232)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2106)), op(0x37))))
		i2 =  (i2 + 4)
		__asm(push(i2), push((mstate.ebp+-1989)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2160)), op(0x37))))
		i2 =  (i2 + 4)
		__asm(push(i2), push((mstate.ebp+-1998)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2034)), op(0x37))))
		i2 =  (i2 + 4)
		__asm(push(i2), push((mstate.ebp+-2007)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2034)), op(0x37))))
		i2 =  (i2 + 8)
		__asm(push(i2), push((mstate.ebp+-2016)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2268)), op(0x37))))
		i2 =  (i2 + 4)
		__asm(push(i2), push((mstate.ebp+-2250)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2268)), op(0x37))))
		i2 =  (i2 + 8)
		__asm(push(i2), push((mstate.ebp+-2025)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2178)), op(0x37))))
		i2 =  (i2 + 3)
		__asm(push(i2), push((mstate.ebp+-2052)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2205)), op(0x37))))
		i2 =  (i2 + 1)
		__asm(push(i2), push((mstate.ebp+-2070)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2205)), op(0x37))))
		i2 =  (i2 + 99)
		__asm(push(i2), push((mstate.ebp+-2133)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2205)), op(0x37))))
		i2 =  (i2 + 100)
		__asm(push(i2), push((mstate.ebp+-2151)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2178)), op(0x37))))
		i2 =  (i2 + 2)
		__asm(push(i2), push((mstate.ebp+-2187)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2178)), op(0x37))))
		i2 =  (i2 + 1)
		__asm(push(i2), push((mstate.ebp+-2196)), op(0x3c))
		i2 =  ((mstate.ebp+-1472))
		__asm(push(i2), push((mstate.ebp+-2142)), op(0x3c))
		i2 =  ((mstate.ebp+-1552))
		__asm(push(i2), push((mstate.ebp+-2259)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2115)), op(0x37))))
		i2 =  (i2 + 1)
		__asm(push(i2), push((mstate.ebp+-2169)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2034)), op(0x37))))
		__asm(push(i2), push((mstate.ebp+-2124)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2268)), op(0x37))))
		__asm(push(i2), push((mstate.ebp+-2088)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2151)), op(0x37))))
		__asm(push(i2), push((mstate.ebp+-2097)), op(0x3c))
		i11 = i14
		i14 = i15
		i15 = i16
		i22 = i17
		i21 = i18
		i24 = i19
		i12 = i20
		i17 = i25
		i18 = i26
		i8 = i27
		i19 = i10
		i2 = i6
		i16 = i28
		i20 = i7
		i23 = i29
		i7 = i30
		i6 = i9
		i10 = i31
		i9 =  ((__xasm<int>(push((mstate.ebp+-2286)), op(0x37))))
	__asm(lbl("___vfprintf__XprivateX__BB54_32_F"))
		__asm(push(i14), push((mstate.ebp+-2331)), op(0x3c))
		i14 = i15
		__asm(push(i14), push((mstate.ebp+-2295)), op(0x3c))
		i14 = i22
		__asm(push(i14), push((mstate.ebp+-2313)), op(0x3c))
		i14 = i24
		__asm(push(i14), push((mstate.ebp+-2349)), op(0x3c))
		__asm(push(i12), push((mstate.ebp+-2340)), op(0x3c))
		i12 = i17
		__asm(push(i12), push((mstate.ebp+-2502)), op(0x3c))
		i12 = i18
		__asm(push(i12), push((mstate.ebp+-2484)), op(0x3c))
		__asm(push(i8), push((mstate.ebp+-2475)), op(0x3c))
		i8 = i19
		__asm(push(i8), push((mstate.ebp+-2520)), op(0x3c))
		i8 = i16
		__asm(push(i8), push((mstate.ebp+-2403)), op(0x3c))
		i8 = i20
		__asm(push(i8), push((mstate.ebp+-2358)), op(0x3c))
		i8 = i23
		i12 =  (i8 - i9)
		__asm(push(i8!=i9), iftrue, target("___vfprintf__XprivateX__BB54_34_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_33_F"))
		i9 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_43_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_34_F"))
		i14 =  (i12 + i6)
		__asm(push(i14>-1), iftrue, target("___vfprintf__XprivateX__BB54_36_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_35_F"))
		i6 =  (-1)
		i9 = i21
		i0 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1496_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_36_F"))
		__asm(push(i9), push(i10), op(0x3c))
		__asm(push(i12), push((i10+4)), op(0x3c))
		i9 =  ((__xasm<int>(push(i4), op(0x37))))
		i9 =  (i9 + i12)
		__asm(push(i9), push(i4), op(0x3c))
		i12 =  ((__xasm<int>(push(i5), op(0x37))))
		i12 =  (i12 + 1)
		__asm(push(i12), push(i5), op(0x3c))
		i10 =  (i10 + 8)
		__asm(push(i12>7), iftrue, target("___vfprintf__XprivateX__BB54_38_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_37_F"))
		i9 = i10
		i6 = i14
		__asm(jump, target("___vfprintf__XprivateX__BB54_43_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_38_F"))
		__asm(push(i9!=0), iftrue, target("___vfprintf__XprivateX__BB54_40_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_39_F"))
		i6 =  (0)
		__asm(push(i6), push(i5), op(0x3c))
		i9 = i3
		i6 = i14
		__asm(jump, target("___vfprintf__XprivateX__BB54_43_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_40_F"))
		i9 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i9), push((mstate.esp+4)), op(0x3c))
		state = 4
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state4"))
		i9 = mstate.eax
		mstate.esp += 8
		i10 =  (0)
		__asm(push(i10), push(i4), op(0x3c))
		__asm(push(i10), push(i5), op(0x3c))
		__asm(push(i9==0), iftrue, target("___vfprintf__XprivateX__BB54_42_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_41_F"))
		i9 = i21
		i0 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1496_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_42_F"))
		i9 = i3
		i6 = i14
	__asm(lbl("___vfprintf__XprivateX__BB54_43_F"))
		__asm(push(i9), push((mstate.ebp+-2304)), op(0x3c))
		__asm(push(i6), push((mstate.ebp+-2322)), op(0x3c))
		i6 =  (i7 & 255)
		__asm(push(i6==0), iftrue, target("___vfprintf__XprivateX__BB54_1492_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_44_F"))
		i6 =  (0)
		__asm(push(i6), push((mstate.ebp+-1762)), op(0x3a))
		i9 =  ((__xasm<int>(push((mstate.ebp+-2169)), op(0x37))))
		__asm(push(i6), push(i9), op(0x3a))
		i9 =  (-1)
		i7 =  (i8 + 1)
		i8 = i6
		i10 = i11
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_45_B"), label)
		i9 =  (i9 + i11)
		i7 = i9
		i9 = i1
		i10 = i14
		i1 = i12
	__asm(jump, target("___vfprintf__XprivateX__BB54_46_F"), lbl("___vfprintf__XprivateX__BB54_46_B"), label, lbl("___vfprintf__XprivateX__BB54_46_F")); 
		i14 = i10
		i12 = i1
		i1 =  ((__xasm<int>(push(i7), op(0x35), op(0x51))))
		i7 =  (i7 + 1)
		i10 = i14
		i11 = i1
		i1 = i9
	__asm(jump, target("___vfprintf__XprivateX__BB54_47_F"), lbl("___vfprintf__XprivateX__BB54_47_B"), label, lbl("___vfprintf__XprivateX__BB54_47_F")); 
		i9 = i11
		__asm(jump, target("___vfprintf__XprivateX__BB54_49_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_48_B"), label)
		i1 =  (i1 + i11)
		i1 =  (i1 + i7)
		i1 =  (i1 + 1)
		i7 = i1
		i1 = i15
	__asm(jump, target("___vfprintf__XprivateX__BB54_49_F"), lbl("___vfprintf__XprivateX__BB54_49_B"), label, lbl("___vfprintf__XprivateX__BB54_49_F")); 
		i11 = i9
		i15 =  (0)
		i9 = i7
		i16 = i11
	__asm(jump, target("___vfprintf__XprivateX__BB54_50_F"), lbl("___vfprintf__XprivateX__BB54_50_B"), label, lbl("___vfprintf__XprivateX__BB54_50_F")); 
		i11 = i15
		i15 =  (i9 + i11)
		__asm(push(i16>87), iftrue, target("___vfprintf__XprivateX__BB54_90_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_51_F"))
		__asm(push(i16>64), iftrue, target("___vfprintf__XprivateX__BB54_73_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_52_F"))
		__asm(push(i16>42), iftrue, target("___vfprintf__XprivateX__BB54_63_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_53_F"))
		__asm(push(i16>34), iftrue, target("___vfprintf__XprivateX__BB54_58_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_54_F"))
		__asm(push(i16==0), iftrue, target("___vfprintf__XprivateX__BB54_1492_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_55_F"))
		__asm(push(i16==32), iftrue, target("___vfprintf__XprivateX__BB54_56_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_56_F"))
		i16 =  ((__xasm<int>(push((mstate.ebp+-1762)), op(0x35))))
		__asm(push(i16!=0), iftrue, target("___vfprintf__XprivateX__BB54_45_B"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_57_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_57_F"))
		i16 =  (32)
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i16 =  ((__xasm<int>(push(i15), op(0x35), op(0x51))))
		i15 =  (i11 + 1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_50_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_58_F"))
		__asm(push(i16==35), iftrue, target("___vfprintf__XprivateX__BB54_147_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_59_F"))
		__asm(push(i16==39), iftrue, target("___vfprintf__XprivateX__BB54_167_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_60_F"))
		__asm(push(i16==42), iftrue, target("___vfprintf__XprivateX__BB54_61_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_61_F"))
		i6 =  ((__xasm<int>(push(i15), op(0x35), op(0x51))))
		i6 =  (i6 + -48)
		__asm(push(uint(i6)>uint(9)), iftrue, target("___vfprintf__XprivateX__BB54_151_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_62_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_62_F"))
		i10 =  (0)
		i6 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_149_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_63_F"))
		__asm(push(i16>45), iftrue, target("___vfprintf__XprivateX__BB54_67_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_64_F"))
		__asm(push(i16==43), iftrue, target("___vfprintf__XprivateX__BB54_166_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_65_F"))
		__asm(push(i16==45), iftrue, target("___vfprintf__XprivateX__BB54_66_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_66_F"))
		i7 =  (i9 + i11)
		i9 =  (i8 | 4)
		i8 = i9
		i9 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_67_F"))
		__asm(push(i16==46), iftrue, target("___vfprintf__XprivateX__BB54_181_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_68_F"))
		__asm(push(i16==48), iftrue, target("___vfprintf__XprivateX__BB54_198_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_69_F"))
		i17 =  (i16 + -49)
		__asm(push(uint(i17)<uint(9)), iftrue, target("___vfprintf__XprivateX__BB54_70_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_70_F"))
		i9 =  (0)
		i15 = i9
		__asm(jump, target("___vfprintf__XprivateX__BB54_71_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_71_F"), lbl("___vfprintf__XprivateX__BB54_71_B"), label, lbl("___vfprintf__XprivateX__BB54_71_F")); 
		i17 =  (i11 + i15)
		i17 =  (i7 + i17)
		i17 =  ((__xasm<int>(push(i17), op(0x35))))
		i9 =  (i9 * 10)
		i18 =  (i17 << 24)
		i9 =  (i16 + i9)
		i16 =  (i18 >> 24)
		i18 =  (i9 + -48)
		i9 =  (i15 + 1)
		i15 =  (i16 + -48)
		__asm(push(uint(i15)>uint(9)), iftrue, target("___vfprintf__XprivateX__BB54_199_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_72_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_72_F"))
		i15 = i9
		i9 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_71_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_73_F"))
		__asm(push(i16>70), iftrue, target("___vfprintf__XprivateX__BB54_82_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_74_F"))
		__asm(push(i16>67), iftrue, target("___vfprintf__XprivateX__BB54_78_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_75_F"))
		__asm(push(i16==65), iftrue, target("___vfprintf__XprivateX__BB54_95_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_76_F"))
		__asm(push(i16==67), iftrue, target("___vfprintf__XprivateX__BB54_77_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_77_F"))
		i7 =  (i8 | 16)
		__asm(jump, target("___vfprintf__XprivateX__BB54_142_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_78_F"))
		__asm(push(i16==68), iftrue, target("___vfprintf__XprivateX__BB54_220_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_79_F"))
		__asm(push(i16==69), iftrue, target("___vfprintf__XprivateX__BB54_104_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_80_F"))
		__asm(push(i16==70), iftrue, target("___vfprintf__XprivateX__BB54_81_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_81_F"), lbl("___vfprintf__XprivateX__BB54_81_B"), label, lbl("___vfprintf__XprivateX__BB54_81_F")); 
		i7 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_440_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_82_F"))
		__asm(push(i16>78), iftrue, target("___vfprintf__XprivateX__BB54_86_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_83_F"))
		__asm(push(i16==71), iftrue, target("___vfprintf__XprivateX__BB54_109_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_84_F"))
		__asm(push(i16==76), iftrue, target("___vfprintf__XprivateX__BB54_85_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_85_F"))
		i7 =  (i9 + i11)
		i8 =  (i8 | 8)
		i9 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_86_F"))
		__asm(push(i16==79), iftrue, target("___vfprintf__XprivateX__BB54_979_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_87_F"))
		__asm(push(i16==83), iftrue, target("___vfprintf__XprivateX__BB54_1015_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_88_F"))
		__asm(push(i16==85), iftrue, target("___vfprintf__XprivateX__BB54_89_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_89_F"))
		i7 =  (i8 | 16)
		__asm(jump, target("___vfprintf__XprivateX__BB54_134_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_90_F"))
		__asm(push(i16>107), iftrue, target("___vfprintf__XprivateX__BB54_115_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_91_F"))
		__asm(push(i16>101), iftrue, target("___vfprintf__XprivateX__BB54_106_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_92_F"))
		__asm(push(i16>98), iftrue, target("___vfprintf__XprivateX__BB54_101_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_93_F"))
		__asm(push(i16==88), iftrue, target("___vfprintf__XprivateX__BB54_146_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_94_F"))
		__asm(push(i16==97), iftrue, target("___vfprintf__XprivateX__BB54_95_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_95_F"))
		i7 =  (_xdigs_lower_2E_4528)
		i10 =  (i1 >>> 31)
		i13 =  (_xdigs_upper_2E_4529)
		i10 =  (i10 ^ 1)
		i17 =  ((i16==97) ? 120 : 88)
		i18 =  ((__xasm<int>(push((mstate.ebp+-2169)), op(0x37))))
		__asm(push(i17), push(i18), op(0x3a))
		i7 =  ((i16==97) ? i7 : i13)
		i13 =  ((i16==97) ? 112 : 80)
		i1 =  (i10 + i1)
		__asm(push(i21==0), iftrue, target("___vfprintf__XprivateX__BB54_98_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_96_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_96_F"))
		i10 =  (1)
		i17 =  ((__xasm<int>(push((i21+-4)), op(0x37))))
		__asm(push(i17), push(i21), op(0x3c))
		i10 =  (i10 << i17)
		__asm(push(i10), push((i21+4)), op(0x3c))
		i10 =  (i21 + -4)
		i18 = i10
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_98_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_97_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_97_F"))
		i19 =  (_freelist)
		i17 =  (i17 << 2)
		i17 =  (i19 + i17)
		i19 =  ((__xasm<int>(push(i17), op(0x37))))
		__asm(push(i19), push(i10), op(0x3c))
		__asm(push(i18), push(i17), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_98_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_98_F"))
		i10 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		i17 =  (i8 & 8)
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_346_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_99_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_99_F"))
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_264_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_100_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_100_F"))
		i17 =  (i2 << 3)
		i10 =  (i10 + i17)
		__asm(jump, target("___vfprintf__XprivateX__BB54_265_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_101_F"))
		__asm(push(i16==99), iftrue, target("___vfprintf__XprivateX__BB54_141_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_102_F"))
		__asm(push(i16==100), iftrue, target("___vfprintf__XprivateX__BB54_140_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_103_F"))
		__asm(push(i16==101), iftrue, target("___vfprintf__XprivateX__BB54_104_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_104_F"))
		i7 = i16
		__asm(push(i1>-1), iftrue, target("___vfprintf__XprivateX__BB54_436_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_105_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_105_F"))
		i1 =  (7)
		__asm(jump, target("___vfprintf__XprivateX__BB54_440_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_106_F"))
		__asm(push(i16>103), iftrue, target("___vfprintf__XprivateX__BB54_111_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_107_F"))
		__asm(push(i16==102), iftrue, target("___vfprintf__XprivateX__BB54_81_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_108_F"))
		__asm(push(i16==103), iftrue, target("___vfprintf__XprivateX__BB54_109_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_109_F"))
		i7 =  (i16 + -2)
		__asm(push(i1==0), iftrue, target("___vfprintf__XprivateX__BB54_439_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_110_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_110_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_440_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_111_F"))
		__asm(push(i16==104), iftrue, target("___vfprintf__XprivateX__BB54_204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_112_F"))
		__asm(push(i16==105), iftrue, target("___vfprintf__XprivateX__BB54_140_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_113_F"))
		__asm(push(i16==106), iftrue, target("___vfprintf__XprivateX__BB54_114_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_114_F"))
		i7 =  (i9 + i11)
		i8 =  (i8 | 4096)
		i9 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_115_F"))
		__asm(push(i16>114), iftrue, target("___vfprintf__XprivateX__BB54_126_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_116_F"))
		__asm(push(i16>110), iftrue, target("___vfprintf__XprivateX__BB54_122_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_117_F"))
		__asm(push(i16==108), iftrue, target("___vfprintf__XprivateX__BB54_207_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_118_F"))
		__asm(push(i16==110), iftrue, target("___vfprintf__XprivateX__BB54_119_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_119_F"))
		i7 =  (i8 & 32)
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_945_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_120_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_120_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_943_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_121_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_121_F"))
		i1 =  (i2 << 3)
		i7 =  (i7 + i1)
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_944_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_122_F"))
		__asm(push(i16==111), iftrue, target("___vfprintf__XprivateX__BB54_139_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_123_F"))
		__asm(push(i16==112), iftrue, target("___vfprintf__XprivateX__BB54_1011_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_124_F"))
		__asm(push(i16==113), iftrue, target("___vfprintf__XprivateX__BB54_125_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_125_F"))
		i7 =  (i9 + i11)
		i8 =  (i8 | 32)
		i9 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_126_F"))
		__asm(push(i16>116), iftrue, target("___vfprintf__XprivateX__BB54_130_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_127_F"))
		__asm(push(i16==115), iftrue, target("___vfprintf__XprivateX__BB54_138_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_128_F"))
		__asm(push(i16==116), iftrue, target("___vfprintf__XprivateX__BB54_129_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_129_F"))
		i7 =  (i9 + i11)
		i8 =  (i8 | 2048)
		i9 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_130_F"))
		__asm(push(i16==122), iftrue, target("___vfprintf__XprivateX__BB54_210_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_131_F"))
		__asm(push(i16==120), iftrue, target("___vfprintf__XprivateX__BB54_1110_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_132_F"))
		__asm(push(i16!=117), iftrue, target("___vfprintf__XprivateX__BB54_1204_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_133_F"))
		i7 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_134_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_134_F"))
		i8 =  (i7 & 7200)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1095_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_135_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_135_F"))
		i8 =  (i7 & 4096)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1084_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_136_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_136_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1083_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_137_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_137_F"))
		i16 =  (0)
		i17 =  (i2 << 3)
		i8 =  (i8 + i17)
		i17 =  ((__xasm<int>(push(i8), op(0x37))))
		i8 =  ((__xasm<int>(push((i8+4)), op(0x37))))
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i19 =  (10)
		i2 =  (i2 + 1)
		i16 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i18 = i16
		i16 = i17
		i17 = i19
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_138_F"))
		i7 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_1016_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_139_F"))
		i7 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_980_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_140_F"))
		i7 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_221_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_141_F"))
		i7 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_142_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_142_F"))
		i8 =  (i7 & 16)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_216_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_143_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_143_F"))
		i8 =  (_initial_2E_4576)
		i10 =  ((__xasm<int>(push((mstate.ebp+-2142)), op(0x37))))
		i16 =  (128)
		memcpy(i10, i8, i16)
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_211_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_144_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_144_F"))
		i10 =  ((mstate.ebp+-1472))
		i16 =  (i2 << 3)
		i8 =  (i8 + i16)
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		mstate.esp -= 12
		i16 =  ((__xasm<int>(push((mstate.ebp+-2205)), op(0x37))))
		__asm(push(i16), push(mstate.esp), op(0x3c))
		__asm(push(i8), push((mstate.esp+4)), op(0x3c))
		__asm(push(i10), push((mstate.esp+8)), op(0x3c))
		mstate.esp -= 4;FSM__UTF8_wcrtomb.start()
	__asm(lbl("___vfprintf_state5"))
		i8 = mstate.eax
		mstate.esp += 12
		__asm(push(i8==-1), iftrue, target("___vfprintf__XprivateX__BB54_213_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_145_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_145_F"))
		i10 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_219_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_146_F"))
		i7 =  (_xdigs_upper_2E_4529)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1111_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_147_F"))
		i7 =  (i9 + i11)
		i9 =  (i8 | 1)
		i8 = i9
		i9 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_148_B"), label)
		i6 = i15
		__asm(jump, target("___vfprintf__XprivateX__BB54_149_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_149_F"))
		i15 =  (i6 + 1)
		i6 =  (i11 + i6)
		i16 =  (i11 + i15)
		i6 =  (i7 + i6)
		i6 =  ((__xasm<int>(push(i6), op(0x35), op(0x51))))
		i10 =  (i10 * 10)
		i16 =  (i7 + i16)
		i17 =  ((__xasm<int>(push(i16), op(0x35), op(0x51))))
		i6 =  (i10 + i6)
		i10 =  (i6 + -48)
		i6 =  (i17 + -48)
		__asm(push(uint(i6)<uint(10)), iftrue, target("___vfprintf__XprivateX__BB54_148_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_150_F"))
		i7 = i16
		i6 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_152_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_151_F"))
		i6 =  (0)
		i7 =  (i9 + i11)
	__asm(lbl("___vfprintf__XprivateX__BB54_152_F"))
		i10 =  ((__xasm<int>(push(i7), op(0x35))))
		i15 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i10!=36), iftrue, target("___vfprintf__XprivateX__BB54_160_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_153_F"))
		__asm(push(i15!=0), iftrue, target("___vfprintf__XprivateX__BB54_155_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_154_F"))
		i9 =  ((mstate.ebp+-1556))
		i15 =  ((__xasm<int>(push((mstate.ebp+-2259)), op(0x37))))
		__asm(push(i15), push((mstate.ebp+-1556)), op(0x3c))
		i15 =  ((__xasm<int>(push((mstate.ebp+-1476)), op(0x37))))
		mstate.esp -= 12
		i10 =  ((__xasm<int>(push((mstate.ebp+-2241)), op(0x37))))
		__asm(push(i10), push(mstate.esp), op(0x3c))
		__asm(push(i15), push((mstate.esp+4)), op(0x3c))
		__asm(push(i9), push((mstate.esp+8)), op(0x3c))
		state = 6
		mstate.esp -= 4;FSM___find_arguments.start()
		return
	__asm(lbl("___vfprintf_state6"))
		mstate.esp += 12
	__asm(lbl("___vfprintf__XprivateX__BB54_155_F"))
		i9 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		i7 =  (i7 + 1)
		__asm(push(i9==0), iftrue, target("___vfprintf__XprivateX__BB54_159_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_156_F"))
		i6 =  (i6 << 3)
		i9 =  (i9 + i6)
		i9 =  ((__xasm<int>(push(i9), op(0x37))))
		__asm(push(i9>-1), iftrue, target("___vfprintf__XprivateX__BB54_158_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_157_F"))
		i6 = i2
		i15 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_165_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_158_F"))
		i6 = i9
		i9 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_159_F"))
		i9 =  (i12 + 4)
		i6 = i12
		i15 = i2
		__asm(jump, target("___vfprintf__XprivateX__BB54_163_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_160_F"))
		__asm(push(i15==0), iftrue, target("___vfprintf__XprivateX__BB54_162_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_161_F"))
		i7 =  (i2 << 3)
		i9 =  (i9 + i11)
		i2 =  (i2 + 1)
		i6 =  (i15 + i7)
		i7 = i9
		i15 = i2
		i9 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_163_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_162_F"))
		i7 =  (i9 + i11)
		i9 =  (i2 + 1)
		i2 =  (i12 + 4)
		i6 = i12
		i15 = i9
		i9 = i2
	__asm(lbl("___vfprintf__XprivateX__BB54_163_F"))
		i16 = i9
		i9 =  ((__xasm<int>(push(i6), op(0x37))))
		__asm(push(i9>-1), iftrue, target("___vfprintf__XprivateX__BB54_1510_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_164_F"))
		i6 = i15
		i15 = i16
		__asm(jump, target("___vfprintf__XprivateX__BB54_165_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_165_F"))
		i2 = i6
		i6 =  (i8 | 4)
		i9 =  (0 - i9)
		i8 = i6
		i6 = i9
		i9 = i1
		i10 = i14
		i1 = i15
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_166_F"))
		i7 =  (43)
		__asm(push(i7), push((mstate.ebp+-1762)), op(0x3a))
		i7 =  (i9 + i11)
		i9 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_167_F"))
		i7 =  ((__xasm<int>(push(___mlocale_changed_2E_b), op(0x35))))
		i8 =  (i8 | 512)
		i10 =  (i7 ^ 1)
		i10 =  (i10 & 1)
		__asm(push(i10!=0), iftrue, target("___vfprintf__XprivateX__BB54_169_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_168_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_170_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_169_F"))
		i7 =  (1)
		__asm(push(i7), push(___mlocale_changed_2E_b), op(0x3a))
	__asm(lbl("___vfprintf__XprivateX__BB54_170_F"))
		i10 =  ((__xasm<int>(push(___nlocale_changed_2E_b), op(0x35))))
		i15 =  (i10 ^ 1)
		i15 =  (i15 & 1)
		__asm(push(i15!=0), iftrue, target("___vfprintf__XprivateX__BB54_172_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_171_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_173_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_172_F"))
		i10 =  (1)
		__asm(push(i10), push(_ret_2E_1494_2E_0_2E_b), op(0x3a))
		__asm(push(i10), push(_ret_2E_1494_2E_2_2E_b), op(0x3a))
		__asm(push(i10), push(___nlocale_changed_2E_b), op(0x3a))
	__asm(lbl("___vfprintf__XprivateX__BB54_173_F"))
		i15 =  (0)
		__asm(push(i15), push((mstate.ebp+-1761)), op(0x3a))
		i7 =  (i7 & 1)
		__asm(push(i7!=0), iftrue, target("___vfprintf__XprivateX__BB54_175_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_174_F"))
		i7 =  (1)
		__asm(push(i7), push(___mlocale_changed_2E_b), op(0x3a))
	__asm(lbl("___vfprintf__XprivateX__BB54_175_F"))
		i7 =  (i10 & 1)
		__asm(push(i7!=0), iftrue, target("___vfprintf__XprivateX__BB54_177_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_176_F"))
		i7 =  (1)
		__asm(push(i7), push(_ret_2E_1494_2E_0_2E_b), op(0x3a))
		__asm(push(i7), push(_ret_2E_1494_2E_2_2E_b), op(0x3a))
		__asm(push(i7), push(___nlocale_changed_2E_b), op(0x3a))
	__asm(lbl("___vfprintf__XprivateX__BB54_177_F"))
		i7 =  (_numempty22)
		i10 =  ((__xasm<int>(push(_ret_2E_1494_2E_2_2E_b), op(0x35))))
		i10 =  ((i10!=0) ? i7 : 0)
		i7 =  (i9 + i11)
		i9 = i1
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_178_B"), label)
		i9 = i15
		__asm(jump, target("___vfprintf__XprivateX__BB54_179_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_179_F"), lbl("___vfprintf__XprivateX__BB54_179_B"), label, lbl("___vfprintf__XprivateX__BB54_179_F")); 
		i15 =  (i9 + 1)
		i16 =  (i11 + i15)
		i9 =  (i9 + i11)
		i16 =  (i7 + i16)
		i9 =  (i9 + i7)
		i16 =  ((__xasm<int>(push(i16), op(0x35), op(0x51))))
		i10 =  (i10 * 10)
		i17 =  ((__xasm<int>(push((i9+2)), op(0x35), op(0x51))))
		i10 =  (i10 + i16)
		i10 =  (i10 + -48)
		i9 =  (i9 + 2)
		i16 =  (i17 + -48)
		__asm(push(uint(i16)<uint(10)), iftrue, target("___vfprintf__XprivateX__BB54_178_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_180_F"))
		i7 = i9
		i9 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_184_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_181_F"))
		i1 =  (i11 + i7)
		i9 =  ((__xasm<int>(push(i15), op(0x35))))
		i1 =  (i1 + 1)
		__asm(push(i9==42), iftrue, target("___vfprintf__XprivateX__BB54_182_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_196_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_182_F"))
		i9 =  ((__xasm<int>(push(i1), op(0x35), op(0x51))))
		i9 =  (i9 + -48)
		__asm(push(uint(i9)<uint(10)), iftrue, target("___vfprintf__XprivateX__BB54_1511_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_183_F"))
		i9 =  (0)
		i7 = i1
		__asm(jump, target("___vfprintf__XprivateX__BB54_184_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_184_F"))
		i10 =  ((__xasm<int>(push(i7), op(0x35))))
		i15 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i10!=36), iftrue, target("___vfprintf__XprivateX__BB54_190_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_185_F"))
		__asm(push(i15!=0), iftrue, target("___vfprintf__XprivateX__BB54_187_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_186_F"))
		i1 =  ((mstate.ebp+-1556))
		i15 =  ((__xasm<int>(push((mstate.ebp+-2259)), op(0x37))))
		__asm(push(i15), push((mstate.ebp+-1556)), op(0x3c))
		i15 =  ((__xasm<int>(push((mstate.ebp+-1476)), op(0x37))))
		mstate.esp -= 12
		i10 =  ((__xasm<int>(push((mstate.ebp+-2241)), op(0x37))))
		__asm(push(i10), push(mstate.esp), op(0x3c))
		__asm(push(i15), push((mstate.esp+4)), op(0x3c))
		__asm(push(i1), push((mstate.esp+8)), op(0x3c))
		state = 7
		mstate.esp -= 4;FSM___find_arguments.start()
		return
	__asm(lbl("___vfprintf_state7"))
		mstate.esp += 12
	__asm(lbl("___vfprintf__XprivateX__BB54_187_F"))
		i1 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		i7 =  (i7 + 1)
		__asm(push(i1==0), iftrue, target("___vfprintf__XprivateX__BB54_189_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_188_F"))
		i9 =  (i9 << 3)
		i1 =  (i1 + i9)
		i1 =  ((__xasm<int>(push(i1), op(0x37))))
		i9 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_189_F"))
		i1 =  ((__xasm<int>(push(i12), op(0x37))))
		i15 =  (i12 + 4)
		i9 = i1
		i10 = i14
		i1 = i15
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_190_F"))
		__asm(push(i15==0), iftrue, target("___vfprintf__XprivateX__BB54_192_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_191_F"))
		i7 =  (i2 << 3)
		i7 =  (i15 + i7)
		i9 =  ((__xasm<int>(push(i7), op(0x37))))
		i2 =  (i2 + 1)
		i7 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_192_F"))
		i9 =  ((__xasm<int>(push(i12), op(0x37))))
		i2 =  (i2 + 1)
		i15 =  (i12 + 4)
		i7 = i1
		i10 = i14
		i1 = i15
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_193_B"), label)
		i1 =  (0)
		i16 = i1
		i15 = i1
		i1 = i9
		__asm(jump, target("___vfprintf__XprivateX__BB54_194_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_194_F"), lbl("___vfprintf__XprivateX__BB54_194_B"), label, lbl("___vfprintf__XprivateX__BB54_194_F")); 
		i9 = i16
		i16 = i1
		i1 =  (i9 + 1)
		i9 =  (i15 * 10)
		i15 =  (i11 + i1)
		i16 =  (i9 + i16)
		i9 =  (i7 + i15)
		i9 =  ((__xasm<int>(push(i9), op(0x35), op(0x51))))
		i15 =  (i16 + -48)
		i16 =  (i9 + -48)
		__asm(push(uint(i16)>uint(9)), iftrue, target("___vfprintf__XprivateX__BB54_48_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_195_F"))
		i16 = i1
		i1 = i9
		__asm(jump, target("___vfprintf__XprivateX__BB54_194_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_196_F"))
		i9 =  (i9 << 24)
		i9 =  (i9 >> 24)
		i16 =  (i9 + -48)
		__asm(push(uint(i16)<uint(10)), iftrue, target("___vfprintf__XprivateX__BB54_193_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_197_F"))
		i16 =  (0)
		i7 = i1
		i1 = i16
		__asm(jump, target("___vfprintf__XprivateX__BB54_49_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_198_F"))
		i7 =  (i9 + i11)
		i9 =  (i8 | 128)
		i8 = i9
		i9 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_199_F"))
		i9 =  (i11 + i9)
		i7 =  (i7 + i9)
		i9 =  (i17 & 255)
		__asm(push(i9==36), iftrue, target("___vfprintf__XprivateX__BB54_201_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_200_F"))
		i11 = i16
		i6 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_47_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_201_F"))
		i2 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i2==0), iftrue, target("___vfprintf__XprivateX__BB54_203_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_202_F"))
		i9 = i1
		i10 = i14
		i2 = i18
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_203_F"))
		i2 =  ((mstate.ebp+-1556))
		i9 =  ((__xasm<int>(push((mstate.ebp+-2259)), op(0x37))))
		__asm(push(i9), push((mstate.ebp+-1556)), op(0x3c))
		i9 =  ((__xasm<int>(push((mstate.ebp+-1476)), op(0x37))))
		mstate.esp -= 12
		i10 =  ((__xasm<int>(push((mstate.ebp+-2241)), op(0x37))))
		__asm(push(i10), push(mstate.esp), op(0x3c))
		__asm(push(i9), push((mstate.esp+4)), op(0x3c))
		__asm(push(i2), push((mstate.esp+8)), op(0x3c))
		state = 8
		mstate.esp -= 4;FSM___find_arguments.start()
		return
	__asm(lbl("___vfprintf_state8"))
		mstate.esp += 12
		i9 = i1
		i10 = i14
		i2 = i18
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_204_F"))
		i7 =  (i8 & 64)
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_206_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_205_F"))
		i7 =  (i8 | 8192)
		i8 =  (i9 + i11)
		i9 =  (i7 & -65)
		i7 = i8
		i8 = i9
		i9 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_206_F"))
		i7 =  (i9 + i11)
		i8 =  (i8 | 64)
		i9 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_207_F"))
		i7 =  (i8 & 16)
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_209_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_208_F"))
		i7 =  (i8 | 32)
		i8 =  (i9 + i11)
		i9 =  (i7 & -17)
		i7 = i8
		i8 = i9
		i9 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_209_F"))
		i7 =  (i9 + i11)
		i8 =  (i8 | 16)
		i9 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_210_F"))
		i7 =  (i9 + i11)
		i8 =  (i8 | 1024)
		i9 = i1
		i10 = i14
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_211_F"))
		i8 =  ((mstate.ebp+-1472))
		i10 =  ((__xasm<int>(push(i12), op(0x37))))
		mstate.esp -= 12
		i16 =  ((__xasm<int>(push((mstate.ebp+-2205)), op(0x37))))
		__asm(push(i16), push(mstate.esp), op(0x3c))
		__asm(push(i10), push((mstate.esp+4)), op(0x3c))
		__asm(push(i8), push((mstate.esp+8)), op(0x3c))
		mstate.esp -= 4;FSM__UTF8_wcrtomb.start()
	__asm(lbl("___vfprintf_state9"))
		i8 = mstate.eax
		mstate.esp += 12
		i10 =  (i12 + 4)
		__asm(push(i8==-1), iftrue, target("___vfprintf__XprivateX__BB54_213_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_212_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_219_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_213_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-1980)), op(0x37))))
		i7 =  ((__xasm<int>(push(i7), op(0x36))))
		i7 =  (i7 | 64)
		i0 =  ((__xasm<int>(push((mstate.ebp+-1980)), op(0x37))))
		__asm(push(i7), push(i0), op(0x3b))
		__asm(push(i21==0), iftrue, target("___vfprintf__XprivateX__BB54_215_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_214_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		i0 = i21
		i1 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1498_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_215_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		i0 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1501_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_216_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_218_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_217_F"))
		i10 =  (1)
		i16 =  (i2 << 3)
		i8 =  (i8 + i16)
		i8 =  ((__xasm<int>(push(i8), op(0x35))))
		i16 =  ((__xasm<int>(push((mstate.ebp+-2205)), op(0x37))))
		__asm(push(i8), push(i16), op(0x3a))
		i8 = i10
		i10 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_219_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_218_F"))
		i8 =  (1)
		i10 =  ((__xasm<int>(push(i12), op(0x35))))
		i16 =  ((__xasm<int>(push((mstate.ebp+-2205)), op(0x37))))
		__asm(push(i10), push(i16), op(0x3a))
		i10 =  (i12 + 4)
	__asm(lbl("___vfprintf__XprivateX__BB54_219_F"))
		i12 =  (0)
		__asm(push(i12), push((mstate.ebp+-1762)), op(0x3a))
		i2 =  (i2 + 1)
		i16 =  ((__xasm<int>(push((mstate.ebp+-2205)), op(0x37))))
		i17 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i18 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i19 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2313)), op(0x37))))
		i20 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i22 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i23 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i24 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i25 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i26 = i1
		i1 = i12
		i12 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		i27 = i12
		i12 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i28 = i12
		i12 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		i29 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_1205_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_220_F"))
		i7 =  (i8 | 16)
	__asm(lbl("___vfprintf__XprivateX__BB54_221_F"))
		i8 =  (i7 & 7200)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_243_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_222_F"))
		i8 =  (i7 & 4096)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_228_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_223_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_227_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_224_F"))
		i16 =  (i2 << 3)
		i8 =  (i8 + i16)
		i16 =  ((__xasm<int>(push(i8), op(0x37))))
		i8 =  ((__xasm<int>(push((i8+4)), op(0x37))))
		i2 =  (i2 + 1)
		__asm(push(i8<0), iftrue, target("___vfprintf__XprivateX__BB54_226_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_225_F"))
		i17 =  (10)
		i18 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_226_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_242_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_227_F"))
		i8 =  ((__xasm<int>(push(i12), op(0x37))))
		i16 =  ((__xasm<int>(push((i12+4)), op(0x37))))
		i12 =  (i12 + 8)
		__asm(jump, target("___vfprintf__XprivateX__BB54_239_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_228_F"))
		i8 =  (i7 & 1024)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_232_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_229_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_231_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_230_F"))
		i16 =  (0)
		i17 =  (i2 << 3)
		i8 =  (i8 + i17)
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_239_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_231_F"))
		i16 =  (0)
		i8 =  ((__xasm<int>(push(i12), op(0x37))))
		i12 =  (i12 + 4)
		__asm(jump, target("___vfprintf__XprivateX__BB54_239_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_232_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		i16 =  (i7 & 2048)
		__asm(push(i16==0), iftrue, target("___vfprintf__XprivateX__BB54_236_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_233_F"))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_235_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_234_F"))
		i16 =  (i2 << 3)
		i8 =  (i8 + i16)
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		i16 =  (i8 >> 31)
		__asm(jump, target("___vfprintf__XprivateX__BB54_239_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_235_F"))
		i8 =  ((__xasm<int>(push(i12), op(0x37))))
		i16 =  (i8 >> 31)
		i12 =  (i12 + 4)
		__asm(jump, target("___vfprintf__XprivateX__BB54_239_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_236_F"))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_238_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_237_F"))
		i16 =  (i2 << 3)
		i8 =  (i8 + i16)
		i16 =  ((__xasm<int>(push(i8), op(0x37))))
		i17 =  ((__xasm<int>(push((i8+4)), op(0x37))))
		i8 = i16
		i16 = i17
		__asm(jump, target("___vfprintf__XprivateX__BB54_239_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_238_F"))
		i8 =  ((__xasm<int>(push(i12), op(0x37))))
		i16 =  ((__xasm<int>(push((i12+4)), op(0x37))))
		i12 =  (i12 + 8)
	__asm(lbl("___vfprintf__XprivateX__BB54_239_F"))
		i17 = i16
		i2 =  (i2 + 1)
		__asm(push(i17<0), iftrue, target("___vfprintf__XprivateX__BB54_241_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_240_F"))
		i19 =  (10)
		i16 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i18 = i16
		i16 = i8
		i8 = i17
		i17 = i19
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_241_F"))
		i16 = i8
		i8 = i17
	__asm(lbl("___vfprintf__XprivateX__BB54_242_F"))
		i17 =  (45)
		i18 =  (0)
		__asm(push(i17), push((mstate.ebp+-1762)), op(0x3a))
		i16 =  __subc(i18, i16)
		i8 =  __sube(i18, i8)
		i17 =  (10)
		i18 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_243_F"))
		i8 =  (i7 & 16)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_249_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_244_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_248_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_245_F"))
		i16 =  (i2 << 3)
		i8 =  (i8 + i16)
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		i2 =  (i2 + 1)
		__asm(push(i8<0), iftrue, target("___vfprintf__XprivateX__BB54_247_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_246_F"))
		i17 =  (10)
		i18 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_247_F"))
		i16 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_263_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_248_F"))
		i8 =  ((__xasm<int>(push(i12), op(0x37))))
		i16 =  (i12 + 4)
		__asm(jump, target("___vfprintf__XprivateX__BB54_260_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_249_F"))
		i8 =  (i7 & 64)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_253_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_250_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_252_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_251_F"))
		i16 =  (i2 << 3)
		i8 =  (i8 + i16)
		i8 =  ((__xasm<int>(push(i8), op(0x36), op(0x52))))
		i16 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_260_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_252_F"))
		i8 =  ((__xasm<int>(push(i12), op(0x36), op(0x52))))
		i16 =  (i12 + 4)
		__asm(jump, target("___vfprintf__XprivateX__BB54_260_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_253_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		i16 =  (i7 & 8192)
		__asm(push(i16==0), iftrue, target("___vfprintf__XprivateX__BB54_257_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_254_F"))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_256_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_255_F"))
		i16 =  (i2 << 3)
		i8 =  (i8 + i16)
		i8 =  ((__xasm<int>(push(i8), op(0x35), op(0x51))))
		i16 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_260_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_256_F"))
		i8 =  ((__xasm<int>(push(i12), op(0x35), op(0x51))))
		i16 =  (i12 + 4)
		__asm(jump, target("___vfprintf__XprivateX__BB54_260_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_257_F"))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_259_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_258_F"))
		i16 =  (i2 << 3)
		i8 =  (i8 + i16)
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		i16 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_260_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_259_F"))
		i8 =  ((__xasm<int>(push(i12), op(0x37))))
		i16 =  (i12 + 4)
	__asm(lbl("___vfprintf__XprivateX__BB54_260_F"))
		i12 = i16
		i2 =  (i2 + 1)
		__asm(push(i8<0), iftrue, target("___vfprintf__XprivateX__BB54_262_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_261_F"))
		i17 =  (10)
		i18 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_262_F"))
		i16 = i12
	__asm(lbl("___vfprintf__XprivateX__BB54_263_F"))
		i12 = i16
		i16 =  (45)
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (10)
		i8 =  (0 - i8)
		i18 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_264_F"))
		i17 =  (i12 + 8)
		i10 = i12
		i12 = i17
	__asm(lbl("___vfprintf__XprivateX__BB54_265_F"))
		i17 =  (0)
		f0 =  ((__xasm<Number>(push(i10), op(0x39))))
		i10 =  ((__xasm<int>(push((mstate.ebp+-2088)), op(0x37))))
		__asm(push(f0), push(i10), op(0x3e))
		i10 =  ((__xasm<int>(push((mstate.ebp+-2025)), op(0x37))))
		i10 =  ((__xasm<int>(push(i10), op(0x37))))
		__asm(push(f0), push((mstate.ebp+-1776)), op(0x3e))
		i18 =  ((__xasm<int>(push((mstate.ebp+-1772)), op(0x37))))
		i19 =  (i10 >>> 15)
		i21 =  ((__xasm<int>(push((mstate.ebp+-1776)), op(0x37))))
		i20 =  (i18 & 2146435072)
		i19 =  (i19 & 1)
		__asm(push(i20==0), iftrue, target("___vfprintf__XprivateX__BB54_268_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_266_F"))
		i20 =  (i20 ^ 2146435072)
		i17 =  (i17 | i20)
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_269_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_267_F"))
		i18 =  (4)
		__asm(jump, target("___vfprintf__XprivateX__BB54_270_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_268_F"))
		i18 =  (i18 & 1048575)
		i18 =  (i18 | i21)
		i18 =  ((i18==0) ? 16 : 8)
		__asm(jump, target("___vfprintf__XprivateX__BB54_270_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_269_F"))
		i18 =  (i18 & 1048575)
		i18 =  (i18 | i21)
		i18 =  ((i18==0) ? 1 : 2)
	__asm(lbl("___vfprintf__XprivateX__BB54_270_F"))
		i17 = i18
		__asm(push(i17>3), iftrue, target("___vfprintf__XprivateX__BB54_275_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_271_F"))
		__asm(push(i17==1), iftrue, target("___vfprintf__XprivateX__BB54_285_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_272_F"))
		__asm(push(i17==2), iftrue, target("___vfprintf__XprivateX__BB54_273_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_300_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_273_F"))
		i10 =  (2147483647)
		__asm(push(i10), push((mstate.ebp+-1760)), op(0x3c))
		i10 =  ((__xasm<int>(push(_freelist), op(0x37))))
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_293_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_274_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_274_F"))
		i17 =  ((__xasm<int>(push(i10), op(0x37))))
		__asm(push(i17), push(_freelist), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_296_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_275_F"))
		__asm(push(i17==16), iftrue, target("___vfprintf__XprivateX__BB54_279_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_276_F"))
		__asm(push(i17==8), iftrue, target("___vfprintf__XprivateX__BB54_301_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_277_F"))
		__asm(push(i17!=4), iftrue, target("___vfprintf__XprivateX__BB54_300_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_278_F"))
		i10 =  (i10 & 32767)
		i10 =  (i10 + -16385)
		__asm(jump, target("___vfprintf__XprivateX__BB54_302_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_279_F"))
		i10 =  (1)
		__asm(push(i10), push((mstate.ebp+-1760)), op(0x3c))
		i10 =  ((__xasm<int>(push(_freelist), op(0x37))))
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_281_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_280_F"))
		i17 =  ((__xasm<int>(push(i10), op(0x37))))
		__asm(push(i17), push(_freelist), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_284_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_281_F"))
		i10 =  (_private_mem)
		i17 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i10 =  (i17 - i10)
		i10 =  (i10 >> 3)
		i10 =  (i10 + 3)
		__asm(push(uint(i10)>uint(288)), iftrue, target("___vfprintf__XprivateX__BB54_283_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_282_F"))
		i10 =  (0)
		i18 =  (i17 + 24)
		__asm(push(i18), push(_pmem_next), op(0x3c))
		__asm(push(i10), push((i17+4)), op(0x3c))
		i10 =  (1)
		__asm(push(i10), push((i17+8)), op(0x3c))
		i10 = i17
		__asm(jump, target("___vfprintf__XprivateX__BB54_284_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_283_F"))
		i10 =  (24)
		mstate.esp -= 4
		__asm(push(i10), push(mstate.esp), op(0x3c))
		state = 10
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___vfprintf_state10"))
		i10 = mstate.eax
		mstate.esp += 4
		i17 =  (0)
		__asm(push(i17), push((i10+4)), op(0x3c))
		i17 =  (1)
		__asm(push(i17), push((i10+8)), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_284_F"))
		i17 =  (0)
		__asm(push(i17), push((i10+16)), op(0x3c))
		__asm(push(i17), push((i10+12)), op(0x3c))
		__asm(push(i17), push(i10), op(0x3c))
		i18 =  (48)
		__asm(push(i18), push((i10+4)), op(0x3a))
		__asm(push(i17), push((i10+5)), op(0x3a))
		i17 =  (i10 + 5)
		__asm(push(i17), push((mstate.ebp+-1756)), op(0x3c))
		i10 =  (i10 + 4)
		__asm(jump, target("___vfprintf__XprivateX__BB54_343_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_285_F"))
		i10 =  (2147483647)
		__asm(push(i10), push((mstate.ebp+-1760)), op(0x3c))
		i10 =  ((__xasm<int>(push(_freelist), op(0x37))))
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_287_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_286_F"))
		i17 =  ((__xasm<int>(push(i10), op(0x37))))
		__asm(push(i17), push(_freelist), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_290_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_287_F"))
		i10 =  (_private_mem)
		i17 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i10 =  (i17 - i10)
		i10 =  (i10 >> 3)
		i10 =  (i10 + 3)
		__asm(push(uint(i10)>uint(288)), iftrue, target("___vfprintf__XprivateX__BB54_289_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_288_F"))
		i10 =  (0)
		i18 =  (i17 + 24)
		__asm(push(i18), push(_pmem_next), op(0x3c))
		__asm(push(i10), push((i17+4)), op(0x3c))
		i10 =  (1)
		__asm(push(i10), push((i17+8)), op(0x3c))
		i10 = i17
		__asm(jump, target("___vfprintf__XprivateX__BB54_290_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_289_F"))
		i10 =  (24)
		mstate.esp -= 4
		__asm(push(i10), push(mstate.esp), op(0x3c))
		state = 11
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___vfprintf_state11"))
		i10 = mstate.eax
		mstate.esp += 4
		i17 =  (0)
		__asm(push(i17), push((i10+4)), op(0x3c))
		i17 =  (1)
		__asm(push(i17), push((i10+8)), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_290_F"))
		i17 =  (0)
		__asm(push(i17), push((i10+16)), op(0x3c))
		__asm(push(i17), push((i10+12)), op(0x3c))
		__asm(push(i17), push(i10), op(0x3c))
		i18 =  (73)
		__asm(push(i18), push((i10+4)), op(0x3a))
		i10 =  (i10 + 4)
		i18 =  (__2E_str159)
		i21 = i10
	__asm(jump, target("___vfprintf__XprivateX__BB54_291_F"), lbl("___vfprintf__XprivateX__BB54_291_B"), label, lbl("___vfprintf__XprivateX__BB54_291_F")); 
		i20 =  (i18 + i17)
		i20 =  ((__xasm<int>(push((i20+1)), op(0x35))))
		i22 =  (i10 + i17)
		__asm(push(i20), push((i22+1)), op(0x3a))
		i17 =  (i17 + 1)
		__asm(push(i20==0), iftrue, target("___vfprintf__XprivateX__BB54_342_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_292_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_291_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_293_F"))
		i10 =  (_private_mem)
		i17 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i10 =  (i17 - i10)
		i10 =  (i10 >> 3)
		i10 =  (i10 + 3)
		__asm(push(uint(i10)>uint(288)), iftrue, target("___vfprintf__XprivateX__BB54_295_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_294_F"))
		i10 =  (0)
		i18 =  (i17 + 24)
		__asm(push(i18), push(_pmem_next), op(0x3c))
		__asm(push(i10), push((i17+4)), op(0x3c))
		i10 =  (1)
		__asm(push(i10), push((i17+8)), op(0x3c))
		i10 = i17
		__asm(jump, target("___vfprintf__XprivateX__BB54_296_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_295_F"))
		i10 =  (24)
		mstate.esp -= 4
		__asm(push(i10), push(mstate.esp), op(0x3c))
		state = 12
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___vfprintf_state12"))
		i10 = mstate.eax
		mstate.esp += 4
		i17 =  (0)
		__asm(push(i17), push((i10+4)), op(0x3c))
		i17 =  (1)
		__asm(push(i17), push((i10+8)), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_296_F"))
		i17 =  (0)
		__asm(push(i17), push((i10+16)), op(0x3c))
		__asm(push(i17), push((i10+12)), op(0x3c))
		__asm(push(i17), push(i10), op(0x3c))
		i18 =  (78)
		__asm(push(i18), push((i10+4)), op(0x3a))
		i10 =  (i10 + 4)
		i18 =  (__2E_str260)
		i21 = i10
	__asm(jump, target("___vfprintf__XprivateX__BB54_297_F"), lbl("___vfprintf__XprivateX__BB54_297_B"), label, lbl("___vfprintf__XprivateX__BB54_297_F")); 
		i20 =  (i18 + i17)
		i20 =  ((__xasm<int>(push((i20+1)), op(0x35))))
		i22 =  (i10 + i17)
		__asm(push(i20), push((i22+1)), op(0x3a))
		i17 =  (i17 + 1)
		__asm(push(i20==0), iftrue, target("___vfprintf__XprivateX__BB54_299_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_298_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_297_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_299_F"))
		i10 =  (i10 + i17)
		__asm(push(i10), push((mstate.ebp+-1756)), op(0x3c))
		i10 = i21
		__asm(jump, target("___vfprintf__XprivateX__BB54_343_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_300_F"))
		state = 13
		mstate.esp -= 4;FSM_abort1.start()
		return
	__asm(lbl("___vfprintf_state13"))
	__asm(lbl("___vfprintf__XprivateX__BB54_301_F"))
		i10 =  (i10 & 32767)
		f0 =  (f0 * 5.36312e+154)
		i17 =  ((__xasm<int>(push((mstate.ebp+-2088)), op(0x37))))
		__asm(push(f0), push(i17), op(0x3e))
		i10 =  (i10 + -16899)
		__asm(jump, target("___vfprintf__XprivateX__BB54_302_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_302_F"))
		i17 =  ((i1==0) ? 1 : i1)
		__asm(push(i10), push((mstate.ebp+-1760)), op(0x3c))
		i10 =  ((i17>15) ? i17 : 16)
		__asm(push(uint(i10)<uint(20)), iftrue, target("___vfprintf__XprivateX__BB54_1512_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_303_F"))
		i18 =  (4)
		i21 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_304_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_304_F"), lbl("___vfprintf__XprivateX__BB54_304_B"), label, lbl("___vfprintf__XprivateX__BB54_304_F")); 
		i18 =  (i18 << 1)
		i21 =  (i21 + 1)
		i20 =  (i18 + 16)
		__asm(push(uint(i20)>uint(i10)), iftrue, target("___vfprintf__XprivateX__BB54_306_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_305_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_304_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_306_F"))
		i18 = i21
	__asm(jump, target("___vfprintf__XprivateX__BB54_307_F"), lbl("___vfprintf__XprivateX__BB54_307_B"), label, lbl("___vfprintf__XprivateX__BB54_307_F")); 
		mstate.esp -= 4
		__asm(push(i18), push(mstate.esp), op(0x3c))
		state = 14
		mstate.esp -= 4;FSM___Balloc_D2A.start()
		return
	__asm(lbl("___vfprintf_state14"))
		i21 = mstate.eax
		mstate.esp += 4
		i20 =  (i10 + -1)
		i22 =  (i21 + 4)
		__asm(push(i18), push(i21), op(0x3c))
		i18 =  (i22 + i20)
		i21 = i22
		__asm(push(i20>15), iftrue, target("___vfprintf__XprivateX__BB54_309_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_308_F"))
		i10 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_319_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_309_F"))
		i18 =  (0)
		i10 =  (i10 + i22)
		i10 =  (i10 + -1)
	__asm(jump, target("___vfprintf__XprivateX__BB54_310_F"), lbl("___vfprintf__XprivateX__BB54_310_B"), label, lbl("___vfprintf__XprivateX__BB54_310_F")); 
		i23 =  (0)
		i24 =  (i18 ^ -1)
		__asm(push(i23), push(i10), op(0x3a))
		i10 =  (i10 + -1)
		i18 =  (i18 + 1)
		i23 =  (i20 + i24)
		__asm(push(i23<16), iftrue, target("___vfprintf__XprivateX__BB54_318_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_311_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_310_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_312_B"), label)
		__asm(jump, target("___vfprintf__XprivateX__BB54_313_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_313_F"), lbl("___vfprintf__XprivateX__BB54_313_B"), label, lbl("___vfprintf__XprivateX__BB54_313_F")); 
		i24 =  ((__xasm<int>(push((mstate.ebp+-2268)), op(0x37))))
		i24 =  ((__xasm<int>(push(i24), op(0x35))))
		i24 =  (i24 & 15)
		__asm(push(i24), push(i20), op(0x3a))
		i24 =  ((__xasm<int>(push((mstate.ebp+-2268)), op(0x37))))
		i24 =  ((__xasm<int>(push(i24), op(0x37))))
		i24 =  (i24 >>> 4)
		i25 =  (i10 ^ -1)
		i26 =  ((__xasm<int>(push((mstate.ebp+-2268)), op(0x37))))
		__asm(push(i24), push(i26), op(0x3c))
		i20 =  (i20 + -1)
		i10 =  (i10 + 1)
		i24 =  (i23 + i25)
		__asm(push(uint(i18)>=uint(i24)), iftrue, target("___vfprintf__XprivateX__BB54_315_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_314_F"))
		__asm(push(uint(i24)>uint(i21)), iftrue, target("___vfprintf__XprivateX__BB54_312_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_315_F"))
		i10 = i24
		__asm(jump, target("___vfprintf__XprivateX__BB54_316_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_316_F"), lbl("___vfprintf__XprivateX__BB54_316_B"), label, lbl("___vfprintf__XprivateX__BB54_316_F")); 
		i23 = i10
		i10 =  ((__xasm<int>(push((mstate.ebp+-2250)), op(0x37))))
		i18 =  ((__xasm<int>(push(i10), op(0x35))))
		i10 = i23
		__asm(push(uint(i23)>uint(i21)), iftrue, target("___vfprintf__XprivateX__BB54_1513_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_317_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_317_F"))
		i10 = i18
		i18 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_326_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_318_F"))
		i10 =  (i21 + i23)
	__asm(lbl("___vfprintf__XprivateX__BB54_319_F"))
		i23 = i10
		i18 =  (i21 + 7)
		i10 = i23
		__asm(push(uint(i18)>=uint(i23)), iftrue, target("___vfprintf__XprivateX__BB54_321_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_320_F"))
		__asm(push(uint(i23)>uint(i21)), iftrue, target("___vfprintf__XprivateX__BB54_322_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_321_F"))
		i10 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_316_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_322_F"))
		i24 =  (0)
		i20 = i10
		i10 = i24
		__asm(jump, target("___vfprintf__XprivateX__BB54_313_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_323_B"), label)
		__asm(jump, target("___vfprintf__XprivateX__BB54_324_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_324_F"), lbl("___vfprintf__XprivateX__BB54_324_B"), label, lbl("___vfprintf__XprivateX__BB54_324_F")); 
		i18 =  (i18 & 15)
		__asm(push(i18), push(i20), op(0x3a))
		i18 =  ((__xasm<int>(push((mstate.ebp+-2250)), op(0x37))))
		i18 =  ((__xasm<int>(push(i18), op(0x37))))
		i18 =  (i18 >>> 4)
		i24 =  (i10 ^ -1)
		i25 =  ((__xasm<int>(push((mstate.ebp+-2250)), op(0x37))))
		__asm(push(i18), push(i25), op(0x3c))
		i20 =  (i20 + -1)
		i10 =  (i10 + 1)
		i24 =  (i23 + i24)
		__asm(push(uint(i24)>uint(i21)), iftrue, target("___vfprintf__XprivateX__BB54_323_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_325_F"))
		i10 = i18
		i18 = i24
		__asm(jump, target("___vfprintf__XprivateX__BB54_326_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_326_F"))
		i10 =  (i10 | 8)
		__asm(push(i10), push(i18), op(0x3a))
		__asm(push(i17<0), iftrue, target("___vfprintf__XprivateX__BB54_328_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_327_F"))
		i10 = i17
		__asm(jump, target("___vfprintf__XprivateX__BB54_334_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_328_F"))
		i10 =  ((__xasm<int>(push((i21+15)), op(0x35))))
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_330_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_329_F"))
		i10 =  (16)
		__asm(jump, target("___vfprintf__XprivateX__BB54_334_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_330_F"))
		i10 =  (-1)
		i17 =  (i22 + 14)
	__asm(jump, target("___vfprintf__XprivateX__BB54_331_F"), lbl("___vfprintf__XprivateX__BB54_331_B"), label, lbl("___vfprintf__XprivateX__BB54_331_F")); 
		i18 =  ((__xasm<int>(push(i17), op(0x35))))
		i17 =  (i17 + -1)
		i10 =  (i10 + 1)
		__asm(push(i18!=0), iftrue, target("___vfprintf__XprivateX__BB54_333_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_332_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_331_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_333_F"))
		i10 =  (15 - i10)
	__asm(lbl("___vfprintf__XprivateX__BB54_334_F"))
		__asm(push(i10>15), iftrue, target("___vfprintf__XprivateX__BB54_337_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_335_F"))
		i17 =  (i21 + i10)
		i17 =  ((__xasm<int>(push(i17), op(0x35))))
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_337_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_336_F"))
		i17 =  ((mstate.ebp+-1760))
		mstate.esp -= 12
		__asm(push(i21), push(mstate.esp), op(0x3c))
		__asm(push(i10), push((mstate.esp+4)), op(0x3c))
		__asm(push(i17), push((mstate.esp+8)), op(0x3c))
		mstate.esp -= 4;FSM_dorounding.start()
	__asm(lbl("___vfprintf_state15"))
		mstate.esp += 12
	__asm(lbl("___vfprintf__XprivateX__BB54_337_F"))
		i17 =  (0)
		i18 =  (i21 + i10)
		__asm(push(i18), push((mstate.ebp+-1756)), op(0x3c))
		i20 =  (i10 + -1)
		__asm(push(i17), push(i18), op(0x3a))
		i17 =  (i21 + i20)
		__asm(push(uint(i17)>=uint(i21)), iftrue, target("___vfprintf__XprivateX__BB54_339_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_338_F"), lbl("___vfprintf__XprivateX__BB54_338_B"), label, lbl("___vfprintf__XprivateX__BB54_338_F")); 
		i10 = i21
		__asm(jump, target("___vfprintf__XprivateX__BB54_343_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_339_F"))
		i17 =  (0)
		i10 =  (i22 + i10)
		i10 =  (i10 + -1)
	__asm(jump, target("___vfprintf__XprivateX__BB54_340_F"), lbl("___vfprintf__XprivateX__BB54_340_B"), label, lbl("___vfprintf__XprivateX__BB54_340_F")); 
		i18 =  ((__xasm<int>(push(i10), op(0x35), op(0x51))))
		i18 =  (i7 + i18)
		i18 =  ((__xasm<int>(push(i18), op(0x35))))
		__asm(push(i18), push(i10), op(0x3a))
		i10 =  (i10 + -1)
		i18 =  (i17 + 1)
		i17 =  (i17 ^ -1)
		i17 =  (i20 + i17)
		i17 =  (i21 + i17)
		__asm(push(uint(i17)<uint(i21)), iftrue, target("___vfprintf__XprivateX__BB54_338_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_341_F"))
		i17 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_340_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_342_F"))
		i10 =  (i10 + i17)
		__asm(push(i10), push((mstate.ebp+-1756)), op(0x3c))
		i10 = i21
		__asm(jump, target("___vfprintf__XprivateX__BB54_343_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_343_F"))
		i2 =  (i2 + 1)
		__asm(push(i1<0), iftrue, target("___vfprintf__XprivateX__BB54_345_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_344_F"))
		i17 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_431_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_345_F"))
		i1 = i19
		i17 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_430_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_346_F"))
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_348_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_347_F"))
		i17 =  (i2 << 3)
		i10 =  (i10 + i17)
		__asm(jump, target("___vfprintf__XprivateX__BB54_349_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_348_F"))
		i17 =  (i12 + 8)
		i10 = i12
		i12 = i17
	__asm(lbl("___vfprintf__XprivateX__BB54_349_F"))
		i17 =  (0)
		f0 =  ((__xasm<Number>(push(i10), op(0x39))))
		__asm(push(f0), push((mstate.ebp+-1784)), op(0x3e))
		i10 =  ((__xasm<int>(push((mstate.ebp+-1780)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-1784)), op(0x37))))
		i18 =  (i10 & 2146435072)
		i21 =  (i10 >>> 31)
		i20 = i10
		__asm(push(i18==0), iftrue, target("___vfprintf__XprivateX__BB54_352_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_350_F"))
		i18 =  (i18 ^ 2146435072)
		i17 =  (i17 | i18)
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_353_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_351_F"))
		i17 =  (4)
		__asm(jump, target("___vfprintf__XprivateX__BB54_354_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_352_F"))
		i17 =  (i10 & 1048575)
		i17 =  (i17 | i19)
		i17 =  ((i17==0) ? 16 : 8)
		__asm(jump, target("___vfprintf__XprivateX__BB54_354_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_353_F"))
		i17 =  (i10 & 1048575)
		i17 =  (i17 | i19)
		i17 =  ((i17==0) ? 1 : 2)
	__asm(lbl("___vfprintf__XprivateX__BB54_354_F"))
		__asm(push(i17>3), iftrue, target("___vfprintf__XprivateX__BB54_359_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_355_F"))
		__asm(push(i17==1), iftrue, target("___vfprintf__XprivateX__BB54_369_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_356_F"))
		__asm(push(i17==2), iftrue, target("___vfprintf__XprivateX__BB54_357_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_384_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_357_F"))
		i10 =  (2147483647)
		__asm(push(i10), push((mstate.ebp+-1760)), op(0x3c))
		i10 =  ((__xasm<int>(push(_freelist), op(0x37))))
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_377_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_358_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_358_F"))
		i17 =  ((__xasm<int>(push(i10), op(0x37))))
		__asm(push(i17), push(_freelist), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_380_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_359_F"))
		__asm(push(i17==16), iftrue, target("___vfprintf__XprivateX__BB54_363_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_360_F"))
		__asm(push(i17==8), iftrue, target("___vfprintf__XprivateX__BB54_385_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_361_F"))
		__asm(push(i17!=4), iftrue, target("___vfprintf__XprivateX__BB54_384_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_362_F"))
		i10 =  (i10 >>> 20)
		i10 =  (i10 & 2047)
		i10 =  (i10 + -1022)
		i17 = i19
		i19 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_386_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_363_F"))
		i10 =  (1)
		__asm(push(i10), push((mstate.ebp+-1760)), op(0x3c))
		i10 =  ((__xasm<int>(push(_freelist), op(0x37))))
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_365_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_364_F"))
		i17 =  ((__xasm<int>(push(i10), op(0x37))))
		__asm(push(i17), push(_freelist), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_368_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_365_F"))
		i10 =  (_private_mem)
		i17 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i10 =  (i17 - i10)
		i10 =  (i10 >> 3)
		i10 =  (i10 + 3)
		__asm(push(uint(i10)>uint(288)), iftrue, target("___vfprintf__XprivateX__BB54_367_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_366_F"))
		i10 =  (0)
		i19 =  (i17 + 24)
		__asm(push(i19), push(_pmem_next), op(0x3c))
		__asm(push(i10), push((i17+4)), op(0x3c))
		i10 =  (1)
		__asm(push(i10), push((i17+8)), op(0x3c))
		i10 = i17
		__asm(jump, target("___vfprintf__XprivateX__BB54_368_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_367_F"))
		i10 =  (24)
		mstate.esp -= 8
		i17 =  (0)
		__asm(push(i17), push(mstate.esp), op(0x3c))
		__asm(push(i10), push((mstate.esp+4)), op(0x3c))
		state = 16
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___vfprintf_state16"))
		i10 = mstate.eax
		mstate.esp += 8
		__asm(push(i17), push((i10+4)), op(0x3c))
		i17 =  (1)
		__asm(push(i17), push((i10+8)), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_368_F"))
		i17 =  (0)
		__asm(push(i17), push((i10+16)), op(0x3c))
		__asm(push(i17), push((i10+12)), op(0x3c))
		__asm(push(i17), push(i10), op(0x3c))
		i19 =  (48)
		__asm(push(i19), push((i10+4)), op(0x3a))
		__asm(push(i17), push((i10+5)), op(0x3a))
		i17 =  (i10 + 5)
		__asm(push(i17), push((mstate.ebp+-1756)), op(0x3c))
		i10 =  (i10 + 4)
		__asm(jump, target("___vfprintf__XprivateX__BB54_427_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_369_F"))
		i10 =  (2147483647)
		__asm(push(i10), push((mstate.ebp+-1760)), op(0x3c))
		i10 =  ((__xasm<int>(push(_freelist), op(0x37))))
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_371_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_370_F"))
		i17 =  ((__xasm<int>(push(i10), op(0x37))))
		__asm(push(i17), push(_freelist), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_374_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_371_F"))
		i10 =  (_private_mem)
		i17 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i10 =  (i17 - i10)
		i10 =  (i10 >> 3)
		i10 =  (i10 + 3)
		__asm(push(uint(i10)>uint(288)), iftrue, target("___vfprintf__XprivateX__BB54_373_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_372_F"))
		i10 =  (0)
		i19 =  (i17 + 24)
		__asm(push(i19), push(_pmem_next), op(0x3c))
		__asm(push(i10), push((i17+4)), op(0x3c))
		i10 =  (1)
		__asm(push(i10), push((i17+8)), op(0x3c))
		i10 = i17
		__asm(jump, target("___vfprintf__XprivateX__BB54_374_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_373_F"))
		i10 =  (24)
		mstate.esp -= 8
		i17 =  (0)
		__asm(push(i17), push(mstate.esp), op(0x3c))
		__asm(push(i10), push((mstate.esp+4)), op(0x3c))
		state = 17
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___vfprintf_state17"))
		i10 = mstate.eax
		mstate.esp += 8
		__asm(push(i17), push((i10+4)), op(0x3c))
		i17 =  (1)
		__asm(push(i17), push((i10+8)), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_374_F"))
		i17 =  (0)
		__asm(push(i17), push((i10+16)), op(0x3c))
		__asm(push(i17), push((i10+12)), op(0x3c))
		__asm(push(i17), push(i10), op(0x3c))
		i19 =  (73)
		__asm(push(i19), push((i10+4)), op(0x3a))
		i10 =  (i10 + 4)
		i19 =  (__2E_str159)
		i18 = i10
	__asm(jump, target("___vfprintf__XprivateX__BB54_375_F"), lbl("___vfprintf__XprivateX__BB54_375_B"), label, lbl("___vfprintf__XprivateX__BB54_375_F")); 
		i20 =  (i19 + i17)
		i20 =  ((__xasm<int>(push((i20+1)), op(0x35))))
		i22 =  (i10 + i17)
		__asm(push(i20), push((i22+1)), op(0x3a))
		i17 =  (i17 + 1)
		__asm(push(i20==0), iftrue, target("___vfprintf__XprivateX__BB54_426_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_376_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_375_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_377_F"))
		i10 =  (_private_mem)
		i17 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i10 =  (i17 - i10)
		i10 =  (i10 >> 3)
		i10 =  (i10 + 3)
		__asm(push(uint(i10)>uint(288)), iftrue, target("___vfprintf__XprivateX__BB54_379_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_378_F"))
		i10 =  (0)
		i19 =  (i17 + 24)
		__asm(push(i19), push(_pmem_next), op(0x3c))
		__asm(push(i10), push((i17+4)), op(0x3c))
		i10 =  (1)
		__asm(push(i10), push((i17+8)), op(0x3c))
		i10 = i17
		__asm(jump, target("___vfprintf__XprivateX__BB54_380_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_379_F"))
		i10 =  (24)
		mstate.esp -= 8
		i17 =  (0)
		__asm(push(i17), push(mstate.esp), op(0x3c))
		__asm(push(i10), push((mstate.esp+4)), op(0x3c))
		state = 18
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___vfprintf_state18"))
		i10 = mstate.eax
		mstate.esp += 8
		__asm(push(i17), push((i10+4)), op(0x3c))
		i17 =  (1)
		__asm(push(i17), push((i10+8)), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_380_F"))
		i17 =  (0)
		__asm(push(i17), push((i10+16)), op(0x3c))
		__asm(push(i17), push((i10+12)), op(0x3c))
		__asm(push(i17), push(i10), op(0x3c))
		i19 =  (78)
		__asm(push(i19), push((i10+4)), op(0x3a))
		i10 =  (i10 + 4)
		i19 =  (__2E_str260)
		i18 = i10
	__asm(jump, target("___vfprintf__XprivateX__BB54_381_F"), lbl("___vfprintf__XprivateX__BB54_381_B"), label, lbl("___vfprintf__XprivateX__BB54_381_F")); 
		i20 =  (i19 + i17)
		i20 =  ((__xasm<int>(push((i20+1)), op(0x35))))
		i22 =  (i10 + i17)
		__asm(push(i20), push((i22+1)), op(0x3a))
		i17 =  (i17 + 1)
		__asm(push(i20==0), iftrue, target("___vfprintf__XprivateX__BB54_383_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_382_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_381_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_383_F"))
		i10 =  (i10 + i17)
		__asm(push(i10), push((mstate.ebp+-1756)), op(0x3c))
		i10 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_427_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_384_F"))
		state = 19
		mstate.esp -= 4;FSM_abort1.start()
		return
	__asm(lbl("___vfprintf_state19"))
	__asm(lbl("___vfprintf__XprivateX__BB54_385_F"))
		f0 =  (f0 * 5.36312e+154)
		__asm(push(f0), push((mstate.ebp+-1792)), op(0x3e))
		i19 =  ((__xasm<int>(push((mstate.ebp+-1788)), op(0x37))))
		i10 =  (i19 >>> 20)
		i10 =  (i10 & 2047)
		i17 =  ((__xasm<int>(push((mstate.ebp+-1792)), op(0x37))))
		i10 =  (i10 + -1536)
		__asm(jump, target("___vfprintf__XprivateX__BB54_386_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_386_F"))
		i18 =  ((i1==0) ? 1 : i1)
		__asm(push(i10), push((mstate.ebp+-1760)), op(0x3c))
		i10 =  ((i18>13) ? i18 : 14)
		__asm(push(uint(i10)<uint(20)), iftrue, target("___vfprintf__XprivateX__BB54_1514_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_387_F"))
		i20 =  (4)
		i22 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_388_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_388_F"), lbl("___vfprintf__XprivateX__BB54_388_B"), label, lbl("___vfprintf__XprivateX__BB54_388_F")); 
		i20 =  (i20 << 1)
		i22 =  (i22 + 1)
		i23 =  (i20 + 16)
		__asm(push(uint(i23)>uint(i10)), iftrue, target("___vfprintf__XprivateX__BB54_390_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_389_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_388_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_390_F"))
		i20 = i22
	__asm(jump, target("___vfprintf__XprivateX__BB54_391_F"), lbl("___vfprintf__XprivateX__BB54_391_B"), label, lbl("___vfprintf__XprivateX__BB54_391_F")); 
		mstate.esp -= 4
		__asm(push(i20), push(mstate.esp), op(0x3c))
		state = 20
		mstate.esp -= 4;FSM___Balloc_D2A.start()
		return
	__asm(lbl("___vfprintf_state20"))
		i22 = mstate.eax
		mstate.esp += 4
		i23 =  (i10 + -1)
		i24 =  (i22 + 4)
		__asm(push(i20), push(i22), op(0x3c))
		i20 =  (i24 + i23)
		i22 = i24
		__asm(push(i23>13), iftrue, target("___vfprintf__XprivateX__BB54_393_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_392_F"))
		i10 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_403_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_393_F"))
		i20 =  (0)
		i10 =  (i10 + i24)
		i10 =  (i10 + -1)
	__asm(jump, target("___vfprintf__XprivateX__BB54_394_F"), lbl("___vfprintf__XprivateX__BB54_394_B"), label, lbl("___vfprintf__XprivateX__BB54_394_F")); 
		i25 =  (0)
		i26 =  (i20 ^ -1)
		__asm(push(i25), push(i10), op(0x3a))
		i10 =  (i10 + -1)
		i20 =  (i20 + 1)
		i25 =  (i23 + i26)
		__asm(push(i25<14), iftrue, target("___vfprintf__XprivateX__BB54_402_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_395_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_394_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_396_B"), label)
		i20 = i19
		__asm(jump, target("___vfprintf__XprivateX__BB54_397_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_397_F"), lbl("___vfprintf__XprivateX__BB54_397_B"), label, lbl("___vfprintf__XprivateX__BB54_397_F")); 
		i19 = i20
		i20 = i23
		i23 =  (i17 & 15)
		i27 =  (i20 ^ -1)
		__asm(push(i23), push(i19), op(0x3a))
		i19 =  (i19 + -1)
		i23 =  (i20 + 1)
		i20 =  (i26 + i27)
		i17 =  (i17 >>> 4)
		__asm(push(uint(i25)>=uint(i20)), iftrue, target("___vfprintf__XprivateX__BB54_399_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_398_F"))
		__asm(push(uint(i20)>uint(i22)), iftrue, target("___vfprintf__XprivateX__BB54_396_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_399_F"))
		i19 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_400_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_400_F"), lbl("___vfprintf__XprivateX__BB54_400_B"), label, lbl("___vfprintf__XprivateX__BB54_400_F")); 
		i25 = i17
		i26 = i10
		i10 = i19
		i19 = i26
		i17 = i10
		__asm(push(uint(i10)>uint(i22)), iftrue, target("___vfprintf__XprivateX__BB54_1515_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_401_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_401_F"))
		i17 = i19
		__asm(jump, target("___vfprintf__XprivateX__BB54_410_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_402_F"))
		i10 =  (i22 + i25)
	__asm(lbl("___vfprintf__XprivateX__BB54_403_F"))
		i26 = i10
		i25 =  (i22 + 5)
		i10 = i26
		__asm(push(uint(i25)>=uint(i26)), iftrue, target("___vfprintf__XprivateX__BB54_405_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_404_F"))
		__asm(push(uint(i26)>uint(i22)), iftrue, target("___vfprintf__XprivateX__BB54_406_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_405_F"))
		i10 = i19
		i19 = i26
		__asm(jump, target("___vfprintf__XprivateX__BB54_400_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_406_F"))
		i23 =  (0)
		i20 = i10
		i10 = i19
		__asm(jump, target("___vfprintf__XprivateX__BB54_397_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_407_B"), label)
		i23 = i26
		__asm(jump, target("___vfprintf__XprivateX__BB54_408_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_408_F"), lbl("___vfprintf__XprivateX__BB54_408_B"), label, lbl("___vfprintf__XprivateX__BB54_408_F")); 
		i26 =  (i19 >>> 4)
		i23 =  (i23 & 15)
		i27 =  (i17 ^ -1)
		i19 =  (i19 & -1048576)
		i26 =  (i26 & 65535)
		__asm(push(i23), push(i20), op(0x3a))
		i19 =  (i26 | i19)
		i20 =  (i20 + -1)
		i17 =  (i17 + 1)
		i23 =  (i10 + i27)
		i26 = i19
		__asm(push(uint(i23)>uint(i22)), iftrue, target("___vfprintf__XprivateX__BB54_407_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_409_F"))
		i17 = i26
		i10 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_410_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_410_F"))
		i17 =  (i17 | 1)
		__asm(push(i17), push(i10), op(0x3a))
		__asm(push(i18<0), iftrue, target("___vfprintf__XprivateX__BB54_412_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_411_F"))
		i10 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_418_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_412_F"))
		i10 =  ((__xasm<int>(push((i22+13)), op(0x35))))
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_414_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_413_F"))
		i10 =  (14)
		__asm(jump, target("___vfprintf__XprivateX__BB54_418_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_414_F"))
		i10 =  (-1)
		i17 =  (i24 + 12)
	__asm(jump, target("___vfprintf__XprivateX__BB54_415_F"), lbl("___vfprintf__XprivateX__BB54_415_B"), label, lbl("___vfprintf__XprivateX__BB54_415_F")); 
		i19 =  ((__xasm<int>(push(i17), op(0x35))))
		i17 =  (i17 + -1)
		i10 =  (i10 + 1)
		__asm(push(i19!=0), iftrue, target("___vfprintf__XprivateX__BB54_417_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_416_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_415_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_417_F"))
		i10 =  (13 - i10)
	__asm(lbl("___vfprintf__XprivateX__BB54_418_F"))
		__asm(push(i10>13), iftrue, target("___vfprintf__XprivateX__BB54_421_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_419_F"))
		i17 =  (i22 + i10)
		i17 =  ((__xasm<int>(push(i17), op(0x35))))
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_421_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_420_F"))
		i17 =  ((mstate.ebp+-1760))
		mstate.esp -= 12
		__asm(push(i22), push(mstate.esp), op(0x3c))
		__asm(push(i10), push((mstate.esp+4)), op(0x3c))
		__asm(push(i17), push((mstate.esp+8)), op(0x3c))
		mstate.esp -= 4;FSM_dorounding.start()
	__asm(lbl("___vfprintf_state21"))
		mstate.esp += 12
	__asm(lbl("___vfprintf__XprivateX__BB54_421_F"))
		i17 =  (0)
		i19 =  (i22 + i10)
		__asm(push(i19), push((mstate.ebp+-1756)), op(0x3c))
		i18 =  (i10 + -1)
		__asm(push(i17), push(i19), op(0x3a))
		i17 =  (i22 + i18)
		__asm(push(uint(i17)>=uint(i22)), iftrue, target("___vfprintf__XprivateX__BB54_423_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_422_F"), lbl("___vfprintf__XprivateX__BB54_422_B"), label, lbl("___vfprintf__XprivateX__BB54_422_F")); 
		i10 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_427_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_423_F"))
		i17 =  (0)
		i10 =  (i24 + i10)
		i10 =  (i10 + -1)
	__asm(jump, target("___vfprintf__XprivateX__BB54_424_F"), lbl("___vfprintf__XprivateX__BB54_424_B"), label, lbl("___vfprintf__XprivateX__BB54_424_F")); 
		i19 =  ((__xasm<int>(push(i10), op(0x35), op(0x51))))
		i19 =  (i7 + i19)
		i19 =  ((__xasm<int>(push(i19), op(0x35))))
		__asm(push(i19), push(i10), op(0x3a))
		i10 =  (i10 + -1)
		i19 =  (i17 + 1)
		i17 =  (i17 ^ -1)
		i17 =  (i18 + i17)
		i17 =  (i22 + i17)
		__asm(push(uint(i17)<uint(i22)), iftrue, target("___vfprintf__XprivateX__BB54_422_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_425_F"))
		i17 = i19
		__asm(jump, target("___vfprintf__XprivateX__BB54_424_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_426_F"))
		i10 =  (i10 + i17)
		__asm(push(i10), push((mstate.ebp+-1756)), op(0x3c))
		i10 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_427_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_427_F"))
		i2 =  (i2 + 1)
		__asm(push(i1<0), iftrue, target("___vfprintf__XprivateX__BB54_429_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_428_F"))
		i19 = i21
		i17 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_431_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_429_F"))
		i1 = i21
		i17 = i10
	__asm(lbl("___vfprintf__XprivateX__BB54_430_F"))
		i19 =  ((__xasm<int>(push((mstate.ebp+-1756)), op(0x37))))
		i18 =  (i19 - i17)
		i19 = i1
		i1 = i18
	__asm(lbl("___vfprintf__XprivateX__BB54_431_F"))
		i18 = i19
		i19 =  ((__xasm<int>(push((mstate.ebp+-1760)), op(0x37))))
		__asm(push(i19==2147483647), iftrue, target("___vfprintf__XprivateX__BB54_433_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_432_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_883_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_433_F"))
		i21 =  (0)
		i20 =  ((__xasm<int>(push((mstate.ebp+-2169)), op(0x37))))
		__asm(push(i21), push(i20), op(0x3a))
		__asm(push(i18==0), iftrue, target("___vfprintf__XprivateX__BB54_435_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_434_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_885_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_435_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_886_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_436_F"))
		i1 =  (i1 + 1)
		i1 =  ((i1<0) ? 6 : i1)
		__asm(push(i21==0), iftrue, target("___vfprintf__XprivateX__BB54_438_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_437_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_442_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_438_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_445_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_439_F"))
		i1 =  (1)
	__asm(lbl("___vfprintf__XprivateX__BB54_440_F"))
		i1 =  ((i1<0) ? 6 : i1)
		__asm(push(i21==0), iftrue, target("___vfprintf__XprivateX__BB54_1516_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_441_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_442_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_442_F"))
		i10 =  (1)
		i13 =  ((__xasm<int>(push((i21+-4)), op(0x37))))
		__asm(push(i13), push(i21), op(0x3c))
		i10 =  (i10 << i13)
		__asm(push(i10), push((i21+4)), op(0x3c))
		i10 =  (i21 + -4)
		i17 = i10
		__asm(push(i10!=0), iftrue, target("___vfprintf__XprivateX__BB54_444_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_443_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_445_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_444_F"))
		i19 =  (_freelist)
		i13 =  (i13 << 2)
		i13 =  (i19 + i13)
		i19 =  ((__xasm<int>(push(i13), op(0x37))))
		__asm(push(i19), push(i10), op(0x3c))
		__asm(push(i17), push(i13), op(0x3c))
	__asm(jump, target("___vfprintf__XprivateX__BB54_445_F"), lbl("___vfprintf__XprivateX__BB54_445_B"), label, lbl("___vfprintf__XprivateX__BB54_445_F")); 
		__asm(push(i7), push((mstate.ebp+-2421)), op(0x3c))
		i7 = i1
		__asm(push(i7), push((mstate.ebp+-2511)), op(0x3c))
		i7 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		i1 =  (i8 & 8)
		__asm(push(i1==0), iftrue, target("___vfprintf__XprivateX__BB54_477_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_446_F"))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_448_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_447_F"))
		i1 =  (i2 << 3)
		i7 =  (i7 + i1)
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_449_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_448_F"))
		i1 =  (i12 + 8)
		i7 = i12
	__asm(lbl("___vfprintf__XprivateX__BB54_449_F"))
		i12 = i1
		i1 =  (0)
		f0 =  ((__xasm<Number>(push(i7), op(0x39))))
		i7 =  ((__xasm<int>(push((mstate.ebp+-2124)), op(0x37))))
		__asm(push(f0), push(i7), op(0x3e))
		i7 =  ((__xasm<int>(push((mstate.ebp+-2016)), op(0x37))))
		i7 =  ((__xasm<int>(push(i7), op(0x37))))
		i10 =  ((__xasm<int>(push((mstate.ebp+-2034)), op(0x37))))
		i10 =  ((__xasm<int>(push(i10), op(0x37))))
		i13 =  ((__xasm<int>(push((mstate.ebp+-2160)), op(0x37))))
		__asm(push(i10), push(i13), op(0x3c))
		i10 =  ((__xasm<int>(push((mstate.ebp+-2007)), op(0x37))))
		i10 =  ((__xasm<int>(push(i10), op(0x37))))
		i13 =  ((__xasm<int>(push((mstate.ebp+-1998)), op(0x37))))
		__asm(push(i10), push(i13), op(0x3c))
		i10 =  ((__xasm<int>(push((mstate.ebp+-2124)), op(0x37))))
		i10 =  ((__xasm<int>(push((i10+4)), op(0x37))))
		i13 =  ((__xasm<int>(push((mstate.ebp+-2124)), op(0x37))))
		i13 =  ((__xasm<int>(push(i13), op(0x37))))
		i17 =  ((__xasm<int>(push((mstate.ebp+-2421)), op(0x37))))
		i17 =  (i17 & 255)
		i19 =  (i7 & 32767)
		i7 =  (i7 >>> 15)
		i18 =  (i10 & 2146435072)
		i17 =  ((i17==0) ? 3 : 2)
		i19 =  (i19 + -16446)
		i7 =  (i7 & 1)
		i2 =  (i2 + 1)
		__asm(push(i18==0), iftrue, target("___vfprintf__XprivateX__BB54_452_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_450_F"))
		i18 =  (i18 ^ 2146435072)
		i1 =  (i1 | i18)
		__asm(push(i1==0), iftrue, target("___vfprintf__XprivateX__BB54_453_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_451_F"))
		i1 =  (4)
		__asm(jump, target("___vfprintf__XprivateX__BB54_454_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_452_F"))
		i1 =  (i10 & 1048575)
		i1 =  (i1 | i13)
		i1 =  ((i1==0) ? 16 : 8)
		__asm(jump, target("___vfprintf__XprivateX__BB54_454_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_453_F"))
		i1 =  (i10 & 1048575)
		i1 =  (i1 | i13)
		i1 =  ((i1==0) ? 1 : 2)
	__asm(lbl("___vfprintf__XprivateX__BB54_454_F"))
		__asm(push(i1>3), iftrue, target("___vfprintf__XprivateX__BB54_459_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_455_F"))
		__asm(push(i1==1), iftrue, target("___vfprintf__XprivateX__BB54_470_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_456_F"))
		__asm(push(i1==2), iftrue, target("___vfprintf__XprivateX__BB54_457_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_474_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_457_F"))
		i1 =  (4)
		__asm(push(i1), push((mstate.ebp+-36)), op(0x3c))
		mstate.esp -= 28
		i1 =  ((mstate.ebp+-1756))
		i10 =  ((mstate.ebp+-1760))
		i13 =  ((mstate.ebp+-36))
		__asm(push(i19), push(mstate.esp), op(0x3c))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2160)), op(0x37))))
		__asm(push(i19), push((mstate.esp+4)), op(0x3c))
		__asm(push(i13), push((mstate.esp+8)), op(0x3c))
		__asm(push(i17), push((mstate.esp+12)), op(0x3c))
		i13 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		__asm(push(i13), push((mstate.esp+16)), op(0x3c))
		__asm(push(i10), push((mstate.esp+20)), op(0x3c))
		__asm(push(i1), push((mstate.esp+24)), op(0x3c))
		state = 22
		mstate.esp -= 4;FSM___gdtoa.start()
		return
	__asm(lbl("___vfprintf_state22"))
		i10 = mstate.eax
		mstate.esp += 28
		i1 =  ((__xasm<int>(push((mstate.ebp+-1760)), op(0x37))))
		__asm(push(i1==-32768), iftrue, target("___vfprintf__XprivateX__BB54_473_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_458_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_458_F"))
		i19 = i1
		i18 = i7
		i17 = i10
		i7 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		i1 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2421)), op(0x37))))
		i13 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_883_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_459_F"))
		__asm(push(i1==16), iftrue, target("___vfprintf__XprivateX__BB54_464_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_460_F"))
		__asm(push(i1==8), iftrue, target("___vfprintf__XprivateX__BB54_467_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_461_F"))
		__asm(push(i1!=4), iftrue, target("___vfprintf__XprivateX__BB54_474_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_462_F"))
		i1 =  (1)
		__asm(push(i1), push((mstate.ebp+-36)), op(0x3c))
		mstate.esp -= 28
		i1 =  ((mstate.ebp+-1756))
		i10 =  ((mstate.ebp+-1760))
		i13 =  ((mstate.ebp+-36))
		__asm(push(i19), push(mstate.esp), op(0x3c))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2160)), op(0x37))))
		__asm(push(i19), push((mstate.esp+4)), op(0x3c))
		__asm(push(i13), push((mstate.esp+8)), op(0x3c))
		__asm(push(i17), push((mstate.esp+12)), op(0x3c))
		i17 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		__asm(push(i17), push((mstate.esp+16)), op(0x3c))
		__asm(push(i10), push((mstate.esp+20)), op(0x3c))
		__asm(push(i1), push((mstate.esp+24)), op(0x3c))
		state = 23
		mstate.esp -= 4;FSM___gdtoa.start()
		return
	__asm(lbl("___vfprintf_state23"))
		i10 = mstate.eax
		mstate.esp += 28
		i1 =  ((__xasm<int>(push((mstate.ebp+-1760)), op(0x37))))
		__asm(push(i1==-32768), iftrue, target("___vfprintf__XprivateX__BB54_475_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_463_F"))
		i19 = i1
		i18 = i7
		i17 = i10
		i7 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		i1 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2421)), op(0x37))))
		i13 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_883_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_464_F"))
		i1 =  (0)
		__asm(push(i1), push((mstate.ebp+-36)), op(0x3c))
		mstate.esp -= 28
		i1 =  ((mstate.ebp+-1756))
		i10 =  ((mstate.ebp+-1760))
		i13 =  ((mstate.ebp+-36))
		__asm(push(i19), push(mstate.esp), op(0x3c))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2160)), op(0x37))))
		__asm(push(i19), push((mstate.esp+4)), op(0x3c))
		__asm(push(i13), push((mstate.esp+8)), op(0x3c))
		__asm(push(i17), push((mstate.esp+12)), op(0x3c))
		i17 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		__asm(push(i17), push((mstate.esp+16)), op(0x3c))
		__asm(push(i10), push((mstate.esp+20)), op(0x3c))
		__asm(push(i1), push((mstate.esp+24)), op(0x3c))
		state = 24
		mstate.esp -= 4;FSM___gdtoa.start()
		return
	__asm(lbl("___vfprintf_state24"))
		i10 = mstate.eax
		mstate.esp += 28
		i1 =  ((__xasm<int>(push((mstate.ebp+-1760)), op(0x37))))
		__asm(push(i1==-32768), iftrue, target("___vfprintf__XprivateX__BB54_466_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_465_F"))
		i19 = i1
		i18 = i7
		i17 = i10
		i7 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		i1 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2421)), op(0x37))))
		i13 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_883_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_466_F"))
		i1 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_476_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_467_F"))
		i1 =  (2)
		__asm(push(i1), push((mstate.ebp+-36)), op(0x3c))
		mstate.esp -= 28
		i1 =  ((mstate.ebp+-1756))
		i10 =  ((mstate.ebp+-1760))
		i13 =  ((mstate.ebp+-36))
		__asm(push(i19), push(mstate.esp), op(0x3c))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2160)), op(0x37))))
		__asm(push(i19), push((mstate.esp+4)), op(0x3c))
		__asm(push(i13), push((mstate.esp+8)), op(0x3c))
		__asm(push(i17), push((mstate.esp+12)), op(0x3c))
		i17 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		__asm(push(i17), push((mstate.esp+16)), op(0x3c))
		__asm(push(i10), push((mstate.esp+20)), op(0x3c))
		__asm(push(i1), push((mstate.esp+24)), op(0x3c))
		state = 25
		mstate.esp -= 4;FSM___gdtoa.start()
		return
	__asm(lbl("___vfprintf_state25"))
		i10 = mstate.eax
		mstate.esp += 28
		i1 =  ((__xasm<int>(push((mstate.ebp+-1760)), op(0x37))))
		__asm(push(i1==-32768), iftrue, target("___vfprintf__XprivateX__BB54_469_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_468_F"))
		i19 = i1
		i18 = i7
		i17 = i10
		i7 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		i1 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2421)), op(0x37))))
		i13 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_883_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_469_F"))
		i1 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_476_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_470_F"))
		i1 =  (3)
		__asm(push(i1), push((mstate.ebp+-36)), op(0x3c))
		mstate.esp -= 28
		i1 =  ((mstate.ebp+-1756))
		i10 =  ((mstate.ebp+-1760))
		i13 =  ((mstate.ebp+-36))
		__asm(push(i19), push(mstate.esp), op(0x3c))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2160)), op(0x37))))
		__asm(push(i19), push((mstate.esp+4)), op(0x3c))
		__asm(push(i13), push((mstate.esp+8)), op(0x3c))
		__asm(push(i17), push((mstate.esp+12)), op(0x3c))
		i17 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		__asm(push(i17), push((mstate.esp+16)), op(0x3c))
		__asm(push(i10), push((mstate.esp+20)), op(0x3c))
		__asm(push(i1), push((mstate.esp+24)), op(0x3c))
		state = 26
		mstate.esp -= 4;FSM___gdtoa.start()
		return
	__asm(lbl("___vfprintf_state26"))
		i10 = mstate.eax
		mstate.esp += 28
		i1 =  ((__xasm<int>(push((mstate.ebp+-1760)), op(0x37))))
		__asm(push(i1==-32768), iftrue, target("___vfprintf__XprivateX__BB54_472_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_471_F"))
		i19 = i1
		i18 = i7
		i17 = i10
		i7 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		i1 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2421)), op(0x37))))
		i13 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_883_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_472_F"))
		i1 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_476_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_473_F"))
		i1 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_476_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_474_F"))
		state = 27
		mstate.esp -= 4;FSM_abort1.start()
		return
	__asm(lbl("___vfprintf_state27"))
	__asm(lbl("___vfprintf__XprivateX__BB54_475_F"))
		i1 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_476_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_476_F"))
		i10 = i1
		i1 =  (2147483647)
		__asm(push(i1), push((mstate.ebp+-1760)), op(0x3c))
		i19 = i1
		i18 = i7
		i17 = i10
		i7 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		i1 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2421)), op(0x37))))
		i13 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_883_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_477_F"))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_479_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_478_F"))
		i1 =  (i2 << 3)
		i7 =  (i7 + i1)
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_480_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_479_F"))
		i1 =  (i12 + 8)
		i7 = i12
	__asm(lbl("___vfprintf__XprivateX__BB54_480_F"))
		__asm(push(i1), push((mstate.ebp+-2367)), op(0x3c))
		i1 =  ((__xasm<int>(push((mstate.ebp+-2421)), op(0x37))))
		i1 =  (i1 & 255)
		i10 =  ((__xasm<int>(push(i7), op(0x37))))
		i7 =  ((__xasm<int>(push((i7+4)), op(0x37))))
		i1 =  ((i1==0) ? 3 : 2)
		i2 =  (i2 + 1)
		__asm(push(i2), push((mstate.ebp+-2376)), op(0x3c))
		__asm(push(i7>-1), iftrue, target("___vfprintf__XprivateX__BB54_487_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_481_F"))
		i2 =  (i7 & 2147483647)
		i7 =  (i7 & 2146435072)
		i7 =  (i7 ^ 2146435072)
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_486_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_482_F"))
		i7 =  (1)
		i12 = i7
		i7 = i2
		__asm(jump, target("___vfprintf__XprivateX__BB54_483_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_483_F"), lbl("___vfprintf__XprivateX__BB54_483_B"), label, lbl("___vfprintf__XprivateX__BB54_483_F")); 
		i2 = i12
		__asm(push(i2), push((mstate.ebp+-2385)), op(0x3c))
		i2 = i10
		f0 =  (0)
		__asm(push(i2), push((mstate.ebp+-1800)), op(0x3c))
		__asm(push(i7), push((mstate.ebp+-1796)), op(0x3c))
		f1 =  ((__xasm<Number>(push((mstate.ebp+-1800)), op(0x39))))
		__asm(push(f1!=f0), iftrue, target("___vfprintf__XprivateX__BB54_514_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_484_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_484_F"))
		i7 =  (1)
		__asm(push(i7), push((mstate.ebp+-1760)), op(0x3c))
		i7 =  ((__xasm<int>(push(_freelist), op(0x37))))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_510_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_485_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_485_F"))
		i1 =  ((__xasm<int>(push(i7), op(0x37))))
		__asm(push(i1), push(_freelist), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_513_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_486_F"))
		i7 =  (1)
		i1 = i7
		i7 = i2
		__asm(jump, target("___vfprintf__XprivateX__BB54_490_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_487_F"))
		i2 =  (i7 & 2146435072)
		i2 =  (i2 ^ 2146435072)
		__asm(push(i2==0), iftrue, target("___vfprintf__XprivateX__BB54_489_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_488_F"))
		i2 =  (0)
		i12 = i2
		__asm(jump, target("___vfprintf__XprivateX__BB54_483_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_489_F"))
		i1 =  (0)
	__asm(lbl("___vfprintf__XprivateX__BB54_490_F"))
		i2 = i10
		i10 =  (9999)
		__asm(push(i10), push((mstate.ebp+-1760)), op(0x3c))
		__asm(push(i2!=0), iftrue, target("___vfprintf__XprivateX__BB54_501_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_491_F"))
		i7 =  (i7 & 1048575)
		__asm(push(i7!=0), iftrue, target("___vfprintf__XprivateX__BB54_501_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_492_F"))
		i7 =  ((__xasm<int>(push(_freelist), op(0x37))))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_494_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_493_F"))
		i2 =  ((__xasm<int>(push(i7), op(0x37))))
		__asm(push(i2), push(_freelist), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_497_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_494_F"))
		i7 =  (_private_mem)
		i2 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i7 =  (i2 - i7)
		i7 =  (i7 >> 3)
		i7 =  (i7 + 3)
		__asm(push(uint(i7)>uint(288)), iftrue, target("___vfprintf__XprivateX__BB54_496_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_495_F"))
		i7 =  (0)
		i10 =  (i2 + 24)
		__asm(push(i10), push(_pmem_next), op(0x3c))
		__asm(push(i7), push((i2+4)), op(0x3c))
		i7 =  (1)
		__asm(push(i7), push((i2+8)), op(0x3c))
		i7 = i2
		__asm(jump, target("___vfprintf__XprivateX__BB54_497_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_496_F"))
		i7 =  (24)
		mstate.esp -= 4
		__asm(push(i7), push(mstate.esp), op(0x3c))
		state = 28
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___vfprintf_state28"))
		i7 = mstate.eax
		mstate.esp += 4
		i2 =  (0)
		__asm(push(i2), push((i7+4)), op(0x3c))
		i2 =  (1)
		__asm(push(i2), push((i7+8)), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_497_F"))
		i2 =  (0)
		__asm(push(i2), push((i7+16)), op(0x3c))
		__asm(push(i2), push((i7+12)), op(0x3c))
		__asm(push(i2), push(i7), op(0x3c))
		i10 =  (73)
		__asm(push(i10), push((i7+4)), op(0x3a))
		i7 =  (i7 + 4)
		i10 =  (__2E_str159)
		i12 = i7
	__asm(jump, target("___vfprintf__XprivateX__BB54_498_F"), lbl("___vfprintf__XprivateX__BB54_498_B"), label, lbl("___vfprintf__XprivateX__BB54_498_F")); 
		i13 =  (i10 + i2)
		i13 =  ((__xasm<int>(push((i13+1)), op(0x35))))
		i17 =  (i7 + i2)
		__asm(push(i13), push((i17+1)), op(0x3a))
		i2 =  (i2 + 1)
		__asm(push(i13==0), iftrue, target("___vfprintf__XprivateX__BB54_500_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_499_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_498_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_500_F"))
		i7 =  (i7 + i2)
		__asm(push(i7), push((mstate.ebp+-1756)), op(0x3c))
		i7 = i1
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_880_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_501_F"))
		i7 =  ((__xasm<int>(push(_freelist), op(0x37))))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_503_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_502_F"))
		i2 =  ((__xasm<int>(push(i7), op(0x37))))
		__asm(push(i2), push(_freelist), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_506_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_503_F"))
		i7 =  (_private_mem)
		i2 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i7 =  (i2 - i7)
		i7 =  (i7 >> 3)
		i7 =  (i7 + 3)
		__asm(push(uint(i7)>uint(288)), iftrue, target("___vfprintf__XprivateX__BB54_505_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_504_F"))
		i7 =  (0)
		i10 =  (i2 + 24)
		__asm(push(i10), push(_pmem_next), op(0x3c))
		__asm(push(i7), push((i2+4)), op(0x3c))
		i7 =  (1)
		__asm(push(i7), push((i2+8)), op(0x3c))
		i7 = i2
		__asm(jump, target("___vfprintf__XprivateX__BB54_506_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_505_F"))
		i7 =  (24)
		mstate.esp -= 4
		__asm(push(i7), push(mstate.esp), op(0x3c))
		state = 29
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___vfprintf_state29"))
		i7 = mstate.eax
		mstate.esp += 4
		i2 =  (0)
		__asm(push(i2), push((i7+4)), op(0x3c))
		i2 =  (1)
		__asm(push(i2), push((i7+8)), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_506_F"))
		i2 =  (0)
		__asm(push(i2), push((i7+16)), op(0x3c))
		__asm(push(i2), push((i7+12)), op(0x3c))
		__asm(push(i2), push(i7), op(0x3c))
		i10 =  (78)
		__asm(push(i10), push((i7+4)), op(0x3a))
		i7 =  (i7 + 4)
		i10 =  (__2E_str260)
		i12 = i7
	__asm(jump, target("___vfprintf__XprivateX__BB54_507_F"), lbl("___vfprintf__XprivateX__BB54_507_B"), label, lbl("___vfprintf__XprivateX__BB54_507_F")); 
		i13 =  (i10 + i2)
		i13 =  ((__xasm<int>(push((i13+1)), op(0x35))))
		i17 =  (i7 + i2)
		__asm(push(i13), push((i17+1)), op(0x3a))
		i2 =  (i2 + 1)
		__asm(push(i13==0), iftrue, target("___vfprintf__XprivateX__BB54_509_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_508_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_507_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_509_F"))
		i7 =  (i7 + i2)
		__asm(push(i7), push((mstate.ebp+-1756)), op(0x3c))
		i7 = i1
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_880_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_510_F"))
		i7 =  (_private_mem)
		i1 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i7 =  (i1 - i7)
		i7 =  (i7 >> 3)
		i7 =  (i7 + 3)
		__asm(push(uint(i7)>uint(288)), iftrue, target("___vfprintf__XprivateX__BB54_512_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_511_F"))
		i7 =  (0)
		i2 =  (i1 + 24)
		__asm(push(i2), push(_pmem_next), op(0x3c))
		__asm(push(i7), push((i1+4)), op(0x3c))
		i7 =  (1)
		__asm(push(i7), push((i1+8)), op(0x3c))
		i7 = i1
		__asm(jump, target("___vfprintf__XprivateX__BB54_513_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_512_F"))
		i7 =  (24)
		mstate.esp -= 4
		__asm(push(i7), push(mstate.esp), op(0x3c))
		state = 30
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___vfprintf_state30"))
		i7 = mstate.eax
		mstate.esp += 4
		i1 =  (0)
		__asm(push(i1), push((i7+4)), op(0x3c))
		i1 =  (1)
		__asm(push(i1), push((i7+8)), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_513_F"))
		i1 =  (0)
		__asm(push(i1), push((i7+16)), op(0x3c))
		__asm(push(i1), push((i7+12)), op(0x3c))
		__asm(push(i1), push(i7), op(0x3c))
		i2 =  (48)
		__asm(push(i2), push((i7+4)), op(0x3a))
		__asm(push(i1), push((i7+5)), op(0x3a))
		i1 =  (i7 + 5)
		__asm(push(i1), push((mstate.ebp+-1756)), op(0x3c))
		i1 =  (i7 + 4)
		i7 =  ((__xasm<int>(push((mstate.ebp+-2385)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_880_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_514_F"))
		i10 =  ((__xasm<int>(push((_freelist+4)), op(0x37))))
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_516_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_515_F"))
		i12 =  ((__xasm<int>(push(i10), op(0x37))))
		__asm(push(i12), push((_freelist+4)), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_519_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_516_F"))
		i10 =  (_private_mem)
		i12 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i10 =  (i12 - i10)
		i10 =  (i10 >> 3)
		i10 =  (i10 + 4)
		__asm(push(uint(i10)>uint(288)), iftrue, target("___vfprintf__XprivateX__BB54_518_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_517_F"))
		i10 =  (1)
		i13 =  (i12 + 32)
		__asm(push(i13), push(_pmem_next), op(0x3c))
		__asm(push(i10), push((i12+4)), op(0x3c))
		i10 =  (2)
		__asm(push(i10), push((i12+8)), op(0x3c))
		i10 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_519_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_518_F"))
		i10 =  (32)
		mstate.esp -= 4
		__asm(push(i10), push(mstate.esp), op(0x3c))
		state = 31
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___vfprintf_state31"))
		i10 = mstate.eax
		mstate.esp += 4
		i12 =  (1)
		__asm(push(i12), push((i10+4)), op(0x3c))
		i12 =  (2)
		__asm(push(i12), push((i10+8)), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_519_F"))
		i12 =  (0)
		i13 =  (i7 & 2147483647)
		__asm(push(i12), push((i10+16)), op(0x3c))
		i17 =  ((uint(i13)<uint(1048576)) ? 0 : 1048576)
		i19 =  (i7 & 1048575)
		__asm(push(i12), push((i10+12)), op(0x3c))
		i12 =  (i19 | i17)
		__asm(push(i12), push((mstate.ebp+-4)), op(0x3c))
		__asm(push(i2), push((mstate.ebp+-8)), op(0x3c))
		i12 =  (i13 >>> 20)
		i17 =  (i10 + 20)
		i19 =  (i10 + 16)
		i18 = i7
		__asm(push(i2==0), iftrue, target("___vfprintf__XprivateX__BB54_525_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_520_F"))
		i21 =  ((mstate.ebp+-8))
		mstate.esp -= 4
		__asm(push(i21), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM___lo0bits_D2A.start()
	__asm(lbl("___vfprintf_state32"))
		i21 = mstate.eax
		mstate.esp += 4
		__asm(push(i21==0), iftrue, target("___vfprintf__XprivateX__BB54_522_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_521_F"))
		i20 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i22 =  (32 - i21)
		i23 =  ((__xasm<int>(push((mstate.ebp+-8)), op(0x37))))
		i20 =  (i20 << i22)
		i20 =  (i20 | i23)
		__asm(push(i20), push(i17), op(0x3c))
		i17 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i17 =  (i17 >>> i21)
		__asm(push(i17), push((mstate.ebp+-4)), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_523_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_522_F"))
		i20 =  ((__xasm<int>(push((mstate.ebp+-8)), op(0x37))))
		__asm(push(i20), push(i17), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_523_F"))
		i17 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i17), push((i10+24)), op(0x3c))
		i17 =  ((i17==0) ? 1 : 2)
		__asm(push(i17), push(i19), op(0x3c))
		__asm(push(uint(i13)<uint(1048576)), iftrue, target("___vfprintf__XprivateX__BB54_528_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_524_F"))
		i17 = i21
		__asm(jump, target("___vfprintf__XprivateX__BB54_527_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_525_F"))
		i21 =  ((mstate.ebp+-4))
		mstate.esp -= 4
		__asm(push(i21), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM___lo0bits_D2A.start()
	__asm(lbl("___vfprintf_state33"))
		i21 = mstate.eax
		mstate.esp += 4
		i20 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i20), push(i17), op(0x3c))
		i17 =  (1)
		__asm(push(i17), push(i19), op(0x3c))
		i19 =  (i21 + 32)
		__asm(push(uint(i13)<uint(1048576)), iftrue, target("___vfprintf__XprivateX__BB54_1517_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_526_F"))
		i17 = i19
		__asm(jump, target("___vfprintf__XprivateX__BB54_527_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_527_F"))
		i13 = i17
		i17 =  (53)
		i12 =  (i12 + -1075)
		i19 = i13
		__asm(jump, target("___vfprintf__XprivateX__BB54_533_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_528_F"))
		i13 = i21
		__asm(jump, target("___vfprintf__XprivateX__BB54_529_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_529_F"), lbl("___vfprintf__XprivateX__BB54_529_B"), label, lbl("___vfprintf__XprivateX__BB54_529_F")); 
		i19 =  (i17 << 2)
		i19 =  (i19 + i10)
		i19 =  ((__xasm<int>(push((i19+16)), op(0x37))))
		i21 =  ((uint(i19)<uint(65536)) ? 16 : 0)
		i19 =  (i19 << i21)
		i20 =  ((uint(i19)<uint(16777216)) ? 8 : 0)
		i19 =  (i19 << i20)
		i22 =  ((uint(i19)<uint(268435456)) ? 4 : 0)
		i21 =  (i20 | i21)
		i19 =  (i19 << i22)
		i20 =  ((uint(i19)<uint(1073741824)) ? 2 : 0)
		i21 =  (i21 | i22)
		i21 =  (i21 | i20)
		i19 =  (i19 << i20)
		i12 =  (i12 + -1074)
		__asm(push(i19>-1), iftrue, target("___vfprintf__XprivateX__BB54_531_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_530_F"))
		i19 = i21
		__asm(jump, target("___vfprintf__XprivateX__BB54_532_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_531_F"))
		i19 =  (i19 & 1073741824)
		i21 =  (i21 + 1)
		i19 =  ((i19==0) ? 32 : i21)
	__asm(lbl("___vfprintf__XprivateX__BB54_532_F"))
		i21 = i19
		i17 =  (i17 << 5)
		i19 = i13
		i13 = i21
	__asm(lbl("___vfprintf__XprivateX__BB54_533_F"))
		i21 =  (i18 >>> 20)
		i21 =  (i21 & 2047)
		i13 =  (i17 - i13)
		__asm(push(i13), push((mstate.ebp+-2430)), op(0x3c))
		i12 =  (i12 + i19)
		__asm(push(i12), push((mstate.ebp+-2439)), op(0x3c))
		__asm(push(i21==0), iftrue, target("___vfprintf__XprivateX__BB54_535_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_534_F"))
		i12 =  (0)
		i13 =  (i7 | 1072693248)
		i13 =  (i13 & 1073741823)
		i17 =  (i21 + -1023)
		i19 = i12
		i18 = i2
		i21 = i7
		__asm(jump, target("___vfprintf__XprivateX__BB54_538_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_535_F"))
		i13 =  ((__xasm<int>(push((mstate.ebp+-2439)), op(0x37))))
		i12 =  ((__xasm<int>(push((mstate.ebp+-2430)), op(0x37))))
		i12 =  (i13 + i12)
		i17 =  (i12 + -1)
		i13 =  (i12 + 1074)
		__asm(push(i13<33), iftrue, target("___vfprintf__XprivateX__BB54_537_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_536_F"))
		i19 =  (1)
		i13 =  (i12 + 1042)
		i12 =  (-1010 - i12)
		i13 =  (i2 >>> i13)
		i12 =  (i18 << i12)
		i12 =  (i12 | i13)
		f0 =  (Number(uint(i12)))
		__asm(push(f0), push((mstate.ebp+-1808)), op(0x3e))
		i12 =  ((__xasm<int>(push((mstate.ebp+-1804)), op(0x37))))
		i13 =  ((__xasm<int>(push((mstate.ebp+-1808)), op(0x37))))
		i20 =  (i12 + -32505856)
		i22 =  (0)
		i18 = i13
		i21 = i12
		i12 = i22
		i13 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_538_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_537_F"))
		i19 =  (1)
		i12 =  (-1042 - i12)
		i12 =  (i2 << i12)
		f0 =  (Number(uint(i12)))
		__asm(push(f0), push((mstate.ebp+-1816)), op(0x3e))
		i12 =  ((__xasm<int>(push((mstate.ebp+-1812)), op(0x37))))
		i13 =  ((__xasm<int>(push((mstate.ebp+-1816)), op(0x37))))
		i20 =  (i12 + -32505856)
		i22 =  (0)
		i18 = i13
		i21 = i12
		i12 = i22
		i13 = i20
	__asm(lbl("___vfprintf__XprivateX__BB54_538_F"))
		__asm(push(i19), push((mstate.ebp+-2394)), op(0x3c))
		f0 =  (0)
		i12 =  (i18 | i12)
		__asm(push(i12), push((mstate.ebp+-1824)), op(0x3c))
		__asm(push(i13), push((mstate.ebp+-1820)), op(0x3c))
		f2 =  ((__xasm<Number>(push((mstate.ebp+-1824)), op(0x39))))
		f2 =  (f2 + -1.5)
		f3 =  (Number(i17))
		f2 =  (f2 * 0.28953)
		f3 =  (f3 * 0.30103)
		f2 =  (f2 + 0.176091)
		f2 =  (f2 + f3)
		i12 =  (int(f2))
		__asm(push(f2<f0), iftrue, target("___vfprintf__XprivateX__BB54_540_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_539_F"), lbl("___vfprintf__XprivateX__BB54_539_B"), label, lbl("___vfprintf__XprivateX__BB54_539_F")); 
		__asm(jump, target("___vfprintf__XprivateX__BB54_542_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_540_F"))
		f0 =  (Number(i12))
		__asm(push(f0==f2), iftrue, target("___vfprintf__XprivateX__BB54_539_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_541_F"))
		i12 =  (i12 + -1)
	__asm(lbl("___vfprintf__XprivateX__BB54_542_F"))
		__asm(push(uint(i12)<uint(23)), iftrue, target("___vfprintf__XprivateX__BB54_544_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_543_F"))
		i13 =  (1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_547_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_544_F"))
		i13 =  (___tens_D2A)
		i19 =  (i12 << 3)
		i13 =  (i13 + i19)
		f0 =  ((__xasm<Number>(push(i13), op(0x39))))
		__asm(push(f1<f0), iftrue, target("___vfprintf__XprivateX__BB54_546_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_545_F"))
		i13 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_547_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_546_F"))
		i13 =  (0)
		i12 =  (i12 + -1)
	__asm(lbl("___vfprintf__XprivateX__BB54_547_F"))
		__asm(push(i13), push((mstate.ebp+-2412)), op(0x3c))
		i13 =  ((__xasm<int>(push((mstate.ebp+-2430)), op(0x37))))
		i13 =  (i13 - i17)
		i19 =  (i13 + -1)
		i13 =  (1 - i13)
		i18 =  ((i19>-1) ? i19 : 0)
		i13 =  ((i19>-1) ? 0 : i13)
		__asm(push(i12<0), iftrue, target("___vfprintf__XprivateX__BB54_561_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_548_F"))
		i19 =  (i18 + i12)
		__asm(push(i1>2), iftrue, target("___vfprintf__XprivateX__BB54_553_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_549_F"))
		__asm(push(uint(i1)<uint(2)), iftrue, target("___vfprintf__XprivateX__BB54_573_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_550_F"))
		__asm(push(i1==2), iftrue, target("___vfprintf__XprivateX__BB54_551_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_560_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_551_F"))
		i17 =  (0)
		i18 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_552_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_552_F"), lbl("___vfprintf__XprivateX__BB54_552_B"), label, lbl("___vfprintf__XprivateX__BB54_552_F")); 
		i20 =  (0)
		i21 = i18
		i18 = i17
		i17 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_558_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_553_F"))
		__asm(push(i1==3), iftrue, target("___vfprintf__XprivateX__BB54_576_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_554_F"))
		__asm(push(i1==4), iftrue, target("___vfprintf__XprivateX__BB54_557_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_555_F"))
		__asm(push(i1!=5), iftrue, target("___vfprintf__XprivateX__BB54_560_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_556_F"))
		i17 =  (1)
		i18 =  (0)
		i21 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_578_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_557_F"))
		i17 =  (1)
		i18 =  (0)
		i21 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_558_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_558_F"), lbl("___vfprintf__XprivateX__BB54_558_B"), label, lbl("___vfprintf__XprivateX__BB54_558_F")); 
		i24 = i17
		i17 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		__asm(push(i17<1), iftrue, target("___vfprintf__XprivateX__BB54_575_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_559_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_559_F"))
		i22 = i21
		i20 = i18
		i17 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		i23 = i17
		i21 = i17
		i18 = i24
		i24 = i17
		__asm(jump, target("___vfprintf__XprivateX__BB54_581_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_560_F"))
		i18 =  (1)
		//IMPLICIT_DEF i21 = 
		i20 =  (0)
		i22 = i12
		i23 = i21
		i24 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_581_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_561_F"))
		i20 =  (0 - i12)
		i13 =  (i13 - i12)
		__asm(push(i1>2), iftrue, target("___vfprintf__XprivateX__BB54_565_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_562_F"))
		__asm(push(uint(i1)<uint(2)), iftrue, target("___vfprintf__XprivateX__BB54_571_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_563_F"))
		__asm(push(i1==2), iftrue, target("___vfprintf__XprivateX__BB54_564_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_572_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_564_F"))
		i17 =  (0)
		i19 = i18
		i18 = i17
		i17 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_552_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_565_F"))
		__asm(push(i1==3), iftrue, target("___vfprintf__XprivateX__BB54_570_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_566_F"))
		__asm(push(i1==4), iftrue, target("___vfprintf__XprivateX__BB54_569_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_567_F"))
		__asm(push(i1!=5), iftrue, target("___vfprintf__XprivateX__BB54_572_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_568_F"))
		i17 =  (1)
		i21 =  (0)
		i19 = i18
		i18 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_578_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_569_F"))
		i17 =  (1)
		i21 =  (0)
		i19 = i18
		i18 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_558_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_570_F"))
		i17 =  (0)
		i19 = i18
		i18 = i17
		i17 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_577_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_571_F"))
		i17 =  (0)
		i19 = i18
		i18 = i17
		i17 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_574_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_572_F"))
		i24 =  (1)
		//IMPLICIT_DEF i21 = 
		i22 =  (0)
		i19 = i18
		i23 = i21
		i18 = i24
		i24 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_581_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_573_F"))
		i17 =  (0)
		i18 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_574_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_574_F"))
		i24 =  (0)
		i25 =  (1)
		i26 =  (18)
		i21 =  (-1)
		i22 = i18
		i20 = i17
		i23 = i21
		i17 = i26
		i18 = i25
		__asm(jump, target("___vfprintf__XprivateX__BB54_581_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_575_F"))
		i25 =  (1)
		i22 = i21
		i20 = i18
		i23 = i25
		i21 = i25
		i17 = i25
		i18 = i24
		i24 = i25
		__asm(jump, target("___vfprintf__XprivateX__BB54_581_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_576_F"))
		i17 =  (0)
		i18 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_577_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_577_F"))
		i20 =  (0)
		i21 = i18
		i18 = i17
		i17 = i20
	__asm(lbl("___vfprintf__XprivateX__BB54_578_F"))
		i24 = i17
		i17 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		i17 =  (i12 + i17)
		i25 =  (i17 + 1)
		__asm(push(i25<1), iftrue, target("___vfprintf__XprivateX__BB54_580_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_579_F"))
		i22 = i21
		i20 = i18
		i23 = i25
		i21 = i17
		i17 = i25
		i18 = i24
		i24 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_581_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_580_F"))
		i26 =  (1)
		i22 = i21
		i20 = i18
		i23 = i25
		i21 = i17
		i17 = i26
		i18 = i24
		i24 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
	__asm(lbl("___vfprintf__XprivateX__BB54_581_F"))
		__asm(push(i22), push((mstate.ebp+-2466)), op(0x3c))
		i22 = i23
		__asm(push(i21), push((mstate.ebp+-2457)), op(0x3c))
		__asm(push(i18), push((mstate.ebp+-2493)), op(0x3c))
		i18 = i24
		__asm(push(i18), push((mstate.ebp+-2448)), op(0x3c))
		__asm(push(uint(i17)<uint(20)), iftrue, target("___vfprintf__XprivateX__BB54_1518_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_582_F"))
		i18 =  (4)
		i21 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_583_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_583_F"), lbl("___vfprintf__XprivateX__BB54_583_B"), label, lbl("___vfprintf__XprivateX__BB54_583_F")); 
		i18 =  (i18 << 1)
		i21 =  (i21 + 1)
		i23 =  (i18 + 16)
		__asm(push(uint(i23)>uint(i17)), iftrue, target("___vfprintf__XprivateX__BB54_585_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_584_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_583_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_585_F"))
		i17 = i21
	__asm(jump, target("___vfprintf__XprivateX__BB54_586_F"), lbl("___vfprintf__XprivateX__BB54_586_B"), label, lbl("___vfprintf__XprivateX__BB54_586_F")); 
		mstate.esp -= 4
		__asm(push(i17), push(mstate.esp), op(0x3c))
		state = 34
		mstate.esp -= 4;FSM___Balloc_D2A.start()
		return
	__asm(lbl("___vfprintf_state34"))
		i18 = mstate.eax
		mstate.esp += 4
		__asm(push(i17), push(i18), op(0x3c))
		i17 =  (i18 + 4)
		__asm(push(i17), push((mstate.ebp+-2538)), op(0x3c))
		__asm(push(uint(i22)>uint(14)), iftrue, target("___vfprintf__XprivateX__BB54_640_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_587_F"))
		__asm(push(i12<1), iftrue, target("___vfprintf__XprivateX__BB54_602_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_588_F"))
		i18 =  (___tens_D2A)
		i21 =  (i12 & 15)
		i21 =  (i21 << 3)
		i18 =  (i18 + i21)
		f0 =  ((__xasm<Number>(push(i18), op(0x39))))
		i18 =  (i12 >> 4)
		i21 =  (i18 & 16)
		__asm(push(i21!=0), iftrue, target("___vfprintf__XprivateX__BB54_590_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_589_F"))
		i21 =  (0)
		i23 =  (2)
		i24 = i2
		i25 = i7
		__asm(jump, target("___vfprintf__XprivateX__BB54_596_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_590_F"))
		f2 =  (f1 / 1e+256)
		__asm(push(f2), push((mstate.ebp+-1832)), op(0x3e))
		i21 =  ((__xasm<int>(push((mstate.ebp+-1832)), op(0x37))))
		i23 =  ((__xasm<int>(push((mstate.ebp+-1828)), op(0x37))))
		i18 =  (i18 & 15)
		__asm(push(i18==0), iftrue, target("___vfprintf__XprivateX__BB54_1519_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_591_F"))
		i24 =  (0)
		i25 =  (3)
		__asm(jump, target("___vfprintf__XprivateX__BB54_592_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_592_F"), lbl("___vfprintf__XprivateX__BB54_592_B"), label, lbl("___vfprintf__XprivateX__BB54_592_F")); 
		i26 =  (i18 & 1)
		__asm(push(i26!=0), iftrue, target("___vfprintf__XprivateX__BB54_594_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_593_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_595_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_594_F"))
		i26 =  (___bigtens_D2A)
		i27 =  (i24 << 3)
		i26 =  (i26 + i27)
		f2 =  ((__xasm<Number>(push(i26), op(0x39))))
		f0 =  (f2 * f0)
		i25 =  (i25 + 1)
	__asm(lbl("___vfprintf__XprivateX__BB54_595_F"))
		i26 = i25
		i27 =  (i24 + 1)
		i18 =  (i18 >> 1)
		i24 = i21
		i25 = i23
		i23 = i26
		i21 = i27
	__asm(lbl("___vfprintf__XprivateX__BB54_596_F"))
		i26 = i23
		i27 = i21
		__asm(push(i18==0), iftrue, target("___vfprintf__XprivateX__BB54_598_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_597_F"))
		i21 = i24
		i23 = i25
		i25 = i26
		i24 = i27
		__asm(jump, target("___vfprintf__XprivateX__BB54_592_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_598_F"))
		i21 = i24
		i23 = i25
		i18 = i26
	__asm(jump, target("___vfprintf__XprivateX__BB54_599_F"), lbl("___vfprintf__XprivateX__BB54_599_B"), label, lbl("___vfprintf__XprivateX__BB54_599_F")); 
		__asm(push(i21), push((mstate.ebp+-1840)), op(0x3c))
		__asm(push(i23), push((mstate.ebp+-1836)), op(0x3c))
		f2 =  ((__xasm<Number>(push((mstate.ebp+-1840)), op(0x39))))
		f0 =  (f2 / f0)
		__asm(push(f0), push((mstate.ebp+-1848)), op(0x3e))
		i21 =  ((__xasm<int>(push((mstate.ebp+-1848)), op(0x37))))
		i23 =  ((__xasm<int>(push((mstate.ebp+-1844)), op(0x37))))
		i24 =  ((__xasm<int>(push((mstate.ebp+-2412)), op(0x37))))
		__asm(push(i24==0), iftrue, target("___vfprintf__XprivateX__BB54_601_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_600_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_614_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_601_F"))
		i24 = i22
		i25 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_619_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_602_F"))
		i18 =  (0 - i12)
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_604_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_603_F"))
		i18 =  (2)
		i21 = i2
		i23 = i7
		__asm(jump, target("___vfprintf__XprivateX__BB54_612_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_604_F"))
		i21 =  (___tens_D2A)
		i23 =  (i18 & 15)
		i23 =  (i23 << 3)
		i21 =  (i21 + i23)
		f0 =  ((__xasm<Number>(push(i21), op(0x39))))
		f0 =  (f1 * f0)
		__asm(push(f0), push((mstate.ebp+-1856)), op(0x3e))
		i21 =  ((__xasm<int>(push((mstate.ebp+-1856)), op(0x37))))
		i23 =  ((__xasm<int>(push((mstate.ebp+-1852)), op(0x37))))
		i24 =  (i18 >> 4)
		__asm(push(uint(i18)<uint(16)), iftrue, target("___vfprintf__XprivateX__BB54_1520_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_605_F"))
		i18 =  (___bigtens_D2A)
		i25 =  (2)
		__asm(jump, target("___vfprintf__XprivateX__BB54_606_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_606_F"), lbl("___vfprintf__XprivateX__BB54_606_B"), label, lbl("___vfprintf__XprivateX__BB54_606_F")); 
		i26 = i18
		i27 =  (i24 & 1)
		__asm(push(i27!=0), iftrue, target("___vfprintf__XprivateX__BB54_608_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_607_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_609_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_608_F"))
		__asm(push(i21), push((mstate.ebp+-1864)), op(0x3c))
		__asm(push(i23), push((mstate.ebp+-1860)), op(0x3c))
		f0 =  ((__xasm<Number>(push(i26), op(0x39))))
		f2 =  ((__xasm<Number>(push((mstate.ebp+-1864)), op(0x39))))
		f0 =  (f2 * f0)
		__asm(push(f0), push((mstate.ebp+-1872)), op(0x3e))
		i21 =  ((__xasm<int>(push((mstate.ebp+-1872)), op(0x37))))
		i23 =  ((__xasm<int>(push((mstate.ebp+-1868)), op(0x37))))
		i25 =  (i25 + 1)
	__asm(lbl("___vfprintf__XprivateX__BB54_609_F"))
		i18 =  (i18 + 8)
		i26 =  (i24 >> 1)
		__asm(push(uint(i24)<uint(2)), iftrue, target("___vfprintf__XprivateX__BB54_611_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_610_F"))
		i24 = i26
		__asm(jump, target("___vfprintf__XprivateX__BB54_606_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_611_F"))
		i18 = i25
	__asm(jump, target("___vfprintf__XprivateX__BB54_612_F"), lbl("___vfprintf__XprivateX__BB54_612_B"), label, lbl("___vfprintf__XprivateX__BB54_612_F")); 
		i24 =  ((__xasm<int>(push((mstate.ebp+-2412)), op(0x37))))
		__asm(push(i24==0), iftrue, target("___vfprintf__XprivateX__BB54_1521_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_613_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_614_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_614_F"))
		f0 =  (1)
		__asm(push(i21), push((mstate.ebp+-1880)), op(0x3c))
		__asm(push(i23), push((mstate.ebp+-1876)), op(0x3c))
		f2 =  ((__xasm<Number>(push((mstate.ebp+-1880)), op(0x39))))
		__asm(push(f2>=f0), iftrue, target("___vfprintf__XprivateX__BB54_616_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_615_F"))
		__asm(push(i22>0), iftrue, target("___vfprintf__XprivateX__BB54_617_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_616_F"))
		i24 = i22
		i25 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_619_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_617_F"))
		i21 =  ((__xasm<int>(push((mstate.ebp+-2457)), op(0x37))))
		__asm(push(i21<1), iftrue, target("___vfprintf__XprivateX__BB54_640_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_618_F"))
		f0 =  (f2 * 10)
		__asm(push(f0), push((mstate.ebp+-1888)), op(0x3e))
		i21 =  ((__xasm<int>(push((mstate.ebp+-1888)), op(0x37))))
		i23 =  ((__xasm<int>(push((mstate.ebp+-1884)), op(0x37))))
		i18 =  (i18 + 1)
		i25 =  (i12 + -1)
		i24 =  ((__xasm<int>(push((mstate.ebp+-2457)), op(0x37))))
	__asm(jump, target("___vfprintf__XprivateX__BB54_619_F"), lbl("___vfprintf__XprivateX__BB54_619_B"), label, lbl("___vfprintf__XprivateX__BB54_619_F")); 
		__asm(push(i21), push((mstate.ebp+-1896)), op(0x3c))
		__asm(push(i23), push((mstate.ebp+-1892)), op(0x3c))
		f0 =  ((__xasm<Number>(push((mstate.ebp+-1896)), op(0x39))))
		f2 =  (Number(i18))
		f2 =  (f2 * f0)
		f2 =  (f2 + 7)
		__asm(push(f2), push((mstate.ebp+-1904)), op(0x3e))
		i18 =  ((__xasm<int>(push((mstate.ebp+-1900)), op(0x37))))
		i26 =  ((__xasm<int>(push((mstate.ebp+-1904)), op(0x37))))
		i18 =  (i18 + -54525952)
		__asm(push(i24!=0), iftrue, target("___vfprintf__XprivateX__BB54_625_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_620_F"))
		__asm(push(i26), push((mstate.ebp+-1912)), op(0x3c))
		__asm(push(i18), push((mstate.ebp+-1908)), op(0x3c))
		f2 =  ((__xasm<Number>(push((mstate.ebp+-1912)), op(0x39))))
		f0 =  (f0 + -5)
		__asm(push(f0<=f2), iftrue, target("___vfprintf__XprivateX__BB54_623_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_621_F"))
		i7 =  (0)
		i1 = i25
		i2 = i10
		i10 = i7
		__asm(jump, target("___vfprintf__XprivateX__BB54_622_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_622_F"), lbl("___vfprintf__XprivateX__BB54_622_B"), label, lbl("___vfprintf__XprivateX__BB54_622_F")); 
		i12 =  (49)
		i13 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		__asm(push(i12), push(i13), op(0x3a))
		i12 =  (0)
		i1 =  (i1 + 1)
		i13 =  (i13 + 1)
		i17 = i10
		i10 = i13
		__asm(jump, target("___vfprintf__XprivateX__BB54_863_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_623_F"))
		f2 =  -f2
		__asm(push(f0>=f2), iftrue, target("___vfprintf__XprivateX__BB54_640_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_624_F"), lbl("___vfprintf__XprivateX__BB54_624_B"), label, lbl("___vfprintf__XprivateX__BB54_624_F")); 
		i7 =  (0)
		i1 = i10
		i2 = i7
		__asm(jump, target("___vfprintf__XprivateX__BB54_766_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_625_F"))
		i27 =  ((__xasm<int>(push((mstate.ebp+-2493)), op(0x37))))
		__asm(push(i27==0), iftrue, target("___vfprintf__XprivateX__BB54_631_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_626_F"))
		i27 =  (___tens_D2A)
		i28 =  (i24 << 3)
		__asm(push(i26), push((mstate.ebp+-1920)), op(0x3c))
		__asm(push(i18), push((mstate.ebp+-1916)), op(0x3c))
		i18 =  (i28 + i27)
		f0 =  ((__xasm<Number>(push((i18+-8)), op(0x39))))
		f2 =  ((__xasm<Number>(push((mstate.ebp+-1920)), op(0x39))))
		f0 =  (0.5 / f0)
		i18 =  (0)
		f0 =  (f0 - f2)
	__asm(jump, target("___vfprintf__XprivateX__BB54_627_F"), lbl("___vfprintf__XprivateX__BB54_627_B"), label, lbl("___vfprintf__XprivateX__BB54_627_F")); 
		__asm(push(i21), push((mstate.ebp+-1928)), op(0x3c))
		__asm(push(i23), push((mstate.ebp+-1924)), op(0x3c))
		f2 =  ((__xasm<Number>(push((mstate.ebp+-1928)), op(0x39))))
		i21 =  (int(f2))
		f3 =  (Number(i21))
		i21 =  (i21 + 48)
		i23 =  (i17 + i18)
		__asm(push(i21), push(i23), op(0x3a))
		f2 =  (f2 - f3)
		i21 =  (i18 + 1)
		__asm(push(f2<f0), iftrue, target("___vfprintf__XprivateX__BB54_875_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_628_F"))
		f3 =  (1 - f2)
		__asm(push(f3<f0), iftrue, target("___vfprintf__XprivateX__BB54_655_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_629_F"))
		__asm(push(i21>=i24), iftrue, target("___vfprintf__XprivateX__BB54_640_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_630_F"))
		f2 =  (f2 * 10)
		__asm(push(f2), push((mstate.ebp+-1936)), op(0x3e))
		i21 =  ((__xasm<int>(push((mstate.ebp+-1936)), op(0x37))))
		i23 =  ((__xasm<int>(push((mstate.ebp+-1932)), op(0x37))))
		i18 =  (i18 + 1)
		f0 =  (f0 * 10)
		__asm(jump, target("___vfprintf__XprivateX__BB54_627_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_631_F"))
		i27 =  (___tens_D2A)
		i28 =  (i24 << 3)
		__asm(push(i26), push((mstate.ebp+-1944)), op(0x3c))
		__asm(push(i18), push((mstate.ebp+-1940)), op(0x3c))
		i18 =  (i28 + i27)
		f0 =  ((__xasm<Number>(push((mstate.ebp+-1944)), op(0x39))))
		f2 =  ((__xasm<Number>(push((i18+-8)), op(0x39))))
		i18 =  (0)
		f0 =  (f0 * f2)
	__asm(jump, target("___vfprintf__XprivateX__BB54_632_F"), lbl("___vfprintf__XprivateX__BB54_632_B"), label, lbl("___vfprintf__XprivateX__BB54_632_F")); 
		f2 =  (0)
		__asm(push(i21), push((mstate.ebp+-1952)), op(0x3c))
		__asm(push(i23), push((mstate.ebp+-1948)), op(0x3c))
		f3 =  ((__xasm<Number>(push((mstate.ebp+-1952)), op(0x39))))
		i21 =  (int(f3))
		f4 =  (Number(i21))
		i21 =  (i21 + 48)
		f3 =  (f3 - f4)
		i23 =  (i18 + 1)
		i26 =  (i17 + i18)
		__asm(push(i21), push(i26), op(0x3a))
		i24 =  ((f3==f2) ? i23 : i24)
		__asm(push(i23!=i24), iftrue, target("___vfprintf__XprivateX__BB54_639_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_633_F"))
		i18 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		i18 =  (i18 + i23)
		f2 =  (f0 + 0.5)
		__asm(push(f3<=f2), iftrue, target("___vfprintf__XprivateX__BB54_635_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_634_F"))
		i7 = i25
		i1 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_656_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_635_F"))
		f0 =  (0.5 - f0)
		__asm(push(f3>=f0), iftrue, target("___vfprintf__XprivateX__BB54_640_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_636_F"))
		i7 =  (0)
	__asm(jump, target("___vfprintf__XprivateX__BB54_637_F"), lbl("___vfprintf__XprivateX__BB54_637_B"), label, lbl("___vfprintf__XprivateX__BB54_637_F")); 
		i1 =  (i7 ^ -1)
		i1 =  (i23 + i1)
		i2 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		i1 =  (i2 + i1)
		i1 =  ((__xasm<int>(push(i1), op(0x35))))
		i7 =  (i7 + 1)
		__asm(push(i1!=48), iftrue, target("___vfprintf__XprivateX__BB54_874_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_638_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_637_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_639_F"))
		f2 =  (f3 * 10)
		__asm(push(f2), push((mstate.ebp+-1960)), op(0x3e))
		i21 =  ((__xasm<int>(push((mstate.ebp+-1960)), op(0x37))))
		i23 =  ((__xasm<int>(push((mstate.ebp+-1956)), op(0x37))))
		i18 =  (i18 + 1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_632_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_640_F"))
		i18 =  ((__xasm<int>(push((mstate.ebp+-2439)), op(0x37))))
		__asm(push(i18<0), iftrue, target("___vfprintf__XprivateX__BB54_665_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_641_F"))
		__asm(push(i12>14), iftrue, target("___vfprintf__XprivateX__BB54_665_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_642_F"))
		i1 =  (___tens_D2A)
		i13 =  (i12 << 3)
		i1 =  (i1 + i13)
		f0 =  ((__xasm<Number>(push(i1), op(0x39))))
		i1 =  ((__xasm<int>(push((mstate.ebp+-2448)), op(0x37))))
		__asm(push(i1>-1), iftrue, target("___vfprintf__XprivateX__BB54_644_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_643_F"))
		__asm(push(i22<1), iftrue, target("___vfprintf__XprivateX__BB54_649_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_644_F"))
		i1 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_645_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_645_F"), lbl("___vfprintf__XprivateX__BB54_645_B"), label, lbl("___vfprintf__XprivateX__BB54_645_F")); 
		f1 =  (0)
		__asm(push(i2), push((mstate.ebp+-1968)), op(0x3c))
		__asm(push(i7), push((mstate.ebp+-1964)), op(0x3c))
		f2 =  ((__xasm<Number>(push((mstate.ebp+-1968)), op(0x39))))
		f3 =  (f2 / f0)
		i7 =  (int(f3))
		f3 =  (Number(i7))
		f3 =  (f3 * f0)
		f2 =  (f2 - f3)
		i2 =  (i7 + -1)
		i7 =  ((f2>=f1) ? i7 : i2)
		f3 =  (f2 + f0)
		i2 =  (i7 + 48)
		i13 =  (i17 + i1)
		__asm(push(i2), push(i13), op(0x3a))
		f2 =  ((f2<f1) ? f3 : f2)
		i2 =  (i1 + 1)
		__asm(push(f2==f1), iftrue, target("___vfprintf__XprivateX__BB54_873_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_646_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_646_F"))
		__asm(push(i2!=i22), iftrue, target("___vfprintf__XprivateX__BB54_664_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_647_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_647_F"))
		f2 =  (f2 + f2)
		i1 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		i1 =  (i1 + i2)
		__asm(push(f2<=f0), iftrue, target("___vfprintf__XprivateX__BB54_652_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_648_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_648_F"), lbl("___vfprintf__XprivateX__BB54_648_B"), label, lbl("___vfprintf__XprivateX__BB54_648_F")); 
		i7 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_656_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_649_F"))
		__asm(push(i22<0), iftrue, target("___vfprintf__XprivateX__BB54_624_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_650_F"))
		f0 =  (f0 * 5)
		__asm(push(f1<=f0), iftrue, target("___vfprintf__XprivateX__BB54_624_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_651_F"))
		i7 =  (0)
		i1 = i12
		i2 = i10
		i10 = i7
		__asm(jump, target("___vfprintf__XprivateX__BB54_622_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_652_F"))
		__asm(push(f2==f0), iftrue, target("___vfprintf__XprivateX__BB54_654_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_653_F"), lbl("___vfprintf__XprivateX__BB54_653_B"), label, lbl("___vfprintf__XprivateX__BB54_653_F")); 
		i7 = i12
		i2 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_876_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_654_F"))
		i7 =  (i7 & 1)
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_653_B"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_648_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_655_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		i1 =  (i7 + i21)
		i7 = i25
	__asm(lbl("___vfprintf__XprivateX__BB54_656_F"))
		i2 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_657_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_657_F"), lbl("___vfprintf__XprivateX__BB54_657_B"), label, lbl("___vfprintf__XprivateX__BB54_657_F")); 
		i12 =  (i2 ^ -1)
		i12 =  (i1 + i12)
		i13 =  ((__xasm<int>(push(i12), op(0x35))))
		__asm(push(i13==57), iftrue, target("___vfprintf__XprivateX__BB54_658_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_663_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_658_F"))
		i2 =  (i2 + 1)
		i13 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		__asm(push(i12==i13), iftrue, target("___vfprintf__XprivateX__BB54_660_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_659_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_657_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_660_F"))
		i13 =  (49)
		i2 =  (i2 + -1)
		__asm(push(i13), push(i12), op(0x3a))
		i1 =  (i1 - i2)
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_662_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_661_F"))
		i2 =  (_freelist)
		i12 =  ((__xasm<int>(push((i10+4)), op(0x37))))
		i12 =  (i12 << 2)
		i2 =  (i2 + i12)
		i12 =  ((__xasm<int>(push(i2), op(0x37))))
		__asm(push(i12), push(i10), op(0x3c))
		__asm(push(i10), push(i2), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_662_F"))
		i2 =  (0)
		__asm(push(i2), push(i1), op(0x3a))
		i7 =  (i7 + 2)
		__asm(jump, target("___vfprintf__XprivateX__BB54_879_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_663_F"))
		i13 =  (i13 + 1)
		__asm(push(i13), push(i12), op(0x3a))
		i1 =  (i1 - i2)
		i2 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_876_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_664_F"))
		f1 =  (f2 * 10)
		__asm(push(f1), push((mstate.ebp+-1976)), op(0x3e))
		i7 =  ((__xasm<int>(push((mstate.ebp+-1976)), op(0x37))))
		i13 =  ((__xasm<int>(push((mstate.ebp+-1972)), op(0x37))))
		i1 =  (i1 + 1)
		i2 = i7
		i7 = i13
		__asm(jump, target("___vfprintf__XprivateX__BB54_645_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_665_F"))
		i18 =  ((__xasm<int>(push((mstate.ebp+-2493)), op(0x37))))
		__asm(push(i18!=0), iftrue, target("___vfprintf__XprivateX__BB54_667_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_666_F"))
		i18 =  (0)
		i21 = i13
		__asm(jump, target("___vfprintf__XprivateX__BB54_683_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_667_F"))
		i18 =  ((__xasm<int>(push((mstate.ebp+-2394)), op(0x37))))
		i18 =  (i18 ^ 1)
		i18 =  (i18 & 1)
		__asm(push(i18!=0), iftrue, target("___vfprintf__XprivateX__BB54_677_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_668_F"))
		i18 =  ((__xasm<int>(push((mstate.ebp+-2439)), op(0x37))))
		i18 =  (i18 + 1075)
		i21 =  ((__xasm<int>(push((_freelist+4)), op(0x37))))
		i19 =  (i18 + i19)
		i18 =  (i18 + i13)
		__asm(push(i21==0), iftrue, target("___vfprintf__XprivateX__BB54_670_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_669_F"))
		i23 =  ((__xasm<int>(push(i21), op(0x37))))
		__asm(push(i23), push((_freelist+4)), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_673_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_670_F"))
		i21 =  (_private_mem)
		i23 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i21 =  (i23 - i21)
		i21 =  (i21 >> 3)
		i21 =  (i21 + 4)
		__asm(push(uint(i21)>uint(288)), iftrue, target("___vfprintf__XprivateX__BB54_672_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_671_F"))
		i21 =  (1)
		i24 =  (i23 + 32)
		__asm(push(i24), push(_pmem_next), op(0x3c))
		__asm(push(i21), push((i23+4)), op(0x3c))
		i21 =  (2)
		__asm(push(i21), push((i23+8)), op(0x3c))
		i21 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_673_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_672_F"))
		i21 =  (32)
		mstate.esp -= 4
		__asm(push(i21), push(mstate.esp), op(0x3c))
		state = 35
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___vfprintf_state35"))
		i21 = mstate.eax
		mstate.esp += 4
		i23 =  (1)
		__asm(push(i23), push((i21+4)), op(0x3c))
		i23 =  (2)
		__asm(push(i23), push((i21+8)), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_673_F"))
		i23 =  (0)
		__asm(push(i23), push((i21+12)), op(0x3c))
		i23 =  (1)
		__asm(push(i23), push((i21+20)), op(0x3c))
		__asm(push(i23), push((i21+16)), op(0x3c))
		__asm(push(i19<1), iftrue, target("___vfprintf__XprivateX__BB54_675_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_674_F"))
		__asm(push(i13>0), iftrue, target("___vfprintf__XprivateX__BB54_676_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_675_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_688_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_676_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_687_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_677_F"))
		i18 =  ((__xasm<int>(push((mstate.ebp+-2430)), op(0x37))))
		i18 =  (54 - i18)
		i21 =  ((__xasm<int>(push((_freelist+4)), op(0x37))))
		i19 =  (i18 + i19)
		i18 =  (i18 + i13)
		__asm(push(i21==0), iftrue, target("___vfprintf__XprivateX__BB54_679_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_678_F"))
		i23 =  ((__xasm<int>(push(i21), op(0x37))))
		__asm(push(i23), push((_freelist+4)), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_682_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_679_F"))
		i21 =  (_private_mem)
		i23 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i21 =  (i23 - i21)
		i21 =  (i21 >> 3)
		i21 =  (i21 + 4)
		__asm(push(uint(i21)>uint(288)), iftrue, target("___vfprintf__XprivateX__BB54_681_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_680_F"))
		i21 =  (1)
		i24 =  (i23 + 32)
		__asm(push(i24), push(_pmem_next), op(0x3c))
		__asm(push(i21), push((i23+4)), op(0x3c))
		i21 =  (2)
		__asm(push(i21), push((i23+8)), op(0x3c))
		i21 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_682_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_681_F"))
		i21 =  (32)
		mstate.esp -= 4
		__asm(push(i21), push(mstate.esp), op(0x3c))
		state = 36
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___vfprintf_state36"))
		i21 = mstate.eax
		mstate.esp += 4
		i23 =  (1)
		__asm(push(i23), push((i21+4)), op(0x3c))
		i23 =  (2)
		__asm(push(i23), push((i21+8)), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_682_F"))
		i23 = i21
		i21 =  (0)
		__asm(push(i21), push((i23+12)), op(0x3c))
		i21 =  (1)
		__asm(push(i21), push((i23+20)), op(0x3c))
		__asm(push(i21), push((i23+16)), op(0x3c))
		i21 = i18
		i18 = i23
	__asm(lbl("___vfprintf__XprivateX__BB54_683_F"))
		i23 = i21
		i21 = i18
		__asm(push(i19<1), iftrue, target("___vfprintf__XprivateX__BB54_685_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_684_F"))
		__asm(push(i13>0), iftrue, target("___vfprintf__XprivateX__BB54_686_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_685_F"))
		i18 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_688_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_686_F"))
		i18 = i23
	__asm(lbl("___vfprintf__XprivateX__BB54_687_F"))
		i23 =  ((i19<=i13) ? i19 : i13)
		i19 =  (i19 - i23)
		i13 =  (i13 - i23)
		i18 =  (i18 - i23)
	__asm(lbl("___vfprintf__XprivateX__BB54_688_F"))
		__asm(push(i20>0), iftrue, target("___vfprintf__XprivateX__BB54_690_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_689_F"), lbl("___vfprintf__XprivateX__BB54_689_B"), label, lbl("___vfprintf__XprivateX__BB54_689_F")); 
		__asm(jump, target("___vfprintf__XprivateX__BB54_703_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_690_F"))
		i23 =  ((__xasm<int>(push((mstate.ebp+-2493)), op(0x37))))
		__asm(push(i23==0), iftrue, target("___vfprintf__XprivateX__BB54_702_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_691_F"))
		__asm(push(i20<1), iftrue, target("___vfprintf__XprivateX__BB54_689_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_692_F"))
		mstate.esp -= 8
		__asm(push(i21), push(mstate.esp), op(0x3c))
		__asm(push(i20), push((mstate.esp+4)), op(0x3c))
		state = 37
		mstate.esp -= 4;FSM___pow5mult_D2A.start()
		return
	__asm(lbl("___vfprintf_state37"))
		i21 = mstate.eax
		mstate.esp += 8
		mstate.esp -= 8
		__asm(push(i21), push(mstate.esp), op(0x3c))
		__asm(push(i10), push((mstate.esp+4)), op(0x3c))
		state = 38
		mstate.esp -= 4;FSM___mult_D2A.start()
		return
	__asm(lbl("___vfprintf_state38"))
		i20 = mstate.eax
		mstate.esp += 8
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_694_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_693_F"))
		i23 =  (_freelist)
		i24 =  ((__xasm<int>(push((i10+4)), op(0x37))))
		i24 =  (i24 << 2)
		i23 =  (i23 + i24)
		i24 =  ((__xasm<int>(push(i23), op(0x37))))
		__asm(push(i24), push(i10), op(0x3c))
		__asm(push(i10), push(i23), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_694_F"))
		i10 =  ((__xasm<int>(push((_freelist+4)), op(0x37))))
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_696_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_695_F"))
		i23 =  ((__xasm<int>(push(i10), op(0x37))))
		__asm(push(i23), push((_freelist+4)), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_699_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_696_F"))
		i10 =  (_private_mem)
		i23 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i10 =  (i23 - i10)
		i10 =  (i10 >> 3)
		i10 =  (i10 + 4)
		__asm(push(uint(i10)>uint(288)), iftrue, target("___vfprintf__XprivateX__BB54_698_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_697_F"))
		i10 =  (1)
		i24 =  (i23 + 32)
		__asm(push(i24), push(_pmem_next), op(0x3c))
		__asm(push(i10), push((i23+4)), op(0x3c))
		i10 =  (2)
		__asm(push(i10), push((i23+8)), op(0x3c))
		i10 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_699_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_698_F"))
		i10 =  (32)
		mstate.esp -= 4
		__asm(push(i10), push(mstate.esp), op(0x3c))
		state = 39
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___vfprintf_state39"))
		i10 = mstate.eax
		mstate.esp += 4
		i23 =  (1)
		__asm(push(i23), push((i10+4)), op(0x3c))
		i23 =  (2)
		__asm(push(i23), push((i10+8)), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_699_F"))
		i23 =  (0)
		__asm(push(i23), push((i10+12)), op(0x3c))
		i23 =  (1)
		__asm(push(i23), push((i10+20)), op(0x3c))
		__asm(push(i23), push((i10+16)), op(0x3c))
		i23 =  ((__xasm<int>(push((mstate.ebp+-2466)), op(0x37))))
		__asm(push(i23>0), iftrue, target("___vfprintf__XprivateX__BB54_701_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_700_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_712_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_701_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_711_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_702_F"))
		mstate.esp -= 8
		__asm(push(i10), push(mstate.esp), op(0x3c))
		__asm(push(i20), push((mstate.esp+4)), op(0x3c))
		state = 40
		mstate.esp -= 4;FSM___pow5mult_D2A.start()
		return
	__asm(lbl("___vfprintf_state40"))
		i10 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___vfprintf__XprivateX__BB54_703_F"))
		i20 =  ((__xasm<int>(push((_freelist+4)), op(0x37))))
		__asm(push(i20==0), iftrue, target("___vfprintf__XprivateX__BB54_705_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_704_F"))
		i23 =  ((__xasm<int>(push(i20), op(0x37))))
		__asm(push(i23), push((_freelist+4)), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_708_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_705_F"))
		i20 =  (_private_mem)
		i23 =  ((__xasm<int>(push(_pmem_next), op(0x37))))
		i20 =  (i23 - i20)
		i20 =  (i20 >> 3)
		i20 =  (i20 + 4)
		__asm(push(uint(i20)>uint(288)), iftrue, target("___vfprintf__XprivateX__BB54_707_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_706_F"))
		i20 =  (1)
		i24 =  (i23 + 32)
		__asm(push(i24), push(_pmem_next), op(0x3c))
		__asm(push(i20), push((i23+4)), op(0x3c))
		i20 =  (2)
		__asm(push(i20), push((i23+8)), op(0x3c))
		i20 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_708_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_707_F"))
		i20 =  (32)
		mstate.esp -= 4
		__asm(push(i20), push(mstate.esp), op(0x3c))
		state = 41
		mstate.esp -= 4;FSM_malloc.start()
		return
	__asm(lbl("___vfprintf_state41"))
		i20 = mstate.eax
		mstate.esp += 4
		i23 =  (1)
		__asm(push(i23), push((i20+4)), op(0x3c))
		i23 =  (2)
		__asm(push(i23), push((i20+8)), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_708_F"))
		i23 = i20
		i20 =  (0)
		__asm(push(i20), push((i23+12)), op(0x3c))
		i20 =  (1)
		__asm(push(i20), push((i23+20)), op(0x3c))
		__asm(push(i20), push((i23+16)), op(0x3c))
		i20 =  ((__xasm<int>(push((mstate.ebp+-2466)), op(0x37))))
		__asm(push(i20>0), iftrue, target("___vfprintf__XprivateX__BB54_710_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_709_F"))
		i20 = i10
		i10 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_712_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_710_F"))
		i20 = i10
		i10 = i23
	__asm(lbl("___vfprintf__XprivateX__BB54_711_F"))
		mstate.esp -= 8
		__asm(push(i10), push(mstate.esp), op(0x3c))
		i10 =  ((__xasm<int>(push((mstate.ebp+-2466)), op(0x37))))
		__asm(push(i10), push((mstate.esp+4)), op(0x3c))
		state = 42
		mstate.esp -= 4;FSM___pow5mult_D2A.start()
		return
	__asm(lbl("___vfprintf_state42"))
		i10 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___vfprintf__XprivateX__BB54_712_F"))
		i23 = i20
		i20 =  ((__xasm<int>(push((mstate.ebp+-2493)), op(0x37))))
		__asm(push(i20!=0), iftrue, target("___vfprintf__XprivateX__BB54_715_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_713_F"))
		__asm(push(i1<2), iftrue, target("___vfprintf__XprivateX__BB54_715_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_714_F"), lbl("___vfprintf__XprivateX__BB54_714_B"), label, lbl("___vfprintf__XprivateX__BB54_714_F")); 
		i7 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_719_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_715_F"))
		__asm(push(i2!=0), iftrue, target("___vfprintf__XprivateX__BB54_714_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_716_F"))
		i20 =  (i7 & 1048575)
		__asm(push(i20!=0), iftrue, target("___vfprintf__XprivateX__BB54_714_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_717_F"))
		i7 =  (i7 & 2145386496)
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_714_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_718_F"))
		i7 =  (1)
		i19 =  (i19 + 1)
		i18 =  (i18 + 1)
	__asm(lbl("___vfprintf__XprivateX__BB54_719_F"))
		i20 =  ((__xasm<int>(push((mstate.ebp+-2466)), op(0x37))))
		__asm(push(i20!=0), iftrue, target("___vfprintf__XprivateX__BB54_721_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_720_F"))
		i20 =  (1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_725_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_721_F"))
		i20 =  ((__xasm<int>(push((i10+16)), op(0x37))))
		i20 =  (i20 << 2)
		i20 =  (i20 + i10)
		i20 =  ((__xasm<int>(push((i20+16)), op(0x37))))
		i24 =  ((uint(i20)<uint(65536)) ? 16 : 0)
		i20 =  (i20 << i24)
		i25 =  ((uint(i20)<uint(16777216)) ? 8 : 0)
		i20 =  (i20 << i25)
		i26 =  ((uint(i20)<uint(268435456)) ? 4 : 0)
		i24 =  (i25 | i24)
		i20 =  (i20 << i26)
		i25 =  ((uint(i20)<uint(1073741824)) ? 2 : 0)
		i24 =  (i24 | i26)
		i24 =  (i24 | i25)
		i20 =  (i20 << i25)
		__asm(push(i20>-1), iftrue, target("___vfprintf__XprivateX__BB54_723_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_722_F"))
		i20 = i24
		__asm(jump, target("___vfprintf__XprivateX__BB54_724_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_723_F"))
		i20 =  (i20 & 1073741824)
		i24 =  (i24 + 1)
		i20 =  ((i20==0) ? 32 : i24)
	__asm(lbl("___vfprintf__XprivateX__BB54_724_F"))
		i20 =  (32 - i20)
	__asm(lbl("___vfprintf__XprivateX__BB54_725_F"))
		i20 =  (i20 + i19)
		i20 =  (i20 & 31)
		i24 =  (32 - i20)
		i20 =  ((i20==0) ? i20 : i24)
		__asm(push(i20<5), iftrue, target("___vfprintf__XprivateX__BB54_730_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_726_F"))
		i20 =  (i20 + -4)
		i19 =  (i20 + i19)
		i13 =  (i20 + i13)
		i18 =  (i20 + i18)
		__asm(push(i18>0), iftrue, target("___vfprintf__XprivateX__BB54_728_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_727_F"))
		i18 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_735_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_728_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_729_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_729_F"), lbl("___vfprintf__XprivateX__BB54_729_B"), label, lbl("___vfprintf__XprivateX__BB54_729_F")); 
		mstate.esp -= 8
		__asm(push(i23), push(mstate.esp), op(0x3c))
		__asm(push(i18), push((mstate.esp+4)), op(0x3c))
		state = 43
		mstate.esp -= 4;FSM___lshift_D2A.start()
		return
	__asm(lbl("___vfprintf_state43"))
		i18 = mstate.eax
		mstate.esp += 8
		__asm(jump, target("___vfprintf__XprivateX__BB54_735_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_730_F"))
		__asm(push(i20<4), iftrue, target("___vfprintf__XprivateX__BB54_732_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_731_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_733_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_732_F"))
		i20 =  (i20 + 28)
		i19 =  (i20 + i19)
		i13 =  (i20 + i13)
		i18 =  (i20 + i18)
	__asm(lbl("___vfprintf__XprivateX__BB54_733_F"))
		__asm(push(i18>0), iftrue, target("___vfprintf__XprivateX__BB54_729_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_734_F"))
		i18 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_735_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_735_F"))
		__asm(push(i19>0), iftrue, target("___vfprintf__XprivateX__BB54_737_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_736_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_738_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_737_F"))
		mstate.esp -= 8
		__asm(push(i10), push(mstate.esp), op(0x3c))
		__asm(push(i19), push((mstate.esp+4)), op(0x3c))
		state = 44
		mstate.esp -= 4;FSM___lshift_D2A.start()
		return
	__asm(lbl("___vfprintf_state44"))
		i10 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___vfprintf__XprivateX__BB54_738_F"))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2412)), op(0x37))))
		__asm(push(i19!=0), iftrue, target("___vfprintf__XprivateX__BB54_740_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_739_F"), lbl("___vfprintf__XprivateX__BB54_739_B"), label, lbl("___vfprintf__XprivateX__BB54_739_F")); 
		i19 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_751_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_740_F"))
		i19 =  ((__xasm<int>(push((i18+16)), op(0x37))))
		i23 =  ((__xasm<int>(push((i10+16)), op(0x37))))
		i20 =  (i19 - i23)
		__asm(push(i19==i23), iftrue, target("___vfprintf__XprivateX__BB54_742_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_741_F"))
		i19 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_747_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_742_F"))
		i19 =  (0)
	__asm(jump, target("___vfprintf__XprivateX__BB54_743_F"), lbl("___vfprintf__XprivateX__BB54_743_B"), label, lbl("___vfprintf__XprivateX__BB54_743_F")); 
		i20 =  (i19 ^ -1)
		i20 =  (i23 + i20)
		i24 =  (i20 << 2)
		i25 =  (i18 + i24)
		i24 =  (i10 + i24)
		i25 =  ((__xasm<int>(push((i25+20)), op(0x37))))
		i24 =  ((__xasm<int>(push((i24+20)), op(0x37))))
		__asm(push(i25==i24), iftrue, target("___vfprintf__XprivateX__BB54_745_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_744_F"))
		i19 =  ((uint(i25)<uint(i24)) ? -1 : 1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_747_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_745_F"))
		i19 =  (i19 + 1)
		__asm(push(i20>0), iftrue, target("___vfprintf__XprivateX__BB54_1522_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_746_F"))
		i19 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_747_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_747_F"))
		__asm(push(i19>-1), iftrue, target("___vfprintf__XprivateX__BB54_739_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_748_F"))
		i19 =  (10)
		mstate.esp -= 8
		__asm(push(i18), push(mstate.esp), op(0x3c))
		__asm(push(i19), push((mstate.esp+4)), op(0x3c))
		state = 45
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___vfprintf_state45"))
		i18 = mstate.eax
		mstate.esp += 8
		i12 =  (i12 + -1)
		i19 =  ((__xasm<int>(push((mstate.ebp+-2493)), op(0x37))))
		__asm(push(i19!=0), iftrue, target("___vfprintf__XprivateX__BB54_750_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_749_F"))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2457)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_751_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_750_F"))
		i19 =  (10)
		mstate.esp -= 8
		__asm(push(i21), push(mstate.esp), op(0x3c))
		__asm(push(i19), push((mstate.esp+4)), op(0x3c))
		state = 46
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___vfprintf_state46"))
		i21 = mstate.eax
		mstate.esp += 8
		i19 =  ((__xasm<int>(push((mstate.ebp+-2457)), op(0x37))))
	__asm(lbl("___vfprintf__XprivateX__BB54_751_F"))
		__asm(push(i12), push((mstate.ebp+-2529)), op(0x3c))
		i12 = i18
		i18 = i21
		__asm(push(i19>0), iftrue, target("___vfprintf__XprivateX__BB54_771_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_752_F"))
		__asm(push(i1==3), iftrue, target("___vfprintf__XprivateX__BB54_754_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_753_F"))
		__asm(push(i1!=5), iftrue, target("___vfprintf__XprivateX__BB54_771_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_754_F"))
		__asm(push(i19>-1), iftrue, target("___vfprintf__XprivateX__BB54_756_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_755_F"))
		i1 = i12
		i2 = i18
		i7 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_766_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_756_F"))
		i7 =  (5)
		mstate.esp -= 8
		__asm(push(i10), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		state = 47
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___vfprintf_state47"))
		i7 = mstate.eax
		mstate.esp += 8
		i1 =  ((__xasm<int>(push((i12+16)), op(0x37))))
		i2 =  ((__xasm<int>(push((i7+16)), op(0x37))))
		i10 =  (i1 - i2)
		__asm(push(i1==i2), iftrue, target("___vfprintf__XprivateX__BB54_758_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_757_F"))
		i2 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_763_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_758_F"))
		i1 =  (0)
	__asm(jump, target("___vfprintf__XprivateX__BB54_759_F"), lbl("___vfprintf__XprivateX__BB54_759_B"), label, lbl("___vfprintf__XprivateX__BB54_759_F")); 
		i10 =  (i1 ^ -1)
		i10 =  (i2 + i10)
		i13 =  (i10 << 2)
		i17 =  (i12 + i13)
		i13 =  (i7 + i13)
		i17 =  ((__xasm<int>(push((i17+20)), op(0x37))))
		i13 =  ((__xasm<int>(push((i13+20)), op(0x37))))
		__asm(push(i17==i13), iftrue, target("___vfprintf__XprivateX__BB54_761_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_760_F"))
		i1 =  ((uint(i17)<uint(i13)) ? -1 : 1)
		i2 = i1
		__asm(jump, target("___vfprintf__XprivateX__BB54_763_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_761_F"))
		i1 =  (i1 + 1)
		__asm(push(i10>0), iftrue, target("___vfprintf__XprivateX__BB54_1523_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_762_F"))
		i1 =  (0)
		i2 = i1
		__asm(jump, target("___vfprintf__XprivateX__BB54_763_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_763_F"))
		i1 = i2
		__asm(push(i1<1), iftrue, target("___vfprintf__XprivateX__BB54_765_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_764_F"))
		i1 =  ((__xasm<int>(push((mstate.ebp+-2529)), op(0x37))))
		i2 = i12
		i10 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_622_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_765_F"))
		i1 = i12
		i2 = i18
	__asm(lbl("___vfprintf__XprivateX__BB54_766_F"))
		i10 =  ((__xasm<int>(push((mstate.ebp+-2448)), op(0x37))))
		i10 =  (i10 ^ -1)
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_768_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_767_F"))
		i12 =  (_freelist)
		i13 =  ((__xasm<int>(push((i7+4)), op(0x37))))
		i13 =  (i13 << 2)
		i12 =  (i12 + i13)
		i13 =  ((__xasm<int>(push(i12), op(0x37))))
		__asm(push(i13), push(i7), op(0x3c))
		__asm(push(i7), push(i12), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_768_F"))
		__asm(push(i2==0), iftrue, target("___vfprintf__XprivateX__BB54_770_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_769_F"))
		i7 =  (0)
		i12 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_867_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_770_F"))
		i7 = i10
		i2 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_876_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_771_F"))
		i1 =  ((__xasm<int>(push((mstate.ebp+-2493)), op(0x37))))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_777_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_772_F"))
		i7 =  (0)
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_773_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_773_F"), lbl("___vfprintf__XprivateX__BB54_773_B"), label, lbl("___vfprintf__XprivateX__BB54_773_F")); 
		i2 = i1
		mstate.esp -= 8
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i10), push((mstate.esp+4)), op(0x3c))
		mstate.esp -= 4;FSM___quorem_D2A.start()
	__asm(lbl("___vfprintf_state48"))
		i1 = mstate.eax
		mstate.esp += 8
		i1 =  (i1 + 48)
		i12 =  (i17 + i7)
		__asm(push(i1), push(i12), op(0x3a))
		i12 =  ((__xasm<int>(push((i2+20)), op(0x37))))
		i13 =  (i7 + 1)
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_775_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_774_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_774_F"))
		i12 =  ((__xasm<int>(push((i2+16)), op(0x37))))
		__asm(push(i12<2), iftrue, target("___vfprintf__XprivateX__BB54_861_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_775_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_775_F"))
		__asm(push(i13>=i19), iftrue, target("___vfprintf__XprivateX__BB54_841_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_776_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_776_F"))
		i1 =  (10)
		mstate.esp -= 8
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 49
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___vfprintf_state49"))
		i1 = mstate.eax
		mstate.esp += 8
		i7 =  (i7 + 1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_773_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_777_F"))
		__asm(push(i13>0), iftrue, target("___vfprintf__XprivateX__BB54_779_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_778_F"))
		i1 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_780_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_779_F"))
		mstate.esp -= 8
		__asm(push(i18), push(mstate.esp), op(0x3c))
		__asm(push(i13), push((mstate.esp+4)), op(0x3c))
		state = 50
		mstate.esp -= 4;FSM___lshift_D2A.start()
		return
	__asm(lbl("___vfprintf_state50"))
		i1 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___vfprintf__XprivateX__BB54_780_F"))
		i7 =  (i7 & 1)
		__asm(push(i7!=0), iftrue, target("___vfprintf__XprivateX__BB54_782_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_781_F"))
		i7 = i1
		__asm(jump, target("___vfprintf__XprivateX__BB54_783_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_782_F"))
		i7 =  (1)
		i13 =  ((__xasm<int>(push((i1+4)), op(0x37))))
		mstate.esp -= 4
		__asm(push(i13), push(mstate.esp), op(0x3c))
		state = 51
		mstate.esp -= 4;FSM___Balloc_D2A.start()
		return
	__asm(lbl("___vfprintf_state51"))
		i13 = mstate.eax
		mstate.esp += 4
		i18 =  ((__xasm<int>(push((i1+16)), op(0x37))))
		i21 =  (i13 + 12)
		i18 =  (i18 << 2)
		i23 =  (i1 + 12)
		i18 =  (i18 + 8)
		memcpy(i21, i23, i18)
		mstate.esp -= 8
		__asm(push(i13), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		state = 52
		mstate.esp -= 4;FSM___lshift_D2A.start()
		return
	__asm(lbl("___vfprintf_state52"))
		i7 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___vfprintf__XprivateX__BB54_783_F"))
		i13 =  (0)
		i2 =  (i2 & 1)
		i18 = i13
	__asm(jump, target("___vfprintf__XprivateX__BB54_784_F"), lbl("___vfprintf__XprivateX__BB54_784_B"), label, lbl("___vfprintf__XprivateX__BB54_784_F")); 
		i21 = i1
		mstate.esp -= 8
		__asm(push(i12), push(mstate.esp), op(0x3c))
		__asm(push(i10), push((mstate.esp+4)), op(0x3c))
		mstate.esp -= 4;FSM___quorem_D2A.start()
	__asm(lbl("___vfprintf_state53"))
		i1 = mstate.eax
		mstate.esp += 8
		i23 =  ((__xasm<int>(push((i12+16)), op(0x37))))
		i20 =  ((__xasm<int>(push((i21+16)), op(0x37))))
		i22 =  (i23 - i20)
		i24 =  (i12 + 16)
		i25 =  (i1 + 48)
		i26 =  (i17 + i18)
		i27 =  (i18 + 1)
		__asm(push(i23==i20), iftrue, target("___vfprintf__XprivateX__BB54_786_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_785_F"))
		i20 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_791_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_786_F"))
		i23 =  (0)
	__asm(jump, target("___vfprintf__XprivateX__BB54_787_F"), lbl("___vfprintf__XprivateX__BB54_787_B"), label, lbl("___vfprintf__XprivateX__BB54_787_F")); 
		i22 =  (i23 ^ -1)
		i22 =  (i20 + i22)
		i28 =  (i22 << 2)
		i29 =  (i12 + i28)
		i28 =  (i21 + i28)
		i29 =  ((__xasm<int>(push((i29+20)), op(0x37))))
		i28 =  ((__xasm<int>(push((i28+20)), op(0x37))))
		__asm(push(i29==i28), iftrue, target("___vfprintf__XprivateX__BB54_789_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_788_F"))
		i23 =  ((uint(i29)<uint(i28)) ? -1 : 1)
		i20 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_791_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_789_F"))
		i23 =  (i23 + 1)
		__asm(push(i22>0), iftrue, target("___vfprintf__XprivateX__BB54_1524_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_790_F"))
		i23 =  (0)
		i20 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_791_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_791_F"))
		i23 = i20
		mstate.esp -= 8
		__asm(push(i10), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		state = 54
		mstate.esp -= 4;FSM___diff_D2A.start()
		return
	__asm(lbl("___vfprintf_state54"))
		i20 = mstate.eax
		mstate.esp += 8
		i22 =  ((__xasm<int>(push((i20+12)), op(0x37))))
		__asm(push(i22==0), iftrue, target("___vfprintf__XprivateX__BB54_793_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_792_F"))
		i22 =  (1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_800_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_793_F"))
		i22 =  ((__xasm<int>(push(i24), op(0x37))))
		i28 =  ((__xasm<int>(push((i20+16)), op(0x37))))
		i29 =  (i22 - i28)
		__asm(push(i22==i28), iftrue, target("___vfprintf__XprivateX__BB54_795_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_794_F"))
		i22 = i29
		__asm(jump, target("___vfprintf__XprivateX__BB54_800_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_795_F"))
		i22 =  (0)
	__asm(jump, target("___vfprintf__XprivateX__BB54_796_F"), lbl("___vfprintf__XprivateX__BB54_796_B"), label, lbl("___vfprintf__XprivateX__BB54_796_F")); 
		i29 =  (i22 ^ -1)
		i29 =  (i28 + i29)
		i30 =  (i29 << 2)
		i31 =  (i12 + i30)
		i30 =  (i20 + i30)
		i31 =  ((__xasm<int>(push((i31+20)), op(0x37))))
		i30 =  ((__xasm<int>(push((i30+20)), op(0x37))))
		__asm(push(i31==i30), iftrue, target("___vfprintf__XprivateX__BB54_798_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_797_F"))
		i22 =  ((uint(i31)<uint(i30)) ? -1 : 1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_800_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_798_F"))
		i22 =  (i22 + 1)
		__asm(push(i29>0), iftrue, target("___vfprintf__XprivateX__BB54_1525_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_799_F"))
		i22 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_800_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_800_F"))
		__asm(push(i20==0), iftrue, target("___vfprintf__XprivateX__BB54_802_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_801_F"))
		i28 =  (_freelist)
		i29 =  ((__xasm<int>(push((i20+4)), op(0x37))))
		i29 =  (i29 << 2)
		i28 =  (i28 + i29)
		i29 =  ((__xasm<int>(push(i28), op(0x37))))
		__asm(push(i29), push(i20), op(0x3c))
		__asm(push(i20), push(i28), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_802_F"))
		__asm(push(i22!=0), iftrue, target("___vfprintf__XprivateX__BB54_807_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_803_F"))
		i20 =  (i2 | i13)
		__asm(push(i20!=0), iftrue, target("___vfprintf__XprivateX__BB54_807_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_804_F"))
		__asm(push(i25!=57), iftrue, target("___vfprintf__XprivateX__BB54_806_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_805_F"), lbl("___vfprintf__XprivateX__BB54_805_B"), label, lbl("___vfprintf__XprivateX__BB54_805_F")); 
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_833_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_806_F"))
		i1 =  (i1 + 49)
		i1 =  ((i23>0) ? i1 : i25)
		__asm(push(i1), push(i26), op(0x3a))
		i1 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		i13 =  (i1 + i27)
		i1 =  ((__xasm<int>(push((mstate.ebp+-2529)), op(0x37))))
		i2 = i12
		i12 = i21
		i17 = i7
		i7 = i10
		i10 = i13
		__asm(jump, target("___vfprintf__XprivateX__BB54_863_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_807_F"))
		__asm(push(i23<0), iftrue, target("___vfprintf__XprivateX__BB54_810_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_808_F"))
		__asm(push(i23!=0), iftrue, target("___vfprintf__XprivateX__BB54_829_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_809_F"))
		i23 =  (i2 | i13)
		__asm(push(i23!=0), iftrue, target("___vfprintf__XprivateX__BB54_829_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_810_F"))
		i2 =  ((__xasm<int>(push((i12+20)), op(0x37))))
		__asm(push(i2!=0), iftrue, target("___vfprintf__XprivateX__BB54_814_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_811_F"))
		i2 =  ((__xasm<int>(push(i24), op(0x37))))
		__asm(push(i22<1), iftrue, target("___vfprintf__XprivateX__BB54_813_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_812_F"))
		__asm(push(i2>1), iftrue, target("___vfprintf__XprivateX__BB54_815_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_813_F"), lbl("___vfprintf__XprivateX__BB54_813_B"), label, lbl("___vfprintf__XprivateX__BB54_813_F")); 
		i1 = i25
		i2 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_828_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_814_F"))
		__asm(push(i22<1), iftrue, target("___vfprintf__XprivateX__BB54_813_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_815_F"))
		i2 =  (1)
		mstate.esp -= 8
		__asm(push(i12), push(mstate.esp), op(0x3c))
		__asm(push(i2), push((mstate.esp+4)), op(0x3c))
		state = 55
		mstate.esp -= 4;FSM___lshift_D2A.start()
		return
	__asm(lbl("___vfprintf_state55"))
		i2 = mstate.eax
		mstate.esp += 8
		i12 =  ((__xasm<int>(push((i2+16)), op(0x37))))
		i13 =  ((__xasm<int>(push((i10+16)), op(0x37))))
		i19 =  (i12 - i13)
		__asm(push(i12==i13), iftrue, target("___vfprintf__XprivateX__BB54_817_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_816_F"))
		i12 = i19
		__asm(jump, target("___vfprintf__XprivateX__BB54_822_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_817_F"))
		i12 =  (0)
	__asm(jump, target("___vfprintf__XprivateX__BB54_818_F"), lbl("___vfprintf__XprivateX__BB54_818_B"), label, lbl("___vfprintf__XprivateX__BB54_818_F")); 
		i19 =  (i12 ^ -1)
		i19 =  (i13 + i19)
		i22 =  (i19 << 2)
		i23 =  (i2 + i22)
		i22 =  (i10 + i22)
		i23 =  ((__xasm<int>(push((i23+20)), op(0x37))))
		i22 =  ((__xasm<int>(push((i22+20)), op(0x37))))
		__asm(push(i23==i22), iftrue, target("___vfprintf__XprivateX__BB54_820_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_819_F"))
		i12 =  ((uint(i23)<uint(i22)) ? -1 : 1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_822_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_820_F"))
		i12 =  (i12 + 1)
		__asm(push(i19>0), iftrue, target("___vfprintf__XprivateX__BB54_1526_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_821_F"))
		i12 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_822_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_822_F"))
		__asm(push(i12>0), iftrue, target("___vfprintf__XprivateX__BB54_826_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_823_F"))
		__asm(push(i12==0), iftrue, target("___vfprintf__XprivateX__BB54_825_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_824_F"), lbl("___vfprintf__XprivateX__BB54_824_B"), label, lbl("___vfprintf__XprivateX__BB54_824_F")); 
		i1 = i25
		__asm(jump, target("___vfprintf__XprivateX__BB54_828_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_825_F"))
		i12 =  (i25 & 1)
		__asm(push(i12==0), iftrue, target("___vfprintf__XprivateX__BB54_824_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_826_F"))
		i1 =  (i1 + 49)
		__asm(push(i1==58), iftrue, target("___vfprintf__XprivateX__BB54_832_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_827_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_828_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_828_F"))
		__asm(push(i1), push(i26), op(0x3a))
		i1 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		i13 =  (i1 + i27)
		i1 =  ((__xasm<int>(push((mstate.ebp+-2529)), op(0x37))))
		i12 = i21
		i17 = i7
		i7 = i10
		i10 = i13
		__asm(jump, target("___vfprintf__XprivateX__BB54_863_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_829_F"))
		__asm(push(i22<1), iftrue, target("___vfprintf__XprivateX__BB54_836_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_830_F"))
		__asm(push(i25==57), iftrue, target("___vfprintf__XprivateX__BB54_805_B"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_831_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_831_F"))
		i1 =  (i25 + 1)
		__asm(push(i1), push(i26), op(0x3a))
		i1 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		i13 =  (i1 + i27)
		i1 =  ((__xasm<int>(push((mstate.ebp+-2529)), op(0x37))))
		i2 = i12
		i12 = i21
		i17 = i7
		i7 = i10
		i10 = i13
		__asm(jump, target("___vfprintf__XprivateX__BB54_863_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_832_F"))
		i1 = i2
		__asm(jump, target("___vfprintf__XprivateX__BB54_833_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_833_F"))
		i2 =  (57)
		__asm(push(i2), push(i26), op(0x3a))
		i2 =  (i17 + i18)
		i12 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		i12 =  (i12 + i27)
		i17 = i21
		__asm(jump, target("___vfprintf__XprivateX__BB54_834_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_834_F"), lbl("___vfprintf__XprivateX__BB54_834_B"), label, lbl("___vfprintf__XprivateX__BB54_834_F")); 
		i13 = i1
		i19 = i12
		i12 = i2
		i1 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		__asm(push(i12==i1), iftrue, target("___vfprintf__XprivateX__BB54_859_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_835_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_835_F"))
		i1 = i13
		i2 = i17
		__asm(jump, target("___vfprintf__XprivateX__BB54_852_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_836_F"))
		__asm(push(i25), push(i26), op(0x3a))
		__asm(push(i27==i19), iftrue, target("___vfprintf__XprivateX__BB54_842_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_837_F"))
		i1 =  (10)
		mstate.esp -= 8
		__asm(push(i12), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 56
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___vfprintf_state56"))
		i1 = mstate.eax
		mstate.esp += 8
		__asm(push(i21!=i7), iftrue, target("___vfprintf__XprivateX__BB54_840_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_838_F"))
		i12 =  (10)
		mstate.esp -= 8
		__asm(push(i7), push(mstate.esp), op(0x3c))
		__asm(push(i12), push((mstate.esp+4)), op(0x3c))
		state = 57
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___vfprintf_state57"))
		i7 = mstate.eax
		mstate.esp += 8
		i12 = i7
	__asm(jump, target("___vfprintf__XprivateX__BB54_839_F"), lbl("___vfprintf__XprivateX__BB54_839_B"), label, lbl("___vfprintf__XprivateX__BB54_839_F")); 
		i21 = i12
		i12 =  (i18 + 1)
		i18 = i12
		i12 = i1
		i1 = i21
		__asm(jump, target("___vfprintf__XprivateX__BB54_784_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_840_F"))
		i12 =  (10)
		mstate.esp -= 8
		__asm(push(i21), push(mstate.esp), op(0x3c))
		__asm(push(i12), push((mstate.esp+4)), op(0x3c))
		state = 58
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___vfprintf_state58"))
		i21 = mstate.eax
		mstate.esp += 8
		mstate.esp -= 8
		__asm(push(i7), push(mstate.esp), op(0x3c))
		__asm(push(i12), push((mstate.esp+4)), op(0x3c))
		state = 59
		mstate.esp -= 4;FSM___multadd_D2A.start()
		return
	__asm(lbl("___vfprintf_state59"))
		i7 = mstate.eax
		mstate.esp += 8
		i12 = i21
		__asm(jump, target("___vfprintf__XprivateX__BB54_839_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_841_F"))
		i7 =  (0)
		i12 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		i12 =  (i12 + i13)
		i17 = i7
		i7 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_843_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_842_F"))
		i1 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		i13 =  (i1 + i27)
		i1 = i25
		i2 = i12
		i17 = i21
		i12 = i13
	__asm(lbl("___vfprintf__XprivateX__BB54_843_F"))
		i13 =  (1)
		mstate.esp -= 8
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i13), push((mstate.esp+4)), op(0x3c))
		state = 60
		mstate.esp -= 4;FSM___lshift_D2A.start()
		return
	__asm(lbl("___vfprintf_state60"))
		i2 = mstate.eax
		mstate.esp += 8
		i13 =  ((__xasm<int>(push((i2+16)), op(0x37))))
		i19 =  ((__xasm<int>(push((i10+16)), op(0x37))))
		i18 =  (i13 - i19)
		__asm(push(i13==i19), iftrue, target("___vfprintf__XprivateX__BB54_845_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_844_F"))
		i13 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_850_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_845_F"))
		i13 =  (0)
	__asm(jump, target("___vfprintf__XprivateX__BB54_846_F"), lbl("___vfprintf__XprivateX__BB54_846_B"), label, lbl("___vfprintf__XprivateX__BB54_846_F")); 
		i18 =  (i13 ^ -1)
		i18 =  (i19 + i18)
		i21 =  (i18 << 2)
		i23 =  (i2 + i21)
		i21 =  (i10 + i21)
		i23 =  ((__xasm<int>(push((i23+20)), op(0x37))))
		i21 =  ((__xasm<int>(push((i21+20)), op(0x37))))
		__asm(push(i23==i21), iftrue, target("___vfprintf__XprivateX__BB54_848_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_847_F"))
		i13 =  ((uint(i23)<uint(i21)) ? -1 : 1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_850_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_848_F"))
		i13 =  (i13 + 1)
		__asm(push(i18>0), iftrue, target("___vfprintf__XprivateX__BB54_1527_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_849_F"))
		i13 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_850_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_850_F"))
		__asm(push(i13<1), iftrue, target("___vfprintf__XprivateX__BB54_854_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_851_F"), lbl("___vfprintf__XprivateX__BB54_851_B"), label, lbl("___vfprintf__XprivateX__BB54_851_F")); 
		i1 = i2
		i2 = i17
		__asm(jump, target("___vfprintf__XprivateX__BB54_852_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_852_F"))
		i17 = i1
		i13 = i2
		i19 = i12
		i1 =  ((__xasm<int>(push((i19+-1)), op(0x35))))
		i2 =  (i19 + -1)
		__asm(push(i1!=57), iftrue, target("___vfprintf__XprivateX__BB54_860_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_853_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_853_F"))
		i1 = i17
		i17 = i13
		i12 = i19
		__asm(jump, target("___vfprintf__XprivateX__BB54_834_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_854_F"))
		__asm(push(i13==0), iftrue, target("___vfprintf__XprivateX__BB54_858_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_855_F"), lbl("___vfprintf__XprivateX__BB54_855_B"), label, lbl("___vfprintf__XprivateX__BB54_855_F")); 
		i1 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_856_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_856_F"), lbl("___vfprintf__XprivateX__BB54_856_B"), label, lbl("___vfprintf__XprivateX__BB54_856_F")); 
		i13 =  (i1 ^ -1)
		i13 =  (i12 + i13)
		i13 =  ((__xasm<int>(push(i13), op(0x35))))
		i1 =  (i1 + 1)
		__asm(push(i13!=48), iftrue, target("___vfprintf__XprivateX__BB54_862_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_857_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_857_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_856_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_858_F"))
		i1 =  (i1 & 1)
		__asm(push(i1==0), iftrue, target("___vfprintf__XprivateX__BB54_855_B"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_851_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_859_F"))
		i1 =  (49)
		__asm(push(i1), push(i12), op(0x3a))
		i1 =  ((__xasm<int>(push((mstate.ebp+-2529)), op(0x37))))
		i1 =  (i1 + 1)
		i2 = i13
		i12 = i17
		i17 = i7
		i7 = i10
		i10 = i19
		__asm(jump, target("___vfprintf__XprivateX__BB54_863_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_860_F"))
		i1 =  (i1 + 1)
		__asm(push(i1), push(i2), op(0x3a))
		i1 =  ((__xasm<int>(push((mstate.ebp+-2529)), op(0x37))))
		i2 = i17
		i12 = i13
		i17 = i7
		i7 = i10
		i10 = i19
		__asm(jump, target("___vfprintf__XprivateX__BB54_863_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_861_F"))
		i7 =  (0)
		i1 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		i13 =  (i1 + i13)
		i1 =  ((__xasm<int>(push((mstate.ebp+-2529)), op(0x37))))
		i12 = i7
		i17 = i18
		i7 = i10
		i10 = i13
		__asm(jump, target("___vfprintf__XprivateX__BB54_863_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_862_F"))
		i1 =  (i1 + -1)
		i13 =  (i12 - i1)
		i1 =  ((__xasm<int>(push((mstate.ebp+-2529)), op(0x37))))
		i12 = i17
		i17 = i7
		i7 = i10
		i10 = i13
	__asm(lbl("___vfprintf__XprivateX__BB54_863_F"))
		i13 = i17
		i17 = i10
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_865_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_864_F"))
		i10 =  (_freelist)
		i19 =  ((__xasm<int>(push((i7+4)), op(0x37))))
		i19 =  (i19 << 2)
		i10 =  (i10 + i19)
		i19 =  ((__xasm<int>(push(i10), op(0x37))))
		__asm(push(i19), push(i7), op(0x3c))
		__asm(push(i7), push(i10), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_865_F"))
		__asm(push(i13==0), iftrue, target("___vfprintf__XprivateX__BB54_1528_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_866_F"))
		i10 = i1
		i1 = i2
		i7 = i12
		i2 = i13
		i12 = i17
		__asm(jump, target("___vfprintf__XprivateX__BB54_867_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_867_F"))
		__asm(push(i7==i2), iftrue, target("___vfprintf__XprivateX__BB54_870_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_868_F"))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_870_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_869_F"))
		i13 =  (_freelist)
		i17 =  ((__xasm<int>(push((i7+4)), op(0x37))))
		i17 =  (i17 << 2)
		i13 =  (i13 + i17)
		i17 =  ((__xasm<int>(push(i13), op(0x37))))
		__asm(push(i17), push(i7), op(0x3c))
		__asm(push(i7), push(i13), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_870_F"))
		__asm(push(i2!=0), iftrue, target("___vfprintf__XprivateX__BB54_872_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_871_F"))
		i7 = i10
		i2 = i1
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_876_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_872_F"))
		i7 =  (_freelist)
		i13 =  ((__xasm<int>(push((i2+4)), op(0x37))))
		i13 =  (i13 << 2)
		i7 =  (i7 + i13)
		i13 =  ((__xasm<int>(push(i7), op(0x37))))
		__asm(push(i13), push(i2), op(0x3c))
		__asm(push(i2), push(i7), op(0x3c))
		i7 = i10
		i2 = i1
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_876_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_873_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		i1 =  (i7 + i2)
		i7 = i12
		i2 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_876_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_874_F"))
		i7 =  (i7 + -1)
		i7 =  (i23 - i7)
		i1 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		i1 =  (i1 + i7)
		i7 = i25
		i2 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_876_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_875_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
		i1 =  (i7 + i21)
		i7 = i25
		i2 = i10
	__asm(jump, target("___vfprintf__XprivateX__BB54_876_F"), lbl("___vfprintf__XprivateX__BB54_876_B"), label, lbl("___vfprintf__XprivateX__BB54_876_F")); 
		__asm(push(i2==0), iftrue, target("___vfprintf__XprivateX__BB54_878_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_877_F"))
		i10 =  (_freelist)
		i12 =  ((__xasm<int>(push((i2+4)), op(0x37))))
		i12 =  (i12 << 2)
		i10 =  (i10 + i12)
		i12 =  ((__xasm<int>(push(i10), op(0x37))))
		__asm(push(i12), push(i2), op(0x3c))
		__asm(push(i2), push(i10), op(0x3c))
	__asm(lbl("___vfprintf__XprivateX__BB54_878_F"))
		i2 =  (0)
		__asm(push(i2), push(i1), op(0x3a))
		i7 =  (i7 + 1)
	__asm(lbl("___vfprintf__XprivateX__BB54_879_F"))
		__asm(push(i7), push((mstate.ebp+-1760)), op(0x3c))
		__asm(push(i1), push((mstate.ebp+-1756)), op(0x3c))
		i7 =  ((__xasm<int>(push((mstate.ebp+-2385)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+-2538)), op(0x37))))
	__asm(lbl("___vfprintf__XprivateX__BB54_880_F"))
		i2 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-1760)), op(0x37))))
		__asm(push(i1==9999), iftrue, target("___vfprintf__XprivateX__BB54_882_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_881_F"))
		i19 = i1
		i18 = i7
		i17 = i2
		i7 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		i1 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2421)), op(0x37))))
		i13 = i7
		i10 = i2
		i7 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2376)), op(0x37))))
		i12 =  ((__xasm<int>(push((mstate.ebp+-2367)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_883_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_882_F"))
		i1 =  (2147483647)
		__asm(push(i1), push((mstate.ebp+-1760)), op(0x3c))
		i19 = i1
		i18 = i7
		i17 = i2
		i7 =  ((__xasm<int>(push((mstate.ebp+-2511)), op(0x37))))
		i1 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2421)), op(0x37))))
		i13 = i7
		i10 = i2
		i7 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+-2376)), op(0x37))))
		i12 =  ((__xasm<int>(push((mstate.ebp+-2367)), op(0x37))))
	__asm(lbl("___vfprintf__XprivateX__BB54_883_F"))
		__asm(push(i18==0), iftrue, target("___vfprintf__XprivateX__BB54_1529_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_884_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_885_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_885_F"))
		i18 =  (45)
		__asm(push(i18), push((mstate.ebp+-1762)), op(0x3a))
	__asm(jump, target("___vfprintf__XprivateX__BB54_886_F"), lbl("___vfprintf__XprivateX__BB54_886_B"), label, lbl("___vfprintf__XprivateX__BB54_886_F")); 
		i27 = i7
		__asm(push(i19!=2147483647), iftrue, target("___vfprintf__XprivateX__BB54_892_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_887_F"))
		i7 =  ((__xasm<int>(push(i17), op(0x35))))
		__asm(push(i7!=78), iftrue, target("___vfprintf__XprivateX__BB54_889_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_888_F"))
		i7 =  (__2E_str118283)
		i17 =  (__2E_str219284)
		i28 =  (0)
		__asm(push(i28), push((mstate.ebp+-1762)), op(0x3a))
		i7 =  ((i16>96) ? i7 : i17)
		i29 =  (3)
		i16 = i7
		i7 = i8
		i17 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i18 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i19 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2313)), op(0x37))))
		i20 = i1
		i21 = i10
		i1 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i22 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i23 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i24 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i25 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i26 = i1
		i1 = i28
		i8 = i29
		i10 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i28 = i10
		i10 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		i29 = i10
		i10 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_1205_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_889_F"))
		__asm(push(i16<97), iftrue, target("___vfprintf__XprivateX__BB54_891_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_890_F"))
		i7 =  (__2E_str320285)
		i28 =  (3)
		i29 =  (0)
		i16 = i7
		i7 = i8
		i17 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i18 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i19 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2313)), op(0x37))))
		i20 = i1
		i21 = i10
		i1 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i22 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i23 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i24 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i25 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i26 = i1
		i1 = i29
		i8 = i28
		i10 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i28 = i10
		i10 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		i29 = i10
		i10 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_1205_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_891_F"))
		i7 =  (__2E_str421)
		i28 =  (3)
		i29 =  (0)
		i16 = i7
		i7 = i8
		i17 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i18 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i19 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2313)), op(0x37))))
		i20 = i1
		i21 = i10
		i1 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i22 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i23 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i24 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i25 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i26 = i1
		i1 = i29
		i8 = i28
		i10 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i28 = i10
		i10 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		i29 = i10
		i10 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_1205_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_892_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-1756)), op(0x37))))
		i21 =  (i7 - i17)
		i7 =  (i8 | 256)
		__asm(push(i16==71), iftrue, target("___vfprintf__XprivateX__BB54_895_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_893_F"))
		__asm(push(i16==103), iftrue, target("___vfprintf__XprivateX__BB54_895_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_894_F"), lbl("___vfprintf__XprivateX__BB54_894_B"), label, lbl("___vfprintf__XprivateX__BB54_894_F")); 
		i8 = i13
		__asm(jump, target("___vfprintf__XprivateX__BB54_901_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_895_F"))
		i8 =  (i7 & 1)
		__asm(push(i19<-3), iftrue, target("___vfprintf__XprivateX__BB54_899_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_896_F"))
		__asm(push(i19>i1), iftrue, target("___vfprintf__XprivateX__BB54_899_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_897_F"))
		i1 =  ((i8==0) ? i21 : i1)
		i1 =  (i1 - i19)
		__asm(push(i1<0), iftrue, target("___vfprintf__XprivateX__BB54_927_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_898_F"))
		i8 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_901_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_899_F"))
		__asm(push(i8!=0), iftrue, target("___vfprintf__XprivateX__BB54_894_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_900_F"))
		i1 = i21
		i8 = i13
	__asm(lbl("___vfprintf__XprivateX__BB54_901_F"))
		i16 =  (i8 & 255)
		__asm(push(i16!=0), iftrue, target("___vfprintf__XprivateX__BB54_903_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_902_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_928_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_903_F"))
		i16 =  ((__xasm<int>(push((mstate.ebp+-2178)), op(0x37))))
		__asm(push(i8), push(i16), op(0x3a))
		i16 =  (i19 + -1)
		__asm(push(i16>-1), iftrue, target("___vfprintf__XprivateX__BB54_913_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_904_F"))
		i16 =  (45)
		i13 =  ((__xasm<int>(push((mstate.ebp+-2196)), op(0x37))))
		__asm(push(i16), push(i13), op(0x3a))
		i16 =  (1 - i19)
		__asm(push(i16>9), iftrue, target("___vfprintf__XprivateX__BB54_909_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_905_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_906_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_906_F"), lbl("___vfprintf__XprivateX__BB54_906_B"), label, lbl("___vfprintf__XprivateX__BB54_906_F")); 
		i19 =  (i8 & 255)
		__asm(push(i19==69), iftrue, target("___vfprintf__XprivateX__BB54_920_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_907_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_907_F"))
		i19 =  (i8 & 255)
		__asm(push(i19==101), iftrue, target("___vfprintf__XprivateX__BB54_920_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_908_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_908_F"))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2187)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_921_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_909_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_910_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_910_F"), lbl("___vfprintf__XprivateX__BB54_910_B"), label, lbl("___vfprintf__XprivateX__BB54_910_F")); 
		i19 =  (-1)
		i13 =  ((__xasm<int>(push((mstate.ebp+-2061)), op(0x37))))
		i13 =  (i13 + 5)
		__asm(jump, target("___vfprintf__XprivateX__BB54_911_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_911_F"), lbl("___vfprintf__XprivateX__BB54_911_B"), label, lbl("___vfprintf__XprivateX__BB54_911_F")); 
		i18 =  (i16 / 10)
		i20 =  (i18 * 10)
		i20 =  (i16 - i20)
		i20 =  (i20 + 48)
		__asm(push(i20), push(i13), op(0x3a))
		i13 =  (i13 + -1)
		i19 =  (i19 + 1)
		__asm(push(i16<100), iftrue, target("___vfprintf__XprivateX__BB54_915_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_912_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_912_F"))
		i16 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_911_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_913_F"))
		i19 =  (43)
		i13 =  ((__xasm<int>(push((mstate.ebp+-2196)), op(0x37))))
		__asm(push(i19), push(i13), op(0x3a))
		__asm(push(i16>9), iftrue, target("___vfprintf__XprivateX__BB54_910_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_914_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_906_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_915_F"))
		i16 =  ((mstate.ebp+-224))
		i13 =  (4 - i19)
		i18 =  (i18 + 48)
		i16 =  (i16 + i13)
		__asm(push(i18), push(i16), op(0x3a))
		__asm(push(i13<6), iftrue, target("___vfprintf__XprivateX__BB54_917_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_916_F"))
		i16 =  ((__xasm<int>(push((mstate.ebp+-2187)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_923_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_917_F"))
		i16 =  (0)
		i13 =  ((__xasm<int>(push((mstate.ebp+-2061)), op(0x37))))
		i13 =  (i13 - i19)
		i19 =  (4 - i19)
	__asm(jump, target("___vfprintf__XprivateX__BB54_918_F"), lbl("___vfprintf__XprivateX__BB54_918_B"), label, lbl("___vfprintf__XprivateX__BB54_918_F")); 
		i18 =  (i13 + i16)
		i18 =  ((__xasm<int>(push((i18+4)), op(0x35))))
		i20 =  ((__xasm<int>(push((mstate.ebp+-2223)), op(0x37))))
		i20 =  (i20 + i16)
		__asm(push(i18), push((i20+2)), op(0x3a))
		i16 =  (i16 + 1)
		i18 =  (i19 + i16)
		__asm(push(i18>5), iftrue, target("___vfprintf__XprivateX__BB54_922_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_919_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_918_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_920_F"))
		i19 =  (48)
		i13 =  ((__xasm<int>(push((mstate.ebp+-2187)), op(0x37))))
		__asm(push(i19), push(i13), op(0x3a))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2052)), op(0x37))))
	__asm(lbl("___vfprintf__XprivateX__BB54_921_F"))
		i16 =  (i16 + 48)
		__asm(push(i16), push(i19), op(0x3a))
		i16 =  (i19 + 1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_923_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_922_F"))
		i19 =  ((mstate.ebp+-1752))
		i16 =  (i16 << 0)
		i16 =  (i16 + i19)
		i16 =  (i16 + 2)
	__asm(lbl("___vfprintf__XprivateX__BB54_923_F"))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2223)), op(0x37))))
		i19 =  (i16 - i19)
		i28 =  (i19 + i1)
		__asm(push(i1>1), iftrue, target("___vfprintf__XprivateX__BB54_926_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_924_F"))
		i16 =  (i7 & 1)
		__asm(push(i16!=0), iftrue, target("___vfprintf__XprivateX__BB54_926_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_925_F"))
		i29 =  (0)
		i16 = i17
		i17 = i1
		i13 = i8
		i18 = i19
		i1 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i19 = i1
		i20 = i21
		i21 = i10
		i1 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i22 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i23 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i24 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i25 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i26 = i1
		i1 = i29
		i8 = i28
		i10 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i28 = i10
		i10 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		i29 = i10
		i10 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_1205_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_926_F"))
		i29 =  (0)
		i28 =  (i28 + 1)
		i16 = i17
		i17 = i1
		i13 = i8
		i18 = i19
		i1 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i19 = i1
		i20 = i21
		i21 = i10
		i1 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i22 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i23 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i24 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i25 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i26 = i1
		i1 = i29
		i8 = i28
		i10 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i28 = i10
		i10 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		i29 = i10
		i10 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_1205_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_927_F"))
		i1 =  (0)
		i8 = i1
		__asm(jump, target("___vfprintf__XprivateX__BB54_928_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_928_F"))
		i16 =  ((i19>0) ? i19 : 1)
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_931_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_929_F"))
		i13 =  (i7 & 1)
		__asm(push(i13!=0), iftrue, target("___vfprintf__XprivateX__BB54_931_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_930_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_932_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_931_F"))
		i16 =  (i1 + i16)
		i16 =  (i16 + 1)
	__asm(lbl("___vfprintf__XprivateX__BB54_932_F"))
		i28 = i16
		__asm(push(i14==0), iftrue, target("___vfprintf__XprivateX__BB54_934_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_933_F"))
		__asm(push(i19>0), iftrue, target("___vfprintf__XprivateX__BB54_935_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_934_F"))
		i29 =  (0)
		i16 = i17
		i17 = i1
		i13 = i8
		i1 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i18 = i1
		i20 = i21
		i21 = i10
		i1 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i22 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i23 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i24 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i25 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i26 = i1
		i1 = i29
		i8 = i28
		i10 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i28 = i10
		i10 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		i29 = i10
		i10 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_1205_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_935_F"))
		i16 =  ((__xasm<int>(push(i14), op(0x35))))
		__asm(push(i16==127), iftrue, target("___vfprintf__XprivateX__BB54_1530_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_936_F"))
		i16 =  (0)
		i13 = i14
		i14 = i16
		__asm(jump, target("___vfprintf__XprivateX__BB54_937_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_937_F"), lbl("___vfprintf__XprivateX__BB54_937_B"), label, lbl("___vfprintf__XprivateX__BB54_937_F")); 
		i18 = i14
		i14 =  ((__xasm<int>(push(i13), op(0x35), op(0x51))))
		__asm(push(i14<i19), iftrue, target("___vfprintf__XprivateX__BB54_939_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_938_F"))
		i14 = i19
		i19 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_942_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_939_F"))
		i20 =  ((__xasm<int>(push((i13+1)), op(0x35))))
		i22 =  ((i20==0) ? 1 : 0)
		i23 =  (i13 + 1)
		i22 =  (i22 & 1)
		i13 =  ((i20==0) ? i13 : i23)
		i20 =  ((__xasm<int>(push(i13), op(0x35))))
		i23 =  (i22 ^ 1)
		i16 =  (i16 + i22)
		i18 =  (i18 + i23)
		i14 =  (i19 - i14)
		__asm(push(i20==127), iftrue, target("___vfprintf__XprivateX__BB54_941_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_940_F"))
		i19 = i14
		i14 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_937_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_941_F"))
		i19 = i18
	__asm(jump, target("___vfprintf__XprivateX__BB54_942_F"), lbl("___vfprintf__XprivateX__BB54_942_B"), label, lbl("___vfprintf__XprivateX__BB54_942_F")); 
		i20 = i14
		i22 = i19
		i23 = i16
		i29 =  (0)
		i16 =  (i22 + i28)
		i28 =  (i16 + i23)
		i16 = i17
		i17 = i1
		i14 = i13
		i13 = i8
		i1 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i18 = i1
		i19 = i20
		i20 = i21
		i21 = i10
		i1 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i24 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i25 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i26 = i1
		i1 = i29
		i8 = i28
		i10 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i28 = i10
		i10 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		i29 = i10
		i10 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_1205_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_943_F"))
		i1 =  (i12 + 4)
		i7 = i12
	__asm(lbl("___vfprintf__XprivateX__BB54_944_F"))
		i7 =  ((__xasm<int>(push(i7), op(0x37))))
		i8 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		i8 =  (i8 >> 31)
		i16 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		__asm(push(i16), push(i7), op(0x3c))
		__asm(push(i8), push((i7+4)), op(0x3c))
		i7 =  (i2 + 1)
		i2 =  ((__xasm<int>(push((mstate.ebp+-2304)), op(0x37))))
		i10 = i2
		i6 = i16
		i16 = i13
		i2 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i24 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i13 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2313)), op(0x37))))
		i18 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i17 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i12 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i20 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i19 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i8 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		i22 = i2
		i2 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i23 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_23_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_945_F"))
		i7 =  (i8 & 1024)
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_950_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_946_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_948_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_947_F"))
		i1 =  (i2 << 3)
		i7 =  (i7 + i1)
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_949_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_948_F"))
		i1 =  (i12 + 4)
		i7 = i12
	__asm(lbl("___vfprintf__XprivateX__BB54_949_F"))
		i7 =  ((__xasm<int>(push(i7), op(0x37))))
		i8 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		__asm(push(i8), push(i7), op(0x3c))
		i7 =  (i2 + 1)
		i2 =  ((__xasm<int>(push((mstate.ebp+-2304)), op(0x37))))
		i10 = i2
		i6 = i8
		i16 = i13
		i2 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i24 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i13 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2313)), op(0x37))))
		i18 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i17 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i12 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i20 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i19 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i8 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		i22 = i2
		i2 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i23 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_23_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_950_F"))
		i7 =  (i8 & 2048)
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_955_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_951_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_953_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_952_F"))
		i1 =  (i2 << 3)
		i7 =  (i7 + i1)
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_954_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_953_F"))
		i1 =  (i12 + 4)
		i7 = i12
	__asm(lbl("___vfprintf__XprivateX__BB54_954_F"))
		i7 =  ((__xasm<int>(push(i7), op(0x37))))
		i8 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		__asm(push(i8), push(i7), op(0x3c))
		i7 =  (i2 + 1)
		i2 =  ((__xasm<int>(push((mstate.ebp+-2304)), op(0x37))))
		i10 = i2
		i6 = i8
		i16 = i13
		i2 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i24 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i13 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2313)), op(0x37))))
		i18 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i17 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i12 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i20 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i19 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i8 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		i22 = i2
		i2 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i23 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_23_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_955_F"))
		i7 =  (i8 & 4096)
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_960_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_956_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_958_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_957_F"))
		i1 =  (i2 << 3)
		i7 =  (i7 + i1)
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_959_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_958_F"))
		i1 =  (i12 + 4)
		i7 = i12
	__asm(lbl("___vfprintf__XprivateX__BB54_959_F"))
		i7 =  ((__xasm<int>(push(i7), op(0x37))))
		i8 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		i8 =  (i8 >> 31)
		i16 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		__asm(push(i16), push(i7), op(0x3c))
		__asm(push(i8), push((i7+4)), op(0x3c))
		i7 =  (i2 + 1)
		i2 =  ((__xasm<int>(push((mstate.ebp+-2304)), op(0x37))))
		i10 = i2
		i6 = i16
		i16 = i13
		i2 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i24 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i13 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2313)), op(0x37))))
		i18 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i17 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i12 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i20 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i19 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i8 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		i22 = i2
		i2 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i23 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_23_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_960_F"))
		i7 =  (i8 & 16)
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_965_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_961_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_963_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_962_F"))
		i1 =  (i2 << 3)
		i7 =  (i7 + i1)
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_964_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_963_F"))
		i1 =  (i12 + 4)
		i7 = i12
	__asm(lbl("___vfprintf__XprivateX__BB54_964_F"))
		i7 =  ((__xasm<int>(push(i7), op(0x37))))
		i8 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		__asm(push(i8), push(i7), op(0x3c))
		i7 =  (i2 + 1)
		i2 =  ((__xasm<int>(push((mstate.ebp+-2304)), op(0x37))))
		i10 = i2
		i6 = i8
		i16 = i13
		i2 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i24 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i13 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2313)), op(0x37))))
		i18 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i17 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i12 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i20 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i19 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i8 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		i22 = i2
		i2 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i23 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_23_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_965_F"))
		i7 =  (i8 & 64)
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_970_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_966_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_968_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_967_F"))
		i1 =  (i2 << 3)
		i7 =  (i7 + i1)
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_969_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_968_F"))
		i1 =  (i12 + 4)
		i7 = i12
	__asm(lbl("___vfprintf__XprivateX__BB54_969_F"))
		i7 =  ((__xasm<int>(push(i7), op(0x37))))
		i8 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		__asm(push(i8), push(i7), op(0x3b))
		i7 =  (i2 + 1)
		i2 =  ((__xasm<int>(push((mstate.ebp+-2304)), op(0x37))))
		i10 = i2
		i6 = i8
		i16 = i13
		i2 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i24 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i13 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2313)), op(0x37))))
		i18 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i17 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i12 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i20 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i19 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i8 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		i22 = i2
		i2 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i23 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_23_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_970_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		i1 =  (i8 & 8192)
		__asm(push(i1==0), iftrue, target("___vfprintf__XprivateX__BB54_975_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_971_F"))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_973_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_972_F"))
		i1 =  (i2 << 3)
		i7 =  (i7 + i1)
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_974_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_973_F"))
		i1 =  (i12 + 4)
		i7 = i12
	__asm(lbl("___vfprintf__XprivateX__BB54_974_F"))
		i7 =  ((__xasm<int>(push(i7), op(0x37))))
		i8 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		__asm(push(i8), push(i7), op(0x3a))
		i7 =  (i2 + 1)
		i2 =  ((__xasm<int>(push((mstate.ebp+-2304)), op(0x37))))
		i10 = i2
		i6 = i8
		i16 = i13
		i2 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i24 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i13 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2313)), op(0x37))))
		i18 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i17 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i12 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i20 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i19 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i8 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		i22 = i2
		i2 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i23 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_23_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_975_F"))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_977_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_976_F"))
		i1 =  (i2 << 3)
		i7 =  (i7 + i1)
		i1 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_978_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_977_F"))
		i1 =  (i12 + 4)
		i7 = i12
	__asm(lbl("___vfprintf__XprivateX__BB54_978_F"))
		i7 =  ((__xasm<int>(push(i7), op(0x37))))
		i8 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		__asm(push(i8), push(i7), op(0x3c))
		i7 =  (i2 + 1)
		i2 =  ((__xasm<int>(push((mstate.ebp+-2304)), op(0x37))))
		i10 = i2
		i6 = i8
		i16 = i13
		i2 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i24 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i13 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2313)), op(0x37))))
		i18 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i17 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i12 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i20 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i19 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i8 = i2
		i2 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		i22 = i2
		i2 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i23 = i7
		i7 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_23_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_979_F"))
		i7 =  (i8 | 16)
	__asm(lbl("___vfprintf__XprivateX__BB54_980_F"))
		i8 =  (i7 & 7200)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_996_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_981_F"))
		i8 =  (i7 & 4096)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_985_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_982_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_984_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_983_F"))
		i16 =  (0)
		i17 =  (i2 << 3)
		i8 =  (i8 + i17)
		i17 =  ((__xasm<int>(push(i8), op(0x37))))
		i8 =  ((__xasm<int>(push((i8+4)), op(0x37))))
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i19 =  (8)
		i2 =  (i2 + 1)
		i16 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i18 = i16
		i16 = i17
		i17 = i19
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_984_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x37))))
		i17 =  ((__xasm<int>(push((i12+4)), op(0x37))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i2 =  (i2 + 1)
		i12 =  (i12 + 8)
		i19 =  (8)
		i8 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i18 = i8
		i8 = i17
		i17 = i19
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_985_F"))
		i8 =  (i7 & 1024)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_989_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_986_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_988_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_987_F"))
		i17 =  (0)
		i16 =  (i2 << 3)
		i8 =  (i8 + i16)
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		__asm(push(i17), push((mstate.ebp+-1762)), op(0x3a))
		i19 =  (8)
		i2 =  (i2 + 1)
		i16 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i18 = i16
		i16 = i8
		i8 = i17
		i17 = i19
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_988_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x37))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (8)
		i2 =  (i2 + 1)
		i12 =  (i12 + 4)
		i18 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_989_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		i16 =  (i7 & 2048)
		__asm(push(i16==0), iftrue, target("___vfprintf__XprivateX__BB54_993_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_990_F"))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_992_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_991_F"))
		i16 =  (0)
		i17 =  (i2 << 3)
		i8 =  (i8 + i17)
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (i8 >> 31)
		i19 =  (8)
		i2 =  (i2 + 1)
		i16 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i18 = i16
		i16 = i8
		i8 = i17
		i17 = i19
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_992_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x37))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i8 =  (i16 >> 31)
		i17 =  (8)
		i2 =  (i2 + 1)
		i12 =  (i12 + 4)
		i18 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_993_F"))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_995_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_994_F"))
		i16 =  (0)
		i17 =  (i2 << 3)
		i8 =  (i8 + i17)
		i17 =  ((__xasm<int>(push(i8), op(0x37))))
		i8 =  ((__xasm<int>(push((i8+4)), op(0x37))))
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i19 =  (8)
		i2 =  (i2 + 1)
		i16 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i18 = i16
		i16 = i17
		i17 = i19
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_995_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x37))))
		i17 =  ((__xasm<int>(push((i12+4)), op(0x37))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i2 =  (i2 + 1)
		i12 =  (i12 + 8)
		i19 =  (8)
		i8 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i18 = i8
		i8 = i17
		i17 = i19
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_996_F"))
		i8 =  (i7 & 16)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1000_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_997_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_999_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_998_F"))
		i16 =  (0)
		i17 =  (i2 << 3)
		i8 =  (i8 + i17)
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (8)
		i2 =  (i2 + 1)
		i18 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_999_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x37))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (8)
		i2 =  (i2 + 1)
		i12 =  (i12 + 4)
		i18 = i16
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1000_F"))
		i8 =  (i7 & 64)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1004_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1001_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1003_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1002_F"))
		i16 =  (0)
		i17 =  (i2 << 3)
		i8 =  (i8 + i17)
		i8 =  ((__xasm<int>(push(i8), op(0x36))))
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (8)
		i2 =  (i2 + 1)
		i18 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1003_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x36))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (8)
		i2 =  (i2 + 1)
		i12 =  (i12 + 4)
		i18 = i16
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1004_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		i16 =  (i7 & 8192)
		__asm(push(i16==0), iftrue, target("___vfprintf__XprivateX__BB54_1008_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1005_F"))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1007_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1006_F"))
		i16 =  (0)
		i17 =  (i2 << 3)
		i8 =  (i8 + i17)
		i8 =  ((__xasm<int>(push(i8), op(0x35))))
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (8)
		i2 =  (i2 + 1)
		i18 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1007_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x35))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (8)
		i2 =  (i2 + 1)
		i12 =  (i12 + 4)
		i18 = i16
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1008_F"))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1010_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1009_F"))
		i16 =  (0)
		i17 =  (i2 << 3)
		i8 =  (i8 + i17)
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (8)
		i2 =  (i2 + 1)
		i18 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1010_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x37))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (8)
		i2 =  (i2 + 1)
		i12 =  (i12 + 4)
		i18 = i16
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1011_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_1013_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1012_F"))
		i16 =  (i2 << 3)
		i7 =  (i7 + i16)
		i16 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_1014_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1013_F"))
		i16 =  (i12 + 4)
		i7 = i12
	__asm(lbl("___vfprintf__XprivateX__BB54_1014_F"))
		i12 = i16
		i16 =  (120)
		i17 =  ((__xasm<int>(push(i7), op(0x37))))
		i7 =  ((__xasm<int>(push((mstate.ebp+-2169)), op(0x37))))
		__asm(push(i16), push(i7), op(0x3a))
		i19 =  (0)
		__asm(push(i19), push((mstate.ebp+-1762)), op(0x3a))
		i20 =  (_xdigs_lower_2E_4528)
		i22 =  (16)
		i2 =  (i2 + 1)
		i7 =  (i8 | 4096)
		i8 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i18 = i8
		i16 = i17
		i8 = i19
		i17 = i22
		i19 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1015_F"))
		i7 =  (i8 | 16)
	__asm(lbl("___vfprintf__XprivateX__BB54_1016_F"))
		i8 =  (i7 & 16)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1060_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1017_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1019_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1018_F"))
		i8 =  (0)
		mstate.esp -= 8
		i16 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		__asm(push(i16), push(mstate.esp), op(0x3c))
		__asm(push(i8), push((mstate.esp+4)), op(0x3c))
		state = 61
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___vfprintf_state61"))
		i8 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___vfprintf__XprivateX__BB54_1019_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1021_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1020_F"))
		i16 =  (i2 << 3)
		i8 =  (i8 + i16)
		i16 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_1022_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1021_F"))
		i16 =  (i12 + 4)
		i8 = i12
	__asm(lbl("___vfprintf__XprivateX__BB54_1022_F"))
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		i2 =  (i2 + 1)
		i10 = i8
		__asm(push(i8!=0), iftrue, target("___vfprintf__XprivateX__BB54_1024_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1023_F"))
		i8 =  (__2E_str522)
		i10 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i12 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1066_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1024_F"))
		i12 =  (_initial_2E_4576)
		i17 =  ((__xasm<int>(push((mstate.ebp+-2106)), op(0x37))))
		i18 =  (128)
		memcpy(i17, i12, i18)
		__asm(push(i1<0), iftrue, target("___vfprintf__XprivateX__BB54_1030_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1025_F"))
		i8 =  (0)
		i12 = i10
	__asm(jump, target("___vfprintf__XprivateX__BB54_1026_F"), lbl("___vfprintf__XprivateX__BB54_1026_B"), label, lbl("___vfprintf__XprivateX__BB54_1026_F")); 
		i17 =  ((mstate.ebp+-192))
		i18 =  ((__xasm<int>(push(i12), op(0x37))))
		mstate.esp -= 12
		i19 =  ((__xasm<int>(push((mstate.ebp+-2214)), op(0x37))))
		__asm(push(i19), push(mstate.esp), op(0x3c))
		__asm(push(i18), push((mstate.esp+4)), op(0x3c))
		__asm(push(i17), push((mstate.esp+8)), op(0x3c))
		mstate.esp -= 4;FSM__UTF8_wcrtomb.start()
	__asm(lbl("___vfprintf_state62"))
		i17 = mstate.eax
		mstate.esp += 12
		i12 =  (i12 + 4)
		i18 =  (i17 + -1)
		__asm(push(uint(i18)<uint(-2)), iftrue, target("___vfprintf__XprivateX__BB54_1028_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1027_F"), lbl("___vfprintf__XprivateX__BB54_1027_B"), label, lbl("___vfprintf__XprivateX__BB54_1027_F")); 
		i12 = i17
		__asm(jump, target("___vfprintf__XprivateX__BB54_1043_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1028_F"))
		i18 =  (i17 + i8)
		__asm(push(uint(i18)>uint(i1)), iftrue, target("___vfprintf__XprivateX__BB54_1027_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1029_F"))
		i8 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_1026_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1030_F"))
		i12 =  ((__xasm<int>(push((mstate.ebp+-1989)), op(0x37))))
		i12 =  ((__xasm<int>(push(i12), op(0x37))))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1531_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1031_F"))
		i12 =  (0)
		i17 =  (-1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1032_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1032_F"), lbl("___vfprintf__XprivateX__BB54_1032_B"), label, lbl("___vfprintf__XprivateX__BB54_1032_F")); 
		i18 =  ((__xasm<int>(push(i8), op(0x37))))
		i19 = i8
		__asm(push(uint(i18)>uint(127)), iftrue, target("___vfprintf__XprivateX__BB54_1034_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1033_F"))
		i18 =  (1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1036_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1034_F"))
		i20 =  ((mstate.ebp+-192))
		mstate.esp -= 12
		i22 =  ((__xasm<int>(push((mstate.ebp+-2232)), op(0x37))))
		__asm(push(i22), push(mstate.esp), op(0x3c))
		__asm(push(i18), push((mstate.esp+4)), op(0x3c))
		__asm(push(i20), push((mstate.esp+8)), op(0x3c))
		mstate.esp -= 4;FSM__UTF8_wcrtomb.start()
	__asm(lbl("___vfprintf_state63"))
		i18 = mstate.eax
		mstate.esp += 12
		__asm(push(i18==-1), iftrue, target("___vfprintf__XprivateX__BB54_1532_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1035_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1036_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1036_F"))
		i19 =  ((__xasm<int>(push(i19), op(0x37))))
		__asm(push(i19!=0), iftrue, target("___vfprintf__XprivateX__BB54_1038_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1037_F"))
		i8 =  (i12 + i18)
		i8 =  (i8 + -1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1041_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1038_F"))
		i8 =  (i8 + 4)
		i17 =  (i17 + 1)
		i12 =  (i18 + i12)
		__asm(push(i17==-2), iftrue, target("___vfprintf__XprivateX__BB54_1040_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1039_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1032_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1040_F"))
		i8 = i12
	__asm(jump, target("___vfprintf__XprivateX__BB54_1041_F"), lbl("___vfprintf__XprivateX__BB54_1041_B"), label, lbl("___vfprintf__XprivateX__BB54_1041_F")); 
		__asm(push(i8==-1), iftrue, target("___vfprintf__XprivateX__BB54_1533_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1042_F"))
		i12 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1043_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1043_F"))
		i17 =  (0)
		mstate.esp -= 8
		i18 =  (i8 + 1)
		__asm(push(i17), push(mstate.esp), op(0x3c))
		__asm(push(i18), push((mstate.esp+4)), op(0x3c))
		state = 64
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___vfprintf_state64"))
		i17 = mstate.eax
		mstate.esp += 8
		__asm(push(i17!=0), iftrue, target("___vfprintf__XprivateX__BB54_1045_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1044_F"))
		i8 =  (0)
		i10 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_1056_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1045_F"))
		i18 =  (_initial_2E_4576)
		i19 =  ((__xasm<int>(push((mstate.ebp+-2106)), op(0x37))))
		i20 =  (128)
		memcpy(i19, i18, i20)
		i18 = i17
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1052_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1046_F"))
		i12 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1047_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1047_F"), lbl("___vfprintf__XprivateX__BB54_1047_B"), label, lbl("___vfprintf__XprivateX__BB54_1047_F")); 
		i19 =  ((mstate.ebp+-192))
		i20 =  ((__xasm<int>(push(i10), op(0x37))))
		mstate.esp -= 12
		i22 =  (i17 + i12)
		__asm(push(i22), push(mstate.esp), op(0x3c))
		__asm(push(i20), push((mstate.esp+4)), op(0x3c))
		__asm(push(i19), push((mstate.esp+8)), op(0x3c))
		mstate.esp -= 4;FSM__UTF8_wcrtomb.start()
	__asm(lbl("___vfprintf_state65"))
		i19 = mstate.eax
		mstate.esp += 12
		i10 =  (i10 + 4)
		i20 =  (i19 + -1)
		__asm(push(uint(i20)<uint(-2)), iftrue, target("___vfprintf__XprivateX__BB54_1049_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1048_F"))
		i8 = i22
		i10 = i19
		__asm(jump, target("___vfprintf__XprivateX__BB54_1053_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1049_F"))
		i12 =  (i12 + i19)
		i20 =  (i17 + i12)
		i22 =  (i20 - i18)
		__asm(push(uint(i22)<uint(i8)), iftrue, target("___vfprintf__XprivateX__BB54_1051_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1050_F"))
		i8 = i20
		i10 = i19
		__asm(jump, target("___vfprintf__XprivateX__BB54_1053_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1051_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1047_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1052_F"))
		i8 = i17
		i10 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_1053_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1053_F"))
		__asm(push(i10!=-1), iftrue, target("___vfprintf__XprivateX__BB54_1055_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1054_F"))
		i7 =  (0)
		mstate.esp -= 8
		__asm(push(i17), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		state = 66
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___vfprintf_state66"))
		i8 = mstate.eax
		mstate.esp += 8
		__asm(jump, target("___vfprintf__XprivateX__BB54_1059_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1055_F"))
		i12 =  (0)
		__asm(push(i12), push(i8), op(0x3a))
		i8 = i17
	__asm(jump, target("___vfprintf__XprivateX__BB54_1056_F"), lbl("___vfprintf__XprivateX__BB54_1056_B"), label, lbl("___vfprintf__XprivateX__BB54_1056_F")); 
		i12 = i10
		i10 = i8
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_1058_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1057_F"))
		i8 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_1066_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1058_F"))
		i7 = i10
	__asm(lbl("___vfprintf__XprivateX__BB54_1059_F"))
		i0 =  ((__xasm<int>(push((mstate.ebp+-1980)), op(0x37))))
		i0 =  ((__xasm<int>(push(i0), op(0x36))))
		i0 =  (i0 | 64)
		i2 =  ((__xasm<int>(push((mstate.ebp+-1980)), op(0x37))))
		__asm(push(i0), push(i2), op(0x3b))
		i0 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		i6 = i0
		i9 = i21
		i0 = i7
		__asm(jump, target("___vfprintf__XprivateX__BB54_1496_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1060_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1062_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1061_F"))
		i16 =  (i2 << 3)
		i8 =  (i8 + i16)
		i16 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_1063_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1062_F"))
		i16 =  (i12 + 4)
		i8 = i12
	__asm(lbl("___vfprintf__XprivateX__BB54_1063_F"))
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		i2 =  (i2 + 1)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1065_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1064_F"))
		i10 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i12 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1066_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1065_F"))
		i8 =  (__2E_str522)
		i10 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i12 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
	__asm(lbl("___vfprintf__XprivateX__BB54_1066_F"))
		i30 = i16
		i16 = i8
		__asm(push(i1<0), iftrue, target("___vfprintf__XprivateX__BB54_1079_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1067_F"))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1073_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1068_F"), lbl("___vfprintf__XprivateX__BB54_1068_B"), label, lbl("___vfprintf__XprivateX__BB54_1068_F")); 
		i16 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1069_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1069_F"), lbl("___vfprintf__XprivateX__BB54_1069_B"), label, lbl("___vfprintf__XprivateX__BB54_1069_F")); 
		__asm(push(i16==0), iftrue, target("___vfprintf__XprivateX__BB54_1078_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1070_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1070_F"))
		i16 =  (i16 - i8)
		__asm(push(i16>i1), iftrue, target("___vfprintf__XprivateX__BB54_1078_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1071_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1071_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1072_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1072_F"), lbl("___vfprintf__XprivateX__BB54_1072_B"), label, lbl("___vfprintf__XprivateX__BB54_1072_F")); 
		i27 = i16
		i28 =  (0)
		__asm(push(i28), push((mstate.ebp+-1762)), op(0x3a))
		i16 = i8
		i17 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i18 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i19 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2313)), op(0x37))))
		i20 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i22 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i23 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i24 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i25 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i26 = i1
		i1 = i28
		i8 = i27
		i27 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		i28 = i10
		i29 = i12
		i10 = i30
		__asm(jump, target("___vfprintf__XprivateX__BB54_1205_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1073_F"))
		i17 =  (i1 + 1)
	__asm(jump, target("___vfprintf__XprivateX__BB54_1074_F"), lbl("___vfprintf__XprivateX__BB54_1074_B"), label, lbl("___vfprintf__XprivateX__BB54_1074_F")); 
		i18 =  ((__xasm<int>(push(i16), op(0x35))))
		i19 = i16
		__asm(push(i18!=0), iftrue, target("___vfprintf__XprivateX__BB54_1076_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1075_F"))
		i16 = i19
		__asm(jump, target("___vfprintf__XprivateX__BB54_1069_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1076_F"))
		i17 =  (i17 + -1)
		i16 =  (i16 + 1)
		__asm(push(i17==1), iftrue, target("___vfprintf__XprivateX__BB54_1068_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1077_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1074_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1078_F"))
		i16 = i1
		__asm(jump, target("___vfprintf__XprivateX__BB54_1072_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1079_F"))
		i17 =  ((__xasm<int>(push(i8), op(0x35))))
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_1534_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1080_F"))
		i17 = i16
		__asm(jump, target("___vfprintf__XprivateX__BB54_1081_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1081_F"), lbl("___vfprintf__XprivateX__BB54_1081_B"), label, lbl("___vfprintf__XprivateX__BB54_1081_F")); 
		i18 =  ((__xasm<int>(push((i17+1)), op(0x35))))
		i17 =  (i17 + 1)
		i19 = i17
		__asm(push(i18==0), iftrue, target("___vfprintf__XprivateX__BB54_1535_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1082_F"))
		i17 = i19
		__asm(jump, target("___vfprintf__XprivateX__BB54_1081_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1083_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x37))))
		i17 =  ((__xasm<int>(push((i12+4)), op(0x37))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i19 =  (10)
		i2 =  (i2 + 1)
		i12 =  (i12 + 8)
		i8 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i18 = i8
		i8 = i17
		i17 = i19
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1084_F"))
		i8 =  (i7 & 1024)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1088_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1085_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1087_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1086_F"))
		i17 =  (0)
		i16 =  (i2 << 3)
		i8 =  (i8 + i16)
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		__asm(push(i17), push((mstate.ebp+-1762)), op(0x3a))
		i19 =  (10)
		i2 =  (i2 + 1)
		i16 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i18 = i16
		i16 = i8
		i8 = i17
		i17 = i19
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1087_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x37))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (10)
		i2 =  (i2 + 1)
		i12 =  (i12 + 4)
		i18 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1088_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		i16 =  (i7 & 2048)
		__asm(push(i16==0), iftrue, target("___vfprintf__XprivateX__BB54_1092_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1089_F"))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1091_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1090_F"))
		i16 =  (0)
		i17 =  (i2 << 3)
		i8 =  (i8 + i17)
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (i8 >> 31)
		i19 =  (10)
		i2 =  (i2 + 1)
		i16 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i18 = i16
		i16 = i8
		i8 = i17
		i17 = i19
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1091_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x37))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i8 =  (i16 >> 31)
		i17 =  (10)
		i2 =  (i2 + 1)
		i12 =  (i12 + 4)
		i18 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1092_F"))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1094_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1093_F"))
		i16 =  (0)
		i17 =  (i2 << 3)
		i8 =  (i8 + i17)
		i17 =  ((__xasm<int>(push(i8), op(0x37))))
		i8 =  ((__xasm<int>(push((i8+4)), op(0x37))))
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i19 =  (10)
		i2 =  (i2 + 1)
		i16 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i18 = i16
		i16 = i17
		i17 = i19
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1094_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x37))))
		i17 =  ((__xasm<int>(push((i12+4)), op(0x37))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i19 =  (10)
		i2 =  (i2 + 1)
		i12 =  (i12 + 8)
		i8 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i18 = i8
		i8 = i17
		i17 = i19
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1095_F"))
		i8 =  (i7 & 16)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1099_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1096_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1098_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1097_F"))
		i16 =  (0)
		i17 =  (i2 << 3)
		i8 =  (i8 + i17)
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (10)
		i2 =  (i2 + 1)
		i18 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1098_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x37))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (10)
		i2 =  (i2 + 1)
		i12 =  (i12 + 4)
		i18 = i16
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1099_F"))
		i8 =  (i7 & 64)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1103_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1100_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1102_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1101_F"))
		i16 =  (0)
		i17 =  (i2 << 3)
		i8 =  (i8 + i17)
		i8 =  ((__xasm<int>(push(i8), op(0x36))))
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (10)
		i2 =  (i2 + 1)
		i18 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1102_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x36))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (10)
		i2 =  (i2 + 1)
		i12 =  (i12 + 4)
		i18 = i16
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1103_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		i16 =  (i7 & 8192)
		__asm(push(i16==0), iftrue, target("___vfprintf__XprivateX__BB54_1107_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1104_F"))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1106_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1105_F"))
		i16 =  (0)
		i17 =  (i2 << 3)
		i8 =  (i8 + i17)
		i8 =  ((__xasm<int>(push(i8), op(0x35))))
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (10)
		i2 =  (i2 + 1)
		i18 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1106_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x35))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (10)
		i2 =  (i2 + 1)
		i12 =  (i12 + 4)
		i18 = i16
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1107_F"))
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1109_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1108_F"))
		i16 =  (0)
		i17 =  (i2 << 3)
		i8 =  (i8 + i17)
		i8 =  ((__xasm<int>(push(i8), op(0x37))))
		__asm(push(i16), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (10)
		i2 =  (i2 + 1)
		i18 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1109_F"))
		i8 =  (0)
		i16 =  ((__xasm<int>(push(i12), op(0x37))))
		__asm(push(i8), push((mstate.ebp+-1762)), op(0x3a))
		i17 =  (10)
		i2 =  (i2 + 1)
		i12 =  (i12 + 4)
		i18 = i16
		i8 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i16 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1150_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1110_F"))
		i7 =  (_xdigs_lower_2E_4528)
	__asm(lbl("___vfprintf__XprivateX__BB54_1111_F"))
		i19 = i7
		i7 =  (i8 & 7200)
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_1129_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1112_F"))
		i17 =  (i8 & 4096)
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_1118_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1113_F"))
		i17 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_1117_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1114_F"))
		i18 =  (i2 << 3)
		i17 =  (i17 + i18)
		i18 =  ((__xasm<int>(push(i17), op(0x37))))
		i17 =  ((__xasm<int>(push((i17+4)), op(0x37))))
		i20 =  (i8 & 1)
		__asm(push(i20==0), iftrue, target("___vfprintf__XprivateX__BB54_1116_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1115_F"))
		i20 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1146_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1116_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i16 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_1149_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1117_F"))
		i17 =  ((__xasm<int>(push(i12), op(0x37))))
		i18 =  ((__xasm<int>(push((i12+4)), op(0x37))))
		i12 =  (i12 + 8)
		i20 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1144_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1118_F"))
		i17 =  (i8 & 1024)
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_1122_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1119_F"))
		i17 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_1121_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1120_F"))
		i18 =  (0)
		i20 =  (i2 << 3)
		i17 =  (i17 + i20)
		i17 =  ((__xasm<int>(push(i17), op(0x37))))
		i20 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1144_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1121_F"))
		i18 =  (0)
		i17 =  ((__xasm<int>(push(i12), op(0x37))))
		i12 =  (i12 + 4)
		i20 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1144_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1122_F"))
		i17 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		i18 =  (i8 & 2048)
		__asm(push(i18==0), iftrue, target("___vfprintf__XprivateX__BB54_1126_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1123_F"))
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_1125_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1124_F"))
		i18 =  (i2 << 3)
		i17 =  (i17 + i18)
		i17 =  ((__xasm<int>(push(i17), op(0x37))))
		i18 =  (i17 >> 31)
		i20 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1144_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1125_F"))
		i17 =  ((__xasm<int>(push(i12), op(0x37))))
		i18 =  (i17 >> 31)
		i12 =  (i12 + 4)
		i20 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1144_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1126_F"))
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_1128_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1127_F"))
		i18 =  (i2 << 3)
		i17 =  (i17 + i18)
		i18 =  ((__xasm<int>(push(i17), op(0x37))))
		i22 =  ((__xasm<int>(push((i17+4)), op(0x37))))
		i17 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i20 = i17
		i17 = i18
		i18 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1144_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1128_F"))
		i17 =  ((__xasm<int>(push(i12), op(0x37))))
		i18 =  ((__xasm<int>(push((i12+4)), op(0x37))))
		i12 =  (i12 + 8)
		i20 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1144_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1129_F"))
		i17 =  (i8 & 16)
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_1133_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1130_F"))
		i17 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_1132_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1131_F"))
		i18 =  (i2 << 3)
		i17 =  (i17 + i18)
		i17 =  ((__xasm<int>(push(i17), op(0x37))))
		i20 = i17
		i17 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i18 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1144_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1132_F"))
		i17 =  ((__xasm<int>(push(i12), op(0x37))))
		i12 =  (i12 + 4)
		i20 = i17
		i17 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i18 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1144_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1133_F"))
		i17 =  (i8 & 64)
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_1137_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1134_F"))
		i17 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_1136_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1135_F"))
		i18 =  (i2 << 3)
		i17 =  (i17 + i18)
		i17 =  ((__xasm<int>(push(i17), op(0x36))))
		i20 = i17
		i17 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i18 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1144_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1136_F"))
		i17 =  ((__xasm<int>(push(i12), op(0x36))))
		i12 =  (i12 + 4)
		i20 = i17
		i17 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i18 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1144_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1137_F"))
		i17 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		i18 =  (i8 & 8192)
		__asm(push(i18==0), iftrue, target("___vfprintf__XprivateX__BB54_1141_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1138_F"))
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_1140_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1139_F"))
		i18 =  (i2 << 3)
		i17 =  (i17 + i18)
		i17 =  ((__xasm<int>(push(i17), op(0x35))))
		i20 = i17
		i17 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i18 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1144_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1140_F"))
		i17 =  ((__xasm<int>(push(i12), op(0x35))))
		i12 =  (i12 + 4)
		i20 = i17
		i17 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i18 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1144_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1141_F"))
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_1143_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1142_F"))
		i18 =  (i2 << 3)
		i17 =  (i17 + i18)
		i17 =  ((__xasm<int>(push(i17), op(0x37))))
		i20 = i17
		i17 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i18 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1144_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1143_F"))
		i17 =  ((__xasm<int>(push(i12), op(0x37))))
		i12 =  (i12 + 4)
		i20 = i17
		i17 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i18 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
	__asm(lbl("___vfprintf__XprivateX__BB54_1144_F"))
		i22 = i18
		i18 =  (i8 & 1)
		__asm(push(i18==0), iftrue, target("___vfprintf__XprivateX__BB54_1536_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1145_F"))
		i18 = i17
		i17 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1146_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1146_F"))
		i22 =  (i18 | i17)
		i23 =  ((i20!=0) ? 1 : 0)
		i22 =  ((i22!=0) ? 1 : 0)
		i7 =  ((i7==0) ? i23 : i22)
		i7 =  (i7 & 1)
		__asm(push(i7!=0), iftrue, target("___vfprintf__XprivateX__BB54_1148_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1147_F"))
		i7 = i20
		i16 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_1149_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1148_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-2169)), op(0x37))))
		__asm(push(i16), push(i7), op(0x3a))
		i7 = i20
		i16 = i18
	__asm(jump, target("___vfprintf__XprivateX__BB54_1149_F"), lbl("___vfprintf__XprivateX__BB54_1149_B"), label, lbl("___vfprintf__XprivateX__BB54_1149_F")); 
		i18 = i7
		i7 =  (0)
		__asm(push(i7), push((mstate.ebp+-1762)), op(0x3a))
		i20 =  (16)
		i2 =  (i2 + 1)
		i7 =  (i8 & -513)
		i8 = i17
		i17 = i20
	__asm(lbl("___vfprintf__XprivateX__BB54_1150_F"))
		i24 = i18
		i25 = i16
		i16 = i17
		i27 = i19
		i17 =  ((i1>-1) ? -129 : -1)
		i7 =  (i7 & i17)
		i17 =  (i7 & 7200)
		__asm(push(i17==0), iftrue, target("___vfprintf__XprivateX__BB54_1195_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1151_F"))
		i17 =  (i25 | i8)
		__asm(push(i17!=0), iftrue, target("___vfprintf__XprivateX__BB54_1156_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1152_F"))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1156_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1153_F"))
		i17 =  (i7 & 1)
		__asm(push(i16!=8), iftrue, target("___vfprintf__XprivateX__BB54_1155_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1154_F"))
		__asm(push(i17!=0), iftrue, target("___vfprintf__XprivateX__BB54_1156_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1155_F"), lbl("___vfprintf__XprivateX__BB54_1155_B"), label, lbl("___vfprintf__XprivateX__BB54_1155_F")); 
		i16 =  ((__xasm<int>(push((mstate.ebp+-2151)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1201_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1156_F"))
		i17 =  ((__xasm<int>(push((mstate.ebp+-1761)), op(0x35))))
		i18 =  (i7 & 1)
		i19 =  (i7 & 512)
		i20 =  ((i8!=0) ? 1 : 0)
		__asm(push(i20!=0), iftrue, target("___vfprintf__XprivateX__BB54_1158_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1157_F"))
		i10 =  (i17 << 24)
		mstate.esp -= 32
		i10 =  (i10 >> 24)
		__asm(push(i25), push(mstate.esp), op(0x3c))
		i17 =  ((__xasm<int>(push((mstate.ebp+-2151)), op(0x37))))
		__asm(push(i17), push((mstate.esp+4)), op(0x3c))
		__asm(push(i16), push((mstate.esp+8)), op(0x3c))
		__asm(push(i18), push((mstate.esp+12)), op(0x3c))
		__asm(push(i27), push((mstate.esp+16)), op(0x3c))
		__asm(push(i19), push((mstate.esp+20)), op(0x3c))
		__asm(push(i10), push((mstate.esp+24)), op(0x3c))
		__asm(push(i14), push((mstate.esp+28)), op(0x3c))
		state = 67
		mstate.esp -= 4;FSM___ultoa.start()
		return
	__asm(lbl("___vfprintf_state67"))
		i16 = mstate.eax
		mstate.esp += 32
		__asm(jump, target("___vfprintf__XprivateX__BB54_1201_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1158_F"))
		__asm(push(i16==8), iftrue, target("___vfprintf__XprivateX__BB54_1187_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1159_F"))
		__asm(push(i16==10), iftrue, target("___vfprintf__XprivateX__BB54_1164_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1160_F"))
		__asm(push(i16!=16), iftrue, target("___vfprintf__XprivateX__BB54_1194_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1161_F"))
		i16 =  ((__xasm<int>(push((mstate.ebp+-2043)), op(0x37))))
		i10 = i25
		i17 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_1162_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1162_F"), lbl("___vfprintf__XprivateX__BB54_1162_B"), label, lbl("___vfprintf__XprivateX__BB54_1162_F")); 
		i18 =  (i10 & 15)
		i18 =  (i27 + i18)
		i18 =  ((__xasm<int>(push(i18), op(0x35))))
		i19 =  (i10 >>> 4)
		i20 =  (i17 << 28)
		__asm(push(i18), push((i16+99)), op(0x3a))
		i18 =  (i17 >>> 4)
		i19 =  (i19 | i20)
		i16 =  (i16 + -1)
		i10 =  ((uint(i10)<uint(16)) ? 1 : 0)
		i17 =  ((i17==0) ? 1 : 0)
		i10 =  ((i17!=0) ? i10 : 0)
		__asm(push(i10!=0), iftrue, target("___vfprintf__XprivateX__BB54_1200_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1163_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1163_F"))
		i10 = i19
		i17 = i18
		__asm(jump, target("___vfprintf__XprivateX__BB54_1162_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1164_F"))
		i16 =  ((i8!=0) ? 1 : 0)
		i18 =  ((uint(i25)>uint(9)) ? 1 : 0)
		i20 =  ((i8==0) ? 1 : 0)
		i16 =  ((i20!=0) ? i18 : i16)
		__asm(push(i16!=0), iftrue, target("___vfprintf__XprivateX__BB54_1166_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1165_F"))
		i16 =  (0)
		mstate.esp -= 16
		i10 =  (10)
		__asm(push(i25), push(mstate.esp), op(0x3c))
		__asm(push(i8), push((mstate.esp+4)), op(0x3c))
		__asm(push(i10), push((mstate.esp+8)), op(0x3c))
		__asm(push(i16), push((mstate.esp+12)), op(0x3c))
		mstate.esp -= 4;(mstate.funcs[___udivdi3])()
	__asm(lbl("___vfprintf_state68"))
		i17 = mstate.eax
		i19 = mstate.edx
		mstate.esp += 16
		mstate.esp -= 16
		__asm(push(i17), push(mstate.esp), op(0x3c))
		__asm(push(i19), push((mstate.esp+4)), op(0x3c))
		__asm(push(i10), push((mstate.esp+8)), op(0x3c))
		__asm(push(i16), push((mstate.esp+12)), op(0x3c))
		mstate.esp -= 4;(mstate.funcs[___muldi3])()
	__asm(lbl("___vfprintf_state69"))
		i16 = mstate.eax
		i10 = mstate.edx
		i16 =  __subc(i25, i16)
		i16 =  (i16 + 48)
		i10 =  ((__xasm<int>(push((mstate.ebp+-2133)), op(0x37))))
		__asm(push(i16), push(i10), op(0x3a))
		mstate.esp += 16
		i16 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_1201_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1166_F"))
		__asm(push(i8<0), iftrue, target("___vfprintf__XprivateX__BB54_1168_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1167_F"))
		i16 =  (0)
		i18 = i25
		i20 = i8
		i22 =  ((__xasm<int>(push((mstate.ebp+-2151)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1169_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1168_F"))
		i16 =  (10)
		mstate.esp -= 16
		i18 =  (0)
		__asm(push(i25), push(mstate.esp), op(0x3c))
		__asm(push(i8), push((mstate.esp+4)), op(0x3c))
		__asm(push(i16), push((mstate.esp+8)), op(0x3c))
		__asm(push(i18), push((mstate.esp+12)), op(0x3c))
		mstate.esp -= 4;(mstate.funcs[___udivdi3])()
	__asm(lbl("___vfprintf_state70"))
		i20 = mstate.eax
		i22 = mstate.edx
		mstate.esp += 16
		mstate.esp -= 16
		__asm(push(i20), push(mstate.esp), op(0x3c))
		__asm(push(i22), push((mstate.esp+4)), op(0x3c))
		__asm(push(i16), push((mstate.esp+8)), op(0x3c))
		__asm(push(i18), push((mstate.esp+12)), op(0x3c))
		mstate.esp -= 4;(mstate.funcs[___muldi3])()
	__asm(lbl("___vfprintf_state71"))
		i16 = mstate.eax
		i16 =  __subc(i25, i16)
		i16 =  (i16 + 48)
		i18 =  ((__xasm<int>(push((mstate.ebp+-2133)), op(0x37))))
		__asm(push(i16), push(i18), op(0x3a))
		i16 =  (1)
		i18 = i20
		i20 = i22
		i22 =  ((__xasm<int>(push((mstate.ebp+-2133)), op(0x37))))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1169_F"), lbl("___vfprintf__XprivateX__BB54_1169_B"), label, lbl("___vfprintf__XprivateX__BB54_1169_F")); 
		i23 =  (i10 + 1)
		i26 = i10
		__asm(push(i19==0), iftrue, target("___vfprintf__XprivateX__BB54_1175_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1170_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1171_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1171_F"), lbl("___vfprintf__XprivateX__BB54_1171_B"), label, lbl("___vfprintf__XprivateX__BB54_1171_F")); 
		i28 =  (0)
		mstate.esp -= 16
		i29 =  (10)
		__asm(push(i18), push(mstate.esp), op(0x3c))
		__asm(push(i20), push((mstate.esp+4)), op(0x3c))
		__asm(push(i29), push((mstate.esp+8)), op(0x3c))
		__asm(push(i28), push((mstate.esp+12)), op(0x3c))
		mstate.esp -= 4;(mstate.funcs[___divdi3])()
	__asm(lbl("___vfprintf_state72"))
		i30 = mstate.eax
		i31 = mstate.edx
		mstate.esp += 16
		mstate.esp -= 16
		__asm(push(i30), push(mstate.esp), op(0x3c))
		__asm(push(i31), push((mstate.esp+4)), op(0x3c))
		__asm(push(i29), push((mstate.esp+8)), op(0x3c))
		__asm(push(i28), push((mstate.esp+12)), op(0x3c))
		mstate.esp -= 4;(mstate.funcs[___muldi3])()
	__asm(lbl("___vfprintf_state73"))
		i28 = mstate.eax
		i29 = mstate.edx
		i28 =  __subc(i18, i28)
		i28 =  (i28 + 48)
		__asm(push(i28), push((i22+-1)), op(0x3a))
		i28 =  ((__xasm<int>(push(i26), op(0x35))))
		i16 =  (i16 + 1)
		i29 =  (i22 + -1)
		mstate.esp += 16
		__asm(push(i28!=127), iftrue, target("___vfprintf__XprivateX__BB54_1179_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1172_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1172_F"), lbl("___vfprintf__XprivateX__BB54_1172_B"), label, lbl("___vfprintf__XprivateX__BB54_1172_F")); 
		i22 = i29
		__asm(jump, target("___vfprintf__XprivateX__BB54_1173_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1173_F"), lbl("___vfprintf__XprivateX__BB54_1173_B"), label, lbl("___vfprintf__XprivateX__BB54_1173_F")); 
		i28 =  (10)
		mstate.esp -= 16
		i29 =  (0)
		__asm(push(i18), push(mstate.esp), op(0x3c))
		__asm(push(i20), push((mstate.esp+4)), op(0x3c))
		__asm(push(i28), push((mstate.esp+8)), op(0x3c))
		__asm(push(i29), push((mstate.esp+12)), op(0x3c))
		i28 =  (9)
		i18 =  __addc(i18, i28)
		i20 =  __adde(i20, i29)
		mstate.esp -= 4;(mstate.funcs[___divdi3])()
	__asm(lbl("___vfprintf_state74"))
		i28 = mstate.eax
		i29 = mstate.edx
		mstate.esp += 16
		i30 =  ((i20!=0) ? 1 : 0)
		i18 =  ((uint(i18)>uint(18)) ? 1 : 0)
		i20 =  ((i20==0) ? 1 : 0)
		i18 =  ((i20!=0) ? i18 : i30)
		__asm(push(i18!=0), iftrue, target("___vfprintf__XprivateX__BB54_1186_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1174_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1174_F"))
		i16 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1201_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1175_F"))
		i16 = i18
		i10 = i20
		i17 = i22
	__asm(jump, target("___vfprintf__XprivateX__BB54_1176_F"), lbl("___vfprintf__XprivateX__BB54_1176_B"), label, lbl("___vfprintf__XprivateX__BB54_1176_F")); 
		i18 =  (10)
		mstate.esp -= 16
		i19 =  (0)
		__asm(push(i16), push(mstate.esp), op(0x3c))
		__asm(push(i10), push((mstate.esp+4)), op(0x3c))
		__asm(push(i18), push((mstate.esp+8)), op(0x3c))
		__asm(push(i19), push((mstate.esp+12)), op(0x3c))
		mstate.esp -= 4;(mstate.funcs[___divdi3])()
	__asm(lbl("___vfprintf_state75"))
		i20 = mstate.eax
		i22 = mstate.edx
		mstate.esp += 16
		mstate.esp -= 16
		__asm(push(i20), push(mstate.esp), op(0x3c))
		__asm(push(i22), push((mstate.esp+4)), op(0x3c))
		__asm(push(i18), push((mstate.esp+8)), op(0x3c))
		__asm(push(i19), push((mstate.esp+12)), op(0x3c))
		mstate.esp -= 4;(mstate.funcs[___muldi3])()
	__asm(lbl("___vfprintf_state76"))
		i18 = mstate.eax
		i23 = mstate.edx
		i18 =  __subc(i16, i18)
		i23 =  (9)
		i18 =  (i18 + 48)
		i16 =  __addc(i16, i23)
		i10 =  __adde(i10, i19)
		__asm(push(i18), push((i17+-1)), op(0x3a))
		i17 =  (i17 + -1)
		mstate.esp += 16
		i18 =  ((i10!=0) ? 1 : 0)
		i16 =  ((uint(i16)>uint(18)) ? 1 : 0)
		i10 =  ((i10==0) ? 1 : 0)
		i16 =  ((i10!=0) ? i16 : i18)
		__asm(push(i16!=0), iftrue, target("___vfprintf__XprivateX__BB54_1178_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1177_F"))
		i16 = i17
		__asm(jump, target("___vfprintf__XprivateX__BB54_1201_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1178_F"))
		i16 = i20
		i10 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1176_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1179_F"))
		i28 =  (i28 << 24)
		i28 =  (i28 >> 24)
		__asm(push(i28!=i16), iftrue, target("___vfprintf__XprivateX__BB54_1172_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1180_F"))
		i28 =  ((i20<0) ? 1 : 0)
		i30 =  ((uint(i18)<uint(10)) ? 1 : 0)
		i31 =  ((i20==0) ? 1 : 0)
		i28 =  ((i31!=0) ? i30 : i28)
		__asm(push(i28!=0), iftrue, target("___vfprintf__XprivateX__BB54_1172_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1181_F"))
		__asm(push(i17), push((i22+-2)), op(0x3a))
		i16 =  ((__xasm<int>(push(i23), op(0x35))))
		i22 =  (i22 + -2)
		__asm(push(i16!=0), iftrue, target("___vfprintf__XprivateX__BB54_1183_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1182_F"))
		i16 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1173_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1183_F"))
		i16 =  (10)
		mstate.esp -= 16
		i23 =  (0)
		__asm(push(i18), push(mstate.esp), op(0x3c))
		__asm(push(i20), push((mstate.esp+4)), op(0x3c))
		__asm(push(i16), push((mstate.esp+8)), op(0x3c))
		__asm(push(i23), push((mstate.esp+12)), op(0x3c))
		i16 =  (9)
		i16 =  __addc(i18, i16)
		i18 =  __adde(i20, i23)
		mstate.esp -= 4;(mstate.funcs[___divdi3])()
	__asm(lbl("___vfprintf_state77"))
		i20 = mstate.eax
		i23 = mstate.edx
		i10 =  (i10 + 1)
		mstate.esp += 16
		i26 =  ((i18!=0) ? 1 : 0)
		i16 =  ((uint(i16)>uint(18)) ? 1 : 0)
		i18 =  ((i18==0) ? 1 : 0)
		i16 =  ((i18!=0) ? i16 : i26)
		__asm(push(i16!=0), iftrue, target("___vfprintf__XprivateX__BB54_1185_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1184_F"))
		i16 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1201_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1185_F"))
		i16 =  (0)
		i18 = i20
		i20 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_1169_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1186_F"))
		i18 = i28
		i20 = i29
		__asm(jump, target("___vfprintf__XprivateX__BB54_1171_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1187_F"))
		i16 =  (-1)
		i10 =  ((__xasm<int>(push((mstate.ebp+-2043)), op(0x37))))
		i17 = i25
		i19 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_1188_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1188_F"), lbl("___vfprintf__XprivateX__BB54_1188_B"), label, lbl("___vfprintf__XprivateX__BB54_1188_F")); 
		i20 =  (i17 | 48)
		i20 =  (i20 & 55)
		i22 =  (i17 >>> 3)
		i23 =  (i19 << 29)
		__asm(push(i20), push((i10+99)), op(0x3a))
		i26 =  (i19 >>> 3)
		i22 =  (i22 | i23)
		i10 =  (i10 + -1)
		i16 =  (i16 + 1)
		i17 =  ((uint(i17)<uint(8)) ? 1 : 0)
		i19 =  ((i19==0) ? 1 : 0)
		i17 =  ((i19!=0) ? i17 : 0)
		__asm(push(i17!=0), iftrue, target("___vfprintf__XprivateX__BB54_1190_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1189_F"))
		i17 = i22
		i19 = i26
		__asm(jump, target("___vfprintf__XprivateX__BB54_1188_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1190_F"))
		__asm(push(i18==0), iftrue, target("___vfprintf__XprivateX__BB54_1192_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1191_F"))
		i17 =  (i20 & 255)
		__asm(push(i17!=48), iftrue, target("___vfprintf__XprivateX__BB54_1193_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1192_F"))
		i16 =  (i10 + 100)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1201_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1193_F"))
		i10 =  ((mstate.ebp+-1664))
		i16 =  (98 - i16)
		i17 =  (48)
		i16 =  (i10 + i16)
		__asm(push(i17), push(i16), op(0x3a))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1201_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1194_F"))
		state = 78
		mstate.esp -= 4;FSM_abort1.start()
		return
	__asm(lbl("___vfprintf_state78"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1195_F"))
		__asm(push(i24!=0), iftrue, target("___vfprintf__XprivateX__BB54_1199_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1196_F"))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1199_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1197_F"))
		i10 =  (i7 & 1)
		__asm(push(i16!=8), iftrue, target("___vfprintf__XprivateX__BB54_1155_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1198_F"))
		__asm(push(i10==0), iftrue, target("___vfprintf__XprivateX__BB54_1155_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1199_F"))
		i10 =  ((__xasm<int>(push((mstate.ebp+-1761)), op(0x35), op(0x51))))
		mstate.esp -= 32
		i17 =  (i7 & 1)
		i18 =  (i7 & 512)
		__asm(push(i24), push(mstate.esp), op(0x3c))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2151)), op(0x37))))
		__asm(push(i19), push((mstate.esp+4)), op(0x3c))
		__asm(push(i16), push((mstate.esp+8)), op(0x3c))
		__asm(push(i17), push((mstate.esp+12)), op(0x3c))
		__asm(push(i27), push((mstate.esp+16)), op(0x3c))
		__asm(push(i18), push((mstate.esp+20)), op(0x3c))
		__asm(push(i10), push((mstate.esp+24)), op(0x3c))
		__asm(push(i14), push((mstate.esp+28)), op(0x3c))
		state = 79
		mstate.esp -= 4;FSM___ultoa.start()
		return
	__asm(lbl("___vfprintf_state79"))
		i16 = mstate.eax
		mstate.esp += 32
		__asm(jump, target("___vfprintf__XprivateX__BB54_1201_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1200_F"))
		i16 =  (i16 + 100)
	__asm(lbl("___vfprintf__XprivateX__BB54_1201_F"))
		i10 =  ((__xasm<int>(push((mstate.ebp+-2097)), op(0x37))))
		i10 =  (i10 - i16)
		__asm(push(i10>100), iftrue, target("___vfprintf__XprivateX__BB54_1203_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1202_F"))
		i17 = i1
		i18 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i19 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i20 =  ((__xasm<int>(push((mstate.ebp+-2313)), op(0x37))))
		i22 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i23 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i26 = i8
		i8 = i10
		i10 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i28 = i10
		i10 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		i29 = i10
		i10 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_1205_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1203_F"))
		state = 80
		mstate.esp -= 4;FSM_abort1.start()
		return
	__asm(lbl("___vfprintf_state80"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1204_F"))
		i10 =  (0)
		i7 =  ((__xasm<int>(push((mstate.ebp+-2205)), op(0x37))))
		__asm(push(i16), push(i7), op(0x3a))
		__asm(push(i10), push((mstate.ebp+-1762)), op(0x3a))
		i27 =  (1)
		i16 = i7
		i7 = i8
		i17 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2331)), op(0x37))))
		i18 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2295)), op(0x37))))
		i19 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2313)), op(0x37))))
		i20 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2349)), op(0x37))))
		i22 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2340)), op(0x37))))
		i23 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2502)), op(0x37))))
		i24 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2484)), op(0x37))))
		i25 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-2475)), op(0x37))))
		i26 = i1
		i1 = i10
		i8 = i27
		i10 =  ((__xasm<int>(push((mstate.ebp+-2520)), op(0x37))))
		i27 = i10
		i10 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		i28 = i10
		i10 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		i29 = i10
		i10 = i12
	__asm(lbl("___vfprintf__XprivateX__BB54_1205_F"))
		i12 = i16
		i16 = i17
		i17 = i18
		i18 = i19
		i19 = i20
		i20 = i22
		i22 = i23
		i23 = i24
		__asm(push(i23), push((mstate.ebp+-2547)), op(0x3c))
		i23 = i25
		__asm(push(i23), push((mstate.ebp+-2556)), op(0x3c))
		i23 = i26
		__asm(push(i23), push((mstate.ebp+-2565)), op(0x3c))
		i23 = i27
		__asm(push(i23), push((mstate.ebp+-2583)), op(0x3c))
		__asm(push(i2), push((mstate.ebp+-2574)), op(0x3c))
		i23 = i28
		i2 = i29
		__asm(push(i2), push((mstate.ebp+-2592)), op(0x3c))
		i2 = i10
		__asm(push(i2), push((mstate.ebp+-2601)), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-1762)), op(0x35))))
		i10 =  ((i2!=0) ? 1 : 0)
		i24 =  ((__xasm<int>(push((mstate.ebp+-2169)), op(0x37))))
		i24 =  ((__xasm<int>(push(i24), op(0x35))))
		i25 =  ((i8>=i1) ? i8 : i1)
		i10 =  (i10 & 1)
		i24 =  ((i24==0) ? 0 : 2)
		i10 =  (i10 + i25)
		i10 =  (i10 + i24)
		i26 =  ((i10>=i6) ? i10 : i6)
		i27 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		i26 =  (i26 + i27)
		__asm(push(i26>-1), iftrue, target("___vfprintf__XprivateX__BB54_1207_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1206_F"))
		i0 =  (-1)
		i6 = i0
		i9 = i21
		i0 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_1496_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1207_F"))
		i27 =  (i7 & 132)
		__asm(push(i27==0), iftrue, target("___vfprintf__XprivateX__BB54_1209_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1208_F"), lbl("___vfprintf__XprivateX__BB54_1208_B"), label, lbl("___vfprintf__XprivateX__BB54_1208_F")); 
		i28 =  ((__xasm<int>(push((mstate.ebp+-2304)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1226_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1209_F"))
		i28 =  (i6 - i10)
		__asm(push(i28<1), iftrue, target("___vfprintf__XprivateX__BB54_1208_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1210_F"))
		i28 =  (i2 & 255)
		i28 =  ((i28!=0) ? 1 : 0)
		i28 =  (i28 & 1)
		i29 =  (i24 + i25)
		i28 =  (i29 + i28)
		i28 =  (i6 - i28)
		i29 =  ((__xasm<int>(push((mstate.ebp+-2304)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1219_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1211_B"), label)
		i31 =  (16)
		__asm(push(i31), push(i28), op(0x3c))
		i28 =  ((__xasm<int>(push(i4), op(0x37))))
		i28 =  (i28 + 16)
		__asm(push(i28), push(i4), op(0x3c))
		i31 =  ((__xasm<int>(push(i5), op(0x37))))
		i31 =  (i31 + 1)
		__asm(push(i31), push(i5), op(0x3c))
		i29 =  (i29 + 8)
		__asm(push(i31>7), iftrue, target("___vfprintf__XprivateX__BB54_1213_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1212_F"))
		i28 = i29
		__asm(jump, target("___vfprintf__XprivateX__BB54_1218_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1213_F"))
		__asm(push(i28!=0), iftrue, target("___vfprintf__XprivateX__BB54_1215_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1214_F"))
		i28 =  (0)
		__asm(push(i28), push(i5), op(0x3c))
		i28 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1218_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1215_F"))
		i28 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i28), push((mstate.esp+4)), op(0x3c))
		state = 81
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state81"))
		i28 = mstate.eax
		mstate.esp += 8
		i29 =  (0)
		__asm(push(i29), push(i4), op(0x3c))
		__asm(push(i29), push(i5), op(0x3c))
		__asm(push(i28==0), iftrue, target("___vfprintf__XprivateX__BB54_1217_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1216_F"), lbl("___vfprintf__XprivateX__BB54_1216_B"), label, lbl("___vfprintf__XprivateX__BB54_1216_F")); 
		i0 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		i6 = i0
		i9 = i21
		i0 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_1496_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1217_F"))
		i28 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1218_F"))
		i29 = i28
		i28 =  (i30 + -16)
	__asm(lbl("___vfprintf__XprivateX__BB54_1219_F"))
		i30 = i28
		i28 =  (_blanks_2E_4526)
		__asm(push(i28), push(i29), op(0x3c))
		i28 =  (i29 + 4)
		__asm(push(i30>16), iftrue, target("___vfprintf__XprivateX__BB54_1211_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1220_F"))
		__asm(push(i30), push(i28), op(0x3c))
		i28 =  ((__xasm<int>(push(i4), op(0x37))))
		i28 =  (i28 + i30)
		__asm(push(i28), push(i4), op(0x3c))
		i30 =  ((__xasm<int>(push(i5), op(0x37))))
		i30 =  (i30 + 1)
		__asm(push(i30), push(i5), op(0x3c))
		i29 =  (i29 + 8)
		__asm(push(i30>7), iftrue, target("___vfprintf__XprivateX__BB54_1222_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1221_F"))
		i28 = i29
		__asm(jump, target("___vfprintf__XprivateX__BB54_1226_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1222_F"))
		__asm(push(i28!=0), iftrue, target("___vfprintf__XprivateX__BB54_1224_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1223_F"))
		i28 =  (0)
		__asm(push(i28), push(i5), op(0x3c))
		i28 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1226_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1224_F"))
		i28 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i28), push((mstate.esp+4)), op(0x3c))
		state = 82
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state82"))
		i28 = mstate.eax
		mstate.esp += 8
		i29 =  (0)
		__asm(push(i29), push(i4), op(0x3c))
		__asm(push(i29), push(i5), op(0x3c))
		__asm(push(i28!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1225_F"))
		i28 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1226_F"))
		i29 =  ((__xasm<int>(push((mstate.ebp+-1762)), op(0x35))))
		__asm(push(i29!=0), iftrue, target("___vfprintf__XprivateX__BB54_1228_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1227_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1234_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1228_F"))
		i29 =  ((mstate.ebp+-1762))
		__asm(push(i29), push(i28), op(0x3c))
		i29 =  (1)
		__asm(push(i29), push((i28+4)), op(0x3c))
		i29 =  ((__xasm<int>(push(i4), op(0x37))))
		i29 =  (i29 + 1)
		__asm(push(i29), push(i4), op(0x3c))
		i30 =  ((__xasm<int>(push(i5), op(0x37))))
		i30 =  (i30 + 1)
		__asm(push(i30), push(i5), op(0x3c))
		i28 =  (i28 + 8)
		__asm(push(i30>7), iftrue, target("___vfprintf__XprivateX__BB54_1230_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1229_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1234_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1230_F"))
		__asm(push(i29!=0), iftrue, target("___vfprintf__XprivateX__BB54_1232_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1231_F"))
		i28 =  (0)
		__asm(push(i28), push(i5), op(0x3c))
		i28 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1234_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1232_F"))
		i28 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i28), push((mstate.esp+4)), op(0x3c))
		state = 83
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state83"))
		i28 = mstate.eax
		mstate.esp += 8
		i29 =  (0)
		__asm(push(i29), push(i4), op(0x3c))
		__asm(push(i29), push(i5), op(0x3c))
		__asm(push(i28!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1233_F"))
		i28 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1234_F"))
		i29 =  ((__xasm<int>(push((mstate.ebp+-2169)), op(0x37))))
		i29 =  ((__xasm<int>(push(i29), op(0x35))))
		__asm(push(i29!=0), iftrue, target("___vfprintf__XprivateX__BB54_1236_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1235_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1242_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1236_F"))
		i29 =  (48)
		i30 =  ((__xasm<int>(push((mstate.ebp+-2115)), op(0x37))))
		__asm(push(i29), push(i30), op(0x3a))
		__asm(push(i30), push(i28), op(0x3c))
		i29 =  (2)
		__asm(push(i29), push((i28+4)), op(0x3c))
		i29 =  ((__xasm<int>(push(i4), op(0x37))))
		i29 =  (i29 + 2)
		__asm(push(i29), push(i4), op(0x3c))
		i30 =  ((__xasm<int>(push(i5), op(0x37))))
		i30 =  (i30 + 1)
		__asm(push(i30), push(i5), op(0x3c))
		i28 =  (i28 + 8)
		__asm(push(i30>7), iftrue, target("___vfprintf__XprivateX__BB54_1238_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1237_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1242_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1238_F"))
		__asm(push(i29!=0), iftrue, target("___vfprintf__XprivateX__BB54_1240_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1239_F"))
		i28 =  (0)
		__asm(push(i28), push(i5), op(0x3c))
		i28 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1242_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1240_F"))
		i28 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i28), push((mstate.esp+4)), op(0x3c))
		state = 84
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state84"))
		i28 = mstate.eax
		mstate.esp += 8
		i29 =  (0)
		__asm(push(i29), push(i4), op(0x3c))
		__asm(push(i29), push(i5), op(0x3c))
		__asm(push(i28!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1241_F"))
		i28 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1242_F"))
		__asm(push(i27==128), iftrue, target("___vfprintf__XprivateX__BB54_1246_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1243_F"), lbl("___vfprintf__XprivateX__BB54_1243_B"), label, lbl("___vfprintf__XprivateX__BB54_1243_F")); 
		__asm(jump, target("___vfprintf__XprivateX__BB54_1244_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1244_F"), lbl("___vfprintf__XprivateX__BB54_1244_B"), label, lbl("___vfprintf__XprivateX__BB54_1244_F")); 
		i1 =  (i1 - i8)
		__asm(push(i1>0), iftrue, target("___vfprintf__XprivateX__BB54_1264_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1245_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1245_F"))
		i1 = i28
		__asm(jump, target("___vfprintf__XprivateX__BB54_1277_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1246_F"))
		i27 =  (i6 - i10)
		__asm(push(i27<1), iftrue, target("___vfprintf__XprivateX__BB54_1243_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1247_F"))
		i27 =  (i2 & 255)
		i27 =  ((i27!=0) ? 1 : 0)
		i27 =  (i27 & 1)
		i29 =  (i24 + i25)
		i27 =  (i29 + i27)
		i27 =  (i6 - i27)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1255_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1248_B"), label)
		i30 =  (16)
		__asm(push(i30), push(i29), op(0x3c))
		i29 =  ((__xasm<int>(push(i4), op(0x37))))
		i29 =  (i29 + 16)
		__asm(push(i29), push(i4), op(0x3c))
		i30 =  ((__xasm<int>(push(i5), op(0x37))))
		i30 =  (i30 + 1)
		__asm(push(i30), push(i5), op(0x3c))
		i28 =  (i28 + 8)
		__asm(push(i30>7), iftrue, target("___vfprintf__XprivateX__BB54_1250_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1249_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1254_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1250_F"))
		__asm(push(i29!=0), iftrue, target("___vfprintf__XprivateX__BB54_1252_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1251_F"))
		i28 =  (0)
		__asm(push(i28), push(i5), op(0x3c))
		i28 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1254_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1252_F"))
		i28 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i28), push((mstate.esp+4)), op(0x3c))
		state = 85
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state85"))
		i28 = mstate.eax
		mstate.esp += 8
		i29 =  (0)
		__asm(push(i29), push(i4), op(0x3c))
		__asm(push(i29), push(i5), op(0x3c))
		__asm(push(i28!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1253_F"))
		i28 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1254_F"))
		i27 =  (i27 + -16)
	__asm(lbl("___vfprintf__XprivateX__BB54_1255_F"))
		i29 =  (_zeroes_2E_4527)
		__asm(push(i29), push(i28), op(0x3c))
		i29 =  (i28 + 4)
		__asm(push(i27>16), iftrue, target("___vfprintf__XprivateX__BB54_1248_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1256_F"))
		__asm(push(i27), push(i29), op(0x3c))
		i29 =  ((__xasm<int>(push(i4), op(0x37))))
		i27 =  (i29 + i27)
		__asm(push(i27), push(i4), op(0x3c))
		i29 =  ((__xasm<int>(push(i5), op(0x37))))
		i29 =  (i29 + 1)
		__asm(push(i29), push(i5), op(0x3c))
		i28 =  (i28 + 8)
		__asm(push(i29>7), iftrue, target("___vfprintf__XprivateX__BB54_1258_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1257_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1244_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1258_F"))
		__asm(push(i27!=0), iftrue, target("___vfprintf__XprivateX__BB54_1260_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1259_F"))
		i28 =  (0)
		__asm(push(i28), push(i5), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1261_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1260_F"))
		i28 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i28), push((mstate.esp+4)), op(0x3c))
		state = 86
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state86"))
		i28 = mstate.eax
		mstate.esp += 8
		i27 =  (0)
		__asm(push(i27), push(i4), op(0x3c))
		__asm(push(i27), push(i5), op(0x3c))
		__asm(push(i28!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1261_F"))
		i1 =  (i1 - i8)
		__asm(push(i1>0), iftrue, target("___vfprintf__XprivateX__BB54_1263_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1262_F"), lbl("___vfprintf__XprivateX__BB54_1262_B"), label, lbl("___vfprintf__XprivateX__BB54_1262_F")); 
		i1 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1277_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1263_F"))
		i28 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1272_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1264_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1272_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1265_B"), label)
		i29 =  (16)
		__asm(push(i29), push(i28), op(0x3c))
		i28 =  ((__xasm<int>(push(i4), op(0x37))))
		i28 =  (i28 + 16)
		__asm(push(i28), push(i4), op(0x3c))
		i29 =  ((__xasm<int>(push(i5), op(0x37))))
		i29 =  (i29 + 1)
		__asm(push(i29), push(i5), op(0x3c))
		i1 =  (i1 + 8)
		__asm(push(i29>7), iftrue, target("___vfprintf__XprivateX__BB54_1267_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1266_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1271_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1267_F"))
		__asm(push(i28!=0), iftrue, target("___vfprintf__XprivateX__BB54_1269_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1268_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		i1 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1271_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1269_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 87
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state87"))
		i1 = mstate.eax
		mstate.esp += 8
		i28 =  (0)
		__asm(push(i28), push(i4), op(0x3c))
		__asm(push(i28), push(i5), op(0x3c))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1270_F"))
		i1 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1271_F"))
		i28 = i1
		i1 =  (i27 + -16)
	__asm(lbl("___vfprintf__XprivateX__BB54_1272_F"))
		i27 = i1
		i1 = i28
		i28 =  (_zeroes_2E_4527)
		__asm(push(i28), push(i1), op(0x3c))
		i28 =  (i1 + 4)
		__asm(push(i27>16), iftrue, target("___vfprintf__XprivateX__BB54_1265_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1273_F"))
		__asm(push(i27), push(i28), op(0x3c))
		i28 =  ((__xasm<int>(push(i4), op(0x37))))
		i27 =  (i28 + i27)
		__asm(push(i27), push(i4), op(0x3c))
		i28 =  ((__xasm<int>(push(i5), op(0x37))))
		i28 =  (i28 + 1)
		__asm(push(i28), push(i5), op(0x3c))
		i1 =  (i1 + 8)
		__asm(push(i28>7), iftrue, target("___vfprintf__XprivateX__BB54_1275_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1274_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1277_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1275_F"))
		__asm(push(i27!=0), iftrue, target("___vfprintf__XprivateX__BB54_1537_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1276_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		i1 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1277_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1277_F"))
		i27 =  (i7 & 256)
		__asm(push(i27!=0), iftrue, target("___vfprintf__XprivateX__BB54_1285_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1278_F"))
		__asm(push(i12), push(i1), op(0x3c))
		__asm(push(i8), push((i1+4)), op(0x3c))
		i12 =  ((__xasm<int>(push(i4), op(0x37))))
		i12 =  (i12 + i8)
		__asm(push(i12), push(i4), op(0x3c))
		i16 =  ((__xasm<int>(push(i5), op(0x37))))
		i16 =  (i16 + 1)
		__asm(push(i16), push(i5), op(0x3c))
		i1 =  (i1 + 8)
		__asm(push(i16>7), iftrue, target("___vfprintf__XprivateX__BB54_1280_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1279_F"))
		i12 = i14
		i14 = i20
		i16 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1471_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1280_F"))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1282_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1281_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1283_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1282_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 88
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state88"))
		i1 = mstate.eax
		mstate.esp += 8
		i12 =  (0)
		__asm(push(i12), push(i4), op(0x3c))
		__asm(push(i12), push(i5), op(0x3c))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1283_F"))
		i1 =  (i7 & 4)
		__asm(push(i1==0), iftrue, target("___vfprintf__XprivateX__BB54_1488_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1284_F"))
		i1 = i3
		i7 = i14
		i12 = i20
		i14 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1473_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1285_F"))
		i8 =  (i13 & 255)
		__asm(push(i8!=0), iftrue, target("___vfprintf__XprivateX__BB54_1430_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1286_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1760)), op(0x37))))
		__asm(push(i8>0), iftrue, target("___vfprintf__XprivateX__BB54_1322_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1287_F"))
		i8 =  (_zeroes_2E_4527)
		__asm(push(i8), push(i1), op(0x3c))
		i8 =  (1)
		__asm(push(i8), push((i1+4)), op(0x3c))
		i8 =  ((__xasm<int>(push(i4), op(0x37))))
		i8 =  (i8 + 1)
		__asm(push(i8), push(i4), op(0x3c))
		i27 =  ((__xasm<int>(push(i5), op(0x37))))
		i27 =  (i27 + 1)
		__asm(push(i27), push(i5), op(0x3c))
		i1 =  (i1 + 8)
		__asm(push(i27>7), iftrue, target("___vfprintf__XprivateX__BB54_1289_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1288_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1293_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1289_F"))
		__asm(push(i8!=0), iftrue, target("___vfprintf__XprivateX__BB54_1291_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1290_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		i1 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1293_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1291_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 89
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state89"))
		i1 = mstate.eax
		mstate.esp += 8
		i8 =  (0)
		__asm(push(i8), push(i4), op(0x3c))
		__asm(push(i8), push(i5), op(0x3c))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1292_F"))
		i1 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1293_F"))
		__asm(push(i16!=0), iftrue, target("___vfprintf__XprivateX__BB54_1298_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1294_F"))
		i8 =  (i7 & 1)
		__asm(push(i8!=0), iftrue, target("___vfprintf__XprivateX__BB54_1298_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1295_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1296_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1296_F"), lbl("___vfprintf__XprivateX__BB54_1296_B"), label, lbl("___vfprintf__XprivateX__BB54_1296_F")); 
		i8 = i1
		i1 =  ((__xasm<int>(push((mstate.ebp+-1760)), op(0x37))))
		i1 =  (0 - i1)
		__asm(push(i1>0), iftrue, target("___vfprintf__XprivateX__BB54_1307_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1297_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1297_F"))
		i1 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_1305_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1298_F"))
		i8 =  (1)
		i27 =  ((__xasm<int>(push((mstate.ebp+-2079)), op(0x37))))
		__asm(push(i27), push(i1), op(0x3c))
		__asm(push(i8), push((i1+4)), op(0x3c))
		i8 =  ((__xasm<int>(push(i4), op(0x37))))
		i8 =  (i8 + 1)
		__asm(push(i8), push(i4), op(0x3c))
		i27 =  ((__xasm<int>(push(i5), op(0x37))))
		i27 =  (i27 + 1)
		__asm(push(i27), push(i5), op(0x3c))
		i1 =  (i1 + 8)
		__asm(push(i27>7), iftrue, target("___vfprintf__XprivateX__BB54_1300_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1299_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1296_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1300_F"))
		__asm(push(i8!=0), iftrue, target("___vfprintf__XprivateX__BB54_1302_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1301_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1303_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1302_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 90
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state90"))
		i1 = mstate.eax
		mstate.esp += 8
		i8 =  (0)
		__asm(push(i8), push(i4), op(0x3c))
		__asm(push(i8), push(i5), op(0x3c))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1303_F"))
		i1 =  ((__xasm<int>(push((mstate.ebp+-1760)), op(0x37))))
		i1 =  (0 - i1)
		__asm(push(i1>0), iftrue, target("___vfprintf__XprivateX__BB54_1306_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1304_F"))
		i1 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1305_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1305_F"), lbl("___vfprintf__XprivateX__BB54_1305_B"), label, lbl("___vfprintf__XprivateX__BB54_1305_F")); 
		i8 =  ((__xasm<int>(push((mstate.ebp+-1760)), op(0x37))))
		i16 =  (i8 + i16)
		i8 = i1
		i1 = i16
		i16 = i20
		i20 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1404_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1306_F"))
		i8 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1315_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1307_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1315_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1308_B"), label)
		i28 =  (16)
		__asm(push(i28), push(i27), op(0x3c))
		i27 =  ((__xasm<int>(push(i4), op(0x37))))
		i27 =  (i27 + 16)
		__asm(push(i27), push(i4), op(0x3c))
		i28 =  ((__xasm<int>(push(i5), op(0x37))))
		i28 =  (i28 + 1)
		__asm(push(i28), push(i5), op(0x3c))
		i8 =  (i8 + 8)
		__asm(push(i28>7), iftrue, target("___vfprintf__XprivateX__BB54_1310_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1309_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1314_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1310_F"))
		__asm(push(i27!=0), iftrue, target("___vfprintf__XprivateX__BB54_1312_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1311_F"))
		i8 =  (0)
		__asm(push(i8), push(i5), op(0x3c))
		i8 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1314_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1312_F"))
		i8 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i8), push((mstate.esp+4)), op(0x3c))
		state = 91
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state91"))
		i8 = mstate.eax
		mstate.esp += 8
		i27 =  (0)
		__asm(push(i27), push(i4), op(0x3c))
		__asm(push(i27), push(i5), op(0x3c))
		__asm(push(i8!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1313_F"))
		i8 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1314_F"))
		i1 =  (i1 + -16)
	__asm(lbl("___vfprintf__XprivateX__BB54_1315_F"))
		i27 =  (_zeroes_2E_4527)
		__asm(push(i27), push(i8), op(0x3c))
		i27 =  (i8 + 4)
		__asm(push(i1>16), iftrue, target("___vfprintf__XprivateX__BB54_1308_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1316_F"))
		__asm(push(i1), push(i27), op(0x3c))
		i27 =  ((__xasm<int>(push(i4), op(0x37))))
		i1 =  (i27 + i1)
		__asm(push(i1), push(i4), op(0x3c))
		i27 =  ((__xasm<int>(push(i5), op(0x37))))
		i27 =  (i27 + 1)
		__asm(push(i27), push(i5), op(0x3c))
		i8 =  (i8 + 8)
		__asm(push(i27>7), iftrue, target("___vfprintf__XprivateX__BB54_1318_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1317_F"))
		i1 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_1305_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1318_F"))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1320_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1319_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1321_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1320_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 92
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state92"))
		i1 = mstate.eax
		mstate.esp += 8
		i8 =  (0)
		__asm(push(i8), push(i4), op(0x3c))
		__asm(push(i8), push(i5), op(0x3c))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1321_F"))
		i1 =  ((__xasm<int>(push((mstate.ebp+-1760)), op(0x37))))
		i1 =  (i1 + i16)
		i8 = i3
		i16 = i20
		i20 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1404_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1322_F"))
		i8 =  ((__xasm<int>(push((mstate.ebp+-1756)), op(0x37))))
		i8 =  (i8 - i12)
		i8 =  ((i8>i18) ? i18 : i8)
		__asm(push(i8>0), iftrue, target("___vfprintf__XprivateX__BB54_1326_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1323_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1324_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1324_F"), lbl("___vfprintf__XprivateX__BB54_1324_B"), label, lbl("___vfprintf__XprivateX__BB54_1324_F")); 
		i27 = i1
		i1 =  (i18 - i8)
		i1 =  ((i8<0) ? i18 : i1)
		__asm(push(i1>0), iftrue, target("___vfprintf__XprivateX__BB54_1336_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1325_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1325_F"))
		i1 = i27
		__asm(jump, target("___vfprintf__XprivateX__BB54_1333_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1326_F"))
		__asm(push(i12), push(i1), op(0x3c))
		__asm(push(i8), push((i1+4)), op(0x3c))
		i27 =  ((__xasm<int>(push(i4), op(0x37))))
		i27 =  (i27 + i8)
		__asm(push(i27), push(i4), op(0x3c))
		i28 =  ((__xasm<int>(push(i5), op(0x37))))
		i28 =  (i28 + 1)
		__asm(push(i28), push(i5), op(0x3c))
		i1 =  (i1 + 8)
		__asm(push(i28>7), iftrue, target("___vfprintf__XprivateX__BB54_1328_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1327_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1324_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1328_F"))
		__asm(push(i27!=0), iftrue, target("___vfprintf__XprivateX__BB54_1330_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1329_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1331_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1330_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 93
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state93"))
		i1 = mstate.eax
		mstate.esp += 8
		i27 =  (0)
		__asm(push(i27), push(i4), op(0x3c))
		__asm(push(i27), push(i5), op(0x3c))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1331_F"))
		i1 =  (i18 - i8)
		i1 =  ((i8<0) ? i18 : i1)
		__asm(push(i1>0), iftrue, target("___vfprintf__XprivateX__BB54_1335_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1332_F"))
		i1 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1333_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1333_F"), lbl("___vfprintf__XprivateX__BB54_1333_B"), label, lbl("___vfprintf__XprivateX__BB54_1333_F")); 
		i8 = i1
		i1 =  (i12 + i18)
		__asm(push(i14==0), iftrue, target("___vfprintf__XprivateX__BB54_1354_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1334_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1334_F"))
		i12 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_1352_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1335_F"))
		i8 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1344_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1336_F"))
		i8 = i27
		__asm(jump, target("___vfprintf__XprivateX__BB54_1344_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1337_B"), label)
		i28 =  (16)
		__asm(push(i28), push(i1), op(0x3c))
		i1 =  ((__xasm<int>(push(i4), op(0x37))))
		i1 =  (i1 + 16)
		__asm(push(i1), push(i4), op(0x3c))
		i28 =  ((__xasm<int>(push(i5), op(0x37))))
		i28 =  (i28 + 1)
		__asm(push(i28), push(i5), op(0x3c))
		i8 =  (i8 + 8)
		__asm(push(i28>7), iftrue, target("___vfprintf__XprivateX__BB54_1339_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1338_F"))
		i1 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_1343_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1339_F"))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1341_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1340_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		i1 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1343_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1341_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 94
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state94"))
		i1 = mstate.eax
		mstate.esp += 8
		i8 =  (0)
		__asm(push(i8), push(i4), op(0x3c))
		__asm(push(i8), push(i5), op(0x3c))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1342_F"))
		i1 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1343_F"))
		i8 = i1
		i1 =  (i27 + -16)
	__asm(lbl("___vfprintf__XprivateX__BB54_1344_F"))
		i27 = i1
		i1 =  (_zeroes_2E_4527)
		__asm(push(i1), push(i8), op(0x3c))
		i1 =  (i8 + 4)
		__asm(push(i27>16), iftrue, target("___vfprintf__XprivateX__BB54_1337_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1345_F"))
		__asm(push(i27), push(i1), op(0x3c))
		i1 =  ((__xasm<int>(push(i4), op(0x37))))
		i1 =  (i1 + i27)
		__asm(push(i1), push(i4), op(0x3c))
		i27 =  ((__xasm<int>(push(i5), op(0x37))))
		i27 =  (i27 + 1)
		__asm(push(i27), push(i5), op(0x3c))
		i8 =  (i8 + 8)
		__asm(push(i27>7), iftrue, target("___vfprintf__XprivateX__BB54_1347_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1346_F"))
		i1 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_1333_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1347_F"))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1349_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1348_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1350_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1349_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 95
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state95"))
		i1 = mstate.eax
		mstate.esp += 8
		i8 =  (0)
		__asm(push(i8), push(i4), op(0x3c))
		__asm(push(i8), push(i5), op(0x3c))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1350_F"))
		i1 =  (i12 + i18)
		__asm(push(i14==0), iftrue, target("___vfprintf__XprivateX__BB54_1353_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1351_F"))
		i12 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1352_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1352_F"))
		i8 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1390_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1353_F"))
		i12 = i3
		i8 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1395_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1354_F"))
		i12 = i8
		i8 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1395_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1355_B"), label)
		__asm(push(i22<1), iftrue, target("___vfprintf__XprivateX__BB54_1357_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1356_F"))
		i22 =  (i22 + -1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1358_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1357_F"))
		i20 =  (i20 + -1)
		i14 =  (i14 + -1)
	__asm(lbl("___vfprintf__XprivateX__BB54_1358_F"))
		i28 =  ((mstate.ebp+-1761))
		__asm(push(i28), push(i27), op(0x3c))
		i28 =  (1)
		__asm(push(i28), push((i27+4)), op(0x3c))
		i28 =  ((__xasm<int>(push(i4), op(0x37))))
		i28 =  (i28 + 1)
		__asm(push(i28), push(i4), op(0x3c))
		i29 =  ((__xasm<int>(push(i5), op(0x37))))
		i29 =  (i29 + 1)
		__asm(push(i29), push(i5), op(0x3c))
		i27 =  (i27 + 8)
		__asm(push(i29>7), iftrue, target("___vfprintf__XprivateX__BB54_1360_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1359_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1364_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1360_F"))
		__asm(push(i28!=0), iftrue, target("___vfprintf__XprivateX__BB54_1362_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1361_F"))
		i27 =  (0)
		__asm(push(i27), push(i5), op(0x3c))
		i27 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1364_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1362_F"))
		i27 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i27), push((mstate.esp+4)), op(0x3c))
		state = 96
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state96"))
		i27 = mstate.eax
		mstate.esp += 8
		i28 =  (0)
		__asm(push(i28), push(i4), op(0x3c))
		__asm(push(i28), push(i5), op(0x3c))
		__asm(push(i27!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1363_F"))
		i27 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1364_F"))
		i28 =  ((__xasm<int>(push((mstate.ebp+-1756)), op(0x37))))
		i29 =  ((__xasm<int>(push(i14), op(0x35), op(0x51))))
		i28 =  (i28 - i12)
		i28 =  ((i29<i28) ? i29 : i28)
		__asm(push(i28>0), iftrue, target("___vfprintf__XprivateX__BB54_1366_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1365_F"))
		i12 = i27
		__asm(jump, target("___vfprintf__XprivateX__BB54_1372_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1366_F"))
		__asm(push(i12), push(i27), op(0x3c))
		__asm(push(i28), push((i27+4)), op(0x3c))
		i12 =  ((__xasm<int>(push(i4), op(0x37))))
		i12 =  (i12 + i28)
		__asm(push(i12), push(i4), op(0x3c))
		i29 =  ((__xasm<int>(push(i5), op(0x37))))
		i29 =  (i29 + 1)
		__asm(push(i29), push(i5), op(0x3c))
		i27 =  (i27 + 8)
		__asm(push(i29>7), iftrue, target("___vfprintf__XprivateX__BB54_1368_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1367_F"))
		i12 = i27
		__asm(jump, target("___vfprintf__XprivateX__BB54_1372_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1368_F"))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1370_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1369_F"))
		i12 =  (0)
		__asm(push(i12), push(i5), op(0x3c))
		i12 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1372_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1370_F"))
		i12 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i12), push((mstate.esp+4)), op(0x3c))
		state = 97
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state97"))
		i12 = mstate.eax
		mstate.esp += 8
		i27 =  (0)
		__asm(push(i27), push(i4), op(0x3c))
		__asm(push(i27), push(i5), op(0x3c))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1371_F"))
		i12 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1372_F"))
		i27 =  ((__xasm<int>(push(i14), op(0x35))))
		i29 =  (i27 << 24)
		i28 =  ((i28>-1) ? i28 : 0)
		i29 =  (i29 >> 24)
		i29 =  (i29 - i28)
		__asm(push(i29>0), iftrue, target("___vfprintf__XprivateX__BB54_1374_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1373_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1389_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1374_F"))
		i27 =  (i27 << 24)
		i27 =  (i27 >> 24)
		i27 =  (i27 - i28)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1382_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1375_B"), label)
		i29 =  (16)
		__asm(push(i29), push(i28), op(0x3c))
		i28 =  ((__xasm<int>(push(i4), op(0x37))))
		i28 =  (i28 + 16)
		__asm(push(i28), push(i4), op(0x3c))
		i29 =  ((__xasm<int>(push(i5), op(0x37))))
		i29 =  (i29 + 1)
		__asm(push(i29), push(i5), op(0x3c))
		i12 =  (i12 + 8)
		__asm(push(i29>7), iftrue, target("___vfprintf__XprivateX__BB54_1377_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1376_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1381_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1377_F"))
		__asm(push(i28!=0), iftrue, target("___vfprintf__XprivateX__BB54_1379_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1378_F"))
		i12 =  (0)
		__asm(push(i12), push(i5), op(0x3c))
		i12 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1381_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1379_F"))
		i12 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i12), push((mstate.esp+4)), op(0x3c))
		state = 98
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state98"))
		i12 = mstate.eax
		mstate.esp += 8
		i28 =  (0)
		__asm(push(i28), push(i4), op(0x3c))
		__asm(push(i28), push(i5), op(0x3c))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1380_F"))
		i12 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1381_F"))
		i27 =  (i27 + -16)
	__asm(lbl("___vfprintf__XprivateX__BB54_1382_F"))
		i28 =  (_zeroes_2E_4527)
		__asm(push(i28), push(i12), op(0x3c))
		i28 =  (i12 + 4)
		__asm(push(i27>16), iftrue, target("___vfprintf__XprivateX__BB54_1375_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1383_F"))
		__asm(push(i27), push(i28), op(0x3c))
		i28 =  ((__xasm<int>(push(i4), op(0x37))))
		i27 =  (i28 + i27)
		__asm(push(i27), push(i4), op(0x3c))
		i28 =  ((__xasm<int>(push(i5), op(0x37))))
		i28 =  (i28 + 1)
		__asm(push(i28), push(i5), op(0x3c))
		i12 =  (i12 + 8)
		__asm(push(i28>7), iftrue, target("___vfprintf__XprivateX__BB54_1385_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1384_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1389_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1385_F"))
		__asm(push(i27!=0), iftrue, target("___vfprintf__XprivateX__BB54_1387_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1386_F"))
		i12 =  (0)
		__asm(push(i12), push(i5), op(0x3c))
		i12 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1389_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1387_F"))
		i12 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i12), push((mstate.esp+4)), op(0x3c))
		state = 99
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state99"))
		i12 = mstate.eax
		mstate.esp += 8
		i27 =  (0)
		__asm(push(i27), push(i4), op(0x3c))
		__asm(push(i27), push(i5), op(0x3c))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1388_F"))
		i12 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1389_F"))
		i27 =  ((__xasm<int>(push(i14), op(0x35), op(0x51))))
		i8 =  (i8 + i27)
	__asm(lbl("___vfprintf__XprivateX__BB54_1390_F"))
		i27 = i12
		i12 =  (i1 + i8)
		__asm(push(i22>0), iftrue, target("___vfprintf__XprivateX__BB54_1355_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1391_F"))
		__asm(push(i20>0), iftrue, target("___vfprintf__XprivateX__BB54_1355_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1392_F"))
		i1 =  ((__xasm<int>(push((mstate.ebp+-1756)), op(0x37))))
		__asm(push(uint(i12)>uint(i1)), iftrue, target("___vfprintf__XprivateX__BB54_1394_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1393_F"))
		i1 = i12
		i12 = i27
		i8 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1395_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1394_F"))
		i12 = i27
		i8 = i22
	__asm(lbl("___vfprintf__XprivateX__BB54_1395_F"))
		i22 = i12
		i27 = i8
		__asm(push(i16!=0), iftrue, target("___vfprintf__XprivateX__BB54_1398_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1396_F"))
		i12 =  (i7 & 1)
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1398_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1397_F"))
		i12 = i1
		i8 = i22
		i1 = i16
		i16 = i20
		i20 = i27
		__asm(jump, target("___vfprintf__XprivateX__BB54_1404_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1398_F"))
		i12 =  (1)
		i8 =  ((__xasm<int>(push((mstate.ebp+-2079)), op(0x37))))
		__asm(push(i8), push(i22), op(0x3c))
		__asm(push(i12), push((i22+4)), op(0x3c))
		i12 =  ((__xasm<int>(push(i4), op(0x37))))
		i12 =  (i12 + 1)
		__asm(push(i12), push(i4), op(0x3c))
		i8 =  ((__xasm<int>(push(i5), op(0x37))))
		i8 =  (i8 + 1)
		__asm(push(i8), push(i5), op(0x3c))
		i22 =  (i22 + 8)
		__asm(push(i8>7), iftrue, target("___vfprintf__XprivateX__BB54_1400_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1399_F"))
		i12 = i1
		i8 = i22
		i1 = i16
		i16 = i20
		i20 = i27
		__asm(jump, target("___vfprintf__XprivateX__BB54_1404_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1400_F"))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1402_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1401_F"))
		i12 =  (0)
		__asm(push(i12), push(i5), op(0x3c))
		i12 = i1
		i8 = i3
		i1 = i16
		i16 = i20
		i20 = i27
		__asm(jump, target("___vfprintf__XprivateX__BB54_1404_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1402_F"))
		i12 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i12), push((mstate.esp+4)), op(0x3c))
		state = 100
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state100"))
		i12 = mstate.eax
		mstate.esp += 8
		i8 =  (0)
		__asm(push(i8), push(i4), op(0x3c))
		__asm(push(i8), push(i5), op(0x3c))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1403_F"))
		i12 = i1
		i8 = i3
		i1 = i16
		i16 = i20
		i20 = i27
	__asm(lbl("___vfprintf__XprivateX__BB54_1404_F"))
		i22 = i8
		i8 =  ((__xasm<int>(push((mstate.ebp+-1756)), op(0x37))))
		i8 =  (i8 - i12)
		i8 =  ((i8>i1) ? i1 : i8)
		__asm(push(i8>0), iftrue, target("___vfprintf__XprivateX__BB54_1408_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1405_F"))
		i12 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1406_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1406_F"), lbl("___vfprintf__XprivateX__BB54_1406_B"), label, lbl("___vfprintf__XprivateX__BB54_1406_F")); 
		i22 =  (i1 - i8)
		i1 =  ((i8<0) ? i1 : i22)
		__asm(push(i1>0), iftrue, target("___vfprintf__XprivateX__BB54_1416_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1407_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1407_F"))
		i1 = i12
		i12 = i14
		i14 = i16
		i16 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_1471_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1408_F"))
		__asm(push(i12), push(i22), op(0x3c))
		__asm(push(i8), push((i22+4)), op(0x3c))
		i12 =  ((__xasm<int>(push(i4), op(0x37))))
		i12 =  (i12 + i8)
		__asm(push(i12), push(i4), op(0x3c))
		i27 =  ((__xasm<int>(push(i5), op(0x37))))
		i27 =  (i27 + 1)
		__asm(push(i27), push(i5), op(0x3c))
		i22 =  (i22 + 8)
		__asm(push(i27>7), iftrue, target("___vfprintf__XprivateX__BB54_1410_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1409_F"))
		i12 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1406_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1410_F"))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1412_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1411_F"))
		i12 =  (0)
		__asm(push(i12), push(i5), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1413_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1412_F"))
		i12 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i12), push((mstate.esp+4)), op(0x3c))
		state = 101
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state101"))
		i12 = mstate.eax
		mstate.esp += 8
		i22 =  (0)
		__asm(push(i22), push(i4), op(0x3c))
		__asm(push(i22), push(i5), op(0x3c))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1413_F"))
		i12 =  (i1 - i8)
		i1 =  ((i8<0) ? i1 : i12)
		__asm(push(i1>0), iftrue, target("___vfprintf__XprivateX__BB54_1415_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1414_F"), lbl("___vfprintf__XprivateX__BB54_1414_B"), label, lbl("___vfprintf__XprivateX__BB54_1414_F")); 
		i1 = i3
		i12 = i14
		i14 = i16
		i16 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_1471_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1415_F"))
		i12 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1424_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1416_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1424_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1417_B"), label)
		i8 =  (16)
		__asm(push(i8), push(i12), op(0x3c))
		i12 =  ((__xasm<int>(push(i4), op(0x37))))
		i12 =  (i12 + 16)
		__asm(push(i12), push(i4), op(0x3c))
		i8 =  ((__xasm<int>(push(i5), op(0x37))))
		i8 =  (i8 + 1)
		__asm(push(i8), push(i5), op(0x3c))
		i1 =  (i1 + 8)
		__asm(push(i8>7), iftrue, target("___vfprintf__XprivateX__BB54_1419_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1418_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1423_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1419_F"))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1421_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1420_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		i1 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1423_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1421_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 102
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state102"))
		i1 = mstate.eax
		mstate.esp += 8
		i12 =  (0)
		__asm(push(i12), push(i4), op(0x3c))
		__asm(push(i12), push(i5), op(0x3c))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1422_F"))
		i1 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1423_F"))
		i12 = i1
		i1 =  (i22 + -16)
	__asm(lbl("___vfprintf__XprivateX__BB54_1424_F"))
		i22 = i1
		i1 = i12
		i12 =  (_zeroes_2E_4527)
		__asm(push(i12), push(i1), op(0x3c))
		i12 =  (i1 + 4)
		__asm(push(i22>16), iftrue, target("___vfprintf__XprivateX__BB54_1417_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1425_F"))
		__asm(push(i22), push(i12), op(0x3c))
		i12 =  ((__xasm<int>(push(i4), op(0x37))))
		i12 =  (i12 + i22)
		__asm(push(i12), push(i4), op(0x3c))
		i22 =  ((__xasm<int>(push(i5), op(0x37))))
		i22 =  (i22 + 1)
		__asm(push(i22), push(i5), op(0x3c))
		i1 =  (i1 + 8)
		__asm(push(i22>7), iftrue, target("___vfprintf__XprivateX__BB54_1427_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1426_F"))
		i12 = i14
		i14 = i16
		i16 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_1471_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1427_F"))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1429_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1428_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		i1 = i3
		i12 = i14
		i14 = i16
		i16 = i20
		__asm(jump, target("___vfprintf__XprivateX__BB54_1471_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1429_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 103
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state103"))
		i1 = mstate.eax
		mstate.esp += 8
		i12 =  (0)
		__asm(push(i12), push(i4), op(0x3c))
		__asm(push(i12), push(i5), op(0x3c))
		__asm(push(i1==0), iftrue, target("___vfprintf__XprivateX__BB54_1414_B"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1430_F"))
		__asm(push(i16>1), iftrue, target("___vfprintf__XprivateX__BB54_1432_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1431_F"))
		i8 =  (i7 & 1)
		__asm(push(i8==0), iftrue, target("___vfprintf__XprivateX__BB54_1461_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1432_F"))
		i8 =  (46)
		i27 =  ((__xasm<int>(push(i12), op(0x35))))
		i28 =  ((__xasm<int>(push((mstate.ebp+-2205)), op(0x37))))
		__asm(push(i27), push(i28), op(0x3a))
		i27 =  ((__xasm<int>(push((mstate.ebp+-2070)), op(0x37))))
		__asm(push(i8), push(i27), op(0x3a))
		__asm(push(i28), push(i1), op(0x3c))
		i8 =  (2)
		__asm(push(i8), push((i1+4)), op(0x3c))
		i8 =  ((__xasm<int>(push(i4), op(0x37))))
		i8 =  (i8 + 2)
		__asm(push(i8), push(i4), op(0x3c))
		i27 =  ((__xasm<int>(push(i5), op(0x37))))
		i27 =  (i27 + 1)
		__asm(push(i27), push(i5), op(0x3c))
		i1 =  (i1 + 8)
		i12 =  (i12 + 1)
		__asm(push(i27>7), iftrue, target("___vfprintf__XprivateX__BB54_1434_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1433_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1438_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1434_F"))
		__asm(push(i8!=0), iftrue, target("___vfprintf__XprivateX__BB54_1436_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1435_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		i1 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1438_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1436_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 104
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state104"))
		i1 = mstate.eax
		mstate.esp += 8
		i8 =  (0)
		__asm(push(i8), push(i4), op(0x3c))
		__asm(push(i8), push(i5), op(0x3c))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1437_F"))
		i1 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1438_F"))
		__asm(push(i12), push(i1), op(0x3c))
		i12 =  (i19 + -1)
		__asm(push(i12), push((i1+4)), op(0x3c))
		i8 =  ((__xasm<int>(push(i4), op(0x37))))
		i12 =  (i12 + i8)
		__asm(push(i12), push(i4), op(0x3c))
		i8 =  ((__xasm<int>(push(i5), op(0x37))))
		i8 =  (i8 + 1)
		__asm(push(i8), push(i5), op(0x3c))
		i1 =  (i1 + 8)
		__asm(push(i8<8), iftrue, target("___vfprintf__XprivateX__BB54_1445_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1439_F"))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1441_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1440_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1442_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1441_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 105
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state105"))
		i1 = mstate.eax
		mstate.esp += 8
		i12 =  (0)
		__asm(push(i12), push(i4), op(0x3c))
		__asm(push(i12), push(i5), op(0x3c))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1442_F"))
		i1 =  (i16 - i19)
		__asm(push(i1>0), iftrue, target("___vfprintf__XprivateX__BB54_1444_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1443_F"), lbl("___vfprintf__XprivateX__BB54_1443_B"), label, lbl("___vfprintf__XprivateX__BB54_1443_F")); 
		i1 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1465_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1444_F"))
		i12 = i1
		i1 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1455_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1445_F"))
		i12 =  (i16 - i19)
		__asm(push(i12>0), iftrue, target("___vfprintf__XprivateX__BB54_1447_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1446_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1465_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1447_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1455_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1448_B"), label)
		i8 =  (16)
		__asm(push(i8), push(i12), op(0x3c))
		i12 =  ((__xasm<int>(push(i4), op(0x37))))
		i12 =  (i12 + 16)
		__asm(push(i12), push(i4), op(0x3c))
		i8 =  ((__xasm<int>(push(i5), op(0x37))))
		i8 =  (i8 + 1)
		__asm(push(i8), push(i5), op(0x3c))
		i1 =  (i1 + 8)
		__asm(push(i8>7), iftrue, target("___vfprintf__XprivateX__BB54_1450_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1449_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1454_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1450_F"))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1452_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1451_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		i1 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1454_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1452_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 106
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state106"))
		i1 = mstate.eax
		mstate.esp += 8
		i12 =  (0)
		__asm(push(i12), push(i4), op(0x3c))
		__asm(push(i12), push(i5), op(0x3c))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1453_F"))
		i1 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1454_F"))
		i12 =  (i16 + -16)
	__asm(lbl("___vfprintf__XprivateX__BB54_1455_F"))
		i16 = i12
		i12 =  (_zeroes_2E_4527)
		__asm(push(i12), push(i1), op(0x3c))
		i12 =  (i1 + 4)
		__asm(push(i16>16), iftrue, target("___vfprintf__XprivateX__BB54_1448_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1456_F"))
		__asm(push(i16), push(i12), op(0x3c))
		i12 =  ((__xasm<int>(push(i4), op(0x37))))
		i12 =  (i12 + i16)
		__asm(push(i12), push(i4), op(0x3c))
		i16 =  ((__xasm<int>(push(i5), op(0x37))))
		i16 =  (i16 + 1)
		__asm(push(i16), push(i5), op(0x3c))
		i1 =  (i1 + 8)
		__asm(push(i16>7), iftrue, target("___vfprintf__XprivateX__BB54_1458_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1457_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1465_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1458_F"))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1460_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1459_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		i1 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1465_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1460_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 107
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state107"))
		i1 = mstate.eax
		mstate.esp += 8
		i12 =  (0)
		__asm(push(i12), push(i4), op(0x3c))
		__asm(push(i12), push(i5), op(0x3c))
		__asm(push(i1==0), iftrue, target("___vfprintf__XprivateX__BB54_1443_B"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1461_F"))
		i16 =  (1)
		__asm(push(i12), push(i1), op(0x3c))
		__asm(push(i16), push((i1+4)), op(0x3c))
		i12 =  ((__xasm<int>(push(i4), op(0x37))))
		i12 =  (i12 + 1)
		__asm(push(i12), push(i4), op(0x3c))
		i16 =  ((__xasm<int>(push(i5), op(0x37))))
		i16 =  (i16 + 1)
		__asm(push(i16), push(i5), op(0x3c))
		i1 =  (i1 + 8)
		__asm(push(i16>7), iftrue, target("___vfprintf__XprivateX__BB54_1463_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1462_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1465_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1463_F"))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1538_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1464_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		i1 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1465_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1465_F"))
		i12 =  ((__xasm<int>(push((mstate.ebp+-2178)), op(0x37))))
		__asm(push(i12), push(i1), op(0x3c))
		__asm(push(i17), push((i1+4)), op(0x3c))
		i12 =  ((__xasm<int>(push(i4), op(0x37))))
		i12 =  (i12 + i17)
		__asm(push(i12), push(i4), op(0x3c))
		i16 =  ((__xasm<int>(push(i5), op(0x37))))
		i16 =  (i16 + 1)
		__asm(push(i16), push(i5), op(0x3c))
		i1 =  (i1 + 8)
		__asm(push(i16>7), iftrue, target("___vfprintf__XprivateX__BB54_1467_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1466_F"))
		i12 = i14
		i14 = i20
		i16 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1471_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1467_F"))
		__asm(push(i12!=0), iftrue, target("___vfprintf__XprivateX__BB54_1469_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1468_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		i1 = i3
		i12 = i14
		i14 = i20
		i16 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1471_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1469_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 108
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state108"))
		i1 = mstate.eax
		mstate.esp += 8
		i12 =  (0)
		__asm(push(i12), push(i4), op(0x3c))
		__asm(push(i12), push(i5), op(0x3c))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1470_F"))
		i1 = i3
		i12 = i14
		i14 = i20
		i16 = i22
	__asm(lbl("___vfprintf__XprivateX__BB54_1471_F"))
		i8 = i16
		i7 =  (i7 & 4)
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_1539_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1472_F"))
		i7 = i12
		i12 = i14
		i14 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_1473_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1473_F"))
		i8 = i14
		i10 =  (i6 - i10)
		__asm(push(i10>0), iftrue, target("___vfprintf__XprivateX__BB54_1475_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1474_F"), lbl("___vfprintf__XprivateX__BB54_1474_B"), label, lbl("___vfprintf__XprivateX__BB54_1474_F")); 
		i1 = i7
		i7 = i12
		i12 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_1489_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1475_F"))
		i2 =  (i2 & 255)
		i2 =  ((i2!=0) ? 1 : 0)
		i2 =  (i2 & 1)
		i10 =  (i24 + i25)
		i2 =  (i10 + i2)
		i6 =  (i6 - i2)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1483_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1476_B"), label)
		i10 =  (16)
		__asm(push(i10), push(i6), op(0x3c))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i6 =  (i6 + 16)
		__asm(push(i6), push(i4), op(0x3c))
		i10 =  ((__xasm<int>(push(i5), op(0x37))))
		i10 =  (i10 + 1)
		__asm(push(i10), push(i5), op(0x3c))
		i1 =  (i1 + 8)
		__asm(push(i10>7), iftrue, target("___vfprintf__XprivateX__BB54_1478_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1477_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1482_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1478_F"))
		__asm(push(i6!=0), iftrue, target("___vfprintf__XprivateX__BB54_1480_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1479_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		i1 = i3
		__asm(jump, target("___vfprintf__XprivateX__BB54_1482_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1480_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 109
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state109"))
		i1 = mstate.eax
		mstate.esp += 8
		i6 =  (0)
		__asm(push(i6), push(i4), op(0x3c))
		__asm(push(i6), push(i5), op(0x3c))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1481_F"))
		i1 = i3
	__asm(lbl("___vfprintf__XprivateX__BB54_1482_F"))
		i6 =  (i2 + -16)
	__asm(lbl("___vfprintf__XprivateX__BB54_1483_F"))
		i2 = i6
		i6 =  (_blanks_2E_4526)
		__asm(push(i6), push(i1), op(0x3c))
		i6 =  (i1 + 4)
		__asm(push(i2>16), iftrue, target("___vfprintf__XprivateX__BB54_1476_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1484_F"))
		__asm(push(i2), push(i6), op(0x3c))
		i1 =  ((__xasm<int>(push(i4), op(0x37))))
		i1 =  (i1 + i2)
		__asm(push(i1), push(i4), op(0x3c))
		i6 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  (i6 + 1)
		__asm(push(i6), push(i5), op(0x3c))
		__asm(push(i6<8), iftrue, target("___vfprintf__XprivateX__BB54_1474_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1485_F"))
		__asm(push(i1!=0), iftrue, target("___vfprintf__XprivateX__BB54_1487_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1486_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		i1 = i7
		i7 = i12
		i12 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_1489_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1487_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 110
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state110"))
		i1 = mstate.eax
		mstate.esp += 8
		i6 =  (0)
		__asm(push(i6), push(i4), op(0x3c))
		__asm(push(i6), push(i5), op(0x3c))
		__asm(push(i1==0), iftrue, target("___vfprintf__XprivateX__BB54_1474_B"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1488_F"))
		i1 = i14
		i7 = i20
		i12 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1489_F"))
	__asm(jump, target("___vfprintf__XprivateX__BB54_1489_F"), lbl("___vfprintf__XprivateX__BB54_1489_B"), label, lbl("___vfprintf__XprivateX__BB54_1489_F")); 
		i2 = i12
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		__asm(push(i6==0), iftrue, target("___vfprintf__XprivateX__BB54_22_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1490_F"))
		i6 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i6), push((mstate.esp+4)), op(0x3c))
		state = 111
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state111"))
		i6 = mstate.eax
		mstate.esp += 8
		i8 =  (0)
		__asm(push(i8), push(i4), op(0x3c))
		__asm(push(i8), push(i5), op(0x3c))
		__asm(push(i6==0), iftrue, target("___vfprintf__XprivateX__BB54_22_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1491_F"))
		i6 = i26
		i9 = i21
		i0 = i23
		__asm(jump, target("___vfprintf__XprivateX__BB54_1496_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1492_F"))
		i7 =  ((__xasm<int>(push(i4), op(0x37))))
		__asm(push(i7==0), iftrue, target("___vfprintf__XprivateX__BB54_1495_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1493_F"))
		i7 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		state = 112
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state112"))
		i0 = mstate.eax
		mstate.esp += 8
		i7 =  (0)
		__asm(push(i7), push(i4), op(0x3c))
		__asm(push(i7), push(i5), op(0x3c))
		__asm(push(i0==0), iftrue, target("___vfprintf__XprivateX__BB54_1495_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1494_F"))
		i0 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		i6 = i0
		i9 = i21
		i0 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1496_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1495_F"))
		i0 =  (0)
		__asm(push(i0), push(i5), op(0x3c))
		i0 =  ((__xasm<int>(push((mstate.ebp+-2322)), op(0x37))))
		i6 = i0
		i9 = i21
		i0 =  ((__xasm<int>(push((mstate.ebp+-2403)), op(0x37))))
	__asm(lbl("___vfprintf__XprivateX__BB54_1496_F"))
		i7 = i6
		i1 = i9
		i2 = i0
		__asm(push(i1==0), iftrue, target("___vfprintf__XprivateX__BB54_1540_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1497_F"))
		i0 = i1
		i1 = i2
		__asm(jump, target("___vfprintf__XprivateX__BB54_1498_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1498_F"))
		i2 =  (1)
		i3 =  ((__xasm<int>(push((i0+-4)), op(0x37))))
		__asm(push(i3), push(i0), op(0x3c))
		i2 =  (i2 << i3)
		__asm(push(i2), push((i0+4)), op(0x3c))
		i0 =  (i0 + -4)
		i2 = i0
		__asm(push(i0!=0), iftrue, target("___vfprintf__XprivateX__BB54_1500_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1499_F"))
		i0 = i1
		__asm(jump, target("___vfprintf__XprivateX__BB54_1501_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1500_F"))
		i4 =  (_freelist)
		i3 =  (i3 << 2)
		i3 =  (i4 + i3)
		i4 =  ((__xasm<int>(push(i3), op(0x37))))
		__asm(push(i4), push(i0), op(0x3c))
		__asm(push(i2), push(i3), op(0x3c))
		i0 = i1
	__asm(jump, target("___vfprintf__XprivateX__BB54_1501_F"), lbl("___vfprintf__XprivateX__BB54_1501_B"), label, lbl("___vfprintf__XprivateX__BB54_1501_F")); 
		i1 = i7
		__asm(push(i0==0), iftrue, target("___vfprintf__XprivateX__BB54_1503_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1502_F"))
		i2 =  (0)
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i2), push((mstate.esp+4)), op(0x3c))
		state = 113
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___vfprintf_state113"))
		i0 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___vfprintf__XprivateX__BB54_1503_F"))
		i0 =  ((__xasm<int>(push((mstate.ebp+-1980)), op(0x37))))
		i0 =  ((__xasm<int>(push(i0), op(0x36))))
		i2 =  ((__xasm<int>(push((mstate.ebp+-1556)), op(0x37))))
		i0 =  (i0 & 64)
		i0 =  ((i0==0) ? i1 : -1)
		__asm(push(i2==0), iftrue, target("___vfprintf__XprivateX__BB54_1505_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1504_F"))
		i1 =  ((__xasm<int>(push((mstate.ebp+-2259)), op(0x37))))
		__asm(push(i1!=i2), iftrue, target("___vfprintf__XprivateX__BB54_1506_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1505_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1507_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1506_F"))
		i1 =  (0)
		mstate.esp -= 8
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 114
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___vfprintf_state114"))
		i1 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___vfprintf__XprivateX__BB54_1507_F"))
		mstate.eax = i0
	__asm(lbl("___vfprintf__XprivateX__BB54_1508_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___vfprintf__XprivateX__BB54_1509_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_28_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1510_F"))
		i6 = i9
		i9 = i1
		i10 = i14
		i2 = i15
		i1 = i16
		__asm(jump, target("___vfprintf__XprivateX__BB54_46_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1511_F"))
		i10 =  (0)
		i9 = i10
		__asm(jump, target("___vfprintf__XprivateX__BB54_179_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1512_F"))
		i18 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_307_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1513_F"))
		i24 =  (0)
		i20 = i10
		i10 = i24
		__asm(jump, target("___vfprintf__XprivateX__BB54_324_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1514_F"))
		i20 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_391_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1515_F"))
		i23 =  (0)
		i20 = i17
		i17 = i23
		i23 = i19
		i19 = i26
		__asm(jump, target("___vfprintf__XprivateX__BB54_408_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1516_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_445_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1517_F"))
		i17 =  (1)
		i13 = i19
		__asm(jump, target("___vfprintf__XprivateX__BB54_529_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1518_F"))
		i17 =  (0)
		__asm(jump, target("___vfprintf__XprivateX__BB54_586_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1519_F"))
		i18 =  (3)
		__asm(jump, target("___vfprintf__XprivateX__BB54_599_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1520_F"))
		i18 =  (2)
		__asm(jump, target("___vfprintf__XprivateX__BB54_612_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1521_F"))
		i24 = i22
		i25 = i12
		__asm(jump, target("___vfprintf__XprivateX__BB54_619_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1522_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_743_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1523_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_759_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1524_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_787_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1525_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_796_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1526_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_818_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1527_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_846_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1528_F"))
		i7 = i1
		i1 = i17
		__asm(jump, target("___vfprintf__XprivateX__BB54_876_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1529_F"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_886_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1530_F"))
		i16 =  (0)
		i13 = i14
		i14 = i19
		i19 = i16
		__asm(jump, target("___vfprintf__XprivateX__BB54_942_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1531_F"))
		i8 =  (22)
		__asm(push(i8), push(_val_2E_1440), op(0x3c))
		i8 =  (-1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1041_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1532_F"))
		i8 =  (-1)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1041_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1533_F"))
		i8 =  (0)
		i10 =  ((__xasm<int>(push((mstate.ebp+-2358)), op(0x37))))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1056_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1534_F"))
		i17 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_1535_F"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1535_F"))
		i16 =  (i17 - i16)
		__asm(jump, target("___vfprintf__XprivateX__BB54_1072_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1536_F"))
		i7 = i20
		i16 = i17
		i17 = i22
		__asm(jump, target("___vfprintf__XprivateX__BB54_1149_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1537_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 115
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state115"))
		i1 = mstate.eax
		mstate.esp += 8
		i27 =  (0)
		__asm(push(i27), push(i4), op(0x3c))
		__asm(push(i27), push(i5), op(0x3c))
		__asm(push(i1==0), iftrue, target("___vfprintf__XprivateX__BB54_1262_B"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1538_F"))
		i1 =  ((mstate.ebp+-1744))
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 116
		mstate.esp -= 4;FSM___sfvwrite.start()
		return
	__asm(lbl("___vfprintf_state116"))
		i1 = mstate.eax
		mstate.esp += 8
		i12 =  (0)
		__asm(push(i12), push(i4), op(0x3c))
		__asm(push(i12), push(i5), op(0x3c))
		__asm(push(i1==0), iftrue, target("___vfprintf__XprivateX__BB54_1443_B"))
		__asm(jump, target("___vfprintf__XprivateX__BB54_1216_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1539_F"))
		i1 = i12
		i7 = i14
		i12 = i8
		__asm(jump, target("___vfprintf__XprivateX__BB54_1489_B"))
	__asm(lbl("___vfprintf__XprivateX__BB54_1540_F"))
		i0 = i2
		__asm(jump, target("___vfprintf__XprivateX__BB54_1501_B"))
	__asm(lbl("___vfprintf_errState"))
		throw("Invalid state in ___vfprintf")
	}
}



// Async
public const ___sflush:int = regFunc(FSM___sflush.start)

public final class FSM___sflush extends Machine {

	public static function start():void {
			var result:FSM___sflush = new FSM___sflush
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int

	public static const intRegCount:int = 7

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___sflush_entry"))
		__asm(push(state), switchjump(
			"___sflush_errState",
			"___sflush_state0",
			"___sflush_state1"))
	__asm(lbl("___sflush_state0"))
	__asm(lbl("___sflush__XprivateX__BB55_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((i0+12)), op(0x36), op(0x52))))
		i2 =  (i0 + 12)
		i3 =  (i1 & 8)
		__asm(push(i3==0), iftrue, target("___sflush__XprivateX__BB55_11_F"))
	__asm(lbl("___sflush__XprivateX__BB55_1_F"))
		i3 =  ((__xasm<int>(push((i0+16)), op(0x37))))
		__asm(push(i3==0), iftrue, target("___sflush__XprivateX__BB55_11_F"))
	__asm(lbl("___sflush__XprivateX__BB55_2_F"))
		i4 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i3), push(i0), op(0x3c))
		i5 =  (i0 + 8)
		i6 = i3
		i1 =  (i1 & 3)
		__asm(push(i1!=0), iftrue, target("___sflush__XprivateX__BB55_5_F"))
	__asm(lbl("___sflush__XprivateX__BB55_3_F"))
		i1 =  ((__xasm<int>(push((i0+20)), op(0x37))))
		__asm(push(i1), push(i5), op(0x3c))
		i4 =  (i4 - i6)
		__asm(push(i4<1), iftrue, target("___sflush__XprivateX__BB55_11_F"))
	__asm(lbl("___sflush__XprivateX__BB55_4_F"))
		i5 =  (0)
		__asm(jump, target("___sflush__XprivateX__BB55_7_F"))
	__asm(lbl("___sflush__XprivateX__BB55_5_F"))
		i1 =  (0)
		__asm(push(i1), push(i5), op(0x3c))
		i4 =  (i4 - i6)
		__asm(push(i4<1), iftrue, target("___sflush__XprivateX__BB55_11_F"))
	__asm(lbl("___sflush__XprivateX__BB55_6_F"))
		i5 =  (0)
	__asm(jump, target("___sflush__XprivateX__BB55_7_F"), lbl("___sflush__XprivateX__BB55_7_B"), label, lbl("___sflush__XprivateX__BB55_7_F")); 
		mstate.esp -= 12
		i1 =  (i3 + i5)
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		__asm(push(i4), push((mstate.esp+8)), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM__swrite.start()
		return
	__asm(lbl("___sflush_state1"))
		i1 = mstate.eax
		mstate.esp += 12
		__asm(push(i1>0), iftrue, target("___sflush__XprivateX__BB55_9_F"))
	__asm(lbl("___sflush__XprivateX__BB55_8_F"))
		i4 =  (-1)
		i5 =  ((__xasm<int>(push(i2), op(0x36))))
		i5 =  (i5 | 64)
		__asm(push(i5), push(i2), op(0x3b))
		mstate.eax = i4
		__asm(jump, target("___sflush__XprivateX__BB55_12_F"))
	__asm(lbl("___sflush__XprivateX__BB55_9_F"))
		i4 =  (i4 - i1)
		i5 =  (i5 + i1)
		__asm(push(i4<1), iftrue, target("___sflush__XprivateX__BB55_11_F"))
	__asm(lbl("___sflush__XprivateX__BB55_10_F"))
		__asm(jump, target("___sflush__XprivateX__BB55_7_B"))
	__asm(lbl("___sflush__XprivateX__BB55_11_F"))
		i0 =  (0)
		mstate.eax = i0
	__asm(lbl("___sflush__XprivateX__BB55_12_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___sflush_errState"))
		throw("Invalid state in ___sflush")
	}
}



// Async
public const ___sread:int = regFunc(FSM___sread.start)

public final class FSM___sread extends Machine {

	public static function start():void {
			var result:FSM___sread = new FSM___sread
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int

	public static const intRegCount:int = 3

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___sread_entry"))
		__asm(push(state), switchjump(
			"___sread_errState",
			"___sread_state0",
			"___sread_state1"))
	__asm(lbl("___sread_state0"))
	__asm(lbl("___sread__XprivateX__BB56_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i0 =  ((__xasm<int>(push((i0+14)), op(0x36), op(0x52))))
				state = 1
	__asm(lbl("___sread_state1"))
//InlineAsmStart
	i0 =  mstate.system.read(i0, i1, i2);//!!ASYNC

	//InlineAsmEnd
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___sread_errState"))
		throw("Invalid state in ___sread")
	}
}



// Async
public const ___swrite:int = regFunc(FSM___swrite.start)

public final class FSM___swrite extends Machine {

	public static function start():void {
			var result:FSM___swrite = new FSM___swrite
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int

	public static const intRegCount:int = 3

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___swrite_entry"))
		__asm(push(state), switchjump(
			"___swrite_errState",
			"___swrite_state0",
			"___swrite_state1"))
	__asm(lbl("___swrite_state0"))
	__asm(lbl("___swrite__XprivateX__BB57_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i0 =  ((__xasm<int>(push((i0+14)), op(0x36), op(0x52))))
				state = 1
	__asm(lbl("___swrite_state1"))
//InlineAsmStart
	i0 =  mstate.system.write(i0, i1, i2);//!!ASYNC

	//InlineAsmEnd
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___swrite_errState"))
		throw("Invalid state in ___swrite")
	}
}



// Async
public const ___sseek:int = regFunc(FSM___sseek.start)

public final class FSM___sseek extends Machine {

	public static function start():void {
			var result:FSM___sseek = new FSM___sseek
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int

	public static const intRegCount:int = 3

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___sseek_entry"))
		__asm(push(state), switchjump(
			"___sseek_errState",
			"___sseek_state0",
			"___sseek_state1"))
	__asm(lbl("___sseek_state0"))
	__asm(lbl("___sseek__XprivateX__BB58_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i0 =  ((__xasm<int>(push((i0+14)), op(0x36), op(0x52))))
				state = 1
	__asm(lbl("___sseek_state1"))
//InlineAsmStart
	i0 =  mstate.system.lseek(i0, i1, i2);//!!ASYNC

	//InlineAsmEnd
		i1 =  (i0 >> 31)
		mstate.edx = i1
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___sseek_errState"))
		throw("Invalid state in ___sseek")
	}
}



// Async
public const ___sclose:int = regFunc(FSM___sclose.start)

public final class FSM___sclose extends Machine {

	public static function start():void {
			var result:FSM___sclose = new FSM___sclose
		gstate.gworker = result
	}

	public var i0:int

	public static const intRegCount:int = 1

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___sclose_entry"))
		__asm(push(state), switchjump(
			"___sclose_errState",
			"___sclose_state0",
			"___sclose_state1"))
	__asm(lbl("___sclose_state0"))
	__asm(lbl("___sclose__XprivateX__BB59_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i0 =  ((__xasm<int>(push((i0+14)), op(0x36), op(0x52))))
				state = 1
	__asm(lbl("___sclose_state1"))
//InlineAsmStart
	i0 =  mstate.system.close(i0);//!!ASYNC

	//InlineAsmEnd
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___sclose_errState"))
		throw("Invalid state in ___sclose")
	}
}



// Async
public const __swrite:int = regFunc(FSM__swrite.start)

public final class FSM__swrite extends Machine {

	public static function start():void {
			var result:FSM__swrite = new FSM__swrite
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
	public var i8:int, i9:int, i10:int

	public static const intRegCount:int = 11

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("__swrite_entry"))
		__asm(push(state), switchjump(
			"__swrite_errState",
			"__swrite_state0",
			"__swrite_state1",
			"__swrite_state2"))
	__asm(lbl("__swrite_state0"))
	__asm(lbl("__swrite__XprivateX__BB60_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((i0+12)), op(0x36))))
		i2 =  (i0 + 12)
		i3 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i4 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i1 =  (i1 & 256)
		__asm(push(i1==0), iftrue, target("__swrite__XprivateX__BB60_5_F"))
	__asm(lbl("__swrite__XprivateX__BB60_1_F"))
		i1 =  (0)
		i5 =  ((__xasm<int>(push(_val_2E_1440), op(0x37))))
		mstate.esp -= 16
		i6 =  (2)
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		__asm(push(i1), push((mstate.esp+8)), op(0x3c))
		__asm(push(i6), push((mstate.esp+12)), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM__sseek.start()
		return
	__asm(lbl("__swrite_state1"))
		i1 = mstate.eax
		i6 = mstate.edx
		mstate.esp += 16
		i1 =  (i1 & i6)
		__asm(push(i1!=-1), iftrue, target("__swrite__XprivateX__BB60_4_F"))
	__asm(lbl("__swrite__XprivateX__BB60_2_F"))
		i1 =  ((__xasm<int>(push(i2), op(0x36))))
		i1 =  (i1 & 1024)
		__asm(push(i1==0), iftrue, target("__swrite__XprivateX__BB60_4_F"))
	__asm(lbl("__swrite__XprivateX__BB60_3_F"))
		i0 =  (-1)
		__asm(jump, target("__swrite__XprivateX__BB60_14_F"))
	__asm(lbl("__swrite__XprivateX__BB60_4_F"))
		__asm(push(i5), push(_val_2E_1440), op(0x3c))
	__asm(lbl("__swrite__XprivateX__BB60_5_F"))
		i1 =  ((__xasm<int>(push((i0+44)), op(0x37))))
		i5 =  ((__xasm<int>(push((i0+28)), op(0x37))))
		mstate.esp -= 12
		__asm(push(i5), push(mstate.esp), op(0x3c))
		__asm(push(i3), push((mstate.esp+4)), op(0x3c))
		__asm(push(i4), push((mstate.esp+8)), op(0x3c))
		state = 2
		mstate.esp -= 4;(mstate.funcs[i1])()
		return
	__asm(lbl("__swrite_state2"))
		i1 = mstate.eax
		mstate.esp += 12
		__asm(push(i1<0), iftrue, target("__swrite__XprivateX__BB60_12_F"))
	__asm(lbl("__swrite__XprivateX__BB60_6_F"))
		i3 =  ((__xasm<int>(push(i2), op(0x36))))
		i4 =  (i3 & 4352)
		__asm(push(i4!=4352), iftrue, target("__swrite__XprivateX__BB60_9_F"))
	__asm(lbl("__swrite__XprivateX__BB60_7_F"))
		i4 =  (2147483647)
		i5 =  ((__xasm<int>(push((i0+80)), op(0x37))))
		i6 =  ((__xasm<int>(push((i0+84)), op(0x37))))
		i7 =  (i1 >> 31)
		i8 =  (-1)
		i8 =  __subc(i8, i1)
		i4 =  __sube(i4, i7)
		i0 =  (i0 + 80)
		i9 =  ((i6>i4) ? 1 : 0)
		i8 =  ((uint(i5)>uint(i8)) ? 1 : 0)
		i4 =  ((i6==i4) ? 1 : 0)
		i10 = i1
		i4 =  ((i4!=0) ? i8 : i9)
		__asm(push(i4!=0), iftrue, target("__swrite__XprivateX__BB60_9_F"))
	__asm(lbl("__swrite__XprivateX__BB60_8_F"))
		i2 =  __addc(i5, i10)
		i3 =  __adde(i6, i7)
		__asm(push(i2), push(i0), op(0x3c))
		__asm(push(i3), push((i0+4)), op(0x3c))
		__asm(jump, target("__swrite__XprivateX__BB60_11_F"))
	__asm(lbl("__swrite__XprivateX__BB60_9_F"))
		i0 =  (i3 & -4097)
	__asm(jump, target("__swrite__XprivateX__BB60_10_F"), lbl("__swrite__XprivateX__BB60_10_B"), label, lbl("__swrite__XprivateX__BB60_10_F")); 
		__asm(push(i0), push(i2), op(0x3b))
	__asm(lbl("__swrite__XprivateX__BB60_11_F"))
		mstate.eax = i1
		__asm(jump, target("__swrite__XprivateX__BB60_15_F"))
	__asm(lbl("__swrite__XprivateX__BB60_12_F"))
		__asm(push(i1<0), iftrue, target("__swrite__XprivateX__BB60_16_F"))
	__asm(lbl("__swrite__XprivateX__BB60_13_F"))
		i0 = i1
		__asm(jump, target("__swrite__XprivateX__BB60_14_F"))
	__asm(lbl("__swrite__XprivateX__BB60_14_F"))
		mstate.eax = i0
	__asm(lbl("__swrite__XprivateX__BB60_15_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("__swrite__XprivateX__BB60_16_F"))
		i0 =  ((__xasm<int>(push(i2), op(0x36))))
		i0 =  (i0 & -4097)
		__asm(jump, target("__swrite__XprivateX__BB60_10_B"))
	__asm(lbl("__swrite_errState"))
		throw("Invalid state in __swrite")
	}
}



// Async
public const ___fflush:int = regFunc(FSM___fflush.start)

public final class FSM___fflush extends Machine {

	public static function start():void {
			var result:FSM___fflush = new FSM___fflush
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int

	public static const intRegCount:int = 6

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___fflush_entry"))
		__asm(push(state), switchjump(
			"___fflush_errState",
			"___fflush_state0",
			"___fflush_state1",
			"___fflush_state2"))
	__asm(lbl("___fflush_state0"))
	__asm(lbl("___fflush__XprivateX__BB61_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		__asm(push(i0!=0), iftrue, target("___fflush__XprivateX__BB61_14_F"))
	__asm(lbl("___fflush__XprivateX__BB61_1_F"))
		i0 =  (___sglue)
		i1 =  (0)
	__asm(jump, target("___fflush__XprivateX__BB61_2_F"), lbl("___fflush__XprivateX__BB61_2_B"), label, lbl("___fflush__XprivateX__BB61_2_F")); 
		i2 =  ((__xasm<int>(push((i0+4)), op(0x37))))
		i3 =  ((__xasm<int>(push((i0+8)), op(0x37))))
		i4 =  (i2 + -1)
		__asm(push(i4>-1), iftrue, target("___fflush__XprivateX__BB61_4_F"))
	__asm(lbl("___fflush__XprivateX__BB61_3_F"))
		__asm(jump, target("___fflush__XprivateX__BB61_10_F"))
	__asm(lbl("___fflush__XprivateX__BB61_4_F"))
		i2 =  (i2 + -1)
	__asm(jump, target("___fflush__XprivateX__BB61_5_F"), lbl("___fflush__XprivateX__BB61_5_B"), label, lbl("___fflush__XprivateX__BB61_5_F")); 
		i4 =  ((__xasm<int>(push((i3+12)), op(0x36))))
		i4 =  (i4 << 16)
		i4 =  (i4 >> 16)
		i5 = i3
		__asm(push(i4>0), iftrue, target("___fflush__XprivateX__BB61_7_F"))
	__asm(lbl("___fflush__XprivateX__BB61_6_F"))
		__asm(jump, target("___fflush__XprivateX__BB61_8_F"))
	__asm(lbl("___fflush__XprivateX__BB61_7_F"))
		mstate.esp -= 4
		__asm(push(i5), push(mstate.esp), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM___sflush.start()
		return
	__asm(lbl("___fflush_state1"))
		i4 = mstate.eax
		mstate.esp += 4
		i1 =  (i4 | i1)
	__asm(lbl("___fflush__XprivateX__BB61_8_F"))
		i3 =  (i3 + 88)
		i2 =  (i2 + -1)
		__asm(push(i2>-1), iftrue, target("___fflush__XprivateX__BB61_18_F"))
	__asm(lbl("___fflush__XprivateX__BB61_9_F"))
		__asm(jump, target("___fflush__XprivateX__BB61_10_F"))
	__asm(lbl("___fflush__XprivateX__BB61_10_F"))
		i0 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i0==0), iftrue, target("___fflush__XprivateX__BB61_12_F"))
	__asm(lbl("___fflush__XprivateX__BB61_11_F"))
		__asm(jump, target("___fflush__XprivateX__BB61_2_B"))
	__asm(lbl("___fflush__XprivateX__BB61_12_F"))
		mstate.eax = i1
	__asm(jump, target("___fflush__XprivateX__BB61_13_F"), lbl("___fflush__XprivateX__BB61_13_B"), label, lbl("___fflush__XprivateX__BB61_13_F")); 
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___fflush__XprivateX__BB61_14_F"))
		i1 =  ((__xasm<int>(push((i0+12)), op(0x36))))
		i1 =  (i1 & 24)
		__asm(push(i1!=0), iftrue, target("___fflush__XprivateX__BB61_17_F"))
	__asm(lbl("___fflush__XprivateX__BB61_15_F"))
		i0 =  (9)
		__asm(push(i0), push(_val_2E_1440), op(0x3c))
		i0 =  (-1)
	__asm(jump, target("___fflush__XprivateX__BB61_16_F"), lbl("___fflush__XprivateX__BB61_16_B"), label, lbl("___fflush__XprivateX__BB61_16_F")); 
		mstate.eax = i0
		__asm(jump, target("___fflush__XprivateX__BB61_13_B"))
	__asm(lbl("___fflush__XprivateX__BB61_17_F"))
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 2
		mstate.esp -= 4;FSM___sflush.start()
		return
	__asm(lbl("___fflush_state2"))
		i0 = mstate.eax
		mstate.esp += 4
		__asm(jump, target("___fflush__XprivateX__BB61_16_B"))
	__asm(lbl("___fflush__XprivateX__BB61_18_F"))
		__asm(jump, target("___fflush__XprivateX__BB61_5_B"))
	__asm(lbl("___fflush_errState"))
		throw("Invalid state in ___fflush")
	}
}



// Async
public const __cleanup:int = regFunc(FSM__cleanup.start)

public final class FSM__cleanup extends Machine {

	public static function start():void {
			var result:FSM__cleanup = new FSM__cleanup
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int

	public static const intRegCount:int = 6

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("__cleanup_entry"))
		__asm(push(state), switchjump(
			"__cleanup_errState",
			"__cleanup_state0",
			"__cleanup_state1"))
	__asm(lbl("__cleanup_state0"))
	__asm(lbl("__cleanup__XprivateX__BB62_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  (___sglue)
		i1 =  (0)
	__asm(jump, target("__cleanup__XprivateX__BB62_1_F"), lbl("__cleanup__XprivateX__BB62_1_B"), label, lbl("__cleanup__XprivateX__BB62_1_F")); 
		i2 =  ((__xasm<int>(push((i0+4)), op(0x37))))
		i3 =  ((__xasm<int>(push((i0+8)), op(0x37))))
		i4 =  (i2 + -1)
		__asm(push(i4>-1), iftrue, target("__cleanup__XprivateX__BB62_3_F"))
	__asm(lbl("__cleanup__XprivateX__BB62_2_F"))
		__asm(jump, target("__cleanup__XprivateX__BB62_9_F"))
	__asm(lbl("__cleanup__XprivateX__BB62_3_F"))
		i2 =  (i2 + -1)
	__asm(jump, target("__cleanup__XprivateX__BB62_4_F"), lbl("__cleanup__XprivateX__BB62_4_B"), label, lbl("__cleanup__XprivateX__BB62_4_F")); 
		i4 =  ((__xasm<int>(push((i3+12)), op(0x36))))
		i4 =  (i4 << 16)
		i4 =  (i4 >> 16)
		i5 = i3
		__asm(push(i4>0), iftrue, target("__cleanup__XprivateX__BB62_6_F"))
	__asm(lbl("__cleanup__XprivateX__BB62_5_F"))
		__asm(jump, target("__cleanup__XprivateX__BB62_7_F"))
	__asm(lbl("__cleanup__XprivateX__BB62_6_F"))
		mstate.esp -= 4
		__asm(push(i5), push(mstate.esp), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM___sflush.start()
		return
	__asm(lbl("__cleanup_state1"))
		i4 = mstate.eax
		mstate.esp += 4
		i1 =  (i4 | i1)
	__asm(lbl("__cleanup__XprivateX__BB62_7_F"))
		i3 =  (i3 + 88)
		i2 =  (i2 + -1)
		__asm(push(i2>-1), iftrue, target("__cleanup__XprivateX__BB62_12_F"))
	__asm(lbl("__cleanup__XprivateX__BB62_8_F"))
		__asm(jump, target("__cleanup__XprivateX__BB62_9_F"))
	__asm(lbl("__cleanup__XprivateX__BB62_9_F"))
		i0 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i0==0), iftrue, target("__cleanup__XprivateX__BB62_11_F"))
	__asm(lbl("__cleanup__XprivateX__BB62_10_F"))
		__asm(jump, target("__cleanup__XprivateX__BB62_1_B"))
	__asm(lbl("__cleanup__XprivateX__BB62_11_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("__cleanup__XprivateX__BB62_12_F"))
		__asm(jump, target("__cleanup__XprivateX__BB62_4_B"))
	__asm(lbl("__cleanup_errState"))
		throw("Invalid state in __cleanup")
	}
}



// Async
public const __sseek:int = regFunc(FSM__sseek.start)

public final class FSM__sseek extends Machine {

	public static function start():void {
			var result:FSM__sseek = new FSM__sseek
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int

	public static const intRegCount:int = 8

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("__sseek_entry"))
		__asm(push(state), switchjump(
			"__sseek_errState",
			"__sseek_state0",
			"__sseek_state1",
			"__sseek_state2"))
	__asm(lbl("__sseek_state0"))
	__asm(lbl("__sseek__XprivateX__BB63_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  (0)
		i1 =  ((__xasm<int>(push(_val_2E_1440), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		__asm(push(i0), push(_val_2E_1440), op(0x3c))
		i0 =  ((__xasm<int>(push((i2+40)), op(0x37))))
		i3 =  ((__xasm<int>(push((i2+28)), op(0x37))))
		mstate.esp -= 16
		i4 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i5 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i6 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		__asm(push(i3), push(mstate.esp), op(0x3c))
		__asm(push(i5), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		__asm(push(i4), push((mstate.esp+12)), op(0x3c))
		state = 1
		mstate.esp -= 4;(mstate.funcs[i0])()
		return
	__asm(lbl("__sseek_state1"))
		i0 = mstate.eax
		i3 = mstate.edx
		mstate.esp += 16
		i7 =  ((__xasm<int>(push(_val_2E_1440), op(0x37))))
		__asm(push(i7!=0), iftrue, target("__sseek__XprivateX__BB63_2_F"))
	__asm(lbl("__sseek__XprivateX__BB63_1_F"))
		__asm(push(i1), push(_val_2E_1440), op(0x3c))
	__asm(lbl("__sseek__XprivateX__BB63_2_F"))
		i1 =  (i2 + 12)
		__asm(push(i3>-1), iftrue, target("__sseek__XprivateX__BB63_18_F"))
	__asm(lbl("__sseek__XprivateX__BB63_3_F"))
		__asm(push(i7==29), iftrue, target("__sseek__XprivateX__BB63_13_F"))
	__asm(lbl("__sseek__XprivateX__BB63_4_F"))
		__asm(push(i7!=0), iftrue, target("__sseek__XprivateX__BB63_17_F"))
	__asm(lbl("__sseek__XprivateX__BB63_5_F"))
		__asm(push(i4!=1), iftrue, target("__sseek__XprivateX__BB63_7_F"))
	__asm(lbl("__sseek__XprivateX__BB63_6_F"))
		i0 =  (i5 | i6)
		__asm(push(i0==0), iftrue, target("__sseek__XprivateX__BB63_12_F"))
	__asm(lbl("__sseek__XprivateX__BB63_7_F"))
		i0 =  ((__xasm<int>(push((i2+48)), op(0x37))))
		i3 =  (i2 + 48)
		__asm(push(i0==0), iftrue, target("__sseek__XprivateX__BB63_11_F"))
	__asm(lbl("__sseek__XprivateX__BB63_8_F"))
		i4 =  (i2 + 64)
		__asm(push(i0==i4), iftrue, target("__sseek__XprivateX__BB63_10_F"))
	__asm(lbl("__sseek__XprivateX__BB63_9_F"))
		i4 =  (0)
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i4), push((mstate.esp+4)), op(0x3c))
		state = 2
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("__sseek_state2"))
		i0 = mstate.eax
		mstate.esp += 8
	__asm(lbl("__sseek__XprivateX__BB63_10_F"))
		i0 =  (0)
		__asm(push(i0), push(i3), op(0x3c))
	__asm(lbl("__sseek__XprivateX__BB63_11_F"))
		i0 =  (0)
		i3 =  ((__xasm<int>(push((i2+16)), op(0x37))))
		__asm(push(i3), push(i2), op(0x3c))
		__asm(push(i0), push((i2+4)), op(0x3c))
		i0 =  ((__xasm<int>(push(i1), op(0x36))))
		i0 =  (i0 & -33)
		__asm(push(i0), push(i1), op(0x3b))
	__asm(lbl("__sseek__XprivateX__BB63_12_F"))
		i0 =  (22)
		i2 =  ((__xasm<int>(push(i1), op(0x36))))
		i2 =  (i2 | 64)
		__asm(push(i2), push(i1), op(0x3b))
		__asm(push(i0), push(_val_2E_1440), op(0x3c))
		i0 =  ((__xasm<int>(push(i1), op(0x36))))
		i0 =  (i0 & -4097)
		__asm(push(i0), push(i1), op(0x3b))
		i0 =  (-1)
		__asm(jump, target("__sseek__XprivateX__BB63_15_F"))
	__asm(lbl("__sseek__XprivateX__BB63_13_F"))
		i0 =  (-1)
		i2 =  ((__xasm<int>(push(i1), op(0x36))))
		i2 =  (i2 & -4353)
	__asm(jump, target("__sseek__XprivateX__BB63_14_F"), lbl("__sseek__XprivateX__BB63_14_B"), label, lbl("__sseek__XprivateX__BB63_14_F")); 
		__asm(push(i2), push(i1), op(0x3b))
	__asm(lbl("__sseek__XprivateX__BB63_15_F"))
		mstate.edx = i0
	__asm(jump, target("__sseek__XprivateX__BB63_16_F"), lbl("__sseek__XprivateX__BB63_16_B"), label, lbl("__sseek__XprivateX__BB63_16_F")); 
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("__sseek__XprivateX__BB63_17_F"))
		i0 =  (-1)
		i2 =  ((__xasm<int>(push(i1), op(0x36))))
		i2 =  (i2 & -4097)
		__asm(jump, target("__sseek__XprivateX__BB63_14_B"))
	__asm(lbl("__sseek__XprivateX__BB63_18_F"))
		i4 =  ((__xasm<int>(push(i1), op(0x36))))
		i5 =  (i4 & 1024)
		__asm(push(i5==0), iftrue, target("__sseek__XprivateX__BB63_20_F"))
	__asm(lbl("__sseek__XprivateX__BB63_19_F"))
		i4 =  (i4 | 4096)
		__asm(push(i4), push(i1), op(0x3b))
		__asm(push(i0), push((i2+80)), op(0x3c))
		__asm(push(i3), push((i2+84)), op(0x3c))
	__asm(lbl("__sseek__XprivateX__BB63_20_F"))
		mstate.edx = i3
		__asm(jump, target("__sseek__XprivateX__BB63_16_B"))
	__asm(lbl("__sseek_errState"))
		throw("Invalid state in __sseek")
	}
}



// Async
public const ___sfvwrite:int = regFunc(FSM___sfvwrite.start)

public final class FSM___sfvwrite extends Machine {

	public static function start():void {
			var result:FSM___sfvwrite = new FSM___sfvwrite
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
	public var i8:int, i9:int, i10:int, i11:int, i12:int, i13:int, i14:int, i15:int
	public var i16:int, i17:int, i18:int, i19:int

	public static const intRegCount:int = 20

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___sfvwrite_entry"))
		__asm(push(state), switchjump(
			"___sfvwrite_errState",
			"___sfvwrite_state0",
			"___sfvwrite_state1",
			"___sfvwrite_state2",
			"___sfvwrite_state3",
			"___sfvwrite_state4",
			"___sfvwrite_state5",
			"___sfvwrite_state6",
			"___sfvwrite_state7",
			"___sfvwrite_state8",
			"___sfvwrite_state9"))
	__asm(lbl("___sfvwrite_state0"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i2 =  ((__xasm<int>(push((i0+8)), op(0x37))))
		i3 =  (i0 + 8)
		__asm(push(i2!=0), iftrue, target("___sfvwrite__XprivateX__BB64_2_F"))
	__asm(jump, target("___sfvwrite__XprivateX__BB64_1_F"), lbl("___sfvwrite__XprivateX__BB64_1_B"), label, lbl("___sfvwrite__XprivateX__BB64_1_F")); 
		i0 =  (0)
		__asm(jump, target("___sfvwrite__XprivateX__BB64_72_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_2_F"))
		i2 =  ((__xasm<int>(push((i1+12)), op(0x36))))
		i4 =  (i1 + 12)
		i5 =  (i2 & 8)
		__asm(push(i5==0), iftrue, target("___sfvwrite__XprivateX__BB64_5_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_3_F"))
		i5 =  ((__xasm<int>(push((i1+16)), op(0x37))))
		__asm(push(i5!=0), iftrue, target("___sfvwrite__XprivateX__BB64_7_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_4_F"))
		i2 =  (i2 & 512)
		__asm(push(i2!=0), iftrue, target("___sfvwrite__XprivateX__BB64_7_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_5_F"))
		mstate.esp -= 4
		__asm(push(i1), push(mstate.esp), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM___swsetup.start()
		return
	__asm(lbl("___sfvwrite_state1"))
		i2 = mstate.eax
		mstate.esp += 4
		__asm(push(i2==0), iftrue, target("___sfvwrite__XprivateX__BB64_7_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_6_F"))
		i0 =  (-1)
		__asm(jump, target("___sfvwrite__XprivateX__BB64_72_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_7_F"))
		i0 =  ((__xasm<int>(push(i0), op(0x37))))
		i2 =  ((__xasm<int>(push(i4), op(0x36))))
		i5 =  ((__xasm<int>(push(i0), op(0x37))))
		i6 =  ((__xasm<int>(push((i0+4)), op(0x37))))
		i7 =  (i2 & 2)
		__asm(push(i7==0), iftrue, target("___sfvwrite__XprivateX__BB64_15_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_8_F"))
		i2 = i5
		i5 = i6
		__asm(jump, target("___sfvwrite__XprivateX__BB64_10_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_9_B"), label)
		i2 =  ((__xasm<int>(push((i0+8)), op(0x37))))
		i5 =  ((__xasm<int>(push((i0+12)), op(0x37))))
		i0 =  (i0 + 8)
	__asm(lbl("___sfvwrite__XprivateX__BB64_10_F"))
		i6 =  (0)
	__asm(jump, target("___sfvwrite__XprivateX__BB64_11_F"), lbl("___sfvwrite__XprivateX__BB64_11_B"), label, lbl("___sfvwrite__XprivateX__BB64_11_F")); 
		__asm(push(i5==0), iftrue, target("___sfvwrite__XprivateX__BB64_9_B"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_12_F"))
		mstate.esp -= 12
		i7 =  ((uint(i5)<uint(1025)) ? i5 : 1024)
		i8 =  (i2 + i6)
		__asm(push(i1), push(mstate.esp), op(0x3c))
		__asm(push(i8), push((mstate.esp+4)), op(0x3c))
		__asm(push(i7), push((mstate.esp+8)), op(0x3c))
		state = 2
		mstate.esp -= 4;FSM__swrite.start()
		return
	__asm(lbl("___sfvwrite_state2"))
		i7 = mstate.eax
		mstate.esp += 12
		__asm(push(i7<1), iftrue, target("___sfvwrite__XprivateX__BB64_71_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_13_F"))
		i8 =  ((__xasm<int>(push(i3), op(0x37))))
		i9 =  (i8 - i7)
		__asm(push(i9), push(i3), op(0x3c))
		i5 =  (i5 - i7)
		i6 =  (i6 + i7)
		__asm(push(i8==i7), iftrue, target("___sfvwrite__XprivateX__BB64_1_B"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_14_F"))
		__asm(jump, target("___sfvwrite__XprivateX__BB64_11_B"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_15_F"))
		i7 =  (i1 + 8)
		i2 =  (i2 & 1)
		__asm(push(i2==0), iftrue, target("___sfvwrite__XprivateX__BB64_17_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_16_F"))
		i2 =  (0)
		i8 =  (i1 + 20)
		i9 =  (i1 + 16)
		i10 = i1
		__asm(jump, target("___sfvwrite__XprivateX__BB64_43_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_17_F"))
		i2 =  (i1 + 20)
		i8 =  (i1 + 16)
		i9 = i1
		__asm(jump, target("___sfvwrite__XprivateX__BB64_19_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_18_B"), label)
		i5 =  ((__xasm<int>(push((i0+8)), op(0x37))))
		i6 =  ((__xasm<int>(push((i0+12)), op(0x37))))
		i0 =  (i0 + 8)
	__asm(lbl("___sfvwrite__XprivateX__BB64_19_F"))
		i10 =  (0)
	__asm(jump, target("___sfvwrite__XprivateX__BB64_20_F"), lbl("___sfvwrite__XprivateX__BB64_20_B"), label, lbl("___sfvwrite__XprivateX__BB64_20_F")); 
		i11 =  (i5 + i10)
		__asm(push(i6==0), iftrue, target("___sfvwrite__XprivateX__BB64_18_B"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_21_F"))
		i12 =  ((__xasm<int>(push(i4), op(0x36))))
		i12 =  (i12 & 16896)
		__asm(push(i12!=16896), iftrue, target("___sfvwrite__XprivateX__BB64_28_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_22_F"))
		i12 =  ((__xasm<int>(push(i7), op(0x37))))
		__asm(push(uint(i12)>=uint(i6)), iftrue, target("___sfvwrite__XprivateX__BB64_28_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_23_F"))
		i12 =  ((__xasm<int>(push(i9), op(0x37))))
		i13 =  ((__xasm<int>(push(i8), op(0x37))))
		i14 =  (i6 + 128)
		i12 =  (i12 - i13)
		i15 =  (i14 + i12)
		__asm(push(i14), push(i7), op(0x3c))
		__asm(push(i15), push(i2), op(0x3c))
		mstate.esp -= 8
		i14 =  (i15 + 1)
		__asm(push(i13), push(mstate.esp), op(0x3c))
		__asm(push(i14), push((mstate.esp+4)), op(0x3c))
		state = 3
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___sfvwrite_state3"))
		i14 = mstate.eax
		mstate.esp += 8
		__asm(push(i14!=0), iftrue, target("___sfvwrite__XprivateX__BB64_26_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_24_F"))
		__asm(push(i13==0), iftrue, target("___sfvwrite__XprivateX__BB64_26_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_25_F"))
		mstate.esp -= 4
		__asm(push(i13), push(mstate.esp), op(0x3c))
		state = 4
		mstate.esp -= 4;FSM_free.start()
		return
	__asm(lbl("___sfvwrite_state4"))
		mstate.esp += 4
	__asm(lbl("___sfvwrite__XprivateX__BB64_26_F"))
		__asm(push(i14), push(i8), op(0x3c))
		__asm(push(i14==0), iftrue, target("___sfvwrite__XprivateX__BB64_71_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_27_F"))
		i12 =  (i14 + i12)
		__asm(push(i12), push(i9), op(0x3c))
	__asm(lbl("___sfvwrite__XprivateX__BB64_28_F"))
		i12 =  ((__xasm<int>(push(i4), op(0x36))))
		i13 =  ((__xasm<int>(push(i7), op(0x37))))
		i12 =  (i12 & 512)
		__asm(push(i12==0), iftrue, target("___sfvwrite__XprivateX__BB64_32_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_29_F"))
		i13 =  ((uint(i13)>uint(i6)) ? i6 : i13)
		__asm(push(i13>0), iftrue, target("___sfvwrite__XprivateX__BB64_31_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_30_F"))
		i13 = i6
		__asm(jump, target("___sfvwrite__XprivateX__BB64_40_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_31_F"))
		i12 =  ((__xasm<int>(push(i9), op(0x37))))
		i14 = i13
		memcpy(i12, i11, i14)
		i11 =  ((__xasm<int>(push(i7), op(0x37))))
		i11 =  (i11 - i13)
		__asm(push(i11), push(i7), op(0x3c))
		i11 =  ((__xasm<int>(push(i9), op(0x37))))
		i13 =  (i11 + i13)
		__asm(push(i13), push(i9), op(0x3c))
		i13 = i6
		__asm(jump, target("___sfvwrite__XprivateX__BB64_40_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_32_F"))
		i12 =  ((__xasm<int>(push(i9), op(0x37))))
		i14 =  ((__xasm<int>(push(i8), op(0x37))))
		__asm(push(uint(i12)<=uint(i14)), iftrue, target("___sfvwrite__XprivateX__BB64_36_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_33_F"))
		__asm(push(uint(i13)>=uint(i6)), iftrue, target("___sfvwrite__XprivateX__BB64_36_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_34_F"))
		i14 = i13
		memcpy(i12, i11, i14)
		i11 =  ((__xasm<int>(push(i9), op(0x37))))
		i11 =  (i11 + i13)
		__asm(push(i11), push(i9), op(0x3c))
		mstate.esp -= 4
		__asm(push(i1), push(mstate.esp), op(0x3c))
		state = 5
		mstate.esp -= 4;FSM___fflush.start()
		return
	__asm(lbl("___sfvwrite_state5"))
		i11 = mstate.eax
		mstate.esp += 4
		__asm(push(i11!=0), iftrue, target("___sfvwrite__XprivateX__BB64_71_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_35_F"))
		__asm(jump, target("___sfvwrite__XprivateX__BB64_40_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_36_F"))
		i13 =  ((__xasm<int>(push(i2), op(0x37))))
		__asm(push(uint(i13)>uint(i6)), iftrue, target("___sfvwrite__XprivateX__BB64_39_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_37_F"))
		mstate.esp -= 12
		__asm(push(i1), push(mstate.esp), op(0x3c))
		__asm(push(i11), push((mstate.esp+4)), op(0x3c))
		__asm(push(i13), push((mstate.esp+8)), op(0x3c))
		state = 6
		mstate.esp -= 4;FSM__swrite.start()
		return
	__asm(lbl("___sfvwrite_state6"))
		i11 = mstate.eax
		mstate.esp += 12
		__asm(push(i11<1), iftrue, target("___sfvwrite__XprivateX__BB64_71_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_38_F"))
		i13 = i11
		__asm(jump, target("___sfvwrite__XprivateX__BB64_40_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_39_F"))
		i13 = i12
		i12 = i6
		memcpy(i13, i11, i12)
		i13 =  ((__xasm<int>(push(i7), op(0x37))))
		i13 =  (i13 - i6)
		__asm(push(i13), push(i7), op(0x3c))
		i13 =  ((__xasm<int>(push(i9), op(0x37))))
		i13 =  (i13 + i6)
		__asm(push(i13), push(i9), op(0x3c))
		i13 = i6
	__asm(lbl("___sfvwrite__XprivateX__BB64_40_F"))
		i11 = i13
		i12 =  ((__xasm<int>(push(i3), op(0x37))))
		i13 =  (i12 - i11)
		__asm(push(i13), push(i3), op(0x3c))
		i6 =  (i6 - i11)
		i10 =  (i10 + i11)
		__asm(push(i12==i11), iftrue, target("___sfvwrite__XprivateX__BB64_1_B"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_41_F"))
		__asm(jump, target("___sfvwrite__XprivateX__BB64_20_B"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_42_B"), label)
		i5 =  ((__xasm<int>(push((i0+8)), op(0x37))))
		i6 =  ((__xasm<int>(push((i0+12)), op(0x37))))
		i0 =  (i0 + 8)
	__asm(lbl("___sfvwrite__XprivateX__BB64_43_F"))
		i11 =  (0)
		i12 = i5
		i13 = i11
	__asm(jump, target("___sfvwrite__XprivateX__BB64_44_F"), lbl("___sfvwrite__XprivateX__BB64_44_B"), label, lbl("___sfvwrite__XprivateX__BB64_44_F")); 
		i14 =  (i5 + i13)
		__asm(push(i6==0), iftrue, target("___sfvwrite__XprivateX__BB64_42_B"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_45_F"))
		__asm(push(i11==0), iftrue, target("___sfvwrite__XprivateX__BB64_47_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_46_F"))
		__asm(jump, target("___sfvwrite__XprivateX__BB64_57_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_47_F"))
		__asm(push(i6!=0), iftrue, target("___sfvwrite__XprivateX__BB64_51_F"))
	__asm(jump, target("___sfvwrite__XprivateX__BB64_48_F"), lbl("___sfvwrite__XprivateX__BB64_48_B"), label, lbl("___sfvwrite__XprivateX__BB64_48_F")); 
		i2 =  (0)
		__asm(jump, target("___sfvwrite__XprivateX__BB64_49_F"))
	__asm(jump, target("___sfvwrite__XprivateX__BB64_49_F"), lbl("___sfvwrite__XprivateX__BB64_49_B"), label, lbl("___sfvwrite__XprivateX__BB64_49_F")); 
		__asm(push(i2==0), iftrue, target("___sfvwrite__XprivateX__BB64_56_F"))
		__asm(jump, target("___sfvwrite__XprivateX__BB64_50_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_50_F"))
		i11 =  (1)
		i2 =  (i2 + 1)
		i2 =  (i2 - i14)
		__asm(jump, target("___sfvwrite__XprivateX__BB64_57_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_51_F"))
		i2 =  (i6 + 1)
		i11 =  (i13 + i12)
	__asm(jump, target("___sfvwrite__XprivateX__BB64_52_F"), lbl("___sfvwrite__XprivateX__BB64_52_B"), label, lbl("___sfvwrite__XprivateX__BB64_52_F")); 
		i15 =  ((__xasm<int>(push(i11), op(0x35))))
		i16 = i11
		__asm(push(i15!=10), iftrue, target("___sfvwrite__XprivateX__BB64_54_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_53_F"))
		i2 = i16
		__asm(jump, target("___sfvwrite__XprivateX__BB64_49_B"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_54_F"))
		i2 =  (i2 + -1)
		i11 =  (i11 + 1)
		__asm(push(i2==1), iftrue, target("___sfvwrite__XprivateX__BB64_48_B"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_55_F"))
		__asm(jump, target("___sfvwrite__XprivateX__BB64_52_B"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_56_F"))
		i2 =  (1)
		i15 =  (i6 + 1)
		i11 = i2
		i2 = i15
	__asm(lbl("___sfvwrite__XprivateX__BB64_57_F"))
		i15 =  ((__xasm<int>(push(i7), op(0x37))))
		i16 =  ((__xasm<int>(push(i8), op(0x37))))
		i17 =  ((__xasm<int>(push(i10), op(0x37))))
		i18 =  ((__xasm<int>(push(i9), op(0x37))))
		i19 =  ((uint(i2)<=uint(i6)) ? i2 : i6)
		i15 =  (i16 + i15)
		__asm(push(uint(i17)<=uint(i18)), iftrue, target("___sfvwrite__XprivateX__BB64_61_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_58_F"))
		__asm(push(i19<=i15), iftrue, target("___sfvwrite__XprivateX__BB64_61_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_59_F"))
		i16 = i17
		i17 = i15
		memcpy(i16, i14, i17)
		i14 =  ((__xasm<int>(push(i10), op(0x37))))
		i14 =  (i14 + i15)
		__asm(push(i14), push(i10), op(0x3c))
		mstate.esp -= 4
		__asm(push(i1), push(mstate.esp), op(0x3c))
		state = 7
		mstate.esp -= 4;FSM___fflush.start()
		return
	__asm(lbl("___sfvwrite_state7"))
		i14 = mstate.eax
		mstate.esp += 4
		__asm(push(i14!=0), iftrue, target("___sfvwrite__XprivateX__BB64_71_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_60_F"))
		i14 = i15
		__asm(jump, target("___sfvwrite__XprivateX__BB64_65_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_61_F"))
		__asm(push(i16>i19), iftrue, target("___sfvwrite__XprivateX__BB64_64_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_62_F"))
		mstate.esp -= 12
		__asm(push(i1), push(mstate.esp), op(0x3c))
		__asm(push(i14), push((mstate.esp+4)), op(0x3c))
		__asm(push(i16), push((mstate.esp+8)), op(0x3c))
		state = 8
		mstate.esp -= 4;FSM__swrite.start()
		return
	__asm(lbl("___sfvwrite_state8"))
		i14 = mstate.eax
		mstate.esp += 12
		__asm(push(i14<1), iftrue, target("___sfvwrite__XprivateX__BB64_71_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_63_F"))
		__asm(jump, target("___sfvwrite__XprivateX__BB64_65_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_64_F"))
		i15 = i17
		i16 = i19
		memcpy(i15, i14, i16)
		i14 =  ((__xasm<int>(push(i7), op(0x37))))
		i14 =  (i14 - i19)
		__asm(push(i14), push(i7), op(0x3c))
		i14 =  ((__xasm<int>(push(i10), op(0x37))))
		i14 =  (i14 + i19)
		__asm(push(i14), push(i10), op(0x3c))
		i14 = i19
	__asm(lbl("___sfvwrite__XprivateX__BB64_65_F"))
		i15 =  (i2 - i14)
		__asm(push(i2==i14), iftrue, target("___sfvwrite__XprivateX__BB64_67_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_66_F"))
		i2 = i11
		__asm(jump, target("___sfvwrite__XprivateX__BB64_69_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_67_F"))
		mstate.esp -= 4
		__asm(push(i1), push(mstate.esp), op(0x3c))
		state = 9
		mstate.esp -= 4;FSM___fflush.start()
		return
	__asm(lbl("___sfvwrite_state9"))
		i2 = mstate.eax
		mstate.esp += 4
		__asm(push(i2!=0), iftrue, target("___sfvwrite__XprivateX__BB64_71_F"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_68_F"))
		i2 =  (0)
	__asm(lbl("___sfvwrite__XprivateX__BB64_69_F"))
		i11 =  ((__xasm<int>(push(i3), op(0x37))))
		i16 =  (i11 - i14)
		__asm(push(i16), push(i3), op(0x3c))
		i6 =  (i6 - i14)
		i13 =  (i13 + i14)
		__asm(push(i11==i14), iftrue, target("___sfvwrite__XprivateX__BB64_1_B"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_70_F"))
		i11 = i2
		i2 = i15
		__asm(jump, target("___sfvwrite__XprivateX__BB64_44_B"))
	__asm(lbl("___sfvwrite__XprivateX__BB64_71_F"))
		i0 =  (-1)
		i1 =  ((__xasm<int>(push(i4), op(0x36))))
		i1 =  (i1 | 64)
		__asm(push(i1), push(i4), op(0x3b))
	__asm(lbl("___sfvwrite__XprivateX__BB64_72_F"))
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___sfvwrite_errState"))
		throw("Invalid state in ___sfvwrite")
	}
}



// Async
public const ___swsetup:int = regFunc(FSM___swsetup.start)

public final class FSM___swsetup extends Machine {

	public static function start():void {
			var result:FSM___swsetup = new FSM___swsetup
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int

	public static const intRegCount:int = 5

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___swsetup_entry"))
		__asm(push(state), switchjump(
			"___swsetup_errState",
			"___swsetup_state0",
			"___swsetup_state1",
			"___swsetup_state2"))
	__asm(lbl("___swsetup_state0"))
	__asm(lbl("___swsetup__XprivateX__BB65_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push(___sdidinit_2E_b), op(0x35))))
		__asm(push(i1!=0), iftrue, target("___swsetup__XprivateX__BB65_5_F"))
	__asm(lbl("___swsetup__XprivateX__BB65_1_F"))
		i1 =  (_usual)
		i2 =  (_usual_extra)
		i3 =  (0)
		i1 =  (i1 + 56)
	__asm(jump, target("___swsetup__XprivateX__BB65_2_F"), lbl("___swsetup__XprivateX__BB65_2_B"), label, lbl("___swsetup__XprivateX__BB65_2_F")); 
		__asm(push(i2), push(i1), op(0x3c))
		i2 =  (i2 + 148)
		i1 =  (i1 + 88)
		i3 =  (i3 + 1)
		__asm(push(i3==17), iftrue, target("___swsetup__XprivateX__BB65_4_F"))
	__asm(lbl("___swsetup__XprivateX__BB65_3_F"))
		__asm(jump, target("___swsetup__XprivateX__BB65_2_B"))
	__asm(lbl("___swsetup__XprivateX__BB65_4_F"))
		i1 =  (1)
		__asm(push(i1), push(___cleanup_2E_b), op(0x3a))
		__asm(push(i1), push(___sdidinit_2E_b), op(0x3a))
	__asm(lbl("___swsetup__XprivateX__BB65_5_F"))
		i1 =  ((__xasm<int>(push((i0+12)), op(0x36))))
		i2 =  (i0 + 12)
		i3 = i1
		i4 =  (i1 & 8)
		__asm(push(i4!=0), iftrue, target("___swsetup__XprivateX__BB65_16_F"))
	__asm(lbl("___swsetup__XprivateX__BB65_6_F"))
		i4 =  (i3 & 16)
		__asm(push(i4!=0), iftrue, target("___swsetup__XprivateX__BB65_8_F"))
	__asm(lbl("___swsetup__XprivateX__BB65_7_F"))
		i0 =  (9)
		__asm(push(i0), push(_val_2E_1440), op(0x3c))
		i0 =  (-1)
		__asm(jump, target("___swsetup__XprivateX__BB65_24_F"))
	__asm(lbl("___swsetup__XprivateX__BB65_8_F"))
		i3 =  (i3 & 4)
		__asm(push(i3!=0), iftrue, target("___swsetup__XprivateX__BB65_10_F"))
	__asm(lbl("___swsetup__XprivateX__BB65_9_F"))
		__asm(jump, target("___swsetup__XprivateX__BB65_15_F"))
	__asm(lbl("___swsetup__XprivateX__BB65_10_F"))
		i1 =  ((__xasm<int>(push((i0+48)), op(0x37))))
		i3 =  (i0 + 48)
		__asm(push(i1==0), iftrue, target("___swsetup__XprivateX__BB65_14_F"))
	__asm(lbl("___swsetup__XprivateX__BB65_11_F"))
		i4 =  (i0 + 64)
		__asm(push(i1==i4), iftrue, target("___swsetup__XprivateX__BB65_13_F"))
	__asm(lbl("___swsetup__XprivateX__BB65_12_F"))
		i4 =  (0)
		mstate.esp -= 8
		__asm(push(i1), push(mstate.esp), op(0x3c))
		__asm(push(i4), push((mstate.esp+4)), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___swsetup_state1"))
		i1 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___swsetup__XprivateX__BB65_13_F"))
		i1 =  (0)
		__asm(push(i1), push(i3), op(0x3c))
	__asm(lbl("___swsetup__XprivateX__BB65_14_F"))
		i1 =  (0)
		i3 =  ((__xasm<int>(push(i2), op(0x36))))
		i3 =  (i3 & -37)
		__asm(push(i3), push(i2), op(0x3b))
		__asm(push(i1), push((i0+4)), op(0x3c))
		i1 =  ((__xasm<int>(push((i0+16)), op(0x37))))
		__asm(push(i1), push(i0), op(0x3c))
		i1 = i3
	__asm(lbl("___swsetup__XprivateX__BB65_15_F"))
		i1 =  (i1 | 8)
		__asm(push(i1), push(i2), op(0x3b))
	__asm(lbl("___swsetup__XprivateX__BB65_16_F"))
		i1 =  ((__xasm<int>(push((i0+16)), op(0x37))))
		__asm(push(i1!=0), iftrue, target("___swsetup__XprivateX__BB65_18_F"))
	__asm(lbl("___swsetup__XprivateX__BB65_17_F"))
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 2
		mstate.esp -= 4;FSM___smakebuf.start()
		return
	__asm(lbl("___swsetup_state2"))
		mstate.esp += 4
	__asm(lbl("___swsetup__XprivateX__BB65_18_F"))
		i1 =  ((__xasm<int>(push(i2), op(0x36))))
		i2 =  (i1 & 1)
		__asm(push(i2==0), iftrue, target("___swsetup__XprivateX__BB65_20_F"))
	__asm(lbl("___swsetup__XprivateX__BB65_19_F"))
		i1 =  (0)
		__asm(push(i1), push((i0+8)), op(0x3c))
		i2 =  ((__xasm<int>(push((i0+20)), op(0x37))))
		i2 =  (0 - i2)
		__asm(push(i2), push((i0+24)), op(0x3c))
		__asm(jump, target("___swsetup__XprivateX__BB65_22_F"))
	__asm(lbl("___swsetup__XprivateX__BB65_20_F"))
		i2 =  (i0 + 8)
		i1 =  (i1 & 2)
		__asm(push(i1!=0), iftrue, target("___swsetup__XprivateX__BB65_23_F"))
	__asm(lbl("___swsetup__XprivateX__BB65_21_F"))
		i1 =  (0)
		i0 =  ((__xasm<int>(push((i0+20)), op(0x37))))
		__asm(push(i0), push(i2), op(0x3c))
	__asm(lbl("___swsetup__XprivateX__BB65_22_F"))
		mstate.eax = i1
		__asm(jump, target("___swsetup__XprivateX__BB65_25_F"))
	__asm(lbl("___swsetup__XprivateX__BB65_23_F"))
		i0 =  (0)
		__asm(push(i0), push(i2), op(0x3c))
	__asm(lbl("___swsetup__XprivateX__BB65_24_F"))
		mstate.eax = i0
	__asm(lbl("___swsetup__XprivateX__BB65_25_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___swsetup_errState"))
		throw("Invalid state in ___swsetup")
	}
}



// Async
public const ___smakebuf:int = regFunc(FSM___smakebuf.start)

public final class FSM___smakebuf extends Machine {

	public static function start():void {
			var result:FSM___smakebuf = new FSM___smakebuf
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int

	public static const intRegCount:int = 8

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___smakebuf_entry"))
		__asm(push(state), switchjump(
			"___smakebuf_errState",
			"___smakebuf_state0",
			"___smakebuf_state1",
			"___smakebuf_state2",
			"___smakebuf_state3"))
	__asm(lbl("___smakebuf_state0"))
	__asm(lbl("___smakebuf__XprivateX__BB66_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 144
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((i0+12)), op(0x36))))
		i2 =  (i0 + 12)
		i1 =  (i1 & 2)
		__asm(push(i1==0), iftrue, target("___smakebuf__XprivateX__BB66_2_F"))
	__asm(lbl("___smakebuf__XprivateX__BB66_1_F"))
		i2 =  (1)
		i1 =  (i0 + 67)
		__asm(push(i1), push(i0), op(0x3c))
		__asm(push(i1), push((i0+16)), op(0x3c))
		__asm(push(i2), push((i0+20)), op(0x3c))
		__asm(jump, target("___smakebuf__XprivateX__BB66_17_F"))
	__asm(lbl("___smakebuf__XprivateX__BB66_2_F"))
		i1 =  ((__xasm<int>(push((i0+14)), op(0x36))))
		i3 =  (i0 + 14)
		i4 =  (i1 << 16)
		i4 =  (i4 >> 16)
		__asm(push(i4>-1), iftrue, target("___smakebuf__XprivateX__BB66_4_F"))
	__asm(jump, target("___smakebuf__XprivateX__BB66_3_F"), lbl("___smakebuf__XprivateX__BB66_3_B"), label, lbl("___smakebuf__XprivateX__BB66_3_F")); 
		i1 =  (2048)
		i4 =  (0)
		i5 =  (1024)
		__asm(jump, target("___smakebuf__XprivateX__BB66_10_F"))
	__asm(lbl("___smakebuf__XprivateX__BB66_4_F"))
		i4 =  ((mstate.ebp+-96))
		i1 =  (i1 << 16)
		mstate.esp -= 8
		i1 =  (i1 >> 16)
		__asm(push(i1), push(mstate.esp), op(0x3c))
		__asm(push(i4), push((mstate.esp+4)), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM_fstat.start()
		return
	__asm(lbl("___smakebuf_state1"))
		i1 = mstate.eax
		mstate.esp += 8
		__asm(push(i1<0), iftrue, target("___smakebuf__XprivateX__BB66_3_B"))
	__asm(lbl("___smakebuf__XprivateX__BB66_5_F"))
		i1 =  ((__xasm<int>(push((mstate.ebp+-88)), op(0x36))))
		i1 =  (i1 & 61440)
		i4 =  ((__xasm<int>(push((mstate.ebp+-32)), op(0x37))))
		i5 =  ((i1==8192) ? 1 : 0)
		i6 =  (i5 & 1)
		__asm(push(i4!=0), iftrue, target("___smakebuf__XprivateX__BB66_7_F"))
	__asm(lbl("___smakebuf__XprivateX__BB66_6_F"))
		i1 =  (2048)
		i4 =  (1024)
		i5 = i4
		i4 = i6
		__asm(jump, target("___smakebuf__XprivateX__BB66_10_F"))
	__asm(lbl("___smakebuf__XprivateX__BB66_7_F"))
		__asm(push(i4), push((i0+76)), op(0x3c))
		__asm(push(i1==32768), iftrue, target("___smakebuf__XprivateX__BB66_9_F"))
	__asm(lbl("___smakebuf__XprivateX__BB66_8_F"))
		i1 =  (2048)
		i5 = i4
		i4 = i6
		__asm(jump, target("___smakebuf__XprivateX__BB66_10_F"))
	__asm(lbl("___smakebuf__XprivateX__BB66_9_F"))
		i1 =  (___sseek)
		i5 =  ((__xasm<int>(push((i0+40)), op(0x37))))
		i1 =  ((i5==i1) ? 1024 : 2048)
		i5 = i4
		i4 = i6
	__asm(lbl("___smakebuf__XprivateX__BB66_10_F"))
		i6 =  (0)
		mstate.esp -= 8
		__asm(push(i6), push(mstate.esp), op(0x3c))
		__asm(push(i5), push((mstate.esp+4)), op(0x3c))
		state = 2
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___smakebuf_state2"))
		i6 = mstate.eax
		mstate.esp += 8
		__asm(push(i6!=0), iftrue, target("___smakebuf__XprivateX__BB66_12_F"))
	__asm(lbl("___smakebuf__XprivateX__BB66_11_F"))
		i1 =  (1)
		i3 =  ((__xasm<int>(push(i2), op(0x36))))
		i3 =  (i3 | 2)
		__asm(push(i3), push(i2), op(0x3b))
		i2 =  (i0 + 67)
		__asm(push(i2), push(i0), op(0x3c))
		__asm(push(i2), push((i0+16)), op(0x3c))
		__asm(push(i1), push((i0+20)), op(0x3c))
		__asm(jump, target("___smakebuf__XprivateX__BB66_17_F"))
	__asm(lbl("___smakebuf__XprivateX__BB66_12_F"))
		i7 =  (1)
		__asm(push(i7), push(___cleanup_2E_b), op(0x3a))
		__asm(push(i6), push(i0), op(0x3c))
		__asm(push(i6), push((i0+16)), op(0x3c))
		__asm(push(i5), push((i0+20)), op(0x3c))
		i0 =  (i1 | 128)
		__asm(push(i4!=0), iftrue, target("___smakebuf__XprivateX__BB66_14_F"))
	__asm(jump, target("___smakebuf__XprivateX__BB66_13_F"), lbl("___smakebuf__XprivateX__BB66_13_B"), label, lbl("___smakebuf__XprivateX__BB66_13_F")); 
		__asm(jump, target("___smakebuf__XprivateX__BB66_16_F"))
	__asm(lbl("___smakebuf__XprivateX__BB66_14_F"))
		i4 =  ((mstate.ebp+-144))
		i3 =  ((__xasm<int>(push(i3), op(0x36), op(0x52))))
		mstate.esp -= 8
		__asm(push(i3), push(mstate.esp), op(0x3c))
		__asm(push(i4), push((mstate.esp+4)), op(0x3c))
		state = 3
		mstate.esp -= 4;FSM_ioctl.start()
		return
	__asm(lbl("___smakebuf_state3"))
		i3 = mstate.eax
		mstate.esp += 8
		__asm(push(i3==-1), iftrue, target("___smakebuf__XprivateX__BB66_13_B"))
	__asm(lbl("___smakebuf__XprivateX__BB66_15_F"))
		i0 =  (i1 | 129)
	__asm(lbl("___smakebuf__XprivateX__BB66_16_F"))
		i1 =  ((__xasm<int>(push(i2), op(0x36))))
		i0 =  (i1 | i0)
		__asm(push(i0), push(i2), op(0x3b))
	__asm(lbl("___smakebuf__XprivateX__BB66_17_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___smakebuf_errState"))
		throw("Invalid state in ___smakebuf")
	}
}



// Async
public const ___ultoa:int = regFunc(FSM___ultoa.start)

public final class FSM___ultoa extends Machine {

	public static function start():void {
			var result:FSM___ultoa = new FSM___ultoa
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
	public var i8:int, i9:int, i10:int

	public static const intRegCount:int = 11

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___ultoa_entry"))
		__asm(push(state), switchjump(
			"___ultoa_errState",
			"___ultoa_state0",
			"___ultoa_state1"))
	__asm(lbl("___ultoa_state0"))
	__asm(lbl("___ultoa__XprivateX__BB67_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+20)), op(0x37))))
		i4 =  ((__xasm<int>(push((mstate.ebp+24)), op(0x37))))
		i5 =  ((__xasm<int>(push((mstate.ebp+28)), op(0x37))))
		i6 =  ((__xasm<int>(push((mstate.ebp+32)), op(0x35), op(0x51))))
		i7 =  ((__xasm<int>(push((mstate.ebp+36)), op(0x37))))
		__asm(push(i2==8), iftrue, target("___ultoa__XprivateX__BB67_30_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_1_F"))
		__asm(push(i2==10), iftrue, target("___ultoa__XprivateX__BB67_6_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_2_F"))
		__asm(push(i2!=16), iftrue, target("___ultoa__XprivateX__BB67_37_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_3_F"))
		i3 =  (0)
		__asm(jump, target("___ultoa__XprivateX__BB67_4_F"))
	__asm(jump, target("___ultoa__XprivateX__BB67_4_F"), lbl("___ultoa__XprivateX__BB67_4_B"), label, lbl("___ultoa__XprivateX__BB67_4_F")); 
		i2 =  (i0 & 15)
		i2 =  (i4 + i2)
		i5 =  (i3 ^ -1)
		i2 =  ((__xasm<int>(push(i2), op(0x35))))
		i5 =  (i1 + i5)
		__asm(push(i2), push(i5), op(0x3a))
		i3 =  (i3 + 1)
		i2 =  (i0 >>> 4)
		__asm(push(uint(i0)<uint(16)), iftrue, target("___ultoa__XprivateX__BB67_38_F"))
		__asm(jump, target("___ultoa__XprivateX__BB67_5_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_5_F"))
		i0 = i2
		__asm(jump, target("___ultoa__XprivateX__BB67_4_B"))
	__asm(lbl("___ultoa__XprivateX__BB67_6_F"))
		__asm(push(uint(i0)>uint(9)), iftrue, target("___ultoa__XprivateX__BB67_8_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_7_F"))
		i0 =  (i0 + 48)
		__asm(push(i0), push((i1+-1)), op(0x3a))
		i0 =  (i1 + -1)
		__asm(jump, target("___ultoa__XprivateX__BB67_40_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_8_F"))
		__asm(push(i0<0), iftrue, target("___ultoa__XprivateX__BB67_10_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_9_F"))
		i3 =  (0)
		i4 = i1
		__asm(jump, target("___ultoa__XprivateX__BB67_11_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_10_F"))
		i3 =  (1)
		i4 =  (uint(i0) / uint(10))
		i2 =  (i4 * 10)
		i0 =  (i0 - i2)
		i0 =  (i0 + 48)
		__asm(push(i0), push((i1+-1)), op(0x3a))
		i1 =  (i1 + -1)
		i0 = i4
		i4 = i1
	__asm(lbl("___ultoa__XprivateX__BB67_11_F"))
		i1 = i7
	__asm(jump, target("___ultoa__XprivateX__BB67_12_F"), lbl("___ultoa__XprivateX__BB67_12_B"), label, lbl("___ultoa__XprivateX__BB67_12_F")); 
		i2 =  (i1 + 1)
		i7 = i1
		__asm(push(i5==0), iftrue, target("___ultoa__XprivateX__BB67_18_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_13_F"))
		__asm(jump, target("___ultoa__XprivateX__BB67_14_F"))
	__asm(jump, target("___ultoa__XprivateX__BB67_14_F"), lbl("___ultoa__XprivateX__BB67_14_B"), label, lbl("___ultoa__XprivateX__BB67_14_F")); 
		i8 =  (i0 / 10)
		i8 =  (i8 * 10)
		i8 =  (i0 - i8)
		i8 =  (i8 + 48)
		__asm(push(i8), push((i4+-1)), op(0x3a))
		i8 =  ((__xasm<int>(push(i7), op(0x35))))
		i3 =  (i3 + 1)
		i9 =  (i4 + -1)
		i10 =  (i8 << 24)
		i10 =  (i10 >> 24)
		__asm(push(i10==i3), iftrue, target("___ultoa__XprivateX__BB67_22_F"))
		__asm(jump, target("___ultoa__XprivateX__BB67_15_F"))
	__asm(jump, target("___ultoa__XprivateX__BB67_15_F"), lbl("___ultoa__XprivateX__BB67_15_B"), label, lbl("___ultoa__XprivateX__BB67_15_F")); 
		i4 = i9
		__asm(jump, target("___ultoa__XprivateX__BB67_16_F"))
	__asm(jump, target("___ultoa__XprivateX__BB67_16_F"), lbl("___ultoa__XprivateX__BB67_16_B"), label, lbl("___ultoa__XprivateX__BB67_16_F")); 
		i8 =  (i0 / 10)
		i0 =  (i0 + 9)
		__asm(push(uint(i0)>uint(18)), iftrue, target("___ultoa__XprivateX__BB67_29_F"))
		__asm(jump, target("___ultoa__XprivateX__BB67_17_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_17_F"))
		i3 = i4
		__asm(jump, target("___ultoa__XprivateX__BB67_39_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_18_F"))
		i3 = i4
	__asm(jump, target("___ultoa__XprivateX__BB67_19_F"), lbl("___ultoa__XprivateX__BB67_19_B"), label, lbl("___ultoa__XprivateX__BB67_19_F")); 
		i4 =  (i0 / 10)
		i1 =  (i4 * 10)
		i1 =  (i0 - i1)
		i1 =  (i1 + 48)
		__asm(push(i1), push((i3+-1)), op(0x3a))
		i3 =  (i3 + -1)
		i0 =  (i0 + 9)
		__asm(push(uint(i0)>uint(18)), iftrue, target("___ultoa__XprivateX__BB67_21_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_20_F"))
		__asm(jump, target("___ultoa__XprivateX__BB67_39_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_21_F"))
		i0 = i4
		__asm(jump, target("___ultoa__XprivateX__BB67_19_B"))
	__asm(lbl("___ultoa__XprivateX__BB67_22_F"))
		i8 =  (i8 & 255)
		__asm(push(i8==127), iftrue, target("___ultoa__XprivateX__BB67_15_B"))
	__asm(lbl("___ultoa__XprivateX__BB67_23_F"))
		__asm(push(i0<10), iftrue, target("___ultoa__XprivateX__BB67_15_B"))
	__asm(lbl("___ultoa__XprivateX__BB67_24_F"))
		__asm(push(i6), push((i4+-2)), op(0x3a))
		i3 =  ((__xasm<int>(push(i2), op(0x35))))
		i4 =  (i4 + -2)
		__asm(push(i3!=0), iftrue, target("___ultoa__XprivateX__BB67_26_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_25_F"))
		i3 =  (0)
		__asm(jump, target("___ultoa__XprivateX__BB67_16_B"))
	__asm(lbl("___ultoa__XprivateX__BB67_26_F"))
		i3 =  (i1 + 1)
		i2 =  (i0 / 10)
		i0 =  (i0 + 9)
		__asm(push(uint(i0)>uint(18)), iftrue, target("___ultoa__XprivateX__BB67_28_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_27_F"))
		i3 = i4
		__asm(jump, target("___ultoa__XprivateX__BB67_39_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_28_F"))
		i0 =  (0)
		i1 = i3
		i3 = i0
		i0 = i2
		__asm(jump, target("___ultoa__XprivateX__BB67_12_B"))
	__asm(lbl("___ultoa__XprivateX__BB67_29_F"))
		i0 = i8
		__asm(jump, target("___ultoa__XprivateX__BB67_14_B"))
	__asm(lbl("___ultoa__XprivateX__BB67_30_F"))
		i4 =  (0)
		__asm(jump, target("___ultoa__XprivateX__BB67_31_F"))
	__asm(jump, target("___ultoa__XprivateX__BB67_31_F"), lbl("___ultoa__XprivateX__BB67_31_B"), label, lbl("___ultoa__XprivateX__BB67_31_F")); 
		i2 =  (i0 | 48)
		i5 =  (i4 ^ -1)
		i2 =  (i2 & 55)
		i5 =  (i1 + i5)
		__asm(push(i2), push(i5), op(0x3a))
		i4 =  (i4 + 1)
		i6 =  (i0 >>> 3)
		__asm(push(uint(i0)<uint(8)), iftrue, target("___ultoa__XprivateX__BB67_33_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_32_F"))
		i0 = i6
		__asm(jump, target("___ultoa__XprivateX__BB67_31_B"))
	__asm(lbl("___ultoa__XprivateX__BB67_33_F"))
		__asm(push(i3==0), iftrue, target("___ultoa__XprivateX__BB67_35_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_34_F"))
		i3 =  (i2 & 255)
		__asm(push(i3!=48), iftrue, target("___ultoa__XprivateX__BB67_36_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_35_F"))
		i3 = i5
		__asm(jump, target("___ultoa__XprivateX__BB67_39_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_36_F"))
		i3 =  (48)
		i0 =  (i4 + -1)
		i0 =  (-2 - i0)
		i0 =  (i1 + i0)
		__asm(push(i3), push(i0), op(0x3a))
		__asm(jump, target("___ultoa__XprivateX__BB67_40_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_37_F"))
		state = 1
		mstate.esp -= 4;FSM_abort1.start()
		return
	__asm(lbl("___ultoa_state1"))
	__asm(lbl("___ultoa__XprivateX__BB67_38_F"))
		i3 = i5
		__asm(jump, target("___ultoa__XprivateX__BB67_39_F"))
	__asm(lbl("___ultoa__XprivateX__BB67_39_F"))
		i0 = i3
	__asm(lbl("___ultoa__XprivateX__BB67_40_F"))
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___ultoa_errState"))
		throw("Invalid state in ___ultoa")
	}
}



// Async
public const ___grow_type_table:int = regFunc(FSM___grow_type_table.start)

public final class FSM___grow_type_table extends Machine {

	public static function start():void {
			var result:FSM___grow_type_table = new FSM___grow_type_table
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int

	public static const intRegCount:int = 8

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___grow_type_table_entry"))
		__asm(push(state), switchjump(
			"___grow_type_table_errState",
			"___grow_type_table_state0",
			"___grow_type_table_state1",
			"___grow_type_table_state2",
			"___grow_type_table_state3",
			"___grow_type_table_state4",
			"___grow_type_table_state5",
			"___grow_type_table_state6"))
	__asm(lbl("___grow_type_table_state0"))
	__asm(lbl("___grow_type_table__XprivateX__BB68_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
		i1 =  ((__xasm<int>(push(i0), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i4 =  ((__xasm<int>(push(i3), op(0x37))))
		i2 =  (i2 + 1)
		i5 =  (i1 << 1)
		i2 =  ((i2>i5) ? i2 : i5)
		__asm(push(i1!=8), iftrue, target("___grow_type_table__XprivateX__BB68_9_F"))
	__asm(lbl("___grow_type_table__XprivateX__BB68_1_F"))
		i5 =  (0)
		mstate.esp -= 8
		i6 =  (i2 << 2)
		__asm(push(i5), push(mstate.esp), op(0x3c))
		__asm(push(i6), push((mstate.esp+4)), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___grow_type_table_state1"))
		i5 = mstate.eax
		mstate.esp += 8
		i6 = i5
		__asm(push(i5!=0), iftrue, target("___grow_type_table__XprivateX__BB68_3_F"))
	__asm(lbl("___grow_type_table__XprivateX__BB68_2_F"))
		state = 2
		mstate.esp -= 4;FSM_abort1.start()
		return
	__asm(lbl("___grow_type_table_state2"))
	__asm(lbl("___grow_type_table__XprivateX__BB68_3_F"))
		mstate.esp -= 12
		i7 =  (i1 << 2)
		__asm(push(i4), push(mstate.esp), op(0x3c))
		__asm(push(i5), push((mstate.esp+4)), op(0x3c))
		__asm(push(i7), push((mstate.esp+8)), op(0x3c))
		mstate.esp -= 4;FSM_bcopy.start()
	__asm(lbl("___grow_type_table_state3"))
		mstate.esp += 12
		__asm(push(i1<i2), iftrue, target("___grow_type_table__XprivateX__BB68_5_F"))
	__asm(lbl("___grow_type_table__XprivateX__BB68_4_F"))
		i1 = i6
		__asm(jump, target("___grow_type_table__XprivateX__BB68_16_F"))
	__asm(lbl("___grow_type_table__XprivateX__BB68_5_F"))
		i4 = i6
		__asm(jump, target("___grow_type_table__XprivateX__BB68_6_F"))
	__asm(jump, target("___grow_type_table__XprivateX__BB68_6_F"), lbl("___grow_type_table__XprivateX__BB68_6_B"), label, lbl("___grow_type_table__XprivateX__BB68_6_F")); 
		i5 =  (i1 << 2)
		i5 =  (i4 + i5)
		__asm(jump, target("___grow_type_table__XprivateX__BB68_7_F"))
	__asm(jump, target("___grow_type_table__XprivateX__BB68_7_F"), lbl("___grow_type_table__XprivateX__BB68_7_B"), label, lbl("___grow_type_table__XprivateX__BB68_7_F")); 
		i6 =  (0)
		__asm(push(i6), push(i5), op(0x3c))
		i5 =  (i5 + 4)
		i1 =  (i1 + 1)
		__asm(push(i1<i2), iftrue, target("___grow_type_table__XprivateX__BB68_17_F"))
		__asm(jump, target("___grow_type_table__XprivateX__BB68_8_F"))
	__asm(lbl("___grow_type_table__XprivateX__BB68_8_F"))
		i1 = i4
		__asm(jump, target("___grow_type_table__XprivateX__BB68_16_F"))
	__asm(lbl("___grow_type_table__XprivateX__BB68_9_F"))
		mstate.esp -= 8
		i5 =  (i2 << 2)
		__asm(push(i4), push(mstate.esp), op(0x3c))
		__asm(push(i5), push((mstate.esp+4)), op(0x3c))
		state = 4
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___grow_type_table_state4"))
		i5 = mstate.eax
		mstate.esp += 8
		i6 = i4
		__asm(push(i5!=0), iftrue, target("___grow_type_table__XprivateX__BB68_12_F"))
	__asm(lbl("___grow_type_table__XprivateX__BB68_10_F"))
		__asm(push(i4==0), iftrue, target("___grow_type_table__XprivateX__BB68_12_F"))
	__asm(lbl("___grow_type_table__XprivateX__BB68_11_F"))
		i4 =  (0)
		mstate.esp -= 8
		__asm(push(i6), push(mstate.esp), op(0x3c))
		__asm(push(i4), push((mstate.esp+4)), op(0x3c))
		state = 5
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___grow_type_table_state5"))
		i4 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___grow_type_table__XprivateX__BB68_12_F"))
		__asm(push(i5!=0), iftrue, target("___grow_type_table__XprivateX__BB68_14_F"))
	__asm(lbl("___grow_type_table__XprivateX__BB68_13_F"))
		state = 6
		mstate.esp -= 4;FSM_abort1.start()
		return
	__asm(lbl("___grow_type_table_state6"))
	__asm(lbl("___grow_type_table__XprivateX__BB68_14_F"))
		i4 = i5
		__asm(push(i1<i2), iftrue, target("___grow_type_table__XprivateX__BB68_6_B"))
	__asm(lbl("___grow_type_table__XprivateX__BB68_15_F"))
		i1 = i4
		__asm(jump, target("___grow_type_table__XprivateX__BB68_16_F"))
	__asm(lbl("___grow_type_table__XprivateX__BB68_16_F"))
		__asm(push(i1), push(i3), op(0x3c))
		__asm(push(i2), push(i0), op(0x3c))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___grow_type_table__XprivateX__BB68_17_F"))
		__asm(jump, target("___grow_type_table__XprivateX__BB68_7_B"))
	__asm(lbl("___grow_type_table_errState"))
		throw("Invalid state in ___grow_type_table")
	}
}



// Async
public const ___find_arguments:int = regFunc(FSM___find_arguments.start)

public final class FSM___find_arguments extends Machine {

	public static function start():void {
			var result:FSM___find_arguments = new FSM___find_arguments
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
	public var i8:int, i9:int, i10:int, i11:int, i12:int

	public static const intRegCount:int = 13
	public var f0:Number

	public static const NumberRegCount:int = 1
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("___find_arguments_entry"))
		__asm(push(state), switchjump(
			"___find_arguments_errState",
			"___find_arguments_state0",
			"___find_arguments_state1",
			"___find_arguments_state2",
			"___find_arguments_state3",
			"___find_arguments_state4",
			"___find_arguments_state5",
			"___find_arguments_state6",
			"___find_arguments_state7",
			"___find_arguments_state8",
			"___find_arguments_state9",
			"___find_arguments_state10",
			"___find_arguments_state11",
			"___find_arguments_state12",
			"___find_arguments_state13",
			"___find_arguments_state14",
			"___find_arguments_state15",
			"___find_arguments_state16",
			"___find_arguments_state17",
			"___find_arguments_state18",
			"___find_arguments_state19",
			"___find_arguments_state20",
			"___find_arguments_state21",
			"___find_arguments_state22",
			"___find_arguments_state23",
			"___find_arguments_state24",
			"___find_arguments_state25",
			"___find_arguments_state26",
			"___find_arguments_state27",
			"___find_arguments_state28",
			"___find_arguments_state29",
			"___find_arguments_state30",
			"___find_arguments_state31",
			"___find_arguments_state32",
			"___find_arguments_state33",
			"___find_arguments_state34",
			"___find_arguments_state35",
			"___find_arguments_state36",
			"___find_arguments_state37",
			"___find_arguments_state38",
			"___find_arguments_state39"))
	__asm(lbl("___find_arguments_state0"))
	__asm(lbl("___find_arguments__XprivateX__BB69_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 52
		i0 =  ((mstate.ebp+-48))
		__asm(push(i0), push((mstate.ebp+-52)), op(0x3c))
		i1 =  (8)
		__asm(push(i1), push((mstate.ebp+-4)), op(0x3c))
		i1 =  (0)
		__asm(push(i1), push((mstate.ebp+-48)), op(0x3c))
		__asm(push(i1), push((mstate.ebp+-44)), op(0x3c))
		__asm(push(i1), push((mstate.ebp+-40)), op(0x3c))
		__asm(push(i1), push((mstate.ebp+-36)), op(0x3c))
		__asm(push(i1), push((mstate.ebp+-32)), op(0x3c))
		__asm(push(i1), push((mstate.ebp+-28)), op(0x3c))
		__asm(push(i1), push((mstate.ebp+-24)), op(0x3c))
		__asm(push(i1), push((mstate.ebp+-20)), op(0x3c))
		i2 =  (1)
		i3 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i4 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i5 =  ((__xasm<int>(push((mstate.ebp+16)), op(0x37))))
	__asm(jump, target("___find_arguments__XprivateX__BB69_1_F"), lbl("___find_arguments__XprivateX__BB69_1_B"), label, lbl("___find_arguments__XprivateX__BB69_1_F")); 
		i6 =  ((__xasm<int>(push(i3), op(0x35))))
		__asm(push(i6==0), iftrue, target("___find_arguments__XprivateX__BB69_12_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_2_F"))
		i6 =  (i6 & 255)
		__asm(push(i6!=37), iftrue, target("___find_arguments__XprivateX__BB69_24_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_3_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_4_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_4_F"), lbl("___find_arguments__XprivateX__BB69_4_B"), label, lbl("___find_arguments__XprivateX__BB69_4_F")); 
		i6 =  (0)
		i3 =  (i3 + 1)
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_5_F"), lbl("___find_arguments__XprivateX__BB69_5_B"), label, lbl("___find_arguments__XprivateX__BB69_5_F")); 
		i7 =  ((__xasm<int>(push(i3), op(0x35), op(0x51))))
		i3 =  (i3 + 1)
		__asm(push(i7>87), iftrue, target("___find_arguments__XprivateX__BB69_62_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_6_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_6_F"))
		__asm(push(i7>64), iftrue, target("___find_arguments__XprivateX__BB69_41_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_7_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_7_F"))
		__asm(push(i7>42), iftrue, target("___find_arguments__XprivateX__BB69_33_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_8_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_8_F"))
		__asm(push(i7>38), iftrue, target("___find_arguments__XprivateX__BB69_28_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_9_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_9_F"))
		__asm(push(i7==32), iftrue, target("___find_arguments__XprivateX__BB69_11_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_10_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_10_F"))
		__asm(push(i7==35), iftrue, target("___find_arguments__XprivateX__BB69_11_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_49_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_11_F"), lbl("___find_arguments__XprivateX__BB69_11_B"), label, lbl("___find_arguments__XprivateX__BB69_11_F")); 
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_12_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_13_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_13_F"), lbl("___find_arguments__XprivateX__BB69_13_B"), label, lbl("___find_arguments__XprivateX__BB69_13_F")); 
		__asm(push(i1<8), iftrue, target("___find_arguments__XprivateX__BB69_354_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_14_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_14_F"))
		i2 =  (0)
		i3 =  (i1 << 3)
		mstate.esp -= 8
		i3 =  (i3 + 8)
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i3), push((mstate.esp+4)), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___find_arguments_state1"))
		i3 = mstate.eax
		mstate.esp += 8
		__asm(push(i3), push(i5), op(0x3c))
		__asm(push(i2), push(i3), op(0x3c))
		i2 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		__asm(push(i1<1), iftrue, target("___find_arguments__XprivateX__BB69_353_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_15_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_15_F"))
		i3 =  (1)
		__asm(jump, target("___find_arguments__XprivateX__BB69_16_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_16_F"), lbl("___find_arguments__XprivateX__BB69_16_B"), label, lbl("___find_arguments__XprivateX__BB69_16_F")); 
		i6 =  (i3 << 2)
		i2 =  (i2 + i6)
		i2 =  ((__xasm<int>(push(i2), op(0x37))))
		__asm(push(i2>11), iftrue, target("___find_arguments__XprivateX__BB69_368_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_17_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_17_F"))
		__asm(push(i2>5), iftrue, target("___find_arguments__XprivateX__BB69_359_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_18_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_18_F"))
		__asm(push(i2>2), iftrue, target("___find_arguments__XprivateX__BB69_355_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_19_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_19_F"))
		__asm(push(i2==0), iftrue, target("___find_arguments__XprivateX__BB69_390_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_20_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_20_F"))
		__asm(push(i2==1), iftrue, target("___find_arguments__XprivateX__BB69_391_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_21_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_21_F"))
		__asm(push(i2==2), iftrue, target("___find_arguments__XprivateX__BB69_22_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_389_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_22_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_23_B"), label)
		i3 = i7
		__asm(jump, target("___find_arguments__XprivateX__BB69_24_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_24_F"), lbl("___find_arguments__XprivateX__BB69_24_B"), label, lbl("___find_arguments__XprivateX__BB69_24_F")); 
		i6 =  ((__xasm<int>(push((i3+1)), op(0x35))))
		i3 =  (i3 + 1)
		i7 = i3
		__asm(push(i6==0), iftrue, target("___find_arguments__XprivateX__BB69_27_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_25_F"))
		i6 =  (i6 & 255)
		__asm(push(i6!=37), iftrue, target("___find_arguments__XprivateX__BB69_23_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_26_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_4_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_27_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_13_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_28_F"))
		__asm(push(i7==39), iftrue, target("___find_arguments__XprivateX__BB69_11_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_29_F"))
		__asm(push(i7==42), iftrue, target("___find_arguments__XprivateX__BB69_30_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_49_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_30_F"))
		i7 = i3
		__asm(jump, target("___find_arguments__XprivateX__BB69_31_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_31_F"), lbl("___find_arguments__XprivateX__BB69_31_B"), label, lbl("___find_arguments__XprivateX__BB69_31_F")); 
		i8 =  ((__xasm<int>(push(i3), op(0x35), op(0x51))))
		i9 = i3
		i8 =  (i8 + -48)
		__asm(push(uint(i8)<uint(10)), iftrue, target("___find_arguments__XprivateX__BB69_198_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_32_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_32_F"))
		i8 =  (0)
		__asm(jump, target("___find_arguments__XprivateX__BB69_201_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_33_F"))
		i8 =  (1)
		i9 =  (i7 + -43)
		i8 =  (i8 << i9)
		__asm(push(uint(i9)>uint(14)), iftrue, target("___find_arguments__XprivateX__BB69_49_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_34_F"))
		i9 =  (i8 & 32704)
		__asm(push(i9!=0), iftrue, target("___find_arguments__XprivateX__BB69_194_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_35_F"))
		i9 =  (i8 & 37)
		__asm(push(i9!=0), iftrue, target("___find_arguments__XprivateX__BB69_11_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_36_F"))
		i8 =  (i8 & 8)
		__asm(push(i8!=0), iftrue, target("___find_arguments__XprivateX__BB69_37_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_49_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_37_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_38_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_38_F"), lbl("___find_arguments__XprivateX__BB69_38_B"), label, lbl("___find_arguments__XprivateX__BB69_38_F")); 
		i7 =  ((__xasm<int>(push(i3), op(0x35))))
		i8 =  (i3 + 1)
		i9 = i3
		__asm(push(i7!=42), iftrue, target("___find_arguments__XprivateX__BB69_222_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_39_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_39_F"))
		i3 =  ((__xasm<int>(push(i8), op(0x35), op(0x51))))
		i3 =  (i3 + -48)
		__asm(push(uint(i3)<uint(10)), iftrue, target("___find_arguments__XprivateX__BB69_208_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_40_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_40_F"))
		i3 =  (0)
		i7 = i8
		__asm(jump, target("___find_arguments__XprivateX__BB69_212_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_41_F"))
		__asm(push(i7>70), iftrue, target("___find_arguments__XprivateX__BB69_52_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_42_F"))
		__asm(push(i7>67), iftrue, target("___find_arguments__XprivateX__BB69_47_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_43_F"))
		__asm(push(i7==65), iftrue, target("___find_arguments__XprivateX__BB69_67_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_44_F"))
		__asm(push(i7==67), iftrue, target("___find_arguments__XprivateX__BB69_45_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_49_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_45_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_46_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_46_F"), lbl("___find_arguments__XprivateX__BB69_46_B"), label, lbl("___find_arguments__XprivateX__BB69_46_F")); 
		i6 =  (i6 | 16)
		__asm(jump, target("___find_arguments__XprivateX__BB69_108_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_47_F"))
		__asm(push(i7==68), iftrue, target("___find_arguments__XprivateX__BB69_236_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_48_F"))
		__asm(push(i7==69), iftrue, target("___find_arguments__XprivateX__BB69_67_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_49_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_49_F"), lbl("___find_arguments__XprivateX__BB69_49_B"), label, lbl("___find_arguments__XprivateX__BB69_49_F")); 
		i6 = i7
		__asm(jump, target("___find_arguments__XprivateX__BB69_50_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_50_F"), lbl("___find_arguments__XprivateX__BB69_50_B"), label, lbl("___find_arguments__XprivateX__BB69_50_F")); 
		__asm(push(i6==0), iftrue, target("___find_arguments__XprivateX__BB69_13_B"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_51_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_51_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_52_F"))
		__asm(push(i7>78), iftrue, target("___find_arguments__XprivateX__BB69_57_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_53_F"))
		__asm(push(i7==71), iftrue, target("___find_arguments__XprivateX__BB69_67_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_54_F"))
		__asm(push(i7==76), iftrue, target("___find_arguments__XprivateX__BB69_55_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_49_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_55_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_56_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_56_F"), lbl("___find_arguments__XprivateX__BB69_56_B"), label, lbl("___find_arguments__XprivateX__BB69_56_F")); 
		i6 =  (i6 | 8)
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_57_F"))
		__asm(push(i7==79), iftrue, target("___find_arguments__XprivateX__BB69_296_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_58_F"))
		__asm(push(i7==83), iftrue, target("___find_arguments__XprivateX__BB69_325_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_59_F"))
		__asm(push(i7==85), iftrue, target("___find_arguments__XprivateX__BB69_60_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_49_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_60_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_61_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_61_F"), lbl("___find_arguments__XprivateX__BB69_61_B"), label, lbl("___find_arguments__XprivateX__BB69_61_F")); 
		i6 =  (i6 | 16)
		__asm(jump, target("___find_arguments__XprivateX__BB69_115_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_62_F"))
		__asm(push(i7>109), iftrue, target("___find_arguments__XprivateX__BB69_87_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_63_F"))
		__asm(push(i7>100), iftrue, target("___find_arguments__XprivateX__BB69_75_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_64_F"))
		__asm(push(i7>98), iftrue, target("___find_arguments__XprivateX__BB69_72_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_65_F"))
		__asm(push(i7==88), iftrue, target("___find_arguments__XprivateX__BB69_114_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_66_F"))
		__asm(push(i7==97), iftrue, target("___find_arguments__XprivateX__BB69_67_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_49_B"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_67_F"), lbl("___find_arguments__XprivateX__BB69_67_B"), label, lbl("___find_arguments__XprivateX__BB69_67_F")); 
		__asm(jump, target("___find_arguments__XprivateX__BB69_68_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_68_F"), lbl("___find_arguments__XprivateX__BB69_68_B"), label, lbl("___find_arguments__XprivateX__BB69_68_F")); 
		i7 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i6 =  (i6 & 8)
		__asm(push(i6==0), iftrue, target("___find_arguments__XprivateX__BB69_261_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_69_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_69_F"))
		__asm(push(i2<i7), iftrue, target("___find_arguments__XprivateX__BB69_71_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_70_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_70_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 2
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state2"))
		mstate.esp += 12
		__asm(jump, target("___find_arguments__XprivateX__BB69_71_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_71_F"))
		i6 =  (22)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_72_F"))
		__asm(push(i7==99), iftrue, target("___find_arguments__XprivateX__BB69_107_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_73_F"))
		__asm(push(i7==100), iftrue, target("___find_arguments__XprivateX__BB69_74_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_49_B"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_74_F"), lbl("___find_arguments__XprivateX__BB69_74_B"), label, lbl("___find_arguments__XprivateX__BB69_74_F")); 
		__asm(jump, target("___find_arguments__XprivateX__BB69_238_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_75_F"))
		__asm(push(i7>104), iftrue, target("___find_arguments__XprivateX__BB69_81_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_76_F"))
		i8 =  (i7 + -101)
		__asm(push(uint(i8)<uint(3)), iftrue, target("___find_arguments__XprivateX__BB69_67_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_77_F"))
		__asm(push(i7==104), iftrue, target("___find_arguments__XprivateX__BB69_78_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_49_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_78_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_79_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_79_F"), lbl("___find_arguments__XprivateX__BB69_79_B"), label, lbl("___find_arguments__XprivateX__BB69_79_F")); 
		i7 =  (i6 & 64)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_227_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_80_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_80_F"))
		i6 =  (i6 | 8192)
		i6 =  (i6 & -65)
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_81_F"))
		__asm(push(i7==105), iftrue, target("___find_arguments__XprivateX__BB69_74_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_82_F"))
		__asm(push(i7==106), iftrue, target("___find_arguments__XprivateX__BB69_228_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_83_F"))
		__asm(push(i7==108), iftrue, target("___find_arguments__XprivateX__BB69_84_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_49_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_84_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_85_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_85_F"), lbl("___find_arguments__XprivateX__BB69_85_B"), label, lbl("___find_arguments__XprivateX__BB69_85_F")); 
		i7 =  (i6 & 16)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_230_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_86_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_86_F"))
		i6 =  (i6 | 32)
		i6 =  (i6 & -17)
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_87_F"))
		__asm(push(i7>114), iftrue, target("___find_arguments__XprivateX__BB69_96_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_88_F"))
		__asm(push(i7>111), iftrue, target("___find_arguments__XprivateX__BB69_92_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_89_F"))
		__asm(push(i7==110), iftrue, target("___find_arguments__XprivateX__BB69_264_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_90_F"))
		__asm(push(i7==111), iftrue, target("___find_arguments__XprivateX__BB69_91_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_49_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_91_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_298_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_92_F"))
		__asm(push(i7==112), iftrue, target("___find_arguments__XprivateX__BB69_321_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_93_F"))
		__asm(push(i7==113), iftrue, target("___find_arguments__XprivateX__BB69_94_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_49_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_94_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_95_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_95_F"), lbl("___find_arguments__XprivateX__BB69_95_B"), label, lbl("___find_arguments__XprivateX__BB69_95_F")); 
		i6 =  (i6 | 32)
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_96_F"))
		__asm(push(i7>116), iftrue, target("___find_arguments__XprivateX__BB69_101_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_97_F"))
		__asm(push(i7==115), iftrue, target("___find_arguments__XprivateX__BB69_106_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_98_F"))
		__asm(push(i7==116), iftrue, target("___find_arguments__XprivateX__BB69_99_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_49_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_99_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_100_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_100_F"), lbl("___find_arguments__XprivateX__BB69_100_B"), label, lbl("___find_arguments__XprivateX__BB69_100_F")); 
		i6 =  (i6 | 2048)
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_101_F"))
		__asm(push(i7==117), iftrue, target("___find_arguments__XprivateX__BB69_114_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_102_F"))
		__asm(push(i7==120), iftrue, target("___find_arguments__XprivateX__BB69_114_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_103_F"))
		__asm(push(i7!=122), iftrue, target("___find_arguments__XprivateX__BB69_49_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_104_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_105_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_105_F"), lbl("___find_arguments__XprivateX__BB69_105_B"), label, lbl("___find_arguments__XprivateX__BB69_105_F")); 
		i6 =  (i6 | 1024)
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_106_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_327_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_107_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_108_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_108_F"), lbl("___find_arguments__XprivateX__BB69_108_B"), label, lbl("___find_arguments__XprivateX__BB69_108_F")); 
		i7 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i6 =  (i6 & 16)
		__asm(push(i6==0), iftrue, target("___find_arguments__XprivateX__BB69_233_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_109_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_109_F"))
		__asm(push(i2<i7), iftrue, target("___find_arguments__XprivateX__BB69_111_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_110_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_110_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 3
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state3"))
		mstate.esp += 12
		__asm(jump, target("___find_arguments__XprivateX__BB69_111_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_111_F"))
		i6 =  (23)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((__xasm<int>(push(i3), op(0x35))))
		i1 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		__asm(push(i6==0), iftrue, target("___find_arguments__XprivateX__BB69_231_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_112_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_112_F"))
		i6 =  (i6 & 255)
		__asm(push(i6!=37), iftrue, target("___find_arguments__XprivateX__BB69_232_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_113_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_113_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_4_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_114_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_115_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_115_F"), lbl("___find_arguments__XprivateX__BB69_115_B"), label, lbl("___find_arguments__XprivateX__BB69_115_F")); 
		i7 =  (i6 & 4096)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_334_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_116_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_116_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_118_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_117_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_117_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 4
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state4"))
		mstate.esp += 12
		__asm(jump, target("___find_arguments__XprivateX__BB69_118_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_118_F"))
		i6 =  (16)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i1 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_119_B"), label)
		i7 =  (i7 << 0)
		i3 =  (i7 + i3)
		i3 =  (i3 + 1)
		i7 = i8
	__asm(jump, target("___find_arguments__XprivateX__BB69_120_F"), lbl("___find_arguments__XprivateX__BB69_120_B"), label, lbl("___find_arguments__XprivateX__BB69_120_F")); 
		__asm(push(i7>87), iftrue, target("___find_arguments__XprivateX__BB69_151_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_121_F"))
		__asm(push(i7>64), iftrue, target("___find_arguments__XprivateX__BB69_135_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_122_F"))
		__asm(push(i7>42), iftrue, target("___find_arguments__XprivateX__BB69_130_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_123_F"))
		__asm(push(i7>38), iftrue, target("___find_arguments__XprivateX__BB69_127_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_124_F"))
		__asm(push(i7==32), iftrue, target("___find_arguments__XprivateX__BB69_126_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_125_F"))
		__asm(push(i7==35), iftrue, target("___find_arguments__XprivateX__BB69_126_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_142_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_126_F"), lbl("___find_arguments__XprivateX__BB69_126_B"), label, lbl("___find_arguments__XprivateX__BB69_126_F")); 
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_127_F"))
		__asm(push(i7==39), iftrue, target("___find_arguments__XprivateX__BB69_126_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_128_F"))
		__asm(push(i7==42), iftrue, target("___find_arguments__XprivateX__BB69_129_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_142_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_129_F"))
		i7 = i3
		__asm(jump, target("___find_arguments__XprivateX__BB69_31_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_130_F"))
		i8 =  (1)
		i9 =  (i7 + -43)
		i8 =  (i8 << i9)
		__asm(push(uint(i9)>uint(14)), iftrue, target("___find_arguments__XprivateX__BB69_142_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_131_F"))
		i9 =  (i8 & 32704)
		__asm(push(i9!=0), iftrue, target("___find_arguments__XprivateX__BB69_193_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_132_F"))
		i9 =  (i8 & 37)
		__asm(push(i9!=0), iftrue, target("___find_arguments__XprivateX__BB69_126_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_133_F"))
		i8 =  (i8 & 8)
		__asm(push(i8!=0), iftrue, target("___find_arguments__XprivateX__BB69_134_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_142_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_134_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_38_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_135_F"))
		__asm(push(i7>70), iftrue, target("___find_arguments__XprivateX__BB69_143_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_136_F"))
		__asm(push(i7>67), iftrue, target("___find_arguments__XprivateX__BB69_140_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_137_F"))
		__asm(push(i7==65), iftrue, target("___find_arguments__XprivateX__BB69_156_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_138_F"))
		__asm(push(i7==67), iftrue, target("___find_arguments__XprivateX__BB69_139_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_142_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_139_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_46_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_140_F"))
		__asm(push(i7==68), iftrue, target("___find_arguments__XprivateX__BB69_192_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_141_F"))
		__asm(push(i7==69), iftrue, target("___find_arguments__XprivateX__BB69_156_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_142_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_142_F"), lbl("___find_arguments__XprivateX__BB69_142_B"), label, lbl("___find_arguments__XprivateX__BB69_142_F")); 
		i6 = i7
		__asm(jump, target("___find_arguments__XprivateX__BB69_50_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_143_F"))
		__asm(push(i7>78), iftrue, target("___find_arguments__XprivateX__BB69_147_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_144_F"))
		__asm(push(i7==71), iftrue, target("___find_arguments__XprivateX__BB69_156_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_145_F"))
		__asm(push(i7==76), iftrue, target("___find_arguments__XprivateX__BB69_146_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_142_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_146_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_56_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_147_F"))
		__asm(push(i7==79), iftrue, target("___find_arguments__XprivateX__BB69_191_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_148_F"))
		__asm(push(i7==83), iftrue, target("___find_arguments__XprivateX__BB69_190_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_149_F"))
		__asm(push(i7==85), iftrue, target("___find_arguments__XprivateX__BB69_150_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_142_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_150_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_61_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_151_F"))
		__asm(push(i7>109), iftrue, target("___find_arguments__XprivateX__BB69_168_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_152_F"))
		__asm(push(i7>100), iftrue, target("___find_arguments__XprivateX__BB69_160_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_153_F"))
		__asm(push(i7>98), iftrue, target("___find_arguments__XprivateX__BB69_157_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_154_F"))
		__asm(push(i7==88), iftrue, target("___find_arguments__XprivateX__BB69_189_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_155_F"))
		__asm(push(i7==97), iftrue, target("___find_arguments__XprivateX__BB69_156_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_142_B"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_156_F"), lbl("___find_arguments__XprivateX__BB69_156_B"), label, lbl("___find_arguments__XprivateX__BB69_156_F")); 
		__asm(jump, target("___find_arguments__XprivateX__BB69_68_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_157_F"))
		__asm(push(i7==99), iftrue, target("___find_arguments__XprivateX__BB69_188_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_158_F"))
		__asm(push(i7==100), iftrue, target("___find_arguments__XprivateX__BB69_159_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_142_B"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_159_F"), lbl("___find_arguments__XprivateX__BB69_159_B"), label, lbl("___find_arguments__XprivateX__BB69_159_F")); 
		__asm(jump, target("___find_arguments__XprivateX__BB69_238_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_160_F"))
		__asm(push(i7>104), iftrue, target("___find_arguments__XprivateX__BB69_164_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_161_F"))
		i8 =  (i7 + -101)
		__asm(push(uint(i8)<uint(3)), iftrue, target("___find_arguments__XprivateX__BB69_156_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_162_F"))
		__asm(push(i7==104), iftrue, target("___find_arguments__XprivateX__BB69_163_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_142_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_163_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_79_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_164_F"))
		__asm(push(i7==105), iftrue, target("___find_arguments__XprivateX__BB69_159_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_165_F"))
		__asm(push(i7==106), iftrue, target("___find_arguments__XprivateX__BB69_187_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_166_F"))
		__asm(push(i7==108), iftrue, target("___find_arguments__XprivateX__BB69_167_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_142_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_167_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_85_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_168_F"))
		__asm(push(i7>114), iftrue, target("___find_arguments__XprivateX__BB69_176_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_169_F"))
		__asm(push(i7>111), iftrue, target("___find_arguments__XprivateX__BB69_173_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_170_F"))
		__asm(push(i7==110), iftrue, target("___find_arguments__XprivateX__BB69_186_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_171_F"))
		__asm(push(i7==111), iftrue, target("___find_arguments__XprivateX__BB69_172_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_142_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_172_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_298_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_173_F"))
		__asm(push(i7==112), iftrue, target("___find_arguments__XprivateX__BB69_185_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_174_F"))
		__asm(push(i7==113), iftrue, target("___find_arguments__XprivateX__BB69_175_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_142_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_175_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_95_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_176_F"))
		__asm(push(i7>116), iftrue, target("___find_arguments__XprivateX__BB69_180_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_177_F"))
		__asm(push(i7==115), iftrue, target("___find_arguments__XprivateX__BB69_184_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_178_F"))
		__asm(push(i7==116), iftrue, target("___find_arguments__XprivateX__BB69_179_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_142_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_179_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_100_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_180_F"))
		__asm(push(i7==117), iftrue, target("___find_arguments__XprivateX__BB69_189_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_181_F"))
		__asm(push(i7==120), iftrue, target("___find_arguments__XprivateX__BB69_189_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_182_F"))
		__asm(push(i7!=122), iftrue, target("___find_arguments__XprivateX__BB69_142_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_183_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_105_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_184_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_327_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_185_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_322_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_186_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_265_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_187_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_229_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_188_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_108_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_189_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_115_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_190_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_326_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_191_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_297_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_192_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_237_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_193_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_195_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_194_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_195_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_195_F"))
		i8 =  (0)
		i9 = i3
		i10 = i8
		__asm(jump, target("___find_arguments__XprivateX__BB69_196_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_196_F"), lbl("___find_arguments__XprivateX__BB69_196_B"), label, lbl("___find_arguments__XprivateX__BB69_196_F")); 
		i11 =  (i9 + i10)
		i11 =  ((__xasm<int>(push(i11), op(0x35))))
		i8 =  (i8 * 10)
		i12 =  (i11 << 24)
		i7 =  (i7 + i8)
		i8 =  (i12 >> 24)
		i12 =  (i7 + -48)
		i7 =  (i10 + 1)
		i10 =  (i8 + -48)
		__asm(push(uint(i10)>uint(9)), iftrue, target("___find_arguments__XprivateX__BB69_224_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_197_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_197_F"))
		i10 = i7
		i7 = i8
		i8 = i12
		__asm(jump, target("___find_arguments__XprivateX__BB69_196_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_198_F"))
		i3 =  (0)
		i8 = i9
	__asm(jump, target("___find_arguments__XprivateX__BB69_199_F"), lbl("___find_arguments__XprivateX__BB69_199_B"), label, lbl("___find_arguments__XprivateX__BB69_199_F")); 
		i9 =  ((__xasm<int>(push(i8), op(0x35), op(0x51))))
		i3 =  (i3 * 10)
		i10 =  ((__xasm<int>(push((i8+1)), op(0x35), op(0x51))))
		i3 =  (i3 + i9)
		i9 =  (i3 + -48)
		i3 =  (i8 + 1)
		i8 = i3
		i10 =  (i10 + -48)
		__asm(push(uint(i10)<uint(10)), iftrue, target("___find_arguments__XprivateX__BB69_415_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_200_F"))
		i8 = i9
		__asm(jump, target("___find_arguments__XprivateX__BB69_201_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_201_F"))
		i9 =  ((__xasm<int>(push(i3), op(0x35))))
		i10 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i9!=36), iftrue, target("___find_arguments__XprivateX__BB69_205_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_202_F"))
		__asm(push(i8<i10), iftrue, target("___find_arguments__XprivateX__BB69_204_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_203_F"))
		i7 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i10 =  ((mstate.ebp+-52))
		__asm(push(i8), push(mstate.esp), op(0x3c))
		__asm(push(i10), push((mstate.esp+4)), op(0x3c))
		__asm(push(i7), push((mstate.esp+8)), op(0x3c))
		state = 5
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state5"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_204_F"))
		i7 =  (2)
		i10 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i9 =  (i8 << 2)
		i10 =  (i10 + i9)
		__asm(push(i7), push(i10), op(0x3c))
		i1 =  ((i8>i1) ? i8 : i1)
		i3 =  (i3 + 1)
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_205_F"))
		__asm(push(i2<i10), iftrue, target("___find_arguments__XprivateX__BB69_207_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_206_F"))
		i3 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i8 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i8), push((mstate.esp+4)), op(0x3c))
		__asm(push(i3), push((mstate.esp+8)), op(0x3c))
		state = 6
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state6"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_207_F"))
		i3 =  (2)
		i8 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i9 =  (i2 << 2)
		i8 =  (i8 + i9)
		__asm(push(i3), push(i8), op(0x3c))
		i1 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i3 = i7
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_208_F"))
		i3 =  (0)
		i7 = i9
	__asm(jump, target("___find_arguments__XprivateX__BB69_209_F"), lbl("___find_arguments__XprivateX__BB69_209_B"), label, lbl("___find_arguments__XprivateX__BB69_209_F")); 
		i9 =  ((__xasm<int>(push((i7+1)), op(0x35), op(0x51))))
		i3 =  (i3 * 10)
		i10 =  ((__xasm<int>(push((i7+2)), op(0x35), op(0x51))))
		i3 =  (i3 + i9)
		i3 =  (i3 + -48)
		i7 =  (i7 + 1)
		i9 =  (i10 + -48)
		__asm(push(uint(i9)>uint(9)), iftrue, target("___find_arguments__XprivateX__BB69_211_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_210_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_209_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_211_F"))
		i7 =  (i7 + 1)
	__asm(lbl("___find_arguments__XprivateX__BB69_212_F"))
		i9 =  ((__xasm<int>(push(i7), op(0x35))))
		i10 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i9!=36), iftrue, target("___find_arguments__XprivateX__BB69_216_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_213_F"))
		__asm(push(i3<i10), iftrue, target("___find_arguments__XprivateX__BB69_215_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_214_F"))
		i8 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i9 =  ((mstate.ebp+-52))
		__asm(push(i3), push(mstate.esp), op(0x3c))
		__asm(push(i9), push((mstate.esp+4)), op(0x3c))
		__asm(push(i8), push((mstate.esp+8)), op(0x3c))
		state = 7
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state7"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_215_F"))
		i8 =  (2)
		i9 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i10 =  (i3 << 2)
		i9 =  (i9 + i10)
		__asm(push(i8), push(i9), op(0x3c))
		i1 =  ((i3>i1) ? i3 : i1)
		i3 =  (i7 + 1)
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_216_F"))
		__asm(push(i2<i10), iftrue, target("___find_arguments__XprivateX__BB69_218_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_217_F"))
		i3 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i3), push((mstate.esp+8)), op(0x3c))
		state = 8
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state8"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_218_F"))
		i3 =  (2)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i9 =  (i2 << 2)
		i7 =  (i7 + i9)
		__asm(push(i3), push(i7), op(0x3c))
		i1 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i3 = i8
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_219_B"), label)
		i7 =  (0)
		__asm(jump, target("___find_arguments__XprivateX__BB69_220_F"))
	__asm(jump, target("___find_arguments__XprivateX__BB69_220_F"), lbl("___find_arguments__XprivateX__BB69_220_B"), label, lbl("___find_arguments__XprivateX__BB69_220_F")); 
		i8 =  (i9 + i7)
		i8 =  ((__xasm<int>(push((i8+1)), op(0x35), op(0x51))))
		i7 =  (i7 + 1)
		i10 =  (i8 + -48)
		__asm(push(uint(i10)>uint(9)), iftrue, target("___find_arguments__XprivateX__BB69_119_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_221_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_220_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_222_F"))
		i7 =  (i7 << 24)
		i7 =  (i7 >> 24)
		i10 =  (i7 + -48)
		__asm(push(uint(i10)<uint(10)), iftrue, target("___find_arguments__XprivateX__BB69_219_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_223_F"))
		i3 = i8
		__asm(jump, target("___find_arguments__XprivateX__BB69_120_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_224_F"))
		i3 =  (i3 + i7)
		i7 =  (i11 & 255)
		__asm(push(i7==36), iftrue, target("___find_arguments__XprivateX__BB69_226_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_225_F"))
		i7 = i8
		__asm(jump, target("___find_arguments__XprivateX__BB69_120_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_226_F"))
		i2 = i12
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_227_F"))
		i6 =  (i6 | 64)
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_228_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_229_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_229_F"))
		i6 =  (i6 | 4096)
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_230_F"))
		i6 =  (i6 | 16)
		__asm(jump, target("___find_arguments__XprivateX__BB69_5_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_231_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_13_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_232_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_24_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_233_F"))
		__asm(push(i2<i7), iftrue, target("___find_arguments__XprivateX__BB69_235_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_234_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 9
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state9"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_235_F"))
		i6 =  (2)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_236_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_237_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_237_F"))
		i6 =  (i6 | 16)
	__asm(lbl("___find_arguments__XprivateX__BB69_238_F"))
		i7 =  (i6 & 4096)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_242_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_239_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_241_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_240_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 10
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state10"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_241_F"))
		i6 =  (15)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_242_F"))
		i7 =  (i6 & 1024)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_246_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_243_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i1 =  ((i2>i1) ? i2 : i1)
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_245_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_244_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 11
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state11"))
		mstate.esp += 12
		i6 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i7 =  (i2 << 2)
		i8 =  (13)
		i6 =  (i6 + i7)
		__asm(push(i8), push(i6), op(0x3c))
		i6 =  (i2 + 1)
		i2 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_245_F"))
		i6 =  (13)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  (i2 + 1)
		i2 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_246_F"))
		i7 =  (i6 & 2048)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_250_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_247_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i1 =  ((i2>i1) ? i2 : i1)
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_249_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_248_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 12
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state12"))
		mstate.esp += 12
		i6 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i7 =  (i2 << 2)
		i8 =  (11)
		i6 =  (i6 + i7)
		__asm(push(i8), push(i6), op(0x3c))
		i6 =  (i2 + 1)
		i2 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_249_F"))
		i6 =  (11)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  (i2 + 1)
		i2 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_250_F"))
		i7 =  (i6 & 32)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_254_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_251_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i1 =  ((i2>i1) ? i2 : i1)
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_253_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_252_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 13
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state13"))
		mstate.esp += 12
		i6 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i7 =  (i2 << 2)
		i6 =  (i6 + i7)
		i7 =  (8)
		__asm(push(i7), push(i6), op(0x3c))
		i6 =  (i2 + 1)
		i2 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_253_F"))
		i6 =  (8)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  (i2 + 1)
		i2 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_254_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i6 =  (i6 & 16)
		__asm(push(i6==0), iftrue, target("___find_arguments__XprivateX__BB69_258_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_255_F"))
		i6 =  ((i2>i1) ? i2 : i1)
		__asm(push(i2<i7), iftrue, target("___find_arguments__XprivateX__BB69_257_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_256_F"))
		i1 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i1), push((mstate.esp+8)), op(0x3c))
		state = 14
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state14"))
		mstate.esp += 12
		i1 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i7 =  (i2 << 2)
		i8 =  (5)
		i1 =  (i1 + i7)
		__asm(push(i8), push(i1), op(0x3c))
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_257_F"))
		i1 =  (5)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i1), push(i7), op(0x3c))
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_258_F"))
		__asm(push(i2<i7), iftrue, target("___find_arguments__XprivateX__BB69_260_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_259_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 15
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state15"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_260_F"))
		i6 =  (2)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_261_F"))
		__asm(push(i2<i7), iftrue, target("___find_arguments__XprivateX__BB69_263_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_262_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 16
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state16"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_263_F"))
		i6 =  (21)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_264_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_265_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_265_F"))
		i7 =  (i6 & 4096)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_269_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_266_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_268_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_267_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 17
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state17"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_268_F"))
		i6 =  (17)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_269_F"))
		i7 =  (i6 & 2048)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_273_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_270_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_272_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_271_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 18
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state18"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_272_F"))
		i6 =  (12)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_273_F"))
		i7 =  (i6 & 1024)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_277_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_274_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_276_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_275_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 19
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state19"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_276_F"))
		i6 =  (14)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_277_F"))
		i7 =  (i6 & 32)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_281_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_278_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_280_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_279_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 20
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state20"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_280_F"))
		i6 =  (10)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_281_F"))
		i7 =  (i6 & 16)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_285_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_282_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_284_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_283_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 21
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state21"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_284_F"))
		i6 =  (7)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_285_F"))
		i7 =  (i6 & 64)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_289_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_286_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_288_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_287_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 22
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state22"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_288_F"))
		i6 =  (1)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_289_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i6 =  (i6 & 8192)
		__asm(push(i6==0), iftrue, target("___find_arguments__XprivateX__BB69_293_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_290_F"))
		__asm(push(i2<i7), iftrue, target("___find_arguments__XprivateX__BB69_292_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_291_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 23
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state23"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_292_F"))
		i6 =  (20)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_293_F"))
		__asm(push(i2<i7), iftrue, target("___find_arguments__XprivateX__BB69_295_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_294_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 24
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state24"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_295_F"))
		i6 =  (4)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_296_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_297_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_297_F"))
		i6 =  (i6 | 16)
	__asm(lbl("___find_arguments__XprivateX__BB69_298_F"))
		i7 =  (i6 & 4096)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_302_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_299_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_301_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_300_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 25
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state25"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_301_F"))
		i6 =  (16)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_302_F"))
		i7 =  (i6 & 1024)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_306_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_303_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i1 =  ((i2>i1) ? i2 : i1)
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_305_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_304_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 26
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state26"))
		mstate.esp += 12
		i6 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i7 =  (i2 << 2)
		i8 =  (13)
		i6 =  (i6 + i7)
		__asm(push(i8), push(i6), op(0x3c))
		i6 =  (i2 + 1)
		i2 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_305_F"))
		i6 =  (13)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  (i2 + 1)
		i2 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_306_F"))
		i7 =  (i6 & 2048)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_310_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_307_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i1 =  ((i2>i1) ? i2 : i1)
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_309_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_308_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 27
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state27"))
		mstate.esp += 12
		i6 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i7 =  (i2 << 2)
		i8 =  (11)
		i6 =  (i6 + i7)
		__asm(push(i8), push(i6), op(0x3c))
		i6 =  (i2 + 1)
		i2 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_309_F"))
		i6 =  (11)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  (i2 + 1)
		i2 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_310_F"))
		i7 =  (i6 & 32)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_314_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_311_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i1 =  ((i2>i1) ? i2 : i1)
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_313_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_312_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 28
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state28"))
		mstate.esp += 12
		i6 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i7 =  (i2 << 2)
		i8 =  (9)
		i6 =  (i6 + i7)
		__asm(push(i8), push(i6), op(0x3c))
		i6 =  (i2 + 1)
		i2 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_313_F"))
		i6 =  (9)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  (i2 + 1)
		i2 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_314_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i6 =  (i6 & 16)
		__asm(push(i6==0), iftrue, target("___find_arguments__XprivateX__BB69_318_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_315_F"))
		i6 =  ((i2>i1) ? i2 : i1)
		__asm(push(i2<i7), iftrue, target("___find_arguments__XprivateX__BB69_317_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_316_F"))
		i1 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i1), push((mstate.esp+8)), op(0x3c))
		state = 29
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state29"))
		mstate.esp += 12
		i1 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i7 =  (i2 << 2)
		i8 =  (6)
		i1 =  (i1 + i7)
		__asm(push(i8), push(i1), op(0x3c))
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_317_F"))
		i1 =  (6)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i1), push(i7), op(0x3c))
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_318_F"))
		__asm(push(i2<i7), iftrue, target("___find_arguments__XprivateX__BB69_320_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_319_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 30
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state30"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_320_F"))
		i6 =  (3)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_321_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_322_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_322_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_324_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_323_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 31
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state31"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_324_F"))
		i6 =  (18)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i6 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		i1 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_325_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_326_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_326_F"))
		i6 =  (i6 | 16)
	__asm(lbl("___find_arguments__XprivateX__BB69_327_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i6 =  (i6 & 16)
		__asm(push(i6==0), iftrue, target("___find_arguments__XprivateX__BB69_331_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_328_F"))
		__asm(push(i2<i7), iftrue, target("___find_arguments__XprivateX__BB69_330_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_329_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 32
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state32"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_330_F"))
		i6 =  (24)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i1 =  ((i2>i1) ? i2 : i1)
		i6 =  (i2 + 1)
		i2 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_331_F"))
		__asm(push(i2<i7), iftrue, target("___find_arguments__XprivateX__BB69_333_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_332_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 33
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state33"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_333_F"))
		i6 =  (19)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i1 =  ((i2>i1) ? i2 : i1)
		i6 =  (i2 + 1)
		i2 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_334_F"))
		i7 =  (i6 & 1024)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_338_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_335_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i1 =  ((i2>i1) ? i2 : i1)
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_337_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_336_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 34
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state34"))
		mstate.esp += 12
		i6 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i7 =  (i2 << 2)
		i8 =  (13)
		i6 =  (i6 + i7)
		__asm(push(i8), push(i6), op(0x3c))
		i2 =  (i2 + 1)
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_337_F"))
		i6 =  (13)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i2 =  (i2 + 1)
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_338_F"))
		i7 =  (i6 & 2048)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_342_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_339_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i1 =  ((i2>i1) ? i2 : i1)
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_341_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_340_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 35
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state35"))
		mstate.esp += 12
		i6 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i7 =  (i2 << 2)
		i8 =  (11)
		i6 =  (i6 + i7)
		__asm(push(i8), push(i6), op(0x3c))
		i2 =  (i2 + 1)
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_341_F"))
		i6 =  (11)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i2 =  (i2 + 1)
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_342_F"))
		i7 =  (i6 & 32)
		__asm(push(i7==0), iftrue, target("___find_arguments__XprivateX__BB69_346_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_343_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i1 =  ((i2>i1) ? i2 : i1)
		__asm(push(i2<i6), iftrue, target("___find_arguments__XprivateX__BB69_345_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_344_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 36
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state36"))
		mstate.esp += 12
		i6 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i7 =  (i2 << 2)
		i8 =  (9)
		i6 =  (i6 + i7)
		__asm(push(i8), push(i6), op(0x3c))
		i2 =  (i2 + 1)
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_345_F"))
		i6 =  (9)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i2 =  (i2 + 1)
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_346_F"))
		i7 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		i6 =  (i6 & 16)
		__asm(push(i6==0), iftrue, target("___find_arguments__XprivateX__BB69_350_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_347_F"))
		i1 =  ((i2>i1) ? i2 : i1)
		__asm(push(i2<i7), iftrue, target("___find_arguments__XprivateX__BB69_349_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_348_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 37
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state37"))
		mstate.esp += 12
		i6 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i7 =  (i2 << 2)
		i8 =  (6)
		i6 =  (i6 + i7)
		__asm(push(i8), push(i6), op(0x3c))
		i2 =  (i2 + 1)
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_349_F"))
		i6 =  (6)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i2 =  (i2 + 1)
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_350_F"))
		__asm(push(i2<i7), iftrue, target("___find_arguments__XprivateX__BB69_352_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_351_F"))
		i6 =  ((mstate.ebp+-4))
		mstate.esp -= 12
		i7 =  ((mstate.ebp+-52))
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i7), push((mstate.esp+4)), op(0x3c))
		__asm(push(i6), push((mstate.esp+8)), op(0x3c))
		state = 38
		mstate.esp -= 4;FSM___grow_type_table.start()
		return
	__asm(lbl("___find_arguments_state38"))
		mstate.esp += 12
	__asm(lbl("___find_arguments__XprivateX__BB69_352_F"))
		i6 =  (3)
		i7 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		i8 =  (i2 << 2)
		i7 =  (i7 + i8)
		__asm(push(i6), push(i7), op(0x3c))
		i1 =  ((i2>i1) ? i2 : i1)
		i2 =  (i2 + 1)
		__asm(jump, target("___find_arguments__XprivateX__BB69_1_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_353_F"))
		i4 = i2
		i1 = i2
		__asm(jump, target("___find_arguments__XprivateX__BB69_411_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_354_F"))
		i2 =  (0)
		i3 =  ((__xasm<int>(push(i5), op(0x37))))
		__asm(push(i2), push(i3), op(0x3c))
		i2 =  (1)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_355_F"))
		__asm(push(i2==3), iftrue, target("___find_arguments__XprivateX__BB69_392_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_356_F"))
		__asm(push(i2==4), iftrue, target("___find_arguments__XprivateX__BB69_393_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_357_F"))
		__asm(push(i2==5), iftrue, target("___find_arguments__XprivateX__BB69_358_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_389_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_358_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_359_F"))
		__asm(push(i2>8), iftrue, target("___find_arguments__XprivateX__BB69_364_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_360_F"))
		__asm(push(i2==6), iftrue, target("___find_arguments__XprivateX__BB69_394_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_361_F"))
		__asm(push(i2==7), iftrue, target("___find_arguments__XprivateX__BB69_395_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_362_F"))
		__asm(push(i2==8), iftrue, target("___find_arguments__XprivateX__BB69_363_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_389_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_363_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  (i3 << 3)
		i7 =  ((__xasm<int>(push(i4), op(0x37))))
		i8 =  ((__xasm<int>(push((i4+4)), op(0x37))))
		i2 =  (i2 + i6)
		__asm(push(i7), push(i2), op(0x3c))
		__asm(push(i8), push((i2+4)), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 8)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_364_F"))
		__asm(push(i2==9), iftrue, target("___find_arguments__XprivateX__BB69_396_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_365_F"))
		__asm(push(i2==10), iftrue, target("___find_arguments__XprivateX__BB69_397_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_366_F"))
		__asm(push(i2==11), iftrue, target("___find_arguments__XprivateX__BB69_367_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_389_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_367_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_368_F"))
		__asm(push(i2>17), iftrue, target("___find_arguments__XprivateX__BB69_378_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_369_F"))
		__asm(push(i2>14), iftrue, target("___find_arguments__XprivateX__BB69_374_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_370_F"))
		__asm(push(i2==12), iftrue, target("___find_arguments__XprivateX__BB69_398_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_371_F"))
		__asm(push(i2==13), iftrue, target("___find_arguments__XprivateX__BB69_399_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_372_F"))
		__asm(push(i2==14), iftrue, target("___find_arguments__XprivateX__BB69_373_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_389_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_373_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_374_F"))
		__asm(push(i2==15), iftrue, target("___find_arguments__XprivateX__BB69_400_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_375_F"))
		__asm(push(i2==16), iftrue, target("___find_arguments__XprivateX__BB69_401_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_376_F"))
		__asm(push(i2==17), iftrue, target("___find_arguments__XprivateX__BB69_377_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_389_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_377_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_378_F"))
		__asm(push(i2>20), iftrue, target("___find_arguments__XprivateX__BB69_383_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_379_F"))
		__asm(push(i2==18), iftrue, target("___find_arguments__XprivateX__BB69_404_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_380_F"))
		__asm(push(i2==19), iftrue, target("___find_arguments__XprivateX__BB69_403_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_381_F"))
		__asm(push(i2==20), iftrue, target("___find_arguments__XprivateX__BB69_382_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_389_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_382_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_383_F"))
		__asm(push(i2>22), iftrue, target("___find_arguments__XprivateX__BB69_387_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_384_F"))
		__asm(push(i2==21), iftrue, target("___find_arguments__XprivateX__BB69_402_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_385_F"))
		__asm(push(i2==22), iftrue, target("___find_arguments__XprivateX__BB69_386_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_389_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_386_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		f0 =  ((__xasm<Number>(push(i4), op(0x39))))
		i6 =  (i3 << 3)
		i2 =  (i2 + i6)
		__asm(push(f0), push(i2), op(0x3e))
		i2 =  (i3 + 1)
		i4 =  (i4 + 8)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_387_F"))
		__asm(push(i2==23), iftrue, target("___find_arguments__XprivateX__BB69_405_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_388_F"))
		__asm(push(i2==24), iftrue, target("___find_arguments__XprivateX__BB69_406_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_389_F"))
		__asm(jump, target("___find_arguments__XprivateX__BB69_407_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_390_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_391_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_392_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_393_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_394_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_395_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_396_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  (i3 << 3)
		i7 =  ((__xasm<int>(push(i4), op(0x37))))
		i8 =  ((__xasm<int>(push((i4+4)), op(0x37))))
		i2 =  (i2 + i6)
		__asm(push(i7), push(i2), op(0x3c))
		__asm(push(i8), push((i2+4)), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 8)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_397_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_398_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_399_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_400_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  (i3 << 3)
		i7 =  ((__xasm<int>(push(i4), op(0x37))))
		i8 =  ((__xasm<int>(push((i4+4)), op(0x37))))
		i2 =  (i2 + i6)
		__asm(push(i7), push(i2), op(0x3c))
		__asm(push(i8), push((i2+4)), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 8)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_401_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  (i3 << 3)
		i7 =  ((__xasm<int>(push(i4), op(0x37))))
		i8 =  ((__xasm<int>(push((i4+4)), op(0x37))))
		i2 =  (i2 + i6)
		__asm(push(i7), push(i2), op(0x3c))
		__asm(push(i8), push((i2+4)), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 8)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_402_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		f0 =  ((__xasm<Number>(push(i4), op(0x39))))
		i6 =  (i3 << 3)
		i2 =  (i2 + i6)
		__asm(push(f0), push(i2), op(0x3e))
		i2 =  (i3 + 1)
		i4 =  (i4 + 8)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_403_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_404_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_405_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i2 =  (i3 + 1)
		i4 =  (i4 + 4)
		__asm(jump, target("___find_arguments__XprivateX__BB69_408_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_406_F"))
		i2 =  ((__xasm<int>(push(i5), op(0x37))))
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i7 =  (i3 << 3)
		i2 =  (i2 + i7)
		__asm(push(i6), push(i2), op(0x3c))
		i4 =  (i4 + 4)
	__asm(lbl("___find_arguments__XprivateX__BB69_407_F"))
		i2 =  (i3 + 1)
	__asm(lbl("___find_arguments__XprivateX__BB69_408_F"))
		i6 =  ((__xasm<int>(push((mstate.ebp+-52)), op(0x37))))
		__asm(push(i2>i1), iftrue, target("___find_arguments__XprivateX__BB69_410_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_409_F"))
		i3 = i2
		i2 = i6
		__asm(jump, target("___find_arguments__XprivateX__BB69_16_B"))
	__asm(lbl("___find_arguments__XprivateX__BB69_410_F"))
		i4 = i6
		i1 = i6
	__asm(lbl("___find_arguments__XprivateX__BB69_411_F"))
		i2 = i4
		__asm(push(i1==0), iftrue, target("___find_arguments__XprivateX__BB69_414_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_412_F"))
		__asm(push(i0==i2), iftrue, target("___find_arguments__XprivateX__BB69_414_F"))
	__asm(lbl("___find_arguments__XprivateX__BB69_413_F"))
		i0 =  (0)
		mstate.esp -= 8
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i0), push((mstate.esp+4)), op(0x3c))
		state = 39
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("___find_arguments_state39"))
		i0 = mstate.eax
		mstate.esp += 8
	__asm(lbl("___find_arguments__XprivateX__BB69_414_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("___find_arguments__XprivateX__BB69_415_F"))
		i3 = i9
		__asm(jump, target("___find_arguments__XprivateX__BB69_199_B"))
	__asm(lbl("___find_arguments_errState"))
		throw("Invalid state in ___find_arguments")
	}
}



// Sync
public const _malloc_pages:int = regFunc(FSM_malloc_pages.start)

public final class FSM_malloc_pages extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
		var i8:int, i9:int


		__asm(label, lbl("_malloc_pages_entry"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i0 =  (i0 + 4095)
		i1 =  ((__xasm<int>(push(_free_list), op(0x37))))
		i2 =  (i0 & -4096)
		__asm(push(i1==0), iftrue, target("_malloc_pages__XprivateX__BB70_14_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_1_F"))
		i0 = i1
	__asm(jump, target("_malloc_pages__XprivateX__BB70_2_F"), lbl("_malloc_pages__XprivateX__BB70_2_B"), label, lbl("_malloc_pages__XprivateX__BB70_2_F")); 
		i1 =  ((__xasm<int>(push((i0+16)), op(0x37))))
		i3 =  (i0 + 16)
		__asm(push(uint(i1)<uint(i2)), iftrue, target("_malloc_pages__XprivateX__BB70_12_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_3_F"))
		i4 =  ((__xasm<int>(push((i0+8)), op(0x37))))
		i5 =  (i0 + 8)
		__asm(push(i1!=i2), iftrue, target("_malloc_pages__XprivateX__BB70_9_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_4_F"))
		i1 =  ((__xasm<int>(push(i0), op(0x37))))
		i3 = i0
		__asm(push(i1==0), iftrue, target("_malloc_pages__XprivateX__BB70_6_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_5_F"))
		i5 =  ((__xasm<int>(push((i0+4)), op(0x37))))
		__asm(push(i5), push((i1+4)), op(0x3c))
	__asm(lbl("_malloc_pages__XprivateX__BB70_6_F"))
		i1 =  ((__xasm<int>(push((i0+4)), op(0x37))))
		i3 =  ((__xasm<int>(push(i3), op(0x37))))
		__asm(push(i3), push(i1), op(0x3c))
		i1 =  (i2 >>> 12)
		__asm(push(i4==0), iftrue, target("_malloc_pages__XprivateX__BB70_8_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_7_F"))
		i3 = i4
		__asm(jump, target("_malloc_pages__XprivateX__BB70_22_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_8_F"))
		__asm(jump, target("_malloc_pages__XprivateX__BB70_15_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_9_F"))
		i0 =  (i4 + i2)
		__asm(push(i0), push(i5), op(0x3c))
		i0 =  (i1 - i2)
		__asm(push(i0), push(i3), op(0x3c))
		i1 =  (i2 >>> 12)
		__asm(push(i4==0), iftrue, target("_malloc_pages__XprivateX__BB70_11_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_10_F"))
		i0 =  (0)
		i3 = i4
		__asm(jump, target("_malloc_pages__XprivateX__BB70_22_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_11_F"))
		i0 =  (0)
		__asm(jump, target("_malloc_pages__XprivateX__BB70_15_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_12_F"))
		i0 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i0==0), iftrue, target("_malloc_pages__XprivateX__BB70_14_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_13_F"))
		__asm(jump, target("_malloc_pages__XprivateX__BB70_2_B"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_14_F"))
		i0 =  (0)
		i1 =  (i2 >>> 12)
	__asm(lbl("_malloc_pages__XprivateX__BB70_15_F"))
		i3 = i0
		i4 = i1
		i0 =  (0)
		i0 = _sbrk(i0)
		i0 =  (i0 + 4095)
		i5 =  (i0 & -4096)
		i0 =  (i5 + i2)
		__asm(push(uint(i0)>=uint(i5)), iftrue, target("_malloc_pages__XprivateX__BB70_17_F"))
	__asm(jump, target("_malloc_pages__XprivateX__BB70_16_F"), lbl("_malloc_pages__XprivateX__BB70_16_B"), label, lbl("_malloc_pages__XprivateX__BB70_16_F")); 
		i5 =  (0)
		i0 = i3
		i1 = i4
		i3 = i5
		__asm(jump, target("_malloc_pages__XprivateX__BB70_22_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_17_F"))
		i1 = i0
		i1 = _brk(i1)
		__asm(push(i1!=0), iftrue, target("_malloc_pages__XprivateX__BB70_16_B"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_18_F"))
		i1 =  (i0 >>> 12)
		i6 =  ((__xasm<int>(push(_malloc_origo), op(0x37))))
		i1 =  (i1 + -1)
		i6 =  (i1 - i6)
		__asm(push(i6), push(_last_index), op(0x3c))
		__asm(push(i0), push(_malloc_brk), op(0x3c))
		i0 =  ((__xasm<int>(push(_malloc_ninfo), op(0x37))))
		i1 =  (i6 + 1)
		__asm(push(uint(i1)>=uint(i0)), iftrue, target("_malloc_pages__XprivateX__BB70_20_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_19_F"))
		i0 = i3
		i1 = i4
		i3 = i5
		__asm(jump, target("_malloc_pages__XprivateX__BB70_22_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_20_F"))
		i0 =  (__2E_str210)
		i1 =  (4)
		i7 =  (0)
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		i0 = _sbrk(i7)
		i0 =  (i0 & 4095)
		i0 =  (4096 - i0)
		i1 =  (i6 >>> 9)
		i0 =  (i0 & 4095)
		i1 =  (i1 & 1048575)
		i1 =  (i1 + 2)
		i0 = _sbrk(i0)
		i0 =  (i1 << 12)
		i0 = _sbrk(i0)
		i6 = i0
		__asm(push(i0==-1), iftrue, target("_malloc_pages__XprivateX__BB70_16_B"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_21_F"))
		i7 =  (__2E_str19)
		i8 =  ((__xasm<int>(push(_malloc_ninfo), op(0x37))))
		i9 =  ((__xasm<int>(push(_page_dir), op(0x37))))
		i8 =  (i8 << 2)
		i1 =  (i1 << 10)
		memcpy(i0, i9, i8)
		i0 =  (i1 & 1073740800)
		__asm(push(i0), push(_malloc_ninfo), op(0x3c))
		__asm(push(i6), push(_page_dir), op(0x3c))
		i1 =  (4)
		i0 = i7
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		i0 = i3
		i1 = i4
		i3 = i5
	__asm(lbl("_malloc_pages__XprivateX__BB70_22_F"))
		__asm(push(i3==0), iftrue, target("_malloc_pages__XprivateX__BB70_29_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_23_F"))
		i4 =  (2)
		i5 =  ((__xasm<int>(push(_malloc_origo), op(0x37))))
		i6 =  (i3 >>> 12)
		i7 =  (i6 - i5)
		i8 =  ((__xasm<int>(push(_page_dir), op(0x37))))
		i7 =  (i7 << 2)
		i7 =  (i8 + i7)
		__asm(push(i4), push(i7), op(0x3c))
		__asm(push(uint(i1)<uint(2)), iftrue, target("_malloc_pages__XprivateX__BB70_27_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_24_F"))
		i4 =  (0)
		i5 =  (i6 - i5)
		i5 =  (i5 << 2)
		i5 =  (i5 + i8)
		i5 =  (i5 + 4)
		i1 =  (i1 + -1)
	__asm(jump, target("_malloc_pages__XprivateX__BB70_25_F"), lbl("_malloc_pages__XprivateX__BB70_25_B"), label, lbl("_malloc_pages__XprivateX__BB70_25_F")); 
		i6 =  (3)
		__asm(push(i6), push(i5), op(0x3c))
		i5 =  (i5 + 4)
		i4 =  (i4 + 1)
		__asm(push(i4==i1), iftrue, target("_malloc_pages__XprivateX__BB70_27_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_26_F"))
		__asm(jump, target("_malloc_pages__XprivateX__BB70_25_B"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_27_F"))
		i1 =  ((__xasm<int>(push(_malloc_junk_2E_b), op(0x35))))
		i1 =  (i1 ^ 1)
		i1 =  (i1 & 1)
		__asm(push(i1!=0), iftrue, target("_malloc_pages__XprivateX__BB70_29_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_28_F"))
		i1 =  (-48)
		i4 = i3
		memset(i4, i1, i2)
	__asm(lbl("_malloc_pages__XprivateX__BB70_29_F"))
		__asm(push(i0==0), iftrue, target("_malloc_pages__XprivateX__BB70_33_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_30_F"))
		i1 =  ((__xasm<int>(push(_px), op(0x37))))
		__asm(push(i1!=0), iftrue, target("_malloc_pages__XprivateX__BB70_32_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_31_F"))
		__asm(push(i0), push(_px), op(0x3c))
		__asm(jump, target("_malloc_pages__XprivateX__BB70_33_F"))
	__asm(lbl("_malloc_pages__XprivateX__BB70_32_F"))
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM_ifree.start()
	__asm(lbl("_malloc_pages_state1"))
		mstate.esp += 4
	__asm(lbl("_malloc_pages__XprivateX__BB70_33_F"))
		mstate.eax = i3
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	}
}



// Sync
public const _ifree:int = regFunc(FSM_ifree.start)

public final class FSM_ifree extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
		var i8:int


		__asm(label, lbl("_ifree_entry"))
	__asm(lbl("_ifree__XprivateX__BB71_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
	__asm(jump, target("_ifree__XprivateX__BB71_1_F"), lbl("_ifree__XprivateX__BB71_1_B"), label, lbl("_ifree__XprivateX__BB71_1_F")); 
		i2 = i0
		__asm(push(i2==0), iftrue, target("_ifree__XprivateX__BB71_74_F"))
	__asm(lbl("_ifree__XprivateX__BB71_2_F"))
		i0 =  ((__xasm<int>(push(_malloc_origo), op(0x37))))
		i1 =  (i2 >>> 12)
		i3 =  (i1 - i0)
		i4 = i2
		__asm(push(uint(i3)<uint(12)), iftrue, target("_ifree__XprivateX__BB71_74_F"))
	__asm(lbl("_ifree__XprivateX__BB71_3_F"))
		i5 =  ((__xasm<int>(push(_last_index), op(0x37))))
		__asm(push(uint(i3)>uint(i5)), iftrue, target("_ifree__XprivateX__BB71_74_F"))
	__asm(lbl("_ifree__XprivateX__BB71_4_F"))
		i5 =  ((__xasm<int>(push(_page_dir), op(0x37))))
		i6 =  (i3 << 2)
		i6 =  (i5 + i6)
		i7 =  ((__xasm<int>(push(i6), op(0x37))))
		i8 = i5
		__asm(push(uint(i7)>uint(3)), iftrue, target("_ifree__XprivateX__BB71_59_F"))
	__asm(lbl("_ifree__XprivateX__BB71_5_F"))
		__asm(push(i7!=2), iftrue, target("_ifree__XprivateX__BB71_74_F"))
	__asm(lbl("_ifree__XprivateX__BB71_6_F"))
		__asm(push(i7==1), iftrue, target("_ifree__XprivateX__BB71_74_F"))
	__asm(lbl("_ifree__XprivateX__BB71_7_F"))
		i4 =  (i4 & 4095)
		__asm(push(i4!=0), iftrue, target("_ifree__XprivateX__BB71_74_F"))
	__asm(lbl("_ifree__XprivateX__BB71_8_F"))
		i4 =  (1)
		i7 =  (i3 << 2)
		__asm(push(i4), push(i6), op(0x3c))
		i4 =  (i7 + i8)
		i4 =  ((__xasm<int>(push((i4+4)), op(0x37))))
		__asm(push(i4==3), iftrue, target("_ifree__XprivateX__BB71_10_F"))
	__asm(lbl("_ifree__XprivateX__BB71_9_F"))
		i0 =  (4096)
		__asm(jump, target("_ifree__XprivateX__BB71_14_F"))
	__asm(lbl("_ifree__XprivateX__BB71_10_F"))
		i4 =  (1)
		i0 =  (i1 - i0)
		i0 =  (i0 << 2)
		i7 = i5
	__asm(jump, target("_ifree__XprivateX__BB71_11_F"), lbl("_ifree__XprivateX__BB71_11_B"), label, lbl("_ifree__XprivateX__BB71_11_F")); 
		i1 =  (1)
		i3 =  (i0 + i7)
		__asm(push(i1), push((i3+4)), op(0x3c))
		i1 =  ((__xasm<int>(push((i3+8)), op(0x37))))
		i7 =  (i7 + 4)
		i4 =  (i4 + 1)
		__asm(push(i1!=3), iftrue, target("_ifree__XprivateX__BB71_13_F"))
	__asm(lbl("_ifree__XprivateX__BB71_12_F"))
		__asm(jump, target("_ifree__XprivateX__BB71_11_B"))
	__asm(lbl("_ifree__XprivateX__BB71_13_F"))
		i0 =  (i4 << 12)
	__asm(lbl("_ifree__XprivateX__BB71_14_F"))
		i4 = i0
		i0 =  ((__xasm<int>(push(_malloc_junk_2E_b), op(0x35))))
		i0 =  (i0 ^ 1)
		i0 =  (i0 & 1)
		__asm(push(i0!=0), iftrue, target("_ifree__XprivateX__BB71_16_F"))
	__asm(lbl("_ifree__XprivateX__BB71_15_F"))
		i0 =  (-48)
		i7 = i2
		i1 = i4
		memset(i7, i0, i1)
	__asm(lbl("_ifree__XprivateX__BB71_16_F"))
		i0 =  ((__xasm<int>(push(_malloc_hint_2E_b), op(0x35))))
		i0 =  (i0 ^ 1)
		i0 =  (i0 & 1)
		__asm(push(i0!=0), iftrue, target("_ifree__XprivateX__BB71_18_F"))
	__asm(lbl("_ifree__XprivateX__BB71_17_F"))
		i0 =  (__2E_str8)
		i7 =  (4)
		i1 = i7
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
	__asm(lbl("_ifree__XprivateX__BB71_18_F"))
		i0 =  ((__xasm<int>(push(_px), op(0x37))))
		i7 =  (i2 + i4)
		__asm(push(i0==0), iftrue, target("_ifree__XprivateX__BB71_20_F"))
	__asm(lbl("_ifree__XprivateX__BB71_19_F"))
		i1 = i0
		__asm(jump, target("_ifree__XprivateX__BB71_21_F"))
	__asm(lbl("_ifree__XprivateX__BB71_20_F"))
		i0 =  (20)
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM_imalloc.start()
	__asm(lbl("_ifree_state1"))
		i0 = mstate.eax
		mstate.esp += 4
		__asm(push(i0), push(_px), op(0x3c))
		i1 = i0
	__asm(lbl("_ifree__XprivateX__BB71_21_F"))
		__asm(push(i2), push((i0+8)), op(0x3c))
		__asm(push(i7), push((i1+12)), op(0x3c))
		__asm(push(i4), push((i1+16)), op(0x3c))
		i0 =  ((__xasm<int>(push(_free_list), op(0x37))))
		__asm(push(i0!=0), iftrue, target("_ifree__XprivateX__BB71_25_F"))
	__asm(lbl("_ifree__XprivateX__BB71_22_F"))
		i4 =  (_free_list)
		__asm(push(i0), push(i1), op(0x3c))
		__asm(push(i4), push((i1+4)), op(0x3c))
		__asm(push(i1), push(_free_list), op(0x3c))
		i0 =  (0)
		__asm(push(i0), push(_px), op(0x3c))
		i0 =  ((__xasm<int>(push(i1), op(0x37))))
		__asm(push(i0==0), iftrue, target("_ifree__XprivateX__BB71_24_F"))
	__asm(lbl("_ifree__XprivateX__BB71_23_F"))
		i0 =  (0)
		__asm(jump, target("_ifree__XprivateX__BB71_57_F"))
	__asm(lbl("_ifree__XprivateX__BB71_24_F"))
		i0 =  (0)
		i4 = i1
		__asm(jump, target("_ifree__XprivateX__BB71_48_F"))
	__asm(lbl("_ifree__XprivateX__BB71_25_F"))
		i3 =  ((__xasm<int>(push((i0+12)), op(0x37))))
		__asm(push(uint(i3)<uint(i2)), iftrue, target("_ifree__XprivateX__BB71_27_F"))
	__asm(lbl("_ifree__XprivateX__BB71_26_F"))
		__asm(jump, target("_ifree__XprivateX__BB71_32_F"))
	__asm(lbl("_ifree__XprivateX__BB71_27_F"))
		__asm(jump, target("_ifree__XprivateX__BB71_28_F"))
	__asm(jump, target("_ifree__XprivateX__BB71_28_F"), lbl("_ifree__XprivateX__BB71_28_B"), label, lbl("_ifree__XprivateX__BB71_28_F")); 
		i3 = i0
		i0 =  ((__xasm<int>(push(i3), op(0x37))))
		__asm(push(i0!=0), iftrue, target("_ifree__XprivateX__BB71_29_F"))
		__asm(jump, target("_ifree__XprivateX__BB71_31_F"))
	__asm(lbl("_ifree__XprivateX__BB71_29_F"))
		i3 =  ((__xasm<int>(push((i0+12)), op(0x37))))
		__asm(push(uint(i3)<uint(i2)), iftrue, target("_ifree__XprivateX__BB71_28_B"))
	__asm(lbl("_ifree__XprivateX__BB71_30_F"))
		__asm(jump, target("_ifree__XprivateX__BB71_32_F"))
	__asm(lbl("_ifree__XprivateX__BB71_31_F"))
		i0 = i3
	__asm(lbl("_ifree__XprivateX__BB71_32_F"))
		i3 =  ((__xasm<int>(push((i0+8)), op(0x37))))
		i5 =  (i0 + 8)
		__asm(push(uint(i3)<=uint(i7)), iftrue, target("_ifree__XprivateX__BB71_34_F"))
	__asm(lbl("_ifree__XprivateX__BB71_33_F"))
		i4 =  (0)
		__asm(push(i0), push(i1), op(0x3c))
		i7 =  ((__xasm<int>(push((i0+4)), op(0x37))))
		__asm(push(i7), push((i1+4)), op(0x3c))
		__asm(push(i1), push((i0+4)), op(0x3c))
		i0 =  ((__xasm<int>(push((i1+4)), op(0x37))))
		__asm(push(i1), push(i0), op(0x3c))
		__asm(push(i4), push(_px), op(0x3c))
		i0 = i1
		__asm(jump, target("_ifree__XprivateX__BB71_45_F"))
	__asm(lbl("_ifree__XprivateX__BB71_34_F"))
		i6 =  ((__xasm<int>(push((i0+12)), op(0x37))))
		i8 =  (i0 + 12)
		__asm(push(i6!=i2), iftrue, target("_ifree__XprivateX__BB71_41_F"))
	__asm(lbl("_ifree__XprivateX__BB71_35_F"))
		i7 =  (i6 + i4)
		__asm(push(i7), push(i8), op(0x3c))
		i1 =  ((__xasm<int>(push((i0+16)), op(0x37))))
		i4 =  (i1 + i4)
		__asm(push(i4), push((i0+16)), op(0x3c))
		i1 =  ((__xasm<int>(push(i0), op(0x37))))
		i2 =  (i0 + 16)
		i3 = i0
		__asm(push(i1!=0), iftrue, target("_ifree__XprivateX__BB71_37_F"))
	__asm(jump, target("_ifree__XprivateX__BB71_36_F"), lbl("_ifree__XprivateX__BB71_36_B"), label, lbl("_ifree__XprivateX__BB71_36_F")); 
		i4 =  (0)
		__asm(jump, target("_ifree__XprivateX__BB71_45_F"))
	__asm(lbl("_ifree__XprivateX__BB71_37_F"))
		i5 =  ((__xasm<int>(push((i1+8)), op(0x37))))
		__asm(push(i7!=i5), iftrue, target("_ifree__XprivateX__BB71_36_B"))
	__asm(lbl("_ifree__XprivateX__BB71_38_F"))
		i7 =  ((__xasm<int>(push((i1+12)), op(0x37))))
		__asm(push(i7), push(i8), op(0x3c))
		i7 =  ((__xasm<int>(push((i1+16)), op(0x37))))
		i4 =  (i7 + i4)
		__asm(push(i4), push(i2), op(0x3c))
		i4 =  ((__xasm<int>(push(i1), op(0x37))))
		__asm(push(i4), push(i3), op(0x3c))
		__asm(push(i4!=0), iftrue, target("_ifree__XprivateX__BB71_40_F"))
	__asm(lbl("_ifree__XprivateX__BB71_39_F"))
		i4 = i1
		__asm(jump, target("_ifree__XprivateX__BB71_45_F"))
	__asm(lbl("_ifree__XprivateX__BB71_40_F"))
		__asm(push(i0), push((i4+4)), op(0x3c))
		i4 = i1
		__asm(jump, target("_ifree__XprivateX__BB71_45_F"))
	__asm(lbl("_ifree__XprivateX__BB71_41_F"))
		__asm(push(i3!=i7), iftrue, target("_ifree__XprivateX__BB71_43_F"))
	__asm(lbl("_ifree__XprivateX__BB71_42_F"))
		i1 =  (0)
		i7 =  ((__xasm<int>(push((i0+16)), op(0x37))))
		i4 =  (i7 + i4)
		__asm(push(i4), push((i0+16)), op(0x3c))
		__asm(push(i2), push(i5), op(0x3c))
		i4 = i1
		__asm(jump, target("_ifree__XprivateX__BB71_45_F"))
	__asm(lbl("_ifree__XprivateX__BB71_43_F"))
		i4 =  ((__xasm<int>(push(i0), op(0x37))))
		i2 = i0
		__asm(push(i4!=0), iftrue, target("_ifree__XprivateX__BB71_36_B"))
	__asm(lbl("_ifree__XprivateX__BB71_44_F"))
		i4 =  (0)
		__asm(push(i4), push(i1), op(0x3c))
		__asm(push(i0), push((i1+4)), op(0x3c))
		__asm(push(i1), push(i2), op(0x3c))
		__asm(push(i4), push(_px), op(0x3c))
		i0 = i1
	__asm(lbl("_ifree__XprivateX__BB71_45_F"))
		i2 = i4
		i4 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i4==0), iftrue, target("_ifree__XprivateX__BB71_47_F"))
	__asm(lbl("_ifree__XprivateX__BB71_46_F"))
		i0 = i2
		__asm(jump, target("_ifree__XprivateX__BB71_57_F"))
	__asm(lbl("_ifree__XprivateX__BB71_47_F"))
		i4 = i0
		i0 = i2
	__asm(lbl("_ifree__XprivateX__BB71_48_F"))
		i2 = i4
		i4 =  ((__xasm<int>(push((i2+16)), op(0x37))))
		i7 =  ((__xasm<int>(push(_malloc_cache), op(0x37))))
		i1 =  (i2 + 16)
		__asm(push(uint(i4)>uint(i7)), iftrue, target("_ifree__XprivateX__BB71_50_F"))
	__asm(jump, target("_ifree__XprivateX__BB71_49_F"), lbl("_ifree__XprivateX__BB71_49_B"), label, lbl("_ifree__XprivateX__BB71_49_F")); 
		__asm(jump, target("_ifree__XprivateX__BB71_57_F"))
	__asm(lbl("_ifree__XprivateX__BB71_50_F"))
		i4 =  ((__xasm<int>(push((i2+12)), op(0x37))))
		i7 =  ((__xasm<int>(push(_malloc_brk), op(0x37))))
		i3 =  (i2 + 12)
		__asm(push(i4!=i7), iftrue, target("_ifree__XprivateX__BB71_49_B"))
	__asm(lbl("_ifree__XprivateX__BB71_51_F"))
		i4 =  (0)
		i4 = _sbrk(i4)
		i7 =  ((__xasm<int>(push(_malloc_brk), op(0x37))))
		__asm(push(i4!=i7), iftrue, target("_ifree__XprivateX__BB71_49_B"))
	__asm(lbl("_ifree__XprivateX__BB71_52_F"))
		i2 =  ((__xasm<int>(push((i2+8)), op(0x37))))
		i4 =  ((__xasm<int>(push(_malloc_cache), op(0x37))))
		i2 =  (i2 + i4)
		__asm(push(i2), push(i3), op(0x3c))
		__asm(push(i4), push(i1), op(0x3c))
		i2 = _brk(i2)
		i2 =  ((__xasm<int>(push(i3), op(0x37))))
		__asm(push(i2), push(_malloc_brk), op(0x3c))
		i4 =  ((__xasm<int>(push(_malloc_origo), op(0x37))))
		i7 =  ((__xasm<int>(push(_last_index), op(0x37))))
		i2 =  (i2 >>> 12)
		i1 =  (i2 - i4)
		__asm(push(uint(i1)>uint(i7)), iftrue, target("_ifree__XprivateX__BB71_56_F"))
	__asm(lbl("_ifree__XprivateX__BB71_53_F"))
		i2 =  (i2 - i4)
		i4 =  ((__xasm<int>(push(_page_dir), op(0x37))))
		i3 =  (i2 << 2)
		i4 =  (i4 + i3)
	__asm(jump, target("_ifree__XprivateX__BB71_54_F"), lbl("_ifree__XprivateX__BB71_54_B"), label, lbl("_ifree__XprivateX__BB71_54_F")); 
		i3 =  (0)
		__asm(push(i3), push(i4), op(0x3c))
		i4 =  (i4 + 4)
		i2 =  (i2 + 1)
		__asm(push(uint(i2)>uint(i7)), iftrue, target("_ifree__XprivateX__BB71_56_F"))
	__asm(lbl("_ifree__XprivateX__BB71_55_F"))
		__asm(jump, target("_ifree__XprivateX__BB71_54_B"))
	__asm(lbl("_ifree__XprivateX__BB71_56_F"))
		i2 =  (i1 + -1)
		__asm(push(i2), push(_last_index), op(0x3c))
	__asm(lbl("_ifree__XprivateX__BB71_57_F"))
		__asm(push(i0==0), iftrue, target("_ifree__XprivateX__BB71_74_F"))
	__asm(lbl("_ifree__XprivateX__BB71_58_F"))
		__asm(jump, target("_ifree__XprivateX__BB71_1_B"))
	__asm(lbl("_ifree__XprivateX__BB71_59_F"))
		i0 =  ((__xasm<int>(push((i7+8)), op(0x36))))
		i1 =  ((__xasm<int>(push((i7+10)), op(0x36))))
		i3 =  (i4 & 4095)
		i1 =  (i3 >>> i1)
		i3 =  (i7 + 10)
		i5 =  (i0 + -1)
		i4 =  (i5 & i4)
		__asm(push(i4!=0), iftrue, target("_ifree__XprivateX__BB71_74_F"))
	__asm(lbl("_ifree__XprivateX__BB71_60_F"))
		i4 =  (1)
		i5 =  (i1 & -32)
		i5 =  (i5 >>> 3)
		i5 =  (i7 + i5)
		i1 =  (i1 & 31)
		i6 =  ((__xasm<int>(push((i5+16)), op(0x37))))
		i1 =  (i4 << i1)
		i4 =  (i5 + 16)
		i5 =  (i6 & i1)
		__asm(push(i5!=0), iftrue, target("_ifree__XprivateX__BB71_74_F"))
	__asm(lbl("_ifree__XprivateX__BB71_61_F"))
		i5 =  ((__xasm<int>(push(_malloc_junk_2E_b), op(0x35))))
		i5 =  (i5 ^ 1)
		i5 =  (i5 & 1)
		__asm(push(i5!=0), iftrue, target("_ifree__XprivateX__BB71_63_F"))
	__asm(lbl("_ifree__XprivateX__BB71_62_F"))
		i5 =  (-48)
		memset(i2, i5, i0)
	__asm(lbl("_ifree__XprivateX__BB71_63_F"))
		i0 =  ((__xasm<int>(push(i4), op(0x37))))
		i0 =  (i0 | i1)
		__asm(push(i0), push(i4), op(0x3c))
		i0 =  ((__xasm<int>(push((i7+12)), op(0x36))))
		i1 =  (i0 + 1)
		__asm(push(i1), push((i7+12)), op(0x3b))
		i2 =  ((__xasm<int>(push(i3), op(0x36))))
		i3 =  ((__xasm<int>(push(_page_dir), op(0x37))))
		i2 =  (i2 << 2)
		i2 =  (i3 + i2)
		__asm(push(i0!=0), iftrue, target("_ifree__XprivateX__BB71_75_F"))
	__asm(lbl("_ifree__XprivateX__BB71_64_F"))
		i0 =  ((__xasm<int>(push(i2), op(0x37))))
		__asm(push(i0!=0), iftrue, target("_ifree__XprivateX__BB71_66_F"))
	__asm(lbl("_ifree__XprivateX__BB71_65_F"))
		i0 = i2
		__asm(jump, target("_ifree__XprivateX__BB71_73_F"))
	__asm(lbl("_ifree__XprivateX__BB71_66_F"))
		i0 =  (i7 + 4)
		i1 = i2
	__asm(jump, target("_ifree__XprivateX__BB71_67_F"), lbl("_ifree__XprivateX__BB71_67_B"), label, lbl("_ifree__XprivateX__BB71_67_F")); 
		i2 =  ((__xasm<int>(push(i1), op(0x37))))
		i3 =  ((__xasm<int>(push(i2), op(0x37))))
		__asm(push(i3!=0), iftrue, target("_ifree__XprivateX__BB71_69_F"))
	__asm(lbl("_ifree__XprivateX__BB71_68_F"))
		i0 = i1
		__asm(jump, target("_ifree__XprivateX__BB71_73_F"))
	__asm(lbl("_ifree__XprivateX__BB71_69_F"))
		i4 =  ((__xasm<int>(push((i3+4)), op(0x37))))
		i5 =  ((__xasm<int>(push(i0), op(0x37))))
		i1 =  ((uint(i4)<uint(i5)) ? i2 : i1)
		i4 =  ((uint(i4)>=uint(i5)) ? 1 : 0)
		__asm(push(i3==0), iftrue, target("_ifree__XprivateX__BB71_72_F"))
	__asm(lbl("_ifree__XprivateX__BB71_70_F"))
		i3 =  (i4 & 1)
		__asm(push(i3!=0), iftrue, target("_ifree__XprivateX__BB71_72_F"))
	__asm(lbl("_ifree__XprivateX__BB71_71_F"))
		i1 = i2
		__asm(jump, target("_ifree__XprivateX__BB71_67_B"))
	__asm(lbl("_ifree__XprivateX__BB71_72_F"))
		i0 = i1
	__asm(lbl("_ifree__XprivateX__BB71_73_F"))
		i1 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i1), push(i7), op(0x3c))
		__asm(push(i7), push(i0), op(0x3c))
		__asm(jump, target("_ifree__XprivateX__BB71_74_F"))
	__asm(jump, target("_ifree__XprivateX__BB71_74_F"), lbl("_ifree__XprivateX__BB71_74_B"), label, lbl("_ifree__XprivateX__BB71_74_F")); 
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	__asm(lbl("_ifree__XprivateX__BB71_75_F"))
		i0 =  ((__xasm<int>(push((i7+14)), op(0x36))))
		i1 =  (i1 & 65535)
		__asm(push(i1!=i0), iftrue, target("_ifree__XprivateX__BB71_74_B"))
	__asm(lbl("_ifree__XprivateX__BB71_76_F"))
		i0 =  ((__xasm<int>(push(i2), op(0x37))))
		__asm(push(i0==i7), iftrue, target("_ifree__XprivateX__BB71_81_F"))
	__asm(lbl("_ifree__XprivateX__BB71_77_F"))
		i0 = i2
		__asm(jump, target("_ifree__XprivateX__BB71_78_F"))
	__asm(jump, target("_ifree__XprivateX__BB71_78_F"), lbl("_ifree__XprivateX__BB71_78_B"), label, lbl("_ifree__XprivateX__BB71_78_F")); 
		i0 =  ((__xasm<int>(push(i0), op(0x37))))
		i1 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i1==i7), iftrue, target("_ifree__XprivateX__BB71_82_F"))
	__asm(lbl("_ifree__XprivateX__BB71_79_F"))
		__asm(jump, target("_ifree__XprivateX__BB71_78_B"))
	__asm(lbl("_ifree__XprivateX__BB71_80_B"), label)
		mstate.esp -= 4
		__asm(push(i1), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM_ifree.start()
	__asm(lbl("_ifree_state2"))
		mstate.esp += 4
		__asm(jump, target("_ifree__XprivateX__BB71_1_B"))
	__asm(lbl("_ifree__XprivateX__BB71_81_F"))
		i0 = i2
		__asm(jump, target("_ifree__XprivateX__BB71_82_F"))
	__asm(lbl("_ifree__XprivateX__BB71_82_F"))
		i1 =  (2)
		i2 =  ((__xasm<int>(push(i7), op(0x37))))
		__asm(push(i2), push(i0), op(0x3c))
		i0 =  ((__xasm<int>(push((i7+4)), op(0x37))))
		i2 =  ((__xasm<int>(push(_malloc_origo), op(0x37))))
		i0 =  (i0 >>> 12)
		i0 =  (i0 - i2)
		i0 =  (i0 << 2)
		i0 =  (i3 + i0)
		__asm(push(i1), push(i0), op(0x3c))
		i0 =  ((__xasm<int>(push((i7+4)), op(0x37))))
		i1 = i7
		__asm(push(i0!=i7), iftrue, target("_ifree__XprivateX__BB71_80_B"))
		__asm(jump, target("_ifree__XprivateX__BB71_83_F"))
	__asm(lbl("_ifree__XprivateX__BB71_83_F"))
		__asm(jump, target("_ifree__XprivateX__BB71_1_B"))
	}
}



// Sync
public const _imalloc:int = regFunc(FSM_imalloc.start)

public final class FSM_imalloc extends Machine {

	public static function start():void {
		var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
		var i8:int, i9:int, i10:int, i11:int, i12:int, i13:int, i14:int, i15:int
		var i16:int, i17:int


		__asm(label, lbl("_imalloc_entry"))
	__asm(lbl("_imalloc__XprivateX__BB72_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i1 =  (i0 + 4096)
		__asm(push(uint(i1)>=uint(i0)), iftrue, target("_imalloc__XprivateX__BB72_2_F"))
	__asm(jump, target("_imalloc__XprivateX__BB72_1_F"), lbl("_imalloc__XprivateX__BB72_1_B"), label, lbl("_imalloc__XprivateX__BB72_1_F")); 
		i1 =  (0)
		__asm(jump, target("_imalloc__XprivateX__BB72_50_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_2_F"))
		__asm(push(uint(i0)>uint(2048)), iftrue, target("_imalloc__XprivateX__BB72_49_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_3_F"))
		i1 =  (i0 + -1)
		i1 =  ((uint(i0)<uint(16)) ? 15 : i1)
		__asm(push(uint(i1)<uint(2)), iftrue, target("_imalloc__XprivateX__BB72_54_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_4_F"))
		i2 =  (-1)
		__asm(jump, target("_imalloc__XprivateX__BB72_5_F"))
	__asm(jump, target("_imalloc__XprivateX__BB72_5_F"), lbl("_imalloc__XprivateX__BB72_5_B"), label, lbl("_imalloc__XprivateX__BB72_5_F")); 
		i2 =  (i2 + 1)
		i1 =  (i1 >> 1)
		__asm(push(uint(i1)<uint(2)), iftrue, target("_imalloc__XprivateX__BB72_7_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_6_F"))
		__asm(jump, target("_imalloc__XprivateX__BB72_5_B"))
	__asm(lbl("_imalloc__XprivateX__BB72_7_F"))
		i1 =  (i2 + 2)
	__asm(jump, target("_imalloc__XprivateX__BB72_8_F"), lbl("_imalloc__XprivateX__BB72_8_B"), label, lbl("_imalloc__XprivateX__BB72_8_F")); 
		i2 =  ((__xasm<int>(push(_page_dir), op(0x37))))
		i3 =  (i1 << 2)
		i3 =  (i2 + i3)
		i3 =  ((__xasm<int>(push(i3), op(0x37))))
		__asm(push(i3!=0), iftrue, target("_imalloc__XprivateX__BB72_35_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_9_F"))
		i2 =  (4096)
		mstate.esp -= 4
		__asm(push(i2), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM_malloc_pages.start()
	__asm(lbl("_imalloc_state1"))
		i2 = mstate.eax
		mstate.esp += 4
		__asm(push(i2==0), iftrue, target("_imalloc__XprivateX__BB72_1_B"))
	__asm(lbl("_imalloc__XprivateX__BB72_10_F"))
		i3 =  (4096)
		i3 =  (i3 >>> i1)
		i4 =  (i3 + 31)
		i4 =  (i4 >>> 3)
		i5 =  (1)
		i4 =  (i4 & 536870908)
		i6 =  (i4 + 16)
		i5 =  (i5 << i1)
		i7 =  (i6 << 1)
		__asm(push(i5>i7), iftrue, target("_imalloc__XprivateX__BB72_12_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_11_F"))
		i7 = i2
		__asm(jump, target("_imalloc__XprivateX__BB72_14_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_12_F"))
		mstate.esp -= 4
		__asm(push(i6), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM_imalloc.start()
	__asm(lbl("_imalloc_state2"))
		i7 = mstate.eax
		mstate.esp += 4
		__asm(push(i7==0), iftrue, target("_imalloc__XprivateX__BB72_55_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_13_F"))
		__asm(jump, target("_imalloc__XprivateX__BB72_14_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_14_F"))
		__asm(push(i5), push((i7+8)), op(0x3b))
		__asm(push(i1), push((i7+10)), op(0x3b))
		__asm(push(i3), push((i7+12)), op(0x3b))
		__asm(push(i3), push((i7+14)), op(0x3b))
		__asm(push(i2), push((i7+4)), op(0x3c))
		i8 =  (i3 & 65535)
		i9 =  (i7 + 14)
		i10 =  (i7 + 12)
		i11 = i7
		__asm(push(uint(i8)>uint(31)), iftrue, target("_imalloc__XprivateX__BB72_22_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_15_F"))
		i12 =  (0)
		__asm(jump, target("_imalloc__XprivateX__BB72_16_F"))
	__asm(jump, target("_imalloc__XprivateX__BB72_16_F"), lbl("_imalloc__XprivateX__BB72_16_B"), label, lbl("_imalloc__XprivateX__BB72_16_F")); 
		__asm(push(i12<i8), iftrue, target("_imalloc__XprivateX__BB72_26_F"))
		__asm(jump, target("_imalloc__XprivateX__BB72_17_F"))
	__asm(jump, target("_imalloc__XprivateX__BB72_17_F"), lbl("_imalloc__XprivateX__BB72_17_B"), label, lbl("_imalloc__XprivateX__BB72_17_F")); 
		__asm(push(i2!=i7), iftrue, target("_imalloc__XprivateX__BB72_30_F"))
		__asm(jump, target("_imalloc__XprivateX__BB72_18_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_18_F"))
		__asm(push(i6<1), iftrue, target("_imalloc__XprivateX__BB72_30_F"))
		__asm(jump, target("_imalloc__XprivateX__BB72_19_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_19_F"))
		i6 =  (0)
		i4 =  (i4 + 16)
		__asm(jump, target("_imalloc__XprivateX__BB72_20_F"))
	__asm(jump, target("_imalloc__XprivateX__BB72_20_F"), lbl("_imalloc__XprivateX__BB72_20_B"), label, lbl("_imalloc__XprivateX__BB72_20_F")); 
		i8 =  (1)
		i12 =  (i6 & -32)
		i13 =  (i6 & 31)
		i12 =  (i12 >>> 3)
		i8 =  (i8 << i13)
		i12 =  (i11 + i12)
		i13 =  ((__xasm<int>(push((i12+16)), op(0x37))))
		i8 =  (i8 ^ -1)
		i8 =  (i13 & i8)
		__asm(push(i8), push((i12+16)), op(0x3c))
		i8 =  ((__xasm<int>(push(i9), op(0x36))))
		i8 =  (i8 + -1)
		__asm(push(i8), push(i9), op(0x3b))
		i4 =  (i4 - i5)
		i6 =  (i6 + 1)
		__asm(push(i4<1), iftrue, target("_imalloc__XprivateX__BB72_29_F"))
		__asm(jump, target("_imalloc__XprivateX__BB72_21_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_21_F"))
		__asm(jump, target("_imalloc__XprivateX__BB72_20_B"))
	__asm(lbl("_imalloc__XprivateX__BB72_22_F"))
		i12 =  (0)
		i13 = i8
		i14 = i12
	__asm(jump, target("_imalloc__XprivateX__BB72_23_F"), lbl("_imalloc__XprivateX__BB72_23_B"), label, lbl("_imalloc__XprivateX__BB72_23_F")); 
		i15 =  (-1)
		i16 =  (i12 & 134217727)
		i16 =  (i16 << 2)
		i16 =  (i11 + i16)
		__asm(push(i15), push((i16+16)), op(0x3c))
		i13 =  (i13 + -32)
		i14 =  (i14 + 32)
		i12 =  (i12 + 1)
		__asm(push(uint(i13)>uint(31)), iftrue, target("_imalloc__XprivateX__BB72_25_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_24_F"))
		i12 = i14
		__asm(jump, target("_imalloc__XprivateX__BB72_16_B"))
	__asm(lbl("_imalloc__XprivateX__BB72_25_F"))
		__asm(jump, target("_imalloc__XprivateX__BB72_23_B"))
	__asm(lbl("_imalloc__XprivateX__BB72_26_F"))
		i13 =  (0)
		i8 =  (i8 - i12)
	__asm(jump, target("_imalloc__XprivateX__BB72_27_F"), lbl("_imalloc__XprivateX__BB72_27_B"), label, lbl("_imalloc__XprivateX__BB72_27_F")); 
		i14 =  (1)
		i15 =  (i12 + i13)
		i16 =  (i15 & -32)
		i16 =  (i16 >>> 3)
		i15 =  (i15 & 31)
		i16 =  (i11 + i16)
		i17 =  ((__xasm<int>(push((i16+16)), op(0x37))))
		i14 =  (i14 << i15)
		i14 =  (i17 | i14)
		__asm(push(i14), push((i16+16)), op(0x3c))
		i13 =  (i13 + 1)
		__asm(push(i13==i8), iftrue, target("_imalloc__XprivateX__BB72_17_B"))
	__asm(lbl("_imalloc__XprivateX__BB72_28_F"))
		__asm(jump, target("_imalloc__XprivateX__BB72_27_B"))
	__asm(lbl("_imalloc__XprivateX__BB72_29_F"))
		i4 =  (i6 + -1)
		i3 =  (i3 - i4)
		i3 =  (i3 + -1)
		__asm(push(i3), push(i10), op(0x3b))
	__asm(lbl("_imalloc__XprivateX__BB72_30_F"))
		i3 =  ((__xasm<int>(push(_malloc_origo), op(0x37))))
		i2 =  (i2 >>> 12)
		i2 =  (i2 - i3)
		i3 =  ((__xasm<int>(push(_page_dir), op(0x37))))
		i2 =  (i2 << 2)
		i4 =  (i1 << 2)
		i2 =  (i3 + i2)
		__asm(push(i11), push(i2), op(0x3c))
		i2 =  (i3 + i4)
		i4 =  ((__xasm<int>(push(i2), op(0x37))))
		__asm(push(i4), push(i7), op(0x3c))
		__asm(push(i11), push(i2), op(0x3c))
		i2 =  ((__xasm<int>(push((i11+16)), op(0x37))))
		i4 =  (i11 + 16)
		__asm(push(i2==0), iftrue, target("_imalloc__XprivateX__BB72_34_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_31_F"))
		i2 = i3
		i3 = i11
		__asm(jump, target("_imalloc__XprivateX__BB72_32_F"))
	__asm(jump, target("_imalloc__XprivateX__BB72_32_F"), lbl("_imalloc__XprivateX__BB72_32_B"), label, lbl("_imalloc__XprivateX__BB72_32_F")); 
		i6 =  ((__xasm<int>(push(i4), op(0x37))))
		i5 =  (i6 & 1)
		__asm(push(i5==0), iftrue, target("_imalloc__XprivateX__BB72_56_F"))
		__asm(jump, target("_imalloc__XprivateX__BB72_33_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_33_F"))
		i7 =  (1)
		i5 =  (0)
		__asm(jump, target("_imalloc__XprivateX__BB72_44_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_34_F"))
		i2 = i3
		i3 = i11
		__asm(jump, target("_imalloc__XprivateX__BB72_38_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_35_F"))
		i4 =  ((__xasm<int>(push((i3+16)), op(0x37))))
		i5 =  (i3 + 16)
		__asm(push(i4==0), iftrue, target("_imalloc__XprivateX__BB72_37_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_36_F"))
		i4 = i5
		__asm(jump, target("_imalloc__XprivateX__BB72_32_B"))
	__asm(lbl("_imalloc__XprivateX__BB72_37_F"))
		i4 = i5
	__asm(jump, target("_imalloc__XprivateX__BB72_38_F"), lbl("_imalloc__XprivateX__BB72_38_B"), label, lbl("_imalloc__XprivateX__BB72_38_F")); 
		i5 =  ((__xasm<int>(push((i4+4)), op(0x37))))
		i4 =  (i4 + 4)
		i6 = i4
		__asm(push(i5==0), iftrue, target("_imalloc__XprivateX__BB72_40_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_39_F"))
		__asm(jump, target("_imalloc__XprivateX__BB72_32_B"))
	__asm(lbl("_imalloc__XprivateX__BB72_40_F"))
		i4 = i6
		__asm(jump, target("_imalloc__XprivateX__BB72_38_B"))
	__asm(lbl("_imalloc__XprivateX__BB72_41_B"), label)
		__asm(jump, target("_imalloc__XprivateX__BB72_42_F"))
	__asm(jump, target("_imalloc__XprivateX__BB72_42_F"), lbl("_imalloc__XprivateX__BB72_42_B"), label, lbl("_imalloc__XprivateX__BB72_42_F")); 
		i5 =  (i5 + 1)
		i7 =  (i7 << 1)
		i8 =  (i6 & i7)
		__asm(push(i8==0), iftrue, target("_imalloc__XprivateX__BB72_41_B"))
	__asm(lbl("_imalloc__XprivateX__BB72_43_F"))
		__asm(jump, target("_imalloc__XprivateX__BB72_44_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_44_F"))
		i6 =  (i6 ^ i7)
		__asm(push(i6), push(i4), op(0x3c))
		i6 =  ((__xasm<int>(push((i3+12)), op(0x36))))
		i6 =  (i6 + -1)
		__asm(push(i6), push((i3+12)), op(0x3b))
		i6 =  (i6 & 65535)
		__asm(push(i6!=0), iftrue, target("_imalloc__XprivateX__BB72_46_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_45_F"))
		i6 =  (0)
		i1 =  (i1 << 2)
		i7 =  ((__xasm<int>(push(i3), op(0x37))))
		i1 =  (i2 + i1)
		__asm(push(i7), push(i1), op(0x3c))
		__asm(push(i6), push(i3), op(0x3c))
	__asm(lbl("_imalloc__XprivateX__BB72_46_F"))
		i1 =  (i3 + 16)
		i1 =  (i4 - i1)
		i1 =  (i1 << 3)
		i2 =  ((__xasm<int>(push(_malloc_junk_2E_b), op(0x35))))
		i4 =  ((__xasm<int>(push((i3+10)), op(0x36))))
		i1 =  (i1 + i5)
		i2 =  (i2 ^ 1)
		i1 =  (i1 << i4)
		i2 =  (i2 & 1)
		__asm(push(i2!=0), iftrue, target("_imalloc__XprivateX__BB72_48_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_47_F"))
		i2 =  (-48)
		i4 =  ((__xasm<int>(push((i3+8)), op(0x36))))
		i5 =  ((__xasm<int>(push((i3+4)), op(0x37))))
		i5 =  (i5 + i1)
		memset(i5, i2, i4)
		i3 =  ((__xasm<int>(push((i3+4)), op(0x37))))
		i1 =  (i3 + i1)
		__asm(jump, target("_imalloc__XprivateX__BB72_50_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_48_F"))
		i2 =  ((__xasm<int>(push((i3+4)), op(0x37))))
		i1 =  (i2 + i1)
		__asm(jump, target("_imalloc__XprivateX__BB72_50_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_49_F"))
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM_malloc_pages.start()
	__asm(lbl("_imalloc_state3"))
		i1 = mstate.eax
		mstate.esp += 4
	__asm(lbl("_imalloc__XprivateX__BB72_50_F"))
		i2 =  ((__xasm<int>(push(_malloc_zero_2E_b), op(0x35))))
		i2 =  (i2 ^ 1)
		__asm(push(i1==0), iftrue, target("_imalloc__XprivateX__BB72_53_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_51_F"))
		i2 =  (i2 & 1)
		__asm(push(i2!=0), iftrue, target("_imalloc__XprivateX__BB72_53_F"))
	__asm(lbl("_imalloc__XprivateX__BB72_52_F"))
		i2 =  (0)
		i3 = i1
		memset(i3, i2, i0)
	__asm(jump, target("_imalloc__XprivateX__BB72_53_F"), lbl("_imalloc__XprivateX__BB72_53_B"), label, lbl("_imalloc__XprivateX__BB72_53_F")); 
		mstate.eax = i1
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		return
	__asm(lbl("_imalloc__XprivateX__BB72_54_F"))
		i1 =  (1)
		__asm(jump, target("_imalloc__XprivateX__BB72_8_B"))
	__asm(lbl("_imalloc__XprivateX__BB72_55_F"))
		i1 =  (0)
		mstate.esp -= 4
		__asm(push(i2), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM_ifree.start()
	__asm(lbl("_imalloc_state4"))
		mstate.esp += 4
		__asm(jump, target("_imalloc__XprivateX__BB72_53_B"))
	__asm(lbl("_imalloc__XprivateX__BB72_56_F"))
		i7 =  (1)
		i5 =  (0)
		__asm(jump, target("_imalloc__XprivateX__BB72_42_B"))
	}
}



// Async
public const _pubrealloc:int = regFunc(FSM_pubrealloc.start)

public final class FSM_pubrealloc extends Machine {

	public static function start():void {
			var result:FSM_pubrealloc = new FSM_pubrealloc
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int, i5:int, i6:int, i7:int
	public var i8:int, i9:int, i10:int, i11:int, i12:int

	public static const intRegCount:int = 13

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("_pubrealloc_entry"))
		__asm(push(state), switchjump(
			"_pubrealloc_errState",
			"_pubrealloc_state0",
			"_pubrealloc_state1",
			"_pubrealloc_state2",
			"_pubrealloc_state3",
			"_pubrealloc_state4",
			"_pubrealloc_state5",
			"_pubrealloc_state6",
			"_pubrealloc_state7",
			"_pubrealloc_state8",
			"_pubrealloc_state9"))
	__asm(lbl("_pubrealloc_state0"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 4096
		i0 =  ((__xasm<int>(push(_malloc_active_2E_3509), op(0x37))))
		i2 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		i3 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		__asm(push(i0<1), iftrue, target("_pubrealloc__XprivateX__BB73_5_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_1_F"))
		__asm(push(i0!=1), iftrue, target("_pubrealloc__XprivateX__BB73_3_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_2_F"))
		i2 =  (2)
		__asm(push(i2), push(_malloc_active_2E_3509), op(0x3c))
	__asm(lbl("_pubrealloc__XprivateX__BB73_3_F"))
		i2 =  (88)
		__asm(push(i2), push(_val_2E_1440), op(0x3c))
		i2 =  (0)
	__asm(jump, target("_pubrealloc__XprivateX__BB73_4_F"), lbl("_pubrealloc__XprivateX__BB73_4_B"), label, lbl("_pubrealloc__XprivateX__BB73_4_F")); 
		mstate.eax = i2
		__asm(jump, target("_pubrealloc__XprivateX__BB73_129_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_5_F"))
		i0 =  (1)
		__asm(push(i0), push(_malloc_active_2E_3509), op(0x3c))
		i0 =  ((__xasm<int>(push(_malloc_started_2E_3510_2E_b), op(0x35))))
		__asm(push(i0!=0), iftrue, target("_pubrealloc__XprivateX__BB73_77_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_6_F"))
		__asm(push(i2==0), iftrue, target("_pubrealloc__XprivateX__BB73_8_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_7_F"))
		i2 =  (0)
		__asm(push(i2), push(_malloc_active_2E_3509), op(0x3c))
		i3 =  (88)
		__asm(push(i3), push(_val_2E_1440), op(0x3c))
		__asm(jump, target("_pubrealloc__XprivateX__BB73_4_B"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_8_F"))
		i0 =  (0)
		i4 =  ((__xasm<int>(push(_val_2E_1440), op(0x37))))
		i5 =  ((mstate.ebp+-4096))
	__asm(jump, target("_pubrealloc__XprivateX__BB73_9_F"), lbl("_pubrealloc__XprivateX__BB73_9_B"), label, lbl("_pubrealloc__XprivateX__BB73_9_F")); 
		i6 = i0
		__asm(push(i6==1), iftrue, target("_pubrealloc__XprivateX__BB73_12_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_10_F"))
		__asm(push(i6!=0), iftrue, target("_pubrealloc__XprivateX__BB73_69_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_11_F"))
		i0 =  (__2E_str96)
		mstate.esp -= 20
		i1 =  (__2E_str13)
		i7 =  (99)
		i8 =  (22)
		__asm(push(i5), push(mstate.esp), op(0x3c))
		__asm(push(i0), push((mstate.esp+4)), op(0x3c))
		__asm(push(i8), push((mstate.esp+8)), op(0x3c))
		__asm(push(i1), push((mstate.esp+12)), op(0x3c))
		__asm(push(i7), push((mstate.esp+16)), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM_sprintf.start()
		return
	__asm(lbl("_pubrealloc_state1"))
		mstate.esp += 20
		i1 =  (3)
		i0 = i5
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		__asm(push(i8), push(_val_2E_1440), op(0x3c))
		__asm(jump, target("_pubrealloc__XprivateX__BB73_69_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_12_F"))
		i0 =  (__2E_str876)
		i1 =  (4)
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		mstate.esp -= 4
		i0 =  (__2E_str113335)
		__asm(push(i0), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM_getenv.start()
	__asm(lbl("_pubrealloc_state2"))
		i0 = mstate.eax
		mstate.esp += 4
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_69_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_13_F"))
		i1 =  ((__xasm<int>(push(_malloc_cache), op(0x37))))
		i7 =  ((__xasm<int>(push(_malloc_hint_2E_b), op(0x35))))
		i8 =  ((__xasm<int>(push(_malloc_realloc_2E_b), op(0x35))))
		i9 =  ((__xasm<int>(push(_malloc_junk_2E_b), op(0x35))))
		i10 =  ((__xasm<int>(push(_malloc_sysv_2E_b), op(0x35))))
		i11 =  ((__xasm<int>(push(_malloc_zero_2E_b), op(0x35))))
		__asm(jump, target("_pubrealloc__XprivateX__BB73_66_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_14_B"), label)
		i1 =  (i1 << 24)
		i1 =  (i1 >> 24)
		__asm(push(i1>89), iftrue, target("_pubrealloc__XprivateX__BB73_26_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_15_F"))
		__asm(push(i1>73), iftrue, target("_pubrealloc__XprivateX__BB73_21_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_16_F"))
		__asm(push(i1==60), iftrue, target("_pubrealloc__XprivateX__BB73_39_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_17_F"))
		__asm(push(i1==62), iftrue, target("_pubrealloc__XprivateX__BB73_36_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_18_F"))
		__asm(push(i1==72), iftrue, target("_pubrealloc__XprivateX__BB73_19_F"))
		__asm(jump, target("_pubrealloc__XprivateX__BB73_35_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_19_F"))
		i0 =  (i0 + 1)
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_45_F"))
		__asm(jump, target("_pubrealloc__XprivateX__BB73_20_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_20_F"))
		i1 =  (1)
		i7 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_66_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_21_F"))
		__asm(push(i1==74), iftrue, target("_pubrealloc__XprivateX__BB73_53_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_22_F"))
		__asm(push(i1==82), iftrue, target("_pubrealloc__XprivateX__BB73_49_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_23_F"))
		__asm(push(i1==86), iftrue, target("_pubrealloc__XprivateX__BB73_24_F"))
		__asm(jump, target("_pubrealloc__XprivateX__BB73_35_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_24_F"))
		i0 =  (i0 + 1)
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_59_F"))
		__asm(jump, target("_pubrealloc__XprivateX__BB73_25_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_25_F"))
		i1 =  (1)
		i10 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_66_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_26_F"))
		__asm(push(i1>113), iftrue, target("_pubrealloc__XprivateX__BB73_32_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_27_F"))
		__asm(push(i1==90), iftrue, target("_pubrealloc__XprivateX__BB73_63_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_28_F"))
		__asm(push(i1==104), iftrue, target("_pubrealloc__XprivateX__BB73_42_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_29_F"))
		__asm(push(i1==106), iftrue, target("_pubrealloc__XprivateX__BB73_30_F"))
		__asm(jump, target("_pubrealloc__XprivateX__BB73_35_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_30_F"))
		i0 =  (i0 + 1)
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_52_F"))
		__asm(jump, target("_pubrealloc__XprivateX__BB73_31_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_31_F"))
		i1 =  (0)
		i9 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_66_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_32_F"))
		__asm(push(i1==114), iftrue, target("_pubrealloc__XprivateX__BB73_46_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_33_F"))
		__asm(push(i1==118), iftrue, target("_pubrealloc__XprivateX__BB73_56_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_34_F"))
		__asm(push(i1==122), iftrue, target("_pubrealloc__XprivateX__BB73_60_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_35_F"))
		i1 = i11
		__asm(jump, target("_pubrealloc__XprivateX__BB73_64_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_36_F"))
		i0 =  (i0 + 1)
		i1 =  (i12 << 1)
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_38_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_37_F"))
		__asm(jump, target("_pubrealloc__XprivateX__BB73_66_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_38_F"))
		i0 = i11
		__asm(jump, target("_pubrealloc__XprivateX__BB73_68_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_39_F"))
		i0 =  (i0 + 1)
		i1 =  (i12 >>> 1)
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_41_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_40_F"))
		__asm(jump, target("_pubrealloc__XprivateX__BB73_66_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_41_F"))
		i0 = i11
		__asm(jump, target("_pubrealloc__XprivateX__BB73_68_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_42_F"))
		i0 =  (i0 + 1)
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_44_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_43_F"))
		i1 =  (0)
		i7 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_66_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_44_F"))
		i1 =  (0)
		i0 = i11
		i7 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_68_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_45_F"))
		i1 =  (1)
		i0 = i11
		i7 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_68_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_46_F"))
		i0 =  (i0 + 1)
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_48_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_47_F"))
		i1 =  (0)
		i8 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_66_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_48_F"))
		i1 =  (0)
		i0 = i11
		i8 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_68_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_49_F"))
		i0 =  (i0 + 1)
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_51_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_50_F"))
		i1 =  (1)
		i8 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_66_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_51_F"))
		i1 =  (1)
		i0 = i11
		i8 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_68_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_52_F"))
		i1 =  (0)
		i0 = i11
		i9 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_68_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_53_F"))
		i0 =  (i0 + 1)
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_55_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_54_F"))
		i1 =  (1)
		i9 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_66_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_55_F"))
		i1 =  (1)
		i0 = i11
		i9 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_68_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_56_F"))
		i0 =  (i0 + 1)
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_58_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_57_F"))
		i1 =  (0)
		i10 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_66_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_58_F"))
		i1 =  (0)
		i0 = i11
		i10 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_68_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_59_F"))
		i1 =  (1)
		i0 = i11
		i10 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_68_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_60_F"))
		i0 =  (i0 + 1)
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_62_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_61_F"))
		i1 =  (0)
		i11 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_66_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_62_F"))
		i0 =  (0)
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_68_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_63_F"))
		i1 =  (1)
	__asm(lbl("_pubrealloc__XprivateX__BB73_64_F"))
		i0 =  (i0 + 1)
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_130_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_65_F"))
		i11 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_66_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_66_F"))
		i12 = i1
		i1 =  ((__xasm<int>(push(i0), op(0x35))))
		__asm(push(i1!=0), iftrue, target("_pubrealloc__XprivateX__BB73_14_B"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_67_F"))
		i0 = i11
		i1 = i12
	__asm(jump, target("_pubrealloc__XprivateX__BB73_68_F"), lbl("_pubrealloc__XprivateX__BB73_68_B"), label, lbl("_pubrealloc__XprivateX__BB73_68_F")); 
		__asm(push(i1), push(_malloc_cache), op(0x3c))
		__asm(push(i7), push(_malloc_hint_2E_b), op(0x3a))
		__asm(push(i8), push(_malloc_realloc_2E_b), op(0x3a))
		__asm(push(i9), push(_malloc_junk_2E_b), op(0x3a))
		__asm(push(i10), push(_malloc_sysv_2E_b), op(0x3a))
		__asm(push(i0), push(_malloc_zero_2E_b), op(0x3a))
	__asm(lbl("_pubrealloc__XprivateX__BB73_69_F"))
		i0 =  (i6 + 1)
		__asm(push(i0==3), iftrue, target("_pubrealloc__XprivateX__BB73_71_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_70_F"))
		__asm(jump, target("_pubrealloc__XprivateX__BB73_9_B"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_71_F"))
		i0 =  ((__xasm<int>(push(_malloc_zero_2E_b), op(0x35))))
		i0 =  (i0 ^ 1)
		i0 =  (i0 & 1)
		__asm(push(i0!=0), iftrue, target("_pubrealloc__XprivateX__BB73_73_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_72_F"))
		i0 =  (1)
		__asm(push(i0), push(_malloc_junk_2E_b), op(0x3a))
	__asm(lbl("_pubrealloc__XprivateX__BB73_73_F"))
		i0 =  (__2E_str210)
		i1 =  (4)
		i5 =  (0)
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		i0 = _sbrk(i5)
		i0 =  (i0 & 4095)
		i0 =  (4096 - i0)
		i0 =  (i0 & 4095)
		i0 = _sbrk(i0)
		i0 =  (4096)
		i0 = _sbrk(i0)
		__asm(push(i0), push(_page_dir), op(0x3c))
		i0 = i5
		i0 = _sbrk(i0)
		i0 =  (i0 + 4095)
		i0 =  (i0 >>> 12)
		i0 =  (i0 + -12)
		__asm(push(i0), push(_malloc_origo), op(0x3c))
		i0 =  (1024)
		__asm(push(i0), push(_malloc_ninfo), op(0x3c))
		i0 =  ((__xasm<int>(push(_malloc_cache), op(0x37))))
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_75_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_74_F"))
		__asm(jump, target("_pubrealloc__XprivateX__BB73_76_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_75_F"))
		i0 =  (i0 + 1)
		__asm(push(i0), push(_malloc_cache), op(0x3c))
	__asm(lbl("_pubrealloc__XprivateX__BB73_76_F"))
		i1 =  (20)
		i0 =  (i0 << 12)
		__asm(push(i0), push(_malloc_cache), op(0x3c))
		mstate.esp -= 4
		__asm(push(i1), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM_imalloc.start()
	__asm(lbl("_pubrealloc_state3"))
		i0 = mstate.eax
		mstate.esp += 4
		__asm(push(i0), push(_px), op(0x3c))
		__asm(push(i4), push(_val_2E_1440), op(0x3c))
		i0 =  (1)
		__asm(push(i0), push(_malloc_started_2E_3510_2E_b), op(0x3a))
	__asm(lbl("_pubrealloc__XprivateX__BB73_77_F"))
		i0 =  ((__xasm<int>(push(_malloc_sysv_2E_b), op(0x35))))
		i1 =  ((i2==2048) ? 0 : i2)
		i0 =  (i0 ^ 1)
		i0 =  (i0 & 1)
		__asm(push(i0!=0), iftrue, target("_pubrealloc__XprivateX__BB73_82_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_78_F"))
		__asm(push(i3!=0), iftrue, target("_pubrealloc__XprivateX__BB73_82_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_79_F"))
		__asm(push(i1!=0), iftrue, target("_pubrealloc__XprivateX__BB73_81_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_80_F"))
		i1 =  (0)
		i3 = i1
		__asm(jump, target("_pubrealloc__XprivateX__BB73_125_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_81_F"))
		i3 =  (0)
		mstate.esp -= 4
		__asm(push(i1), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM_ifree.start()
	__asm(lbl("_pubrealloc_state4"))
		mstate.esp += 4
		__asm(push(i3), push(_malloc_active_2E_3509), op(0x3c))
		i1 = i3
		i0 = i1
		i1 = i3
		__asm(jump, target("_pubrealloc__XprivateX__BB73_126_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_82_F"))
		__asm(push(i3!=0), iftrue, target("_pubrealloc__XprivateX__BB73_86_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_83_F"))
		__asm(push(i1!=0), iftrue, target("_pubrealloc__XprivateX__BB73_85_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_84_F"))
		i3 =  (2048)
		i1 =  (0)
		__asm(jump, target("_pubrealloc__XprivateX__BB73_125_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_85_F"))
		i3 =  (0)
		mstate.esp -= 4
		__asm(push(i1), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM_ifree.start()
	__asm(lbl("_pubrealloc_state5"))
		mstate.esp += 4
		__asm(push(i3), push(_malloc_active_2E_3509), op(0x3c))
		i1 =  (2048)
		i0 = i3
		__asm(jump, target("_pubrealloc__XprivateX__BB73_126_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_86_F"))
		__asm(push(i1!=0), iftrue, target("_pubrealloc__XprivateX__BB73_88_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_87_F"))
		i1 =  (0)
		mstate.esp -= 4
		__asm(push(i3), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM_imalloc.start()
	__asm(lbl("_pubrealloc_state6"))
		i3 = mstate.eax
		mstate.esp += 4
		i0 =  ((i3==0) ? 1 : 0)
		__asm(push(i1), push(_malloc_active_2E_3509), op(0x3c))
		i1 =  (i0 & 1)
		i0 = i1
		i1 = i3
		__asm(jump, target("_pubrealloc__XprivateX__BB73_126_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_88_F"))
		i0 =  ((__xasm<int>(push(_malloc_origo), op(0x37))))
		i2 =  (i1 >>> 12)
		i4 =  (i2 - i0)
		i5 = i1
		__asm(push(uint(i4)>uint(11)), iftrue, target("_pubrealloc__XprivateX__BB73_90_F"))
	__asm(jump, target("_pubrealloc__XprivateX__BB73_89_F"), lbl("_pubrealloc__XprivateX__BB73_89_B"), label, lbl("_pubrealloc__XprivateX__BB73_89_F")); 
		i1 =  (0)
		__asm(jump, target("_pubrealloc__XprivateX__BB73_124_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_90_F"))
		i6 =  ((__xasm<int>(push(_last_index), op(0x37))))
		__asm(push(uint(i4)>uint(i6)), iftrue, target("_pubrealloc__XprivateX__BB73_89_B"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_91_F"))
		i6 =  ((__xasm<int>(push(_page_dir), op(0x37))))
		i7 =  (i4 << 2)
		i7 =  (i6 + i7)
		i7 =  ((__xasm<int>(push(i7), op(0x37))))
		i8 = i6
		__asm(push(i7!=2), iftrue, target("_pubrealloc__XprivateX__BB73_108_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_92_F"))
		i5 =  (i5 & 4095)
		__asm(push(i5!=0), iftrue, target("_pubrealloc__XprivateX__BB73_89_B"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_93_F"))
		i5 =  (i4 << 2)
		i5 =  (i5 + i8)
		i5 =  ((__xasm<int>(push((i5+4)), op(0x37))))
		__asm(push(i5==3), iftrue, target("_pubrealloc__XprivateX__BB73_95_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_94_F"))
		i0 =  (4096)
		__asm(jump, target("_pubrealloc__XprivateX__BB73_99_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_95_F"))
		i5 =  (-1)
		i0 =  (i2 - i0)
		i0 =  (i0 << 2)
		i0 =  (i0 + i6)
		i0 =  (i0 + 8)
	__asm(jump, target("_pubrealloc__XprivateX__BB73_96_F"), lbl("_pubrealloc__XprivateX__BB73_96_B"), label, lbl("_pubrealloc__XprivateX__BB73_96_F")); 
		i7 =  ((__xasm<int>(push(i0), op(0x37))))
		i0 =  (i0 + 4)
		i5 =  (i5 + 1)
		__asm(push(i7!=3), iftrue, target("_pubrealloc__XprivateX__BB73_98_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_97_F"))
		__asm(jump, target("_pubrealloc__XprivateX__BB73_96_B"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_98_F"))
		i0 =  (i5 << 12)
		i0 =  (i0 + 8192)
	__asm(lbl("_pubrealloc__XprivateX__BB73_99_F"))
		i5 =  ((__xasm<int>(push(_malloc_realloc_2E_b), op(0x35))))
		__asm(push(i5!=0), iftrue, target("_pubrealloc__XprivateX__BB73_101_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_100_F"))
		__asm(push(uint(i0)>=uint(i3)), iftrue, target("_pubrealloc__XprivateX__BB73_104_F"))
	__asm(jump, target("_pubrealloc__XprivateX__BB73_101_F"), lbl("_pubrealloc__XprivateX__BB73_101_B"), label, lbl("_pubrealloc__XprivateX__BB73_101_F")); 
		__asm(jump, target("_pubrealloc__XprivateX__BB73_102_F"))
	__asm(jump, target("_pubrealloc__XprivateX__BB73_102_F"), lbl("_pubrealloc__XprivateX__BB73_102_B"), label, lbl("_pubrealloc__XprivateX__BB73_102_F")); 
		mstate.esp -= 4
		__asm(push(i3), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM_imalloc.start()
	__asm(lbl("_pubrealloc_state7"))
		i2 = mstate.eax
		mstate.esp += 4
		__asm(push(i2!=0), iftrue, target("_pubrealloc__XprivateX__BB73_118_F"))
		__asm(jump, target("_pubrealloc__XprivateX__BB73_103_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_103_F"))
		i1 = i2
		__asm(jump, target("_pubrealloc__XprivateX__BB73_124_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_104_F"))
		i5 =  (i0 + -4096)
		__asm(push(uint(i5)>=uint(i3)), iftrue, target("_pubrealloc__XprivateX__BB73_101_B"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_105_F"))
		i5 =  ((__xasm<int>(push(_malloc_junk_2E_b), op(0x35))))
		__asm(push(i5!=0), iftrue, target("_pubrealloc__XprivateX__BB73_107_F"))
	__asm(jump, target("_pubrealloc__XprivateX__BB73_106_F"), lbl("_pubrealloc__XprivateX__BB73_106_B"), label, lbl("_pubrealloc__XprivateX__BB73_106_F")); 
		__asm(jump, target("_pubrealloc__XprivateX__BB73_124_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_107_F"))
		i5 =  (-48)
		i7 =  (i1 + i3)
		i0 =  (i0 - i3)
		i3 =  ((i1==0) ? 1 : 0)
		memset(i7, i5, i0)
		i0 =  (0)
		__asm(push(i0), push(_malloc_active_2E_3509), op(0x3c))
		i0 =  (i3 & 1)
		__asm(jump, target("_pubrealloc__XprivateX__BB73_126_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_108_F"))
		__asm(push(uint(i7)<uint(4)), iftrue, target("_pubrealloc__XprivateX__BB73_89_B"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_109_F"))
		i0 =  ((__xasm<int>(push((i7+8)), op(0x36))))
		i2 = i0
		i4 =  (i0 + -1)
		i4 =  (i4 & i5)
		__asm(push(i4!=0), iftrue, target("_pubrealloc__XprivateX__BB73_89_B"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_110_F"))
		i4 =  (1)
		i6 =  ((__xasm<int>(push((i7+10)), op(0x36))))
		i5 =  (i5 & 4095)
		i5 =  (i5 >>> i6)
		i6 =  (i5 & -32)
		i6 =  (i6 >>> 3)
		i5 =  (i5 & 31)
		i6 =  (i7 + i6)
		i6 =  ((__xasm<int>(push((i6+16)), op(0x37))))
		i4 =  (i4 << i5)
		i4 =  (i4 & i6)
		__asm(push(i4!=0), iftrue, target("_pubrealloc__XprivateX__BB73_89_B"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_111_F"))
		i4 =  ((__xasm<int>(push(_malloc_realloc_2E_b), op(0x35))))
		__asm(push(uint(i2)<uint(i3)), iftrue, target("_pubrealloc__XprivateX__BB73_113_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_112_F"))
		i4 =  (i4 ^ 1)
		i4 =  (i4 & 1)
		__asm(push(i4!=0), iftrue, target("_pubrealloc__XprivateX__BB73_114_F"))
	__asm(jump, target("_pubrealloc__XprivateX__BB73_113_F"), lbl("_pubrealloc__XprivateX__BB73_113_B"), label, lbl("_pubrealloc__XprivateX__BB73_113_F")); 
		i0 = i2
		__asm(jump, target("_pubrealloc__XprivateX__BB73_102_B"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_114_F"))
		i4 =  (i2 >>> 1)
		__asm(push(uint(i4)<uint(i3)), iftrue, target("_pubrealloc__XprivateX__BB73_116_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_115_F"))
		i0 =  (i0 & 65535)
		__asm(push(i0!=16), iftrue, target("_pubrealloc__XprivateX__BB73_113_B"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_116_F"))
		i0 =  ((__xasm<int>(push(_malloc_junk_2E_b), op(0x35))))
		i0 =  (i0 ^ 1)
		i0 =  (i0 & 1)
		__asm(push(i0!=0), iftrue, target("_pubrealloc__XprivateX__BB73_106_B"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_117_F"))
		i0 =  (-48)
		i4 =  (i1 + i3)
		i3 =  (i2 - i3)
		i2 =  ((i1==0) ? 1 : 0)
		memset(i4, i0, i3)
		i0 =  (0)
		__asm(push(i0), push(_malloc_active_2E_3509), op(0x3c))
		i0 =  (i2 & 1)
		__asm(jump, target("_pubrealloc__XprivateX__BB73_126_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_118_F"))
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_123_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_119_F"))
		__asm(push(i3==0), iftrue, target("_pubrealloc__XprivateX__BB73_123_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_120_F"))
		__asm(push(uint(i0)>=uint(i3)), iftrue, target("_pubrealloc__XprivateX__BB73_122_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_121_F"))
		i3 =  (0)
		i4 = i2
		i5 = i1
		memcpy(i4, i5, i0)
		mstate.esp -= 4
		__asm(push(i1), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM_ifree.start()
	__asm(lbl("_pubrealloc_state8"))
		mstate.esp += 4
		i1 =  ((i2==0) ? 1 : 0)
		__asm(push(i3), push(_malloc_active_2E_3509), op(0x3c))
		i1 =  (i1 & 1)
		i0 = i1
		i1 = i2
		__asm(jump, target("_pubrealloc__XprivateX__BB73_126_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_122_F"))
		i0 = i2
		i4 = i1
		memcpy(i0, i4, i3)
	__asm(lbl("_pubrealloc__XprivateX__BB73_123_F"))
		mstate.esp -= 4
		__asm(push(i1), push(mstate.esp), op(0x3c))
		mstate.esp -= 4;FSM_ifree.start()
	__asm(lbl("_pubrealloc_state9"))
		mstate.esp += 4
		i1 = i2
	__asm(lbl("_pubrealloc__XprivateX__BB73_124_F"))
		i0 = i1
		i1 =  ((i0==0) ? 1 : 0)
		i1 =  (i1 & 1)
		i3 = i0
	__asm(lbl("_pubrealloc__XprivateX__BB73_125_F"))
		i0 = i1
		i1 = i3
		i2 =  (0)
		__asm(push(i2), push(_malloc_active_2E_3509), op(0x3c))
	__asm(lbl("_pubrealloc__XprivateX__BB73_126_F"))
		__asm(push(i0==0), iftrue, target("_pubrealloc__XprivateX__BB73_128_F"))
	__asm(lbl("_pubrealloc__XprivateX__BB73_127_F"))
		i0 =  (12)
		__asm(push(i0), push(_val_2E_1440), op(0x3c))
	__asm(lbl("_pubrealloc__XprivateX__BB73_128_F"))
		mstate.eax = i1
	__asm(lbl("_pubrealloc__XprivateX__BB73_129_F"))
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("_pubrealloc__XprivateX__BB73_130_F"))
		i0 = i1
		i1 = i12
		__asm(jump, target("_pubrealloc__XprivateX__BB73_68_B"))
	__asm(lbl("_pubrealloc_errState"))
		throw("Invalid state in _pubrealloc")
	}
}



// Async
public const _malloc:int = regFunc(FSM_malloc.start)

public final class FSM_malloc extends Machine {

	public static function start():void {
			var result:FSM_malloc = new FSM_malloc
		gstate.gworker = result
	}

	public var i0:int, i1:int

	public static const intRegCount:int = 2

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("_malloc_entry"))
		__asm(push(state), switchjump(
			"_malloc_errState",
			"_malloc_state0",
			"_malloc_state1"))
	__asm(lbl("_malloc_state0"))
	__asm(lbl("_malloc__XprivateX__BB74_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  (0)
		mstate.esp -= 8
		i1 =  ((__xasm<int>(push((mstate.ebp+8)), op(0x37))))
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		state = 1
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("_malloc_state1"))
		i0 = mstate.eax
		mstate.esp += 8
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("_malloc_errState"))
		throw("Invalid state in _malloc")
	}
}



// Async
public const _InitLibrary:int = regFunc(FSM_InitLibrary.start)

public final class FSM_InitLibrary extends Machine {

	public static function start():void {
			var result:FSM_InitLibrary = new FSM_InitLibrary
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int

	public static const intRegCount:int = 3

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("_InitLibrary_entry"))
		__asm(push(state), switchjump(
			"_InitLibrary_errState",
			"_InitLibrary_state0",
			"_InitLibrary_state1",
			"_InitLibrary_state2"))
	__asm(lbl("_InitLibrary_state0"))
	__asm(lbl("_InitLibrary__XprivateX__BB75_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 4
		i0 =  (0)
		__asm(push(i0), push((mstate.ebp+-4)), op(0x3c))
		mstate.esp -= 12
		i0 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		i1 =  (__2E_str99)
		i2 =  ((mstate.ebp+-4))
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i1), push((mstate.esp+4)), op(0x3c))
		__asm(push(i2), push((mstate.esp+8)), op(0x3c))
		state = 1
		mstate.esp -= 4;(mstate.funcs[_AS3_ArrayValue])()
		return
	__asm(lbl("_InitLibrary_state1"))
		mstate.esp += 12
		i0 =  ((__xasm<int>(push((mstate.ebp+-4)), op(0x37))))
		__asm(push(i0==1), iftrue, target("_InitLibrary__XprivateX__BB75_3_F"))
	__asm(lbl("_InitLibrary__XprivateX__BB75_1_F"))
		i0 =  (65551)
	__asm(jump, target("_InitLibrary__XprivateX__BB75_2_F"), lbl("_InitLibrary__XprivateX__BB75_2_B"), label, lbl("_InitLibrary__XprivateX__BB75_2_F")); 
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 2
		mstate.esp -= 4;(mstate.funcs[_AS3_Int])()
		return
	__asm(lbl("_InitLibrary_state2"))
		i0 = mstate.eax
		mstate.esp += 4
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("_InitLibrary__XprivateX__BB75_3_F"))
		i0 =  (0)
		__asm(jump, target("_InitLibrary__XprivateX__BB75_2_B"))
	__asm(lbl("_InitLibrary_errState"))
		throw("Invalid state in _InitLibrary")
	}
}



// Async
public const _HaltOperation:int = regFunc(FSM_HaltOperation.start)

public final class FSM_HaltOperation extends Machine {

	public static function start():void {
			var result:FSM_HaltOperation = new FSM_HaltOperation
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int

	public static const intRegCount:int = 5

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("_HaltOperation_entry"))
		__asm(push(state), switchjump(
			"_HaltOperation_errState",
			"_HaltOperation_state0",
			"_HaltOperation_state1",
			"_HaltOperation_state2",
			"_HaltOperation_state3",
			"_HaltOperation_state4",
			"_HaltOperation_state5",
			"_HaltOperation_state6",
			"_HaltOperation_state7",
			"_HaltOperation_state8",
			"_HaltOperation_state9",
			"_HaltOperation_state10"))
	__asm(lbl("_HaltOperation_state0"))
	__asm(lbl("_HaltOperation__XprivateX__BB76_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 0
		i0 =  (__2E_str1100)
		mstate.esp -= 12
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		//IMPLICIT_DEF i2 = 
		__asm(push(i1), push(mstate.esp), op(0x3c))
		__asm(push(i0), push((mstate.esp+4)), op(0x3c))
		__asm(push(i2), push((mstate.esp+8)), op(0x3c))
		state = 1
		mstate.esp -= 4;(mstate.funcs[_AS3_ArrayValue])()
		return
	__asm(lbl("_HaltOperation_state1"))
		mstate.esp += 12
		mstate.esp -= 8
		i0 =  (__2E_str2101)
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i0), push((mstate.esp+4)), op(0x3c))
		state = 2
		mstate.esp -= 4;(mstate.funcs[_AS3_GetS])()
		return
	__asm(lbl("_HaltOperation_state2"))
		i0 = mstate.eax
		mstate.esp += 8
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 3
		mstate.esp -= 4;(mstate.funcs[_AS3_PtrValue])()
		return
	__asm(lbl("_HaltOperation_state3"))
		i0 = mstate.eax
		mstate.esp += 4
		i1 = i0
		__asm(push(i0==0), iftrue, target("_HaltOperation__XprivateX__BB76_4_F"))
	__asm(lbl("_HaltOperation__XprivateX__BB76_1_F"))
		i2 =  (__2E_str2101)
		state = 4
		mstate.esp -= 4;(mstate.funcs[_AS3_Null])()
		return
	__asm(lbl("_HaltOperation_state4"))
		i3 = mstate.eax
		mstate.esp -= 12
		//IMPLICIT_DEF i4 = 
		__asm(push(i4), push(mstate.esp), op(0x3c))
		__asm(push(i2), push((mstate.esp+4)), op(0x3c))
		__asm(push(i3), push((mstate.esp+8)), op(0x3c))
		state = 5
		mstate.esp -= 4;(mstate.funcs[_AS3_SetS])()
		return
	__asm(lbl("_HaltOperation_state5"))
		i2 = mstate.eax
		mstate.esp += 12
		i2 =  ((__xasm<int>(push(i0), op(0x37))))
		__asm(push(i2==0), iftrue, target("_HaltOperation__XprivateX__BB76_3_F"))
	__asm(lbl("_HaltOperation__XprivateX__BB76_2_F"))
		mstate.esp -= 4
		__asm(push(i2), push(mstate.esp), op(0x3c))
		state = 6
		mstate.esp -= 4;(mstate.funcs[_DNSServiceRefDeallocate])()
		return
	__asm(lbl("_HaltOperation_state6"))
		mstate.esp += 4
	__asm(lbl("_HaltOperation__XprivateX__BB76_3_F"))
		i2 =  (0)
		i3 =  ((__xasm<int>(push((i1+4)), op(0x37))))
		mstate.esp -= 4
		__asm(push(i3), push(mstate.esp), op(0x3c))
		state = 7
		mstate.esp -= 4;(mstate.funcs[_AS3_Release])()
		return
	__asm(lbl("_HaltOperation_state7"))
		mstate.esp += 4
		i1 =  ((__xasm<int>(push((i1+8)), op(0x37))))
		mstate.esp -= 4
		__asm(push(i1), push(mstate.esp), op(0x3c))
		state = 8
		mstate.esp -= 4;(mstate.funcs[_AS3_Release])()
		return
	__asm(lbl("_HaltOperation_state8"))
		mstate.esp += 4
		mstate.esp -= 8
		__asm(push(i0), push(mstate.esp), op(0x3c))
		__asm(push(i2), push((mstate.esp+4)), op(0x3c))
		state = 9
		mstate.esp -= 4;FSM_pubrealloc.start()
		return
	__asm(lbl("_HaltOperation_state9"))
		i0 = mstate.eax
		mstate.esp += 8
	__asm(lbl("_HaltOperation__XprivateX__BB76_4_F"))
		state = 10
		mstate.esp -= 4;(mstate.funcs[_AS3_Undefined])()
		return
	__asm(lbl("_HaltOperation_state10"))
		i0 = mstate.eax
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("_HaltOperation_errState"))
		throw("Invalid state in _HaltOperation")
	}
}



// Async
public const _BlockForData:int = regFunc(FSM_BlockForData.start)

public final class FSM_BlockForData extends Machine {

	public static function start():void {
			var result:FSM_BlockForData = new FSM_BlockForData
		gstate.gworker = result
	}

	public var i0:int, i1:int, i2:int, i3:int, i4:int

	public static const intRegCount:int = 5

	public static const NumberRegCount:int = 0
	public final override function work():void {
		Alchemy::SetjmpAbuse { freezeCache = 0; }
		__asm(label, lbl("_BlockForData_entry"))
		__asm(push(state), switchjump(
			"_BlockForData_errState",
			"_BlockForData_state0",
			"_BlockForData_state1",
			"_BlockForData_state2",
			"_BlockForData_state3",
			"_BlockForData_state4",
			"_BlockForData_state5",
			"_BlockForData_state6"))
	__asm(lbl("_BlockForData_state0"))
	__asm(lbl("_BlockForData__XprivateX__BB77_0_F"))
		mstate.esp -= 4; __asm(push(mstate.ebp), push(mstate.esp), op(0x3c))
		mstate.ebp = mstate.esp
		mstate.esp -= 4224
		i0 =  (__2E_str1100)
		mstate.esp -= 12
		i1 =  ((__xasm<int>(push((mstate.ebp+12)), op(0x37))))
		//IMPLICIT_DEF i2 = 
		__asm(push(i1), push(mstate.esp), op(0x3c))
		__asm(push(i0), push((mstate.esp+4)), op(0x3c))
		__asm(push(i2), push((mstate.esp+8)), op(0x3c))
		state = 1
		mstate.esp -= 4;(mstate.funcs[_AS3_ArrayValue])()
		return
	__asm(lbl("_BlockForData_state1"))
		mstate.esp += 12
		mstate.esp -= 8
		i0 =  (__2E_str2101)
		__asm(push(i2), push(mstate.esp), op(0x3c))
		__asm(push(i0), push((mstate.esp+4)), op(0x3c))
		state = 2
		mstate.esp -= 4;(mstate.funcs[_AS3_GetS])()
		return
	__asm(lbl("_BlockForData_state2"))
		i0 = mstate.eax
		mstate.esp += 8
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 3
		mstate.esp -= 4;(mstate.funcs[_AS3_PtrValue])()
		return
	__asm(lbl("_BlockForData_state3"))
		i0 = mstate.eax
		mstate.esp += 4
		i1 =  ((mstate.ebp+-4224))
		__asm(push(i0==0), iftrue, target("_BlockForData__XprivateX__BB77_5_F"))
	__asm(lbl("_BlockForData__XprivateX__BB77_1_F"))
		i2 =  (0)
		i0 =  ((__xasm<int>(push(i0), op(0x37))))
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 4
		mstate.esp -= 4;(mstate.funcs[_DNSServiceRefSockFD])()
		return
	__asm(lbl("_BlockForData_state4"))
		i0 = mstate.eax
		mstate.esp += 4
		i1 =  (i1 + 124)
	__asm(jump, target("_BlockForData__XprivateX__BB77_2_F"), lbl("_BlockForData__XprivateX__BB77_2_B"), label, lbl("_BlockForData__XprivateX__BB77_2_F")); 
		i3 =  (0)
		__asm(push(i3), push(i1), op(0x3c))
		i1 =  (i1 + -4)
		i2 =  (i2 + 1)
		__asm(push(i2==32), iftrue, target("_BlockForData__XprivateX__BB77_4_F"))
	__asm(lbl("_BlockForData__XprivateX__BB77_3_F"))
		__asm(jump, target("_BlockForData__XprivateX__BB77_2_B"))
	__asm(lbl("_BlockForData__XprivateX__BB77_4_F"))
		i1 =  ((mstate.ebp+-4224))
		i2 =  (i0 & -32)
		i2 =  (i2 >>> 3)
		i3 =  (1)
		i0 =  (i0 & 31)
		i1 =  (i1 + i2)
		i2 =  ((__xasm<int>(push(i1), op(0x37))))
		i0 =  (i3 << i0)
		i0 =  (i2 | i0)
		__asm(push(i0), push(i1), op(0x3c))
		i0 =  (__2E_str25)
		i1 =  (4)
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		mstate.esp -= 20
		i0 =  (__2E_str96)
		i1 =  (__2E_str126)
		i2 =  (9)
		i3 =  (78)
		i4 =  ((mstate.ebp+-4096))
		__asm(push(i4), push(mstate.esp), op(0x3c))
		__asm(push(i0), push((mstate.esp+4)), op(0x3c))
		__asm(push(i3), push((mstate.esp+8)), op(0x3c))
		__asm(push(i1), push((mstate.esp+12)), op(0x3c))
		__asm(push(i2), push((mstate.esp+16)), op(0x3c))
		state = 5
		mstate.esp -= 4;FSM_sprintf.start()
		return
	__asm(lbl("_BlockForData_state5"))
		mstate.esp += 20
		i1 =  (3)
		i0 = i4
		//InlineAsmStart
	log(i1, mstate.gworker.stringFromPtr(i0))
	//InlineAsmEnd
		__asm(push(i3), push(_val_2E_1440), op(0x3c))
	__asm(lbl("_BlockForData__XprivateX__BB77_5_F"))
		i0 =  (0)
		mstate.esp -= 4
		__asm(push(i0), push(mstate.esp), op(0x3c))
		state = 6
		mstate.esp -= 4;(mstate.funcs[_AS3_Int])()
		return
	__asm(lbl("_BlockForData_state6"))
		i0 = mstate.eax
		mstate.esp += 4
		mstate.eax = i0
		mstate.esp = mstate.ebp
		mstate.ebp = __xasm<int>(push(mstate.esp), op(0x37)); mstate.esp += 4
		//RETL
		mstate.esp += 4
		mstate.gworker = caller
		return
	__asm(lbl("_BlockForData_errState"))
		throw("Invalid state in _BlockForData")
	}
}



// External functions
var _AS3_ArrayValue:int
var _AS3_Int:int
var _AS3_GetS:int
var _AS3_PtrValue:int
var _AS3_Null:int
var _AS3_SetS:int
var _DNSServiceRefDeallocate:int
var _AS3_Release:int
var _AS3_Undefined:int
var _DNSServiceRefSockFD:int
var _AS3_False:int
var _AS3_Function:int
var _AS3_Object:int
var _abort:int

// Global variables
const __2E_str:int = gstaticInitter.alloc(6, 1)
const __2E_str1:int = gstaticInitter.alloc(6, 1)
const _val_2E_1440:int = gstaticInitter.alloc(4, 4)
const __2E_str8:int = gstaticInitter.alloc(8, 1)
const __2E_str19:int = gstaticInitter.alloc(7, 1)
const __2E_str210:int = gstaticInitter.alloc(10, 1)
const __2E_str25:int = gstaticInitter.alloc(7, 1)
const __2E_str126:int = gstaticInitter.alloc(14, 1)
const __2E_str37:int = gstaticInitter.alloc(5, 1)
const __2E_str138:int = gstaticInitter.alloc(14, 1)
const __2E_str340:int = gstaticInitter.alloc(12, 1)
const __2E_str643:int = gstaticInitter.alloc(10, 1)
const __2E_str251:int = gstaticInitter.alloc(12, 1)
const __2E_str876:int = gstaticInitter.alloc(10, 1)
const __2E_str977:int = gstaticInitter.alloc(7, 1)
const __2E_str13:int = gstaticInitter.alloc(14, 1)
const __2E_str96:int = gstaticInitter.alloc(23, 1)
const _environ:int = gstaticInitter.alloc(4, 4)
const __2E_str159:int = gstaticInitter.alloc(9, 1)
const __2E_str260:int = gstaticInitter.alloc(4, 1)
const ___tens_D2A:int = gstaticInitter.alloc(184, 8)
const ___bigtens_D2A:int = gstaticInitter.alloc(40, 8)
const _freelist:int = gstaticInitter.alloc(64, 4)
const _pmem_next:int = gstaticInitter.alloc(4, 4)
const _private_mem:int = gstaticInitter.alloc(2304, 8)
const _p05_2E_3773:int = gstaticInitter.alloc(12, 4)
const _p5s:int = gstaticInitter.alloc(4, 4)
const ___mlocale_changed_2E_b:int = gstaticInitter.alloc(1, 1)
const __2E_str20159:int = gstaticInitter.alloc(2, 1)
const _numempty22:int = gstaticInitter.alloc(2, 1)
const ___nlocale_changed_2E_b:int = gstaticInitter.alloc(1, 1)
const _ret_2E_1494_2E_0_2E_b:int = gstaticInitter.alloc(1, 1)
const _ret_2E_1494_2E_2_2E_b:int = gstaticInitter.alloc(1, 1)
const ___sF:int = gstaticInitter.alloc(264, 8)
const ___sdidinit_2E_b:int = gstaticInitter.alloc(1, 1)
const _usual_extra:int = gstaticInitter.alloc(2516, 8)
const _usual:int = gstaticInitter.alloc(1496, 8)
const ___cleanup_2E_b:int = gstaticInitter.alloc(1, 1)
const ___sglue:int = gstaticInitter.alloc(12, 8)
const _uglue:int = gstaticInitter.alloc(12, 8)
const ___sFX:int = gstaticInitter.alloc(444, 8)
const _initial_2E_4576:int = gstaticInitter.alloc(128, 8)
const _xdigs_lower_2E_4528:int = gstaticInitter.alloc(17, 1)
const _xdigs_upper_2E_4529:int = gstaticInitter.alloc(17, 1)
const __2E_str118283:int = gstaticInitter.alloc(4, 1)
const __2E_str219284:int = gstaticInitter.alloc(4, 1)
const __2E_str320285:int = gstaticInitter.alloc(4, 1)
const __2E_str421:int = gstaticInitter.alloc(4, 1)
const __2E_str522:int = gstaticInitter.alloc(7, 1)
const _blanks_2E_4526:int = gstaticInitter.alloc(16, 1)
const _zeroes_2E_4527:int = gstaticInitter.alloc(16, 1)
const ___atexit:int = gstaticInitter.alloc(4, 4)
const ___atexit0_2E_3021:int = gstaticInitter.alloc(520, 8)
const _free_list:int = gstaticInitter.alloc(20, 8)
const _malloc_origo:int = gstaticInitter.alloc(4, 4)
const _last_index:int = gstaticInitter.alloc(4, 4)
const _malloc_brk:int = gstaticInitter.alloc(4, 4)
const _malloc_ninfo:int = gstaticInitter.alloc(4, 4)
const _page_dir:int = gstaticInitter.alloc(4, 4)
const _malloc_junk_2E_b:int = gstaticInitter.alloc(1, 1)
const _px:int = gstaticInitter.alloc(4, 4)
const _malloc_zero_2E_b:int = gstaticInitter.alloc(1, 1)
const _malloc_hint_2E_b:int = gstaticInitter.alloc(1, 1)
const _malloc_cache:int = gstaticInitter.alloc(4, 4)
const _malloc_active_2E_3509:int = gstaticInitter.alloc(4, 4)
const _malloc_started_2E_3510_2E_b:int = gstaticInitter.alloc(1, 1)
const __2E_str113335:int = gstaticInitter.alloc(15, 1)
const _malloc_realloc_2E_b:int = gstaticInitter.alloc(1, 1)
const _malloc_sysv_2E_b:int = gstaticInitter.alloc(1, 1)
const __2E_str7403:int = gstaticInitter.alloc(13, 1)
const __2E_str99:int = gstaticInitter.alloc(8, 1)
const __2E_str1100:int = gstaticInitter.alloc(11, 1)
const __2E_str2101:int = gstaticInitter.alloc(15, 1)
const __2E_str3102:int = gstaticInitter.alloc(88, 1)


public function modStaticInit():void {
	_AS3_ArrayValue = importSym("_AS3_ArrayValue")
	_AS3_Int = importSym("_AS3_Int")
	_AS3_GetS = importSym("_AS3_GetS")
	_AS3_PtrValue = importSym("_AS3_PtrValue")
	_AS3_Null = importSym("_AS3_Null")
	_AS3_SetS = importSym("_AS3_SetS")
	_DNSServiceRefDeallocate = importSym("_DNSServiceRefDeallocate")
	_AS3_Release = importSym("_AS3_Release")
	_AS3_Undefined = importSym("_AS3_Undefined")
	_DNSServiceRefSockFD = importSym("_DNSServiceRefSockFD")
	_AS3_False = importSym("_AS3_False")
	_AS3_Function = importSym("_AS3_Function")
	_AS3_Object = importSym("_AS3_Object")
	_abort = importSym("_abort")
	modPreStaticInit()
	gstaticInitter.start(__2E_str)
	gstaticInitter.asciz = "_fini"
	gstaticInitter.start(__2E_str1)
	gstaticInitter.asciz = "_init"
	gstaticInitter.start(_val_2E_1440)
	gstaticInitter.zero = 4
	gstaticInitter.start(__2E_str8)
	gstaticInitter.asciz = "madvise"
	gstaticInitter.start(__2E_str19)
	gstaticInitter.asciz = "munmap"
	gstaticInitter.start(__2E_str210)
	gstaticInitter.asciz = "mmap anon"
	gstaticInitter.start(__2E_str25)
	gstaticInitter.asciz = "select"
	gstaticInitter.start(__2E_str126)
	gstaticInitter.asciz = "select_glue.c"
	gstaticInitter.start(__2E_str37)
	gstaticInitter.asciz = "kill"
	gstaticInitter.start(__2E_str138)
	gstaticInitter.asciz = "signal_glue.c"
	gstaticInitter.start(__2E_str340)
	gstaticInitter.asciz = "sigprocmask"
	gstaticInitter.start(__2E_str643)
	gstaticInitter.asciz = "sigaction"
	gstaticInitter.start(__2E_str251)
	gstaticInitter.asciz = "stat_glue.c"
	gstaticInitter.start(__2E_str876)
	gstaticInitter.asciz = "issetugid"
	gstaticInitter.start(__2E_str977)
	gstaticInitter.asciz = "getpid"
	gstaticInitter.start(__2E_str13)
	gstaticInitter.asciz = "unistd_glue.c"
	gstaticInitter.start(__2E_str96)
	gstaticInitter.asciz = "__seterrno(%d, %s, %d)"
	gstaticInitter.start(_environ)
	gstaticInitter.zero = 4
	gstaticInitter.start(__2E_str159)
	gstaticInitter.asciz = "Infinity"
	gstaticInitter.start(__2E_str260)
	gstaticInitter.asciz = "NaN"
	gstaticInitter.start(___tens_D2A)
	gstaticInitter.i32 = 0	// double least significant word 1
	gstaticInitter.i32 = 1072693248	// double most significant word 1
	gstaticInitter.i32 = 0	// double least significant word 10
	gstaticInitter.i32 = 1076101120	// double most significant word 10
	gstaticInitter.i32 = 0	// double least significant word 100
	gstaticInitter.i32 = 1079574528	// double most significant word 100
	gstaticInitter.i32 = 0	// double least significant word 1000
	gstaticInitter.i32 = 1083129856	// double most significant word 1000
	gstaticInitter.i32 = 0	// double least significant word 10000
	gstaticInitter.i32 = 1086556160	// double most significant word 10000
	gstaticInitter.i32 = 0	// double least significant word 100000
	gstaticInitter.i32 = 1090021888	// double most significant word 100000
	gstaticInitter.i32 = 0	// double least significant word 1e+06
	gstaticInitter.i32 = 1093567616	// double most significant word 1e+06
	gstaticInitter.i32 = 0	// double least significant word 1e+07
	gstaticInitter.i32 = 1097011920	// double most significant word 1e+07
	gstaticInitter.i32 = 0	// double least significant word 1e+08
	gstaticInitter.i32 = 1100470148	// double most significant word 1e+08
	gstaticInitter.i32 = 0	// double least significant word 1e+09
	gstaticInitter.i32 = 1104006501	// double most significant word 1e+09
	gstaticInitter.i32 = 536870912	// double least significant word 1e+10
	gstaticInitter.i32 = 1107468383	// double most significant word 1e+10
	gstaticInitter.i32 = 3892314112	// double least significant word 1e+11
	gstaticInitter.i32 = 1110919286	// double most significant word 1e+11
	gstaticInitter.i32 = 2717908992	// double least significant word 1e+12
	gstaticInitter.i32 = 1114446484	// double most significant word 1e+12
	gstaticInitter.i32 = 3846176768	// double least significant word 1e+13
	gstaticInitter.i32 = 1117925532	// double most significant word 1e+13
	gstaticInitter.i32 = 512753664	// double least significant word 1e+14
	gstaticInitter.i32 = 1121369284	// double most significant word 1e+14
	gstaticInitter.i32 = 640942080	// double least significant word 1e+15
	gstaticInitter.i32 = 1124887541	// double most significant word 1e+15
	gstaticInitter.i32 = 937459712	// double least significant word 1e+16
	gstaticInitter.i32 = 1128383353	// double most significant word 1e+16
	gstaticInitter.i32 = 2245566464	// double least significant word 1e+17
	gstaticInitter.i32 = 1131820119	// double most significant word 1e+17
	gstaticInitter.i32 = 1733216256	// double least significant word 1e+18
	gstaticInitter.i32 = 1135329645	// double most significant word 1e+18
	gstaticInitter.i32 = 1620131072	// double least significant word 1e+19
	gstaticInitter.i32 = 1138841828	// double most significant word 1e+19
	gstaticInitter.i32 = 2025163840	// double least significant word 1e+20
	gstaticInitter.i32 = 1142271773	// double most significant word 1e+20
	gstaticInitter.i32 = 3605196624	// double least significant word 1e+21
	gstaticInitter.i32 = 1145772772	// double most significant word 1e+21
	gstaticInitter.i32 = 105764242	// double least significant word 1e+22
	gstaticInitter.i32 = 1149300943	// double most significant word 1e+22
	gstaticInitter.start(___bigtens_D2A)
	gstaticInitter.i32 = 937459712	// double least significant word 1e+16
	gstaticInitter.i32 = 1128383353	// double most significant word 1e+16
	gstaticInitter.i32 = 3037031959	// double least significant word 1e+32
	gstaticInitter.i32 = 1184086197	// double most significant word 1e+32
	gstaticInitter.i32 = 3913284085	// double least significant word 1e+64
	gstaticInitter.i32 = 1295535875	// double most significant word 1e+64
	gstaticInitter.i32 = 4180679986	// double least significant word 1e+128
	gstaticInitter.i32 = 1518499656	// double most significant word 1e+128
	gstaticInitter.i32 = 2138292028	// double least significant word 1e+256
	gstaticInitter.i32 = 1964330973	// double most significant word 1e+256
	gstaticInitter.start(_freelist)
	gstaticInitter.zero = 64
	gstaticInitter.start(_pmem_next)
	gstaticInitter.i32 = _private_mem
	gstaticInitter.start(_private_mem)
	gstaticInitter.zero = 2304
	gstaticInitter.start(_p05_2E_3773)
	gstaticInitter.i32 = 5
	gstaticInitter.i32 = 25
	gstaticInitter.i32 = 125
	gstaticInitter.start(_p5s)
	gstaticInitter.zero = 4
	gstaticInitter.start(___mlocale_changed_2E_b)
	gstaticInitter.zero = 1
	gstaticInitter.start(__2E_str20159)
	gstaticInitter.asciz = "."
	gstaticInitter.start(_numempty22)
	gstaticInitter.asciz = "\x7f"
	gstaticInitter.start(___nlocale_changed_2E_b)
	gstaticInitter.zero = 1
	gstaticInitter.start(_ret_2E_1494_2E_0_2E_b)
	gstaticInitter.zero = 1
	gstaticInitter.start(_ret_2E_1494_2E_2_2E_b)
	gstaticInitter.zero = 1
	gstaticInitter.start(___sF)
	gstaticInitter.zero = 4
	gstaticInitter.zero = 4
	gstaticInitter.zero = 4
	gstaticInitter.i16 = 4
	gstaticInitter.zero = 2
	gstaticInitter.zero = 8
	gstaticInitter.zero = 4
	gstaticInitter.i32 = ___sF
	gstaticInitter.i32 = ___sclose
	gstaticInitter.i32 = ___sread
	gstaticInitter.i32 = ___sseek
	gstaticInitter.i32 = ___swrite
	gstaticInitter.zero = 8
	gstaticInitter.i32 = ___sFX
	gstaticInitter.zero = 4
	gstaticInitter.zero = 3
	gstaticInitter.zero = 1
	gstaticInitter.zero = 8
	gstaticInitter.zero = 4
	gstaticInitter.zero = 8
	gstaticInitter.zero = 4
	gstaticInitter.zero = 4
	gstaticInitter.zero = 4
	gstaticInitter.i16 = 8
	gstaticInitter.i16 = 1
	gstaticInitter.zero = 8
	gstaticInitter.zero = 4
	gstaticInitter.i32 = (___sF) + 88
	gstaticInitter.i32 = ___sclose
	gstaticInitter.i32 = ___sread
	gstaticInitter.i32 = ___sseek
	gstaticInitter.i32 = ___swrite
	gstaticInitter.zero = 8
	gstaticInitter.i32 = (___sFX) + 148
	gstaticInitter.zero = 4
	gstaticInitter.zero = 3
	gstaticInitter.zero = 1
	gstaticInitter.zero = 8
	gstaticInitter.zero = 4
	gstaticInitter.zero = 8
	gstaticInitter.zero = 4
	gstaticInitter.zero = 4
	gstaticInitter.zero = 4
	gstaticInitter.i16 = 10
	gstaticInitter.i16 = 2
	gstaticInitter.zero = 8
	gstaticInitter.zero = 4
	gstaticInitter.i32 = (___sF) + 176
	gstaticInitter.i32 = ___sclose
	gstaticInitter.i32 = ___sread
	gstaticInitter.i32 = ___sseek
	gstaticInitter.i32 = ___swrite
	gstaticInitter.zero = 8
	gstaticInitter.i32 = (___sFX) + 296
	gstaticInitter.zero = 4
	gstaticInitter.zero = 3
	gstaticInitter.zero = 1
	gstaticInitter.zero = 8
	gstaticInitter.zero = 4
	gstaticInitter.zero = 8
	gstaticInitter.start(___sdidinit_2E_b)
	gstaticInitter.zero = 1
	gstaticInitter.start(_usual_extra)
	gstaticInitter.zero = 2516
	gstaticInitter.start(_usual)
	gstaticInitter.zero = 1496
	gstaticInitter.start(___cleanup_2E_b)
	gstaticInitter.zero = 1
	gstaticInitter.start(___sglue)
	gstaticInitter.i32 = _uglue
	gstaticInitter.i32 = 3
	gstaticInitter.i32 = ___sF
	gstaticInitter.start(_uglue)
	gstaticInitter.zero = 4
	gstaticInitter.i32 = 17
	gstaticInitter.i32 = _usual
	gstaticInitter.start(___sFX)
	gstaticInitter.zero = 444
	gstaticInitter.start(_initial_2E_4576)
	gstaticInitter.zero = 128
	gstaticInitter.start(_xdigs_lower_2E_4528)
	gstaticInitter.ascii = "0123456789abcdef?"
	gstaticInitter.start(_xdigs_upper_2E_4529)
	gstaticInitter.ascii = "0123456789ABCDEF?"
	gstaticInitter.start(__2E_str118283)
	gstaticInitter.asciz = "nan"
	gstaticInitter.start(__2E_str219284)
	gstaticInitter.asciz = "NAN"
	gstaticInitter.start(__2E_str320285)
	gstaticInitter.asciz = "inf"
	gstaticInitter.start(__2E_str421)
	gstaticInitter.asciz = "INF"
	gstaticInitter.start(__2E_str522)
	gstaticInitter.asciz = "(null)"
	gstaticInitter.start(_blanks_2E_4526)
	gstaticInitter.ascii = "                "
	gstaticInitter.start(_zeroes_2E_4527)
	gstaticInitter.ascii = "0000000000000000"
	gstaticInitter.start(___atexit)
	gstaticInitter.zero = 4
	gstaticInitter.start(___atexit0_2E_3021)
	gstaticInitter.zero = 520
	gstaticInitter.start(_free_list)
	gstaticInitter.zero = 20
	gstaticInitter.start(_malloc_origo)
	gstaticInitter.zero = 4
	gstaticInitter.start(_last_index)
	gstaticInitter.zero = 4
	gstaticInitter.start(_malloc_brk)
	gstaticInitter.zero = 4
	gstaticInitter.start(_malloc_ninfo)
	gstaticInitter.zero = 4
	gstaticInitter.start(_page_dir)
	gstaticInitter.zero = 4
	gstaticInitter.start(_malloc_junk_2E_b)
	gstaticInitter.zero = 1
	gstaticInitter.start(_px)
	gstaticInitter.zero = 4
	gstaticInitter.start(_malloc_zero_2E_b)
	gstaticInitter.zero = 1
	gstaticInitter.start(_malloc_hint_2E_b)
	gstaticInitter.zero = 1
	gstaticInitter.start(_malloc_cache)
	gstaticInitter.i32 = 16
	gstaticInitter.start(_malloc_active_2E_3509)
	gstaticInitter.zero = 4
	gstaticInitter.start(_malloc_started_2E_3510_2E_b)
	gstaticInitter.zero = 1
	gstaticInitter.start(__2E_str113335)
	gstaticInitter.asciz = "MALLOC_OPTIONS"
	gstaticInitter.start(_malloc_realloc_2E_b)
	gstaticInitter.zero = 1
	gstaticInitter.start(_malloc_sysv_2E_b)
	gstaticInitter.zero = 1
	gstaticInitter.start(__2E_str7403)
	gstaticInitter.asciz = "VGLIOCTL %d\n"
	gstaticInitter.start(__2E_str99)
	gstaticInitter.asciz = "IntType"
	gstaticInitter.start(__2E_str1100)
	gstaticInitter.asciz = "AS3ValType"
	gstaticInitter.start(__2E_str2101)
	gstaticInitter.asciz = "fNativeContext"
	gstaticInitter.start(__2E_str3102)
	gstaticInitter.asciz = "InitLibrary: AS3ValType,hasAutoCallbacks: AS3ValType,HaltOperation,BlockForData:IntVal "
	modPostStaticInit()
}
modEnd()
}



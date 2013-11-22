//////project name
//Artnet

//////description
//Utility library to talk Artnet, ie. DMX over ethernet
//following the ArtNet 2 specification (which seems no longer available)
//here is a link to the ArtNet 3 specification instead: http://www.artisticlicence.com/WebSiteMaster/User%20Guides/art-net.pdf

//////licence
//GNU Lesser General Public License (LGPL v3)

//////language/ide
//delphi

//////initial author
//Sebastian Oschatz -> oschatz@vvvv.org

unit Artnet;

interface

uses
  Sysutils, Syncobjs, Classes,
  IdGlobal, IdUDPServer, IdSocketHandle,
  Events;

type
  TMArtnetString18 = array[0..17] of char;
  TMArtnetString64 = array[0..63] of char;

  TMArtPollPacket  = record
    { ID - Array of 8 characters, the final character is a null termination.
    Value = ‘A’ ‘r’ ‘t’ ‘-‘ ‘N’ ‘e’ ‘t’ 0x00 }
    ID : array[0..7] of char;

    { The OpCode defines the class of data following ArtPoll within this UDP packet.
    Transmitted low byte first. See Table 1 for the OpCode listing.  }
    OpCode : Word; // Set to OpPoll.

    { Art-Net protocol revision  -  Current value 14.
    Servers should ignore communication with nodes using a protocol version
    lower than 14. }
    ProtVerH : Byte; { High byte of the Art-Net protocol revision number. }
    ProtVerL : Byte; { Low byte of the Art-Net protocol revision number. }
    { Set behaviour of Node }
    TalkToMe : Byte;
    {   Bits 7-2 Unused, transmit as zero, do not test upon receipt.
        Bit 1   0 = Only send ArtPollReply in response to an ArtPoll or ArtAddress.
                1 = Send ArtPollReply whenever Node conditions change.
                    This selection allows the Server to be informed of change
                    without the need to continuously poll.
        Bit 0   0 = Broadcast all further ArtPollReplys.
                1 = Send all future ArtPollReplys to the sender of
                    this packet. }
    Pad : Byte;  // Filler byte to make packet length even.
  end;

  TMArtPollReplyPacket  = record
    ID : array[0..7] of char;
    { ID - Array of 8 characters, the final character is a null termination.
    Value = ‘A’ ‘r’ ‘t’ ‘-‘ ‘N’ ‘e’ ‘t’ 0x00 }

    OpCode : Word;
    { The OpCode defines the class of data following ArtPoll within this UDP packet.
    Transmitted low byte first. See Table 1 for the OpCode listing.  }

    IPAddress : array[0..3] of Byte;
    { Array containing the Node’s IP address. First array entry is most significant
    byte of address. }

    PortL : Byte;
    PortH : Byte;
    { The Port is always 0x1936 Transmitted low byte first. }

    VersInfoH : Byte;
    VersInfoL : Byte;
    { High byte of Node’s firmware revision number.
    The Server should only use this field to decide if a firmware update should proceed.
    The convention is that a higher number is a more recent release of firmware. }
    { Low byte of Node’s firmware revision number. }

    SubSwitchH : Byte;
    { The high byte of the Node’s Subnet Address. This field is currently unused and
    set to zero. It is provided to allow future expansion. }

    SubSwitchL : Byte;
    { The low byte of the Node’s Sub-net Address. This is the variable that addresses a Node
    within Art-Net. In the Ether-Lynx and Netgate products, the front panel Sub-net
    ‘switch’ sets this field. }

    OemH : Byte;
    { The high byte of the Oem value. }
    OemL : Byte;
    { The low byte of the Oem value. The Oem word describes the equipment
    vendor and the feature set available. Bit 15 high indicates extended features available.
    Current registered codes are defined in Table 2. }

    UbeaVersion : Byte;
    { This field contains the firmware version of the User Bios Extension Area (UBEA). If the
    UBEA is not programmed, this field contains zero. }

    Status : Byte;
    { General Status register containing bit fields as follows.
        7-6 Indicator state.
                00 Indicator state unknown.
                01 Indicators in Locate Mode.
                10 Indicators in Mute Mode.
                11 Indicators in Normal Mode.
        5-4 Universe Address Programming Authority
                00 Universe Programming Authority
                        unknown.
                01 Set by front panel controls.
                10 Programmed by network.
                11 Not used.

        3 Not implemented, transmit as zero, receivers
                do not test.
        2       0 = Normal firmware boot (from flash).
                        Nodes that do not support dual boot,
                        clear this field to zero.

                1 = Booted from ROM.
        1       0 = Not capable of Remote Device Management (RDM).
                1 = Capable of Remote Device Management (RDM).
        0       0 = UBEA not present or corrupt
                1 = UBEA present   }


    EstaMan : Word;
    { The ESTA manufacturer code. These codes are used to represent equipment
    manufacturer. They are assigned by ESTA. This field can be interpreted as two ASCII
    bytes representing the manufacturer initials }

    ShortName : array[0..17] of char;
    { The array represents a null terminated short name for the Node. The Server uses the
    ArtAddress packet to program this string. Max length is 17 characters plus the null.
    This is a fixed length field, although the string it contains can be shorter than the
    field. }

    LongName : array[0..63] of char;
    { The array represents a null terminated long name for the Node. The Server uses the
    ArtAddress packet to program this string. Max length is 63 characters plus the null.
    This is a fixed length field, although the string it contains can be shorter than the
    field. }

    NodeReport : array[0..63] of char;
    { The array is a textual report of the Node’s operating status or operational errors. It is
    primarily intended for ‘engineering’ data rather than ‘end user’ data. The field is
    formatted as: “#xxxx [yyyy..] zzzzz…”  xxxx is a hex status code as defined in Table
    3. yyyy is a decimal counter that increments every time the Node sends an
    ArtPollResponse that is not responding to an ArtPoll.
    This allows the server to monitor event changes in the Node.
    zzzz is an English text string defining the status.
    This is a fixed length field, although the string it contains can be shorter than the field. }

    NumPortsH : byte;
    NumPortsL : byte;
    { The high byte of the word describing the number of input or output ports. The high
    byte is for future expansion and is currently zero. If number
    of inputs is not equal to number of outputs, the largest value is taken.
    Zero is an illegal value. The maximum value is 4. }

    PortTypes : array[0..3] of byte;
    { This array defines the operation and protocol of each channel.
    (Ether-Lynx example = 0xc0, 0xc0, 0xc0, 0xc0).
    The array length is fixed, independent of the number of inputs or
    outputs physically available on the Node.
        7       Set is this channel can output data from the
                Art-Net Network.
        6       Set if this channel can input onto the Art-
                NetNetwork.
        5-0     00000 = DMX512
                00001 = MIDI
                00010 = Avab
                00011 = Colortran CMX
                00100 = ADB 62.5
                00101 = Art-Net   }

    GoodInput : array[0..3] of byte;
    { This array defines input status of the node.
        7       Set – Data received.
        6       Set – Channel includes DMX512 test packets.
        5       Set – Channel includes DMX512 SIP’s.
        4       Set – Channel includes DMX512 text packets.
        3       Set – Input is disabled.
        2       Set – Receive errors detected.
        1-0     Unused and transmitted as zero.}

    GoodOutput : array[0..3] of byte;
    { This array defines output status of the node.
        7       Set – Data is being transmitted.
        6       Set – Channel includes DMX512 test packets.
        5       Set – Channel includes DMX512 SIP’s.
        4       Set – Channel includes DMX512 text packets.
        3       Set – Output is merging ArtNet data.
        2       Set – DMX output short detected on power up
        1       Set – Merge Mode is LTP.
        0       Unused and transmitted as zero. }


    Swin : array[0..3] of byte;
    { This array defines the 8 bit Universe address of the available input
    channels. In DMX-Hub and Netgate, the high nibble is identical to
    the data held in the low nibble of Subswitch. The low nibble corresponds
    to the front panel selector for each channel. }

    Swout : array[0..3] of byte;
    { This array defines the 8 bit Universe address of the available output
    channels. In DMX-Hub and Netgate, the high nibble is identical to
    the data held in the low nibble of Subswitch. The low nibble corresponds
    to the front panel selector for each channel.  }

    SwVideo : byte;
    { Set to 00 when video display is showing local data.
    Set to 01 when video is showing ethernet data.  }

    SwMacro : byte;
    { If the Node supports macro key inputs, this byte represents the trigger
    values. The Node is responsible for ‘debouncing’ inputs. When the ArtPollReply
    is set to transmit automatically, (TalkToMe Bit 1), the ArtPollReply will be
    sent on both key down and key up events. However, the Server should not
    assume that only one bit position has changed.
    The Macro inputs are used for remote event triggering or cueing.
    Bit fields are active high.
        7       Set – Macro 8 active.
        6       Set – Macro 7 active.
        5       Set – Macro 6 active.
        4       Set – Macro 5 active.
        3       Set – Macro 4 active.
        2       Set – Macro 3 active.
        1       Set – Macro 2 active.
        0       Set – Macro 1 active.  }

   SwRemote : byte;
   { If the Node supports remote trigger inputs, this byte represents the trigger
   values. The Node is responsible for ‘debouncing’ inputs.
   When the ArtPollReply is set to transmit automatically, (TalkToMe Bit 1), the
   ArtPollReply will be sent on both key down and key up events. However, the Server
   should not assume that only one bit position has changed. The Remote inputs are
   used for remote event triggering or cueing.
   Bit fields are active high.
        7 Set – Remote 8 active.
        6 Set – Remote 7 active.
        5 Set – Remote 6 active.
        4 Set – Remote 5 active.
        3 Set – Remote 4 active.
        2 Set – Remote 3 active.
        1 Set – Remote 2 active.
        0 Set – Remote 1 active.
   }

 Reserved27 : Byte; // Not used, set to zero
 Reserved28 : Byte; // Not used, set to zero
 Reserved29 : Byte; // Not used, set to zero

 Style : Byte;
 { The Style code defines the equipment style of the device.
  The Style code defines the general functionality of a Server.
  Code Mnemonic Description
  0x00 StNode A DMX to / from Art-Net device
  0x01 StServer A lighting console.
  0x02 StMedia A Media Server.
  0x03 StRoute A network routing device.
  0x04 StBackup A backup device.
  0x05 StConfig A configuration or diagnostic tool.
 }

 MACAddress : array[0..5] of byte;
 { MAC Address Hi Byte to Lo Byte. Set to zero if node
  cannot supply this information. }

 Filler : array[0..31] of byte;
 { Transmit as zero. For future expansion.}
end;

  TMArtPollData = record
    IsInput : boolean;
    Subnet : integer;
    Universe : integer;
    ShortName : string;
    LongName : string;
  end;

  TMArtDmxPacket  = record
    ID : array[0..7] of AnsiChar;
    { ID - Array of 8 characters, the final character is a null termination.
    Value = ‘A’ ‘r’ ‘t’ ‘-‘ ‘N’ ‘e’ ‘t’ 0x00 }

    OpCode : Word;
    { The OpCode defines the class of data following ArtPoll within this UDP packet.
    Transmitted low byte first. See Table 1 for the OpCode listing.  }

    { Art-Net protocol revision  -  Current value 14.
    Servers should ignore communication with nodes using a protocol version
    lower than 14. }
    ProtVerH : Byte; { High byte of the Art-Net protocol revision number. }
    ProtVerL : Byte; { Low byte of the Art-Net protocol revision number. }

    Sequence : Byte;
    { The sequence number is used to ensure that ArtDmx packets are used in the
    correct order. When Art-Net is carried over a medium such as the Internet,
    it is possible that ArtDmx packets will reach the receiver out of order.
    This field is incremented in the range 0x01 to 0xff to allow the receiving node
    to resequence packets. The Sequence field is set to 0x00 to disable this feature. }

    Physical : Byte;
    { The physical input port from which DMX512 data was input. This field is for
    information only. Use Universe for data routing. }

    UniverseL : Byte;
    UniverseH : Byte;
    
    { The high byte is currently set to zero. The low byte is the address of this
    Universe of data. In DMX-Hub, the high nibble is the Sub-net switch and the
    low Nibble is the Universe address switch. Transmitted low byte first. }

    LengthH : Byte;
    LengthL : Byte;
    { The length of the DMX512 data array. This value should be an even number in
    the range 2 – 512. It represents the number of DMX512 channels received. }

    Data : array[0..511] of byte;
  end;

  TMArtnetDecoder = class;

  TMArtnetEvent = procedure (Sender: TMArtnetDecoder) of object;

  TMArtnetDecoder = class
  private
    FCriticalSection: TCriticalSection;
    FSocket: TIdUDPServer;
    FDoArtPollReply: Boolean;
    FCurrentTime: Double;
    FInputs: array[0..255] of string;
    Outputs: array[0..255] of string;
    Inputs: array [0..255] of string;
    FArtPoll: TMEvent;
    FID: Integer;
    procedure ReadCB(AThread: TIdUDPListenerThread; AData: TIdBytes; ABinding:
        TIdSocketHandle);
  protected
    function isArtDMX(packet : pointer): Boolean;
    procedure ParseArtDMX(packet : pointer; timestamp : double);
    function CreateArtDMX(subnet, universe: byte; dmx : PByteArray	): 
        TMArtDMXPacket;
    function CreateArtPollReply(name, shortname: string; isInput: boolean; subnet, 
        universe: byte; fakeipid : byte): TMArtPollReplyPacket;
    function CreateNodeReport: string;
    function isArtPoll(packet : pointer): Boolean;
  public
    DMXReceived: array[0..15] of array[0..15] of array[0..512] of byte;
    DMXLastReceiveTime: array[0..15] of array[0..15] of double;
    constructor Create; 
    destructor Destroy;  override;
    procedure SendDMX(DestAdr: String; subnet, universe: byte; dmx: PByteArray);
    procedure Poll;
    procedure SendPortUpdate;
    function GetID: Integer;
    property ArtPoll: TMEvent read FArtPoll;
  published
    procedure SendArtPollReply(shortname, name: string; isInput: boolean; subnet, 
        universe, id: byte);
  end;

function GArtnetDriver: TMArtnetDecoder;


const
  cmalOpArtPoll = $2000;
  { This is an ArtPoll packet, no other data is contained in this UDP packet. }
  
  cmalOpArtPollReply = $2100;
  { This is an ArtPollReply Packet. It contains device status information. }

  cmalOpArtDMX = $5000;
  { This is an ArtDmx data packet. It contains DMX512 information for a single Universe. }

  cmalArtNetID = 'Art-Net' + #0;

var
  GArtNetPort : smallint = $1936;

implementation

uses
  Variants, IdUDPBase, Clock;

var
  GArtnetDriverVar : TMArtnetDecoder;

function GArtnetDriver: TMArtnetDecoder;
begin
  if not assigned(GArtnetDriverVar) then
  begin
    GArtnetDriverVar := TMArtnetDecoder.Create;
  end;

  result := GArtnetDriverVar;
end;


function TMArtnetDecoder.CreateArtDMX(subnet, universe: byte; dmx : 
    PByteArray	): TMArtDMXPacket;
var
  i : integer;
begin
  fillchar(result, sizeof(result), 0);
  result.ID := cmalArtNetID;  // magic
  result.OpCode := cmalOpArtDMX;
  result.ProtVerH := 0;
  result.ProtVerL := 14;
  result.Sequence := 0;  // no sequence
  result.Physical := 0;
  result.UniverseL := ((subnet and $0F) * 16 ) + (universe and $0F);
  result.UniverseH := 0;
  result.LengthH := hi(512);
  result.LengthL := lo(512);
  for i:= 0 to 511 do
    result.Data[i] := dmx[i];
end;

function TMArtnetDecoder.CreateArtPollReply(name, shortname: string; isInput: 
    boolean; subnet, universe: byte; fakeipid : byte): TMArtPollReplyPacket;
var
  k : byte;
  ip : longword;
  x : integer;
begin
  fillchar(result, sizeof(result), 0);
  result.ID := cmalArtNetID; // magic
  result.OpCode := cmalOpArtPollReply;


  (*
  ip := GetCurrentIPAdress;
  result.IPAddress[0] := ip and $FF;
  result.IPAddress[1] := ip and $FF00 shr 8;
  result.IPAddress[2] := ip and $FF0000 shr 16;
  result.IPAddress[3] := ip and $FF000000 shr 24;
  *)

  // faking the ip will allow multiple devices listed in the GrandMA desk
  // as we broadcast everything the ip is not needed anyway.
  
  result.IPAddress[0] := 2;
  result.IPAddress[1] := 0;
  result.IPAddress[2] := 0;
  result.IPAddress[3] := fakeipid;


  result.PortH := $19;   // magic
  result.PortL := $36;  // magic
  result.VersInfoH := 1;
  result.VersInfoL := 2;
  result.SubSwitchH := 0;
  result.SubSwitchL := (subnet and $0F);
  result.OemH := 0;
  result.OemL := 255;
  result.UBEAVersion := 0;
  result.Status := 0;
  result.EstaMan := 0;
  StrPLCopy(result.ShortName, shortname, 17);
  StrPLCopy(result.LongName, name, 64);
  StrPLCopy(result.NodeReport, CreateNodeReport, 64);
  result.NumPortsH := 0;
  result.NumPortsL := 1;

  x := 0;
  // bit 7    Set if this channel can output data from the Art-Net Network.
  // bit 6    Set if this channel can input onto the Art- NetNetwork.
  if isInput
    then result.PortTypes[x] := $40
    else result.PortTypes[x] := $80;

  result.GoodInput[x] := $80;
  result.GoodOutput[x] := 0;

  k := ((subnet and $0F) * 16 ) + (universe and $0F);
  if isInput
    then result.Swin[x] := k
    else result.Swout[x] := k;

  result.SwVideo := 0;    // just copied from real packets.. dont know what it means
  result.SwMacro := 85;
  result.SwRemote := 176;

  result.Style := 0;
  result.IPAddress[2] := k; 

end;

function TMArtnetDecoder.CreateNodeReport: string;
begin
 { The array is a textual report of the Node’s operating status or operational errors. It is
    primarily intended for ‘engineering’ data rather than ‘end user’ data. The field is
    formatted as: “#xxxx [yyyy..] zzzzz…”  xxxx is a hex status code as defined in Table
    3. yyyy is a decimal counter that increments every time the Node sends an
    ArtPollResponse that is not responding to an ArtPoll.
    This allows the server to monitor event changes in the Node.
    zzzz is an English text string defining the status.

    Code   Mnemonic     Description
    0x0000 RcDebug      Booted in debug mode (Only used in development)
    0x0001 RcPowerOk    Power On Tests successful
    0x0002 RcPowerFail  Hardware tests failed at Power On
    0x0003 RcSocketWr1  Last UDP from Node failed due to truncated length,
                        Most likely caused by a collision.
    0x0004 RcParseFail  Unable to identify last UDP transmission. Check
                        OpCode and packet length.
    0x0005 RcUdpFail    Unable to open Udp Socket in last transmission
                        attempt
    0x0006 RcShNameOk   Confirms that Short Name programming via
                        ArtAddress, was successful.
    0x0007 RcLoNameOk   Confirms that Long Name programming via
                        ArtAddress, was successful.
    0x0008 RcDmxError   DMX512 receive errors detected.
    0x0009 RcDmxUdpFull Ran out of internal DMX transmit buffers.
    0x000a RcDmxRxFull  Ran out of internal DMX Rx buffers.
    0x000b RcSwitchErr  Rx Universe switches conflict.
    0x000c RcConfigErr  Product configuration does not match firmware.
    0x000d RcDmxShort   DMX output short detected. See GoodOutput field.
    0x000e RcFirmwareFail Last attempt to upload new firmware failed.
    0x000f RcUserFail   User changed switch settings when address locked by
                        remote programming. User changes ignored.
}

  Result := '#0001 [0000] everything you know is wrong';
end;

function TMArtnetDecoder.isArtDMX(packet : pointer): Boolean;
var
  dmx : ^TMArtDMXPacket;
begin
  dmx := packet;
  result := false;
  if strcomp(dmx.ID, cmalArtNetID)<>0  then exit;
  if dmx.OpCode <> cmalOpArtDMX then exit;
  result := true;
end;

function TMArtnetDecoder.isArtPoll(packet : pointer): Boolean;
var
  poll : ^TMArtPollPacket;
begin
  poll := packet;
  result := false;
  if strcomp(poll.ID, cmalArtNetID)<>0  then exit;
  if poll.OpCode <> cmalOpArtPoll then exit;   // we tested successfully against $2100 ..
  result := true;
end;

procedure TMArtnetDecoder.ParseArtDMX(packet : pointer; timestamp : double);
var
  dmx : ^TMArtDMXPacket;
  i : integer;
begin
  if not isArtDMX(packet) then
    exit;

  dmx := packet;

  for i:= 0 to 511 do
    DMXReceived[dmx.UniverseL div 16, dmx.UniverseL mod 16, i] := dmx.Data[i];

  DMXLastReceiveTime[dmx.UniverseL div 16, dmx.UniverseL mod 16] := timestamp;
end;

constructor TMArtnetDecoder.Create;
var
  i, j : integer; 
begin
  FCriticalSection := TCriticalSection.Create;
  FSocket := TIdUDPServer.Create(nil);
  FSocket.ThreadedEvent := True;
  FSocket.DefaultPort := GArtNetPort;

  FSocket.OnUDPRead := ReadCB;
  FSocket.BroadcastEnabled := True;
  FSocket.Active := True;
  
  FArtPoll := TMEvent.Create;
  fillchar(DMXReceived, sizeof(DMXReceived), 0);

  for i:= 0 to 15 do
    for j:= 0 to 15 do
      DMXLastReceiveTime[i, j] := GClock.Time;
end;

destructor TMArtnetDecoder.Destroy;
begin
  FSocket.Active := False;
  FSocket.Destroy;

  FArtPoll.Free;
  FCriticalSection.Free;

  inherited;
end;

procedure TMArtnetDecoder.SendDMX(DestAdr: String; subnet, universe: byte; dmx:
    PByteArray);
var
  artdmx : TMArtDMXPacket;
  buffer: TIdBytes;
begin
  artdmx := CreateArtDMX(subnet, universe, dmx);

  buffer := IdGlobal.RawToBytes(artdmx, SizeOf(artdmx));

  FSocket.SendBuffer(DestAdr, GArtNetPort, Id_IPv4, buffer);
end;

procedure TMArtnetDecoder.Poll;
var
  i : integer; 
begin
  // make sure this can be called multiple times during the mainloop...
  if FDoArtPollReply then
    ArtPoll.Call(self, null);

  FDoArtPollReply := False;
end;


procedure TMArtnetDecoder.SendArtPollReply(shortname, name: string; isInput: 
    boolean; subnet, universe, id: byte);
var
  ArtpollReply : TMArtPollReplyPacket;
  buffer: TIdBytes;
begin
  ArtpollReply := CreateArtPollReply(shortname, name, isInput, subnet, universe, id);

  buffer := IdGlobal.RawToBytes(ArtpollReply, SizeOf(ArtpollReply));

  FSocket.SendBuffer('255.255.255.255', GArtNetPort, buffer);
end;

procedure TMArtnetDecoder.SendPortUpdate;
begin
  FDoArtPollReply := True;
end;

function TMArtnetDecoder.GetID: Integer;
begin
  Result := FID;
  FID := (FID + 1) and $FF;
end;

procedure TMArtnetDecoder.ReadCB(AThread: TIdUDPListenerThread; AData:
    TIdBytes; ABinding: TIdSocketHandle);
var
  item: Pointer;
  size: integer;
begin
  try
    GetMem(item, Length(AData));

    IdGlobal.BytesToRaw(AData, item^, Length(AData));

    // parse
    if isArtPoll(item)
      then FDoArtPollReply := True;

    ParseArtDMX(item, GClock.Time);
  finally
    FreeMem(item);
  end;
end;


initialization
  GArtnetDriverVar := nil;

finalization
  GArtnetDriverVar.Free;
  GArtnetDriverVar := nil;

end.
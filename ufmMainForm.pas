unit ufmMainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Winapi.DirectSound, Winapi.MMSystem,
  Vcl.StdCtrls;

type
  TfrmMainForm = class(TForm)
    btn1: TButton;
    procedure btn1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    DirectSound: IDirectSound;
    DirectSoundBuffer: IDirectSoundBuffer;
    SecondarySoundBuffer: IDirectSoundBuffer;
    procedure AppCreateWritePrimaryBuffer;
    procedure AppCreateWriteSecondaryBuffer;
    procedure AppWriteDataToBuffer(Buffer: IDirectSoundBuffer; OffSet: DWord;
      var SoundData; SoundBytes: DWord);
    procedure CopyWAVToBuffer(Name: PChar; var Buffer: IDirectSoundBuffer);
    { Public declarations }
  end;

var
  frmMainForm: TfrmMainForm;

implementation

{$R *.dfm}

procedure TfrmMainForm.FormDestroy(Sender: TObject);
var
  i: ShortInt;
begin
  if Assigned(DirectSoundBuffer) then
  begin
    DirectSoundBuffer.Stop;
    DirectSoundBuffer._Release;
    DirectSoundBuffer := nil;
  end;

  if Assigned(SecondarySoundBuffer) then
  begin
    SecondarySoundBuffer.Stop;
//    SecondarySoundBuffer._Release;
    SecondarySoundBuffer := nil;
  end;


  // for i := 0 to 1 do
  // if Assigned(SecondarySoundBuffer[i]) then
  // SecondarySoundBuffer[i]._Release;
  // if Assigned(DirectSound) then
//   DirectSound._Release;
   DirectSound := nil;
end;

procedure TfrmMainForm.AppCreateWritePrimaryBuffer;
var
  BufferDesc: DSBUFFERDESC;
  Caps: DSBCaps;
  PCM: TWaveFormatEx;
  Res: HResult;
begin
  if DirectSound.SetCooperativeLevel(Handle, DSSCL_PRIORITY) <> DS_OK then
    raise Exception.Create('Unable to set Coopeative Level');

  FillChar(BufferDesc, SizeOf(DSBUFFERDESC), 0);
  FillChar(PCM, SizeOf(TWaveFormatEx), 0);

  PCM.wFormatTag := WAVE_FORMAT_PCM;
  PCM.nChannels := 2;
  PCM.nSamplesPerSec := 44100;
  PCM.wBitsPerSample := 16;
  PCM.nBlockAlign := Round((PCM.wBitsPerSample / 8) * PCM.nChannels);
  PCM.nAvgBytesPerSec := PCM.nSamplesPerSec * PCM.nBlockAlign;
  PCM.cbSize := 0;

  with BufferDesc do
  begin
    dwSize := SizeOf(DSBUFFERDESC);
    dwFlags := DSBCAPS_PRIMARYBUFFER or DSBCAPS_CTRLVOLUME;
    dwBufferBytes := 0;
    lpwfxFormat := nil;
    dwReserved := 0;
  end;

  // if DirectSound.SetCooperativeLevel(Handle, DSSCL_WRITEPRIMARY) <> DS_OK then
  // raise Exception.Create('Unable to set Coopeative Level');
  if DirectSound.CreateSoundBuffer(BufferDesc, DirectSoundBuffer, nil) <> DS_OK
  then
    raise Exception.Create('Create Sound Buffer failed');

  Res := DirectSoundBuffer.SetFormat(@PCM);
  if Res <> DS_OK then
    raise Exception.Create('Unable to Set Format ' + IntToHex(Res, 8));
  // if DirectSound.SetCooperativeLevel(Handle, DSSCL_NORMAL) <> DS_OK then
  // raise Exception.Create('Unable to set Coopeative Level');
end;

procedure TfrmMainForm.AppCreateWriteSecondaryBuffer;
var
  BufferDesc: DSBUFFERDESC;
  Caps: DSBCaps;
  PCM: TWaveFormatEx;
begin
  FillChar(BufferDesc, SizeOf(DSBUFFERDESC), 0);
  FillChar(PCM, SizeOf(TWaveFormatEx), 0);

  PCM.wFormatTag := WAVE_FORMAT_PCM;
  PCM.nChannels := 2;
  PCM.nSamplesPerSec := 44100;
  PCM.wBitsPerSample := 16;
  PCM.nBlockAlign := Round((PCM.wBitsPerSample / 8) * PCM.nChannels);
  PCM.nAvgBytesPerSec := PCM.nSamplesPerSec * PCM.nBlockAlign;
  PCM.cbSize := 0;

  with BufferDesc do
  begin
    dwSize := SizeOf(DSBUFFERDESC);
    dwFlags := DSBCAPS_CTRLVOLUME;
    dwBufferBytes := 361352;
    lpwfxFormat := @PCM;
    dwReserved := 0;
  end;

  if DirectSound.CreateSoundBuffer(BufferDesc, SecondarySoundBuffer, nil) <> DS_OK
  then
    raise Exception.Create('Create Sound Buffer failed');
end;

procedure TfrmMainForm.AppWriteDataToBuffer(Buffer: IDirectSoundBuffer;
  OffSet: DWord; var SoundData; SoundBytes: DWord);
var
  AudioPtr1, AudioPtr2: Pointer;
  AudioBytes1, AudioBytes2: DWord;
  h: HResult;
  Temp: Pointer;
begin
  h := SecondarySoundBuffer.Lock(OffSet, SoundBytes, @AudioPtr1, @AudioBytes1, @AudioPtr2,
    @AudioBytes2, 0);
  if h = DSERR_BUFFERLOST then
  begin
    Buffer.Restore;
    if Buffer.Lock(OffSet, SoundBytes, AudioPtr1, @AudioBytes1, AudioPtr2,
      @AudioBytes2, 0) <> DS_OK then
      raise Exception.Create('Unable to Lock Sound Buffer');
  end
  else if h <> DS_OK then
    raise Exception.Create('Unable to Lock Sound Buffer');

  Temp := @SoundData;
  Move(Temp^, AudioPtr1^, AudioBytes1);
  if AudioPtr2 <> nil then
  begin
    Temp := @SoundData;
    Inc(Integer(Temp), AudioBytes1);
//    Move(Temp^, AudioPtr2^, AudioBytes2);
  end;
  if Buffer.UnLock(AudioPtr1, AudioBytes1, AudioPtr2, AudioBytes2) <> DS_OK then
    raise Exception.Create('Unable to UnLock Sound Buffer');
end;

procedure TfrmMainForm.btn1Click(Sender: TObject);
begin
  CopyWAVToBuffer('1.wav', SecondarySoundBuffer);
  // CopyWAVToBuffer('flip.wav', SecondarySoundBuffer[1]);
  if SecondarySoundBuffer.Play(0, 0, 0) <> DS_OK then
    ShowMessage('Can not play the Sound');
  // if SecondarySoundBuffer[1].Play(0, 0, 0) <> DS_OK then
  // ShowMessage('Can not play the Sound');
end;

procedure TfrmMainForm.CopyWAVToBuffer(Name: PChar;
  var Buffer: IDirectSoundBuffer);
var
  Data: PAnsiChar;
  FName: TFileStream;
  DataSize: DWord;
  Chunk: string[4];
  Pos: Integer;
begin
  FName := TFileStream.Create(Name, fmOpenRead);
  Pos := 24;
  SetLength(Chunk, 4);
  repeat
    FName.Seek(Pos, soFromBeginning);
    FName.Read(Chunk[1], 4);
    Inc(Pos);
  until Chunk = 'data';
  FName.Seek(Pos + 3, soFromBeginning);
  FName.Read(DataSize, SizeOf(DWord));
  GetMem(Data, DataSize);
  FName.Read(Data^, DataSize);
  FName.Free;
  AppWriteDataToBuffer(Buffer, 0, Data^, DataSize);
  FreeMem(Data, DataSize);
end;

procedure TfrmMainForm.FormCreate(Sender: TObject);
begin
  begin
    if DirectSoundCreate(nil, DirectSound, nil) <> DS_OK then
      raise Exception.Create('Failed to create IDirectSound object');
    AppCreateWritePrimaryBuffer;
    AppCreateWriteSecondaryBuffer;
  end;
end;

end.

program DirectSoundExample;

uses
  Vcl.Forms,
  ufmMainForm in 'ufmMainForm.pas' {frmMainForm};

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMainForm, frmMainForm);
  Application.Run;
end.

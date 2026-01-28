program ProjectGaugeSkia;

//
// Based on GDI+/VCL code written by Grégory Maël Nolann Malonn (January, 2026)
//

uses
  System.StartUpCopy,
  FMX.Skia,
  FMX.Forms,
  ufMain in 'ufMain.pas' {frmMain};

{$R *.res}

begin
  GlobalUseSkia := False;
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
